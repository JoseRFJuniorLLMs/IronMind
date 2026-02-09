import 'package:flutter/material.dart';

/// Focus indicator widget for keyboard navigation
/// Shows a high-contrast border around focused elements
/// Essential for users navigating with:
/// - Bluetooth keyboard
/// - Switch controls
/// - Voice commands
/// - Screen readers with keyboard
///
/// WCAG 2.1 Success Criterion 2.4.7 (Level AA): Focus Visible
class FocusIndicator extends StatelessWidget {
  final Widget child;
  final FocusNode? focusNode;
  final Color focusColor;
  final double borderWidth;
  final double borderRadius;

  const FocusIndicator({
    super.key,
    required this.child,
    this.focusNode,
    this.focusColor = const Color(0xFF00BFFF), // Bright blue (high contrast)
    this.borderWidth = 3.0,
    this.borderRadius = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    final node = focusNode ?? FocusNode();

    return Focus(
      focusNode: node,
      child: AnimatedBuilder(
        animation: node,
        builder: (context, child) {
          return Container(
            decoration: node.hasFocus
                ? BoxDecoration(
                    border: Border.all(
                      color: focusColor,
                      width: borderWidth,
                    ),
                    borderRadius: BorderRadius.circular(borderRadius),
                    // Optional glow effect
                    boxShadow: [
                      BoxShadow(
                        color: focusColor.withValues(alpha: 0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  )
                : null,
            child: child,
          );
        },
        child: child,
      ),
    );
  }
}

/// Focusable button with visible focus indicator
class FocusableButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final String? semanticLabel;
  final String? semanticHint;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final EdgeInsetsGeometry? padding;
  final FocusNode? focusNode;

  const FocusableButton({
    super.key,
    required this.child,
    this.onPressed,
    this.semanticLabel,
    this.semanticHint,
    this.backgroundColor,
    this.foregroundColor,
    this.padding,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final button = ElevatedButton(
      onPressed: onPressed,
      focusNode: focusNode,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        padding: padding ?? const EdgeInsets.all(16),
        minimumSize: const Size(64, 64), // Elderly-friendly size
      ),
      child: child,
    );

    // Wrap with semantics if provided
    if (semanticLabel != null) {
      return Semantics(
        button: true,
        label: semanticLabel,
        hint: semanticHint,
        enabled: onPressed != null,
        excludeSemantics: true,
        child: FocusIndicator(
          focusNode: focusNode,
          child: button,
        ),
      );
    }

    return FocusIndicator(
      focusNode: focusNode,
      child: button,
    );
  }
}

/// Focusable icon button with visible focus indicator
class FocusableIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? semanticLabel;
  final String? semanticHint;
  final Color? color;
  final double size;
  final FocusNode? focusNode;

  const FocusableIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.semanticLabel,
    this.semanticHint,
    this.color,
    this.size = 24.0,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final iconButton = IconButton(
      icon: Icon(icon, size: size),
      onPressed: onPressed,
      focusNode: focusNode,
      color: color,
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48), // WCAG minimum
      ),
    );

    // Wrap with semantics if provided
    if (semanticLabel != null) {
      return Semantics(
        button: true,
        label: semanticLabel,
        hint: semanticHint,
        enabled: onPressed != null,
        excludeSemantics: true,
        child: FocusIndicator(
          focusNode: focusNode,
          child: iconButton,
        ),
      );
    }

    return FocusIndicator(
      focusNode: focusNode,
      child: iconButton,
    );
  }
}

/// Focusable text field with visible focus indicator
class FocusableTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final String? semanticLabel;
  final TextInputType? keyboardType;
  final bool obscureText;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;

  const FocusableTextField({
    super.key,
    this.controller,
    this.labelText,
    this.hintText,
    this.semanticLabel,
    this.keyboardType,
    this.obscureText = false,
    this.focusNode,
    this.onChanged,
    this.onEditingComplete,
  });

  @override
  Widget build(BuildContext context) {
    final node = focusNode ?? FocusNode();

    return Focus(
      focusNode: node,
      child: AnimatedBuilder(
        animation: node,
        builder: (context, child) {
          return Semantics(
            label: semanticLabel ?? labelText,
            textField: true,
            child: TextField(
              controller: controller,
              focusNode: node,
              keyboardType: keyboardType,
              obscureText: obscureText,
              onChanged: onChanged,
              onEditingComplete: onEditingComplete,
              style: const TextStyle(fontSize: 18), // Larger for field readability
              decoration: InputDecoration(
                labelText: labelText,
                hintText: hintText,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: node.hasFocus
                        ? const Color(0xFF00BFFF) // Bright blue when focused
                        : Colors.grey,
                    width: node.hasFocus ? 3.0 : 1.0,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Colors.grey,
                    width: 1.0,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xFF00BFFF), // Bright blue
                    width: 3.0, // Thick border
                  ),
                ),
                contentPadding: const EdgeInsets.all(16), // Large padding
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Focus traversal order widget
/// Defines tab order for keyboard navigation
class FocusTraversalOrderWidget extends StatelessWidget {
  final int order;
  final Widget child;

  const FocusTraversalOrderWidget({
    super.key,
    required this.order,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return FocusTraversalOrder(
      order: NumericFocusOrder(order.toDouble()),
      child: child,
    );
  }
}

/// Focus scope widget for grouping focusable elements
class FocusScopeWidget extends StatelessWidget {
  final List<Widget> children;
  final FocusNode? focusNode;

  const FocusScopeWidget({
    super.key,
    required this.children,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      node: focusNode != null ? FocusScopeNode() : null,
      child: Column(
        children: children,
      ),
    );
  }
}
