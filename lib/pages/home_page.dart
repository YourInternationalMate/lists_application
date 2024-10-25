// Required package imports for the shopping list application
import 'package:Lists/util/categorie_filter.dart';
import 'package:Lists/util/my_button.dart';
import 'package:Lists/util/my_drawer.dart';
import 'package:Lists/util/my_reorderable_list_view.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:Lists/data/database.dart';
import 'package:Lists/util/data_tile.dart';
import 'package:Lists/util/shopping_tile.dart';
import 'package:Lists/util/dialog_box.dart';

// Main stateful widget for the shopping list home screen
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

// State class for HomePage that manages UI state and animations
class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  // Database instance for storing shopping list data
  final _myBox = Hive.box('ListsBox');

  // Database handler for shopping list operations
  ShoppingDataBase db = ShoppingDataBase();

  // Name of the currently active shopping list
  String currentListName = 'Default List';

  // List of all available shopping list names
  late List<String> listNames;

  // Loading state indicator for async operations
  bool _isLoading = true;

  // Text controllers for managing product input fields
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _linkController = TextEditingController();

  // Key for accessing scaffold state and managing drawer
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Controller for managing list scrolling behavior
  late ScrollController _scrollController;

  // Animation controllers for various UI animations
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late AnimationController _rotationController;

  // Animation definitions for UI elements
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  // Currently selected category filter
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _setupAnimations();
    initializeData();
  }

  // Initialize all required controllers for the application
  void _initializeControllers() {
    _scrollController = ScrollController();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _rotationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
  }

  // Set up animations with their curves and initial states
  void _setupAnimations() {
    _slideAnimation = Tween<Offset>(
      begin: const Offset(-1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOutBack,
    );

    _fadeController.forward();
    _slideController.forward();
    _scaleController.forward();
  }

  // Load initial data and set up the default list if needed
  Future<void> initializeData() async {
    setState(() => _isLoading = true);

    try {
      listNames = db.getAllListNames();

      if (listNames.isEmpty) {
        db.createNewList(currentListName);
        listNames = [currentListName];
      } else {
        currentListName = listNames.first;
      }

      await db.loadData(currentListName);

      _fadeController.forward();
      _slideController.forward();
      _scaleController.forward();
    } catch (e) {
      _showError('Error initializing data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Display error message with retry option
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red,
        action: SnackBarAction(
          label: 'Retry',
          onPressed: initializeData,
          textColor: Colors.white,
        ),
      ),
    );
  }

  // Handle category filter changes
  void onChangedCategory(String? newValue) {
    setState(() {
      _selectedCategory = newValue!;
      _fadeController.forward(from: 0.0);
    });
  }

  // Display dialog and handle creation of new shopping list
  Future<void> createNewList() async {
    final TextEditingController listNameController = TextEditingController();

    final bool? shouldCreate = await showDialog<bool>(
      context: context,
      builder: (context) => _buildCreateListDialog(listNameController),
    );

    if (shouldCreate == true && listNameController.text.isNotEmpty) {
      setState(() {
        currentListName = listNameController.text;
        db.createNewList(currentListName);
        listNames = db.getAllListNames();
      });

      _fadeController.forward(from: 0.0);
      _slideController.forward(from: 0.0);
      _scaleController.forward(from: 0.0);
    }
  }

  // Display dialog for creating new product and handle its addition
  Future<void> createNewProduct() async {
    _nameController.clear();
    _priceController.clear();
    _linkController.clear();

    final bool? shouldCreate = await showDialog<bool>(
      context: context,
      builder: (context) => DialogBox(
        nameController: _nameController,
        priceController: _priceController,
        linkController: _linkController,
        onChangedCategory: onChangedCategory,
        onSave: () => Navigator.of(context).pop(true),
        categories: db.categories,
        selectedCategory: _selectedCategory,
        onCancel: () => Navigator.of(context).pop(false),
      ),
    );

    if (shouldCreate == true) {
      if (_nameController.text.isEmpty || _priceController.text.isEmpty) return;

      setState(() {
        db.addItem(currentListName, {
          'name': _nameController.text,
          'price': _priceController.text,
          'link': _linkController.text,
          'category': _selectedCategory
        });
      });

      await _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 100,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // Update existing product with new information
  void updateProduct(int index) {
    setState(() {
      Map<String, String> updatedItem = {};

      updatedItem['name'] = _nameController.text.isNotEmpty
          ? _nameController.text
          : db.currentShoppingList[index]['name'] ?? '';

      updatedItem['price'] = _priceController.text.isNotEmpty
          ? _priceController.text
          : db.currentShoppingList[index]['price'] ?? '';

      updatedItem['link'] = _linkController.text.isNotEmpty
          ? _linkController.text
          : db.currentShoppingList[index]['link'] ?? '';

      updatedItem['category'] = _selectedCategory;

      db.updateItem(currentListName, index, updatedItem);
    });
  }

  // Delete product with undo functionality
  Future<void> deleteProduct(int index) async {
    final deletedItem = Map<String, String>.from(db.currentShoppingList[index]);

    setState(() {
      db.deleteItem(currentListName, index);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Theme.of(context).colorScheme.secondary,
        content: Text(
          'Item deleted',
          style: TextStyle(color: Theme.of(context).colorScheme.onSecondary),
        ),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            setState(() {
              db.currentShoppingList.insert(index, deletedItem);
              db.updateDataBase(currentListName);
            });
          },
        ),
      ),
    );
  }

  // Clean up resources when widget is disposed
  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    _rotationController.dispose();
    _scrollController.dispose();
    _nameController.dispose();
    _priceController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  // Build main app scaffold with drawer and content
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Theme.of(context).colorScheme.surface,
      floatingActionButton: ScaleTransition(
        scale: _scaleAnimation,
        child: FloatingActionButton(
          backgroundColor: Theme.of(context).colorScheme.secondary,
          onPressed: createNewProduct,
          child:
              Icon(Icons.add, color: Theme.of(context).colorScheme.onSecondary),
        ),
      ),
      drawer: MyDrawer(
        listNames: listNames,
        onCreateNewList: createNewList,
        onListChange: (String selectedList) {
          setState(() {
            currentListName = selectedList;
            db.loadData(currentListName);
          });
        },
        onDeleteList: (String listName) {
          setState(() {
            db.deleteList(listName);
            listNames = db.getAllListNames();

            if (currentListName == listName) {
              if (listNames.isNotEmpty) {
                currentListName = listNames.first;
                db.loadData(currentListName);
              } else {
                currentListName = 'Default List';
                db.createNewList(currentListName);
                listNames = [currentListName];
              }
            }
          });
        },
        onCurrencyChange: (String newCurrency) {
          setState(() {
            db.saveCurrency(newCurrency);
            _scaleController.forward(from: 0.8);
          });
        },
        currentCurrency: db.currentCurrency,
      ),
      body: SafeArea(
        child: _isLoading
            ? _buildLoadingState()
            : Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  _buildCategoryFilter(),
                  const SizedBox(height: 10),
                  _buildShoppingList(),
                ],
              ),
      ),
    );
  }

  // Build header section with menu and data tiles
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(top: 20, left: 25, right: 25),
      child: Row(
        children: [
          // Menu button with rotation animation
          SizedBox(
            width: 48,
            child: IconButton(
              icon: AnimatedBuilder(
                animation: _slideController,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _slideController.value * 0.5,
                    child: Icon(
                      Icons.menu,
                      color: Theme.of(context).colorScheme.onPrimary,
                      size: 28,
                    ),
                  );
                },
              ),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              splashRadius: 24,
              tooltip: 'Open menu',
            ),
          ),

          // Data tiles showing list statistics
          Expanded(
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 140),
                      child: DataTile(
                        data: db.currentShoppingList.length.toString(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 140),
                      child: DataTile(
                        data:
                            '${totalPrice.toStringAsFixed(2)}${db.currentCurrency}',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 48),
        ],
      ),
    );
  }

  // Build category filter section with animation
  Widget _buildCategoryFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25.0),
      child: SlideTransition(
        position: _slideAnimation,
        child: CategoryFilter(
          selectedCategory: _selectedCategory,
          onCategoryChanged: onChangedCategory,
          categories: [...db.categories],
        ),
      ),
    );
  }

  // Build main shopping list view with reordering support
  Widget _buildShoppingList() {
    return Expanded(
      child: filteredList.isEmpty
          ? _buildEmptyState()
          : Theme(
              data: Theme.of(context).copyWith(
                canvasColor: Colors.transparent,
                pageTransitionsTheme: const PageTransitionsTheme(
                  builders: {
                    TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
                    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                  },
                ),
              ),
              child: CustomReorderableListView(
                itemCount: filteredList.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    final item = filteredList[oldIndex];

                    final originalIndex = db.currentShoppingList.indexWhere(
                        (element) =>
                            element['name'] == item['name'] &&
                            element['price'] == item['price'] &&
                            element['link'] == item['link']);

                    if (newIndex > oldIndex) {
                      newIndex = newIndex - 1;
                    }

                    List<int> mainListIndices = [];
                    for (var filteredItem in filteredList) {
                      int index = db.currentShoppingList.indexWhere((element) =>
                          element['name'] == filteredItem['name'] &&
                          element['price'] == filteredItem['price'] &&
                          element['link'] == filteredItem['link']);
                      if (index != -1) {
                        mainListIndices.add(index);
                      }
                    }

                    int targetMainIndex;
                    if (newIndex >= mainListIndices.length) {
                      targetMainIndex = mainListIndices.last;
                    } else {
                      targetMainIndex = mainListIndices[newIndex];
                    }

                    if (originalIndex != -1) {
                      filteredList.removeAt(oldIndex);
                      filteredList.insert(newIndex, item);
                      db.reorderItems(
                          currentListName, originalIndex, targetMainIndex);
                    }
                  });
                },
                itemBuilder: (context, index) {
                  final item = filteredList[index];
                  return ShoppingTile(
                    key: ValueKey('${item['name']}_${item['price']}_$index'),
                    productName: item['name'] ?? '',
                    productPrice: item['price'] ?? '',
                    productLink: item['link'] ?? '',
                    currency: db.currentCurrency,
                    nameController: _nameController,
                    priceController: _priceController,
                    linkController: _linkController,
                    categories: db.categories,
                    selectedCategory: _selectedCategory,
                    onChangedCategory: onChangedCategory,
                    deleteFunction: (context) {
                      final originalIndex = db.currentShoppingList.indexWhere(
                          (element) =>
                              element['name'] == item['name'] &&
                              element['price'] == item['price'] &&
                              element['link'] == item['link']);
                      if (originalIndex != -1) {
                        deleteProduct(originalIndex);
                      }
                    },
                    editFunction: (context) {
                      final originalIndex = db.currentShoppingList.indexWhere(
                          (element) =>
                              element['name'] == item['name'] &&
                              element['price'] == item['price'] &&
                              element['link'] == item['link']);
                      if (originalIndex != -1) {
                        updateProduct(originalIndex);
                      }
                    },
                    index: index,
                  );
                },
              ),
            ),
    );
  }

  // Build loading spinner state
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Theme.of(context).colorScheme.secondary,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading your lists...',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // Build empty state placeholder
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            "No Items Yet",
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Tap the + button to add items",
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  // Build create list dialog with animation
  Widget _buildCreateListDialog(TextEditingController controller) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            title: Text(
              'Create New List',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
            content: TextField(
              controller: controller,
              autofocus: true,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Enter list name',
                hintStyle: TextStyle(
                  color:
                      Theme.of(context).colorScheme.onPrimary.withOpacity(0.5),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.secondary,
                    width: 2,
                  ),
                ),
              ),
            ),
            actions: [
              MyButton(
                text: "Cancel",
                onPressed: () => Navigator.pop(context, false),
              ),
              MyButton(
                text: "Create",
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
        );
      },
    );
  }

  // Calculate total price of all items in current list
  double get totalPrice {
    double sum = 0;
    for (var item in db.currentShoppingList) {
      // Extract original currency from price
      String price = item['price'] ?? '0';
      String originalCurrency = price.contains('€') ? '€' : '\$';
      price = price.replaceAll(RegExp(r'[€$]'), '');

      // Convert price to current currency
      double convertedPrice = db.convertCurrency(
        price,
        originalCurrency,
        db.currentCurrency,
      );

      sum += convertedPrice;
    }
    return sum;
  }

  // Get filtered list based on selected category
  List<Map<String, String>> get filteredList {
    if (_selectedCategory == 'All') {
      return List<Map<String, String>>.from(db.currentShoppingList);
    }
    return List<Map<String, String>>.from(db.currentShoppingList
        .where((item) => item['category'] == _selectedCategory));
  }
}
