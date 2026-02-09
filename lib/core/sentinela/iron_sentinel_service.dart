import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:logger/logger.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../safety/vibration_detector_fsm.dart';

/// IronSentinel - Serviço de monitoramento contínuo de equipamentos em background
/// Refatorado do SentinelaService (monitoramento de saúde para inspeção industrial)
/// Monitora vibração via acelerômetro enquanto operador trabalha
class IronSentinelService {
  static final Logger _logger = Logger();

  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false, // Manual start - operador inicia inspeção
        isForegroundMode: true,
        notificationChannelId: 'iron_sentinel_channel',
        initialNotificationTitle: 'IronMind Sentinel',
        initialNotificationContent: 'Monitorando equipamento em tempo real',
        foregroundServiceNotificationId: 889,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
      ),
    );

    _logger.i('[IronSentinel] Serviço configurado');
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    _logger.i('[IronSentinel] Serviço iniciado');
    WakelockPlus.enable();

    final alertMachine = IndustrialAlertMachine(service);
    GyroscopeEvent? latestGyro;
    bool isMonitoring = true;

    // Ler tipo de máquina configurado
    final prefs = await SharedPreferences.getInstance();
    final machineType = prefs.getString('iron_machine_type') ?? 'trator';

    final vibrationDetector = VibrationDetectorFSM(
      onAnomalyDetected: (event) {
        _logger.w('[IronSentinel] ANOMALIA: ${event.type.name} '
            'conf=${event.confidence.toStringAsFixed(0)}%');
        alertMachine.registerAnomaly(
          event.type.name,
          'Pico: ${event.peakMagnitude.toStringAsFixed(2)}G | '
          'Freq: ${event.dominantFrequency.toStringAsFixed(1)}Hz | '
          'Conf: ${event.confidence.toStringAsFixed(0)}%',
          event.confidence,
        );
      },
      onDebugLog: (msg) => _logger.d(msg),
    );

    vibrationDetector.configureForMachine(machineType);

    // Iniciar sensores
    gyroscopeEventStream(samplingPeriod: const Duration(milliseconds: 100))
        .listen((gyro) {
      latestGyro = gyro;
    });

    userAccelerometerEventStream(
            samplingPeriod: const Duration(milliseconds: 100))
        .listen((accel) {
      if (isMonitoring && latestGyro != null) {
        vibrationDetector.processSensorData(
            accel: accel, gyro: latestGyro!);
      }
    });

    alertMachine.sendStatusUpdate();

    // Status periódico
    Timer.periodic(const Duration(seconds: 5), (timer) async {
      alertMachine.sendStatusUpdate();

      if (service is AndroidServiceInstance) {
        if (await service.isForegroundService()) {
          final calibrated = vibrationDetector.isCalibrated;
          final baseline = vibrationDetector.baseline.toStringAsFixed(3);
          service.setForegroundNotificationInfo(
            title: isMonitoring
                ? 'IronMind Sentinel - $machineType'
                : 'IronMind Sentinel - PAUSADO',
            content: calibrated
                ? 'Baseline: ${baseline}G | ${alertMachine.getCurrentLevel()}'
                : 'Calibrando sensores...',
          );
        }
      }
    });

    // Comandos
    service.on('pause_monitoring').listen((_) async {
      isMonitoring = false;
      _logger.i('[IronSentinel] Monitoramento pausado');
    });

    service.on('resume_monitoring').listen((_) async {
      isMonitoring = true;
      _logger.i('[IronSentinel] Monitoramento retomado');
    });

    service.on('switch_machine').listen((event) async {
      final newType = event?['machine_type'] as String? ?? 'trator';
      vibrationDetector.configureForMachine(newType);
      vibrationDetector.recalibrate();
      await prefs.setString('iron_machine_type', newType);
      _logger.i('[IronSentinel] Máquina alterada para: $newType');
    });

    service.on('recalibrate').listen((_) {
      vibrationDetector.recalibrate();
      _logger.i('[IronSentinel] Recalibrando sensores');
    });

    service.on('stop').listen((_) {
      isMonitoring = false;
      WakelockPlus.disable();
      service.stopSelf();
      _logger.i('[IronSentinel] Serviço encerrado');
    });

    service.on('user_confirmed_safe').listen((_) {
      alertMachine.operatorConfirmedSafe();
    });
  }

  static Future<void> start({String machineType = 'trator'}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('iron_machine_type', machineType);
    await FlutterBackgroundService().startService();
    _logger.i('[IronSentinel] Iniciado para: $machineType');
  }

  static Future<void> stop() async {
    FlutterBackgroundService().invoke('stop');
  }

  static Future<void> switchMachine(String machineType) async {
    FlutterBackgroundService().invoke('switch_machine', {
      'machine_type': machineType,
    });
  }

  static Future<void> recalibrate() async {
    FlutterBackgroundService().invoke('recalibrate');
  }

  static Future<void> pause() async {
    FlutterBackgroundService().invoke('pause_monitoring');
  }

  static Future<void> resume() async {
    FlutterBackgroundService().invoke('resume_monitoring');
  }

  static Future<void> confirmSafe() async {
    FlutterBackgroundService().invoke('user_confirmed_safe');
  }

  static Future<bool> isRunning() async {
    return await FlutterBackgroundService().isRunning();
  }
}

/// Máquina de estados de alerta industrial
enum IndustrialAlertLevel { normal, attention, warning, critical }

class IndustrialAlertMachine {
  final Logger _logger = Logger();
  final ServiceInstance _service;
  final FlutterTts _tts = FlutterTts();

  IndustrialAlertLevel _currentLevel = IndustrialAlertLevel.normal;
  final List<_AnomalyRecord> _recentAnomalies = [];
  Timer? _escalationTimer;
  bool _ttsInitialized = false;

  IndustrialAlertMachine(this._service) {
    _initTts();
    _service.on('user_confirmed_safe').listen((_) => operatorConfirmedSafe());
  }

  Future<void> _initTts() async {
    try {
      await _tts.setLanguage('pt-BR');
      await _tts.setSpeechRate(0.6); // Normal speed for operators
      await _tts.setVolume(1.0);
      _ttsInitialized = true;
    } catch (e) {
      _logger.e('[IronSentinel] TTS falhou: $e');
    }
  }

  void sendStatusUpdate() {
    _service.invoke('update', {
      'level': _currentLevel.name,
      'anomaly_count': _recentAnomalies.length,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  String getCurrentLevel() {
    switch (_currentLevel) {
      case IndustrialAlertLevel.normal:
        return 'Normal';
      case IndustrialAlertLevel.attention:
        return 'Atenção';
      case IndustrialAlertLevel.warning:
        return 'Alerta - Verificar equipamento';
      case IndustrialAlertLevel.critical:
        return 'CRITICO - Parar operação!';
    }
  }

  void registerAnomaly(String type, String details, double confidence) {
    final now = DateTime.now();
    _recentAnomalies.add(_AnomalyRecord(now, type, details, confidence));

    // Limpar anomalias antigas (>2 min)
    _recentAnomalies.removeWhere(
        (a) => now.difference(a.timestamp).inSeconds > 120);

    _evaluateLevel();
  }

  void _evaluateLevel() {
    final count = _recentAnomalies.length;
    final maxConf = _recentAnomalies.isEmpty
        ? 0.0
        : _recentAnomalies
            .map((a) => a.confidence)
            .reduce((a, b) => a > b ? a : b);

    // Pico crítico único com alta confiança
    if (maxConf > 90) {
      _escalateToWarning();
      return;
    }

    // Múltiplas anomalias
    if (count >= 3) {
      _escalateToWarning();
    } else if (count >= 1) {
      _currentLevel = IndustrialAlertLevel.attention;
      sendStatusUpdate();
    }
  }

  Future<void> _escalateToWarning() async {
    if (_currentLevel == IndustrialAlertLevel.warning ||
        _currentLevel == IndustrialAlertLevel.critical) return;

    _currentLevel = IndustrialAlertLevel.warning;
    sendStatusUpdate();

    // Vibrar
    try {
      final hasVibrator = await Vibration.hasVibrator() ?? false;
      if (hasVibrator) {
        Vibration.vibrate(
          pattern: [0, 800, 400, 800, 400, 800],
          intensities: [0, 255, 0, 255, 0, 255],
        );
      }
    } catch (_) {}

    // TTS
    if (_ttsInitialized) {
      final lastAnomaly = _recentAnomalies.isNotEmpty
          ? _recentAnomalies.last.type
          : 'desconhecida';
      await _tts.speak(
        'Atenção! Anomalia detectada no equipamento. '
        'Tipo: $lastAnomaly. '
        'Verifique o equipamento ou confirme que está tudo bem.',
      );
    }

    // Notificar UI
    _service.invoke('show_equipment_alert', {
      'type': _recentAnomalies.isNotEmpty ? _recentAnomalies.last.type : '',
      'details': _recentAnomalies.isNotEmpty ? _recentAnomalies.last.details : '',
      'timeout': 20,
    });

    // Escalação automática em 20s
    _escalationTimer?.cancel();
    _escalationTimer = Timer(const Duration(seconds: 20), () {
      _escalateToCritical();
    });
  }

  Future<void> _escalateToCritical() async {
    _currentLevel = IndustrialAlertLevel.critical;
    sendStatusUpdate();

    _logger.e('[IronSentinel] CRITICO - Operação deve parar!');

    try {
      Vibration.vibrate(
        pattern: [0, 300, 150, 300, 150, 300, 150, 300],
        intensities: [0, 255, 0, 255, 0, 255, 0, 255],
      );
    } catch (_) {}

    if (_ttsInitialized) {
      await _tts.speak(
        'Alerta crítico! Pare a operação imediatamente! '
        'Anomalia grave detectada no equipamento.',
      );
    }

    // Registrar localização
    try {
      final position = await Geolocator.getCurrentPosition();
      _service.invoke('critical_alert', {
        'anomalies': _recentAnomalies.map((a) => {
          'type': a.type,
          'details': a.details,
          'confidence': a.confidence,
        }).toList(),
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      _service.invoke('critical_alert', {
        'anomalies': _recentAnomalies.map((a) => {
          'type': a.type,
          'details': a.details,
          'confidence': a.confidence,
        }).toList(),
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  void operatorConfirmedSafe() {
    _escalationTimer?.cancel();
    _currentLevel = IndustrialAlertLevel.normal;
    _recentAnomalies.clear();
    Vibration.cancel();
    sendStatusUpdate();

    if (_ttsInitialized) {
      _tts.speak('Confirmado. Continuando monitoramento.');
    }

    _service.invoke('dismiss_equipment_alert', {});
    _logger.i('[IronSentinel] Operador confirmou - voltando ao normal');
  }
}

class _AnomalyRecord {
  final DateTime timestamp;
  final String type;
  final String details;
  final double confidence;

  _AnomalyRecord(this.timestamp, this.type, this.details, this.confidence);
}
