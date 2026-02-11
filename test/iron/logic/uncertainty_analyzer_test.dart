import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:ironmind/iron/detection/yolo_engine.dart';
import 'package:ironmind/iron/logic/uncertainty_analyzer.dart';

Detection _makeDetection(String className, double confidence) {
  return Detection(
    bbox: BoundingBox(xCenter: 0.5, yCenter: 0.5, width: 0.1, height: 0.1),
    classId: 0,
    className: className,
    confidence: confidence,
  );
}

void main() {
  late UncertaintyAnalyzer analyzer;

  setUp(() {
    analyzer = UncertaintyAnalyzer();
  });

  group('Shannon Entropy', () {
    test('entropy de lista vazia é 0', () {
      expect(analyzer.shannonEntropy([]), 0.0);
    });

    test('entropy de classe unica é 0', () {
      final detections = [
        _makeDetection('corrosao', 0.9),
        _makeDetection('corrosao', 0.8),
        _makeDetection('corrosao', 0.7),
      ];

      expect(analyzer.shannonEntropy(detections), 0.0);
    });

    test('entropy de 2 classes iguais é 1.0', () {
      final detections = [
        _makeDetection('corrosao', 0.9),
        _makeDetection('trinca', 0.8),
      ];

      expect(analyzer.shannonEntropy(detections), closeTo(1.0, 0.01));
    });

    test('entropy de 4 classes iguais é 2.0', () {
      final detections = [
        _makeDetection('corrosao', 0.9),
        _makeDetection('trinca', 0.8),
        _makeDetection('vazamento', 0.7),
        _makeDetection('desgaste', 0.6),
      ];

      expect(analyzer.shannonEntropy(detections), closeTo(2.0, 0.01));
    });

    test('entropy com distribuição desigual', () {
      final detections = [
        _makeDetection('corrosao', 0.9),
        _makeDetection('corrosao', 0.8),
        _makeDetection('corrosao', 0.7),
        _makeDetection('trinca', 0.6),
      ];

      // 3/4 corrosao + 1/4 trinca
      // H = -(0.75*log2(0.75) + 0.25*log2(0.25)) ≈ 0.811
      expect(analyzer.shannonEntropy(detections), closeTo(0.811, 0.01));
    });
  });

  group('Decision Making', () {
    test('confiança alta (>=0.90) → accept', () {
      final det = _makeDetection('corrosao', 0.95);
      expect(analyzer.decide(det), AnalysisDecision.accept);
    });

    test('confiança média (0.75-0.90) → geminiQuick', () {
      final det = _makeDetection('corrosao', 0.80);
      expect(analyzer.decide(det), AnalysisDecision.geminiQuick);
    });

    test('confiança baixa (0.50-0.75) → geminiDeep', () {
      final det = _makeDetection('corrosao', 0.60);
      expect(analyzer.decide(det), AnalysisDecision.geminiDeep);
    });

    test('confiança muito baixa (<0.50) → discard', () {
      final det = _makeDetection('corrosao', 0.30);
      expect(analyzer.decide(det), AnalysisDecision.discard);
    });

    test('limites exatos: 0.90 → accept', () {
      final det = _makeDetection('corrosao', 0.90);
      expect(analyzer.decide(det), AnalysisDecision.accept);
    });

    test('limites exatos: 0.75 → geminiQuick', () {
      final det = _makeDetection('corrosao', 0.75);
      expect(analyzer.decide(det), AnalysisDecision.geminiQuick);
    });

    test('limites exatos: 0.50 → geminiDeep', () {
      final det = _makeDetection('corrosao', 0.50);
      expect(analyzer.decide(det), AnalysisDecision.geminiDeep);
    });
  });

  group('analyzeFrame', () {
    test('filtra detecções abaixo do minimumDisplay (0.60)', () {
      final detections = [
        _makeDetection('corrosao', 0.95), // accept
        _makeDetection('trinca', 0.55),   // filtrado (< 0.60)
        _makeDetection('vazamento', 0.40), // filtrado
      ];

      final decisions = analyzer.analyzeFrame(detections);

      expect(decisions.length, 1);
      expect(decisions.values.first, AnalysisDecision.accept);
    });

    test('retorna decisão para cada detecção visível', () {
      final detections = [
        _makeDetection('corrosao', 0.95),  // accept
        _makeDetection('trinca', 0.82),    // geminiQuick
        _makeDetection('vazamento', 0.65), // geminiDeep
      ];

      final decisions = analyzer.analyzeFrame(detections);

      expect(decisions.length, 3);
      expect(decisions.values.toList(), containsAll([
        AnalysisDecision.accept,
        AnalysisDecision.geminiQuick,
        AnalysisDecision.geminiDeep,
      ]));
    });

    test('lista vazia retorna mapa vazio', () {
      expect(analyzer.analyzeFrame([]), isEmpty);
    });
  });

  group('Frame Urgency', () {
    test('sem detecções → urgência 0', () {
      expect(analyzer.frameUrgency([]), 0.0);
    });

    test('só componentes OK → urgência 0', () {
      final detections = [
        _makeDetection('pneu_ok', 0.95),
        _makeDetection('freio_ok', 0.90),
      ];

      expect(analyzer.frameUrgency(detections), 0.0);
    });

    test('defeito crítico com alta confiança → urgência alta', () {
      final detections = [
        _makeDetection('freio_gasto', 0.95),
      ];

      // severity=1.0 (critico), conf=0.95
      // urgency = (0.95 * 1.0) / 0.95 = 1.0
      expect(analyzer.frameUrgency(detections), closeTo(1.0, 0.01));
    });

    test('defeito menor com baixa confiança → urgência baixa', () {
      final detections = [
        _makeDetection('arranhao_leve', 0.60),
      ];

      // severity=0.4 (menor), conf=0.60
      // urgency = (0.60 * 0.4) / 0.60 = 0.4
      expect(analyzer.frameUrgency(detections), closeTo(0.4, 0.01));
    });

    test('mix de defeitos calcula média ponderada', () {
      final detections = [
        _makeDetection('freio_gasto', 0.90),        // critical=1.0
        _makeDetection('arranhao_leve', 0.70),       // minor=0.4
      ];

      // weighted = (0.90*1.0 + 0.70*0.4) / (0.90 + 0.70)
      // = (0.90 + 0.28) / 1.60 = 1.18 / 1.60 = 0.7375
      expect(analyzer.frameUrgency(detections), closeTo(0.7375, 0.01));
    });

    test('urgência clamped a [0, 1]', () {
      final detections = [
        _makeDetection('freio_gasto', 0.99),
      ];

      final urgency = analyzer.frameUrgency(detections);
      expect(urgency, greaterThanOrEqualTo(0.0));
      expect(urgency, lessThanOrEqualTo(1.0));
    });
  });

  group('Should Alert', () {
    test('urgência > 0.6 → deve alertar', () {
      final detections = [
        _makeDetection('freio_gasto', 0.95), // urgency ~1.0
      ];

      expect(analyzer.shouldAlert(detections), isTrue);
    });

    test('urgência <= 0.6 → não alerta', () {
      final detections = [
        _makeDetection('arranhao_leve', 0.70), // urgency ~0.4
      ];

      expect(analyzer.shouldAlert(detections), isFalse);
    });

    test('lista vazia → não alerta', () {
      expect(analyzer.shouldAlert([]), isFalse);
    });
  });

  group('Custom Thresholds', () {
    test('thresholds customizados funcionam', () {
      final custom = UncertaintyAnalyzer(
        highConfidence: 0.95,
        mediumConfidence: 0.80,
        lowConfidence: 0.60,
        minimumDisplay: 0.50,
      );

      expect(custom.decide(_makeDetection('x', 0.96)), AnalysisDecision.accept);
      expect(custom.decide(_makeDetection('x', 0.92)), AnalysisDecision.geminiQuick);
      expect(custom.decide(_makeDetection('x', 0.70)), AnalysisDecision.geminiDeep);
      expect(custom.decide(_makeDetection('x', 0.40)), AnalysisDecision.discard);
    });
  });
}
