import 'package:flutter/material.dart';

class AppTextStyles {
  // Estilos padrao
  static const TextStyle h1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
  );

  static const TextStyle caption = TextStyle(fontSize: 12, color: Colors.grey);

  // ============================================
  // ESTILOS PARA IDOSOS (Fontes maiores)
  // ============================================

  /// Titulo principal - 32dp bold
  static const TextStyle elderlyTitle = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    height: 1.3,
  );

  /// Subtitulo - 24dp semibold
  static const TextStyle elderlySubtitle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    height: 1.3,
  );

  /// Texto de corpo - 20dp
  static const TextStyle elderlyBody = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w500,
    height: 1.5,
  );

  /// Texto de corpo grande - 22dp
  static const TextStyle elderlyBodyLarge = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w500,
    height: 1.5,
  );

  /// Botao - 20dp bold
  static const TextStyle elderlyButton = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    letterSpacing: 1,
  );

  /// Botao grande - 24dp bold
  static const TextStyle elderlyButtonLarge = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    letterSpacing: 2,
  );

  /// Label - 18dp medium
  static const TextStyle elderlyLabel = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
  );

  /// Caption - 16dp (nunca menor que 16 para idosos)
  static const TextStyle elderlyCaption = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: Colors.grey,
  );

  /// Input hint - 20dp
  static const TextStyle elderlyHint = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w400,
    color: Colors.grey,
  );

  /// Numero grande (telefone, CPF) - 28dp
  static const TextStyle elderlyNumber = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w500,
    letterSpacing: 2,
  );

  // ============================================
  // ESTILOS PARA CARDS E LISTAS
  // ============================================

  /// Titulo de card - 20dp bold
  static const TextStyle cardTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: Colors.black87,
  );

  /// Subtitulo de card - 16dp
  static const TextStyle cardSubtitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: Colors.black54,
  );

  /// Texto de lista - 18dp
  static const TextStyle listItem = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
  );

  // ============================================
  // TAMANHOS MINIMOS RECOMENDADOS
  // ============================================

  /// Tamanho minimo para texto legivel por idosos
  static const double minElderlyFontSize = 16.0;

  /// Tamanho recomendado para corpo de texto
  static const double recommendedBodySize = 20.0;

  /// Tamanho recomendado para titulos
  static const double recommendedTitleSize = 28.0;

  /// Tamanho recomendado para botoes
  static const double recommendedButtonSize = 20.0;
}
