import 'package:flutter_test/flutter_test.dart';
import 'package:ironmind/iron/logic/manual_lookup_service.dart';
import 'package:ironmind/iron/detection/yolo_engine.dart';

Detection _det(String className, double confidence) {
  return Detection(
    bbox: BoundingBox(xCenter: 0.5, yCenter: 0.5, width: 0.1, height: 0.1),
    classId: 0,
    className: className,
    confidence: confidence,
  );
}

void main() {
  group('ManualEntry', () {
    test('isDefect para estado defeito', () {
      final entry = ManualEntry(
        className: 'corrosao_grave',
        nome: 'Corrosão Grave',
        estado: 'defeito',
        fala: 'Corrosão grave detectada no chassi.',
        acao: 'Lixar e aplicar tratamento anticorrosivo.',
        severidade: 'alta',
      );

      expect(entry.isDefect, isTrue);
      expect(entry.isCritical, isFalse);
    });

    test('isCritical para severidade critica', () {
      final entry = ManualEntry(
        className: 'freio_gasto',
        nome: 'Freio Gasto',
        estado: 'defeito',
        fala: 'Pastilha de freio abaixo do mínimo.',
        acao: 'Substituir pastilha imediatamente.',
        severidade: 'critica',
        prazo: 'imediato',
      );

      expect(entry.isDefect, isTrue);
      expect(entry.isCritical, isTrue);
      expect(entry.isImmediate, isTrue);
    });

    test('ttsText inclui acao para defeito', () {
      final entry = ManualEntry(
        className: 'vazamento',
        nome: 'Vazamento',
        estado: 'defeito',
        fala: 'Vazamento detectado.',
        acao: 'Trocar vedação.',
      );

      expect(entry.ttsText, contains('Vazamento detectado'));
      expect(entry.ttsText, contains('Acao recomendada'));
      expect(entry.ttsText, contains('Trocar vedação'));
    });

    test('ttsText retorna só fala para estado OK', () {
      final entry = ManualEntry(
        className: 'pneu_ok',
        nome: 'Pneu OK',
        estado: 'ok',
        fala: 'Pneu em bom estado.',
        acao: 'Nenhuma ação necessária.',
      );

      expect(entry.ttsText, 'Pneu em bom estado.');
      expect(entry.ttsText, isNot(contains('Acao recomendada')));
    });

    test('severityColor baseado em severidade', () {
      expect(
        ManualEntry(className: 'x', nome: '', estado: '', fala: '', acao: '', severidade: 'critica').severityColor,
        'red',
      );
      expect(
        ManualEntry(className: 'x', nome: '', estado: '', fala: '', acao: '', severidade: 'alta').severityColor,
        'orange',
      );
      expect(
        ManualEntry(className: 'x', nome: '', estado: '', fala: '', acao: '', severidade: 'media').severityColor,
        'yellow',
      );
      expect(
        ManualEntry(className: 'x', nome: '', estado: '', fala: '', acao: '', severidade: 'baixa').severityColor,
        'blue',
      );
      expect(
        ManualEntry(className: 'x', nome: '', estado: '', fala: '', acao: '').severityColor,
        'green',
      );
    });
  });

  group('ManualLookupService', () {
    test('inicia descarregado', () {
      final service = ManualLookupService();
      expect(service.isLoaded, isFalse);
      expect(service.entryCount, 0);
    });

    test('generateTTS com lista vazia', () {
      final service = ManualLookupService();
      final text = service.generateTTS([]);
      expect(text, 'Nenhum componente detectado no campo de visao.');
    });

    test('generateTTS retorna texto vazio quando nao há match', () {
      final service = ManualLookupService();
      final detections = [_det('classe_inexistente', 0.90)];
      // Sem entries carregadas, lookup retorna null
      final text = service.generateTTS(detections);
      // Com 0 entries matched, buffer fica vazio
      expect(text, isEmpty);
    });

    test('generateDisplayText com lista vazia', () {
      final service = ManualLookupService();
      expect(service.generateDisplayText([]), isEmpty);
    });

    test('lookup retorna null para classe inexistente', () {
      final service = ManualLookupService();
      expect(service.lookup('nao_existe'), isNull);
    });

    test('lookupDetection retorna null para classe inexistente', () {
      final service = ManualLookupService();
      expect(service.lookupDetection(_det('nao_existe', 0.9)), isNull);
    });
  });
}
