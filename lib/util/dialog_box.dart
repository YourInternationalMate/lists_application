import 'package:flutter/material.dart';
import 'package:lists_application/util/my_button.dart';
import 'package:flutter/services.dart';

// Dialog box for creating or editing shopping list items with animations
class DialogBox extends StatefulWidget {
  // Controllers for text input fields
  final TextEditingController nameController;
  final TextEditingController priceController;
  final TextEditingController linkController;
  
  // Callback functions for user actions
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final ValueChanged<String?> onChangedCategory;
  
  // Data for category selection
  final List<String> categories;
  final String selectedCategory;

  const DialogBox({
    super.key,
    required this.nameController,
    required this.priceController,
    required this.linkController,
    required this.onSave,
    required this.onCancel,
    required this.categories,
    required this.selectedCategory,
    required this.onChangedCategory,
  });

  @override
  State<DialogBox> createState() => _DialogBoxState();
}

// State class managing animations and dialog content
class _DialogBoxState extends State<DialogBox> with SingleTickerProviderStateMixin {
  // Animation controllers and animations
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    // Initialize dialog appearance animation
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        content: SizedBox(
          height: MediaQuery.of(context).size.height * 0.5,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Animated category dropdown
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 300),
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: DropdownButton<String>(
                        dropdownColor: Theme.of(context).colorScheme.surface,
                        value: widget.categories.contains(widget.selectedCategory)
                            ? widget.selectedCategory
                            : widget.categories.first,
                        items: widget.categories.toSet().map((String category) {
                          return DropdownMenuItem<String>(
                            value: category,
                            child: Text(
                              category,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: widget.onChangedCategory,
                      ),
                    ),
                  );
                },
              ),

              // Sequentially animated input fields
              ..._buildAnimatedInputFields(),

              // Animated action buttons
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 300),
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          MyButton(text: "Save", onPressed: widget.onSave),
                          const SizedBox(width: 8),
                          MyButton(text: "Cancel", onPressed: widget.onCancel),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build input fields with staggered animations
  List<Widget> _buildAnimatedInputFields() {
    final fields = [
      _buildInputField(
        controller: widget.nameController,
        hintText: 'Item Name',
      ),
      _buildInputField(
        controller: widget.priceController,
        hintText: 'Item Price',
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^[0-9\.]+$')),
        ],
      ),
      _buildInputField(
        controller: widget.linkController,
        hintText: 'Item Link',
      ),
    ];

    return fields.asMap().entries.map((entry) {
      return TweenAnimationBuilder<double>(
        duration: Duration(milliseconds: 200 + (entry.key * 100)),  // Staggered timing
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: child,
            ),
          );
        },
        child: entry.value,
      );
    }).toList();
  }

  // Build styled input field with consistent appearance
  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: controller,
      style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        hintText: hintText,
        hintStyle: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
      ),
      inputFormatters: inputFormatters,
    );
  }
}