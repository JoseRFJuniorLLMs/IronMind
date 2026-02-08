import 'dart:async';
import '../diagnosis/moondream_vlm.dart';

/// Comandos de voz suportados
enum VoiceCommand {
  diagnose,
  capture,
  identify,
  checkConfidence,
  next,
  save,
  confirm,
  reject,
  correctClass,
  severityHigh,
  dailySummary,
  defectCount,
  explain,
  sync,
  openHistory,
  openSettings,
  repeatLast,
}

/// Estatísticas do dia
class DailyStats {
  final int total;
  final int approved;
  final int rejected;
  final int uncertain;
  double get approvalRate => total > 0 ? (approved / total) * 100 : 0;

  DailyStats({
    this.total = 0,
    this.approved = 0,
    this.rejected = 0,
    this.uncertain = 0,
  });
}

/// Controlador de voz EVA integrado com IronMind
///
/// Reutiliza a infraestrutura do EVA-Mobile:
/// - Whisper Small Q5 (140MB) para STT offline
/// - Piper TTS pt-BR (15MB) para respostas faladas
/// - 16+ comandos de voz em português
class EVAVoiceController {
  final MoondreamDiagnostic _moondream;

  // Serviços de voz (do EVA-Mobile)
  // late NativeAudioService _audioService;
  // late WhisperSTT _stt;
  // late PiperTTS _tts;

  String? _lastSpokenText;
  bool _isListening = false;

  /// Mapeamento de palavras-chave para comandos
  final Map<String, VoiceCommand> _commandMap = {
    'diagnosticar': VoiceCommand.diagnose,
    'analisar': VoiceCommand.diagnose,
    'verificar': VoiceCommand.diagnose,
    'capturar': VoiceCommand.capture,
    'foto': VoiceCommand.capture,
    'fotografar': VoiceCommand.capture,
    'o que é isso': VoiceCommand.identify,
    'que peça é essa': VoiceCommand.identify,
    'identificar': VoiceCommand.identify,
    'está bom': VoiceCommand.checkConfidence,
    'tá bom': VoiceCommand.checkConfidence,
    'próxima peça': VoiceCommand.next,
    'próxima': VoiceCommand.next,
    'seguinte': VoiceCommand.next,
    'gravar defeito': VoiceCommand.save,
    'salvar': VoiceCommand.save,
    'registrar': VoiceCommand.save,
    'está correto': VoiceCommand.confirm,
    'correto': VoiceCommand.confirm,
    'confirmar': VoiceCommand.confirm,
    'sim': VoiceCommand.confirm,
    'não é isso': VoiceCommand.reject,
    'errado': VoiceCommand.reject,
    'incorreto': VoiceCommand.reject,
    'gravidade alta': VoiceCommand.severityHigh,
    'urgente': VoiceCommand.severityHigh,
    'crítico': VoiceCommand.severityHigh,
    'resumo do dia': VoiceCommand.dailySummary,
    'resumo': VoiceCommand.dailySummary,
    'estatísticas': VoiceCommand.dailySummary,
    'quantos defeitos': VoiceCommand.defectCount,
    'quantas reprovações': VoiceCommand.defectCount,
    'explicar': VoiceCommand.explain,
    'por quê': VoiceCommand.explain,
    'por que': VoiceCommand.explain,
    'enviar dados': VoiceCommand.sync,
    'sincronizar': VoiceCommand.sync,
    'sync': VoiceCommand.sync,
    'histórico': VoiceCommand.openHistory,
    'últimas inspeções': VoiceCommand.openHistory,
    'configurações': VoiceCommand.openSettings,
    'settings': VoiceCommand.openSettings,
    'repetir': VoiceCommand.repeatLast,
    'de novo': VoiceCommand.repeatLast,
  };

  /// Callbacks para ações na UI
  Function()? onDiagnose;
  Function()? onCapture;
  Function()? onNext;
  Function()? onSave;
  Function()? onConfirm;
  Function()? onReject;
  Function()? onOpenHistory;
  Function()? onOpenSettings;
  Function()? onSync;

  EVAVoiceController(this._moondream);

  bool get isListening => _isListening;

  /// Inicia a escuta de comando de voz
  Future<VoiceCommand?> processVoice() async {
    if (_isListening) return null;
    _isListening = true;

    try {
      // 1. Capturar áudio (16kHz mono PCM)
      // final audioStream = await _audioService.startCapture();

      // 2. STT com Whisper Small Q5 (180ms)
      // final transcription = await _stt.transcribe(audioStream);
      final transcription = ''; // placeholder

      // 3. Parse do comando
      final command = parseCommand(transcription);

      if (command != null) {
        await executeCommand(command, context: transcription);
      } else {
        await speak('Comando não reconhecido. Repita por favor.');
      }

      return command;
    } finally {
      _isListening = false;
    }
  }

  /// Parse texto em comando
  VoiceCommand? parseCommand(String text) {
    final lower = text.toLowerCase().trim();

    // Procura match mais longo primeiro (ex: "gravar defeito" antes de "gravar")
    final sortedKeys = _commandMap.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    for (final key in sortedKeys) {
      if (lower.contains(key)) {
        return _commandMap[key];
      }
    }

    return null;
  }

  /// Executa um comando de voz
  Future<void> executeCommand(VoiceCommand cmd, {String? context}) async {
    switch (cmd) {
      case VoiceCommand.diagnose:
        onDiagnose?.call();
        break;

      case VoiceCommand.capture:
        onCapture?.call();
        await speak('Capturando.');
        break;

      case VoiceCommand.next:
        onNext?.call();
        await speak('Próxima peça.');
        break;

      case VoiceCommand.save:
        onSave?.call();
        await speak('Defeito gravado.');
        break;

      case VoiceCommand.confirm:
        onConfirm?.call();
        await speak('Diagnóstico confirmado e salvo.');
        break;

      case VoiceCommand.reject:
        onReject?.call();
        await speak('Marcado para revisão.');
        break;

      case VoiceCommand.severityHigh:
        await speak('Gravidade alterada para alta.');
        break;

      case VoiceCommand.dailySummary:
        final stats = await _getDailyStats();
        await speak(
          'Hoje: ${stats.total} inspeções. '
          '${stats.approved} aprovadas, ${stats.rejected} reprovadas. '
          'Taxa: ${stats.approvalRate.toStringAsFixed(1)} por cento.',
        );
        break;

      case VoiceCommand.defectCount:
        final stats = await _getDailyStats();
        await speak('${stats.rejected} defeitos encontrados hoje.');
        break;

      case VoiceCommand.explain:
        await speak('Analisando. Aguarde.');
        // TODO: Buscar última inspeção e usar Moondream
        break;

      case VoiceCommand.sync:
        onSync?.call();
        await speak('Enviando dados.');
        break;

      case VoiceCommand.openHistory:
        onOpenHistory?.call();
        break;

      case VoiceCommand.openSettings:
        onOpenSettings?.call();
        break;

      case VoiceCommand.repeatLast:
        if (_lastSpokenText != null) {
          await speak(_lastSpokenText!);
        } else {
          await speak('Nada para repetir.');
        }
        break;

      default:
        await speak('Comando em desenvolvimento.');
    }
  }

  /// Sintetiza e fala texto via Piper TTS (50ms)
  Future<void> speak(String text) async {
    _lastSpokenText = text;

    // TODO: Implementar com Piper TTS
    // final audioBytes = await _tts.synthesize(
    //   text, voice: 'pt-BR-male', speed: 1.0);
    // await _audioService.play(audioBytes);
  }

  Future<DailyStats> _getDailyStats() async {
    // TODO: Buscar do repositório local
    return DailyStats(total: 0, approved: 0, rejected: 0, uncertain: 0);
  }

  void dispose() {
    _isListening = false;
  }
}
