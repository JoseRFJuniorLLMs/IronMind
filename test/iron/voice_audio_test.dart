import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:ironmind/iron/voice/yamnet_classifier.dart';

void main() {
  group('YAMNetClassifier', () {
    late YAMNetClassifier classifier;

    setUp(() {
      classifier = YAMNetClassifier();
    });

    test('estado inicial nao inicializado', () {
      expect(classifier.isInitialized, false);
      expect(classifier.isRunning, false);
    });

    test('initialize marca como inicializado', () async {
      await classifier.initialize();
      expect(classifier.isInitialized, true);
    });

    test('classify retorna null quando nao inicializado', () async {
      final result = await classifier.classify(Float32List(15600));
      expect(result, isNull);
    });

    test('classify retorna null em modo placeholder (silencio)', () async {
      await classifier.initialize();
      final result = await classifier.classify(Float32List(15600));
      // Placeholder retorna silencio com score 0.1 (abaixo threshold 0.70)
      expect(result, isNull);
    });

    test('startContinuousClassification nao inicia sem initialize', () {
      classifier.startContinuousClassification();
      expect(classifier.isRunning, false);
    });

    test('startContinuousClassification funciona apos initialize', () async {
      await classifier.initialize();
      classifier.startContinuousClassification();
      expect(classifier.isRunning, true);
    });

    test('stopContinuousClassification para a classificacao', () async {
      await classifier.initialize();
      classifier.startContinuousClassification();
      classifier.stopContinuousClassification();
      expect(classifier.isRunning, false);
    });

    test('dispose reseta tudo', () async {
      await classifier.initialize();
      classifier.startContinuousClassification();
      classifier.dispose();

      expect(classifier.isInitialized, false);
      expect(classifier.isRunning, false);
    });

    test('constantes definidas corretamente', () {
      expect(YAMNetClassifier.sampleRate, 16000);
      expect(YAMNetClassifier.frameLength, 15600);
      expect(YAMNetClassifier.alertThreshold, 0.70);
    });

    test('industrialSounds tem 7 sons', () {
      expect(YAMNetClassifier.industrialSounds.length, 7);
      expect(YAMNetClassifier.industrialSounds.containsKey('motor_batendo'), true);
      expect(YAMNetClassifier.industrialSounds.containsKey('vazamento_ar'), true);
      expect(YAMNetClassifier.industrialSounds.containsKey('rolamento_rangendo'), true);
    });

    test('normalSounds tem 5 sons', () {
      expect(YAMNetClassifier.normalSounds.length, 5);
      expect(YAMNetClassifier.normalSounds.contains('silencio'), true);
    });
  });

  group('AudioEvent', () {
    test('construtor com valores corretos', () {
      final event = AudioEvent(
        className: 'motor_batendo',
        confidence: 0.85,
        alertMessage: 'Motor com batida anormal',
        isDangerous: true,
      );

      expect(event.className, 'motor_batendo');
      expect(event.confidence, 0.85);
      expect(event.alertMessage, 'Motor com batida anormal');
      expect(event.isDangerous, true);
    });

    test('isDangerous default e false', () {
      final event = AudioEvent(
        className: 'silencio',
        confidence: 0.99,
        alertMessage: '',
      );

      expect(event.isDangerous, false);
    });
  });
}
