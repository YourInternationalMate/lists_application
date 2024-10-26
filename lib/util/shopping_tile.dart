import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:Lists/util/dialog_box.dart';
import 'package:url_launcher/url_launcher.dart';

// Interactive shopping list item with animations and slidable actions
class ShoppingTile extends StatefulWidget {
  // Item properties
  final String productName;
  final String productPrice;
  final String productLink;
  final String currency;
  
  // Controllers for editing
  final TextEditingController nameController;
  final TextEditingController priceController;
  final TextEditingController linkController;
  
  // Category management
  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String?> onChangedCategory;
  
  // Item management
  final int index;
  final Function(BuildContext)? deleteFunction;
  final Function(BuildContext)? editFunction;

  const ShoppingTile({
    super.key,
    required this.productName,
    required this.productPrice,
    required this.productLink,
    required this.currency,
    required this.nameController,
    required this.priceController,
    required this.linkController,
    required this.categories,
    required this.selectedCategory,
    required this.index,
    required this.deleteFunction,
    required this.editFunction,
    required this.onChangedCategory,
  });

  @override
  State<ShoppingTile> createState() => _ShoppingTileState();
}

class _ShoppingTileState extends State<ShoppingTile>
    with SingleTickerProviderStateMixin {
  // Animation controllers and animations
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _opacityAnimation;
  
  // State tracking
  bool _isHovered = false;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    // Initialize animation controller
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    // Setup scale animation for appearance
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
    ));

    // Setup slide animation for entry
    _slideAnimation = Tween<double>(
      begin: 100.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
    ));

    // Setup opacity animation for fade in
    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Handle URL launching for product link
  Future<void> _launchUrl(BuildContext context) async {
  String urlString = widget.productLink.trim();
  
  // Füge http:// hinzu, wenn kein Protokoll angegeben ist
  if (!urlString.startsWith('http://') && !urlString.startsWith('https://')) {
    urlString = 'https://$urlString';
  }
  
  try {
    final Uri url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(
        url,
        mode: LaunchMode.externalApplication,  // Öffnet im externen Browser
      );
    } else {
      _showError(context, 'Could not open link: Invalid URL');
    }
  } catch (e) {
    _showError(context, 'Could not open link: ${e.toString()}');
  }
}

  // Display error when URL launch fails
  void _showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.red,
      duration: const Duration(seconds: 3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      action: SnackBarAction(
        label: 'OK',
        textColor: Colors.white,
        onPressed: () {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        },
      ),
    ),
  );
}

  // Format price with currency conversion
  String _formatPrice() {
    String price = widget.productPrice.replaceAll(RegExp(r'[€$]'), '');
    String originalCurrency = widget.productPrice.contains('€') ? '€' : '\$';
    
    if (originalCurrency == widget.currency) {
      return '${double.parse(price).toStringAsFixed(2)}${widget.currency}';
    }
    
    double rate = (originalCurrency == '€') ? 1 / 0.85 : 0.85;
    double convertedPrice = double.parse(price) * rate;
    
    return '${convertedPrice.toStringAsFixed(2)}${widget.currency}';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: MouseRegion(
                onEnter: (_) => setState(() => _isHovered = true),
                onExit: (_) => setState(() => _isHovered = false),
                child: _buildSlidableContent(context),
              ),
            ),
          ),
        );
      },
    );
  }

  // Build slidable container with actions
  Widget _buildSlidableContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 25, right: 25, top: 25),
      child: Slidable(
        key: ValueKey(widget.productName),
        startActionPane: ActionPane(
          motion: const ScrollMotion(),
          extentRatio: 0.225,
          children: [_buildEditAction(context)],
        ),
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          dismissible: DismissiblePane(
            onDismissed: () => widget.deleteFunction?.call(context),
            closeOnCancel: true,
          ),
          extentRatio: 0.225,
          children: [_buildDeleteAction(context)],
        ),
        child: _buildMainContent(context),
      ),
    );
  }

  // Build main tile content
  Widget _buildMainContent(BuildContext context) {
    return GestureDetector(
      onDoubleTap: () => _launchUrl(context),
      child: Container(
        height: 80,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            if (_isHovered || _isDragging)
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: widget.index,
              child: Icon(
                Icons.drag_handle,
                color: Theme.of(context).colorScheme.onPrimary.withOpacity(
                      _isHovered ? 1.0 : 0.5,
                    ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: _buildAnimatedText(
                widget.productName,
                TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 20,
                  fontWeight: _isHovered ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 1,
              child: _buildAnimatedPrice(),
            ),
          ],
        ),
      ),
    );
  }

  // Build animated text with hover effect
  Widget _buildAnimatedText(String text, TextStyle style, {TextAlign? textAlign}) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 200),
      tween: Tween(begin: 0.0, end: _isHovered ? 1.0 : 0.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(10 * value, 0),
          child: Text(
            text,
            style: style,
            textAlign: textAlign,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        );
      },
    );
  }

  // Build animated price display
  Widget _buildAnimatedPrice() {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.8 + (0.2 * value),
          child: Text(
            _formatPrice(),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
        );
      },
    );
  }

  // Build edit action button
  Widget _buildEditAction(BuildContext context) {
    return CustomSlidableAction(
      onPressed: (context) => showDialog(
        context: context,
        builder: (context) {
          widget.nameController.text = widget.productName;
          widget.priceController.text = widget.productPrice;
          widget.linkController.text = widget.productLink;

          return DialogBox(
            nameController: widget.nameController,
            priceController: widget.priceController,
            linkController: widget.linkController,
            categories: widget.categories,
            selectedCategory: widget.selectedCategory,
            onChangedCategory: widget.onChangedCategory,
            onSave: () {
              widget.editFunction!(context);
              Navigator.of(context).pop();
            },
            onCancel: () => Navigator.of(context).pop(),
          );
        },
      ),
      backgroundColor: Colors.yellow.shade300,
      foregroundColor: Theme.of(context).colorScheme.onPrimary,
      borderRadius: const BorderRadius.horizontal(
        left: Radius.circular(12),
        right: Radius.circular(12),
      ),
      child: const Icon(Icons.edit),
    );
  }

  // Build delete action button
  Widget _buildDeleteAction(BuildContext context) {
    return CustomSlidableAction(
      onPressed: widget.deleteFunction,
      backgroundColor: Colors.red.shade300,
      foregroundColor: Theme.of(context).colorScheme.onPrimary,
      borderRadius: const BorderRadius.horizontal(
        left: Radius.circular(12),
        right: Radius.circular(12),
      ),
      child: _buildDeleteActionContent(),
    );
  }

  // Build animated delete icon
  Widget _buildDeleteActionContent() {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 200),
      tween: Tween(begin: 1.0, end: _isHovered ? 1.2 : 1.0),
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: Icon(
            Icons.delete,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        );
      },
    );
  }

  // Handle drag start animation
  void startDrag() {
    setState(() => _isDragging = true);
    _controller.repeat(
      reverse: true,
      period: const Duration(milliseconds: 800),
    );
  }

  // Handle drag end animation
  void endDrag() {
    setState(() => _isDragging = false);
    _controller.forward(from: 0.0);
  }
}