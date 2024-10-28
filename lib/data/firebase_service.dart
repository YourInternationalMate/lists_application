import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedListInfo {
  final String originalListId;
  final String ownerEmail;
  final String ownerId;
  final DateTime sharedAt;
  final List<String> sharedWithEmails;

  SharedListInfo({
    required this.originalListId,
    required this.ownerEmail,
    required this.ownerId,
    required this.sharedAt,
    required this.sharedWithEmails,
  });

  Map<String, dynamic> toMap() {
    return {
      'originalListId': originalListId,
      'ownerEmail': ownerEmail,
      'ownerId': ownerId,
      'sharedAt': sharedAt,
      'sharedWithEmails': sharedWithEmails,
    };
  }

  static SharedListInfo fromMap(Map<String, dynamic> map) {
    return SharedListInfo(
      originalListId: map['originalListId'] ?? '',
      ownerEmail: map['ownerEmail'] ?? '',
      ownerId: map['ownerId'] ?? '',
      sharedAt: (map['sharedAt'] as Timestamp).toDate(),
      sharedWithEmails: List<String>.from(map['sharedWithEmails'] ?? []),
    );
  }
}

class FirebaseService {
  // Core Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SharedPreferences _prefs;

  bool _isInitialized = false;

  // Collection references
  late CollectionReference _listsCollection;
  late CollectionReference _userSettingsCollection;

  // Cache constants
  static const String _namesCachePrefix = 'list_name_';
  static const String _lastCacheUpdateKey = 'last_names_cache_update';
  static const int _cacheValidityDuration = 5 * 60 * 1000; // 5 minutes

  // Current user data
  String? get currentUserId => _auth.currentUser?.uid;

  // Private constructor for singleton pattern
  FirebaseService._create(this._prefs) {
    _listsCollection = _firestore.collection('lists');
    _userSettingsCollection = _firestore.collection('userSettings');
  }

  // Factory constructor
  static Future<FirebaseService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return FirebaseService._create(prefs);
  }

  // Batch load list names with caching
  Future<Map<String, String>> batchLoadListNames(List<String> listIds) async {
    if (listIds.isEmpty) return {};

    final currentTime = DateTime.now().millisecondsSinceEpoch;
    final lastUpdate = _prefs.getInt(_lastCacheUpdateKey) ?? 0;
    final Map<String, String> results = {};
    final List<String> idsToFetch = [];

    // Check cache first
    for (String id in listIds) {
      final cachedName = _prefs.getString('$_namesCachePrefix$id');
      if (cachedName != null &&
          (currentTime - lastUpdate) < _cacheValidityDuration) {
        results[id] = cachedName;
      } else {
        idsToFetch.add(id);
      }
    }

    if (idsToFetch.isEmpty) return results;

    try {
      final Map<String, Future<DocumentSnapshot>> futures = {};

      for (String id in idsToFetch) {
        if (id.contains('_')) {
          futures[id] = _firestore
              .collection('lists')
              .doc(currentUserId)
              .collection('sharedLists')
              .doc(id)
              .get();
        } else {
          futures[id] = _firestore
              .collection('lists')
              .doc(currentUserId)
              .collection('userLists')
              .doc(id)
              .get();
        }
      }

      final responses = await Future.wait(futures.values);
      var index = 0;

      for (var id in futures.keys) {
        final doc = responses[index++];
        if (doc.exists) {
          final name = (doc.data() as Map<String, dynamic>)['name'] ?? id;
          results[id] = name;
          await _prefs.setString('$_namesCachePrefix$id', name);
        } else {
          results[id] = id;
        }
      }

      await _prefs.setInt(_lastCacheUpdateKey, currentTime);
      return results;
    } catch (e) {
      print('Error batch loading list names: $e');
      return results;
    }
  }

  // Cache management
  Future<void> clearNameCache() async {
    final keys = _prefs.getKeys();
    for (String key in keys) {
      if (key.startsWith(_namesCachePrefix)) {
        await _prefs.remove(key);
      }
    }
    await _prefs.remove(_lastCacheUpdateKey);
  }

  // List Operations
  Future<void> createNewList(String listName) async {
    if (currentUserId == null) return;

    await _listsCollection
        .doc(currentUserId)
        .collection('userLists')
        .doc(listName)
        .set({
      'name': listName,
      'createdAt': FieldValue.serverTimestamp(),
      'items': [],
      'sharedWith': [],
      'sharedWithEmails': [],
      'owner': currentUserId,
    });
  }

  Future<List<Map<String, dynamic>>> loadListData(String listName) async {
    if (currentUserId == null) return [];

    try {
      if (listName.contains('_')) {
        final sharedDoc = await _firestore
            .collection('lists')
            .doc(currentUserId)
            .collection('sharedLists')
            .doc(listName)
            .get();

        if (sharedDoc.exists) {
          return List<Map<String, dynamic>>.from(
              sharedDoc.data()?['items'] ?? []);
        }
      } else {
        final docSnapshot = await _firestore
            .collection('lists')
            .doc(currentUserId)
            .collection('userLists')
            .doc(listName)
            .get();

        if (docSnapshot.exists) {
          return List<Map<String, dynamic>>.from(
              docSnapshot.data()?['items'] ?? []);
        }
      }
      return [];
    } catch (e) {
      print('Error loading list data: $e');
      return [];
    }
  }

  Future<void> updateList(
      String listName, List<Map<String, dynamic>> items) async {
    if (currentUserId == null) return;

    await _listsCollection
        .doc(currentUserId)
        .collection('userLists')
        .doc(listName)
        .update({
      'items': items,
      'lastModified': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteList(String listName) async {
    if (currentUserId == null) return;

    final batch = _firestore.batch();

    try {
      if (listName.contains('_')) {
        final sharedListRef = _firestore
            .collection('lists')
            .doc(currentUserId)
            .collection('sharedLists')
            .doc(listName);

        batch.delete(sharedListRef);
      } else {
        final listRef = _firestore
            .collection('lists')
            .doc(currentUserId)
            .collection('userLists')
            .doc(listName);

        final doc = await listRef.get();

        if (doc.exists) {
          final sharedWithIds =
              List<String>.from(doc.data()?['sharedWith'] ?? []);

          for (final userId in sharedWithIds) {
            final sharedRef = _firestore
                .collection('lists')
                .doc(userId)
                .collection('sharedLists')
                .doc('${currentUserId}_$listName');

            batch.delete(sharedRef);
          }

          batch.delete(listRef);
        }
      }

      await batch.commit();
      // Clear cache for deleted list
      await _prefs.remove('$_namesCachePrefix$listName');
    } catch (e) {
      print('Error deleting list: $e');
      throw Exception('Failed to delete list: ${e.toString()}');
    }
  }

  // User Settings Operations
  Future<void> saveUserSettings(Map<String, dynamic> settings) async {
    if (currentUserId == null) return;

    await _userSettingsCollection
        .doc(currentUserId)
        .set(settings, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>> loadUserSettings() async {
    if (!_isInitialized) return {};
    try {
      final docSnapshot = await _userSettingsCollection.doc(currentUserId).get();
      if (docSnapshot.exists) {
        return docSnapshot.data() as Map<String, dynamic>;
      }
      return {'currency': '€'};
    } catch (e) {
      print('Error loading user settings: $e');
      return {'currency': '€'};
    }
  }

  // Sharing Operations
  Future<void> shareList(String listName, String email) async {
    return shareListWithUser(listName, email);
  }

  Future<void> shareListWithUser(String listId, String targetEmail) async {
    if (currentUserId == null) throw Exception('Not authenticated');
    if (targetEmail == _auth.currentUser?.email) {
      throw Exception('Cannot share list with yourself');
    }

    try {
      if (!await checkShareRateLimit()) {
        throw Exception('Sharing rate limit exceeded. Please try again later.');
      }

      final userQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: targetEmail)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) throw Exception('User not found');

      final targetUserId = userQuery.docs.first.id;
      final batch = _firestore.batch();

      final listDoc = await _firestore
          .collection('lists')
          .doc(currentUserId)
          .collection('userLists')
          .doc(listId)
          .get();

      if (!listDoc.exists) throw Exception('List does not exist');

      final listData = listDoc.data()!;
      final sharedListId = '${currentUserId}_$listId';

      // Update original list
      batch.update(
          _listsCollection
              .doc(currentUserId)
              .collection('userLists')
              .doc(listId),
          {
            'sharedWith': FieldValue.arrayUnion([targetUserId]),
            'sharedWithEmails': FieldValue.arrayUnion([targetEmail]),
            'lastModified': FieldValue.serverTimestamp(),
          });

      // Create shared list
      batch.set(
          _listsCollection
              .doc(targetUserId)
              .collection('sharedLists')
              .doc(sharedListId),
          {
            'originalListId': listId,
            'ownerId': currentUserId,
            'ownerEmail': _auth.currentUser?.email,
            'name': listData['name'] ?? listId,
            'items': listData['items'] ?? [],
            'sharedWith': [targetUserId],
            'sharedAt': FieldValue.serverTimestamp(),
            'lastModified': FieldValue.serverTimestamp(),
          });

      await batch.commit();
    } catch (e) {
      print('Error sharing list: $e');
      throw Exception('Failed to share list: ${e.toString()}');
    }
  }

  Future<bool> checkShareRateLimit() async {
    if (currentUserId == null) return false;

    try {
      final rateLimitDoc =
          await _firestore.collection('rateLimit').doc(currentUserId).get();

      if (!rateLimitDoc.exists) {
        await _firestore.collection('rateLimit').doc(currentUserId).set({
          'shareCount': 1,
          'timestamp': FieldValue.serverTimestamp(),
        });
        return true;
      }

      final data = rateLimitDoc.data() as Map<String, dynamic>;
      final timestamp = (data['timestamp'] as Timestamp).toDate();
      final count = data['shareCount'] as int;

      if (DateTime.now().difference(timestamp) > const Duration(hours: 24)) {
        await _firestore.collection('rateLimit').doc(currentUserId).set({
          'shareCount': 1,
          'timestamp': FieldValue.serverTimestamp(),
        });
        return true;
      }

      if (count >= 50) return false;

      await _firestore.collection('rateLimit').doc(currentUserId).update({
        'shareCount': FieldValue.increment(1),
      });

      return true;
    } catch (e) {
      print('Error checking rate limit: $e');
      return false;
    }
  }

  Stream<List<Map<String, dynamic>>> getListStream(String listName) {
    if (currentUserId == null) {
      return Stream.value([]);
    }

    try {
      if (listName.contains('_')) {
        return _firestore
            .collection('lists')
            .doc(currentUserId)
            .collection('sharedLists')
            .doc(listName)
            .snapshots()
            .handleError((error) {
              print('Error in shared list stream: $error');
              return [];
            })
            .map((snapshot) {
              if (!snapshot.exists) return [];
              return List<Map<String, dynamic>>.from(snapshot.data()?['items'] ?? []);
            });
      }

      return _firestore
          .collection('lists')
          .doc(currentUserId)
          .collection('userLists')
          .doc(listName)
          .snapshots()
          .handleError((error) {
            print('Error in list stream: $error');
            return [];
          })
          .map((snapshot) {
            if (!snapshot.exists) return [];
            return List<Map<String, dynamic>>.from(snapshot.data()?['items'] ?? []);
          });
    } catch (e) {
      print('Error setting up list stream: $e');
      return Stream.value([]);
    }
  }

  Future<List<String>> getAllListNames() async {
    if (currentUserId == null) return [];

    try {
      final lists = <String>[];

      final ownedLists = await _firestore
          .collection('lists')
          .doc(currentUserId)
          .collection('userLists')
          .get();

      lists.addAll(ownedLists.docs.map((doc) => doc.id));

      final sharedLists = await _firestore
          .collection('lists')
          .doc(currentUserId)
          .collection('sharedLists')
          .get();

      lists.addAll(sharedLists.docs.map((doc) => doc.id));

      return lists;
    } catch (e) {
      print('Error getting list names: $e');
      return [];
    }
  }

  // Currency conversion helper
  double convertCurrency(String price, String fromCurrency, String toCurrency) {
    final numericPrice = double.parse(price.replaceAll(RegExp(r'[€$]'), ''));

    if (fromCurrency == toCurrency) return numericPrice;

    const eurToUsdRate = 1.18;

    if (fromCurrency == '\$' && toCurrency == '€') {
      return numericPrice / eurToUsdRate;
    } else if (fromCurrency == '€' && toCurrency == '\$') {
      return numericPrice * eurToUsdRate;
    }

    return numericPrice;
  }

  Future<void> updateSharedList(String ownerId, String listName, List<Map<String, dynamic>> items) async {
    try {
      // Einzelne Updates statt Batch
      // Update original list
      await _firestore
          .collection('lists')
          .doc(ownerId)
          .collection('userLists')
          .doc(listName)
          .update({
        'items': items,
        'lastModified': FieldValue.serverTimestamp(),
      });

      // Get shared users
      final originalListDoc = await _firestore
          .collection('lists')
          .doc(ownerId)
          .collection('userLists')
          .doc(listName)
          .get();

      if (originalListDoc.exists) {
        final sharedWithUsers = List<String>.from(originalListDoc.data()?['sharedWith'] ?? []);
        
        // Update shared copies sequentially
        for (final sharedUserId in sharedWithUsers) {
          await _firestore
              .collection('lists')
              .doc(sharedUserId)
              .collection('sharedLists')
              .doc('${ownerId}_$listName')
              .update({
            'items': items,
            'lastModified': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      print('Error updating shared list: $e');
      throw Exception('Failed to update shared list');
    }
  }

  Future<Map<String, String>?> getOriginalListInfo(String sharedListId) async {
    try {
      final sharedDoc = await _firestore
          .collection('lists')
          .doc(currentUserId)
          .collection('sharedLists')
          .doc(sharedListId)
          .get();

      if (sharedDoc.exists) {
        return {
          'ownerId': sharedDoc.data()?['ownerId'] ?? '',
          'originalListName': sharedDoc.data()?['originalListId'] ?? '',
        };
      }
      return null;
    } catch (e) {
      print('Error getting original list info: $e');
      return null;
    }
  }

  Stream<List<Map<String, dynamic>>> getSharedListsStream() {
    if (currentUserId == null) return Stream.value([]);

    return _listsCollection
        .doc(currentUserId)
        .collection('sharedLists')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'name': doc.id,
          'ownerEmail': data['ownerEmail'],
          'sharedAt': data['sharedAt'],
          'items': data['items'] ?? [],
        };
      }).toList();
    });
  }

  // Cleanup method for testing or user logout
  Future<void> cleanup() async {
    await clearNameCache();
  }
}
