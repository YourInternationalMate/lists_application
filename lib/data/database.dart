import 'dart:async';
import 'package:Lists/data/firebase_service.dart';

class ShoppingDataBase {
  // Private instance of FirebaseService
  late FirebaseService _firebase;
  bool _isInitialized = false;

  // Local cache of current data
  List<Map<String, String>> currentShoppingList = [];
  String currentCurrency = '€';
  Map<String, String> _listNameCache = {};

  // Stream controllers for real-time updates
  final _listUpdateController =
      StreamController<List<Map<String, String>>>.broadcast();
  Stream<List<Map<String, String>>> get listUpdates =>
      _listUpdateController.stream;

  // Stream controller for currency updates
  final _currencyController = StreamController<String>.broadcast();
  Stream<String> get currencyUpdates => _currencyController.stream;

  // Categories (could be moved to Firestore later)
  List<String> categories = [
    'All',
    'Clothing',
    'Electronics',
    'Books',
    'Food',
    'Other'
  ];

  // Initialize stream subscription for real-time updates
  StreamSubscription? _listSubscription;

  // Initialize Firebase Service
  Future<void> initialize() async {
    if (!_isInitialized) {
      _firebase = await FirebaseService.create();
      _isInitialized = true;
    }
  }

  // Load currency preference from user settings
  Future<void> loadCurrency() async {
    await _ensureInitialized();
    try {
      final settings = await _firebase.loadUserSettings();
      currentCurrency = settings['currency'] ?? '€';
    } catch (e) {
      print('Error loading currency: $e');
      currentCurrency = '€'; // Fallback to default
    }
  }

  // Save currency preference to user settings
  Future<void> saveCurrency(String currency) async {
    await _ensureInitialized();
    try {
      await _firebase.saveUserSettings({'currency': currency});
      currentCurrency = currency;
      _currencyController.add(currency);

      if (!_listUpdateController.isClosed) {
        _listUpdateController.add(currentShoppingList);
      }
    } catch (e) {
      print('Error saving currency: $e');
      throw Exception('Failed to save currency preference');
    }
  }

  // Create a new shopping list
  Future<void> createNewList(String listName) async {
    await _ensureInitialized();
    try {
      await _firebase.createNewList(listName);
      currentShoppingList = [];
      _subscribeToListUpdates(listName);
    } catch (e) {
      print('Error creating new list: $e');
      rethrow;
    }
  }

  // Load list data and subscribe to updates
  Future<void> loadData(String listName) async {
    await _ensureInitialized();
    try {
      await loadCurrency();

      final items = await _firebase.loadListData(listName);
      currentShoppingList = _convertToStringMap(items);

      await _listSubscription?.cancel();
      _subscribeToListUpdates(listName);
    } catch (e) {
      print('Error loading data: $e');
      currentShoppingList = [];
      throw Exception('Failed to load list data');
    }
  }

  // Subscribe to real-time updates for current list
  void _subscribeToListUpdates(String listName) {
    _listSubscription?.cancel();

    try {
      _listSubscription = _firebase.getListStream(listName).listen((items) {
        if (!_listUpdateController.isClosed) {
          currentShoppingList = _convertToStringMap(items);
          _listUpdateController.add(currentShoppingList);
        }
      }, onError: (error) {
        print('Error in list subscription: $error');
      });
    } catch (e) {
      print('Error setting up subscription: $e');
    }
  }

  // Convert dynamic maps to string maps
  List<Map<String, String>> _convertToStringMap(List<dynamic> items) {
    return items.map((item) {
      if (item is Map) {
        return Map<String, String>.from(item
            .map((key, value) => MapEntry(key.toString(), value.toString())));
      }
      return <String, String>{};
    }).toList();
  }

  Future<void> updateDataBase(String listId) async {
    await _ensureInitialized();
    try {
      if (!_listUpdateController.isClosed) {
      await _firebase.updateList(listId, currentShoppingList);
      }
    } catch (e) {
      print('Error updating database: $e');
      throw Exception('Failed to update list');
    }
  }

  // Get display name for a list
  Future<String> getListDisplayName(String listId) async {
    await _ensureInitialized();
    if (_listNameCache.containsKey(listId)) {
      return _listNameCache[listId]!;
    }

    try {
      final names = await _firebase.batchLoadListNames([listId]);
      final displayName = names[listId] ?? listId;
      _listNameCache[listId] = displayName;
      return displayName;
    } catch (e) {
      print('Error getting list name: $e');
      return listId;
    }
  }

  // Delete a list
  Future<void> deleteList(String listName) async {
    await _ensureInitialized();
    try {
      await _firebase.deleteList(listName);
      _listNameCache.remove(listName);
    } catch (e) {
      print('Error deleting list: $e');
      throw Exception('Failed to delete list');
    }
  }

  // Get all lists for current user
  Future<List<String>> getAllListNames() async {
    await _ensureInitialized();
    try {
      final listIds = await _firebase.getAllListNames();

      // Clear and update cache
      _listNameCache.clear();
      final names = await _firebase.batchLoadListNames(listIds);
      _listNameCache.addAll(names);

      return listIds;
    } catch (e) {
      print('Error getting list names: $e');
      return [];
    }
  }

  Future<void> addItem(String listId, Map<String, String> item) async {
    await _ensureInitialized();
    try {
      if (!item['price']!.contains('€') && !item['price']!.contains('\$')) {
        item['price'] = '${item['price']}$currentCurrency';
      }

      currentShoppingList.add(item);
      await updateDataBase(listId);
    } catch (e) {
      print('Error adding item: $e');
      throw Exception('Failed to add item');
    }
  }

  // Update existing item
  Future<void> updateItem(
      String listName, int index, Map<String, String> newItem) async {
    await _ensureInitialized();
    try {
      if (index >= 0 && index < currentShoppingList.length) {
        currentShoppingList[index] = newItem;
        await updateDataBase(listName);
      }
    } catch (e) {
      print('Error updating item: $e');
      throw Exception('Failed to update item');
    }
  }

  // Delete item from list
  Future<void> deleteItem(String listName, int index) async {
    await _ensureInitialized();
    try {
      if (index >= 0 && index < currentShoppingList.length) {
        currentShoppingList.removeAt(index);
        await updateDataBase(listName);
      }
    } catch (e) {
      print('Error deleting item: $e');
      throw Exception('Failed to delete item');
    }
  }

  // Reorder items in list
  Future<void> reorderItems(String listName, int oldIndex, int newIndex) async {
    await _ensureInitialized();
    try {
      final item = currentShoppingList.removeAt(oldIndex);
      currentShoppingList.insert(newIndex, item);
      await updateDataBase(listName);
    } catch (e) {
      print('Error reordering items: $e');
      throw Exception('Failed to reorder items');
    }
  }

  // Ensure Firebase Service is initialized
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  // Currency conversion helper
  double convertCurrency(String price, String fromCurrency, String toCurrency) {
    return _firebase.convertCurrency(price, fromCurrency, toCurrency);
  }

  // Cleanup resources
  void dispose() {
    _listSubscription?.cancel();
    _listUpdateController.close();
    _currencyController.close();
  }
}
