import 'package:flutter/material.dart';

// Custom reorderable list view with scrolling behavior
class CustomReorderableListView extends StatelessWidget {
  // Builder function to create list items
  final IndexedWidgetBuilder itemBuilder;
  
  // Total number of items in the list
  final int itemCount;
  
  // Callback function when items are reordered
  final void Function(int, int) onReorder;

  const CustomReorderableListView({
    super.key,
    required this.itemBuilder,
    required this.itemCount,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      // Disable default drag handles for custom implementation
      buildDefaultDragHandles: false,
      
      // Use provided builder function for list items
      itemBuilder: itemBuilder,
      itemCount: itemCount,
      
      // Handle reordering with provided callback
      onReorder: onReorder,
      
      // Remove default drag animation decoration
      proxyDecorator: (child, index, animation) {
        return child; // Return unmodified child widget
      },
      
      // Use default scroll physics for natural scrolling
      physics: const AlwaysScrollableScrollPhysics(),
      
      // Add padding at the bottom for better UX
      padding: const EdgeInsets.only(bottom: 100),
    );
  }
}