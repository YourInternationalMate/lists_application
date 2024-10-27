import 'package:Lists/util/list_tile.dart';
import 'package:Lists/util/share_list_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _scrollController = ScrollController();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Handle user logout
  Future<void> _handleLogout() async {
    final navigator = Navigator.of(context);
    await FirebaseAuth.instance.signOut();
    navigator.pop(); // Close drawer
  }

  // Show share dialog
  void _showShareDialog() {
    Navigator.pop(context); // Close drawer
    showDialog(
      context: context,
      builder: (context) => ShareListDialog(
        listName: widget.currentListName,
        onShare: widget.onShareList,
      ),
    );
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
                  // App Icon und Titel
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
                  // Email und Währungsauswahl
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Email Anzeige
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
          onTap: _showShareDialog,
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

  // Build currency selector with animation
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
                : Theme.of(context).colorScheme.onPrimary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    ),
  );
}

  // Build animated list tiles for each shopping list
  List<Widget> _buildListTiles() {
    return widget.listNames.asMap().entries.map((entry) {
      final index = entry.key;
      final listName = entry.value;
      
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
        child: MyListTile(
          title: listName,
          onTap: () {
            widget.onListChange(listName);
            Navigator.pop(context);
          },
          deleteFunction: (context) {
            _showDeleteConfirmation(context, listName);
          },
        ),
      );
    }).toList();
  }

  // Build animated create new list button
  Widget _buildCreateNewListButton(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final buttonAnimation = CurvedAnimation(
          parent: _animationController,
          curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
        );

        return Transform.translate(
          offset: Offset(0, 50 * (1 - buttonAnimation.value)),
          child: Opacity(
            opacity: buttonAnimation.value,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: ListTile(
                leading: Icon(
                  Icons.add,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
                title: Text(
                  'Create New List',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  widget.onCreateNewList();
                },
                hoverColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              ),
            ),
          ),
        );
      },
    );
  }

  // Show delete confirmation dialog
  void _showDeleteConfirmation(BuildContext context, String listName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          'Delete List',
          style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
        ),
        content: Text(
          'Are you sure you want to delete "$listName"?',
          style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
            ),
          ),
          TextButton(
            onPressed: () {
              widget.onDeleteList(listName);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}