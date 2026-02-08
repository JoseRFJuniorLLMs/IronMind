import 'dart:math';
import '../detection/yolo_engine.dart';

/// Analisa incerteza das detecções usando entropia de Shannon
/// Decide se precisa de análise adicional (EdgeSAM, Moondream, Cloud)
enum AnalysisDecision {
  /// Confiança alta (>0.90) - aceitar direto
  accept,

  /// Confiança média (0.75-0.90) - Moondream analisa
  moondreamAnalysis,

  /// Confiança baixa (0.50-0.75) - Cloud fallback se online
  cloudFallback,

  /// Confiança muito baixa (<0.50) - descartar
  discard,
}

class UncertaintyAnalyzer {
  // Thresholds configuráveis
  final double highConfidence;
  final double mediumConfidence;
  final double lowConfidence;
  final double minimumDisplay;

  UncertaintyAnalyzer({
    this.highConfidence = 0.90,
    this.mediumConfidence = 0.75,
    this.lowConfidence = 0.50,
    this.minimumDisplay = 0.60,
  });

  /// Calcula entropia de Shannon para distribuição de classes
  double shannonEntropy(List<Detection> detections) {
    if (detections.isEmpty) return 0.0;

    // Conta frequência de cada classe
    final classCounts = <String, int>{};
    for (final det in detections) {
      classCounts[det.className] = (classCounts[det.className] ?? 0) + 1;
    }

    final total = detections.length;
    double entropy = 0.0;

    for (final count in classCounts.values) {
      final p = count / total;
      if (p > 0) {
        entropy -= p * log(p) / ln2;
      }
    }

    return entropy;
  }

  /// Decide ação para uma detecção específica
  AnalysisDecision decide(Detection detection) {
    final conf = detection.confidence;

    if (conf >= highConfidence) return AnalysisDecision.accept;
    if (conf >= mediumConfidence) return AnalysisDecision.moondreamAnalysis;
    if (conf >= lowConfidence) return AnalysisDecision.cloudFallback;
    return AnalysisDecision.discard;
  }

  /// Analisa frame completo e retorna decisões para cada detecção
  Map<Detection, AnalysisDecision> analyzeFrame(List<Detection> detections) {
    final decisions = <Detection, AnalysisDecision>{};

    // Filtra abaixo do mínimo de exibição
    final visible = detections.where((d) => d.confidence >= minimumDisplay);

    for (final det in visible) {
      decisions[det] = decide(det);
    }

    return decisions;
  }

  /// Calcula score de urgência do frame (0.0 = tudo OK, 1.0 = emergência)
  double frameUrgency(List<Detection> detections) {
    if (detections.isEmpty) return 0.0;

    final defects = detections.where((d) => d.isDefect).toList();
    if (defects.isEmpty) return 0.0;

    // Urgência = média ponderada das confianças dos defeitos
    double totalWeight = 0.0;
    double weightedSum = 0.0;

    for (final defect in defects) {
      final weight = defect.confidence;
      weightedSum += weight * _severityMultiplier(defect.className);
      totalWeight += weight;
    }

    return (weightedSum / totalWeight).clamp(0.0, 1.0);
  }

  /// Multiplicador de severidade por tipo de defeito
  double _severityMultiplier(String className) {
    // Defeitos críticos (segurança)
    const critical = {
      'freio_gasto', 'suspensao_danificada', 'conexao_eletrica_solta',
      'cilindro_vazando', 'solda_trincada',
    };

    // Defeitos sérios (operação)
    const serious = {
      'mangueira_vazando', 'oleo_vazando', 'hidraulico_vazando',
      'corrosao_grave', 'vedacao_comprometida', 'esteira_desgastada',
    };

    if (critical.contains(className)) return 1.0;
    if (serious.contains(className)) return 0.7;
    return 0.4; // Defeitos menores
  }

  /// Determina se deve acionar alerta sonoro
  bool shouldAlert(List<Detection> detections) {
    return frameUrgency(detections) > 0.6;
  }
}
