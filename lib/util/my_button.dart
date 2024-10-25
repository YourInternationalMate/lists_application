import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Custom button widget with animations, loading state, and customizable appearance
class MyButton extends StatefulWidget {
  // Button properties
  final String text;
  final VoidCallback onPressed;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? textColor;
  final IconData? icon;
  final double? width;
  final double? height;

  const MyButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.backgroundColor,
    this.textColor,
    this.icon,
    this.width,
    this.height,
  });

  @override
  State<MyButton> createState() => _MyButtonState();
}

// State class managing animations and interactions
class _MyButtonState extends State<MyButton> with SingleTickerProviderStateMixin {
  // Animation controller for press effect
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  
  // Interaction states
  bool _isPressed = false;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    // Initialize scale animation for press effect
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Handle press interaction states
  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _animationController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _animationController.reverse();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  if (_isHovered && !widget.isLoading)
                    BoxShadow(
                      color: (widget.backgroundColor ?? 
                          Theme.of(context).colorScheme.secondary)
                          .withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                ],
              ),
              child: GestureDetector(
                onTapDown: widget.isLoading ? null : _handleTapDown,
                onTapUp: widget.isLoading ? null : _handleTapUp,
                onTapCancel: _handleTapCancel,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeInOut,
                  child: ElevatedButton(
                    onPressed: widget.isLoading ? null : widget.onPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.backgroundColor ?? 
                          Theme.of(context).colorScheme.secondary,
                      foregroundColor: widget.textColor ?? 
                          Theme.of(context).colorScheme.onSecondary,
                      elevation: _isPressed ? 2 : (_isHovered ? 8 : 4),
                      shadowColor: (widget.backgroundColor ?? 
                          Theme.of(context).colorScheme.secondary)
                          .withOpacity(0.5),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 150),
                      child: widget.isLoading
                          ? _buildLoadingIndicator()
                          : _buildButtonContent(),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Build loading spinner widget
  Widget _buildLoadingIndicator() {
    return SizedBox(
      height: 20,
      width: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(
          widget.textColor ?? Theme.of(context).colorScheme.onSecondary,
        ),
      ),
    );
  }

  // Build button content with optional icon
  Widget _buildButtonContent() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(
            widget.icon,
            size: 18,
            color: widget.textColor ?? Theme.of(context).colorScheme.onSecondary,
          ),
          const SizedBox(width: 8),
        ],
        Text(
          widget.text,
          style: TextStyle(
            color: widget.textColor ?? Theme.of(context).colorScheme.onSecondary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  // Add diagnostic properties for debugging
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<bool>('isPressed', _isPressed));
    properties.add(DiagnosticsProperty<bool>('isHovered', _isHovered));
  }
}

// Custom splash factory for enhanced touch feedback
class CustomSplashFactory extends InteractiveInkFeatureFactory {
  @override
  InteractiveInkFeature create({
    required MaterialInkController controller,
    required RenderBox referenceBox,
    required Offset position,
    required Color color,
    required TextDirection textDirection,
    bool containedInkWell = false,
    RectCallback? rectCallback,
    BorderRadius? borderRadius,
    ShapeBorder? customBorder,
    double? radius,
    VoidCallback? onRemoved,
  }) {
    return CustomSplash(
      controller: controller,
      referenceBox: referenceBox,
      position: position,
      color: color,
      containedInkWell: containedInkWell,
      rectCallback: rectCallback,
      borderRadius: borderRadius,
      customBorder: customBorder,
      radius: radius,
      onRemoved: onRemoved,
      textDirection: textDirection,
    );
  }
}

// Custom splash animation implementation
class CustomSplash extends InteractiveInkFeature {
  final BorderRadius? borderRadius;
  @override
  final ShapeBorder? customBorder;
  final RectCallback? rectCallback;
  final double? radius;
  @override
  final Color color;
  final TextDirection textDirection;

  CustomSplash({
    required MaterialInkController controller,
    required super.referenceBox,
    required Offset position,
    required this.color,
    required this.textDirection,
    this.containedInkWell = false,
    this.rectCallback,
    this.borderRadius,
    this.customBorder,
    this.radius,
    super.onRemoved,
  }) : super(
          color: color,
          controller: controller,
        ) {
    // Initialize alpha animation for splash effect
    _alphaController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: controller.vsync,
    )..addListener(controller.markNeedsPaint);

    _alphaController.forward();
    _alphaAnimation = _alphaController.drive(Tween(begin: 0.0, end: color.alpha.toDouble()));

    controller.addInkFeature(this);
  }

  late final AnimationController _alphaController;
  late final Animation<double> _alphaAnimation;
  bool containedInkWell = false;

  // Handle splash confirmation
  @override
  void confirm() {
    _alphaController.forward();
  }

  // Handle splash cancellation
  @override
  void cancel() {
    _alphaController.reverse();
  }

  // Clean up resources
  @override
  void dispose() {
    _alphaController.dispose();
    super.dispose();
  }

  // Paint the splash effect
  @override
  void paintFeature(Canvas canvas, Matrix4 transform) {
    final Paint paint = Paint()..color = color.withAlpha(_alphaAnimation.value.toInt());
    final Offset center = referenceBox.size.center(Offset.zero);
    final double finalRadius = radius ?? referenceBox.size.width / 2;
    
    canvas.save();
    canvas.transform(transform.storage);
    
    if (customBorder != null || borderRadius != null) {
      final Rect rect = rectCallback?.call() ?? Offset.zero & referenceBox.size;
      final Path clipPath = Path();
      
      if (customBorder != null) {
        clipPath.addPath(
          customBorder!.getOuterPath(rect, textDirection: textDirection),
          Offset.zero,
        );
      } else if (borderRadius != null) {
        clipPath.addRRect(
          borderRadius!.toRRect(rect),
        );
      }
      
      canvas.clipPath(clipPath);
    }
    
    canvas.drawCircle(center, finalRadius * _alphaAnimation.value, paint);
    canvas.restore();
  }
}