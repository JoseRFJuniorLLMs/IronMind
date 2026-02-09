import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../accessibility/accessibility_helper.dart';

class AppTheme {
  // Base font sizes (will be scaled by user's accessibility settings)
  static const double fontSizeSmall = 12.0;
  static const double fontSizeBody = 16.0;
  static const double fontSizeLarge = 20.0;
  static const double fontSizeTitle = 24.0;
  static const double fontSizeHeadline = 32.0;

  /// Creates a theme with responsive font scaling
  /// Respects user's system text scale factor (Settings > Accessibility > Font Size)
  static ThemeData buildTheme(BuildContext context) {
    // Get user's preferred text scale (1.0 = normal, 2.0 = 200% larger)
    final textScaleFactor = MediaQuery.textScaleFactorOf(context);
    final isBoldText = MediaQuery.boldTextOf(context);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),

      // 🔤 Accessible Text Theme - Respects user's font size preferences
      textTheme: _buildTextTheme(context, textScaleFactor, isBoldText),

      // Larger touch targets for buttons (field-friendly)
      buttonTheme: const ButtonThemeData(
        minWidth: AccessibilityHelper.recommendedTouchTargetSize,
        height: AccessibilityHelper.recommendedTouchTargetSize,
      ),
    );
  }

  /// Optimized dark theme with high contrast for accessibility
  static ThemeData buildDarkTheme(BuildContext context) {
    final textScaleFactor = MediaQuery.textScaleFactorOf(context);
    final isBoldText = MediaQuery.boldTextOf(context);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: Color(0xFF1E1E1E), // Darker surface for better contrast
        error: AppColors.error,
        onPrimary: Color(0xFFFFFFFF), // Pure white text on primary
        onSurface: Color(0xFFFFFFFF), // Pure white text on surface (was gray)
        onError: Color(0xFFFFFFFF),
      ),
      scaffoldBackgroundColor: const Color(0xFF121212), // Material Dark baseline
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E1E1E),
        foregroundColor: Color(0xFFFFFFFF), // Pure white
        elevation: 0,
        iconTheme: IconThemeData(color: Color(0xFFFFFFFF)),
      ),

      // High contrast text theme for dark mode
      textTheme: _buildTextTheme(context, textScaleFactor, isBoldText, isDark: true),

      // Larger touch targets
      buttonTheme: const ButtonThemeData(
        minWidth: AccessibilityHelper.recommendedTouchTargetSize,
        height: AccessibilityHelper.recommendedTouchTargetSize,
      ),
    );
  }

  /// Legacy dark theme (without context-aware scaling)
  /// Use buildDarkTheme(context) instead for accessibility
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.surface,
      error: AppColors.error,
    ),
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      elevation: 0,
    ),
  );

  /// Builds text theme with scaled font sizes
  static TextTheme _buildTextTheme(
    BuildContext context,
    double textScaleFactor,
    bool isBoldText, {
    bool isDark = false,
  }) {
    // Clamp text scale between 0.8 and 2.0 for UI stability
    final clampedScale = textScaleFactor.clamp(0.8, 2.0);
    final fontWeight = isBoldText ? FontWeight.bold : FontWeight.normal;
    final textColor = isDark ? const Color(0xFFFFFFFF) : Colors.white; // Pure white for dark mode

    return TextTheme(
      // Display styles (largest)
      displayLarge: TextStyle(
        fontSize: fontSizeHeadline * clampedScale,
        fontWeight: fontWeight,
        color: textColor,
      ),
      displayMedium: TextStyle(
        fontSize: fontSizeTitle * clampedScale,
        fontWeight: fontWeight,
        color: textColor,
      ),

      // Headline styles
      headlineLarge: TextStyle(
        fontSize: fontSizeTitle * clampedScale,
        fontWeight: fontWeight,
        color: textColor,
      ),
      headlineMedium: TextStyle(
        fontSize: fontSizeLarge * clampedScale,
        fontWeight: fontWeight,
        color: textColor,
      ),

      // Title styles
      titleLarge: TextStyle(
        fontSize: fontSizeLarge * clampedScale,
        fontWeight: fontWeight,
        color: textColor,
      ),
      titleMedium: TextStyle(
        fontSize: fontSizeBody * clampedScale,
        fontWeight: fontWeight,
        color: textColor,
      ),

      // Body styles (main content)
      bodyLarge: TextStyle(
        fontSize: fontSizeBody * clampedScale,
        fontWeight: fontWeight,
        color: textColor,
      ),
      bodyMedium: TextStyle(
        fontSize: fontSizeBody * clampedScale,
        fontWeight: fontWeight,
        color: isDark ? const Color(0xFFE0E0E0) : Colors.white70,
      ),

      // Label styles (buttons, chips)
      labelLarge: TextStyle(
        fontSize: fontSizeBody * clampedScale,
        fontWeight: fontWeight,
        color: textColor,
      ),
      labelMedium: TextStyle(
        fontSize: fontSizeSmall * clampedScale,
        fontWeight: fontWeight,
        color: isDark ? const Color(0xFFE0E0E0) : Colors.white70,
      ),
    );
  }
}
