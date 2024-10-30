import 'package:Lists/pages/auth_page.dart';
import 'package:Lists/util/categorie_filter.dart';
import 'package:Lists/util/my_button.dart';
import 'package:Lists/util/my_drawer.dart';
import 'package:Lists/util/my_reorderable_list_view.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:Lists/data/database.dart';
import 'package:Lists/util/data_tile.dart';
import 'package:Lists/util/shopping_tile.dart';
import 'package:Lists/util/dialog_box.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  // Database instance
  final ShoppingDataBase db = ShoppingDataBase();
  
  // Current state
  String currentListName = 'Default List';
  List<String> listNames = [];
  bool _isLoading = true;
  bool _mounted = true;
  
  // Controllers
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _linkController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late ScrollController _scrollController;
  
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late AnimationController _rotationController;
  
  // Animations
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  
  String _selectedCategory = 'All';
  
  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _setupAnimations();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    try {
      setState(() => _isLoading = true);
      
      await db.initialize();
      
      // Listen auf Auth-Änderungen
      FirebaseAuth.instance.authStateChanges().listen((User? user) {
        if (!_mounted) return;  // Early return wenn nicht mehr mounted
        if (user == null && mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const AuthScreen()),
          );
        }
      });

      // Lade initiale Daten
      if (_mounted) {  // Prüfe mounted status
        await initializeData();
      }
      
      // Setup real-time updates
      if (_mounted) {  // Prüfe mounted status
        db.listUpdates.listen(
          (updatedList) {
            if (_mounted && mounted) {  // Doppelte Prüfung
              setState(() {
                db.currentShoppingList = updatedList;
              });
            }
          },
          onError: (error) {
            print('Error in list updates: $error');
          },
        );
      }

    } catch (e) {
      print('Error in initialization: $e');
      if (_mounted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (_mounted && mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _mounted = false;
    db.dispose();
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

  Future<void> _initializeData() async {
    try {
      await initializeData();
      
      // Subscribe to real-time updates
      db.listUpdates.listen((updatedList) {
        if (mounted) {
          setState(() {
            db.currentShoppingList = updatedList;
          });
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleCurrencyChange(String newCurrency) async {
  try {
    await db.saveCurrency(newCurrency);
    setState(() {}); // Trigger rebuild to update the UI
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to change currency: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

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

  Future<void> initializeData() async {
    setState(() => _isLoading = true);

    try {
      final names = await db.getAllListNames();
      setState(() {
        listNames = names;
      });

      if (listNames.isEmpty) {
        await db.createNewList(currentListName);
        setState(() {
          listNames = [currentListName];
        });
      } else {
        setState(() {
          currentListName = listNames.first;
        });
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

  void onChangedCategory(String? newValue) {
    setState(() {
      _selectedCategory = newValue!;
      _fadeController.forward(from: 0.0);
    });
  }

  Future<void> createNewList() async {
    final TextEditingController listNameController = TextEditingController();

    final bool? shouldCreate = await showDialog<bool>(
      context: context,
      builder: (context) => _buildCreateListDialog(listNameController),
    );

    if (shouldCreate == true && listNameController.text.isNotEmpty) {
      setState(() {
        currentListName = listNameController.text;
      });
      await db.createNewList(currentListName);
      final names = await db.getAllListNames();
      setState(() {
        listNames = names;
      });

      _fadeController.forward(from: 0.0);
      _slideController.forward(from: 0.0);
      _scaleController.forward(from: 0.0);
    }
  }

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

      await db.addItem(currentListName, {
        'name': _nameController.text,
        'price': _priceController.text,
        'link': _linkController.text,
        'category': _selectedCategory
      });

      if (_scrollController.hasClients) {
        await _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }
  }

  Future<void> updateProduct(int index) async {
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

    await db.updateItem(currentListName, index, updatedItem);
  }

  Future<void> deleteProduct(int index) async {
    final deletedItem = Map<String, String>.from(db.currentShoppingList[index]);
    
    await db.deleteItem(currentListName, index);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Theme.of(context).colorScheme.secondary,
        content: Text(
          'Item deleted',
          style: TextStyle(color: Theme.of(context).colorScheme.onSecondary),
        ),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            db.currentShoppingList.insert(index, deletedItem);
            await db.updateDataBase(currentListName);
          },
        ),
      ),
    );
  }

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
          child: Icon(
            Icons.add,
            color: Theme.of(context).colorScheme.onSecondary,
          ),
        ),
      ),
      drawer: MyDrawer(
        listNames: listNames,
        currentListName: currentListName,
        onCreateNewList: createNewList,
        onListChange: (String selectedList) async {
          setState(() {
            currentListName = selectedList;
          });
          await db.loadData(currentListName);
        },
        onDeleteList: (String listName) async {
          await db.deleteList(listName);
          final names = await db.getAllListNames();
          setState(() {
            listNames = names;
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
        onCurrencyChange: _handleCurrencyChange,
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(top: 20, left: 25, right: 25),
      child: Row(
        children: [
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
                onReorder: (oldIndex, newIndex) async {
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
                    setState(() {
                      filteredList.removeAt(oldIndex);
                      filteredList.insert(newIndex, item);
                    });
                    await db.reorderItems(
                        currentListName, originalIndex, targetMainIndex);
                  }
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
                  color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.5),
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

  double get totalPrice {
    double sum = 0;
    for (var item in db.currentShoppingList) {
      String price = item['price'] ?? '0';
      String originalCurrency = price.contains('€') ? '€' : '\$';
      price = price.replaceAll(RegExp(r'[€$]'), '');

      double convertedPrice = db.convertCurrency(
        price,
        originalCurrency,
        db.currentCurrency,
      );

      sum += convertedPrice;
    }
    return sum;
  }

  List<Map<String, String>> get filteredList {
    if (_selectedCategory == 'All') {
      return List<Map<String, String>>.from(db.currentShoppingList);
    }
    return List<Map<String, String>>.from(db.currentShoppingList
        .where((item) => item['category'] == _selectedCategory));
  }
}