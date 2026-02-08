Vou criar um plano técnico detalhado e aprofundado focado exclusivamente na camada de **Sensores e Edge AI** para o EVA-Mobile.

---

# 📋 PLANO TÉCNICO COMPLETO: SISTEMA DE SEGURANÇA EDGE AI (EVA-Mobile)

## 🎯 Objetivo

Implementar um sistema de monitoramento de segurança completamente offline que detecte situações de risco (quedas, gritos, ausência de movimento) através de sensores do smartphone, com zero dependência de conectividade ou transcrição de voz.

---

## 🏗️ ARQUITETURA DO SISTEMA

### Camadas de Processamento

```
┌─────────────────────────────────────────────────────┐
│  CAMADA 1: HARDWARE SENSORS (Always-On)            │
│  • Acelerômetro (100Hz)                             │
│  • Giroscópio (50Hz)                                │
│  • Microfone (16kHz - Buffer Circular)              │
│  Consumo: ~2-5% bateria/hora                        │
└─────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│  CAMADA 2: SIGNAL PROCESSING (Edge - CPU)          │
│  • Filtros Kalman (Fusão IMU)                       │
│  • Feature Extraction (MFCC, Spectral)              │
│  • Windowing & Buffering                            │
└─────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│  CAMADA 3: INFERENCE ENGINES (Edge - NPU/GPU)      │
│  • Fall Detection FSM (Finite State Machine)        │
│  • YAMNet Audio Classifier (TFLite)                 │
│  • Activity Recognition Model                       │
└─────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│  CAMADA 4: DECISION LOGIC (Safety Controller)      │
│  • Bayesian Fusion (Multi-Sensor Confidence)        │
│  • False Positive Suppression                       │
│  • Emergency Trigger System                         │
└─────────────────────────────────────────────────────┘
```

---

## 📱 PARTE 1: DETECÇÃO DE QUEDAS (ADVANCED)

### 1.1 Arquitetura de Sensor Fusion

**Sensores Utilizados:**
- **Acelerômetro Linear** (Remove gravidade - mais preciso)
- **Giroscópio** (Detecta rotação súbita)
- **Magnetômetro** (Orientação espacial)
- **Barômetro** (Opcional - detecta mudança de altitude)

**Por que Sensor Fusion?**
- Acelerômetro sozinho: 70-80% de precisão (muitos falsos positivos)
- Acelerômetro + Giroscópio + Orientação: 92-95% de precisão

### 1.2 Física da Queda - Modelo Biomecânico

Uma queda humana passa por **5 fases distintas** que devem ser detectadas sequencialmente:

```
FASE 1: PRÉ-IMPACTO (0.0 - 0.3s)
├─ Perda de Equilíbrio
├─ Aceleração vertical reduz (<0.5G)
├─ Rotação do tronco (Giroscópio > 120°/s)
└─ Mudança brusca de orientação

FASE 2: QUEDA LIVRE (0.3 - 0.6s)
├─ Magnitude total ≈ 0G (freefall)
├─ Duração: 100-400ms
└─ Confirmação: Gyro mostra rotação contínua

FASE 3: IMPACTO (0.6 - 0.8s)
├─ Pico de aceleração > 2.5G
├─ Duração do pico: 50-200ms
├─ Eixo dominante: Y ou Z (dependendo do bolso/pescoço)
└─ Giroscópio registra parada súbita de rotação

FASE 4: PÓS-IMPACTO (0.8 - 1.5s)
├─ Possíveis quiques (2º pico menor)
├─ Estabilização gradual
└─ Orientação final definida

FASE 5: IMOBILIDADE (1.5s - 10s)
├─ Variância de aceleração < 0.3G
├─ Orientação estável (± 5°)
├─ Sem movimento detectável
└─ Padrão respiratório ausente (avançado)
```

### 1.3 Implementação: Máquina de Estados Finitos (FSM)

```dart
// safety_core/fall_detection/fall_detector_fsm.dart

import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:vector_math/vector_math.dart';

enum FallState {
  IDLE,              // Estado normal
  PRE_FALL,          // Perda de equilíbrio detectada
  FREE_FALL,         // Queda livre confirmada
  IMPACT_DETECTED,   // Impacto registrado
  POST_IMPACT,       // Verificando pós-impacto
  FALL_CONFIRMED,    // Queda confirmada
  FALSE_ALARM        // Descartado
}

class FallDetectorFSM {
  // === CONFIGURAÇÕES CALIBRÁVEIS ===
  
  // Thresholds de Aceleração (ajustáveis por perfil de usuário)
  static const double FREEFALL_THRESHOLD = 0.5;  // G
  static const double IMPACT_THRESHOLD_MIN = 2.5; // G
  static const double IMPACT_THRESHOLD_MAX = 6.0; // G (> 6G pode ser falso positivo)
  static const double STILLNESS_THRESHOLD = 0.3;  // G
  
  // Thresholds de Rotação
  static const double ROTATION_THRESHOLD = 120.0; // graus/segundo
  
  // Janelas Temporais
  static const Duration FREEFALL_MIN_DURATION = Duration(milliseconds: 100);
  static const Duration FREEFALL_MAX_DURATION = Duration(milliseconds: 600);
  static const Duration IMPACT_WINDOW = Duration(milliseconds: 200);
  static const Duration STILLNESS_CHECK_DURATION = Duration(seconds: 5);
  static const Duration PRE_ALARM_COUNTDOWN = Duration(seconds: 10);
  
  // === ESTADO INTERNO ===
  FallState _currentState = FallState.IDLE;
  DateTime? _stateEntryTime;
  
  // Buffers circulares para análise temporal
  final List<Vector3> _accelBuffer = [];
  final List<Vector3> _gyroBuffer = [];
  final List<double> _magnitudeBuffer = [];
  final int _bufferSize = 100; // 1 segundo @ 100Hz
  
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
    } else if (_timeInState() > Duration(milliseconds: 500)) {
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
        onDebugLog('❌ Duração de queda inválida: ${freefallDuration.inMilliseconds}ms');
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
    // A lógica real está em _scheduleStillnessCheck()
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
    double variance = recent
        .map((x) => pow(x - mean, 2))
        .reduce((a, b) => a + b) / recent.length;
    
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
    
    onDebugLog('🧭 Variação angular máxima: ${maxAngleChange.toStringAsFixed(1)}°');
    
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
    
    onDebugLog('🚨 QUEDA CONFIRMADA - Confiança: ${event.confidence.toStringAsFixed(1)}%');
    onFallDetected(event);
  }
  
  double _calculateConfidence() {
    double score = 0.0;
    
    // Fator 1: Duração da queda livre (peso 30%)
    if (_freefallStartTime != null && _impactTime != null) {
      var duration = _impactTime!.difference(_freefallStartTime!).inMilliseconds;
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

// === MODELO DE DADOS ===

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
```

---

## 📱 PARTE 2: DETECÇÃO DE ÁUDIO (GRITOS E SONS DE PERIGO)

### 2.1 Arquitetura de Processamento de Áudio

```dart
// safety_core/audio_detection/audio_classifier.dart

import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:fftea/fftea.dart';

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
      _interpreter = await Interpreter.fromAsset('models/yamnet.tflite');
      _isInitialized = true;
      print('✅ YAMNet carregado');
    } catch (e) {
      print('❌ Erro ao carregar YAMNet: $e');
    }
  }
  
  Future<AudioClassificationResult?> classifyAudio(Float32List audioSamples) async {
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
  
  Float32List _preprocessAudio(Float32List samples) {
    // Normalização
    double max = samples.reduce((a, b) => a.abs() > b.abs() ? a : b).abs();
    if (max > 0) {
      for (int i = 0; i < samples.length; i++) {
        samples[i] = samples[i] / max;
      }
    }
    return samples;
  }
  
  AudioClassificationResult _analyzeOutput(List<double> probabilities) {
    Map<String, double> detectedEvents = {};
    
    DANGER_CLASSES.forEach((className, classIndex) {
      double prob = probabilities[classIndex];
      double threshold = CLASS_THRESHOLDS[className]!;
      
      if (prob >= threshold) {
        detectedEvents[className] = prob;
      }
    });
    
    return AudioClassificationResult(
      detectedEvents: detectedEvents,
      maxConfidence: detectedEvents.values.isEmpty 
          ? 0.0 
          : detectedEvents.values.reduce((a, b) => a > b ? a : b),
      isDanger: detectedEvents.isNotEmpty,
    );
  }
  
  void dispose() {
    _interpreter.close();
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
```

### 2.2 Sistema de Captura de Áudio em Background

```dart
// safety_core/audio_detection/audio_capture_service.dart

import 'dart:async';
import 'dart:typed_data';
import 'package:record/record.dart';

class AudioCaptureService {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioEventClassifier _classifier = AudioEventClassifier();
  
  StreamController<AudioClassificationResult>? _resultStream;
  Timer? _captureTimer;
  
  bool _isRunning = false;
  
  Future<void> startMonitoring() async {
    if (_isRunning) return;
    
    await _classifier.initialize();
    _resultStream = StreamController<AudioClassificationResult>.broadcast();
    
    // Iniciar gravação contínua
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ),
    );
    
    // Processar chunks a cada 0.975s
    _captureTimer = Timer.periodic(
      Duration(milliseconds: 975),
      (_) => _processAudioChunk(),
    );
    
    _isRunning = true;
    print('🎤 Monitoramento de áudio iniciado');
  }
  
  Future<void> _processAudioChunk() async {
    try {
      // Capturar chunk de áudio
      var audioData = await _recorder.stop();
      
      if (audioData != null) {
        // Converter para Float32List
        var samples = await _convertToFloat32(audioData);
        
        // Classificar
        var result = await _classifier.classifyAudio(samples);
        
        if (result != null && result.isDanger) {
          _resultStream?.add(result);
        }
        
        // Reiniciar gravação imediatamente
        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.pcm16bits,
            sampleRate: 16000,
            numChannels: 1,
          ),
        );
      }
    } catch (e) {
      print('❌ Erro ao processar áudio: $e');
    }
  }
  
  Future<Float32List> _convertToFloat32(String audioPath) async {
    // Implementar conversão de arquivo PCM para Float32List
    // ...
    return Float32List(15600);
  }
  
  Stream<AudioClassificationResult> get dangerStream => _resultStream!.stream;
  
  Future<void> stopMonitoring() async {
    _isRunning = false;
    _captureTimer?.cancel();
    await _recorder.stop();
    await _resultStream?.close();
    _classifier.dispose();
  }
}
```

---

## 📱 PARTE 3: ORQUESTRAÇÃO E SISTEMA DE DECISÃO

```dart
// safety_core/safety_controller.dart

import 'dart:async';
import 'package:flutter/foundation.dart';

enum SafetyLevel {
  SAFE,           // Tudo normal
  MONITORING,     // Atenção aumentada
  PRE_ALERT,      // Possível perigo
  ALERT,          // Perigo confirmado
  EMERGENCY       // Emergência ativa
}

class SafetyController extends ChangeNotifier {
  // Serviços
  late FallDetectorFSM _fallDetector;
  late AudioCaptureService _audioMonitor;
  
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
    // Fall Detector
    _fallDetector = FallDetectorFSM(
      onFallDetected: _handleFallDetected,
      onDebugLog: (msg) => debugPrint('[FALL] $msg'),
    );
    
    // Audio Monitor
    _audioMonitor = AudioCaptureService();
    _audioMonitor.dangerStream.listen(_handleAudioDanger);
  }
  
  Future<void> startMonitoring() async {
    // Iniciar sensores
    userAccelerometerEvents.listen((accel) {
      gyroscopeEvents.first.then((gyro) {
        _fallDetector.processSensorData(accel: accel, gyro: gyro);
      });
    });
    
    // Iniciar áudio
    await _audioMonitor.startMonitoring();
    
    _currentLevel = SafetyLevel.MONITORING;
    notifyListeners();
  }
  
  // === EVENT HANDLERS ===
  
  void _handleFallDetected(FallEvent event) {
    _fallConfidence = event.confidence / 100.0;
    _detectedEvents.add('Fall detected (${event.confidence.toStringAsFixed(1)}%)');
    
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
    double likelihood = _fallConfidence * _audioConfidence;
    double posterior = (likelihood * prior) / ((likelihood * prior) + (1 - prior));
    
    debugPrint('📊 Probabilidade de Emergência: ${(posterior * 100).toStringAsFixed(1)}%');
    
    // Regras de decisão
    if (posterior > 0.9 || _fallConfidence > 0.95) {
      _triggerEmergency(EmergencyType.CONFIRMED_FALL);
    } else if (posterior > 0.7) {
      _triggerPreAlert();
    } else if (_audioConfidence > 0.85 && _detectedEvents.any((e) => e.contains('Scream'))) {
      _triggerPreAlert();
    }
  }
  
  void _triggerPreAlert() {
    if (_currentLevel == SafetyLevel.PRE_ALERT) return;
    
    _currentLevel = SafetyLevel.PRE_ALERT;
    notifyListeners();
    
    // Countdown de 10 segundos
    _preAlertTimer = Timer(Duration(seconds: 10), () {
      _triggerEmergency(EmergencyType.TIMEOUT);
    });
    
    // Vibrar + Som
    _playPreAlertSound();
  }
  
  void _triggerEmergency(EmergencyType type) {
    _currentLevel = SafetyLevel.EMERGENCY;
    notifyListeners();
    
    // Aqui você chama o EvaWebViewService
    _activateEvaEmergencyMode();
  }
  
  void cancelPreAlert() {
    _preAlertTimer?.cancel();
    _currentLevel = SafetyLevel.MONITORING;
    _fallConfidence = 0.0;
    _audioConfidence = 0.0;
    _detectedEvents.clear();
    notifyListeners();
  }
  
  void _playPreAlertSound() {
    // TTS: "Detectei uma queda. Cancelando em 10 segundos..."
  }
  
  void _activateEvaEmergencyMode() {
    // Integração com o sistema que você já tem pronto
    debugPrint('🚨 ATIVANDO EVA - MODO EMERGÊNCIA');
  }
  
  SafetyLevel get currentLevel => _currentLevel;
  List<String> get recentEvents => _detectedEvents;
}

enum EmergencyType {
  CONFIRMED_FALL,
  TIMEOUT,
  MANUAL_TRIGGER,
}
```

---

## 📱 PARTE 4: BACKGROUND SERVICE (Executar 24/7)

```dart
// main.dart - Configuração do serviço background

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();
  
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'eva_safety_monitor',
      initialNotificationTitle: 'EVA Protegendo Você',
      initialNotificationContent: 'Monitoramento de segurança ativo',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
  
  service.startService();
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  final safetyController = SafetyController();
  await safetyController.startMonitoring();
  
  // Listener para enviar dados para a UI
  safetyController.addListener(() {
    service.invoke('update', {
      'level': safetyController.currentLevel.toString(),
      'events': safetyController.recentEvents,
    });
  });
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}
```

---

## 📊 PARTE 5: OTIMIZAÇÃO DE BATERIA

### Estratégias de Economia de Energia

```dart
class PowerOptimizer {
  // Duty Cycling Adaptativo
  static const Map<SafetyLevel, SensorConfig> POWER_PROFILES = {
    SafetyLevel.SAFE: SensorConfig(
      accelRate: 50,  // 50Hz
      audioEnabled: false,
      checkInterval: Duration(seconds: 2),
    ),
    SafetyLevel.MONITORING: SensorConfig(
      accelRate: 100, // 100Hz
      audioEnabled: true,
      checkInterval: Duration(milliseconds: 975),
    ),
    SafetyLevel.PRE_ALERT: SensorConfig(
      accelRate: 200, // 200Hz máximo
      audioEnabled: true,
      checkInterval: Duration(milliseconds: 500),
    ),
  };
}

class SensorConfig {
  final int accelRate;
  final bool audioEnabled;
  final Duration checkInterval;
  
  const SensorConfig({
    required this.accelRate,
    required this.audioEnabled,
    required this.checkInterval,
  });
}
```

---

## 📦 DEPENDÊNCIAS (pubspec.yaml)

```yaml
dependencies:
  # Sensores
  sensors_plus: ^6.0.1
  
  # Machine Learning
  tflite_flutter: ^0.11.0
  fftea: ^2.0.0
  
  # Áudio
  record: ^5.1.2
  
  # Background Service
  flutter_background_service: ^5.0.10
  flutter_local_notifications: ^18.0.1
  
  # Matemática
  vector_math: ^2.1.4
  
  # Utilidades
  permission_handler: ^11.3.1
  wakelock_plus: ^1.2.8
```

---

## 🧪 CALIBRAÇÃO E TESTES

### Protocolo de Testes Reais

1. **Teste de Queda Real (com proteção)**:
   - Colchão/tatame
   - Celular no bolso e no pescoço (colar)
   - 10 quedas de cada tipo: frontal, lateral, traseira

2. **Falsos Positivos**:
   - Jogar o celular na cama
   - Sentar bruscamente
   - Corrida
   - Subir/descer escadas rapidamente

3. **Gritos e Sons**:
   - Gritos reais em diferentes volumes
   - Música alta
   - TV com ação/horror
   - Conversas animadas

---

Este plano técnico cobre completamente a camada de sensores. Quer que eu detalhe alguma parte específica ou partir para a integração com seu sistema de voz?