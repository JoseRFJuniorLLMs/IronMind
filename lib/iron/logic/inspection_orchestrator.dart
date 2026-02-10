import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../detection/yolo_engine.dart';
import '../segmentation/edgesam_segmenter.dart';
import '../diagnosis/gemini_spatial_engine.dart';
import '../voice/eva_voice_controller.dart';
import 'manual_lookup_service.dart';
import 'model_manager.dart';
import 'uncertainty_analyzer.dart';

/// Resultado completo de uma inspeção de frame
class InspectionResult {
  final List<Detection> detections;
  final SegmentationMask? segmentationMask;
  final SpatialAnalysisResult? spatialAnalysis;
  final double frameUrgency;
  final Duration inferenceTime;
  final String modelUsed;
  final String? manualText;
  final String? manualAction;

  InspectionResult({
    required this.detections,
    this.segmentationMask,
    this.spatialAnalysis,
    required this.frameUrgency,
    required this.inferenceTime,
    required this.modelUsed,
    this.manualText,
    this.manualAction,
  });

  bool get hasDefects => detections.any((d) => d.isDefect);
  int get defectCount => detections.where((d) => d.isDefect).length;
  bool get hasSpatialAnalysis => spatialAnalysis != null && spatialAnalysis!.components.isNotEmpty;
  bool get hasManualText => manualText != null && manualText!.isNotEmpty;
}

/// Pipeline principal de inspeção: Camera → YOLO → EdgeSAM → Gemini Spatial → TTS
/// Orquestra todos os modelos com decisões baseadas em incerteza
class InspectionOrchestrator {
  final ModelManager modelManager;
  final UncertaintyAnalyzer uncertainty;
  final GeminiSpatialEngine gemini;
  final ManualLookupService manualLookup;
  final EVAVoiceController? voiceController;

  // Estado
  bool _isRunning = false;
  int _frameCount = 0;
  int _defectsFound = 0;
  int _geminiCalls = 0;
  DateTime? _sessionStart;
  String _equipmentType = 'equipamento pesado';

  // Callbacks
  void Function(InspectionResult)? onResult;
  void Function(String)? onAlert;
  void Function(SpatialAnalysisResult)? onSpatialResult;

  InspectionOrchestrator({
    ModelManager? modelManager,
    UncertaintyAnalyzer? uncertainty,
    GeminiSpatialEngine? gemini,
    ManualLookupService? manualLookup,
    this.voiceController,
  })  : modelManager = modelManager ?? ModelManager(),
        uncertainty = uncertainty ?? UncertaintyAnalyzer(),
        gemini = gemini ?? GeminiSpatialEngine(),
        manualLookup = manualLookup ?? ManualLookupService();

  bool get isRunning => _isRunning;
  int get frameCount => _frameCount;
  int get defectsFound => _defectsFound;
  int get geminiCalls => _geminiCalls;

  /// Define tipo de equipamento para contexto do Gemini e ManualLookup
  void setEquipmentType(String type) {
    _equipmentType = type;
    manualLookup.setEquipmentType(type);
    debugPrint('[Orchestrator] Equipment type: $type');
  }

  /// Inicializa o pipeline (carrega modelos warm + manuais + Gemini key)
  Future<void> initialize() async {
    debugPrint('[Orchestrator] Inicializando pipeline de inspeção...');
    await Future.wait([
      modelManager.initialize(),
      manualLookup.initialize(),
      if (voiceController != null) voiceController!.initialize(),
    ]);

    // Configura Gemini com API key do .env
    final geminiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (geminiKey.isNotEmpty) {
      gemini.configure(geminiKey);
    }

    _sessionStart = DateTime.now();
    debugPrint('[Orchestrator] Pipeline pronto. '
        'Manuais: ${manualLookup.entryCount} entradas, '
        'Gemini: ${gemini.isConfigured ? "OK" : "sem key"}');
  }

  /// Processa um frame da câmera (chamado a cada ~33ms para 30fps)
  /// Este é o HOT PATH - precisa ser < 70ms no NPU
  Future<InspectionResult> processFrame(Uint8List imageBytes) async {
    final stopwatch = Stopwatch()..start();
    _frameCount++;

    // ─── STAGE 1: Detecção YOLO (22-35ms no NPU) ───
    final detections = await modelManager.yoloEngine.predict(imageBytes);
    final decisions = uncertainty.analyzeFrame(detections);
    final urgency = uncertainty.frameUrgency(detections);

    SegmentationMask? mask;
    SpatialAnalysisResult? spatialResult;

    // ─── STAGE 2: Segmentação EdgeSAM (se defeito detectado) ───
    final defects = detections.where((d) => d.isDefect).toList();
    if (defects.isNotEmpty) {
      _defectsFound += defects.length;

      // EdgeSAM no defeito mais confiante
      final topDefect = defects.reduce(
        (a, b) => a.confidence > b.confidence ? a : b,
      );

      try {
        await modelManager.ensureEdgeSAM();
        if (modelManager.edgeSAM.isLoaded) {
          final center = topDefect.bbox.center;
          mask = await modelManager.edgeSAM.segment(
            imageBytes,
            center,
            Size(640, 640),
          );
        }
      } catch (e) {
        debugPrint('[Orchestrator] EdgeSAM falhou: $e');
      }

      // ─── STAGE 3: Gemini Spatial (se incerteza média/baixa) ───
      final needsGeminiQuick = decisions.entries.any(
        (e) => e.value == AnalysisDecision.geminiQuick,
      );
      final needsGeminiDeep = decisions.entries.any(
        (e) => e.value == AnalysisDecision.geminiDeep,
      );

      if ((needsGeminiQuick || needsGeminiDeep) && gemini.isConfigured) {
        try {
          final budget = needsGeminiDeep ? 'large' : 'small';
          spatialResult = await gemini.analyze(
            imageBytes: imageBytes,
            detections: detections,
            equipmentType: _equipmentType,
            thinkingBudget: budget,
          );
          _geminiCalls++;
          onSpatialResult?.call(spatialResult);

          debugPrint('[Orchestrator] Gemini ($budget): '
              '${spatialResult.componentCount} componentes, '
              '${spatialResult.anomalyCount} anomalias, '
              '${spatialResult.latencyMs}ms');
        } catch (e) {
          debugPrint('[Orchestrator] Gemini falhou: $e');
        }
      }

      // ─── STAGE 4: Alerta por voz com texto do manual ───
      if (uncertainty.shouldAlert(detections) && voiceController != null) {
        // Prioridade: Gemini Spatial > Manual YAML > Mensagem genérica
        String alertMsg;
        if (spatialResult != null && spatialResult.anomalies.isNotEmpty) {
          alertMsg = spatialResult.ttsResume;
        } else if (manualLookup.isLoaded) {
          alertMsg = manualLookup.generateTTS(defects);
        } else {
          alertMsg = _buildAlertMessage(topDefect);
        }
        onAlert?.call(alertMsg);
        voiceController!.speak(alertMsg);
      }
    }

    // ─── STAGE 5: Texto do manual para display ───
    String? manualText;
    String? manualAction;
    if (manualLookup.isLoaded && detections.isNotEmpty) {
      manualText = manualLookup.generateTTS(detections);
      // Pega ação do defeito mais urgente
      final topDetection = detections.firstWhere(
        (d) => d.isDefect,
        orElse: () => detections.first,
      );
      final entry = manualLookup.lookupDetection(topDetection);
      manualAction = entry?.acao;
    }

    stopwatch.stop();

    final result = InspectionResult(
      detections: detections,
      segmentationMask: mask,
      spatialAnalysis: spatialResult,
      frameUrgency: urgency,
      inferenceTime: stopwatch.elapsed,
      modelUsed: modelManager.yoloEngine.currentModelName,
      manualText: manualText,
      manualAction: manualAction,
    );

    onResult?.call(result);
    return result;
  }

  /// Constrói mensagem de alerta para TTS
  String _buildAlertMessage(Detection defect) {
    final className = defect.className.replaceAll('_', ' ');
    final confidence = (defect.confidence * 100).toInt();
    return 'Atenção! $className detectado com $confidence por cento de confiança.';
  }

  /// Atualiza modo bateria
  Future<void> updateBattery(int percent) async {
    await modelManager.updateBatteryMode(percent);
  }

  /// Retorna resumo da sessão
  Map<String, dynamic> sessionSummary() {
    final duration = _sessionStart != null
        ? DateTime.now().difference(_sessionStart!)
        : Duration.zero;

    return {
      'frames_processados': _frameCount,
      'defeitos_encontrados': _defectsFound,
      'gemini_chamadas': _geminiCalls,
      'duracao_minutos': duration.inMinutes,
      'modelo_ativo': modelManager.yoloEngine.currentModelName,
      'ram_estimada_mb': modelManager.estimatedRAMUsage,
    };
  }

  /// Para o pipeline e libera recursos
  Future<void> dispose() async {
    _isRunning = false;
    await modelManager.dispose();
    debugPrint('[Orchestrator] Pipeline encerrado. '
        'Frames: $_frameCount, Defeitos: $_defectsFound');
  }
}
