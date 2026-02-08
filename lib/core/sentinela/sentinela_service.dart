import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:logger/logger.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/services/websocket_service.dart';
import '../../data/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../safety/fall_detector_fsm.dart';

/// 🛡️ SENTINELA - Background Fall Detection Service
/// Monitors for emergency keywords and triggers EVA alert cascade
class SentinelaService {
  static final Logger _logger = Logger();

  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId:
            'sentinela_channel', // ✅ Deve bater com main.dart
        initialNotificationTitle: '🛡️ Sentinela Ativo',
        initialNotificationContent: 'Monitorando sua segurança em tempo real',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
      ),
    );

    _logger.i('✅ Sentinela service configured');
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    _logger.i('🛡️ Sentinela service started');

    // Enable wake lock to keep service alive
    WakelockPlus.enable();

    // Initialize alert state machine with service reference for UI updates
    final alertMachine = AlertStateMachine(service);

    // ✅ Initialize Fall Detector (Accelerometer-based)
    // FASE 1: Removido Whisper - usando apenas acelerômetro
    GyroscopeEvent? latestGyro;
    bool isMonitoring = true;

    final fallDetector = FallDetectorFSM(
      onFallDetected: (event) {
        _logger.w('🚨 SENTINELA: QUEDA DETECTADA -> Confiança: ${event.confidence}%');
        alertMachine.registerDetection('Queda', 'Impacto: ${event.impactMagnitude.toStringAsFixed(2)}G');
        alertMachine.registerDetection('Queda', 'Duração queda livre: ${event.freefallDuration.inMilliseconds}ms');
        alertMachine.registerDetection('Queda', 'Confiança: ${event.confidence.toStringAsFixed(1)}%');
      },
      onDebugLog: (msg) => _logger.d('[FALL_FSM] $msg'),
    );

    // Start accelerometer monitoring
    _logger.i('📱 Starting Accelerometer Fall Detection...');

    gyroscopeEventStream(samplingPeriod: const Duration(milliseconds: 100))
        .listen((gyro) {
      latestGyro = gyro;
    });

    userAccelerometerEventStream(samplingPeriod: const Duration(milliseconds: 100))
        .listen((accel) {
      if (isMonitoring && latestGyro != null) {
        fallDetector.processSensorData(accel: accel, gyro: latestGyro!);
      }
    });

    _logger.i('✅ Fall detection initialized (Whisper REMOVED - FASE 1)');

    // ✅ Send initial status to UI
    alertMachine.sendStatusUpdate();

    // Update notification and UI periodically
    Timer.periodic(const Duration(seconds: 5), (timer) async {
      // Send status update to UI
      alertMachine.sendStatusUpdate();

      if (service is AndroidServiceInstance) {
        if (await service.isForegroundService()) {
          service.setForegroundNotificationInfo(
            title: isMonitoring ? "🛡️ Sentinela Ativo" : "🛡️ Sentinela: PAUSADO",
            content: "Status: ${alertMachine.getCurrentLevel()} (Acelerômetro)",
          );
        }
      }
    });

    // ✅ Listen for PAUSE command (from CallProvider)
    service.on('pause_monitoring').listen((event) async {
      _logger.i('🛡️ Sentinela: Received PAUSE command');
      isMonitoring = false;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('sentinela_mic_released', true); // Compatibilidade
      _logger.i('🛡️ Sentinela: Monitoring paused');
    });

    // ✅ Listen for RESUME command (from CallProvider)
    service.on('resume_monitoring').listen((event) async {
      _logger.i('🛡️ Sentinela: Received RESUME command');
      isMonitoring = true;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('sentinela_mic_released', false);
      _logger.i('🛡️ Sentinela: Monitoring resumed');
    });

    // Listen for stop command
    service.on('stop').listen((event) {
      _logger.i('🛑 Sentinela service stopping');
      isMonitoring = false;
      WakelockPlus.disable();
      service.stopSelf();
    });

    // ✅ Listen for test alert command (for debugging)
    service.on('test_alert').listen((event) {
      _logger.i('🛡️ TEST ALERT triggered');
      alertMachine.registerDetection('Teste', 'Alerta de teste manual');
      alertMachine.registerDetection('Teste', 'Alerta de teste manual');
      alertMachine.registerDetection('Teste', 'Alerta de teste manual');
    });

    // ✅ Listen for reset command
    service.on('reset_alert').listen((event) {
      _logger.i('🛡️ Alert state RESET');
      alertMachine.userConfirmedSafe();
    });
  }

  static Future<void> start() async {
    await FlutterBackgroundService().startService();
    _logger.i('✅ Sentinela service start requested');
  }

  static Future<void> stop() async {
    final service = FlutterBackgroundService();
    service.invoke('stop');
    _logger.i('🛑 Sentinela service stop requested');
  }

  /// ✅ FIX: Pause com confirmação - aguarda microfone ser liberado
  static Future<bool> pause({Duration timeout = const Duration(seconds: 3)}) async {
    final service = FlutterBackgroundService();
    final prefs = await SharedPreferences.getInstance();

    // Marcar como "aguardando pause"
    await prefs.setBool('sentinela_mic_released', false);

    service.invoke('pause_monitoring');
    _logger.i('🛡️ Sentinela pause requested, aguardando confirmação...');

    // Aguardar confirmação com timeout
    final startTime = DateTime.now();
    while (DateTime.now().difference(startTime) < timeout) {
      await Future.delayed(const Duration(milliseconds: 100));

      // Recarregar prefs para ver mudanças do outro isolate
      await prefs.reload();
      final released = prefs.getBool('sentinela_mic_released') ?? false;

      if (released) {
        _logger.i('🛡️ ✅ Sentinela confirmou: Microfone LIBERADO');
        return true;
      }
    }

    _logger.w('🛡️ ⚠️ Timeout aguardando confirmação do Sentinela (prosseguindo mesmo assim)');
    return false; // Timeout, mas prossegue
  }

  /// ✅ FIX: Resume com confirmação
  static Future<void> resume() async {
    final service = FlutterBackgroundService();
    final prefs = await SharedPreferences.getInstance();

    // Limpar flag de liberação
    await prefs.setBool('sentinela_mic_released', false);

    service.invoke('resume_monitoring');
    _logger.i('🛡️ Sentinela resume requested');
  }

  static Future<bool> isRunning() async {
    final service = FlutterBackgroundService();
    return await service.isRunning();
  }

  /// ✅ User confirmed safe - call from UI
  static Future<void> confirmUserSafe() async {
    final service = FlutterBackgroundService();
    service.invoke('user_confirmed_safe');
    _logger.i('🛡️ User confirmed safe sent to Sentinela');
  }

  /// ✅ Manual test trigger for debugging
  static Future<void> triggerTestAlert() async {
    final service = FlutterBackgroundService();
    service.invoke('test_alert');
    _logger.i('🛡️ Test alert triggered');
  }

  /// ✅ Reset alert state
  static Future<void> resetAlertState() async {
    final service = FlutterBackgroundService();
    service.invoke('reset_alert');
    _logger.i('🛡️ Alert state reset');
  }
}

/// Alert State Machine for Fall Detection
enum AlertLevel { normal, suspicious, warning, critical }

class AlertStateMachine {
  final Logger _logger = Logger();
  final WebSocketService _wsService = WebSocketService();
  final ServiceInstance _service;
  final FlutterTts _tts = FlutterTts();

  AlertLevel _currentLevel = AlertLevel.normal;
  final List<DateTime> _detectionHistory = [];
  Timer? _confirmationTimer;
  bool _ttsInitialized = false;

  AlertStateMachine(this._service) {
    _initTts();
    _listenForUserResponse();
  }

  Future<void> _initTts() async {
    try {
      await _tts.setLanguage('pt-BR');
      await _tts.setSpeechRate(0.5); // Slower for elderly
      await _tts.setVolume(1.0);
      _ttsInitialized = true;
      _logger.i('[SENTINELA] TTS initialized');
    } catch (e) {
      _logger.e('[SENTINELA] TTS init failed: $e');
    }
  }

  void _listenForUserResponse() {
    // Listen for user confirmation from UI
    _service.on('user_confirmed_safe').listen((event) {
      _logger.i('[SENTINELA] User confirmed safe via UI');
      userConfirmedSafe();
    });
  }

  /// Send status update to UI
  void sendStatusUpdate() {
    _service.invoke('update', {
      'level': _getSafetyLevelString(),
      'alertLevel': _currentLevel.name,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  String _getSafetyLevelString() {
    switch (_currentLevel) {
      case AlertLevel.normal:
        return 'SafetyLevel.SAFE';
      case AlertLevel.suspicious:
        return 'SafetyLevel.MONITORING';
      case AlertLevel.warning:
        return 'SafetyLevel.ALERT';
      case AlertLevel.critical:
        return 'SafetyLevel.EMERGENCY';
    }
  }

  String getCurrentLevel() {
    switch (_currentLevel) {
      case AlertLevel.normal:
        return 'Normal';
      case AlertLevel.suspicious:
        return 'Suspeito';
      case AlertLevel.warning:
        return 'Alerta - Aguardando confirmação';
      case AlertLevel.critical:
        return 'CRÍTICO - Emergência acionada';
    }
  }

  void registerDetection(String source, String details) {
    final now = DateTime.now();
    _detectionHistory.add(now);

    // Clean old detections (>60s)
    _detectionHistory
        .removeWhere((time) => now.difference(time).inSeconds > 60);

    _logger.i('[SENTINELA] Detecção registrada: $source - $details');
    _evaluateAlertLevel(source, details);
  }

  void _evaluateAlertLevel(String source, String details) {
    final recentCount = _detectionHistory.length;

    if (recentCount >= 3) {
      _escalateToWarning(source, details);
    } else if (recentCount >= 1) {
      _currentLevel = AlertLevel.suspicious;
      _logger.w('[SENTINELA] ⚠️ Detecção suspeita registrada');
      sendStatusUpdate(); // ✅ Notify UI
    }
  }

  Future<void> _escalateToWarning(String source, String details) async {
    _currentLevel = AlertLevel.warning;
    sendStatusUpdate(); // ✅ Notify UI immediately

    _logger.w('[SENTINELA] 🚨 ALERTA: Iniciando confirmação com usuário');

    // ✅ Vibration pattern: long-short-long
    try {
      final hasVibrator = await Vibration.hasVibrator() ?? false;
      if (hasVibrator) {
        Vibration.vibrate(pattern: [0, 1000, 500, 1000, 500, 1000], intensities: [0, 255, 0, 255, 0, 255]);
      }
    } catch (e) {
      _logger.e('[SENTINELA] Vibration error: $e');
    }

    // ✅ TTS announcement
    if (_ttsInitialized) {
      try {
        await _tts.speak('Atenção! Você está bem? Toque na tela para confirmar que está seguro.');
      } catch (e) {
        _logger.e('[SENTINELA] TTS error: $e');
      }
    }

    // ✅ Notify UI to show confirmation dialog
    _service.invoke('show_confirmation_dialog', {
      'source': source,
      'details': details,
      'timeout': 15,
    });

    // Wait 15 seconds for user response
    _confirmationTimer = Timer(const Duration(seconds: 15), () {
      _escalateToCritical(source, details);
    });
  }

  Future<void> userConfirmedSafe() async {
    _logger.i('[SENTINELA] ✅ Usuário confirmou estar seguro');
    _confirmationTimer?.cancel();
    _currentLevel = AlertLevel.normal;
    _detectionHistory.clear();
    sendStatusUpdate(); // ✅ Notify UI

    // ✅ Stop vibration
    Vibration.cancel();

    // ✅ Confirm via TTS
    if (_ttsInitialized) {
      await _tts.speak('Ótimo! Continuamos monitorando.');
    }

    // ✅ Notify UI to dismiss dialog
    _service.invoke('dismiss_confirmation_dialog', {});
  }

  Future<void> _escalateToCritical(String source, String details) async {
    _currentLevel = AlertLevel.critical;
    sendStatusUpdate(); // ✅ Notify UI immediately
    _logger.e('[SENTINELA] 🚨 ALERTA CRÍTICO - Acionando EVA Cascade');

    // ✅ Emergency vibration pattern (continuous)
    try {
      Vibration.vibrate(pattern: [0, 500, 200, 500, 200, 500, 200, 500], intensities: [0, 255, 0, 255, 0, 255, 0, 255]);
    } catch (e) {
      _logger.e('[SENTINELA] Vibration error: $e');
    }

    // ✅ TTS emergency announcement
    if (_ttsInitialized) {
      await _tts.speak('Emergência! Acionando contatos de emergência agora.');
    }

    // ✅ Notify UI about emergency
    _service.invoke('emergency_triggered', {
      'source': source,
      'details': details,
      'timestamp': DateTime.now().toIso8601String(),
    });

    try {
      // Get location
      final location = await _getLocation();

      // ✅ TRIGGER EVA CASCADE
      await _triggerEVACascade(source, details, location);

      // Send SMS to emergency contact
      await _sendEmergencySMS(location, source, details);

      // Call emergency contact
      await _callEmergencyContact();
    } catch (e) {
      _logger.e('[SENTINELA] ❌ Erro ao acionar emergência: $e');

      // Even if location fails, try to call emergency contact
      try {
        await _callEmergencyContact();
      } catch (_) {}
    }
  }

  Future<void> _triggerEVACascade(
    String source,
    String details,
    Position location,
  ) async {
    final cpf = StorageService.getIdosoCpf();
    if (cpf == null) {
      _logger.e('[SENTINELA] ❌ CPF não encontrado, não pode acionar cascade');
      return;
    }

    if (!_wsService.isConnected) {
      await _wsService.connect();
    }

    final sessionId = 'sentinela-${DateTime.now().millisecondsSinceEpoch}';

    // ✅ Send alert to backend (will trigger family cascade)
    _wsService.sendMessage({
      'type': 'sentinela_alert',
      'cpf': cpf,
      'session_id': sessionId,
      'alert_data': {
        'detection_source': source,
        'detection_details': details,
        'latitude': location.latitude,
        'longitude': location.longitude,
        'timestamp': DateTime.now().toIso8601String(),
        'alert_level': 'critical',
      }
    });

    _logger.i('[SENTINELA] ✅ Alerta enviado ao backend EVA');
  }

  Future<Position> _getLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    return await Geolocator.getCurrentPosition();
  }

  Future<void> _sendEmergencySMS(
    Position location,
    String source,
    String details,
  ) async {
    try {
      final contact = await _getEmergencyContact();
      final mapUrl =
          'https://maps.google.com/?q=${location.latitude},${location.longitude}';

      final message = '''ALERTA SENTINELA EVA - Possivel queda detectada! Deteccao: $source. Localizacao: $mapUrl - Verifique imediatamente.''';

      // ✅ Send SMS using url_launcher (opens SMS app with pre-filled message)
      final smsUri = Uri(
        scheme: 'sms',
        path: contact,
        queryParameters: {'body': message},
      );

      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
        _logger.i('[SENTINELA] ✅ SMS app launched with message to $contact');
      } else {
        _logger.w('[SENTINELA] ⚠️ Could not launch SMS app, trying direct...');
        // Fallback: try direct sms: URL
        final directUri = Uri.parse('sms:$contact?body=${Uri.encodeComponent(message)}');
        await launchUrl(directUri);
      }
    } catch (e) {
      _logger.e('[SENTINELA] ❌ Erro ao enviar SMS: $e');
    }
  }

  Future<void> _callEmergencyContact() async {
    try {
      final phone = await _getEmergencyContact();
      await FlutterPhoneDirectCaller.callNumber(phone);
      _logger.i('[SENTINELA] ✅ Ligação iniciada para $phone');
    } catch (e) {
      _logger.e('[SENTINELA] ❌ Erro ao ligar: $e');
    }
  }

  Future<String> _getEmergencyContact() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('emergency_contact') ?? '192'; // SAMU default
  }
}
