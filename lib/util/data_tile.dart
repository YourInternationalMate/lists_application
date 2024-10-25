import 'package:flutter/material.dart';

// Widget for displaying animated data with hover effects and transitions
class DataTile extends StatefulWidget {
  // Data to be displayed in the tile
  final String data;
  
  const DataTile({super.key, required this.data});

  @override
  State<DataTile> createState() => _DataTileState();
}

// State class managing animations and interactions
class _DataTileState extends State<DataTile> with SingleTickerProviderStateMixin {
  // Animation controller for coordinating multiple animations
  late AnimationController _controller;
  
  // Fade animation for text transitions
  late Animation<double> _opacityAnimation;
  
  // Scale animation for bounce effect
  late Animation<double> _bounceAnimation;
  
  // Store previous data for smooth transitions
  String? _previousData;
  
  // Track hover state for interaction effects
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    // Initialize main animation controller
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    // Configure fade animation for text
    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
    ));

    // Configure bounce animation sequence
    _bounceAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.2),
        weight: 1.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 1.0),
        weight: 1.0,
      ),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.6, 1.0, curve: Curves.easeInOut),
    ));

    // Start initial animation
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Handle data updates with animation
  @override
  void didUpdateWidget(DataTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _previousData = oldWidget.data;
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Responsive width calculation
    final screenWidth = MediaQuery.of(context).size.width;
    final tileWidth = screenWidth < 360 ? 120.0 : 140.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _bounceAnimation.value,
            child: Container(
              // Outer container with hover shadow
              decoration: BoxDecoration(
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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  color: Theme.of(context).colorScheme.primary,
                  height: 60,
                  width: tileWidth,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Previous data with fade out animation
                      if (_previousData != null)
                        Opacity(
                          opacity: 1 - _opacityAnimation.value,
                          child: Transform.translate(
                            offset: Offset(0, 20 * _opacityAnimation.value),
                            child: _buildDataText(_previousData!),
                          ),
                        ),
                      // New data with fade in animation
                      Opacity(
                        opacity: _opacityAnimation.value,
                        child: Transform.translate(
                          offset: Offset(0, -20 * (1 - _opacityAnimation.value)),
                          child: _buildDataText(widget.data),
                        ),
                      ),
                      // Hover ripple effect
                      if (_isHovered) _buildRippleEffect(),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Build text display with consistent styling
  Widget _buildDataText(String text) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(
            text,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ),
    );
  }

  // Build animated hover ripple effect
  Widget _buildRippleEffect() {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                Theme.of(context).colorScheme.primary.withOpacity(0.2 * value),
                Colors.transparent,
              ],
              center: Alignment.center,
              radius: 1.5 * value,
            ),
          ),
        );
      },
    );
  }
}