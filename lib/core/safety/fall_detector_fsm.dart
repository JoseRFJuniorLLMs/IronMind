import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:vector_math/vector_math.dart';

enum FallState {
  IDLE, // Estado normal
  PRE_FALL, // Perda de equilíbrio detectada
  FREE_FALL, // Queda livre confirmada
  IMPACT_DETECTED, // Impacto registrado
  POST_IMPACT, // Verificando pós-impacto
  FALL_CONFIRMED, // Queda confirmada
  FALSE_ALARM // Descartado
}

class FallDetectorFSM {
  // === CONFIGURAÇÕES CALIBRÁVEIS ===

  // Thresholds de Aceleração (ajustáveis por perfil de usuário)
  static const double FREEFALL_THRESHOLD = 0.5; // G
  static const double IMPACT_THRESHOLD_MIN = 2.5; // G
  static const double IMPACT_THRESHOLD_MAX =
      6.0; // G (> 6G pode ser falso positivo)
  static const double STILLNESS_THRESHOLD = 0.3; // G

  // Thresholds de Rotação
  static const double ROTATION_THRESHOLD = 120.0; // graus/segundo

  // Janelas Temporais
  static const Duration FREEFALL_MIN_DURATION = Duration(milliseconds: 100);
  static const Duration FREEFALL_MAX_DURATION = Duration(milliseconds: 600);
  static const Duration IMPACT_WINDOW = Duration(milliseconds: 200);
  static const Duration STILLNESS_CHECK_DURATION = Duration(seconds: 5);

  // === ESTADO INTERNO ===
  FallState _currentState = FallState.IDLE;
  DateTime? _stateEntryTime;

  // Buffers circulares para análise temporal
  final List<Vector3> _accelBuffer = [];
  final List<Vector3> _gyroBuffer = [];
  final List<double> _magnitudeBuffer = [];
  final int _bufferSize = 50; // 5 segundos @ 10Hz (100ms)

  // Métricas da queda candidata
  double? _freefallStartMagnitude;
  DateTime? _freefallStartTime;
  double? _impactMagnitude;
  DateTime? _impactTime;
  Vector3? _impactOrientation;

  // Callbacks
  final Function(FallEvent) onFallDetected;
  final Function(String) onDebugLog;

  FallDetectorFSM({
    required this.onFallDetected,
    required this.onDebugLog,
  });

  // === LOOP PRINCIPAL ===

  void processSensorData({
    required UserAccelerometerEvent accel,
    required GyroscopeEvent gyro,
  }) {
    // 1. Calcular métricas instantâneas
    Vector3 accelVec = Vector3(accel.x, accel.y, accel.z);
    Vector3 gyroVec = Vector3(gyro.x, gyro.y, gyro.z);

    double magnitude = accelVec.length;
    double rotationRate = _radToDeg(gyroVec.length);

    // 2. Atualizar buffers
    _updateBuffers(accelVec, gyroVec, magnitude);

    // 3. Máquina de Estados
    switch (_currentState) {
      case FallState.IDLE:
        _handleIdleState(magnitude, rotationRate);
        break;

      case FallState.PRE_FALL:
        _handlePreFallState(magnitude, rotationRate);
        break;

      case FallState.FREE_FALL:
        _handleFreeFallState(magnitude);
        break;

      case FallState.IMPACT_DETECTED:
        _handleImpactDetectedState(magnitude, accelVec);
        break;

      case FallState.POST_IMPACT:
        _handlePostImpactState();
        break;

      case FallState.FALL_CONFIRMED:
        // Estado final - já disparou alarme
        break;

      case FallState.FALSE_ALARM:
        _resetToIdle();
        break;
    }
  }

  // === HANDLERS DE ESTADO ===

  void _handleIdleState(double magnitude, double rotationRate) {
    // Detectar perda de equilíbrio
    if (magnitude < FREEFALL_THRESHOLD && rotationRate > ROTATION_THRESHOLD) {
      _transitionTo(FallState.PRE_FALL);
      onDebugLog('⚠️ Perda de equilíbrio detectada');
    }
  }

  void _handlePreFallState(double magnitude, double rotationRate) {
    // Confirmar início de queda livre
    if (magnitude < FREEFALL_THRESHOLD) {
      _freefallStartMagnitude = magnitude;
      _freefallStartTime = DateTime.now();
      _transitionTo(FallState.FREE_FALL);
      onDebugLog('🪂 Queda livre iniciada');
    } else if (_timeInState() > const Duration(milliseconds: 500)) {
      // Falso alarme - pessoa recuperou equilíbrio
      _transitionTo(FallState.FALSE_ALARM);
    }
  }

  void _handleFreeFallState(double magnitude) {
    Duration freefallDuration = _freefallStartTime != null
        ? DateTime.now().difference(_freefallStartTime!)
        : Duration.zero;

    // Detectar impacto (fim da queda livre)
    if (magnitude > IMPACT_THRESHOLD_MIN) {
      if (freefallDuration >= FREEFALL_MIN_DURATION &&
          freefallDuration <= FREEFALL_MAX_DURATION) {
        _impactMagnitude = magnitude;
        _impactTime = DateTime.now();
        _transitionTo(FallState.IMPACT_DETECTED);
        onDebugLog('💥 Impacto detectado: ${magnitude.toStringAsFixed(2)}G');
      } else {
        // Duração de queda livre inválida
        _transitionTo(FallState.FALSE_ALARM);
        onDebugLog(
            '❌ Duração de queda inválida: ${freefallDuration.inMilliseconds}ms');
      }
    } else if (freefallDuration > FREEFALL_MAX_DURATION) {
      // Queda livre muito longa (impossível em queda humana)
      _transitionTo(FallState.FALSE_ALARM);
    }
  }

  void _handleImpactDetectedState(double magnitude, Vector3 orientation) {
    // Verificar se impacto está dentro do range válido
    if (magnitude > IMPACT_THRESHOLD_MAX) {
      // Impacto muito forte - provavelmente celular jogado
      _transitionTo(FallState.FALSE_ALARM);
      onDebugLog('❌ Impacto excessivo: ${magnitude.toStringAsFixed(2)}G');
      return;
    }

    // Salvar orientação final
    _impactOrientation = orientation;

    // Iniciar verificação de imobilidade
    _transitionTo(FallState.POST_IMPACT);
    _scheduleStillnessCheck();
  }

  void _handlePostImpactState() {
    // Este estado aguarda o timer de stillness check
  }

  // === VERIFICAÇÃO DE IMOBILIDADE ===

  void _scheduleStillnessCheck() async {
    await Future.delayed(STILLNESS_CHECK_DURATION);

    if (_currentState != FallState.POST_IMPACT) return;

    // Analisar últimos 5 segundos de dados
    bool isStill = _analyzeStillness();
    bool orientationStable = _analyzeOrientationStability();

    if (isStill && orientationStable) {
      _transitionTo(FallState.FALL_CONFIRMED);
      _triggerFallAlarm();
    } else {
      _transitionTo(FallState.FALSE_ALARM);
      onDebugLog('✅ Movimento detectado - não é queda real');
    }
  }

  bool _analyzeStillness() {
    if (_magnitudeBuffer.length < 50) return false;

    // Calcular variância dos últimos dados
    var recent = _magnitudeBuffer.sublist(_magnitudeBuffer.length - 50);
    double mean = recent.reduce((a, b) => a + b) / recent.length;
    double variance =
        recent.map((x) => pow(x - mean, 2)).reduce((a, b) => a + b) /
            recent.length;

    double stdDev = sqrt(variance);

    onDebugLog('📊 Desvio padrão: ${stdDev.toStringAsFixed(3)}G');

    return stdDev < STILLNESS_THRESHOLD;
  }

  bool _analyzeOrientationStability() {
    if (_accelBuffer.length < 50) return false;

    var recent = _accelBuffer.sublist(_accelBuffer.length - 50);

    // Calcular variação angular
    double maxAngleChange = 0;
    for (int i = 1; i < recent.length; i++) {
      double angle = _angleBetween(recent[i], recent[i - 1]);
      if (angle > maxAngleChange) maxAngleChange = angle;
    }

    onDebugLog(
        '🧭 Variação angular máxima: ${maxAngleChange.toStringAsFixed(1)}°');

    return maxAngleChange < 5.0; // 5 graus de tolerância
  }

  // === TRIGGER DE ALARME ===

  void _triggerFallAlarm() {
    FallEvent event = FallEvent(
      timestamp: DateTime.now(),
      freefallDuration: _impactTime!.difference(_freefallStartTime!),
      impactMagnitude: _impactMagnitude!,
      finalOrientation: _impactOrientation!,
      confidence: _calculateConfidence(),
    );

    onDebugLog(
        '🚨 QUEDA CONFIRMADA - Confiança: ${event.confidence.toStringAsFixed(1)}%');
    onFallDetected(event);
  }

  double _calculateConfidence() {
    double score = 0.0;

    // Fator 1: Duração da queda livre (peso 30%)
    if (_freefallStartTime != null && _impactTime != null) {
      var duration =
          _impactTime!.difference(_freefallStartTime!).inMilliseconds;
      if (duration >= 200 && duration <= 400) {
        score += 30.0; // Duração ideal
      } else if (duration >= 100 && duration <= 600) {
        score += 20.0; // Duração aceitável
      }
    }

    // Fator 2: Magnitude do impacto (peso 30%)
    if (_impactMagnitude != null) {
      if (_impactMagnitude! >= 3.0 && _impactMagnitude! <= 4.5) {
        score += 30.0; // Impacto típico de queda
      } else if (_impactMagnitude! >= 2.5 && _impactMagnitude! <= 6.0) {
        score += 20.0;
      }
    }

    // Fator 3: Imobilidade pós-queda (peso 40%)
    if (_analyzeStillness() && _analyzeOrientationStability()) {
      score += 40.0;
    }

    return score;
  }

  // === UTILIDADES ===

  void _updateBuffers(Vector3 accel, Vector3 gyro, double magnitude) {
    _accelBuffer.add(accel);
    _gyroBuffer.add(gyro);
    _magnitudeBuffer.add(magnitude);

    if (_accelBuffer.length > _bufferSize) _accelBuffer.removeAt(0);
    if (_gyroBuffer.length > _bufferSize) _gyroBuffer.removeAt(0);
    if (_magnitudeBuffer.length > _bufferSize) _magnitudeBuffer.removeAt(0);
  }

  void _transitionTo(FallState newState) {
    _currentState = newState;
    _stateEntryTime = DateTime.now();
  }

  Duration _timeInState() {
    return DateTime.now().difference(_stateEntryTime ?? DateTime.now());
  }

  void _resetToIdle() {
    _currentState = FallState.IDLE;
    _freefallStartMagnitude = null;
    _freefallStartTime = null;
    _impactMagnitude = null;
    _impactTime = null;
    _impactOrientation = null;
  }

  double _radToDeg(double rad) => rad * 180 / pi;

  double _angleBetween(Vector3 a, Vector3 b) {
    double dot = a.dot(b);
    double cross = a.length * b.length;
    if (cross == 0) return 0;
    return acos((dot / cross).clamp(-1.0, 1.0)) * 180 / pi;
  }
}

class FallEvent {
  final DateTime timestamp;
  final Duration freefallDuration;
  final double impactMagnitude;
  final Vector3 finalOrientation;
  final double confidence; // 0-100%

  FallEvent({
    required this.timestamp,
    required this.freefallDuration,
    required this.impactMagnitude,
    required this.finalOrientation,
    required this.confidence,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'freefall_duration_ms': freefallDuration.inMilliseconds,
        'impact_magnitude_g': impactMagnitude,
        'orientation_x': finalOrientation.x,
        'orientation_y': finalOrientation.y,
        'orientation_z': finalOrientation.z,
        'confidence_percent': confidence,
      };
}
