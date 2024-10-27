import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
    
    await _listsCollection.doc(currentUserId).collection('userLists').doc(listName).set({
      'name': listName,
      'createdAt': FieldValue.serverTimestamp(),
      'items': [],
      'sharedWith': [],
      'owner': currentUserId,
    });
  }

  // Get list data for both owned and shared lists
  Future<List<Map<String, dynamic>>> loadListData(String listName) async {
    if (currentUserId == null) return [];
    
    try {
      // First check if this is a shared list
      if (listName.contains('_')) {
        final sharedDoc = await _firestore
            .collection('lists')
            .doc(currentUserId)
            .collection('sharedLists')
            .doc(listName)
            .get();
            
        if (sharedDoc.exists) {
          final originalPath = sharedDoc.data()?['originalListPath'] as String;
          final originalDoc = await _firestore.doc(originalPath).get();
          
          if (originalDoc.exists) {
            return List<Map<String, dynamic>>.from(
              originalDoc.data()?['items'] ?? []
            );
          }
        }
      }
      
      // If not shared or shared doc doesn't exist, load as normal
      final docSnapshot = await _firestore
          .collection('lists')
          .doc(currentUserId)
          .collection('userLists')
          .doc(listName)
          .get();
      
      if (!docSnapshot.exists) return [];
      
      return List<Map<String, dynamic>>.from(
        docSnapshot.data()?['items'] ?? []
      );
    } catch (e) {
      print('Error loading list data: $e');
      return [];
    }
  }


  Future<void> updateList(String listName, List<Map<String, dynamic>> items) async {
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
    
    await _listsCollection
        .doc(currentUserId)
        .collection('userLists')
        .doc(listName)
        .delete();
  }

  // User Settings Operations
  Future<void> saveUserSettings(Map<String, dynamic> settings) async {
    if (currentUserId == null) return;
    
    await _userSettingsCollection.doc(currentUserId).set(settings, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>> loadUserSettings() async {
    if (currentUserId == null) return {'currency': '€'};
    
    final docSnapshot = await _userSettingsCollection.doc(currentUserId).get();
    
    if (!docSnapshot.exists) {
      return {'currency': '€'};
    }
    
    return docSnapshot.data() as Map<String, dynamic>;
  }

  // Sharing-Logik
  Future<void> shareList(String listName, String email) async {
    if (currentUserId == null) return;
    
    try {
      final userQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .get();
      
      if (userQuery.docs.isEmpty) {
        throw Exception('User not found');
      }
      
      final sharedWithId = userQuery.docs.first.id;
      
      // Get the original list
      final listDoc = await _firestore
          .collection('lists')
          .doc(currentUserId)
          .collection('userLists')
          .doc(listName)
          .get();
      
      if (!listDoc.exists) {
        throw Exception('List not found');
      }

      // Update original list
      await _firestore
          .collection('lists')
          .doc(currentUserId)
          .collection('userLists')
          .doc(listName)
          .set({
        'sharedWith': FieldValue.arrayUnion([sharedWithId]),
        'owner': currentUserId,
        'displayName': listName,
      }, SetOptions(merge: true));

      // Create shared list reference
      await _firestore
          .collection('lists')
          .doc(sharedWithId)
          .collection('sharedLists')
          .doc('${currentUserId}_$listName')
          .set({
        'originalListId': listName,
        'originalListName': listName,
        'ownerId': currentUserId,
        'ownerEmail': _auth.currentUser?.email,
        'sharedAt': FieldValue.serverTimestamp(),
      });
      
    } catch (e) {
      print('Error sharing list: $e');
      rethrow;
    }
  }

  // Get all shared lists for current user
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

  // Remove sharing for a list
  Future<void> unshareList(String listName, String userId) async {
    if (currentUserId == null) return;
    
    try {
      // Remove user from shared list
      await _listsCollection
          .doc(currentUserId)
          .collection('userLists')
          .doc(listName)
          .update({
        'sharedWith': FieldValue.arrayRemove([userId])
      });
      
      // Remove shared list reference
      await _listsCollection
          .doc(userId)
          .collection('sharedLists')
          .doc(listName)
          .delete();
    } catch (e) {
      print('Error unsharing list: $e');
      rethrow;
    }
  }

  Future<bool> checkShareRateLimit() async {
    if (currentUserId == null) return false;
    
    try {
      final rateLimitDoc = await _firestore
          .collection('rateLimit')
          .doc(currentUserId)
          .get();
      
      if (!rateLimitDoc.exists) {
        // Erster Share des Tages
        await _firestore.collection('rateLimit').doc(currentUserId).set({
          'shareCount': 1,
          'timestamp': FieldValue.serverTimestamp(),
        });
        return true;
      }
      
      final data = rateLimitDoc.data() as Map<String, dynamic>;
      final timestamp = (data['timestamp'] as Timestamp).toDate();
      final count = data['shareCount'] as int;
      
      // Prüfe ob der letzte Share mehr als 24h her ist
      if (DateTime.now().difference(timestamp) > const Duration(hours: 24)) {
        // Reset Counter
        await _firestore.collection('rateLimit').doc(currentUserId).set({
          'shareCount': 1,
          'timestamp': FieldValue.serverTimestamp(),
        });
        return true;
      }
      
      // Prüfe ob das Limit erreicht ist
      if (count >= 50) return false;
      
      // Erhöhe Counter
      await _firestore.collection('rateLimit').doc(currentUserId).update({
        'shareCount': FieldValue.increment(1),
      });
      
      return true;
    } catch (e) {
      print('Error checking rate limit: $e');
      return false;
    }
  }

  Future<String> getListDisplayName(String listId) async {
    if (!listId.contains('_')) {
      return listId; // Normale Liste
    }

    try {
      final sharedDoc = await _firestore
          .collection('lists')
          .doc(currentUserId)
          .collection('sharedLists')
          .doc(listId)
          .get();

      if (sharedDoc.exists) {
        return sharedDoc.data()?['originalListName'] ?? listId;
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
          'ownerId': sharedDoc.data()?['ownerId'],
          'originalListName': sharedDoc.data()?['originalListId'],
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
      await _firestore
          .collection('lists')
          .doc(ownerId)
          .collection('userLists')
          .doc(listName)
          .update({
        'items': items,
        'lastModified': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating shared list: $e');
      throw Exception('Failed to update shared list');
    }
  }

  // Stream für List-Updates
  Stream<List<Map<String, dynamic>>> getListStream(String listName) {
    if (currentUserId == null) {
      return Stream.value([]);
    }

    try {
      // Check if this is a shared list
      if (listName.contains('_')) {
        final parts = listName.split('_');
        final originalOwnerId = parts[0];
        final originalListName = parts[1];
        
        return _firestore
            .collection('lists')
            .doc(originalOwnerId)
            .collection('userLists')
            .doc(originalListName)
            .snapshots()
            .map((snapshot) {
          if (!snapshot.exists) return [];
          return List<Map<String, dynamic>>.from(
            snapshot.data()?['items'] ?? []
          );
        });
      }
      
      // Normal list stream
      return _firestore
          .collection('lists')
          .doc(currentUserId)
          .collection('userLists')
          .doc(listName)
          .snapshots()
          .map((snapshot) {
        if (!snapshot.exists) return [];
        return List<Map<String, dynamic>>.from(
          snapshot.data()?['items'] ?? []
        );
      });
    } catch (e) {
      print('Error in list stream: $e');
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