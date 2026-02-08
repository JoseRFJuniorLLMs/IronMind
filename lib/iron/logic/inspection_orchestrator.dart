import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../detection/yolo_engine.dart';
import '../segmentation/edgesam_segmenter.dart';
import '../diagnosis/moondream_vlm.dart';
import '../voice/yamnet_classifier.dart';
import '../voice/eva_voice_controller.dart';
import 'model_manager.dart';
import 'uncertainty_analyzer.dart';

/// Resultado completo de uma inspeção de frame
class InspectionResult {
  final List<Detection> detections;
  final SegmentationMask? segmentationMask;
  final DiagnosticResult? diagnosis;
  final AudioEvent? audioEvent;
  final double frameUrgency;
  final Duration inferenceTime;
  final String modelUsed;

  InspectionResult({
    required this.detections,
    this.segmentationMask,
    this.diagnosis,
    this.audioEvent,
    required this.frameUrgency,
    required this.inferenceTime,
    required this.modelUsed,
  });

  bool get hasDefects => detections.any((d) => d.isDefect);
  int get defectCount => detections.where((d) => d.isDefect).length;
}

/// Pipeline principal de inspeção: Camera → YOLO → EdgeSAM → Moondream → TTS
/// Orquestra todos os modelos com decisões baseadas em incerteza
class InspectionOrchestrator {
  final ModelManager modelManager;
  final UncertaintyAnalyzer uncertainty;
  final EVAVoiceController? voiceController;

  // Estado
  bool _isRunning = false;
  int _frameCount = 0;
  int _defectsFound = 0;
  DateTime? _sessionStart;

  // Callbacks
  void Function(InspectionResult)? onResult;
  void Function(String)? onAlert;

  InspectionOrchestrator({
    ModelManager? modelManager,
    UncertaintyAnalyzer? uncertainty,
    this.voiceController,
  })  : modelManager = modelManager ?? ModelManager(),
        uncertainty = uncertainty ?? UncertaintyAnalyzer();

  bool get isRunning => _isRunning;
  int get frameCount => _frameCount;
  int get defectsFound => _defectsFound;

  /// Inicializa o pipeline (carrega modelos warm)
  Future<void> initialize() async {
    debugPrint('[Orchestrator] Inicializando pipeline de inspeção...');
    await modelManager.initialize();
    _sessionStart = DateTime.now();
    debugPrint('[Orchestrator] Pipeline pronto');
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
    DiagnosticResult? diagnosis;

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
            const Size(640, 640), // Normalizado pelo preview
          );
        }
      } catch (e) {
        debugPrint('[Orchestrator] EdgeSAM falhou: $e');
      }

      // ─── STAGE 3: Diagnóstico Moondream (se incerteza média) ───
      final needsDiagnosis = decisions.entries.any(
        (e) => e.value == AnalysisDecision.moondreamAnalysis,
      );

      if (needsDiagnosis) {
        try {
          await modelManager.ensureMoondream();
          if (modelManager.moondream.isLoaded) {
            final prompt = MoondreamDiagnostic.diagnosticPrompts[
                    topDefect.className] ??
                'Descreva o defeito visível nesta peça mecânica.';
            diagnosis = await modelManager.moondream.diagnose(
              imageBytes,
              prompt,
            );
          }
        } catch (e) {
          debugPrint('[Orchestrator] Moondream falhou: $e');
        }
      }

      // ─── STAGE 4: Alerta por voz (se urgência alta) ───
      if (uncertainty.shouldAlert(detections) && voiceController != null) {
        final alertMsg = _buildAlertMessage(topDefect, diagnosis);
        onAlert?.call(alertMsg);
        // TTS não bloqueia o pipeline
        voiceController!.speak(alertMsg);
      }
    }

    stopwatch.stop();

    final result = InspectionResult(
      detections: detections,
      segmentationMask: mask,
      diagnosis: diagnosis,
      frameUrgency: urgency,
      inferenceTime: stopwatch.elapsed,
      modelUsed: modelManager.yoloEngine.currentModelName,
    );

    onResult?.call(result);
    return result;
  }

  /// Constrói mensagem de alerta para TTS
  String _buildAlertMessage(Detection defect, DiagnosticResult? diagnosis) {
    final className = defect.className.replaceAll('_', ' ');
    final confidence = (defect.confidence * 100).toInt();

    if (diagnosis != null) {
      return 'Atenção! $className detectado com $confidence por cento de confiança. '
          '${diagnosis.description}';
    }

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
