import 'package:hive/hive.dart';

class ShoppingDataBase {
  // List holding items for the current shopping list
  List<Map<String, String>> currentShoppingList = [];
  
  // Default currency for item prices
  String currentCurrency = '€';
  
  // Available categories for items
  List<String> categories = [
    'All',
    'Clothing',
    'Electronics',
    'Books',
    'Food',
    'Other'
  ];

  // Hive box for persistent data storage
  final _myBox = Hive.box('ListsBox');

  // Save selected currency to storage and update current currency
  void saveCurrency(String currency) {
    _myBox.put('currency', currency);
    currentCurrency = currency;
  }

  // Load saved currency from storage, using '€' if not set
  void loadCurrency() {
    currentCurrency = _myBox.get('currency', defaultValue: '€');
  }

  // Create a new shopping list if it doesn't already exist in storage
  void createNewList(String listName) {
    if (!_myBox.containsKey(listName)) {
      currentShoppingList = [];
      updateDataBase(listName);
    }
  }

  // Load items for the specified list from storage, handling potential errors
  Future<void> loadData(String listName) async {
    try {
      loadCurrency();  // Load currency setting
      
      if (_myBox.containsKey(listName)) {
        // Retrieve stored list, converting dynamic data to a Map<String, String>
        List<dynamic> dataList = _myBox.get(listName);
        
        currentShoppingList = List<Map<String, String>>.from(dataList.map((item) {
          if (item is Map<dynamic, dynamic>) {
            return Map<String, String>.from(item.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            ));
          }
          throw TypeError();  // Handle unexpected data format
        }));
      } else {
        // Initialize a new empty list if listName does not exist
        currentShoppingList = [];
        updateDataBase(listName);
      }
    } catch (e) {
      currentShoppingList = [];
      updateDataBase(listName);  // Ensure database consistency in case of errors
    }
  }

  // Save the current shopping list to storage under the specified list name
  void updateDataBase(String listName) {
    _myBox.put(listName, currentShoppingList);
  }

  // Convert price from one currency to another (currently supports € and $ conversions)
  double convertCurrency(String price, String fromCurrency, String toCurrency) {
    double numericPrice = double.parse(price);
    
    // If no conversion needed, return the original price
    if (fromCurrency == toCurrency) return numericPrice;
    
    // Sample conversion rate from USD to EUR
    const double usdToEurRate = 0.85;
    
    if (fromCurrency == '\$' && toCurrency == '€') {
      return numericPrice * usdToEurRate;
    } else if (fromCurrency == '€' && toCurrency == '\$') {
      return numericPrice / usdToEurRate;
    }
    
    return numericPrice;  // Return original if no recognized conversion
  }

  // Delete a shopping list from storage
  void deleteList(String listName) {
    if (_myBox.containsKey(listName)) {
      _myBox.delete(listName);
    }
  }

  // Retrieve all list names stored, excluding any settings keys
  List<String> getAllListNames() {
    return _myBox.keys.where((key) => key != 'currency').cast<String>().toList();
  }

  // Add a new item to the shopping list and update storage
  void addItem(String listName, Map<String, String> item) {
    currentShoppingList.add(item);
    updateDataBase(listName);
  }

  // Update an item at the given index and save changes to storage
  void updateItem(String listName, int index, Map<String, String> newItem) {
    if (index >= 0 && index < currentShoppingList.length) {
      currentShoppingList[index] = newItem;
      updateDataBase(listName);
    }
  }

  // Remove an item from the list at the specified index
  void deleteItem(String listName, int index) {
    if (index >= 0 && index < currentShoppingList.length) {
      currentShoppingList.removeAt(index);
      updateDataBase(listName);
    }
  }

  // Change the position of an item within the list and update storage
  void reorderItems(String listName, int oldIndex, int newIndex) {
    final item = currentShoppingList.removeAt(oldIndex);
    currentShoppingList.insert(newIndex, item);
    updateDataBase(listName);
  }
}