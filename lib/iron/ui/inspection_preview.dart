import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../logic/inspection_orchestrator.dart';
import '../logic/model_manager.dart';
import '../logic/uncertainty_analyzer.dart';
import '../voice/eva_voice_controller.dart';
import '../voice/yamnet_classifier.dart';
import 'detection_overlay.dart';

/// Widget principal de inspeção com câmera real-time + NPU inference
/// Pipeline: Camera 30fps → Isolate → NPU YOLO → Overlay → Display
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
  bool _isInitialized = false;
  String? _audioAlert;
  Timer? _fpsTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAll();
  }

  Future<void> _initializeAll() async {
    // 1. Inicializa câmera
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      debugPrint('[Preview] Nenhuma câmera disponível');
      return;
    }

    // Prioriza câmera traseira (inspeção de máquinas)
    final camera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      camera,
      ResolutionPreset.medium, // 720p para balance FPS/qualidade
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _cameraController!.initialize();

    // 2. Inicializa orchestrator
    _orchestrator = InspectionOrchestrator(
      voiceController: EVAVoiceController(),
    );

    _orchestrator!.onAlert = (alert) {
      setState(() => _audioAlert = alert);
      // Limpa alerta após 3s
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _audioAlert = null);
      });
    };

    await _orchestrator!.initialize();

    // 3. FPS counter
    _fpsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _fps = _frameCount;
          _frameCount = 0;
        });
      }
    });

    // 4. Inicia stream de imagens
    await _cameraController!.startImageStream(_onCameraFrame);

    if (mounted) {
      setState(() => _isInitialized = true);
    }

    debugPrint('[Preview] Câmera e NPU prontos - streaming 30fps');
  }

  /// Callback para cada frame da câmera (~30fps)
  /// CRITICAL PATH: precisa ser rápido, skip se ainda processando
  Future<void> _onCameraFrame(CameraImage image) async {
    if (_isProcessing || _orchestrator == null) return;
    _isProcessing = true;

    try {
      // Converte CameraImage (YUV420) para bytes RGB
      final imageBytes = _convertYUV420toRGB(image);

      // Processa no NPU via orchestrator
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
    if (!_isInitialized || _cameraController == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.cyan),
              SizedBox(height: 16),
              Text(
                'Carregando NPU...',
                style: TextStyle(color: Colors.white, fontSize: 16),
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
              modelName: _lastResult?.modelUsed ?? 'loading...',
              isOffline: true, // TODO: conectar SyncManager
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

          // Layer 6: Diagnóstico Moondream (se disponível)
          if (_lastResult?.diagnosis != null)
            Positioned(
              bottom: 100,
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
                      'DIAGNÓSTICO NPU',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _lastResult!.diagnosis!.description,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 13),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_lastResult!.diagnosis!.latencyMs}ms | '
                      '${(_lastResult!.diagnosis!.confidence * 100).toInt()}%',
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),

          // Layer 7: Botões de ação
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
      final file = await _cameraController!.takePicture();
      debugPrint('[Preview] Frame capturado: ${file.path}');
      // TODO: Salvar com inspeção atual
    } catch (e) {
      debugPrint('[Preview] Erro ao capturar: $e');
    }
  }

  Future<void> _forceDiagnosis() async {
    // Força Moondream mesmo sem detecção automática
    debugPrint('[Preview] Diagnóstico forçado solicitado');
    // TODO: Capturar frame atual e enviar para Moondream
  }

  Future<void> _startVoiceNote() async {
    // Inicia gravação de nota de voz via Whisper
    debugPrint('[Preview] Nota de voz iniciada');
    // TODO: Integrar com EVAVoiceController
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
