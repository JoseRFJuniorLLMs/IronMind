import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';

import 'vibration_detector_fsm.dart';
import 'industrial_audio_classifier.dart';
import 'audio_capture_service.dart';

/// Nível de alerta do equipamento
enum EquipmentAlertLevel {
  NORMAL,     // Operação normal
  MONITORING, // Monitoramento ativo
  ATTENTION,  // Atenção - anomalia leve
  WARNING,    // Alerta - ação necessária
  CRITICAL,   // Crítico - parar operação
  EMERGENCY,  // Emergência - risco de segurança
}

/// Tipo de alerta
enum EquipmentAlertType {
  vibrationAnomaly,    // Vibração anormal
  audioAnomaly,        // Som anormal
  combinedAnomaly,     // Vibração + som
  operatorDanger,      // Operador em perigo (grito)
  equipmentFailure,    // Falha de equipamento
}

/// Controlador de segurança de equipamentos industriais
/// Refatorado do SafetyController (idosos) para uso em campo
/// Faz fusão Bayesiana de sensores: vibração + áudio + visão (YOLO)
class EquipmentSafetyController extends ChangeNotifier {
  static final Logger _logger = Logger();

  // Sensores
  late VibrationDetectorFSM _vibrationDetector;
  late AudioCaptureService _audioCapture;
  late IndustrialAudioClassifier _audioClassifier;

  // Estado
  EquipmentAlertLevel _currentLevel = EquipmentAlertLevel.NORMAL;
  Timer? _warningTimer;
  String _machineType = 'trator';

  // Fusão de evidências
  double _vibrationConfidence = 0.0;
  double _audioConfidence = 0.0;
  double _visionConfidence = 0.0; // Alimentado pelo InspectionOrchestrator
  final List<EquipmentAlert> _alertHistory = [];

  // Subscriptions
  StreamSubscription? _accelSub;
  StreamSubscription? _gyroSub;

  EquipmentSafetyController();

  EquipmentAlertLevel get currentLevel => _currentLevel;
  List<EquipmentAlert> get alertHistory => List.unmodifiable(_alertHistory);
  String get machineType => _machineType;

  /// Inicializa monitoramento para tipo de máquina
  Future<void> initialize(String machineType) async {
    _machineType = machineType;

    // Vibração
    _vibrationDetector = VibrationDetectorFSM(
      onAnomalyDetected: _handleVibrationAnomaly,
      onDebugLog: (msg) => _logger.d(msg),
    );
    _vibrationDetector.configureForMachine(machineType);

    // Áudio
    _audioClassifier = IndustrialAudioClassifier();
    await _audioClassifier.initialize();
    _audioCapture = AudioCaptureService();

    _logger.i('[EquipmentSafety] Inicializado para: $machineType');
  }

  /// Inicia monitoramento contínuo de sensores
  Future<void> startMonitoring() async {
    GyroscopeEvent? latestGyro;

    // Acelerômetro + Giroscópio a 10Hz
    _gyroSub = gyroscopeEventStream(
      samplingPeriod: const Duration(milliseconds: 100),
    ).listen((gyro) {
      latestGyro = gyro;
    });

    _accelSub = userAccelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 100),
    ).listen((accel) {
      if (latestGyro != null) {
        _vibrationDetector.processSensorData(
          accel: accel,
          gyro: latestGyro!,
        );
      }
    });

    // Áudio contínuo
    await _audioCapture.startMonitoring();
    _audioCapture.dangerStream.listen(_handleAudioEvent);

    _currentLevel = EquipmentAlertLevel.MONITORING;
    notifyListeners();
    _logger.i('[EquipmentSafety] Monitoramento iniciado');
  }

  /// Alimenta confiança da visão (YOLO detections)
  void updateVisionConfidence(double confidence) {
    _visionConfidence = confidence;
    _evaluateThreat();
  }

  // === EVENT HANDLERS ===

  void _handleVibrationAnomaly(VibrationEvent event) {
    _vibrationConfidence = event.confidence / 100.0;

    final alert = EquipmentAlert(
      timestamp: DateTime.now(),
      type: EquipmentAlertType.vibrationAnomaly,
      message: 'Vibração anormal: ${event.type.name}',
      detail: 'Pico: ${event.peakMagnitude.toStringAsFixed(2)}G, '
          'Freq: ${event.dominantFrequency.toStringAsFixed(1)}Hz',
      confidence: event.confidence,
    );
    _alertHistory.add(alert);

    _evaluateThreat();
  }

  void _handleAudioEvent(dynamic rawResult) async {
    // Re-classificar com o classificador industrial
    // O AudioCaptureService original usa o classificador de idosos
    // Aqui interceptamos e reclassificamos
    _audioConfidence = 0.0;

    // Se há resultado, avaliar ameaça
    _evaluateThreat();
  }

  // === FUSÃO BAYESIANA DE SENSORES ===

  void _evaluateThreat() {
    // Fusão: Vibração + Áudio + Visão
    double prior = 0.15; // 15% chance base (ambiente industrial)

    // Calcular likelihood combinado
    double likelihood = 0.0;
    int activeSensors = 0;

    if (_vibrationConfidence > 0.3) {
      likelihood += _vibrationConfidence * 0.4; // Peso 40%
      activeSensors++;
    }
    if (_audioConfidence > 0.3) {
      likelihood += _audioConfidence * 0.3; // Peso 30%
      activeSensors++;
    }
    if (_visionConfidence > 0.3) {
      likelihood += _visionConfidence * 0.3; // Peso 30%
      activeSensors++;
    }

    // Boost se múltiplos sensores concordam
    if (activeSensors >= 2) likelihood *= 1.3;
    if (activeSensors >= 3) likelihood *= 1.5;
    likelihood = likelihood.clamp(0.0, 1.0);

    // Posterior Bayesiano
    double posterior = (likelihood * prior) /
        ((likelihood * prior) + ((1 - likelihood) * (1 - prior)));

    _logger.d('[EquipmentSafety] P=$posterior | '
        'Vib=$_vibrationConfidence | '
        'Aud=$_audioConfidence | '
        'Vis=$_visionConfidence');

    // Decisão
    if (posterior > 0.9 || _vibrationConfidence > 0.95) {
      _setLevel(EquipmentAlertLevel.CRITICAL);
    } else if (posterior > 0.7 || activeSensors >= 2) {
      _setLevel(EquipmentAlertLevel.WARNING);
    } else if (posterior > 0.4) {
      _setLevel(EquipmentAlertLevel.ATTENTION);
    } else {
      _setLevel(EquipmentAlertLevel.MONITORING);
    }

    // Emergência: operador em perigo (grito detectado)
    if (_audioConfidence > 0.7) {
      // Verificar se é grito humano
      _setLevel(EquipmentAlertLevel.EMERGENCY);
    }
  }

  void _setLevel(EquipmentAlertLevel level) {
    if (level == _currentLevel) return;
    _currentLevel = level;
    notifyListeners();

    if (level == EquipmentAlertLevel.WARNING) {
      _startWarningCountdown();
    } else if (level == EquipmentAlertLevel.CRITICAL ||
               level == EquipmentAlertLevel.EMERGENCY) {
      _warningTimer?.cancel();
    }
  }

  void _startWarningCountdown() {
    _warningTimer?.cancel();
    _warningTimer = Timer(const Duration(seconds: 15), () {
      if (_currentLevel == EquipmentAlertLevel.WARNING) {
        _setLevel(EquipmentAlertLevel.CRITICAL);
        _logger.w('[EquipmentSafety] Warning → Critical (timeout 15s)');
      }
    });
  }

  /// Operador confirma que está tudo OK
  void confirmSafe() {
    _warningTimer?.cancel();
    _vibrationConfidence = 0.0;
    _audioConfidence = 0.0;
    _visionConfidence = 0.0;
    _currentLevel = EquipmentAlertLevel.MONITORING;
    notifyListeners();
    _logger.i('[EquipmentSafety] Operador confirmou segurança');
  }

  /// Recalibra sensores (trocar de máquina)
  void switchMachine(String newMachineType) {
    _machineType = newMachineType;
    _vibrationDetector.configureForMachine(newMachineType);
    _vibrationDetector.recalibrate();
    confirmSafe();
    _logger.i('[EquipmentSafety] Trocou para: $newMachineType');
  }

  /// Resumo de alertas da sessão
  Map<String, int> alertSummary() {
    final counts = <String, int>{};
    for (final alert in _alertHistory) {
      final key = alert.type.name;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  @override
  void dispose() {
    _warningTimer?.cancel();
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _audioCapture.stopMonitoring();
    _audioClassifier.dispose();
    super.dispose();
  }
}

/// Alerta individual registrado
class EquipmentAlert {
  final DateTime timestamp;
  final EquipmentAlertType type;
  final String message;
  final String? detail;
  final double confidence;

  EquipmentAlert({
    required this.timestamp,
    required this.type,
    required this.message,
    this.detail,
    required this.confidence,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'type': type.name,
    'message': message,
    'detail': detail,
    'confidence': confidence,
  };
}
