import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../logic/inspection_orchestrator.dart';
import '../logic/model_manager.dart';
import '../logic/uncertainty_analyzer.dart';
import '../voice/eva_voice_controller.dart';
import '../voice/yamnet_classifier.dart';
import 'detection_overlay.dart';

/// Widget principal de inspeção com câmera real-time + GPU/NPU inference
/// Pipeline: Camera 30fps → Isolate → GPU YOLO → Overlay → Display
/// Estratégia: Camera-first (mostra imagem imediato), modelos em background
class InspectionPreviewScreen extends StatefulWidget {
  final String machineType; // trator, caminhao, mineracao
  final String? machineId;

  const InspectionPreviewScreen({
    super.key,
    required this.machineType,
    this.machineId,
  });

  @override
  State<InspectionPreviewScreen> createState() =>
      _InspectionPreviewScreenState();
}

class _InspectionPreviewScreenState extends State<InspectionPreviewScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  InspectionOrchestrator? _orchestrator;

  // Estado UI
  InspectionResult? _lastResult;
  int _fps = 0;
  int _frameCount = 0;
  bool _isProcessing = false;
  bool _isCameraReady = false;
  bool _isModelsReady = false;
  String _loadingStatus = 'Iniciando camera...';
  String? _audioAlert;
  Timer? _fpsTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAll();
  }

  Future<void> _initializeAll() async {
    // FASE 1: Camera PRIMEIRO (mostra imagem imediato, sem esperar modelos)
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        debugPrint('[Preview] Nenhuma camera disponivel');
        if (mounted) setState(() => _loadingStatus = 'Sem camera disponivel');
        return;
      }

      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();

      // FPS counter
      _fpsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() {
            _fps = _frameCount;
            _frameCount = 0;
          });
        }
      });

      // Camera pronta - mostra preview IMEDIATAMENTE
      if (mounted) {
        setState(() {
          _isCameraReady = true;
          _loadingStatus = 'Carregando modelos GPU...';
        });
      }
      debugPrint('[Preview] Camera pronta - mostrando preview');
    } catch (e) {
      debugPrint('[Preview] Erro na camera: $e');
      if (mounted) setState(() => _loadingStatus = 'Erro camera: $e');
      return;
    }

    // FASE 2: Modelos em BACKGROUND com timeout de 5s
    try {
      _orchestrator = InspectionOrchestrator(
        voiceController: EVAVoiceController(),
      );
      _orchestrator!.setEquipmentType(widget.machineType);
      _orchestrator!.onAlert = (alert) {
        setState(() => _audioAlert = alert);
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) setState(() => _audioAlert = null);
        });
      };

      // Timeout de 5s - se modelos nao carregarem, segue em modo camera-only
      await _orchestrator!.initialize().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('[Preview] Timeout modelos (5s) - modo camera-only');
        },
      );

      if (mounted) {
        setState(() => _isModelsReady = true);
      }
      debugPrint('[Preview] Modelos prontos');
    } catch (e) {
      debugPrint('[Preview] Modelos falharam (continuando camera-only): $e');
    }

    // FASE 3: Inicia stream de frames
    try {
      await _cameraController!.startImageStream(_onCameraFrame);
      debugPrint('[Preview] Camera + GPU streaming 30fps');
    } catch (e) {
      debugPrint('[Preview] Erro ao iniciar stream: $e');
    }
  }

  /// Callback para cada frame da câmera (~30fps)
  /// CRITICAL PATH: precisa ser rápido, skip se ainda processando
  Future<void> _onCameraFrame(CameraImage image) async {
    if (_isProcessing || _orchestrator == null) return;
    _isProcessing = true;

    try {
      // Converte CameraImage (YUV420) para bytes RGB
      final imageBytes = _convertYUV420toRGB(image);

      // Processa na GPU/NPU via orchestrator
      final result = await _orchestrator!.processFrame(imageBytes);

      _frameCount++;

      if (mounted) {
        setState(() => _lastResult = result);
      }
    } catch (e) {
      debugPrint('[Preview] Erro no frame: $e');
    } finally {
      _isProcessing = false;
    }
  }

  /// Converte YUV420 (câmera) para RGB bytes (modelo)
  Uint8List _convertYUV420toRGB(CameraImage image) {
    // Extrai plano Y (luminância) como grayscale
    // Para YOLO, grayscale é suficiente para detecção
    final plane = image.planes[0];
    final bytes = Uint8List(plane.bytes.length);
    bytes.setAll(0, plane.bytes);
    return bytes;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _cameraController?.stopImageStream();
    } else if (state == AppLifecycleState.resumed) {
      _cameraController?.startImageStream(_onCameraFrame);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Loading screen APENAS enquanto camera nao esta pronta (< 2s)
    if (!_isCameraReady || _cameraController == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.cyan),
              const SizedBox(height: 16),
              Text(
                _loadingStatus,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Layer 1: Camera Preview
          CameraPreview(_cameraController!),

          // Layer 2: Bounding boxes do YOLO
          if (_lastResult != null && _lastResult!.detections.isNotEmpty)
            CustomPaint(
              painter: DetectionOverlayPainter(_lastResult!.detections),
              size: Size.infinite,
            ),

          // Layer 3: Máscara de segmentação EdgeSAM
          if (_lastResult?.segmentationMask != null)
            CustomPaint(
              painter:
                  SegmentationOverlayPainter(_lastResult!.segmentationMask!),
              size: Size.infinite,
            ),

          // Layer 4: HUD (FPS, modelo, status)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            child: HUDWidget(
              fps: _fps,
              detectionCount: _lastResult?.detections.length ?? 0,
              modelName: _lastResult?.modelUsed ?? (_isModelsReady ? 'GPU Ready' : 'Camera Only'),
              isOffline: false,
              audioAlert: _audioAlert,
            ),
          ),

          // Layer 5: Tipo de máquina
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                widget.machineType.toUpperCase(),
                style: const TextStyle(
                  color: Colors.cyan,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),

          // Layer 6: Texto do Manual (offline, baseado em YOLO)
          if (_lastResult != null && _lastResult!.hasManualText)
            Positioned(
              bottom: 100,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _lastResult!.hasDefects ? Colors.red : Colors.cyan,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _lastResult!.hasDefects
                              ? Icons.warning_amber_rounded
                              : Icons.check_circle_outline,
                          color: _lastResult!.hasDefects
                              ? Colors.red
                              : Colors.cyan,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _lastResult!.hasDefects
                              ? 'DEFEITO DETECTADO'
                              : 'MANUAL',
                          style: TextStyle(
                            color: _lastResult!.hasDefects
                                ? Colors.red
                                : Colors.cyan,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _lastResult!.manualText!,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 13),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_lastResult!.manualAction != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _lastResult!.manualAction!,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 11,
                            fontStyle: FontStyle.italic),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),

          // Layer 7: Diagnóstico Gemini Spatial (se disponível)
          if (_lastResult?.spatialAnalysis != null)
            Positioned(
              bottom: _lastResult!.hasManualText ? 260 : 100,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'GEMINI SPATIAL',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _lastResult!.spatialAnalysis!.ttsResume,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 13),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_lastResult!.spatialAnalysis!.latencyMs}ms | '
                      '${_lastResult!.spatialAnalysis!.componentCount} componentes | '
                      '${_lastResult!.spatialAnalysis!.anomalyCount} anomalias',
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),

          // Layer 8: Botões de ação
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Capturar frame
                _ActionButton(
                  icon: Icons.camera_alt,
                  label: 'Capturar',
                  onTap: _captureFrame,
                ),
                // Diagnóstico forçado
                _ActionButton(
                  icon: Icons.biotech,
                  label: 'Diagnosticar',
                  onTap: _forceDiagnosis,
                  color: Colors.orange,
                ),
                // Relatório de voz
                _ActionButton(
                  icon: Icons.mic,
                  label: 'Voz',
                  onTap: _startVoiceNote,
                  color: Colors.cyan,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _captureFrame() async {
    if (_cameraController == null) return;
    try {
      // Pausa stream para capturar foto limpa
      await _cameraController!.stopImageStream();
      final file = await _cameraController!.takePicture();
      debugPrint('[Preview] Frame capturado: ${file.path}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Foto salva: ${file.name}'),
            backgroundColor: Colors.green[700],
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Retoma stream
      await _cameraController!.startImageStream(_onCameraFrame);
    } catch (e) {
      debugPrint('[Preview] Erro ao capturar: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao capturar: $e'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    }
  }

  Future<void> _forceDiagnosis() async {
    if (_cameraController == null) return;
    debugPrint('[Preview] Diagnostico forcado solicitado');

    try {
      // Para o stream (ignora erro se já parado)
      try { await _cameraController!.stopImageStream(); } catch (_) {}

      final file = await _cameraController!.takePicture();
      final bytes = await File(file.path).readAsBytes();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                SizedBox(width: 12),
                Text('Enviando para Gemini...'),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 10),
          ),
        );
      }

      // Tenta Gemini Spatial se disponivel
      if (_orchestrator != null && _orchestrator!.gemini.isConfigured) {
        final result = await _orchestrator!.gemini.analyze(
          imageBytes: bytes,
          detections: [],
          equipmentType: widget.machineType,
          thinkingBudget: 'large',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.source.contains('fallback')
                  ? 'Gemini falhou: ${result.source}'
                  : 'Gemini: ${result.ttsResume}'),
              backgroundColor: result.source.contains('fallback')
                  ? Colors.red[700]
                  : Colors.green[700],
              duration: const Duration(seconds: 5),
            ),
          );
          setState(() {
            _lastResult = InspectionResult(
              detections: [],
              spatialAnalysis: result,
              frameUrgency: 0,
              inferenceTime: Duration(milliseconds: result.latencyMs),
              modelUsed: 'Gemini Spatial',
            );
          });
        }
      } else {
        final reason = _orchestrator == null
            ? 'Pipeline nao inicializado'
            : 'API key GEMINI_API_KEY ausente no .env';
        debugPrint('[Preview] Gemini indisponivel: $reason');
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$reason. Foto salva: ${file.name}'),
              backgroundColor: Colors.red[700],
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }

      // Retoma stream (ignora erro se falhar)
      try { await _cameraController!.startImageStream(_onCameraFrame); } catch (_) {}
    } catch (e) {
      debugPrint('[Preview] Erro no diagnostico: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro no diagnóstico: $e'),
            backgroundColor: Colors.red[700],
            duration: const Duration(seconds: 4),
          ),
        );
      }
      // Tenta retomar stream
      try { await _cameraController!.startImageStream(_onCameraFrame); } catch (_) {}
    }
  }

  Future<void> _startVoiceNote() async {
    debugPrint('[Preview] Nota de voz iniciada');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nota de voz em desenvolvimento'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fpsTimer?.cancel();
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _orchestrator?.dispose();
    super.dispose();
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.8), width: 2),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
