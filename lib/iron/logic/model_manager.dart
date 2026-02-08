import 'dart:async';
import 'package:flutter/foundation.dart';
import '../detection/yolo_engine.dart';
import '../segmentation/edgesam_segmenter.dart';
import '../diagnosis/moondream_vlm.dart';
import '../voice/yamnet_classifier.dart';

/// Gerencia ciclo de vida dos modelos: load, unload, fallback
/// Otimiza RAM mantendo apenas modelos necessários carregados
enum ModelTier {
  /// Modelos sempre quentes (YOLO + YAMNet) ~410MB
  warm,

  /// Modelos sob demanda (EdgeSAM + Moondream) ~600MB extra
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
  final MoondreamDiagnostic moondream = MoondreamDiagnostic();
  final YAMNetClassifier yamnet = YAMNetClassifier();

  BatteryMode _batteryMode = BatteryMode.full;
  bool _isInitialized = false;

  Timer? _edgeSAMTimer;
  Timer? _moondreamTimer;

  // Configurações de auto-unload (segundos)
  static const int _edgeSAMTimeout = 10;
  static const int _moondreamTimeout = 30;

  /// RAM estimada em uso pelos modelos (MB)
  int get estimatedRAMUsage {
    int ram = 0;
    if (yoloEngine.isLoaded) ram += 15; // YOLO26n INT8
    if (yamnet.isInitialized) ram += 3; // YAMNet TFLite
    if (edgeSAM.isLoaded) ram += 100; // EdgeSAM
    if (moondream.isLoaded) ram += 500; // Moondream 0.5B
    return ram;
  }

  /// Inicializa modelos warm (YOLO + YAMNet)
  Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('[ModelManager] Inicializando modelos warm...');

    // Carrega YOLO (com fallback automático interno)
    final yoloOk = await yoloEngine.initialize();
    if (!yoloOk) {
      debugPrint('[ModelManager] ERRO: Nenhum modelo YOLO disponível!');
    }

    // Carrega YAMNet (3MB, rápido)
    await yamnet.initialize();

    _isInitialized = true;
    debugPrint('[ModelManager] Modelos warm prontos. RAM: ~${estimatedRAMUsage}MB');
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
        await moondream.unload();
        // Força fallback para YOLOv8n (mais leve)
        if (yoloEngine.currentModelName != 'yolov8n') {
          await yoloEngine.initialize(modelPath: 'assets/models/detection/yolov8n_int8.onnx');
        }
        break;

      case BatteryMode.economy:
        // Descarrega modelos pesados
        await edgeSAM.unload();
        await moondream.unload();
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

  /// Garante Moondream carregado (lazy load)
  /// Reseta timer de auto-unload
  Future<void> ensureMoondream() async {
    if (_batteryMode == BatteryMode.critical) {
      debugPrint('[ModelManager] Moondream bloqueado: modo crítico');
      return;
    }
    await moondream.ensureLoaded();
    _resetMoondreamTimer();
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

  /// Reseta timer de auto-unload do Moondream
  void _resetMoondreamTimer() {
    _moondreamTimer?.cancel();
    _moondreamTimer = Timer(
      const Duration(seconds: _moondreamTimeout),
      () async {
        debugPrint('[ModelManager] Moondream auto-unload (${_moondreamTimeout}s inativo)');
        await moondream.unload();
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
    _moondreamTimer?.cancel();
    await edgeSAM.unload();
    await moondream.unload();
    yamnet.dispose();
    yoloEngine.dispose();
    _isInitialized = false;
    debugPrint('[ModelManager] Todos os modelos descarregados');
  }
}
