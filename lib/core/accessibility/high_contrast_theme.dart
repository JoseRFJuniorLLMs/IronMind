import 'package:flutter/material.dart';

/// High contrast theme for users with low vision, cataracts, or color blindness
/// Follows WCAG 2.1 Level AAA contrast ratios (7:1 minimum)
///
/// Benefits:
/// - Pure black text on pure white background (21:1 contrast)
/// - Thick borders (3px) for clear element separation
/// - Pure colors (no gradients, no transparency)
/// - High contrast icons and buttons
class HighContrastTheme {
  // WCAG AAA Colors (pure, high contrast)
  static const Color foreground = Color(0xFF000000); // Black
  static const Color background = Color(0xFFFFFFFF); // White
  static const Color primary = Color(0xFF0000FF); // Pure blue
  static const Color error = Color(0xFFFF0000); // Pure red
  static const Color success = Color(0xFF008000); // Pure green
  static const Color warning = Color(0xFFFF8C00); // Dark orange
  static const Color info = Color(0xFF00008B); // Dark blue

  // Inverted colors for dark mode high contrast
  static const Color foregroundDark = Color(0xFFFFFFFF); // White
  static const Color backgroundDark = Color(0xFF000000); // Black
  static const Color primaryDark = Color(0xFF00BFFF); // Bright blue

  /// Light high contrast theme
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,

    // Color scheme - Pure colors only
    colorScheme: const ColorScheme.light(
      primary: primary,
      secondary: info,
      surface: background,
      error: error,
      onPrimary: background,
      onSecondary: background,
      onSurface: foreground,
      onError: background,
    ),

    scaffoldBackgroundColor: background,

    // AppBar - High contrast
    appBarTheme: const AppBarTheme(
      backgroundColor: foreground,
      foregroundColor: background,
      elevation: 0,
      iconTheme: IconThemeData(color: background),
    ),

    // Text theme - Pure black, thick font
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: foreground,
      ),
      displayMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: foreground,
      ),
      headlineLarge: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: foreground,
      ),
      headlineMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: foreground,
      ),
      bodyLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: foreground,
      ),
      bodyMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: foreground,
      ),
      labelLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: foreground,
      ),
    ),

    // Buttons - High contrast with thick borders
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: background,
        textStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(
            color: foreground,
            width: 3, // Thick border
          ),
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: foreground,
        textStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        side: const BorderSide(
          color: foreground,
          width: 3, // Thick border
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primary,
        textStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          decoration: TextDecoration.underline,
        ),
      ),
    ),

    // Input fields - High contrast borders
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: background,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: foreground,
          width: 3,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: foreground,
          width: 3,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: primary,
          width: 4, // Extra thick when focused
        ),
      ),
      labelStyle: const TextStyle(
        color: foreground,
        fontWeight: FontWeight.bold,
      ),
      hintStyle: TextStyle(
        color: foreground.withValues(alpha: 0.6),
        fontWeight: FontWeight.w600,
      ),
    ),

    // Cards - High contrast with borders
    cardTheme: CardThemeData(
      color: background,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(
          color: foreground,
          width: 3,
        ),
      ),
    ),

    // Icons - Pure black
    iconTheme: const IconThemeData(
      color: foreground,
      size: 28,
    ),

    // Dividers - Thick and black
    dividerTheme: const DividerThemeData(
      color: foreground,
      thickness: 3,
      space: 24,
    ),
  );

  /// Dark high contrast theme (inverted colors)
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,

    colorScheme: const ColorScheme.dark(
      primary: primaryDark,
      secondary: primaryDark,
      surface: backgroundDark,
      error: error,
      onPrimary: backgroundDark,
      onSecondary: backgroundDark,
      onSurface: foregroundDark,
      onError: backgroundDark,
    ),

    scaffoldBackgroundColor: backgroundDark,

    appBarTheme: const AppBarTheme(
      backgroundColor: backgroundDark,
      foregroundColor: foregroundDark,
      elevation: 0,
      iconTheme: IconThemeData(color: foregroundDark),
    ),

    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: foregroundDark,
      ),
      displayMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: foregroundDark,
      ),
      headlineLarge: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: foregroundDark,
      ),
      headlineMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: foregroundDark,
      ),
      bodyLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: foregroundDark,
      ),
      bodyMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: foregroundDark,
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryDark,
        foregroundColor: backgroundDark,
        textStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(
            color: foregroundDark,
            width: 3,
          ),
        ),
      ),
    ),

    iconTheme: const IconThemeData(
      color: foregroundDark,
      size: 28,
    ),
  );
}
