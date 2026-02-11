import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:ironmind/iron/detection/yolo_engine.dart';

void main() {
  group('BoundingBox', () {
    test('center retorna Offset correto', () {
      final bbox = BoundingBox(
        xCenter: 0.5,
        yCenter: 0.3,
        width: 0.2,
        height: 0.4,
      );

      expect(bbox.center, const Offset(0.5, 0.3));
    });

    test('toRect converte para coordenadas absolutas', () {
      final bbox = BoundingBox(
        xCenter: 0.5,
        yCenter: 0.5,
        width: 0.2,
        height: 0.4,
      );
      const canvasSize = Size(640, 480);

      final rect = bbox.toRect(canvasSize);

      // Centro: (320, 240), largura: 128, altura: 192
      expect(rect.center.dx, closeTo(320.0, 0.01));
      expect(rect.center.dy, closeTo(240.0, 0.01));
      expect(rect.width, closeTo(128.0, 0.01));
      expect(rect.height, closeTo(192.0, 0.01));
    });

    test('toRect com bbox no canto superior esquerdo', () {
      final bbox = BoundingBox(
        xCenter: 0.1,
        yCenter: 0.1,
        width: 0.1,
        height: 0.1,
      );
      const canvasSize = Size(100, 100);

      final rect = bbox.toRect(canvasSize);

      expect(rect.center.dx, closeTo(10.0, 0.01));
      expect(rect.center.dy, closeTo(10.0, 0.01));
    });
  });

  group('Detection', () {
    test('isDefect retorna true para classe sem _ok', () {
      final det = Detection(
        bbox: BoundingBox(xCenter: 0.5, yCenter: 0.5, width: 0.1, height: 0.1),
        classId: 0,
        className: 'corrosao_grave',
        confidence: 0.85,
      );

      expect(det.isDefect, isTrue);
      expect(det.isOk, isFalse);
    });

    test('isOk retorna true para classe com _ok', () {
      final det = Detection(
        bbox: BoundingBox(xCenter: 0.5, yCenter: 0.5, width: 0.1, height: 0.1),
        classId: 1,
        className: 'pneu_ok',
        confidence: 0.95,
      );

      expect(det.isDefect, isFalse);
      expect(det.isOk, isTrue);
    });

    test('className com _ok no meio ainda é ok', () {
      final det = Detection(
        bbox: BoundingBox(xCenter: 0.5, yCenter: 0.5, width: 0.1, height: 0.1),
        classId: 2,
        className: 'freio_ok_esquerdo',
        confidence: 0.90,
      );

      expect(det.isOk, isTrue);
      expect(det.isDefect, isFalse);
    });
  });

  group('YoloInferenceEngine', () {
    test('initialize cai em modo demo quando modelos nao existem', () async {
      final engine = YoloInferenceEngine();
      final result = await engine.initialize();

      expect(result, isTrue);
      expect(engine.isInitialized, isTrue);
      expect(engine.isLoaded, isTrue);
      expect(engine.currentModelName, 'demo (sem modelo)');
    });

    test('predict retorna lista vazia quando nao inicializado', () async {
      final engine = YoloInferenceEngine();
      final result = await engine.predict(Uint8List(100));

      expect(result, isEmpty);
    });

    test('predict retorna lista vazia em modo demo', () async {
      final engine = YoloInferenceEngine();
      await engine.initialize();
      final result = await engine.predict(Uint8List(100));

      // Demo mode retorna vazio (sem modelo real)
      expect(result, isEmpty);
    });

    test('dispose reseta estado', () async {
      final engine = YoloInferenceEngine();
      await engine.initialize();
      expect(engine.isInitialized, isTrue);

      engine.dispose();
      expect(engine.isInitialized, isFalse);
    });

    test('initialize com classNames customizadas', () async {
      final engine = YoloInferenceEngine(classNames: [
        'corrosao', 'trinca', 'vazamento', 'pneu_ok',
      ]);

      await engine.initialize();
      expect(engine.isInitialized, isTrue);
    });

    test('initialize com modelPath especifico falha graciosamente', () async {
      final engine = YoloInferenceEngine();
      final result = await engine.initialize(
        modelPath: 'assets/models/nonexistent.onnx',
      );

      // Deve cair nos fallbacks e eventualmente modo demo
      expect(result, isTrue);
      expect(engine.currentModelName, 'demo (sem modelo)');
    });
  });
}
