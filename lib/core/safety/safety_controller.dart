import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../data/services/websocket_service.dart';
import '../../data/services/storage_service.dart';
import 'package:geolocator/geolocator.dart';

import 'fall_detector_fsm.dart';
import 'audio_classifier.dart';
import 'audio_capture_service.dart';

enum SafetyLevel {
  SAFE, // Tudo normal
  MONITORING, // Atenção aumentada
  PRE_ALERT, // Possível perigo
  ALERT, // Perigo confirmado
  EMERGENCY // Emergência ativa
}

enum EmergencyType {
  CONFIRMED_FALL,
  TIMEOUT,
  MANUAL_TRIGGER,
  AUDIO_DANGER,
}

class SafetyController extends ChangeNotifier {
  static final Logger _logger = Logger();

  // Serviços
  late FallDetectorFSM _fallDetector;
  late AudioCaptureService _audioMonitor;
  final WebSocketService _wsService = WebSocketService();

  // Estado
  SafetyLevel _currentLevel = SafetyLevel.SAFE;
  Timer? _preAlertTimer;

  // Bayesian Fusion - Acumulador de evidências
  double _fallConfidence = 0.0;
  double _audioConfidence = 0.0;
  final List<String> _detectedEvents = [];

  SafetyController() {
    _initializeServices();
  }

  void _initializeServices() {
    // Fall DetectorInitialization
    _fallDetector = FallDetectorFSM(
      onFallDetected: _handleFallDetected,
      onDebugLog: (msg) => _logger.d('[FALL_FSM] $msg'),
    );

    // Audio Monitor Initialization
    _audioMonitor = AudioCaptureService();
    _audioMonitor.dangerStream.listen(_handleAudioDanger);
  }

  Future<void> startMonitoring() async {
    // Iniciar sensores (Accelerometer + Gyroscope) otimizados para 100ms (10Hz)
    userAccelerometerEventStream(
            samplingPeriod: const Duration(milliseconds: 100))
        .listen((accel) {
      _processAccelEvent(accel);
    });

    gyroscopeEventStream(samplingPeriod: const Duration(milliseconds: 100))
        .listen((gyro) {
      _latestGyro = gyro;
    });

    // Iniciar áudio
    await _audioMonitor.startMonitoring();

    _currentLevel = SafetyLevel.MONITORING;
    notifyListeners();
    _logger.i('✅ SafetyController monitoring started');
  }

  GyroscopeEvent? _latestGyro;

  void _processAccelEvent(UserAccelerometerEvent accel) {
    if (_latestGyro != null) {
      _fallDetector.processSensorData(accel: accel, gyro: _latestGyro!);
    }
  }

  // === EVENT HANDLERS ===

  void _handleFallDetected(FallEvent event) {
    _fallConfidence = event.confidence / 100.0;
    _detectedEvents
        .add('Fall detected (${event.confidence.toStringAsFixed(1)}%)');

    _evaluateThreat();
  }

  void _handleAudioDanger(AudioClassificationResult result) {
    _audioConfidence = result.maxConfidence;
    _detectedEvents.add('Audio: ${result.detectedEvents.keys.join(", ")}');

    _evaluateThreat();
  }

  // === BAYESIAN DECISION FUSION ===

  void _evaluateThreat() {
    // Fusão Bayesiana Simplificada
    // P(Emergency | Fall, Audio) = P(Fall) * P(Audio) * Prior

    double prior = 0.1; // 10% de chance base
    double likelihood = 0.0;

    // Logic: if both are high, very high likelihood. If one is high, high likelihood.
    if (_fallConfidence > 0 && _audioConfidence > 0) {
      likelihood = (_fallConfidence + _audioConfidence) / 2.0; // Average
      if (likelihood > 0.8) likelihood = 0.95; // Boost if both present
    } else {
      likelihood = _fallConfidence > 0 ? _fallConfidence : _audioConfidence;
    }

    double posterior =
        (likelihood * prior) / ((likelihood * prior) + (1 - prior));

    _logger.d(
        '📊 Probabilidade de Emergência: ${(posterior * 100).toStringAsFixed(1)}% | Fall: $_fallConfidence | Audio: $_audioConfidence');

    // Regras de decisão
    if (posterior > 0.9 || _fallConfidence > 0.90) {
      _triggerEmergency(EmergencyType.CONFIRMED_FALL);
    } else if (posterior > 0.7) {
      _triggerPreAlert();
    } else if (_audioConfidence > 0.85 &&
        _detectedEvents.any((e) => e.contains('Scream'))) {
      _triggerPreAlert();
    }
  }

  void _triggerPreAlert() {
    if (_currentLevel == SafetyLevel.PRE_ALERT) return;

    _currentLevel = SafetyLevel.PRE_ALERT;
    notifyListeners();
    _logger.w('⚠️ PRE-ALERT Triggered');

    // Countdown de 10 segundos
    _preAlertTimer?.cancel();
    _preAlertTimer = Timer(const Duration(seconds: 10), () {
      _triggerEmergency(EmergencyType.TIMEOUT);
    });

    // Vibrar + Som (Implementado na UI ou serviço)
    // _playPreAlertSound();
  }

  Future<void> _triggerEmergency(EmergencyType type) async {
    if (_currentLevel == SafetyLevel.EMERGENCY) return;

    _currentLevel = SafetyLevel.EMERGENCY;
    notifyListeners();
    _logger.e('🚨 EMERGENCY ACTIVATED: $type');

    // Send WebSocket Alert
    await _sendWebSocketAlert(type);
  }

  Future<void> _sendWebSocketAlert(EmergencyType type) async {
    if (!_wsService.isConnected) await _wsService.connect();

    Position position;
    try {
      position = await Geolocator.getCurrentPosition();
    } catch (e) {
      position = Position(
          latitude: 0,
          longitude: 0,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0);
    }

    final idosoCpf = await StorageService.getIdosoCpf();

    _wsService.send({
      'type': 'sentinela_alert',
      'priority': 'CRITICAL',
      'alert_data': {
        'detection_source': 'SafetyController (${type.toString()})',
        'detection_details': 'Events: ${_detectedEvents.join(", ")}',
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': DateTime.now().toIso8601String(),
      },
      'idoso_cpf': idosoCpf,
    });
  }

  void cancelPreAlert() {
    _preAlertTimer?.cancel();
    _currentLevel = SafetyLevel.MONITORING;
    _fallConfidence = 0.0;
    _audioConfidence = 0.0;
    _detectedEvents.clear();
    notifyListeners();
    _logger.i('✅ Pre-Alert Cancelled by User');
  }

  SafetyLevel get currentLevel => _currentLevel;
  List<String> get recentEvents => _detectedEvents;
}
