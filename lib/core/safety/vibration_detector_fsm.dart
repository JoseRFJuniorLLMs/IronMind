import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:vector_math/vector_math.dart';

/// Estados de anomalia de vibração em equipamentos industriais
enum VibrationState {
  NORMAL,          // Vibração dentro do padrão
  ELEVATED,        // Vibração acima do normal
  WARNING,         // Padrão de desgaste detectado
  CRITICAL_SPIKE,  // Pico crítico (impacto, quebra)
  ANOMALY_CONFIRMED, // Anomalia confirmada por múltiplos fatores
  FALSE_ALARM      // Descartado
}

/// Detector de anomalias de vibração via acelerômetro/giroscópio do tablet
/// Refatorado do FallDetectorFSM para uso industrial:
/// - Tablet encostado na máquina detecta padrões de vibração
/// - Identifica desgaste, desbalanceamento, impactos
class VibrationDetectorFSM {
  // === THRESHOLDS CALIBRÁVEIS POR TIPO DE MÁQUINA ===

  // Vibração normal (G) - acima disso = elevated
  double elevatedThreshold;
  // Vibração warning (G) - acima disso = desgaste provável
  double warningThreshold;
  // Pico crítico (G) - impacto ou quebra
  double criticalThreshold;
  // Rotação anômala (graus/s) - eixo desbalanceado
  double rotationAnomalyThreshold;

  // Janelas temporais
  static const Duration _elevatedMinDuration = Duration(seconds: 3);
  static const Duration _warningConfirmDuration = Duration(seconds: 5);
  static const Duration _spikeWindow = Duration(milliseconds: 500);

  // === ESTADO INTERNO ===
  VibrationState _currentState = VibrationState.NORMAL;
  DateTime? _stateEntryTime;

  // Buffers circulares para análise temporal (100 pontos = 10s @ 10Hz)
  final List<Vector3> _accelBuffer = [];
  final List<Vector3> _gyroBuffer = [];
  final List<double> _magnitudeBuffer = [];
  final int _bufferSize = 100;

  // Métricas da anomalia candidata
  double? _peakMagnitude;
  DateTime? _elevatedStartTime;
  double _avgBaseline = 0.0; // Baseline calculada nos primeiros 5s

  // Baseline calibration
  bool _isCalibrated = false;
  final List<double> _calibrationSamples = [];
  static const int _calibrationCount = 50; // 5s de amostras

  // Callbacks
  final Function(VibrationEvent) onAnomalyDetected;
  final Function(String) onDebugLog;

  VibrationDetectorFSM({
    required this.onAnomalyDetected,
    required this.onDebugLog,
    // Defaults para trator (ajustar por tipo de máquina)
    this.elevatedThreshold = 1.5,  // G
    this.warningThreshold = 3.0,   // G
    this.criticalThreshold = 6.0,  // G
    this.rotationAnomalyThreshold = 200.0, // graus/s
  });

  VibrationState get currentState => _currentState;
  bool get isCalibrated => _isCalibrated;
  double get baseline => _avgBaseline;

  /// Configura thresholds por tipo de máquina
  void configureForMachine(String machineType) {
    switch (machineType) {
      case 'trator':
        elevatedThreshold = 1.5;
        warningThreshold = 3.0;
        criticalThreshold = 6.0;
        rotationAnomalyThreshold = 200.0;
        break;
      case 'caminhao':
        elevatedThreshold = 1.2;
        warningThreshold = 2.5;
        criticalThreshold = 5.0;
        rotationAnomalyThreshold = 150.0;
        break;
      case 'mineracao':
        // Máquinas de mineração vibram mais naturalmente
        elevatedThreshold = 2.5;
        warningThreshold = 5.0;
        criticalThreshold = 8.0;
        rotationAnomalyThreshold = 300.0;
        break;
    }
    onDebugLog('[Vibration] Configurado para: $machineType');
  }

  // === LOOP PRINCIPAL ===

  void processSensorData({
    required UserAccelerometerEvent accel,
    required GyroscopeEvent gyro,
  }) {
    Vector3 accelVec = Vector3(accel.x, accel.y, accel.z);
    Vector3 gyroVec = Vector3(gyro.x, gyro.y, gyro.z);
    double magnitude = accelVec.length;
    double rotationRate = _radToDeg(gyroVec.length);

    _updateBuffers(accelVec, gyroVec, magnitude);

    // Calibração automática nos primeiros segundos
    if (!_isCalibrated) {
      _calibrate(magnitude);
      return;
    }

    // Magnitude relativa ao baseline
    double relativeMag = magnitude - _avgBaseline;

    switch (_currentState) {
      case VibrationState.NORMAL:
        _handleNormalState(relativeMag, rotationRate);
        break;
      case VibrationState.ELEVATED:
        _handleElevatedState(relativeMag, rotationRate);
        break;
      case VibrationState.WARNING:
        _handleWarningState(relativeMag, magnitude);
        break;
      case VibrationState.CRITICAL_SPIKE:
        _handleCriticalState(magnitude, accelVec);
        break;
      case VibrationState.ANOMALY_CONFIRMED:
        // Estado final - alarme disparado
        break;
      case VibrationState.FALSE_ALARM:
        _resetToNormal();
        break;
    }
  }

  // === CALIBRAÇÃO ===

  void _calibrate(double magnitude) {
    _calibrationSamples.add(magnitude);
    if (_calibrationSamples.length >= _calibrationCount) {
      _avgBaseline = _calibrationSamples.reduce((a, b) => a + b) /
          _calibrationSamples.length;
      _isCalibrated = true;
      onDebugLog('[Vibration] Baseline calibrada: ${_avgBaseline.toStringAsFixed(3)}G');
    }
  }

  /// Recalibra baseline (chamar quando muda de máquina)
  void recalibrate() {
    _isCalibrated = false;
    _calibrationSamples.clear();
    _resetToNormal();
    onDebugLog('[Vibration] Recalibrando...');
  }

  // === HANDLERS DE ESTADO ===

  void _handleNormalState(double relativeMag, double rotationRate) {
    if (relativeMag > criticalThreshold) {
      _peakMagnitude = relativeMag;
      _transitionTo(VibrationState.CRITICAL_SPIKE);
      onDebugLog('[Vibration] PICO CRITICO: ${relativeMag.toStringAsFixed(2)}G');
    } else if (relativeMag > elevatedThreshold) {
      _elevatedStartTime = DateTime.now();
      _transitionTo(VibrationState.ELEVATED);
      onDebugLog('[Vibration] Vibração elevada: ${relativeMag.toStringAsFixed(2)}G');
    }
  }

  void _handleElevatedState(double relativeMag, double rotationRate) {
    if (relativeMag > criticalThreshold) {
      _peakMagnitude = relativeMag;
      _transitionTo(VibrationState.CRITICAL_SPIKE);
      return;
    }

    if (relativeMag < elevatedThreshold * 0.8) {
      // Voltou ao normal
      _transitionTo(VibrationState.FALSE_ALARM);
      return;
    }

    // Se ficou elevada por tempo suficiente → warning
    if (_timeInState() > _elevatedMinDuration) {
      _transitionTo(VibrationState.WARNING);
      onDebugLog('[Vibration] WARNING: vibração elevada sustentada');
    }
  }

  void _handleWarningState(double relativeMag, double absoluteMag) {
    if (relativeMag > criticalThreshold) {
      _peakMagnitude = relativeMag;
      _transitionTo(VibrationState.CRITICAL_SPIKE);
      return;
    }

    if (relativeMag < elevatedThreshold * 0.5) {
      // Voltou ao normal por bastante margem
      _transitionTo(VibrationState.FALSE_ALARM);
      return;
    }

    // Se manteve warning por tempo suficiente → anomalia confirmada
    if (_timeInState() > _warningConfirmDuration) {
      _triggerAnomaly(VibrationAnomalyType.sustainedVibration);
    }
  }

  void _handleCriticalState(double magnitude, Vector3 accelVec) {
    // Pico crítico → confirma imediatamente
    _triggerAnomaly(VibrationAnomalyType.criticalSpike);
  }

  // === TRIGGER DE ANOMALIA ===

  void _triggerAnomaly(VibrationAnomalyType type) {
    _transitionTo(VibrationState.ANOMALY_CONFIRMED);

    final event = VibrationEvent(
      timestamp: DateTime.now(),
      type: type,
      peakMagnitude: _peakMagnitude ?? _getRecentPeak(),
      avgMagnitude: _getRecentAverage(),
      baseline: _avgBaseline,
      stdDeviation: _getRecentStdDev(),
      confidence: _calculateConfidence(type),
      dominantFrequency: _estimateDominantFrequency(),
    );

    onDebugLog('[Vibration] ANOMALIA: ${type.name} '
        'conf=${event.confidence.toStringAsFixed(0)}% '
        'peak=${event.peakMagnitude.toStringAsFixed(2)}G');
    onAnomalyDetected(event);
  }

  double _calculateConfidence(VibrationAnomalyType type) {
    double score = 0.0;

    // Fator 1: Intensidade relativa ao baseline (40%)
    double peak = _peakMagnitude ?? _getRecentPeak();
    double ratio = peak / (_avgBaseline + 0.01);
    if (ratio > 5.0) score += 40.0;
    else if (ratio > 3.0) score += 30.0;
    else if (ratio > 2.0) score += 20.0;

    // Fator 2: Duração da anomalia (30%)
    int duration = _timeInState().inSeconds;
    if (type == VibrationAnomalyType.criticalSpike) {
      score += 30.0; // Picos são sempre 100% na duração
    } else {
      if (duration > 10) score += 30.0;
      else if (duration > 5) score += 20.0;
      else score += 10.0;
    }

    // Fator 3: Consistência (desvio padrão baixo = consistente) (30%)
    double stdDev = _getRecentStdDev();
    if (stdDev < 0.5) score += 30.0; // Vibração consistente = desgaste
    else if (stdDev < 1.0) score += 20.0;
    else score += 10.0; // Alta variância = intermitente

    return score.clamp(0.0, 100.0);
  }

  // === ANÁLISE ESPECTRAL SIMPLIFICADA ===

  /// Estima frequência dominante via zero-crossing rate
  double _estimateDominantFrequency() {
    if (_magnitudeBuffer.length < 20) return 0.0;

    final recent = _magnitudeBuffer.sublist(
        _magnitudeBuffer.length - min(50, _magnitudeBuffer.length));
    double mean = recent.reduce((a, b) => a + b) / recent.length;

    int crossings = 0;
    for (int i = 1; i < recent.length; i++) {
      if ((recent[i - 1] - mean) * (recent[i] - mean) < 0) {
        crossings++;
      }
    }

    // Zero-crossing rate → frequência estimada
    // Sampling rate = 10Hz, cada crossing = meio ciclo
    double samplingRate = 10.0;
    return (crossings / 2.0) * (samplingRate / recent.length);
  }

  // === UTILIDADES ===

  double _getRecentPeak() {
    if (_magnitudeBuffer.isEmpty) return 0.0;
    final recent = _magnitudeBuffer.sublist(
        max(0, _magnitudeBuffer.length - 20));
    return recent.reduce((a, b) => a > b ? a : b);
  }

  double _getRecentAverage() {
    if (_magnitudeBuffer.isEmpty) return 0.0;
    final recent = _magnitudeBuffer.sublist(
        max(0, _magnitudeBuffer.length - 20));
    return recent.reduce((a, b) => a + b) / recent.length;
  }

  double _getRecentStdDev() {
    if (_magnitudeBuffer.length < 10) return 0.0;
    final recent = _magnitudeBuffer.sublist(
        max(0, _magnitudeBuffer.length - 20));
    double mean = recent.reduce((a, b) => a + b) / recent.length;
    double variance = recent.map((x) => pow(x - mean, 2)).reduce((a, b) => a + b) / recent.length;
    return sqrt(variance);
  }

  void _updateBuffers(Vector3 accel, Vector3 gyro, double magnitude) {
    _accelBuffer.add(accel);
    _gyroBuffer.add(gyro);
    _magnitudeBuffer.add(magnitude);
    if (_accelBuffer.length > _bufferSize) _accelBuffer.removeAt(0);
    if (_gyroBuffer.length > _bufferSize) _gyroBuffer.removeAt(0);
    if (_magnitudeBuffer.length > _bufferSize) _magnitudeBuffer.removeAt(0);
  }

  void _transitionTo(VibrationState newState) {
    _currentState = newState;
    _stateEntryTime = DateTime.now();
  }

  Duration _timeInState() {
    return DateTime.now().difference(_stateEntryTime ?? DateTime.now());
  }

  void _resetToNormal() {
    _currentState = VibrationState.NORMAL;
    _peakMagnitude = null;
    _elevatedStartTime = null;
  }

  double _radToDeg(double rad) => rad * 180 / pi;
}

/// Tipos de anomalia detectáveis
enum VibrationAnomalyType {
  sustainedVibration,  // Vibração elevada constante (desgaste)
  criticalSpike,       // Pico único (impacto, quebra)
  periodicAnomaly,     // Padrão periódico anormal (desbalanceamento)
}

/// Evento de anomalia de vibração
class VibrationEvent {
  final DateTime timestamp;
  final VibrationAnomalyType type;
  final double peakMagnitude;     // G
  final double avgMagnitude;      // G
  final double baseline;          // G (calibrado)
  final double stdDeviation;      // G
  final double confidence;        // 0-100%
  final double dominantFrequency; // Hz (estimada)

  VibrationEvent({
    required this.timestamp,
    required this.type,
    required this.peakMagnitude,
    required this.avgMagnitude,
    required this.baseline,
    required this.stdDeviation,
    required this.confidence,
    required this.dominantFrequency,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'type': type.name,
    'peak_magnitude_g': peakMagnitude,
    'avg_magnitude_g': avgMagnitude,
    'baseline_g': baseline,
    'std_deviation': stdDeviation,
    'confidence_percent': confidence,
    'dominant_frequency_hz': dominantFrequency,
  };
}
