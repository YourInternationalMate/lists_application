import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

// Custom list tile with animations, hover effects, and sliding actions
class MyListTile extends StatefulWidget {
  // Tile content and callback functions
  final String title;
  final GestureTapCallback? onTap;
  final Function(BuildContext)? deleteFunction;

  const MyListTile({
    super.key,
    required this.title,
    required this.onTap,
    required this.deleteFunction,
  });

  @override
  State<MyListTile> createState() => _MyListTileState();
}

// State class managing animations and interactions
class _MyListTileState extends State<MyListTile> 
    with SingleTickerProviderStateMixin {
  // Animation controllers and animations
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  
  // Track hover state
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    // Initialize main animation controller
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Configure scale animation for appearance
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    // Configure slide animation for entry
    _slideAnimation = Tween<Offset>(
      begin: const Offset(-1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    // Start initial animation
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FadeTransition(
          opacity: _controller,
          child: SlideTransition(
            position: _slideAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Padding(
                padding: const EdgeInsets.only(left: 25, right: 25, top: 25),
                child: MouseRegion(
                  onEnter: (_) => setState(() => _isHovered = true),
                  onExit: (_) => setState(() => _isHovered = false),
                  child: Slidable(
                    key: ValueKey(widget.title),
                    endActionPane: ActionPane(
                      motion: const ScrollMotion(),
                      dismissible: DismissiblePane(
                        onDismissed: () => widget.deleteFunction?.call(context),
                        closeOnCancel: true,
                      ),
                      extentRatio: 0.35,
                      children: [
                        _buildDeleteAction(context),
                      ],
                    ),
                    child: _buildTileContent(context),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Build delete action button with animation
  Widget _buildDeleteAction(BuildContext context) {
    return CustomSlidableAction(
      onPressed: widget.deleteFunction,
      backgroundColor: Colors.red.shade300,
      foregroundColor: Theme.of(context).colorScheme.onPrimary,
      borderRadius: const BorderRadius.horizontal(
        left: Radius.circular(12),
        right: Radius.circular(12),
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: 0.8 + (_controller.value * 0.2),
            child: Icon(
              Icons.delete,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          );
        },
      ),
    );
  }

  // Build main tile content with hover effects
  Widget _buildTileContent(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            if (_isHovered)
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          children: [
            // Title text with hover effect
            Expanded(
              child: Text(
                widget.title,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 18,
                  fontWeight: _isHovered ? FontWeight.bold : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            // Animated arrow indicator on hover
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _isHovered ? 1.0 : 0.0,
              child: Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}