import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'dart:async';
import 'dart:typed_data';
import '../data/services/medication_analysis_service.dart';
import '../utils/frame_quality_analyzer.dart';

class MedicationScannerScreen extends StatefulWidget {
  final String sessionId;
  final List<dynamic> candidateMedications;
  final String instructions;

  const MedicationScannerScreen({
    Key? key,
    required this.sessionId,
    required this.candidateMedications,
    required this.instructions,
  }) : super(key: key);

  @override
  State<MedicationScannerScreen> createState() => _MedicationScannerScreenState();
}

class _MedicationScannerScreenState extends State<MedicationScannerScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  late AnimationController _pulseController;

  // Estado do scanner
  ScanState _scanState = ScanState.scanning;
  String _statusMessage = 'Posicione a câmera sobre os medicamentos...';

  // Resultado da identificação
  MedicationAnalysisResult? _analysisResult;
  Rect? _boundingBox;

  // Análise de qualidade
  final FrameQualityAnalyzer _qualityAnalyzer = FrameQualityAnalyzer();
  final MedicationAnalysisService _analysisService = MedicationAnalysisService();
  double _currentQuality = 0.0;

  // Timer para auto-capture
  Timer? _autoCaptureTimer;
  Timer? _manualCaptureTimer;
  int _frameCount = 0;
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _initializeCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _pulseController.dispose();
    _autoCaptureTimer?.cancel();
    _manualCaptureTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();

      if (!mounted) return;

      setState(() {});

      // Iniciar processamento de frames
      _startFrameProcessing();
    } catch (e) {
      print('Erro ao inicializar câmera: $e');
      _updateStatus('Erro ao acessar câmera', ScanState.error);
    }
  }

  void _startFrameProcessing() {
    _cameraController!.startImageStream((CameraImage image) {
      _frameCount++;

      // Processar apenas 1 frame a cada 10 (otimização)
      if (_frameCount % 10 != 0) return;

      // Apenas processar se ainda estiver scanning
      if (_scanState != ScanState.scanning) return;

      // Analisar qualidade do frame
      final quality = _qualityAnalyzer.analyzeFrame(image);

      setState(() {
        _currentQuality = quality.overallScore;
      });

      // ✅ FIX: Threshold mais baixo para captura (0.5 em vez de 0.75)
      // Auto-capture se qualidade for razoável
      final isGoodEnough = quality.overallScore >= 0.5 &&
          quality.focusScore >= 0.4 &&
          quality.lightingScore >= 0.4;

      if (isGoodEnough && _scanState == ScanState.scanning) {
        _captureAndSend();
      }
    });

    // ✅ FIX: Timer de fallback - captura após 5s mesmo com qualidade baixa
    _manualCaptureTimer?.cancel();
    _manualCaptureTimer = Timer(const Duration(seconds: 5), () {
      if (_scanState == ScanState.scanning && _currentQuality > 0.3) {
        print('⏱️ Fallback timer: Capturando com qualidade ${(_currentQuality * 100).toInt()}%');
        _captureAndSend();
      }
    });
  }

  Future<void> _captureAndSend() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    // Evitar múltiplas análises simultâneas
    if (_isAnalyzing) return;
    _isAnalyzing = true;

    try {
      // Parar stream temporariamente
      await _cameraController!.stopImageStream();

      _updateStatus('Capturando imagem...', ScanState.processing);

      // Feedback háptico
      HapticFeedback.mediumImpact();

      // Capturar foto
      final XFile photo = await _cameraController!.takePicture();
      final Uint8List imageBytes = await photo.readAsBytes();

      _updateStatus('Analisando medicamento com IA...', ScanState.processing);

      // Analisar localmente usando Gemini Vision
      final result = await _analysisService.analyzeImage(imageBytes);

      if (result.isError) {
        _handleError({'message': result.errorMessage});
      } else if (result.identified) {
        _handleSuccessfulIdentification(result);
      } else {
        _handleNotFound({'message': result.errorMessage ?? 'Medicamento não reconhecido'});
      }

    } catch (e) {
      print('Erro ao capturar imagem: $e');
      _updateStatus('Erro ao capturar. Tente novamente.', ScanState.error);

      // Reiniciar stream após erro
      _startFrameProcessing();
    } finally {
      _isAnalyzing = false;
    }
  }

  void _handleSuccessfulIdentification(MedicationAnalysisResult result) {
    setState(() {
      _scanState = ScanState.identified;
      _analysisResult = result;
      _statusMessage = 'Medicamento identificado!';
    });

    // Feedback háptico de sucesso
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 100), () {
      HapticFeedback.mediumImpact();
    });

    // Falar sobre o medicamento automaticamente
    _analysisService.speakMedicationInfo(result);
  }

  void _handleNotFound(Map<String, dynamic> result) {
    setState(() {
      _scanState = ScanState.notFound;
      _statusMessage = result['message'] ?? 'Medicamento não reconhecido';
    });

    HapticFeedback.vibrate();
  }

  void _handleError(Map<String, dynamic> result) {
    _updateStatus(
      result['message'] ?? 'Erro ao processar imagem',
      ScanState.error,
    );
  }

  void _updateStatus(String message, ScanState state) {
    setState(() {
      _statusMessage = message;
      _scanState = state;
    });
  }

  void _confirmMedicationTaken() {
    HapticFeedback.mediumImpact();
    _analysisService.stopSpeaking();

    // Voltar para tela anterior com feedback de sucesso
    Navigator.pop(context, {
      'confirmed': true,
      'medication': _analysisResult?.name,
      'dosage': _analysisResult?.dosage,
    });
  }

  void _cancel() {
    _analysisService.stopSpeaking();
    Navigator.pop(context, {'confirmed': false});
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.orange),
              SizedBox(height: 16),
              Text(
                'Inicializando câmera...',
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
        children: [
          // Camera Preview
          Positioned.fill(
            child: CameraPreview(_cameraController!),
          ),

          // Overlay de enquadramento
          if (_scanState == ScanState.scanning) _buildFrameGuideOverlay(),

          // Bounding box do medicamento identificado
          if (_boundingBox != null && _scanState == ScanState.identified)
            _buildBoundingBox(),

          // Status bar superior
          _buildTopBar(),

          // Indicador de qualidade (apenas durante scanning)
          if (_scanState == ScanState.scanning) _buildQualityIndicator(),

          // ✅ Botão de captura manual
          if (_scanState == ScanState.scanning) _buildManualCaptureButton(),

          // Instruções
          _buildInstructionsCard(),

          // Resultado da identificação
          if (_scanState == ScanState.identified) _buildIdentificationCard(),

          // Botões de ação
          if (_scanState == ScanState.identified) _buildActionButtons(),

          // Loading overlay
          if (_scanState == ScanState.processing) _buildLoadingOverlay(),

          // Error/Not Found overlay
          if (_scanState == ScanState.error || _scanState == ScanState.notFound)
            _buildErrorOverlay(),

          // Botão de fechar
          _buildCloseButton(),
        ],
      ),
    );
  }

  Widget _buildFrameGuideOverlay() {
    return CustomPaint(
      painter: FrameGuidePainter(
        animationValue: _pulseController.value,
        quality: _currentQuality,
      ),
      child: Container(),
    );
  }

  Widget _buildBoundingBox() {
    return CustomPaint(
      painter: BoundingBoxPainter(
        boundingBox: _boundingBox!,
        color: Colors.green,
      ),
      child: Container(),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 16,
          left: 16,
          right: 16,
          bottom: 16,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.7),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.medication, color: Colors.orange, size: 24),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Scanner de Medicamentos',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQualityIndicator() {
    final qualityColor = _currentQuality > 0.8
        ? Colors.green
        : _currentQuality > 0.5
            ? Colors.orange
            : Colors.red;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 70,
      right: 16,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: qualityColor, width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _currentQuality > 0.8
                  ? Icons.check_circle
                  : Icons.center_focus_weak,
              color: qualityColor,
              size: 16,
            ),
            SizedBox(width: 6),
            Text(
              '${(_currentQuality * 100).toInt()}%',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionsCard() {
    return Positioned(
      bottom: _scanState == ScanState.identified ? 200 : 100,
      left: 16,
      right: 16,
      child: AnimatedOpacity(
        opacity: _scanState == ScanState.scanning ? 1.0 : 0.0,
        duration: Duration(milliseconds: 300),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orange, width: 2),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange, size: 24),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  _statusMessage,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIdentificationCard() {
    final medication = _analysisResult!;

    return Positioned(
      top: MediaQuery.of(context).size.height * 0.15,
      left: 16,
      right: 16,
      child: AnimatedScale(
        scale: _scanState == ScanState.identified ? 1.0 : 0.0,
        duration: Duration(milliseconds: 400),
        curve: Curves.elasticOut,
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF10B981), Color(0xFF059669)],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icone de sucesso
              Icon(
                Icons.check_circle,
                size: 60,
                color: Colors.white,
              ),

              SizedBox(height: 8),

              // Status
              Text(
                '✅ MEDICAMENTO IDENTIFICADO',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: 12),

              // Nome do medicamento
              Text(
                medication.name,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              if (medication.activePrinciple != null) ...[
                SizedBox(height: 4),
                Text(
                  '(${medication.activePrinciple})',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],

              if (medication.dosage != null) ...[
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Dosagem: ${medication.dosage}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],

              if (medication.usage != null) ...[
                SizedBox(height: 12),
                Text(
                  '💊 ${medication.usage}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.95),
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],

              if (medication.instructions != null) ...[
                SizedBox(height: 8),
                Text(
                  '📋 ${medication.instructions}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],

              // Warnings
              if (medication.warnings.isNotEmpty) ...[
                SizedBox(height: 10),
                ...medication.warnings.take(2).map((warning) =>
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '⚠️ $warning',
                        style: TextStyle(color: Colors.yellow[100], fontSize: 11),
                        textAlign: TextAlign.center,
                      ),
                    )),
              ],

              // Efeitos colaterais (da pesquisa Google)
              if (medication.sideEffects.isNotEmpty) ...[
                SizedBox(height: 10),
                Text(
                  '💊 Efeitos colaterais: ${medication.sideEffects.take(3).join(", ")}',
                  style: TextStyle(color: Colors.white70, fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ],

              // Interações medicamentosas (da pesquisa Google)
              if (medication.interactions.isNotEmpty) ...[
                SizedBox(height: 6),
                Text(
                  '🔄 Interações: ${medication.interactions.take(2).join(", ")}',
                  style: TextStyle(color: Colors.orange[200], fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ],

              // Confiança + pesquisa Google
              SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.volume_up, color: Colors.white70, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Ouvindo informações...',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 11,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Confiança: ${(medication.confidence * 100).toInt()}%',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Positioned(
      bottom: 40,
      left: 16,
      right: 16,
      child: Column(
        children: [
          // Botão principal: TOMEI O MEDICAMENTO
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: _confirmMedicationTaken,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.green[700],
                elevation: 8,
                shadowColor: Colors.black.withOpacity(0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 28),
                  SizedBox(width: 12),
                  Text(
                    'TOMEI O MEDICAMENTO',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 12),

          // Botão secundário: NÃO VOU TOMAR
          TextButton(
            onPressed: _cancel,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              'Não vou tomar agora',
              style: TextStyle(
                fontSize: 14,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Colors.orange,
              strokeWidth: 3,
            ),
            SizedBox(height: 24),
            Text(
              _statusMessage,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _scanState == ScanState.error
                    ? Icons.error_outline
                    : Icons.help_outline,
                color: Colors.orange,
                size: 64,
              ),
              SizedBox(height: 24),
              Text(
                _statusMessage,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _scanState = ScanState.scanning;
                    _statusMessage = 'Posicione a câmera sobre os medicamentos...';
                  });
                  _startFrameProcessing();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Tentar Novamente',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ✅ Botão de captura manual para o usuário
  Widget _buildManualCaptureButton() {
    return Positioned(
      bottom: 180,
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          onTap: () {
            if (_scanState == ScanState.scanning) {
              print('📸 Captura manual pelo usuário');
              _captureAndSend();
            }
          },
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(
                color: _currentQuality > 0.5 ? Colors.green : Colors.orange,
                width: 4,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.camera_alt,
              size: 40,
              color: _currentQuality > 0.5 ? Colors.green : Colors.orange,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCloseButton() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      right: 16,
      child: IconButton(
        onPressed: _cancel,
        icon: Icon(Icons.close, color: Colors.white, size: 28),
        style: IconButton.styleFrom(
          backgroundColor: Colors.black.withOpacity(0.5),
        ),
      ),
    );
  }
}

// =====================================================================
// CUSTOM PAINTERS
// =====================================================================

class FrameGuidePainter extends CustomPainter {
  final double animationValue;
  final double quality;

  FrameGuidePainter({
    required this.animationValue,
    required this.quality,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // Cor baseada na qualidade
    final color = quality > 0.8
        ? Colors.green
        : quality > 0.5
            ? Colors.orange
            : Colors.red;

    paint.color = color.withOpacity(0.5 + (animationValue * 0.5));

    // Moldura central
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.8,
      height: size.height * 0.4,
    );

    // Cantos arredondados
    final radius = 20.0;
    final cornerLength = 40.0;

    // Canto superior esquerdo
    canvas.drawLine(
      rect.topLeft + Offset(0, radius),
      rect.topLeft + Offset(0, cornerLength),
      paint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: rect.topLeft + Offset(radius, radius), radius: radius),
      3.14,
      1.57,
      false,
      paint,
    );
    canvas.drawLine(
      rect.topLeft + Offset(radius, 0),
      rect.topLeft + Offset(cornerLength, 0),
      paint,
    );

    // Canto superior direito
    canvas.drawLine(
      rect.topRight + Offset(-cornerLength, 0),
      rect.topRight + Offset(-radius, 0),
      paint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: rect.topRight + Offset(-radius, radius), radius: radius),
      -1.57,
      1.57,
      false,
      paint,
    );
    canvas.drawLine(
      rect.topRight + Offset(0, radius),
      rect.topRight + Offset(0, cornerLength),
      paint,
    );

    // Canto inferior esquerdo
    canvas.drawLine(
      rect.bottomLeft + Offset(0, -cornerLength),
      rect.bottomLeft + Offset(0, -radius),
      paint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: rect.bottomLeft + Offset(radius, -radius), radius: radius),
      1.57,
      1.57,
      false,
      paint,
    );
    canvas.drawLine(
      rect.bottomLeft + Offset(radius, 0),
      rect.bottomLeft + Offset(cornerLength, 0),
      paint,
    );

    // Canto inferior direito
    canvas.drawLine(
      rect.bottomRight + Offset(-cornerLength, 0),
      rect.bottomRight + Offset(-radius, 0),
      paint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: rect.bottomRight + Offset(-radius, -radius), radius: radius),
      0,
      1.57,
      false,
      paint,
    );
    canvas.drawLine(
      rect.bottomRight + Offset(0, -radius),
      rect.bottomRight + Offset(0, -cornerLength),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant FrameGuidePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.quality != quality;
  }
}

class BoundingBoxPainter extends CustomPainter {
  final Rect boundingBox;
  final Color color;

  BoundingBoxPainter({
    required this.boundingBox,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    canvas.drawRect(boundingBox, paint);

    // Preenchimento semi-transparente
    final fillPaint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    canvas.drawRect(boundingBox, fillPaint);
  }

  @override
  bool shouldRepaint(covariant BoundingBoxPainter oldDelegate) {
    return oldDelegate.boundingBox != boundingBox || oldDelegate.color != color;
  }
}

// =====================================================================
// ENUMS
// =====================================================================

enum ScanState {
  scanning,
  processing,
  identified,
  notFound,
  error,
}
