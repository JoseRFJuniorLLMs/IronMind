import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Color blindness support for users with:
/// - Deuteranopia (green-blind) - ~5% of males
/// - Protanopia (red-blind) - ~1% of males
/// - Tritanopia (blue-blind) - rare
///
/// Total affected: ~8% of male population, ~0.5% of female population
///
/// Solution:
/// - Color filters to simulate normal vision
/// - Pattern/texture alternatives to color
/// - Never use ONLY color to convey information
enum ColorBlindType {
  none,        // Normal vision
  deuteranopia, // Green-blind (most common)
  protanopia,  // Red-blind
  tritanopia,  // Blue-blind
}

class ColorBlindFilters {
  static const String _prefKey = 'color_blind_type';
  static ColorBlindType _currentType = ColorBlindType.none;

  /// Get current color blind filter type
  static ColorBlindType getCurrentType() => _currentType;

  /// Load preference from storage
  static Future<void> loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_prefKey);
    if (value != null) {
      _currentType = ColorBlindType.values.firstWhere(
        (e) => e.name == value,
        orElse: () => ColorBlindType.none,
      );
    }
  }

  /// Save preference to storage
  static Future<void> setType(ColorBlindType type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, type.name);
    _currentType = type;
  }

  /// Get ColorFilter matrix for current type
  static ColorFilter? getFilter() {
    switch (_currentType) {
      case ColorBlindType.deuteranopia:
        return ColorFilter.matrix(_deuteranopiaMatrix);
      case ColorBlindType.protanopia:
        return ColorFilter.matrix(_protanopiaMatrix);
      case ColorBlindType.tritanopia:
        return ColorFilter.matrix(_tritanopiaMatrix);
      case ColorBlindType.none:
        return null;
    }
  }

  /// Deuteranopia (green-blind) correction matrix
  /// Based on Brettel, Viénot and Mollon (1997)
  static const List<double> _deuteranopiaMatrix = [
    0.625, 0.375, 0.0, 0.0, 0.0, // Red
    0.7,   0.3,   0.0, 0.0, 0.0, // Green
    0.0,   0.3,   0.7, 0.0, 0.0, // Blue
    0.0,   0.0,   0.0, 1.0, 0.0, // Alpha
  ];

  /// Protanopia (red-blind) correction matrix
  static const List<double> _protanopiaMatrix = [
    0.567, 0.433, 0.0, 0.0, 0.0, // Red
    0.558, 0.442, 0.0, 0.0, 0.0, // Green
    0.0,   0.242, 0.758, 0.0, 0.0, // Blue
    0.0,   0.0,   0.0,   1.0, 0.0, // Alpha
  ];

  /// Tritanopia (blue-blind) correction matrix
  static const List<double> _tritanopiaMatrix = [
    0.95, 0.05, 0.0, 0.0, 0.0, // Red
    0.0,  0.433, 0.567, 0.0, 0.0, // Green
    0.0,  0.475, 0.525, 0.0, 0.0, // Blue
    0.0,  0.0,   0.0,   1.0, 0.0, // Alpha
  ];

  /// Get accessible color pair (high contrast for all types)
  /// Returns colors that work for color blind users
  static ColorPair getAccessibleColors(ColorPurpose purpose) {
    switch (purpose) {
      case ColorPurpose.success:
        // Green → Use blue instead (works for all types)
        return ColorPair(
          primary: const Color(0xFF0066CC), // Blue
          secondary: Colors.white,
          icon: Icons.check_circle,
        );
      case ColorPurpose.error:
        // Red → Use red + pattern
        return ColorPair(
          primary: const Color(0xFFCC0000), // Dark red
          secondary: Colors.white,
          icon: Icons.error,
        );
      case ColorPurpose.warning:
        // Orange → Use orange + pattern
        return ColorPair(
          primary: const Color(0xFFFF8C00), // Dark orange
          secondary: Colors.black,
          icon: Icons.warning_amber,
        );
      case ColorPurpose.info:
        // Blue → Safe for all
        return ColorPair(
          primary: const Color(0xFF0066CC),
          secondary: Colors.white,
          icon: Icons.info,
        );
    }
  }
}

/// Purpose of color (semantic meaning)
enum ColorPurpose {
  success, // Green (danger for color blind)
  error,   // Red (danger for color blind)
  warning, // Orange
  info,    // Blue (safe)
}

/// Accessible color pair with icon
class ColorPair {
  final Color primary;
  final Color secondary;
  final IconData icon;

  const ColorPair({
    required this.primary,
    required this.secondary,
    required this.icon,
  });
}

/// Widget that applies color blind filter
class ColorBlindFilterWidget extends StatelessWidget {
  final Widget child;
  final ColorBlindType? overrideType;

  const ColorBlindFilterWidget({
    super.key,
    required this.child,
    this.overrideType,
  });

  @override
  Widget build(BuildContext context) {
    final type = overrideType ?? ColorBlindFilters.getCurrentType();

    if (type == ColorBlindType.none) {
      return child;
    }

    final filter = ColorBlindFilters.getFilter();
    if (filter == null) {
      return child;
    }

    return ColorFiltered(
      colorFilter: filter,
      child: child,
    );
  }
}

/// Accessible status indicator (uses color + icon + text)
/// Never relies on ONLY color
class AccessibleStatusIndicator extends StatelessWidget {
  final ColorPurpose purpose;
  final String text;
  final double size;

  const AccessibleStatusIndicator({
    super.key,
    required this.purpose,
    required this.text,
    this.size = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    final colors = ColorBlindFilters.getAccessibleColors(purpose);

    return Semantics(
      label: '$text (${_getPurposeName(purpose)})',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colors.primary,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: colors.secondary,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              colors.icon,
              color: colors.secondary,
              size: size,
            ),
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                color: colors.secondary,
                fontSize: size * 0.7,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getPurposeName(ColorPurpose purpose) {
    switch (purpose) {
      case ColorPurpose.success:
        return 'Sucesso';
      case ColorPurpose.error:
        return 'Erro';
      case ColorPurpose.warning:
        return 'Aviso';
      case ColorPurpose.info:
        return 'Informação';
    }
  }
}

/// Accessible button with pattern/texture in addition to color
class AccessibleColorButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final ColorPurpose purpose;

  const AccessibleColorButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.purpose = ColorPurpose.info,
  });

  @override
  Widget build(BuildContext context) {
    final colors = ColorBlindFilters.getAccessibleColors(purpose);

    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(colors.icon),
      label: Text(text),
      style: ElevatedButton.styleFrom(
        backgroundColor: colors.primary,
        foregroundColor: colors.secondary,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        minimumSize: const Size(64, 64),
      ),
    );
  }
}

/// Settings widget for color blind mode selection
class ColorBlindSettings extends StatefulWidget {
  final Function(ColorBlindType)? onChanged;

  const ColorBlindSettings({super.key, this.onChanged});

  @override
  State<ColorBlindSettings> createState() => _ColorBlindSettingsState();
}

class _ColorBlindSettingsState extends State<ColorBlindSettings> {
  ColorBlindType _currentType = ColorBlindType.none;

  @override
  void initState() {
    super.initState();
    _loadCurrentType();
  }

  Future<void> _loadCurrentType() async {
    await ColorBlindFilters.loadPreference();
    setState(() {
      _currentType = ColorBlindFilters.getCurrentType();
    });
  }

  Future<void> _setType(ColorBlindType type) async {
    await ColorBlindFilters.setType(type);
    setState(() {
      _currentType = type;
    });
    widget.onChanged?.call(type);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Filtro de Daltonismo',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Selecione se você tem dificuldade para distinguir certas cores:',
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 16),

        RadioListTile<ColorBlindType>(
          title: const Text('Visão normal (sem filtro)'),
          value: ColorBlindType.none,
          groupValue: _currentType,
          onChanged: (value) => _setType(value!),
        ),

        RadioListTile<ColorBlindType>(
          title: const Text('Deuteranopia (dificuldade com verde)'),
          subtitle: const Text('Mais comum - 5% dos homens'),
          value: ColorBlindType.deuteranopia,
          groupValue: _currentType,
          onChanged: (value) => _setType(value!),
        ),

        RadioListTile<ColorBlindType>(
          title: const Text('Protanopia (dificuldade com vermelho)'),
          subtitle: const Text('Comum - 1% dos homens'),
          value: ColorBlindType.protanopia,
          groupValue: _currentType,
          onChanged: (value) => _setType(value!),
        ),

        RadioListTile<ColorBlindType>(
          title: const Text('Tritanopia (dificuldade com azul)'),
          subtitle: const Text('Raro'),
          value: ColorBlindType.tritanopia,
          groupValue: _currentType,
          onChanged: (value) => _setType(value!),
        ),
      ],
    );
  }
}
