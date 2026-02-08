import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme/app_theme.dart';
import '../core/accessibility/high_contrast_theme.dart';

/// Provider para gerenciar preferencias de acessibilidade
/// Persiste configuracoes no dispositivo
class AccessibilityProvider with ChangeNotifier {
  // Chaves de storage
  static const String _keyHighContrast = 'accessibility_high_contrast';
  static const String _keyLargeText = 'accessibility_large_text';
  static const String _keyBoldText = 'accessibility_bold_text';
  static const String _keyReduceMotion = 'accessibility_reduce_motion';
  static const String _keyVoiceEnabled = 'accessibility_voice_enabled';

  // Estado
  bool _isHighContrast = false;
  bool _isLargeText = false;
  bool _isBoldText = false;
  bool _isReduceMotion = false;
  bool _isVoiceEnabled = true;
  double _textScaleFactor = 1.0;

  // Getters
  bool get isHighContrast => _isHighContrast;
  bool get isLargeText => _isLargeText;
  bool get isBoldText => _isBoldText;
  bool get isReduceMotion => _isReduceMotion;
  bool get isVoiceEnabled => _isVoiceEnabled;
  double get textScaleFactor => _textScaleFactor;

  /// Escala de texto baseada nas preferencias
  double get effectiveTextScale {
    double scale = _textScaleFactor;
    if (_isLargeText) scale *= 1.3;
    return scale.clamp(0.8, 2.0);
  }

  /// Carrega preferencias salvas
  Future<void> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    _isHighContrast = prefs.getBool(_keyHighContrast) ?? false;
    _isLargeText = prefs.getBool(_keyLargeText) ?? false;
    _isBoldText = prefs.getBool(_keyBoldText) ?? false;
    _isReduceMotion = prefs.getBool(_keyReduceMotion) ?? false;
    _isVoiceEnabled = prefs.getBool(_keyVoiceEnabled) ?? true;

    notifyListeners();
  }

  /// Alterna modo de alto contraste
  Future<void> toggleHighContrast() async {
    _isHighContrast = !_isHighContrast;
    await _savePreference(_keyHighContrast, _isHighContrast);
    notifyListeners();
  }

  /// Alterna texto grande
  Future<void> toggleLargeText() async {
    _isLargeText = !_isLargeText;
    await _savePreference(_keyLargeText, _isLargeText);
    notifyListeners();
  }

  /// Alterna texto em negrito
  Future<void> toggleBoldText() async {
    _isBoldText = !_isBoldText;
    await _savePreference(_keyBoldText, _isBoldText);
    notifyListeners();
  }

  /// Alterna reducao de movimento
  Future<void> toggleReduceMotion() async {
    _isReduceMotion = !_isReduceMotion;
    await _savePreference(_keyReduceMotion, _isReduceMotion);
    notifyListeners();
  }

  /// Alterna comandos de voz
  Future<void> toggleVoiceEnabled() async {
    _isVoiceEnabled = !_isVoiceEnabled;
    await _savePreference(_keyVoiceEnabled, _isVoiceEnabled);
    notifyListeners();
  }

  /// Define escala de texto manualmente
  Future<void> setTextScaleFactor(double scale) async {
    _textScaleFactor = scale.clamp(0.8, 2.0);
    notifyListeners();
  }

  /// Retorna o tema apropriado baseado nas configuracoes
  ThemeData getTheme(BuildContext context) {
    if (_isHighContrast) {
      return HighContrastTheme.lightTheme;
    }
    return AppTheme.buildTheme(context);
  }

  /// Retorna o tema escuro apropriado
  ThemeData getDarkTheme(BuildContext context) {
    if (_isHighContrast) {
      return HighContrastTheme.darkTheme;
    }
    return AppTheme.buildDarkTheme(context);
  }

  /// Salva preferencia no storage
  Future<void> _savePreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  /// Reseta todas as configuracoes para padrao
  Future<void> resetToDefaults() async {
    _isHighContrast = false;
    _isLargeText = false;
    _isBoldText = false;
    _isReduceMotion = false;
    _isVoiceEnabled = true;
    _textScaleFactor = 1.0;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyHighContrast);
    await prefs.remove(_keyLargeText);
    await prefs.remove(_keyBoldText);
    await prefs.remove(_keyReduceMotion);
    await prefs.remove(_keyVoiceEnabled);

    notifyListeners();
  }
}
