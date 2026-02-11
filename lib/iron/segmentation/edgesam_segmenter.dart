import 'dart:typed_data';
import 'dart:math';
import 'dart:ui';

/// Máscara de segmentação retornada pelo EdgeSAM
class SegmentationMask {
  final Uint8List mask;
  final double iouScore;
  final Rect boundingBox;
  final double areaPercent;

  SegmentationMask({
    required this.mask,
    required this.iouScore,
    required this.boundingBox,
    this.areaPercent = 0.0,
  });
}

/// EdgeSAM - Segment Anything otimizado para mobile
///
/// 9.4MB INT8, 80ms latência, 30+ FPS na GPU/NPU
/// Lazy-loaded: só carrega quando YOLO detecta defeito
class EdgeSAMSegmenter {
  dynamic _session;
  bool _isLoaded = false;
  DateTime? _lastUsed;

  static const int inputSize = 1024;
  static const int _unloadAfterSeconds = 10;

  bool get isLoaded => _isLoaded;

  /// Lazy load - carrega em ~200ms quando necessário
  Future<void> ensureLoaded() async {
    if (_isLoaded) return;

    // TODO: Implementar com onnxruntime_flutter
    // final modelBytes = await rootBundle.load(
    //   'assets/models/segmentation/edgesam_int8.onnx');
    // _session = OrtSession.fromBuffer(
    //   modelBytes.buffer.asUint8List(),
    //   OrtSessionOptions()..appendExecutionProvider_Nnapi());

    _isLoaded = true;
    _lastUsed = DateTime.now();
  }

  /// Descarrega para liberar RAM (~100MB)
  Future<void> unload() async {
    if (!_isLoaded) return;
    // _session?.release();
    _session = null;
    _isLoaded = false;
  }

  /// Verifica se deve descarregar por inatividade
  bool shouldUnload() {
    if (!_isLoaded || _lastUsed == null) return false;
    return DateTime.now().difference(_lastUsed!).inSeconds > _unloadAfterSeconds;
  }

  /// Segmenta o defeito usando o centro do bounding box do YOLO
  ///
  /// [imageBytes] - Frame da câmera
  /// [defectCenter] - Centro do bounding box (normalizado 0-1)
  /// [imageSize] - Tamanho real da imagem
  Future<SegmentationMask> segment(
    Uint8List imageBytes,
    Offset defectCenter,
    Size imageSize,
  ) async {
    await ensureLoaded();
    _lastUsed = DateTime.now();

    // 1. Pré-processar imagem para 1024x1024
    final processedImage = _preprocessForSAM(imageBytes);

    // 2. Converter ponto normalizado para coordenadas SAM
    final pointX = defectCenter.dx * inputSize;
    final pointY = defectCenter.dy * inputSize;

    // 3. Inferência (80ms)
    // TODO: ONNX Runtime real
    // final imageOrt = OrtValueTensor.createTensorWithDataList(
    //   processedImage.toList(), [1, 3, inputSize, inputSize]);
    // final coordsOrt = OrtValueTensor.createTensorWithDataList(
    //   [pointX, pointY], [1, 1, 2]);
    // final labelsOrt = OrtValueTensor.createTensorWithDataList(
    //   [1.0], [1, 1]); // 1 = foreground
    //
    // final outputs = await _session.runAsync(OrtRunOptions(), {
    //   'image': imageOrt,
    //   'point_coords': coordsOrt,
    //   'point_labels': labelsOrt
    // });

    // 4. Extrair melhor máscara (maior IoU)
    final mask = Uint8List(inputSize * inputSize); // placeholder
    final iouScore = 0.85; // placeholder

    // 5. Calcular área do defeito
    final defectPixels = mask.where((p) => p > 128).length;
    final totalPixels = mask.length;
    final areaPercent = (defectPixels / totalPixels) * 100;

    // 6. Calcular bounding box da máscara
    final maskBbox = _maskToBoundingBox(mask, inputSize, inputSize);

    return SegmentationMask(
      mask: _toBinaryMask(mask),
      iouScore: iouScore,
      boundingBox: maskBbox,
      areaPercent: areaPercent,
    );
  }

  Float32List _preprocessForSAM(Uint8List imageBytes) {
    // Decode → Resize 1024x1024 → CHW → Normalize
    // TODO: implementar com package:image
    return Float32List(3 * inputSize * inputSize);
  }

  Uint8List _toBinaryMask(Uint8List rawMask) {
    final binary = Uint8List(rawMask.length);
    for (int i = 0; i < rawMask.length; i++) {
      binary[i] = rawMask[i] > 128 ? 255 : 0;
    }
    return binary;
  }

  Rect _maskToBoundingBox(Uint8List mask, int width, int height) {
    int minX = width, minY = height, maxX = 0, maxY = 0;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (mask[y * width + x] > 128) {
          minX = min(minX, x);
          minY = min(minY, y);
          maxX = max(maxX, x);
          maxY = max(maxY, y);
        }
      }
    }

    if (maxX <= minX || maxY <= minY) return Rect.zero;

    return Rect.fromLTRB(
      minX / width,
      minY / height,
      maxX / width,
      maxY / height,
    );
  }

  void dispose() {
    unload();
  }
}
