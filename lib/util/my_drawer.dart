import 'package:lists_application/util/list_tile.dart';
import 'package:flutter/material.dart';

// Drawer widget with animated list items and currency selection
class MyDrawer extends StatefulWidget {
  // Properties for list management and currency settings
  final List<String> listNames;
  final VoidCallback onCreateNewList;
  final Function(String) onListChange;
  final Function(String) onDeleteList;
  final Function(String) onCurrencyChange;
  final String currentCurrency;

  const MyDrawer({
    super.key,
    required this.listNames,
    required this.onCreateNewList,
    required this.onListChange,
    required this.onDeleteList,
    required this.onCurrencyChange,
    required this.currentCurrency,
  });

  @override
  State<MyDrawer> createState() => _MyDrawerState();
}

// State class managing animations and scroll behavior
class _MyDrawerState extends State<MyDrawer> with SingleTickerProviderStateMixin {
  // Controllers for animations and scrolling
  late AnimationController _animationController;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    // Initialize animation controller for drawer content
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
          _buildCreateNewListButton(context),
        ],
      ),
    );
  }

  // Build animated drawer header
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
            child: DrawerHeader(
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
              child: Center(
                child: Text(
                  'Your Lists',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        );
      },
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
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        _buildCurrencyOption(context, '€'),
                        Container(
                          width: 1,
                          height: 24,
                          color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.2),
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

  // Build individual currency option with selection state
  Widget _buildCurrencyOption(BuildContext context, String currency) {
    final isSelected = widget.currentCurrency == currency;

    return InkWell(
      onTap: () => widget.onCurrencyChange(currency),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.secondary : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          currency,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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