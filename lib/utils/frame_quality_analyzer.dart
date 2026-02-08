import 'package:camera/camera.dart';
import 'dart:math' as math;
import 'dart:typed_data';

/// Analisa a qualidade de frames da câmera para determinar o momento ideal
/// de captura para identificação de medicamentos
class FrameQualityAnalyzer {
  // ✅ FIX: Thresholds mais baixos para funcionar em condições reais
  // Thresholds anteriores eram muito rígidos (0.7, 0.6, 0.75)
  static const double FOCUS_THRESHOLD = 0.4;
  static const double LIGHTING_THRESHOLD = 0.35;
  static const double FRAMING_THRESHOLD = 0.3;
  static const double STABILITY_THRESHOLD = 0.5;
  static const double OVERALL_THRESHOLD = 0.45;

  // Histórico para análise de estabilidade
  final List<double> _brightnessHistory = [];
  final int _historySize = 5;

  /// Analisa um frame e retorna métricas de qualidade
  FrameQuality analyzeFrame(CameraImage image) {
    final focusScore = _analyzeFocus(image);
    final lightingScore = _analyzeLighting(image);
    final framingScore = _analyzeFraming(image);
    final stabilityScore = _analyzeStability(image);

    final overallScore = (focusScore * 0.35) +
        (lightingScore * 0.30) +
        (framingScore * 0.20) +
        (stabilityScore * 0.15);

    final isReadyForCapture = overallScore >= OVERALL_THRESHOLD &&
        focusScore >= FOCUS_THRESHOLD &&
        lightingScore >= LIGHTING_THRESHOLD;

    return FrameQuality(
      focusScore: focusScore,
      lightingScore: lightingScore,
      framingScore: framingScore,
      stabilityScore: stabilityScore,
      overallScore: overallScore,
      isReadyForCapture: isReadyForCapture,
    );
  }

  /// Analisa o foco usando variância Laplaciana
  /// Imagens nítidas têm alta variância de gradiente
  double _analyzeFocus(CameraImage image) {
    try {
      // Converter YUV para grayscale (usar apenas plano Y)
      final yPlane = image.planes[0];
      final bytes = yPlane.bytes;
      final width = image.width;
      final height = image.height;

      // Aplicar operador Laplaciano em uma região de amostragem (centro)
      final sampleSize = 100; // 100x100 pixels no centro
      final startX = (width - sampleSize) ~/ 2;
      final startY = (height - sampleSize) ~/ 2;

      double laplacianSum = 0.0;
      int count = 0;

      for (int y = startY; y < startY + sampleSize - 1; y++) {
        for (int x = startX; x < startX + sampleSize - 1; x++) {
          final idx = y * width + x;

          if (idx + 1 < bytes.length && idx + width < bytes.length) {
            // Laplaciano simplificado: centro - média dos vizinhos
            final center = bytes[idx].toDouble();
            final right = bytes[idx + 1].toDouble();
            final bottom = bytes[idx + width].toDouble();

            final laplacian = (center * 2 - right - bottom).abs();
            laplacianSum += laplacian;
            count++;
          }
        }
      }

      final variance = count > 0 ? laplacianSum / count : 0.0;

      // Normalizar variância para score 0-1
      // Valores típicos: borrado < 50, nítido > 150
      final score = math.min(1.0, variance / 150.0);

      return score;
    } catch (e) {
      print('Erro ao analisar foco: $e');
      return 0.5; // Score neutro em caso de erro
    }
  }

  /// Analisa a iluminação usando histograma de luminância
  /// Detecta super-exposição, sub-exposição e boa iluminação
  double _analyzeLighting(CameraImage image) {
    try {
      final yPlane = image.planes[0];
      final bytes = yPlane.bytes;

      // Calcular média e desvio padrão da luminância
      double sum = 0.0;
      for (int i = 0; i < bytes.length; i += 10) {
        // Amostragem a cada 10 pixels
        sum += bytes[i];
      }

      final sampledCount = (bytes.length / 10).ceil();
      final mean = sum / sampledCount;

      // Calcular desvio padrão
      double varianceSum = 0.0;
      for (int i = 0; i < bytes.length; i += 10) {
        final diff = bytes[i] - mean;
        varianceSum += diff * diff;
      }
      final stdDev = math.sqrt(varianceSum / sampledCount);

      // Score de iluminação baseado em:
      // 1. Média próxima de 128 (meio-termo)
      // 2. Desvio padrão adequado (contraste)
      final meanScore = 1.0 - ((mean - 128).abs() / 128.0);
      final contrastScore = math.min(1.0, stdDev / 50.0); // Contraste ideal ~50

      final lightingScore = (meanScore * 0.7) + (contrastScore * 0.3);

      // Atualizar histórico para análise de estabilidade
      _brightnessHistory.add(mean);
      if (_brightnessHistory.length > _historySize) {
        _brightnessHistory.removeAt(0);
      }

      return lightingScore.clamp(0.0, 1.0);
    } catch (e) {
      print('Erro ao analisar iluminação: $e');
      return 0.5;
    }
  }

  /// Analisa o enquadramento verificando se há objetos centralizados
  /// Usa detecção de bordas simplificada
  double _analyzeFraming(CameraImage image) {
    try {
      final yPlane = image.planes[0];
      final bytes = yPlane.bytes;
      final width = image.width;
      final height = image.height;

      // Dividir imagem em 9 regiões (3x3)
      final regionWidth = width ~/ 3;
      final regionHeight = height ~/ 3;

      // Calcular densidade de bordas em cada região
      final densities = <double>[];

      for (int ry = 0; ry < 3; ry++) {
        for (int rx = 0; rx < 3; rx++) {
          double edgeSum = 0.0;
          int count = 0;

          final startX = rx * regionWidth;
          final startY = ry * regionHeight;

          for (int y = startY; y < startY + regionHeight - 1; y += 5) {
            for (int x = startX; x < startX + regionWidth - 1; x += 5) {
              final idx = y * width + x;

              if (idx + 1 < bytes.length && idx + width < bytes.length) {
                final current = bytes[idx].toDouble();
                final right = bytes[idx + 1].toDouble();
                final bottom = bytes[idx + width].toDouble();

                final gradientX = (current - right).abs();
                final gradientY = (current - bottom).abs();
                final gradient = math.sqrt(gradientX * gradientX + gradientY * gradientY);

                edgeSum += gradient;
                count++;
              }
            }
          }

          final density = count > 0 ? edgeSum / count : 0.0;
          densities.add(density);
        }
      }

      // Score baseado em densidade central vs periférica
      // Região central (índice 4) deve ter mais bordas (objeto centralizado)
      final centralDensity = densities[4];
      final peripheralDensity = (densities[0] +
              densities[2] +
              densities[6] +
              densities[8]) /
          4;

      // Ideal: centro tem 2-3x mais densidade que periferia
      final ratio = peripheralDensity > 0 ? centralDensity / peripheralDensity : 1.0;
      final framingScore = math.min(1.0, ratio / 2.5);

      return framingScore.clamp(0.0, 1.0);
    } catch (e) {
      print('Erro ao analisar enquadramento: $e');
      return 0.5;
    }
  }

  /// Analisa a estabilidade da câmera usando histórico de brilho
  /// Câmera estável tem brilho consistente entre frames
  double _analyzeStability(CameraImage image) {
    if (_brightnessHistory.length < 3) {
      return 0.5; // Não há histórico suficiente
    }

    try {
      // Calcular variação de brilho entre frames recentes
      double totalVariation = 0.0;

      for (int i = 1; i < _brightnessHistory.length; i++) {
        final variation = (_brightnessHistory[i] - _brightnessHistory[i - 1]).abs();
        totalVariation += variation;
      }

      final avgVariation = totalVariation / (_brightnessHistory.length - 1);

      // Score baseado em baixa variação
      // Variação ideal < 5 pixels de diferença média
      final stabilityScore = 1.0 - math.min(1.0, avgVariation / 15.0);

      return stabilityScore.clamp(0.0, 1.0);
    } catch (e) {
      print('Erro ao analisar estabilidade: $e');
      return 0.5;
    }
  }

  /// Reseta o histórico (útil ao iniciar nova sessão)
  void reset() {
    _brightnessHistory.clear();
  }
}

/// Resultado da análise de qualidade de um frame
class FrameQuality {
  final double focusScore;
  final double lightingScore;
  final double framingScore;
  final double stabilityScore;
  final double overallScore;
  final bool isReadyForCapture;

  FrameQuality({
    required this.focusScore,
    required this.lightingScore,
    required this.framingScore,
    required this.stabilityScore,
    required this.overallScore,
    required this.isReadyForCapture,
  });

  @override
  String toString() {
    return 'FrameQuality('
        'focus: ${(focusScore * 100).toInt()}%, '
        'lighting: ${(lightingScore * 100).toInt()}%, '
        'framing: ${(framingScore * 100).toInt()}%, '
        'stability: ${(stabilityScore * 100).toInt()}%, '
        'overall: ${(overallScore * 100).toInt()}%, '
        'ready: $isReadyForCapture)';
  }

  /// Retorna sugestão textual para melhorar qualidade
  String getImprovementSuggestion() {
    if (focusScore < FrameQualityAnalyzer.FOCUS_THRESHOLD) {
      return 'Aproxime a câmera e foque no medicamento';
    }
    if (lightingScore < FrameQualityAnalyzer.LIGHTING_THRESHOLD) {
      return 'Melhore a iluminação - ative o flash se necessário';
    }
    if (framingScore < FrameQualityAnalyzer.FRAMING_THRESHOLD) {
      return 'Centralize o medicamento no quadro';
    }
    if (stabilityScore < FrameQualityAnalyzer.STABILITY_THRESHOLD) {
      return 'Segure a câmera mais firme ou apoie em uma superfície';
    }
    return 'Continue assim...';
  }

  /// Retorna emoji representando a qualidade geral
  String getQualityEmoji() {
    if (overallScore >= 0.9) return '🟢';
    if (overallScore >= 0.7) return '🟡';
    return '🔴';
  }
}
