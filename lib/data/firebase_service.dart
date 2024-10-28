import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  // Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection references
  late CollectionReference _listsCollection;
  late CollectionReference _userSettingsCollection;

  // Current user data
  String? get currentUserId => _auth.currentUser?.uid;

  FirebaseService() {
    _listsCollection = _firestore.collection('lists');
    _userSettingsCollection = _firestore.collection('userSettings');
  }

  // List Operations
  Future<void> createNewList(String listName) async {
  if (currentUserId == null) return;

  await _listsCollection
      .doc(currentUserId)
      .collection('userLists')
      .doc(listName)
      .set({
    'name': listName,  // Wichtig: Den Namen explizit speichern
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
        // Geteilte Liste direkt aus der sharedLists Collection laden
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
        // Normale Liste laden
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

  // In firebase_service.dart
  Future<void> deleteList(String listName) async {
    if (currentUserId == null) return;

    final batch = _firestore.batch();

    try {
      if (listName.contains('_')) {
        // Geteilte Liste - Lösche nur die Referenz
        final sharedListRef = _firestore
            .collection('lists')
            .doc(currentUserId)
            .collection('sharedLists')
            .doc(listName);

        batch.delete(sharedListRef);
      } else {
        // Eigene Liste - Lösche Liste und alle Sharing-Referenzen
        final listRef = _firestore
            .collection('lists')
            .doc(currentUserId)
            .collection('userLists')
            .doc(listName);

        final doc = await listRef.get();

        if (doc.exists) {
          final sharedWithIds =
              List<String>.from(doc.data()?['sharedWith'] ?? []);

          // Lösche Sharing-Referenzen
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
    if (currentUserId == null) return {'currency': '€'};

    final docSnapshot = await _userSettingsCollection.doc(currentUserId).get();

    if (!docSnapshot.exists) {
      return {'currency': '€'};
    }

    return docSnapshot.data() as Map<String, dynamic>;
  }

  // Sharing Operations
  Future<void> shareList(String listName, String email) async {
    return shareListWithUser(listName, email);
  }

  Future<void> shareListWithUser(String listId, String targetEmail) async {
  if (currentUserId == null) throw Exception('Not authenticated');
  if (targetEmail == _auth.currentUser?.email) throw Exception('Cannot share list with yourself');

  try {
    // Start a new batch operation
    final batch = _firestore.batch();

    // Check rate limit
    if (!await checkShareRateLimit()) {
      throw Exception('Sharing rate limit exceeded. Please try again later.');
    }

    // Get the target user
    final userQuery = await _firestore
        .collection('users')
        .where('email', isEqualTo: targetEmail)
        .limit(1)
        .get();

    if (userQuery.docs.isEmpty) {
      throw Exception('User not found');
    }

    final targetUserId = userQuery.docs.first.id;

    // Get the list document
    final listDoc = await _firestore
        .collection('lists')
        .doc(currentUserId)
        .collection('userLists')
        .doc(listId)
        .get();

    if (!listDoc.exists) {
      throw Exception('List does not exist');
    }

    // Reference to the original list
    final originalListRef = _firestore
        .collection('lists')
        .doc(currentUserId)
        .collection('userLists')
        .doc(listId);

    // Update the original list document with sharing information
    batch.update(originalListRef, {
      'sharedWith': FieldValue.arrayUnion([targetUserId]),
      'sharedWithEmails': FieldValue.arrayUnion([targetEmail]),
      'lastSharedAt': FieldValue.serverTimestamp(),
      'lastModified': FieldValue.serverTimestamp(),
      'owner': currentUserId,
    });

    // Create the shared list reference in target user's collection
    final sharedListId = '${currentUserId}_$listId';
    final sharedListRef = _firestore
        .collection('lists')
        .doc(targetUserId)
        .collection('sharedLists')
        .doc(sharedListId);

    // Get current list data
    final listData = listDoc.data()!;

    // Create shared list document with the correct name
    batch.set(sharedListRef, {
      'originalListId': listId,
      'ownerId': currentUserId,
      'ownerEmail': _auth.currentUser?.email,
      'name': listData['name'] ?? listId,  // Wichtig: Den Original-Namen übertragen
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

// Rate limiting helper function
Future<bool> checkShareRateLimit() async {
  if (currentUserId == null) return false;

  try {
    final rateLimitDoc = await _firestore
        .collection('rateLimit')
        .doc(currentUserId)
        .get();

    if (!rateLimitDoc.exists) {
      // First share of the day
      await _firestore
          .collection('rateLimit')
          .doc(currentUserId)
          .set({
        'shareCount': 1,
        'timestamp': FieldValue.serverTimestamp(),
      });
      return true;
    }

    final data = rateLimitDoc.data() as Map<String, dynamic>;
    final timestamp = (data['timestamp'] as Timestamp).toDate();
    final count = data['shareCount'] as int;

    // Reset if last share was more than 24h ago
    if (DateTime.now().difference(timestamp) > const Duration(hours: 24)) {
      await _firestore
          .collection('rateLimit')
          .doc(currentUserId)
          .set({
        'shareCount': 1,
        'timestamp': FieldValue.serverTimestamp(),
      });
      return true;
    }

    // Check if limit is reached (50 shares per 24h)
    if (count >= 50) {
      return false;
    }

    // Increment counter
    await _firestore
        .collection('rateLimit')
        .doc(currentUserId)
        .update({
      'shareCount': FieldValue.increment(1),
    });

    return true;
  } catch (e) {
    print('Error checking rate limit: $e');
    return false;
  }
}

  // Einmalig ausführen um bestehende Listen zu aktualisieren
Future<void> updateExistingLists() async {
  if (currentUserId == null) return;
  
  final lists = await _firestore
      .collection('lists')
      .doc(currentUserId)
      .collection('userLists')
      .get();
      
  final batch = _firestore.batch();
  
  for (var doc in lists.docs) {
    batch.set(doc.reference, {
      'owner': currentUserId,
      'sharedWith': [],
      'sharedWithEmails': [],
    }, SetOptions(merge: true));
  }
  
  await batch.commit();
}

  Future<void> unshareListWithUser(String listId, String targetEmail) async {
    if (currentUserId == null) throw Exception('Not authenticated');

    try {
      // Find target user
      final userQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: targetEmail)
          .get();

      if (userQuery.docs.isEmpty) {
        throw Exception('User not found');
      }

      final targetUserId = userQuery.docs.first.id;

      // Remove user from shared list
      await _firestore
          .collection('lists')
          .doc(currentUserId)
          .collection('userLists')
          .doc(listId)
          .update({
        'sharedWith': FieldValue.arrayRemove([targetUserId]),
        'sharedWithEmails': FieldValue.arrayRemove([targetEmail]),
      });

      // Delete shared list reference
      final sharedListId = '${currentUserId}_$listId';
      await _firestore
          .collection('lists')
          .doc(targetUserId)
          .collection('sharedLists')
          .doc(sharedListId)
          .delete();
    } catch (e) {
      print('Error unsharing list: $e');
      rethrow;
    }
  }

  Future<SharedListInfo?> getSharedListInfo(String listId) async {
    if (currentUserId == null) return null;

    try {
      final docSnapshot = await _firestore
          .collection('lists')
          .doc(currentUserId)
          .collection('userLists')
          .doc(listId)
          .get();

      if (!docSnapshot.exists) return null;

      final data = docSnapshot.data()!;
      final sharedWithEmails =
          List<String>.from(data['sharedWithEmails'] ?? []);

      return SharedListInfo(
        originalListId: listId,
        ownerEmail: _auth.currentUser?.email ?? '',
        ownerId: currentUserId!,
        sharedAt:
            (data['lastSharedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        sharedWithEmails: sharedWithEmails,
      );
    } catch (e) {
      print('Error getting shared list info: $e');
      return null;
    }
  }

  Stream<List<String>> sharedWithUpdates(String listId) {
    if (currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('lists')
        .doc(currentUserId)
        .collection('userLists')
        .doc(listId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return [];
      return List<String>.from(snapshot.data()?['sharedWithEmails'] ?? []);
    });
  }

  Future<String> getListDisplayName(String listId) async {
  if (currentUserId == null) return listId;

  try {
    if (listId.contains('_')) {
      // Wenn es eine geteilte Liste ist
      final sharedDoc = await _firestore
          .collection('lists')
          .doc(currentUserId)
          .collection('sharedLists')
          .doc(listId)
          .get();

      if (sharedDoc.exists) {
        // Erste Priorität: Name aus der sharedLists-Collection
        final name = sharedDoc.data()?['name'];
        if (name != null && name.toString().isNotEmpty) {
          return name;
        }

        // Zweite Priorität: Original-Liste nachschlagen
        final ownerId = sharedDoc.data()?['ownerId'];
        final originalListId = sharedDoc.data()?['originalListId'];
        if (ownerId != null && originalListId != null) {
          final originalDoc = await _firestore
              .collection('lists')
              .doc(ownerId)
              .collection('userLists')
              .doc(originalListId)
              .get();

          if (originalDoc.exists) {
            return originalDoc.data()?['name'] ?? listId;
          }
        }
      }
    } else {
      // Normale Liste
      final doc = await _firestore
          .collection('lists')
          .doc(currentUserId)
          .collection('userLists')
          .doc(listId)
          .get();

      if (doc.exists) {
        return doc.data()?['name'] ?? listId;
      }
    }
    return listId;
  } catch (e) {
    print('Error getting list display name: $e');
    return listId;
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

  Future<void> updateSharedList(String ownerId, String listName, List<Map<String, dynamic>> items) async {
  try {
    final batch = _firestore.batch();
    
    // Original List Reference
    final originalListRef = _firestore
        .collection('lists')
        .doc(ownerId)
        .collection('userLists')
        .doc(listName);

    // Update original list
    batch.update(originalListRef, {
      'items': items,
      'lastModified': FieldValue.serverTimestamp(),
    });

    // Get all users this list is shared with
    final originalListDoc = await originalListRef.get();
    if (!originalListDoc.exists) throw Exception('Original list not found');
    
    final sharedWithUsers = List<String>.from(originalListDoc.data()?['sharedWith'] ?? []);

    // Update all shared copies
    for (final sharedUserId in sharedWithUsers) {
      final sharedListRef = _firestore
          .collection('lists')
          .doc(sharedUserId)
          .collection('sharedLists')
          .doc('${ownerId}_$listName');

      batch.update(sharedListRef, {
        'items': items,
        'lastModified': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  } catch (e) {
    print('Error updating shared list: $e');
    throw Exception('Failed to update shared list');
  }
}

  Stream<List<Map<String, dynamic>>> getListStream(String listName) {
    if (currentUserId == null) {
      return Stream.value([]);
    }

    try {
      if (listName.contains('_')) {
        // Stream für geteilte Liste
        return _firestore
            .collection('lists')
            .doc(currentUserId)
            .collection('sharedLists')
            .doc(listName)
            .snapshots()
            .handleError((error) {
          print('Error in shared list stream: $error');
          return const [];
        }).map((snapshot) {
          if (!snapshot.exists) return [];
          return List<Map<String, dynamic>>.from(
              snapshot.data()?['items'] ?? []);
        });
      }

      // Stream für normale Liste
      return _firestore
          .collection('lists')
          .doc(currentUserId)
          .collection('userLists')
          .doc(listName)
          .snapshots()
          .handleError((error) {
        print('Error in list stream: $error');
        return const [];
      }).map((snapshot) {
        if (!snapshot.exists) return [];
        return List<Map<String, dynamic>>.from(snapshot.data()?['items'] ?? []);
      });
    } catch (e) {
      print('Error setting up list stream: $e');
      return Stream.value([]);
    }
  }

  // Get all list names including shared ones
  Future<List<String>> getAllListNames() async {
    if (currentUserId == null) return [];

    try {
      final lists = <String>[];

      // Get owned lists
      final ownedLists = await _firestore
          .collection('lists')
          .doc(currentUserId)
          .collection('userLists')
          .get();

      lists.addAll(ownedLists.docs.map((doc) => doc.id));

      // Get shared lists
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

  // Stream for shared lists
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
          'items': (data['listData'] as Map<String, dynamic>)['items'] ?? [],
        };
      }).toList();
    });
  }

  // Currency conversion helper (can be expanded later)
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
}
