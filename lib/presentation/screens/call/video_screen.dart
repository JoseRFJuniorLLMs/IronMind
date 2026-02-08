import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../providers/call_provider.dart';
import '../../../data/services/webrtc_service.dart' show WebRTCConnectionState;

class VideoScreen extends StatefulWidget {
  const VideoScreen({super.key});

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _isInitializing = true;
  String? _errorMessage;
  WebRTCConnectionState _webrtcState = WebRTCConnectionState.disconnected;

  @override
  void initState() {
    super.initState();
    _initRenderers();
    _startVideoCall();
  }

  Future<void> _startVideoCall() async {
    final provider = Provider.of<CallProvider>(context, listen: false);

    // Configurar callbacks de stream ANTES de iniciar
    provider.webrtcService.onLocalStream = (stream) {
      if (mounted) {
        setState(() {
          _localRenderer.srcObject = stream;
        });
      }
    };

    provider.webrtcService.onRemoteStream = (stream) {
      if (mounted) {
        setState(() {
          _remoteRenderer.srcObject = stream;
        });
      }
    };

    // ✅ Callback de estado da conexão WebRTC
    provider.webrtcService.onConnectionStateChange = (state) {
      if (mounted) {
        setState(() {
          _webrtcState = state;
        });
      }
    };

    // ✅ Callback de erro do WebRTC
    provider.webrtcService.onError = (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error;
        });
      }
    };

    // ✅ Iniciar Chamada automaticamente ao abrir a tela
    if (provider.status == CallStatus.idle ||
        provider.status == CallStatus.error) {
      try {
        // Reset WebRTC service para nova chamada
        provider.webrtcService.reset();
        await provider.startVideoCall();
      } catch (e) {
        if (mounted) {
          setState(() {
            _errorMessage = e.toString();
          });
        }
      }
    }

    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Consumer<CallProvider>(
          builder: (context, provider, child) {
            // ✅ FIX: Só fechar automaticamente quando chamada terminar normalmente
            // NÃO fechar em caso de erro - mostrar mensagem ao usuário
            if (provider.status == CallStatus.ended) {
              Future.microtask(() => context.go('/home'));
            }

            // ✅ Mostrar tela de erro se houver problema
            if (provider.status == CallStatus.error || _errorMessage != null) {
              return _buildErrorScreen(provider);
            }

            // ✅ Mostrar loading enquanto inicializa
            if (_isInitializing) {
              return _buildLoadingScreen();
            }

            return Stack(
              children: [
                // ✅ Vídeo Remoto (Operador) - Tela Cheia
                Positioned.fill(
                  child: _remoteRenderer.srcObject != null
                      ? RTCVideoView(
                          _remoteRenderer,
                          objectFit:
                              RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        )
                      : Container(
                          color: Colors.black,
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(
                                  color: Colors.pink,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Aguardando operador...',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),

                // ✅ Vídeo Local (Você) - Picture-in-Picture
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    width: 120,
                    height: 160,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.pink, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: _localRenderer.srcObject != null
                          ? RTCVideoView(
                              _localRenderer,
                              mirror: true,
                              objectFit: RTCVideoViewObjectFit
                                  .RTCVideoViewObjectFitCover,
                            )
                          : Container(
                              color: Colors.grey[900],
                              child: const Icon(
                                Icons.person,
                                color: Colors.white54,
                                size: 48,
                              ),
                            ),
                    ),
                  ),
                ),

                // Status Badge
                Positioned(
                  top: 16,
                  left: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(provider.status),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_webrtcState == WebRTCConnectionState.connected)
                              const Icon(Icons.wifi, color: Colors.white, size: 14),
                            if (_webrtcState == WebRTCConnectionState.connecting)
                              const SizedBox(
                                width: 14, height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            const SizedBox(width: 6),
                            Text(
                              _getStatusText(provider.status),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // WebRTC State (debug info)
                      if (_webrtcState != WebRTCConnectionState.connected &&
                          _webrtcState != WebRTCConnectionState.disconnected)
                        Padding(
                          padding: const EdgeInsets.only(top: 4, left: 4),
                          child: Text(
                            'WebRTC: ${_webrtcState.name}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 10,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Botão Desligar
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: () {
                        provider.endCall();
                        context.go('/home');
                      },
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.call_end,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// ✅ Tela de loading enquanto inicializa
  Widget _buildLoadingScreen() {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.pink),
            SizedBox(height: 24),
            Text(
              'Iniciando câmera...',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(
              'Aguarde um momento',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  /// ✅ Tela de erro com opção de tentar novamente
  Widget _buildErrorScreen(CallProvider provider) {
    final error = _errorMessage ?? provider.errorMessage ?? 'Erro desconhecido';

    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.videocam_off,
              color: Colors.red,
              size: 80,
            ),
            const SizedBox(height: 24),
            const Text(
              'Erro na Videochamada',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                error,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Botão Tentar Novamente
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _errorMessage = null;
                      _isInitializing = true;
                    });
                    _startVideoCall();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar Novamente'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Botão Voltar
                OutlinedButton.icon(
                  onPressed: () {
                    provider.endCall();
                    context.go('/home');
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Voltar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(CallStatus status) {
    switch (status) {
      case CallStatus.connected:
        return Colors.green;
      case CallStatus.connecting:
        return Colors.orange;
      case CallStatus.error:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(CallStatus status) {
    switch (status) {
      case CallStatus.connected:
        return 'Conectado';
      case CallStatus.connecting:
        return 'Conectando...';
      case CallStatus.error:
        return 'Erro';
      default:
        return 'Aguardando...';
    }
  }
}
