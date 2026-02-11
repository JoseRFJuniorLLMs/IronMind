import 'package:flutter_test/flutter_test.dart';
import 'package:ironmind/iron/voice/eva_voice_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EVAVoiceController - Command Parsing', () {
    late EVAVoiceController controller;

    setUp(() {
      controller = EVAVoiceController();
    });

    test('diagnosticar → diagnose', () {
      expect(controller.parseCommand('diagnosticar'), VoiceCommand.diagnose);
    });

    test('analisar → diagnose', () {
      expect(controller.parseCommand('analisar'), VoiceCommand.diagnose);
    });

    test('verificar → diagnose', () {
      expect(controller.parseCommand('verificar'), VoiceCommand.diagnose);
    });

    test('capturar → capture', () {
      expect(controller.parseCommand('capturar'), VoiceCommand.capture);
    });

    test('foto → capture', () {
      expect(controller.parseCommand('foto'), VoiceCommand.capture);
    });

    test('fotografar → capture', () {
      expect(controller.parseCommand('fotografar'), VoiceCommand.capture);
    });

    test('o que é isso → identify', () {
      expect(controller.parseCommand('o que é isso'), VoiceCommand.identify);
    });

    test('que peça é essa → identify', () {
      expect(controller.parseCommand('que peça é essa'), VoiceCommand.identify);
    });

    test('próxima peça → next', () {
      expect(controller.parseCommand('próxima peça'), VoiceCommand.next);
    });

    test('próxima → next', () {
      expect(controller.parseCommand('próxima'), VoiceCommand.next);
    });

    test('seguinte → next', () {
      expect(controller.parseCommand('seguinte'), VoiceCommand.next);
    });

    test('gravar defeito → save', () {
      expect(controller.parseCommand('gravar defeito'), VoiceCommand.save);
    });

    test('salvar → save', () {
      expect(controller.parseCommand('salvar'), VoiceCommand.save);
    });

    test('registrar → save', () {
      expect(controller.parseCommand('registrar'), VoiceCommand.save);
    });

    test('confirmar → confirm', () {
      expect(controller.parseCommand('confirmar'), VoiceCommand.confirm);
    });

    test('está correto → confirm', () {
      expect(controller.parseCommand('está correto'), VoiceCommand.confirm);
    });

    test('sim → confirm', () {
      expect(controller.parseCommand('sim'), VoiceCommand.confirm);
    });

    test('não é isso → reject', () {
      expect(controller.parseCommand('não é isso'), VoiceCommand.reject);
    });

    test('errado → reject', () {
      expect(controller.parseCommand('errado'), VoiceCommand.reject);
    });

    test('gravidade alta → severityHigh', () {
      expect(controller.parseCommand('gravidade alta'), VoiceCommand.severityHigh);
    });

    test('urgente → severityHigh', () {
      expect(controller.parseCommand('urgente'), VoiceCommand.severityHigh);
    });

    test('crítico → severityHigh', () {
      expect(controller.parseCommand('crítico'), VoiceCommand.severityHigh);
    });

    test('resumo do dia → dailySummary', () {
      expect(controller.parseCommand('resumo do dia'), VoiceCommand.dailySummary);
    });

    test('estatísticas → dailySummary', () {
      expect(controller.parseCommand('estatísticas'), VoiceCommand.dailySummary);
    });

    test('quantos defeitos → defectCount', () {
      expect(controller.parseCommand('quantos defeitos'), VoiceCommand.defectCount);
    });

    test('explicar → explain', () {
      expect(controller.parseCommand('explicar'), VoiceCommand.explain);
    });

    test('por quê → explain', () {
      expect(controller.parseCommand('por quê'), VoiceCommand.explain);
    });

    test('sincronizar → sync', () {
      expect(controller.parseCommand('sincronizar'), VoiceCommand.sync);
    });

    test('enviar dados → sync', () {
      expect(controller.parseCommand('enviar dados'), VoiceCommand.sync);
    });

    test('histórico → openHistory', () {
      expect(controller.parseCommand('histórico'), VoiceCommand.openHistory);
    });

    test('configurações → openSettings', () {
      expect(controller.parseCommand('configurações'), VoiceCommand.openSettings);
    });

    test('repetir → repeatLast', () {
      expect(controller.parseCommand('repetir'), VoiceCommand.repeatLast);
    });

    test('de novo → repeatLast', () {
      expect(controller.parseCommand('de novo'), VoiceCommand.repeatLast);
    });

    test('case insensitive', () {
      expect(controller.parseCommand('DIAGNOSTICAR'), VoiceCommand.diagnose);
      expect(controller.parseCommand('Foto'), VoiceCommand.capture);
      expect(controller.parseCommand('URGENTE'), VoiceCommand.severityHigh);
    });

    test('texto com espaços extras', () {
      expect(controller.parseCommand('  diagnosticar  '), VoiceCommand.diagnose);
    });

    test('texto dentro de frase maior', () {
      expect(controller.parseCommand('por favor diagnosticar agora'), VoiceCommand.diagnose);
    });

    test('comando não reconhecido retorna null', () {
      expect(controller.parseCommand(''), isNull);
      expect(controller.parseCommand('abracadabra'), isNull);
      expect(controller.parseCommand('hello world'), isNull);
    });

    test('prioriza match mais longo', () {
      // "gravar defeito" (14 chars) deve ter prioridade sobre "gravar" se existisse
      // "resumo do dia" (13 chars) sobre "resumo" (6 chars)
      expect(controller.parseCommand('resumo do dia de trabalho'), VoiceCommand.dailySummary);
    });
  });

  group('EVAVoiceController - State', () {
    test('inicia sem estar ouvindo', () {
      final controller = EVAVoiceController();
      expect(controller.isListening, isFalse);
    });

    test('inicia sem estar falando', () {
      final controller = EVAVoiceController();
      expect(controller.isSpeaking, isFalse);
    });
  });

  group('DailyStats', () {
    test('valores default', () {
      final stats = DailyStats();
      expect(stats.total, 0);
      expect(stats.approved, 0);
      expect(stats.rejected, 0);
      expect(stats.uncertain, 0);
    });

    test('approvalRate calcula corretamente', () {
      final stats = DailyStats(total: 10, approved: 7, rejected: 3);
      expect(stats.approvalRate, 70.0);
    });

    test('approvalRate com zero total retorna 0', () {
      final stats = DailyStats();
      expect(stats.approvalRate, 0.0);
    });

    test('approvalRate com valores', () {
      final stats = DailyStats(total: 100, approved: 85, rejected: 10, uncertain: 5);
      expect(stats.approvalRate, 85.0);
    });
  });
}
