import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Classificador de sons industriais via YAMNet
/// Refatorado do AudioEventClassifier (idosos) para equipamentos pesados
class IndustrialAudioClassifier {
  late Interpreter _interpreter;
  bool _isInitialized = false;

  // YAMNet config
  static const int SAMPLE_RATE = 16000;
  static const int FRAME_LENGTH = 15600; // 0.975 segundos
  static const int NUM_CLASSES = 521;

  // Classes industriais relevantes no YAMNet (521 classes)
  static const Map<String, int> INDUSTRIAL_CLASSES = {
    // Motores e máquinas
    'Engine': 300,
    'Engine_knocking': 303,
    'Engine_idling': 301,
    'Motor_vehicle_road': 310,

    // Metais e impactos
    'Clang': 397,
    'Clank': 398,
    'Bang': 399,
    'Thud': 404,
    'Hammer': 395,

    // Alertas
    'Alarm': 389,
    'Siren': 390,
    'Horn': 391,
    'Buzzer': 393,

    // Fluidos e pressão
    'Hiss': 411,
    'Steam': 412,
    'Drip': 414,
    'Splashing': 415,

    // Quebras
    'Glass_shatter': 405,
    'Crack': 406,
    'Creak': 407,
    'Squeak': 408,

    // Elétrico
    'Buzz': 418,
    'Electrical_spark': 419,

    // Humano (segurança do operador)
    'Scream': 41,
    'Shout': 42,
  };

  // Thresholds por classe (industriais são mais agressivos)
  static const Map<String, double> CLASS_THRESHOLDS = {
    'Engine_knocking': 0.65,
    'Engine': 0.50,
    'Engine_idling': 0.50,
    'Motor_vehicle_road': 0.50,
    'Clang': 0.70,
    'Clank': 0.70,
    'Bang': 0.75,
    'Thud': 0.70,
    'Hammer': 0.65,
    'Alarm': 0.60,
    'Siren': 0.60,
    'Horn': 0.55,
    'Buzzer': 0.55,
    'Hiss': 0.70,     // Vazamento de pressão
    'Steam': 0.65,    // Vapor/vazamento
    'Drip': 0.75,     // Gotejamento (óleo)
    'Splashing': 0.70,
    'Glass_shatter': 0.80,
    'Crack': 0.75,
    'Creak': 0.70,    // Estrutura cedendo
    'Squeak': 0.65,   // Correia/rolamento
    'Buzz': 0.70,     // Elétrico anormal
    'Electrical_spark': 0.75,
    'Scream': 0.70,   // Operador em perigo
    'Shout': 0.65,
  };

  // Mapeamento para alertas em português
  static const Map<String, String> ALERT_LABELS = {
    'Engine_knocking': 'Motor batendo',
    'Engine': 'Motor detectado',
    'Engine_idling': 'Motor em marcha lenta',
    'Clang': 'Impacto metálico',
    'Clank': 'Batida metálica',
    'Bang': 'Explosão/Estouro',
    'Thud': 'Impacto pesado',
    'Hammer': 'Martelada',
    'Alarm': 'Alarme ativo',
    'Siren': 'Sirene detectada',
    'Horn': 'Buzina',
    'Buzzer': 'Buzina/Alarme',
    'Hiss': 'Vazamento de pressão',
    'Steam': 'Vapor/Vazamento',
    'Drip': 'Gotejamento (possível vazamento)',
    'Splashing': 'Líquido derramando',
    'Glass_shatter': 'Quebra detectada',
    'Crack': 'Rachadura/Trinca',
    'Creak': 'Estrutura cedendo',
    'Squeak': 'Correia/Rolamento rangendo',
    'Buzz': 'Zumbido elétrico anormal',
    'Electrical_spark': 'Faísca elétrica',
    'Scream': 'GRITO - Operador em perigo!',
    'Shout': 'GRITO - Verificar operador',
  };

  // Classificação de severidade
  static const Map<String, IndustrialSoundSeverity> CLASS_SEVERITY = {
    'Engine_knocking': IndustrialSoundSeverity.warning,
    'Engine': IndustrialSoundSeverity.info,
    'Engine_idling': IndustrialSoundSeverity.info,
    'Clang': IndustrialSoundSeverity.warning,
    'Clank': IndustrialSoundSeverity.warning,
    'Bang': IndustrialSoundSeverity.critical,
    'Thud': IndustrialSoundSeverity.warning,
    'Hammer': IndustrialSoundSeverity.info,
    'Alarm': IndustrialSoundSeverity.critical,
    'Siren': IndustrialSoundSeverity.critical,
    'Horn': IndustrialSoundSeverity.info,
    'Buzzer': IndustrialSoundSeverity.info,
    'Hiss': IndustrialSoundSeverity.warning,
    'Steam': IndustrialSoundSeverity.warning,
    'Drip': IndustrialSoundSeverity.warning,
    'Splashing': IndustrialSoundSeverity.warning,
    'Glass_shatter': IndustrialSoundSeverity.critical,
    'Crack': IndustrialSoundSeverity.critical,
    'Creak': IndustrialSoundSeverity.warning,
    'Squeak': IndustrialSoundSeverity.warning,
    'Buzz': IndustrialSoundSeverity.warning,
    'Electrical_spark': IndustrialSoundSeverity.critical,
    'Scream': IndustrialSoundSeverity.emergency,
    'Shout': IndustrialSoundSeverity.critical,
  };

  Future<void> initialize() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/audio/yamnet.tflite');
      _isInitialized = true;
      print('[IndustrialAudio] YAMNet carregado');
    } catch (e) {
      print('[IndustrialAudio] Erro ao carregar YAMNet: $e');
    }
  }

  bool get isInitialized => _isInitialized;

  Future<IndustrialAudioResult?> classifyAudio(Float32List audioSamples) async {
    if (!_isInitialized || audioSamples.length != FRAME_LENGTH) return null;

    var processedAudio = _preprocessAudio(audioSamples);

    var output = List.filled(NUM_CLASSES, 0.0).reshape([1, NUM_CLASSES]);
    _interpreter.run(processedAudio, output);

    return _analyzeOutput(output[0]);
  }

  List<double> _preprocessAudio(Float32List samples) {
    double max = 0.0;
    for (var s in samples) {
      if (s.abs() > max) max = s.abs();
    }
    if (max > 0) {
      for (int i = 0; i < samples.length; i++) {
        samples[i] = samples[i] / max;
      }
    }
    return samples.toList();
  }

  IndustrialAudioResult _analyzeOutput(List<double> probabilities) {
    Map<String, double> detectedEvents = {};
    IndustrialSoundSeverity maxSeverity = IndustrialSoundSeverity.info;

    INDUSTRIAL_CLASSES.forEach((className, classIndex) {
      if (classIndex < probabilities.length) {
        double prob = probabilities[classIndex];
        double threshold = CLASS_THRESHOLDS[className] ?? 0.70;

        if (prob >= threshold) {
          detectedEvents[className] = prob;
          final severity = CLASS_SEVERITY[className] ?? IndustrialSoundSeverity.info;
          if (severity.index > maxSeverity.index) {
            maxSeverity = severity;
          }
        }
      }
    });

    double maxConf = 0.0;
    String? topEvent;
    if (detectedEvents.isNotEmpty) {
      maxConf = detectedEvents.values.reduce((a, b) => a > b ? a : b);
      topEvent = detectedEvents.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
    }

    return IndustrialAudioResult(
      detectedEvents: detectedEvents,
      maxConfidence: maxConf,
      topEvent: topEvent,
      topEventLabel: topEvent != null ? ALERT_LABELS[topEvent] : null,
      severity: maxSeverity,
      hasAnomaly: detectedEvents.isNotEmpty,
    );
  }

  void dispose() {
    if (_isInitialized) {
      _interpreter.close();
    }
  }
}

enum IndustrialSoundSeverity {
  info,      // Informativo (motor normal)
  warning,   // Atenção (desgaste, vazamento)
  critical,  // Crítico (quebra, faísca)
  emergency, // Emergência (operador em perigo)
}

class IndustrialAudioResult {
  final Map<String, double> detectedEvents;
  final double maxConfidence;
  final String? topEvent;
  final String? topEventLabel;
  final IndustrialSoundSeverity severity;
  final bool hasAnomaly;

  IndustrialAudioResult({
    required this.detectedEvents,
    required this.maxConfidence,
    this.topEvent,
    this.topEventLabel,
    required this.severity,
    required this.hasAnomaly,
  });
}
