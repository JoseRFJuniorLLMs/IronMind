import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:ironmind/iron/segmentation/edgesam_segmenter.dart';

void main() {
  group('EdgeSAMSegmenter', () {
    late EdgeSAMSegmenter segmenter;

    setUp(() {
      segmenter = EdgeSAMSegmenter();
    });

    tearDown(() {
      segmenter.dispose();
    });

    test('inicia descarregado', () {
      expect(segmenter.isLoaded, isFalse);
    });

    test('ensureLoaded marca como carregado', () async {
      await segmenter.ensureLoaded();
      expect(segmenter.isLoaded, isTrue);
    });

    test('ensureLoaded é idempotente', () async {
      await segmenter.ensureLoaded();
      await segmenter.ensureLoaded();
      expect(segmenter.isLoaded, isTrue);
    });

    test('unload descarrega', () async {
      await segmenter.ensureLoaded();
      expect(segmenter.isLoaded, isTrue);

      await segmenter.unload();
      expect(segmenter.isLoaded, isFalse);
    });

    test('unload quando não carregado é no-op', () async {
      expect(segmenter.isLoaded, isFalse);
      await segmenter.unload(); // não deve lançar erro
      expect(segmenter.isLoaded, isFalse);
    });

    test('shouldUnload retorna false quando não carregado', () {
      expect(segmenter.shouldUnload(), isFalse);
    });

    test('shouldUnload retorna false logo após uso', () async {
      await segmenter.ensureLoaded();
      expect(segmenter.shouldUnload(), isFalse);
    });

    test('segment retorna máscara com dados corretos', () async {
      final result = await segmenter.segment(
        Uint8List(100),
        const Offset(0.5, 0.5),
        const Size(640, 480),
      );

      expect(result.mask, isNotNull);
      expect(result.mask.length, EdgeSAMSegmenter.inputSize * EdgeSAMSegmenter.inputSize);
      expect(result.iouScore, 0.85);
    });

    test('segment auto-carrega modelo', () async {
      expect(segmenter.isLoaded, isFalse);

      await segmenter.segment(
        Uint8List(100),
        const Offset(0.3, 0.7),
        const Size(1920, 1080),
      );

      expect(segmenter.isLoaded, isTrue);
    });

    test('dispose descarrega modelo', () async {
      await segmenter.ensureLoaded();
      segmenter.dispose();
      expect(segmenter.isLoaded, isFalse);
    });
  });

  group('SegmentationMask', () {
    test('construção com valores obrigatórios', () {
      final mask = SegmentationMask(
        mask: Uint8List.fromList([0, 255, 128, 0]),
        iouScore: 0.92,
        boundingBox: Rect.zero,
      );

      expect(mask.mask.length, 4);
      expect(mask.iouScore, 0.92);
      expect(mask.areaPercent, 0.0);
    });

    test('areaPercent é opcional com default 0.0', () {
      final mask = SegmentationMask(
        mask: Uint8List(10),
        iouScore: 0.8,
        boundingBox: const Rect.fromLTRB(0.1, 0.2, 0.9, 0.8),
        areaPercent: 15.5,
      );

      expect(mask.areaPercent, 15.5);
    });
  });
}
