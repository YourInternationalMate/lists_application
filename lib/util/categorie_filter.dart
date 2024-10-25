// Widget for filtering items by category with animated chips
import 'package:flutter/material.dart';

// Stateful widget to manage category selection and animations
class CategoryFilter extends StatefulWidget {
  // Currently selected category
  final String selectedCategory;
  
  // Callback function when category changes
  final Function(String) onCategoryChanged;
  
  // List of available categories
  final List<String> categories;

  const CategoryFilter({
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.categories,
    super.key,
  });

  @override
  State<CategoryFilter> createState() => _CategoryFilterState();
}

// State class with animation capabilities
class _CategoryFilterState extends State<CategoryFilter> with SingleTickerProviderStateMixin {
  // Controller for horizontal scrolling of categories
  late ScrollController _scrollController;
  
  // Controller for entry animations
  late AnimationController _animationController;
  
  @override
  void initState() {
    super.initState();
    // Initialize scroll controller for horizontal scrolling
    _scrollController = ScrollController();
    
    // Setup animation controller for staggered entry
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _animationController.forward();  // Start entry animation
  }

  @override
  void dispose() {
    // Clean up controllers
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Automatically scroll to make selected category visible
  void _scrollToSelected() {
    final index = widget.categories.indexOf(widget.selectedCategory);
    if (index != -1) {
      final itemOffset = index * 90.0;  // Estimated width of each category chip
      _scrollController.animateTo(
        itemOffset.clamp(0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,  // Fixed height for category filter
      child: ShaderMask(
        // Gradient mask for fade effect at edges
        shaderCallback: (Rect bounds) {
          return LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.white,                    // Solid at edges
              Colors.white.withOpacity(0.1),   // Fade in
              Colors.white.withOpacity(0.1),   // Fade in
              Colors.white,                    // Solid at edges
            ],
            stops: const [0.0, 0.1, 0.9, 1.0],
          ).createShader(bounds);
        },
        blendMode: BlendMode.dstOut,
        child: ListView.builder(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          itemCount: widget.categories.length,
          itemBuilder: (context, index) {
            bool isSelected = widget.selectedCategory == widget.categories[index];
            
            // Staggered animation timing based on index
            final double delayFactor = index / widget.categories.length;
            final Animation<double> animation = CurvedAnimation(
              parent: _animationController,
              curve: Interval(
                delayFactor * 0.5,
                (delayFactor * 0.5) + 0.5,
                curve: Curves.easeOutBack,
              ),
            );

            return AnimatedBuilder(
              animation: animation,
              builder: (context, child) {
                // Slide up and fade in animation
                return Transform.translate(
                  offset: Offset(0, 50 * (1 - animation.value)),
                  child: Opacity(
                    opacity: animation.value.clamp(0.0, 1.0),
                    child: child,
                  ),
                );
              },
              child: Padding(
                // Dynamic padding based on position
                padding: EdgeInsets.only(
                  left: index == 0 ? 0 : 8.0,
                  right: index == widget.categories.length - 1 ? 0 : 8.0,
                ),
                child: FilterChip(
                  labelPadding: const EdgeInsets.symmetric(horizontal: 8.0),
                  selectedColor: Theme.of(context).colorScheme.secondary,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  elevation: isSelected ? 4 : 0,
                  label: Text(
                    widget.categories[index],
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (_) {
                    widget.onCategoryChanged(widget.categories[index]);
                    // Ensure selected category is visible after selection
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _scrollToSelected();
                    });
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}