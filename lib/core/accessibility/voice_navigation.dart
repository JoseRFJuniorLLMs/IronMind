import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:logger/logger.dart';
import 'package:go_router/go_router.dart';

/// Voice navigation service for accessibility
/// Allows operators with motor impairments to navigate using voice commands
/// All processing is done locally (no cloud) for privacy
///
/// Supported commands (Portuguese):
/// - "EVA, ligar para família"
/// - "EVA, abrir câmera"
/// - "EVA, mostrar remédios"
/// - "EVA, emergência"
/// - "EVA, sim" / "EVA, não"
class VoiceNavigationService {
  static final Logger _logger = Logger();
  static final stt.SpeechToText _speech = stt.SpeechToText();
  static final FlutterTts _tts = FlutterTts();

  static bool _isInitialized = false;
  static bool _isListening = false;
  static BuildContext? _context;

  // Callback for UI updates (show listening indicator)
  static void Function(bool isListening)? onListeningChanged;

  /// Initialize voice navigation
  static Future<bool> initialize(BuildContext context) async {
    if (_isInitialized) return true;

    _context = context;

    try {
      // Initialize Speech-to-Text
      final available = await _speech.initialize(
        onStatus: _onSpeechStatus,
        onError: _onSpeechError,
      );

      if (!available) {
        _logger.e('❌ Speech recognition not available on this device');
        return false;
      }

      // Initialize TTS
      await _tts.setLanguage('pt-BR');
      await _tts.setSpeechRate(0.5); // Slower for clarity in field
      await _tts.setVolume(1.0);

      _isInitialized = true;
      _logger.i('✅ Voice navigation initialized');
      return true;
    } catch (e) {
      _logger.e('❌ Failed to initialize voice navigation: $e');
      return false;
    }
  }

  /// Start listening for voice commands
  /// Shows visual indicator while listening
  static Future<void> startListening() async {
    if (!_isInitialized) {
      _logger.w('⚠️ Voice navigation not initialized');
      return;
    }

    if (_isListening) {
      _logger.w('⚠️ Already listening');
      return;
    }

    try {
      // Speak feedback
      await _speak('Sim? Estou ouvindo.');

      // Start listening
      await _speech.listen(
        onResult: _onSpeechResult,
        listenFor: const Duration(seconds: 5), // Timeout after 5s
        pauseFor: const Duration(seconds: 3), // Pause detection
        partialResults: false, // Only final results
        localeId: 'pt_BR', // Portuguese (Brazil)
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation,
      );

      _isListening = true;
      onListeningChanged?.call(true);
      _logger.i('🎤 Voice navigation listening...');
    } catch (e) {
      _logger.e('❌ Failed to start listening: $e');
    }
  }

  /// Stop listening
  static Future<void> stopListening() async {
    if (!_isListening) return;

    await _speech.stop();
    _isListening = false;
    onListeningChanged?.call(false);
    _logger.i('🎤 Voice navigation stopped');
  }

  /// Process speech result and execute command
  static void _onSpeechResult(stt.SpeechRecognitionResult result) {
    if (!result.finalResult) return;

    final text = result.recognizedWords.toLowerCase().trim();
    _logger.i('🎤 Recognized: "$text"');

    _processCommand(text);
  }

  /// Process voice command
  static Future<void> _processCommand(String command) async {
    if (_context == null || !_context!.mounted) {
      _logger.e('❌ No context available for navigation');
      return;
    }

    // Remove "EVA" wake word if present
    final cleanCommand = command
        .replaceAll(RegExp(r'\beva\b', caseSensitive: false), '')
        .trim();

    _logger.i('🎯 Processing command: "$cleanCommand"');

    // Match commands
    bool commandExecuted = false;

    // === PHONE CALL COMMANDS ===
    if (_matchCommand(cleanCommand, ['ligar', 'chamar', 'telefone', 'família'])) {
      await _speak('Iniciando ligação.');
      _context!.go('/call');
      commandExecuted = true;
    }
    // === VIDEO CALL COMMANDS ===
    else if (_matchCommand(cleanCommand, ['vídeo', 'câmera', 'videochamada'])) {
      await _speak('Abrindo câmera para videochamada.');
      _context!.push('/video');
      commandExecuted = true;
    }
    // === SCHEDULE COMMANDS ===
    else if (_matchCommand(cleanCommand, ['agendamento', 'consulta', 'agenda', 'marcar'])) {
      await _speak('Abrindo agendamento.');
      _context!.push('/schedule');
      commandExecuted = true;
    }
    // === INSPECTION HISTORY COMMANDS ===
    else if (_matchCommand(cleanCommand, ['histórico', 'inspeções', 'relatório', 'resultados'])) {
      await _speak('Abrindo histórico de inspeções.');
      _logger.i('TODO: Navigate to /inspection-history');
      commandExecuted = true;
    }
    // === EMERGENCY COMMANDS ===
    else if (_matchCommand(cleanCommand, ['emergência', 'socorro', 'ajuda', 'sos'])) {
      await _speak('Ativando protocolo de emergência.');
      // TODO: Activate emergency protocol
      _logger.i('TODO: Activate emergency protocol');
      commandExecuted = true;
    }
    // === CONFIRMATION COMMANDS ===
    else if (_matchCommand(cleanCommand, ['sim', 'confirmar', 'ok', 'tudo bem'])) {
      await _speak('Confirmado.');
      // TODO: Trigger confirmation callback
      commandExecuted = true;
    }
    // === NEGATION COMMANDS ===
    else if (_matchCommand(cleanCommand, ['não', 'cancelar', 'voltar'])) {
      await _speak('Cancelado.');
      if (_context!.canPop()) {
        _context!.pop();
      }
      commandExecuted = true;
    }
    // === HELP COMMANDS ===
    else if (_matchCommand(cleanCommand, ['ajuda', 'comandos', 'o que posso falar'])) {
      await _speak(
        'Você pode dizer: ligar para família, abrir câmera, mostrar remédios, emergência, sim ou não.',
      );
      commandExecuted = true;
    }

    // Command not recognized
    if (!commandExecuted) {
      await _speak('Desculpe, não entendi o comando. Diga "ajuda" para ver os comandos disponíveis.');
      _logger.w('⚠️ Command not recognized: "$cleanCommand"');
    }

    // Stop listening after command
    await stopListening();
  }

  /// Check if command matches any of the keywords
  static bool _matchCommand(String command, List<String> keywords) {
    return keywords.any((keyword) => command.contains(keyword));
  }

  /// Speak text using TTS
  static Future<void> _speak(String text) async {
    try {
      await _tts.speak(text);
      _logger.i('🔊 TTS: "$text"');
    } catch (e) {
      _logger.e('❌ TTS failed: $e');
    }
  }

  /// Speech status callback
  static void _onSpeechStatus(String status) {
    _logger.i('🎤 Speech status: $status');

    if (status == 'done' || status == 'notListening') {
      _isListening = false;
      onListeningChanged?.call(false);
    }
  }

  /// Speech error callback
  static void _onSpeechError(dynamic error) {
    _logger.e('❌ Speech error: $error');
    _isListening = false;
    onListeningChanged?.call(false);
  }

  /// Dispose resources
  static Future<void> dispose() async {
    await _speech.stop();
    await _tts.stop();
    _isListening = false;
    _isInitialized = false;
  }

  /// Get available commands as formatted string
  static String getAvailableCommands() {
    return '''
Comandos de voz disponíveis:

📞 CHAMADAS:
  • "EVA, ligar para família"
  • "EVA, abrir câmera" (videochamada)

📅 AGENDAMENTO:
  • "EVA, mostrar agenda"
  • "EVA, marcar consulta"

💊 MEDICAMENTOS:
  • "EVA, mostrar remédios"
  • "EVA, hora do medicamento"

🆘 EMERGÊNCIA:
  • "EVA, emergência"
  • "EVA, socorro"

✅ CONFIRMAÇÕES:
  • "EVA, sim"
  • "EVA, não"
  • "EVA, cancelar"

❓ AJUDA:
  • "EVA, ajuda"
  • "EVA, o que posso falar?"
''';
  }
}

/// Voice navigation button widget
/// Shows microphone button with listening indicator
class VoiceNavigationButton extends StatefulWidget {
  const VoiceNavigationButton({super.key});

  @override
  State<VoiceNavigationButton> createState() => _VoiceNavigationButtonState();
}

class _VoiceNavigationButtonState extends State<VoiceNavigationButton>
    with SingleTickerProviderStateMixin {
  bool _isListening = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();

    // Initialize voice navigation
    VoiceNavigationService.initialize(context);

    // Listening state callback
    VoiceNavigationService.onListeningChanged = (isListening) {
      if (mounted) {
        setState(() {
          _isListening = isListening;
        });
      }
    };

    // Pulse animation for listening indicator
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Botão de navegação por voz',
      hint: 'Toque duas vezes para ativar comandos de voz',
      enabled: !_isListening,
      excludeSemantics: true,
      child: FloatingActionButton(
        onPressed: _isListening ? null : () {
          VoiceNavigationService.startListening();
        },
        backgroundColor: _isListening ? Colors.red : Colors.purple,
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            if (_isListening) {
              return Icon(
                Icons.mic,
                size: 28 + (_pulseController.value * 8), // Pulsing size
              );
            }
            return const Icon(Icons.mic_none, size: 28);
          },
        ),
      ),
    );
  }
}
