import 'dart:async';
import 'package:flutter/foundation.dart';
import '../detection/yolo_engine.dart';
import '../segmentation/edgesam_segmenter.dart';
import '../voice/yamnet_classifier.dart';

/// Gerencia ciclo de vida dos modelos: load, unload, fallback
/// Hardware: GPU > NPU > DSP > CPU (via NNAPI delegate)
/// Otimiza RAM mantendo apenas modelos necessários carregados
enum ModelTier {
  /// Modelos sempre quentes (YOLO + YAMNet) ~18MB
  warm,

  /// Modelos sob demanda (EdgeSAM) ~100MB extra
  lazy,

  /// Modo economia (só YOLOv8n + YAMNet) ~8MB
  economy,
}

enum BatteryMode {
  full, // >30% - todos os modelos
  economy, // 20-30% - só YOLO26n
  critical, // <10% - só YOLOv8n (mais leve)
}

class ModelManager {
  final YoloInferenceEngine yoloEngine = YoloInferenceEngine();
  final EdgeSAMSegmenter edgeSAM = EdgeSAMSegmenter();
  final YAMNetClassifier yamnet = YAMNetClassifier();

  BatteryMode _batteryMode = BatteryMode.full;
  bool _isInitialized = false;

  Timer? _edgeSAMTimer;

  // Configurações de auto-unload (segundos)
  static const int _edgeSAMTimeout = 10;

  /// RAM estimada em uso pelos modelos locais (MB)
  /// Nota: Gemini Spatial é cloud, não consome RAM local
  int get estimatedRAMUsage {
    int ram = 0;
    if (yoloEngine.isLoaded) ram += 15; // YOLO26n INT8
    if (yamnet.isInitialized) ram += 3; // YAMNet TFLite
    if (edgeSAM.isLoaded) ram += 100; // EdgeSAM
    return ram;
  }

  /// Inicializa modelos warm (YOLO + YAMNet)
  /// Non-blocking: falhas individuais nao impedem o resto
  /// Hardware: GPU > NPU > DSP > CPU (via NNAPI)
  Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('[ModelManager] Inicializando modelos (GPU prioritario)...');

    // Carrega modelos em paralelo, sem bloquear se algum falhar
    await Future.wait([
      _safeInit('YOLO', () => yoloEngine.initialize()),
      _safeInit('YAMNet', () => yamnet.initialize()),
    ]);

    _isInitialized = true;
    debugPrint('[ModelManager] Init completo. RAM: ~${estimatedRAMUsage}MB');
  }

  /// Wrapper seguro: falha individual nao propaga
  Future<void> _safeInit(String name, Future<dynamic> Function() init) async {
    try {
      await init().timeout(const Duration(seconds: 3));
      debugPrint('[ModelManager] $name: OK');
    } catch (e) {
      debugPrint('[ModelManager] $name falhou (continuando): $e');
    }
  }

  /// Atualiza modo bateria e ajusta modelos
  Future<void> updateBatteryMode(int batteryPercent) async {
    final newMode = _classifyBattery(batteryPercent);
    if (newMode == _batteryMode) return;

    final oldMode = _batteryMode;
    _batteryMode = newMode;
    debugPrint('[ModelManager] Bateria: $oldMode → $newMode ($batteryPercent%)');

    switch (newMode) {
      case BatteryMode.critical:
        // Descarrega tudo exceto YOLOv8n
        await edgeSAM.unload();
        // Força fallback para YOLOv8n (mais leve)
        if (yoloEngine.currentModelName != 'yolov8n') {
          await yoloEngine.initialize(modelPath: 'assets/models/detection/yolov8n_int8.onnx');
        }
        break;

      case BatteryMode.economy:
        // Descarrega modelos pesados
        await edgeSAM.unload();
        break;

      case BatteryMode.full:
        // Não faz nada - lazy models serão carregados sob demanda
        break;
    }
  }

  /// Garante EdgeSAM carregado (lazy load)
  /// Reseta timer de auto-unload
  Future<void> ensureEdgeSAM() async {
    if (_batteryMode != BatteryMode.full) {
      debugPrint('[ModelManager] EdgeSAM bloqueado: modo economia');
      return;
    }
    await edgeSAM.ensureLoaded();
    _resetEdgeSAMTimer();
  }

  /// Reseta timer de auto-unload do EdgeSAM
  void _resetEdgeSAMTimer() {
    _edgeSAMTimer?.cancel();
    _edgeSAMTimer = Timer(
      const Duration(seconds: _edgeSAMTimeout),
      () async {
        debugPrint('[ModelManager] EdgeSAM auto-unload (${_edgeSAMTimeout}s inativo)');
        await edgeSAM.unload();
      },
    );
  }

  BatteryMode _classifyBattery(int percent) {
    if (percent < 10) return BatteryMode.critical;
    if (percent < 30) return BatteryMode.economy;
    return BatteryMode.full;
  }

  /// Libera todos os recursos
  Future<void> dispose() async {
    _edgeSAMTimer?.cancel();
    await edgeSAM.unload();
    yamnet.dispose();
    yoloEngine.dispose();
    _isInitialized = false;
    debugPrint('[ModelManager] Todos os modelos descarregados');
  }
}
