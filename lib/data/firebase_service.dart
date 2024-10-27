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

  Future<List<Map<String, dynamic>>> loadListData(String listName) async {
    if (currentUserId == null) return [];
    
    final docSnapshot = await _listsCollection
        .doc(currentUserId)
        .collection('userLists')
        .doc(listName)
        .get();
    
    if (!docSnapshot.exists) return [];
    
    final data = docSnapshot.data() as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(data['items'] ?? []);
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

  // List Sharing Operations
  Future<void> shareList(String listName, String sharedWithEmail) async {
    if (currentUserId == null) return;
    
    // Get user ID from email
    final userQuery = await _firestore
        .collection('users')
        .where('email', isEqualTo: sharedWithEmail)
        .get();
    
    if (userQuery.docs.isEmpty) {
      throw Exception('User not found');
    }
    
    final sharedWithId = userQuery.docs.first.id;
    
    // Update the original list's shared users
    await _listsCollection
        .doc(currentUserId)
        .collection('userLists')
        .doc(listName)
        .update({
      'sharedWith': FieldValue.arrayUnion([sharedWithId])
    });
    
    // Create a reference in the shared user's lists
    await _listsCollection
        .doc(sharedWithId)
        .collection('sharedLists')
        .doc(listName)
        .set({
      'originalListId': listName,
      'ownerId': currentUserId,
      'sharedAt': FieldValue.serverTimestamp(),
    });
  }

  // Real-time List Updates
  Stream<List<Map<String, dynamic>>> getListStream(String listName) {
    if (currentUserId == null) return Stream.value([]);
    
    return _listsCollection
        .doc(currentUserId)
        .collection('userLists')
        .doc(listName)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return [];
      
      final data = snapshot.data() as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(data['items'] ?? []);
    });
  }

  // Get all lists (both owned and shared)
  Future<List<String>> getAllListNames() async {
    if (currentUserId == null) return [];
    
    // Get owned lists
    final ownedLists = await _listsCollection
        .doc(currentUserId)
        .collection('userLists')
        .get();
    
    // Get shared lists
    final sharedLists = await _listsCollection
        .doc(currentUserId)
        .collection('sharedLists')
        .get();
    
    final ownedListNames = ownedLists.docs.map((doc) => doc.id).toList();
    final sharedListNames = sharedLists.docs.map((doc) => doc.id).toList();
    
    return [...ownedListNames, ...sharedListNames];
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