import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:logger/logger.dart';

/// Multimodal alert system for accessibility
/// Ensures ALL users can perceive alerts regardless of disability:
/// - Deaf users: Vibration + Visual flash
/// - Blind users: TTS (Text-to-Speech) + Sound
/// - Low vision: Visual flash + TTS
/// - Cognitive impairment: Multiple channels reinforce message
enum AlertType {
  critical, // Emergencies, falls, medical alerts
  warning,  // Medication reminders, low battery
  info,     // Messages, general notifications
}

class MultimodalAlert {
  static final Logger _logger = Logger();
  static final AudioPlayer _audioPlayer = AudioPlayer();
  static final FlutterTts _tts = FlutterTts();

  // Pre-configured TTS settings
  static bool _ttsInitialized = false;

  /// Initialize TTS with Portuguese (Brazil) settings
  static Future<void> initTTS() async {
    if (_ttsInitialized) return;

    try {
      await _tts.setLanguage('pt-BR');
      await _tts.setSpeechRate(0.5); // Slower for elderly (0.0 = very slow, 1.0 = normal)
      await _tts.setVolume(1.0); // Maximum volume
      await _tts.setPitch(1.0); // Normal pitch
      _ttsInitialized = true;
      _logger.i('✅ TTS initialized for multimodal alerts');
    } catch (e) {
      _logger.e('❌ Failed to initialize TTS: $e');
    }
  }

  /// Shows a multimodal alert that can be perceived by everyone
  ///
  /// Channels activated simultaneously:
  /// 1. **Vibration** - For deaf users (Morse SOS pattern)
  /// 2. **Sound** - For low vision users (alert tone)
  /// 3. **Visual** - For deaf users (fullscreen flash)
  /// 4. **TTS** - For blind users (spoken message)
  ///
  /// Example:
  /// ```dart
  /// await MultimodalAlert.show(
  ///   context: context,
  ///   type: AlertType.critical,
  ///   message: 'Queda detectada! Verificando se você está bem.',
  /// );
  /// ```
  static Future<void> show({
    required BuildContext context,
    required AlertType type,
    required String message,
    Duration duration = const Duration(seconds: 5),
  }) async {
    _logger.i('🔔 Showing multimodal alert: $message (${type.name})');

    // Initialize TTS if not done yet
    if (!_ttsInitialized) {
      await initTTS();
    }

    // Execute all channels in parallel for immediate feedback
    await Future.wait([
      _vibrateAlert(type),
      _playSoundAlert(type),
      _showVisualAlert(context, type, message, duration),
      _speakAlert(message, type),
    ]);
  }

  /// Channel 1: Vibration (for deaf users)
  static Future<void> _vibrateAlert(AlertType type) async {
    try {
      // Check if device supports vibration
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator != true) {
        _logger.w('⚠️ Device does not support vibration');
        return;
      }

      // Different patterns for different alerts
      List<int> pattern;
      switch (type) {
        case AlertType.critical:
          // SOS in Morse code: ... --- ... (short-short-short long-long-long short-short-short)
          pattern = [
            0, 200, 200, 200, 200, 200, 200, // ... (S)
            400, 600, 400, 600, 400, 600, // --- (O)
            200, 200, 200, 200, 200, 200, // ... (S)
          ];
          break;
        case AlertType.warning:
          // Two long vibrations
          pattern = [0, 500, 300, 500];
          break;
        case AlertType.info:
          // Single short vibration
          pattern = [0, 300];
          break;
      }

      await Vibration.vibrate(pattern: pattern);
      _logger.i('✅ Vibration alert sent (${type.name})');
    } catch (e) {
      _logger.e('❌ Vibration failed: $e');
    }
  }

  /// Channel 2: Sound (for low vision users)
  /// Uses custom sound files if available, otherwise falls back to system feedback
  static Future<void> _playSoundAlert(AlertType type) async {
    try {
      String soundFile;
      double volume;

      switch (type) {
        case AlertType.critical:
          soundFile = 'sounds/alert_critical.mp3';
          volume = 1.0; // Maximum
          break;
        case AlertType.warning:
          soundFile = 'sounds/alert_warning.mp3';
          volume = 0.8;
          break;
        case AlertType.info:
          soundFile = 'sounds/alert_info.mp3';
          volume = 0.6;
          break;
      }

      // Try to play custom sound file
      try {
        await _audioPlayer.setVolume(volume);
        await _audioPlayer.play(AssetSource(soundFile));
        _logger.i('✅ Sound alert played (${type.name})');
      } catch (assetError) {
        // Fallback: Use system haptic feedback + notification sound
        _logger.w('⚠️ Custom sound not found, using system fallback');
        await _playSystemFallback(type);
      }
    } catch (e) {
      _logger.w('⚠️ Sound alert failed: $e');
      // Non-critical - other channels still work
    }
  }

  /// Fallback: System haptic feedback when custom sounds aren't available
  static Future<void> _playSystemFallback(AlertType type) async {
    try {
      switch (type) {
        case AlertType.critical:
          // Heavy impact feedback for critical alerts
          await HapticFeedback.heavyImpact();
          await Future.delayed(const Duration(milliseconds: 200));
          await HapticFeedback.heavyImpact();
          await Future.delayed(const Duration(milliseconds: 200));
          await HapticFeedback.heavyImpact();
          break;
        case AlertType.warning:
          // Medium impact for warnings
          await HapticFeedback.mediumImpact();
          await Future.delayed(const Duration(milliseconds: 300));
          await HapticFeedback.mediumImpact();
          break;
        case AlertType.info:
          // Light impact for info
          await HapticFeedback.lightImpact();
          break;
      }
      _logger.i('✅ System haptic feedback used as fallback');
    } catch (e) {
      _logger.w('⚠️ System fallback also failed: $e');
    }
  }

  /// Channel 3: Visual (for deaf users)
  static Future<void> _showVisualAlert(
    BuildContext context,
    AlertType type,
    String message,
    Duration duration,
  ) async {
    if (!context.mounted) return;

    Color color;
    IconData icon;

    switch (type) {
      case AlertType.critical:
        color = Colors.red;
        icon = Icons.warning_amber_rounded;
        break;
      case AlertType.warning:
        color = Colors.orange;
        icon = Icons.info_outline;
        break;
      case AlertType.info:
        color = Colors.blue;
        icon = Icons.notifications;
        break;
    }

    // Show fullscreen overlay with flashing animation
    final overlay = OverlayEntry(
      builder: (context) => _VisualAlertOverlay(
        color: color,
        icon: icon,
        message: message,
        duration: duration,
      ),
    );

    Overlay.of(context).insert(overlay);

    // Auto-remove after duration
    Future.delayed(duration, () {
      overlay.remove();
    });

    _logger.i('✅ Visual alert shown (${type.name})');
  }

  /// Channel 4: TTS (for blind users)
  static Future<void> _speakAlert(String message, AlertType type) async {
    try {
      // Add urgency prefix for critical alerts
      String spokenMessage = message;
      if (type == AlertType.critical) {
        spokenMessage = 'Atenção! Alerta crítico! $message';
      } else if (type == AlertType.warning) {
        spokenMessage = 'Aviso: $message';
      }

      await _tts.speak(spokenMessage);
      _logger.i('✅ TTS alert spoken (${type.name})');
    } catch (e) {
      _logger.e('❌ TTS failed: $e');
    }
  }

  /// Stops all ongoing alerts
  static Future<void> stopAll() async {
    await Future.wait([
      _audioPlayer.stop(),
      _tts.stop(),
      Vibration.cancel(),
    ]);
  }

  /// Quick alert presets for common scenarios

  static Future<void> showFallDetected(BuildContext context) async {
    await show(
      context: context,
      type: AlertType.critical,
      message: 'Queda detectada! Você está bem? Responda em 30 segundos ou ligaremos para a emergência.',
      duration: const Duration(seconds: 8),
    );
  }

  static Future<void> showMedicationReminder(BuildContext context, String medicationName) async {
    await show(
      context: context,
      type: AlertType.warning,
      message: 'Hora de tomar o medicamento: $medicationName',
      duration: const Duration(seconds: 5),
    );
  }

  static Future<void> showIncomingCall(BuildContext context, String callerName) async {
    await show(
      context: context,
      type: AlertType.info,
      message: 'Chamada recebida de $callerName',
      duration: const Duration(seconds: 4),
    );
  }

  static Future<void> showLowBattery(BuildContext context) async {
    await show(
      context: context,
      type: AlertType.warning,
      message: 'Bateria baixa. Conecte o carregador.',
      duration: const Duration(seconds: 4),
    );
  }

  static Future<void> showEmergencyActivated(BuildContext context) async {
    await show(
      context: context,
      type: AlertType.critical,
      message: 'Emergência ativada! Ligando para seu familiar em 10 segundos.',
      duration: const Duration(seconds: 6),
    );
  }
}

/// Visual alert overlay widget
class _VisualAlertOverlay extends StatefulWidget {
  final Color color;
  final IconData icon;
  final String message;
  final Duration duration;

  const _VisualAlertOverlay({
    required this.color,
    required this.icon,
    required this.message,
    required this.duration,
  });

  @override
  State<_VisualAlertOverlay> createState() => _VisualAlertOverlayState();
}

class _VisualAlertOverlayState extends State<_VisualAlertOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    // Pulsing opacity animation
    _opacityAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacityAnimation,
      builder: (context, child) {
        return Container(
          color: widget.color.withValues(alpha: _opacityAnimation.value * 0.3),
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(32),
              margin: const EdgeInsets.symmetric(horizontal: 40),
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.5),
                    blurRadius: 30,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.icon,
                    size: 80,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    widget.message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
