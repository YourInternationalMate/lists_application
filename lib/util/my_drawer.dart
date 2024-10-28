import 'package:Lists/util/list_tile.dart';
import 'package:Lists/util/share_list_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MyDrawer extends StatefulWidget {
  final List<String> listNames;
  final VoidCallback onCreateNewList;
  final Function(String) onListChange;
  final Function(String) onDeleteList;
  final Function(String) onCurrencyChange;
  final Function(String) onShareList;
  final String currentCurrency;
  final String currentListName;

  const MyDrawer({
    super.key,
    required this.listNames,
    required this.onCreateNewList,
    required this.onListChange,
    required this.onDeleteList,
    required this.onCurrencyChange,
    required this.onShareList,
    required this.currentCurrency,
    required this.currentListName,
  });

  @override
  State<MyDrawer> createState() => _MyDrawerState();
}

class _MyDrawerState extends State<MyDrawer> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late ScrollController _scrollController;
  final user = FirebaseAuth.instance.currentUser;
  bool _mounted = true;
  
  // Cache für Namen und geteilte Benutzer
  Map<String, String> _displayNameCache = {};
  Map<String, List<String>> _sharedUsersCache = {};
  bool _isLoadingNames = true;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _scrollController = ScrollController();
    _animationController.forward();
    
    // Initial Namen und geteilte Benutzer laden
    _loadDisplayNames();
    _loadSharedUsers(widget.currentListName);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    _mounted = false;
    super.dispose();
  }

  @override
  void didUpdateWidget(MyDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listNames != widget.listNames) {
      _loadDisplayNames();
    }
    if (oldWidget.currentListName != widget.currentListName) {
      _loadSharedUsers(widget.currentListName);
    }
  }

  // Lade alle Listennamen
  Future<void> _loadDisplayNames() async {
    if (!_mounted) return;
    
    setState(() => _isLoadingNames = true);
    
    try {
      final firestore = FirebaseFirestore.instance;
      final userId = FirebaseAuth.instance.currentUser?.uid;
      
      if (userId == null) return;

      for (String listId in widget.listNames) {
        if (!_mounted) return;

        if (listId.contains('_')) {
          // Geteilte Liste
          final sharedDoc = await firestore
              .collection('lists')
              .doc(userId)
              .collection('sharedLists')
              .doc(listId)
              .get();

          if (sharedDoc.exists) {
            final name = sharedDoc.data()?['name'];
            if (name != null && name.toString().isNotEmpty) {
              setState(() => _displayNameCache[listId] = name);
            }
          }
        } else {
          // Normale Liste
          final doc = await firestore
              .collection('lists')
              .doc(userId)
              .collection('userLists')
              .doc(listId)
              .get();

          if (doc.exists) {
            final name = doc.data()?['name'] ?? listId;
            setState(() => _displayNameCache[listId] = name);
          }
        }
      }
    } catch (e) {
      print('Error loading display names: $e');
    } finally {
      if (_mounted) {
        setState(() => _isLoadingNames = false);
      }
    }
  }

  // Lade geteilte Benutzer für eine Liste
  Future<void> _loadSharedUsers(String listName) async {
    if (!_mounted) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final docSnapshot = await FirebaseFirestore.instance
          .collection('lists')
          .doc(user.uid)
          .collection('userLists')
          .doc(listName)
          .get();

      if (!docSnapshot.exists || !_mounted) return;

      final data = docSnapshot.data();
      final List<String> sharedWithIds = List<String>.from(data?['sharedWith'] ?? []);
      
      final List<String> sharedEmails = [];
      for (String userId in sharedWithIds) {
        if (!_mounted) return;
        
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
            
        if (userDoc.exists) {
          final email = userDoc.data()?['email'] as String?;
          if (email != null) sharedEmails.add(email);
        }
      }

      if (_mounted) {
        setState(() {
          _sharedUsersCache[listName] = sharedEmails;
        });
      }
    } catch (e) {
      print('Error loading shared users: $e');
    }
  }

  // Handle user logout
  Future<void> _handleLogout() async {
    final navigator = Navigator.of(context);
    await FirebaseAuth.instance.signOut();
    navigator.pop(); // Close drawer
  }

  // Show enhanced share dialog
  void _showShareDialog(BuildContext context) async {
    // Stelle sicher, dass die geteilten Benutzer geladen sind
    await _loadSharedUsers(widget.currentListName);
    
    if (!mounted) return;
    
    Navigator.pop(context); // Close drawer
    
    showDialog(
      context: context,
      builder: (context) => ShareListDialog(
        listName: _displayNameCache[widget.currentListName] ?? widget.currentListName,
        onShare: _handleShare,
        currentlySharedWith: _sharedUsersCache[widget.currentListName],
      ),
    );
  }

  // Handle share action
  Future<void> _handleShare(String email) async {
    try {
      await widget.onShareList(email);
      // Aktualisiere Cache nach erfolgreichem Teilen
      await _loadSharedUsers(widget.currentListName);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          _buildDrawerHeader(context),
          _buildCurrencySelector(context),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: EdgeInsets.zero,
              children: _buildListTiles(),
            ),
          ),
          _buildBottomButtons(context),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final headerAnimation = CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeOut,
        );

        return Transform.translate(
          offset: Offset(-300 * (1 - headerAnimation.value), 0),
          child: Opacity(
            opacity: headerAnimation.value,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.shopping_cart,
                            size: 48,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Shopping Lists',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Signed in as:',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user?.email ?? 'Unknown User',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomButtons(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: Icon(
            Icons.share,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          title: Text(
            'Share Current List',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          trailing: _sharedUsersCache[widget.currentListName]?.isNotEmpty == true
              ? Badge(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  label: Text(
                    _sharedUsersCache[widget.currentListName]!.length.toString(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSecondary,
                    ),
                  ),
                )
              : null,
          onTap: () => _showShareDialog(context),
        ),
        ListTile(
          leading: Icon(
            Icons.add,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          title: Text(
            'Create New List',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          onTap: () {
            Navigator.pop(context);
            widget.onCreateNewList();
          },
        ),
        ListTile(
          leading: Icon(
            Icons.logout,
            color: Theme.of(context).colorScheme.error,
          ),
          title: Text(
            'Logout',
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          onTap: _handleLogout,
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildCurrencySelector(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final currencyAnimation = CurvedAnimation(
          parent: _animationController,
          curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
        );

        return Transform.translate(
          offset: Offset(-300 * (1 - currencyAnimation.value), 0),
          child: Opacity(
            opacity: currencyAnimation.value,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Currency',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        _buildCurrencyOption(context, '€'),
                        Container(
                          width: 1,
                          height: 24,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                        ),
                        _buildCurrencyOption(context, '\$'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCurrencyOption(BuildContext context, String currency) {
    final isSelected = widget.currentCurrency == currency;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => widget.onCurrencyChange(currency),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected 
                ? Theme.of(context).colorScheme.secondary
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            currency,
            style: TextStyle(
              color: isSelected
                  ? Theme.of(context).colorScheme.onSecondary
                  : Theme.of(context).colorScheme.onSurface,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildListTiles() {
    return widget.listNames.asMap().entries.map((entry) {
      final index = entry.key;
      final listId = entry.value;
      final displayName = _displayNameCache[listId] ?? listId;
      
      final Animation<double> animation = CurvedAnimation(
        parent: _animationController,
        curve: Interval(
          0.2 + (index / widget.listNames.length) * 0.5,
          0.2 + ((index + 1) / widget.listNames.length) * 0.5,
          curve: Curves.easeOutCubic,
        ),
      );

      return AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(300 * (1 - animation.value), 0),
            child: Opacity(
              opacity: animation.value,
              child: child,
            ),
          );
        },
        child: _isLoadingNames && !_displayNameCache.containsKey(listId)
            ? _buildLoadingTile()
            : MyListTile(
                title: displayName,
                onTap: () {
                  widget.onListChange(listId);
                  Navigator.pop(context);
                },
                deleteFunction: (context) {
                  _showDeleteConfirmation(context, listId);
                },
              ),
      );
    }).toList();
  }

  Widget _buildLoadingTile() {
    return Padding(
      padding: const EdgeInsets.only(left: 25, right: 25, top: 25),
      child: Container(
        height: 80,
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, String listName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          'Delete List',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${_displayNameCache[listName] ?? listName}"?',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              widget.onDeleteList(listName);
              Navigator.pop(context);  // Close dialog
              Navigator.pop(context);  // Close drawer
            },
            child: Text(
              'Delete',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 24,
      ),
    );
  }

  // Helper method to check if a list is shared
  bool _isListShared(String listName) {
    return _sharedUsersCache[listName]?.isNotEmpty ?? false;
  }
}