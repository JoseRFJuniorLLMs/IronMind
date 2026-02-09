import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// Helper class for accessibility features
/// Provides utilities for font scaling, colors, touch targets, etc.
class AccessibilityHelper {
  /// Gets scaled font size based on user's text scale factor
  /// Clamps between 0.8x (minimum) and 2.0x (maximum) for UI stability
  ///
  /// Example:
  /// ```dart
  /// Text(
  ///   'Hello',
  ///   style: TextStyle(
  ///     fontSize: AccessibilityHelper.getScaledFontSize(context, 16.0),
  ///   ),
  /// )
  /// ```
  static double getScaledFontSize(BuildContext context, double baseSize) {
    final textScaleFactor = MediaQuery.textScaleFactorOf(context);
    // Clamp to prevent UI breaking at extreme scales
    // 0.8 = -20% (minimum)
    // 2.0 = +100% (maximum for field operators)
    final clampedFactor = textScaleFactor.clamp(0.8, 2.0);
    return baseSize * clampedFactor;
  }

  /// Checks if font size is large (user has accessibility needs)
  /// Returns true if text scale factor > 1.3 (30% larger)
  static bool isLargeText(BuildContext context) {
    return MediaQuery.textScaleFactorOf(context) > 1.3;
  }

  /// Checks if user has enabled bold text in system settings
  static bool isBoldTextEnabled(BuildContext context) {
    return MediaQuery.boldTextOf(context);
  }

  /// Checks if user has disabled animations (reduce motion)
  static bool isReduceMotionEnabled(BuildContext context) {
    return MediaQuery.disableAnimationsOf(context);
  }

  /// Minimum touch target size in logical pixels (WCAG 2.1 Level AA)
  static const double minTouchTargetSize = 48.0;

  /// Recommended touch target size for field operators (larger)
  static const double recommendedTouchTargetSize = 64.0;

  /// Ensures widget meets minimum touch target size
  /// Wraps widget with invisible padding if needed
  ///
  /// Example:
  /// ```dart
  /// AccessibilityHelper.ensureMinTouchTarget(
  ///   child: IconButton(icon: Icon(Icons.close), onPressed: () {}),
  /// )
  /// ```
  static Widget ensureMinTouchTarget({
    required Widget child,
    double minSize = minTouchTargetSize,
  }) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: minSize,
        minHeight: minSize,
      ),
      child: child,
    );
  }

  /// Creates a semantically labeled button for field operators
  /// Provides clear description and usage hints
  ///
  /// Example:
  /// ```dart
  /// AccessibilityHelper.semanticButton(
  ///   label: 'Botão de emergência SOS',
  ///   hint: 'Toque duas vezes para ligar para seu familiar',
  ///   child: ElevatedButton(...),
  /// )
  /// ```
  static Widget semanticButton({
    required String label,
    required String hint,
    required Widget child,
    bool enabled = true,
  }) {
    return Semantics(
      button: true,
      label: label,
      hint: hint,
      enabled: enabled,
      excludeSemantics: true, // Exclude child's default semantics
      child: child,
    );
  }

  /// Creates a semantic label for images
  static Widget semanticImage({
    required String label,
    required Widget child,
  }) {
    return Semantics(
      image: true,
      label: label,
      excludeSemantics: true,
      child: child,
    );
  }

  /// Creates a semantic label for text that should be read as-is
  static Widget semanticText({
    required String text,
    required Widget child,
  }) {
    return Semantics(
      label: text,
      excludeSemantics: true,
      child: child,
    );
  }

  /// High contrast colors for visually impaired users
  static const Color highContrastForeground = Colors.black;
  static const Color highContrastBackground = Colors.white;
  static const Color highContrastAccent = Color(0xFF0000FF); // Pure blue

  /// Checks if high contrast mode is enabled (system-wide)
  static bool isHighContrastEnabled(BuildContext context) {
    return MediaQuery.highContrastOf(context);
  }

  /// Gets appropriate text color based on contrast needs
  static Color getTextColor(BuildContext context, {Color defaultColor = Colors.black}) {
    return isHighContrastEnabled(context) ? highContrastForeground : defaultColor;
  }

  /// Gets appropriate background color based on contrast needs
  static Color getBackgroundColor(BuildContext context, {Color defaultColor = Colors.white}) {
    return isHighContrastEnabled(context) ? highContrastBackground : defaultColor;
  }

  /// Announces a message to screen readers (TalkBack/VoiceOver)
  /// Used for dynamic content updates
  ///
  /// Example:
  /// ```dart
  /// AccessibilityHelper.announce(context, 'Medicamento adicionado');
  /// ```
  static void announce(BuildContext context, String message) {
    SemanticsService.announce(message, TextDirection.ltr);
  }

  /// Converts duration to human-readable string for screen readers
  /// Example: 90 → "1 hora e 30 minutos"
  static String durationToReadable(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0 && minutes > 0) {
      return '$hours hora${hours > 1 ? 's' : ''} e $minutes minuto${minutes > 1 ? 's' : ''}';
    } else if (hours > 0) {
      return '$hours hora${hours > 1 ? 's' : ''}';
    } else {
      return '$minutes minuto${minutes > 1 ? 's' : ''}';
    }
  }

  /// Converts date to human-readable string for screen readers
  /// Example: "Segunda-feira, 25 de janeiro de 2026"
  static String dateToReadable(DateTime date) {
    const weekdays = ['Domingo', 'Segunda-feira', 'Terça-feira', 'Quarta-feira',
                      'Quinta-feira', 'Sexta-feira', 'Sábado'];
    const months = ['janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
                    'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'];

    return '${weekdays[date.weekday % 7]}, ${date.day} de ${months[date.month - 1]} de ${date.year}';
  }

  /// Creates a semantic header (for screen reader navigation)
  static Widget semanticHeader({
    required String label,
    required Widget child,
    int level = 1, // 1 = h1, 2 = h2, etc.
  }) {
    return Semantics(
      header: true,
      label: label,
      sortKey: OrdinalSortKey(level.toDouble()),
      excludeSemantics: true,
      child: child,
    );
  }
}
