import 'dart:typed_data';
import 'dart:math';
import 'dart:io';
import 'dart:ui';

/// Resultado de uma detecção individual
class Detection {
  final BoundingBox bbox;
  final int classId;
  final String className;
  final double confidence;

  Detection({
    required this.bbox,
    required this.classId,
    required this.className,
    required this.confidence,
  });

  bool get isDefect => !className.contains('_ok');
  bool get isOk => className.contains('_ok');
}

/// Bounding box normalizada [0,1]
class BoundingBox {
  final double xCenter;
  final double yCenter;
  final double width;
  final double height;

  BoundingBox({
    required this.xCenter,
    required this.yCenter,
    required this.width,
    required this.height,
  });

  Offset get center => Offset(xCenter, yCenter);

  Rect toRect(Size canvasSize) {
    return Rect.fromCenter(
      center: Offset(xCenter * canvasSize.width, yCenter * canvasSize.height),
      width: width * canvasSize.width,
      height: height * canvasSize.height,
    );
  }
}

/// Motor de inferência YOLO com suporte a NPU via NNAPI
///
/// Suporta YOLO26n (primário), YOLO-NAS-S (fallback 1), YOLOv8n (fallback 2)
class YoloInferenceEngine {
  static const int inputSize = 640;
  static const double confidenceThreshold = 0.60;

  // OrtSession quando onnxruntime estiver disponível
  dynamic _session;
  bool _isInitialized = false;
  String _currentModel = '';

  final List<String> classNames;

  YoloInferenceEngine({this.classNames = const []});

  bool get isInitialized => _isInitialized;
  bool get isLoaded => _isInitialized;
  String get currentModel => _currentModel;
  String get currentModelName => _currentModel;

  /// Inicializa com o modelo primário (YOLO26n)
  /// Fallback automático para YOLO-NAS-S → YOLOv8n se falhar
  Future<bool> initialize({String? modelPath}) async {
    final models = [
      modelPath ?? 'assets/models/detection/yolo26n_ironmind_int8.onnx',
      'assets/models/detection/yolo_nas_s_int8.onnx',
      'assets/models/detection/yolov8n_int8.tflite',
    ];

    for (final model in models) {
      try {
        await _loadModel(model);
        _currentModel = model.split('/').last;
        _isInitialized = true;
        return true;
      } catch (e) {
        // Tenta próximo fallback
        continue;
      }
    }

    return false;
  }

  Future<void> _loadModel(String modelPath) async {
    // TODO: Implementar com onnxruntime_flutter ou tflite_flutter
    // final modelBytes = await rootBundle.load(modelPath);
    // final options = OrtSessionOptions()
    //   ..setIntraOpNumThreads(4)
    //   ..appendExecutionProvider_Nnapi(); // NPU Android
    // _session = OrtSession.fromBuffer(modelBytes.buffer.asUint8List(), options);
  }

  /// Executa inferência num frame da câmera
  /// Retorna lista de detecções com bounding boxes
  Future<List<Detection>> predict(Uint8List imageBytes) async {
    if (!_isInitialized) return [];

    final startTime = DateTime.now();

    // 1. Pré-processamento: RGB 640x640, normalizado [0,1]
    final preprocessed = _preprocessImage(imageBytes);

    // 2. Inferência NPU (22ms target)
    // TODO: Chamar _session.runAsync quando ONNX Runtime disponível
    final rawOutput = await _runInference(preprocessed);

    // 3. Pós-processamento (YOLO26 é NMS-free)
    final detections = _postProcess(rawOutput);

    final latency = DateTime.now().difference(startTime).inMilliseconds;

    return detections;
  }

  Float32List _preprocessImage(Uint8List imageBytes) {
    // Decode → Resize 640x640 → CHW → Normalize [0,1]
    // TODO: usar package:image para decode/resize
    final pixels = Float32List(3 * inputSize * inputSize);
    // Implementação real com img.decodeImage + img.copyResize
    return pixels;
  }

  Future<List<List<List<double>>>> _runInference(Float32List input) async {
    // TODO: ONNX Runtime inference real
    // final inputOrt = OrtValueTensor.createTensorWithDataList(
    //   input.toList(), [1, 3, inputSize, inputSize]);
    // final outputs = await _session.runAsync(OrtRunOptions(), {'images': inputOrt});
    return [[[]]]; // placeholder
  }

  List<Detection> _postProcess(List<List<List<double>>> output) {
    final detections = <Detection>[];

    if (output.isEmpty || output[0].isEmpty) return detections;

    final predictions = output[0];

    for (final pred in predictions) {
      if (pred.length < 5 + classNames.length) continue;

      final objectness = pred[4];
      if (objectness < confidenceThreshold) continue;

      // Classe com maior probabilidade
      final classProbs = pred.sublist(5);
      double maxProb = 0;
      int maxIdx = 0;
      for (int i = 0; i < classProbs.length; i++) {
        if (classProbs[i] > maxProb) {
          maxProb = classProbs[i];
          maxIdx = i;
        }
      }

      final confidence = objectness * maxProb;
      if (confidence < confidenceThreshold) continue;

      detections.add(Detection(
        bbox: BoundingBox(
          xCenter: pred[0],
          yCenter: pred[1],
          width: pred[2],
          height: pred[3],
        ),
        classId: maxIdx,
        className: maxIdx < classNames.length ? classNames[maxIdx] : 'unknown',
        confidence: confidence,
      ));
    }

    // YOLO26n é NMS-free, mas por segurança mantemos
    // um filtro simples para fallbacks (YOLO-NAS, v8n)
    if (!_currentModel.contains('yolo26')) {
      return _applyNMS(detections, iouThreshold: 0.5);
    }

    return detections;
  }

  List<Detection> _applyNMS(List<Detection> detections,
      {double iouThreshold = 0.5}) {
    if (detections.isEmpty) return detections;

    // Ordena por confiança decrescente
    final sorted = List<Detection>.from(detections)
      ..sort((a, b) => b.confidence.compareTo(a.confidence));

    final kept = <Detection>[];

    for (final det in sorted) {
      bool shouldKeep = true;
      for (final kept_det in kept) {
        if (_calculateIoU(det.bbox, kept_det.bbox) > iouThreshold) {
          shouldKeep = false;
          break;
        }
      }
      if (shouldKeep) kept.add(det);
    }

    return kept;
  }

  double _calculateIoU(BoundingBox a, BoundingBox b) {
    final aLeft = a.xCenter - a.width / 2;
    final aRight = a.xCenter + a.width / 2;
    final aTop = a.yCenter - a.height / 2;
    final aBottom = a.yCenter + a.height / 2;

    final bLeft = b.xCenter - b.width / 2;
    final bRight = b.xCenter + b.width / 2;
    final bTop = b.yCenter - b.height / 2;
    final bBottom = b.yCenter + b.height / 2;

    final interLeft = max(aLeft, bLeft);
    final interRight = min(aRight, bRight);
    final interTop = max(aTop, bTop);
    final interBottom = min(aBottom, bBottom);

    if (interRight <= interLeft || interBottom <= interTop) return 0.0;

    final interArea = (interRight - interLeft) * (interBottom - interTop);
    final aArea = a.width * a.height;
    final bArea = b.width * b.height;

    return interArea / (aArea + bArea - interArea);
  }

  void dispose() {
    // _session?.release();
    _isInitialized = false;
  }
}
