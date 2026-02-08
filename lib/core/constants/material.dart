import 'package:flutter/material.dart';

/// Paleta de cores consistente para o app EVA
class AppColors {
  // Cores principais
  static const Color primary = Color(0xFF2196F3); // Azul primário
  static const Color primaryDark = Color(0xFF1976D2);
  static const Color primaryLight = Color(0xFF64B5F6);
  
  // Cores secundárias
  static const Color secondary = Color(0xFF4CAF50); // Verde
  static const Color secondaryDark = Color(0xFF388E3C);
  static const Color secondaryLight = Color(0xFF81C784);
  
  // Cores de status
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);
  
  // Cores de chamada
  static const Color calling = Color(0xFFFF9800); // Laranja
  static const Color connected = Color(0xFF4CAF50); // Verde
  static const Color ended = Color(0xFF757575); // Cinza
  
  // Cores de fundo
  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Colors.white;
  
  // Cores de texto
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFFBDBDBD);
  
  // Gradientes
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
  );
  
  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF4CAF50), Color(0xFF388E3C)],
  );
  
  static const LinearGradient errorGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF44336), Color(0xFFD32F2F)],
  );
}