import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';

class AudioEventClassifier {
  late Interpreter _interpreter;
  bool _isInitialized = false;

  // YAMNet configuration
  static const int SAMPLE_RATE = 16000;
  static const int FRAME_LENGTH = 15600; // 0.975 segundos
  static const int NUM_CLASSES = 521;

  // Índices de classes relevantes no YAMNet
  static const Map<String, int> DANGER_CLASSES = {
    'Scream': 41,
    'Shout': 42,
    'Crying_sobbing': 133,
    'Groan': 134,
    'Gasp': 212,
    'Thud': 404,
    'Glass_shatter': 405,
    'Door_slam': 410,
  };

  // Thresholds de confiança por classe
  static const Map<String, double> CLASS_THRESHOLDS = {
    'Scream': 0.75,
    'Shout': 0.70,
    'Crying_sobbing': 0.65,
    'Groan': 0.60,
    'Gasp': 0.70,
    'Thud': 0.80,
    'Glass_shatter': 0.85,
    'Door_slam': 0.75,
  };

  Future<void> initialize() async {
    try {
      // Ensure model asserts are configured in pubspec.yaml
      _interpreter = await Interpreter.fromAsset('assets/models/yamnet.tflite');
      _isInitialized = true;
      print('✅ YAMNet carregado');
    } catch (e) {
      print('❌ Erro ao carregar YAMNet: $e');
      // For now, fail gracefully if model is missing (user needs to provide it)
    }
  }

  Future<AudioClassificationResult?> classifyAudio(
      Float32List audioSamples) async {
    if (!_isInitialized || audioSamples.length != FRAME_LENGTH) {
      return null;
    }

    // 1. Pré-processamento
    var processedAudio = _preprocessAudio(audioSamples);

    // 2. Inferência
    var output = List.filled(NUM_CLASSES, 0.0).reshape([1, NUM_CLASSES]);
    _interpreter.run(processedAudio, output);

    // 3. Análise de resultados
    return _analyzeOutput(output[0]);
  }

  List<double> _preprocessAudio(Float32List samples) {
    // Normalização básica
    double max = 0.0;
    for (var s in samples) {
      if (s.abs() > max) max = s.abs();
    }

    if (max > 0) {
      for (int i = 0; i < samples.length; i++) {
        samples[i] = samples[i] / max;
      }
    }
    // TFLite interpreter expects specific input shape, handling list conversion
    return samples.toList();
  }

  AudioClassificationResult _analyzeOutput(List<double> probabilities) {
    Map<String, double> detectedEvents = {};

    DANGER_CLASSES.forEach((className, classIndex) {
      if (classIndex < probabilities.length) {
        double prob = probabilities[classIndex];
        double threshold = CLASS_THRESHOLDS[className]!;

        if (prob >= threshold) {
          detectedEvents[className] = prob;
        }
      }
    });

    double maxConf = 0.0;
    if (detectedEvents.isNotEmpty) {
      maxConf = detectedEvents.values.reduce((a, b) => a > b ? a : b);
    }

    return AudioClassificationResult(
      detectedEvents: detectedEvents,
      maxConfidence: maxConf,
      isDanger: detectedEvents.isNotEmpty,
    );
  }

  void dispose() {
    if (_isInitialized) {
      _interpreter.close();
    }
  }
}

class AudioClassificationResult {
  final Map<String, double> detectedEvents;
  final double maxConfidence;
  final bool isDanger;

  AudioClassificationResult({
    required this.detectedEvents,
    required this.maxConfidence,
    required this.isDanger,
  });
}
