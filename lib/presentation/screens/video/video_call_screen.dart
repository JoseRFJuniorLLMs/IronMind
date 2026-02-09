import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/storage_service.dart';
import '../../../providers/call_provider.dart';
import 'package:logger/logger.dart';

class VideoCallScreen extends StatefulWidget {
  const VideoCallScreen({super.key});

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final ApiService _apiService = ApiService();
  final Logger _logger = Logger();

  bool _isCameraInitialized = false;
  bool _isLoading = true;
  String? _sessionId;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeCall();
  }

  Future<void> _initializeCall() async {
    await _requestPermissions();
    if (_isCameraInitialized) {
      await _startBackendSession();
    }
  }

  Future<void> _requestPermissions() async {
    // ✅ Solicita permissões de Câmera e Microfone para WebRTC
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.microphone,
    ].request();

    if (statuses[Permission.camera]!.isGranted &&
        statuses[Permission.microphone]!.isGranted) {
      setState(() {
        _isCameraInitialized = true;
      });
      _logger.i('✅ Permissões para vídeo garantidas.');
    } else {
      _logger.e('❌ Permissões negadas.');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Permissão de câmera negada.';
      });
    }
  }

  Future<void> _startBackendSession() async {
    try {
      final operatorId = StorageService.getOperatorId();
      if (operatorId == null) {
        throw Exception('ID do operador não encontrado no storage.');
      }

      _logger.i('📞 Iniciando sessão de vídeo para operador $operatorId...');
      final response = await _apiService.startVideoCall(operatorId);

      if (response['success'] == true && response['session_id'] != null) {
        setState(() {
          _sessionId = response['session_id'];
          _isLoading = false;
        });
        _logger.i('✅ Sessão WEB-RTC Criada: $_sessionId');
      } else {
        throw Exception('Falha ao criar sessão no backend.');
      }
    } catch (e) {
      _logger.e('❌ Erro ao iniciar backend: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erro ao conectar: $e';
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Monta a URL com o session_id se disponível
    // ✅ URL Corrigida para IP direto (MVP)
    final String webrtcUrl = _sessionId != null
        ? "https://eva-ia.org/webrtc-client.html?session_id=$_sessionId&role=mobile"
        : "about:blank";

    return Scaffold(
      backgroundColor: Colors.black, // Fundo preto para vídeo
      body: Stack(
        children: [
          // 1. WebView (WebRTC / Câmera) - Só carrega se tiver SessionID
          if (_sessionId != null && _isCameraInitialized)
            Consumer<CallProvider>(
              builder: (context, provider, child) {
                return InAppWebView(
                  initialUrlRequest: URLRequest(
                    url: WebUri(webrtcUrl),
                  ),
                  initialSettings: InAppWebViewSettings(
                    mediaPlaybackRequiresUserGesture: false,
                    allowsInlineMediaPlayback: true,
                    iframeAllowFullscreen: true,
                    javaScriptEnabled: true,
                    userAgent: "EVA-Mobile-App",
                  ),
                  onWebViewCreated: (controller) {
                    _logger.i('🌐 WebView Criada para URL: $webrtcUrl');
                  },
                  onPermissionRequest: (controller, request) async {
                    return PermissionResponse(
                      resources: request.resources,
                      action: PermissionResponseAction.GRANT,
                    );
                  },
                  onConsoleMessage: (controller, consoleMessage) {
                    _logger.i("🌐 [WebRTC Log]: ${consoleMessage.message}");
                  },
                );
              },
            ),

          // 2. Loading State
          if (_isLoading)
            Container(
              color: Colors.black87,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.pink),
                    const SizedBox(height: 20),
                    Text(
                      _isCameraInitialized
                          ? 'Conectando ao servidor...'
                          : 'Verificando permissões...',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),

          // 3. Error State
          if (_errorMessage != null)
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                color: Colors.black87,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 48),
                    const SizedBox(height: 10),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => context.pop(),
                      child: const Text('Voltar'),
                    )
                  ],
                ),
              ),
            ),

          // 4. Botão de Encerrar (Overlay)
          if (!_isLoading && _errorMessage == null)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: FloatingActionButton(
                  backgroundColor: Colors.red,
                  onPressed: () {
                    // Encerrar chamada
                    context.pop();
                  },
                  child: const Icon(Icons.call_end, color: Colors.white),
                ),
              ),
            ),

          // 5. Botão de Voltar (Topo)
          if (!_isLoading)
            Positioned(
              top: 40,
              left: 20,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => context.pop(),
              ),
            ),
        ],
      ),
    );
  }
}
