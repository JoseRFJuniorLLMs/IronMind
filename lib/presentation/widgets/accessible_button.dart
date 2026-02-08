import 'package:flutter/material.dart';
import '../../core/accessibility/accessibility_helper.dart';

/// Accessible button widget that ensures minimum touch target size
/// Follows WCAG 2.1 Level AA guidelines (48x48dp minimum)
/// Extra large for elderly users (64x64dp recommended)
class AccessibleButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final String? semanticLabel;
  final String? semanticHint;
  final double minSize;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;

  const AccessibleButton({
    super.key,
    required this.child,
    this.onPressed,
    this.semanticLabel,
    this.semanticHint,
    this.minSize = AccessibilityHelper.recommendedTouchTargetSize,
    this.backgroundColor,
    this.foregroundColor,
    this.padding,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final button = ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        padding: padding ?? const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius ?? BorderRadius.circular(12),
        ),
        minimumSize: Size(minSize, minSize),
      ),
      child: child,
    );

    // Wrap with Semantics if labels provided
    if (semanticLabel != null) {
      return Semantics(
        button: true,
        label: semanticLabel,
        hint: semanticHint,
        enabled: onPressed != null,
        excludeSemantics: true,
        child: button,
      );
    }

    return button;
  }
}

/// Accessible icon button with minimum touch target
class AccessibleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? semanticLabel;
  final String? semanticHint;
  final double size;
  final double minTouchTarget;
  final Color? color;
  final Color? backgroundColor;

  const AccessibleIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.semanticLabel,
    this.semanticHint,
    this.size = 24.0,
    this.minTouchTarget = AccessibilityHelper.recommendedTouchTargetSize,
    this.color,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final iconButton = IconButton(
      icon: Icon(icon, size: size),
      onPressed: onPressed,
      color: color,
      style: IconButton.styleFrom(
        backgroundColor: backgroundColor,
        minimumSize: Size(minTouchTarget, minTouchTarget),
      ),
    );

    // Wrap with Semantics if labels provided
    if (semanticLabel != null) {
      return Semantics(
        button: true,
        label: semanticLabel,
        hint: semanticHint,
        enabled: onPressed != null,
        excludeSemantics: true,
        child: iconButton,
      );
    }

    return iconButton;
  }
}

/// Wrapper to ensure any widget meets minimum touch target size
/// Useful for wrapping existing widgets without modifying them
class MinimumTouchTarget extends StatelessWidget {
  final Widget child;
  final double minSize;
  final AlignmentGeometry alignment;

  const MinimumTouchTarget({
    super.key,
    required this.child,
    this.minSize = AccessibilityHelper.minTouchTargetSize,
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: minSize,
        minHeight: minSize,
      ),
      child: Align(
        alignment: alignment,
        child: child,
      ),
    );
  }
}

/// Large emergency button for elderly users
/// Extra-large touch target (128x128dp) with high contrast
class EmergencyButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final IconData icon;
  final Color color;

  const EmergencyButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon = Icons.phone,
    this.color = Colors.red,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Botão de emergência: $label',
      hint: 'Toque duas vezes para acionar emergência',
      enabled: onPressed != null,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(64),
          child: Container(
            width: 128,
            height: 128,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 48,
                  color: Colors.white,
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Accessible text button with large touch target
class AccessibleTextButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final String? semanticHint;
  final TextStyle? textStyle;
  final double minTouchTarget;

  const AccessibleTextButton({
    super.key,
    required this.text,
    this.onPressed,
    this.semanticHint,
    this.textStyle,
    this.minTouchTarget = AccessibilityHelper.recommendedTouchTargetSize,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: text,
      hint: semanticHint,
      enabled: onPressed != null,
      excludeSemantics: true,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          minimumSize: Size(minTouchTarget, minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
        child: Text(
          text,
          style: textStyle,
        ),
      ),
    );
  }
}
