import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:eva_mobile/providers/call_provider.dart'; // Corrected path
import 'package:eva_mobile/presentation/widgets/pulsing_button.dart';
import 'package:logger/logger.dart';
import 'package:video_player/video_player.dart';
import 'dart:math'; // For random selection

class CallScreen extends StatefulWidget {
  const CallScreen({super.key});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final Logger _logger = Logger();
  late VideoPlayerController _videoController;
  bool _isVideoInitialized = false;

  // List of available video avatars
  final List<String> _videoFiles = ['EVA.mp4', 'EVA2.mp4', 'EVA4.mp4'];

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    // Select a random video
    final random = Random();
    final selectedVideo = _videoFiles[random.nextInt(_videoFiles.length)];
    final assetPath = 'assets/videos/$selectedVideo';

    _logger.i('🎲 Randomly selected avatar: $selectedVideo');

    _videoController = VideoPlayerController.asset(assetPath);

    try {
      await _videoController.initialize();
      await _videoController.setLooping(true);
      await _videoController.setVolume(0.0); // Mute video audio
      setState(() {
        _isVideoInitialized = true;
      });
      _logger.i('🎥 Video Avatar initialized successfully');
    } catch (e) {
      _logger.e('❌ Error initializing video avatar ($assetPath): $e');
    }
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          Colors.transparent, // 🎨 Transparente para mostrar degradê
      body: Consumer<CallProvider>(
        builder: (context, provider, child) {
          final isConnected = provider.status == CallStatus.connected;

          // Control video playback based on connection status
          if (_isVideoInitialized) {
            if (isConnected && !_videoController.value.isPlaying) {
              _videoController.play();
            } else if (!isConnected && _videoController.value.isPlaying) {
              _videoController.pause();
            }
          }

          return Stack(
            children: [
              // 1. Background Layer (Video or White)
              Positioned.fill(
                child: isConnected
                    ? (_isVideoInitialized
                        ? FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: _videoController.value.size.width,
                              height: _videoController.value.size.height,
                              child: VideoPlayer(_videoController),
                            ),
                          )
                        : Container(
                            color: Colors
                                .white, // Fallback clean (Video loading or failed)
                          ))
                    : Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(
                                  0xFFFFB6C1), // Light Pink from Speaker button
                              Color(
                                  0xFFE0B0FF), // Light Purple from Mute button
                            ],
                          ),
                        ),
                      ),
              ),

              // 2. Logo Layer (Waiting Only)
              if (!isConnected)
                Center(
                  child: Image.asset(
                    'assets/images/logox.png',
                    width: 200,
                    fit: BoxFit.contain,
                  ),
                ),

              // 3. Audio Engine Layer (REMOVED - Native Audio)
              // Positioned.fill(
              //   child: IgnorePointer(
              //     ignoring: true,
              //     child: Opacity(
              //       opacity: 0.0, 
              //       child: provider.getWebViewWidget(),
              //     ),
              //   ),
              // ),

              // 4. UI Layer (Controls)
              SafeArea(child: _buildCallUI(provider)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCallUI(CallProvider provider) {
    switch (provider.status) {
      case CallStatus.idle: // Was initial
      case CallStatus.connecting:
        return _buildConnectingState();

      case CallStatus.ringing:
        return _buildRingingState(provider);

      case CallStatus.connected:
        return _buildConnectedState(provider);

      case CallStatus.error: // Was failed
        return _buildErrorState(provider);

      case CallStatus.ended: // Was disconnected
      case CallStatus.ending:
        return _buildEndedState(provider);

      default:
        // Idle state -> redirect to home
        Future.microtask(() => context.go('/home'));
        return const Center(
          child: CircularProgressIndicator(color: Colors.pink),
        );
    }
  }

  Widget _buildRingingState(CallProvider provider) {
    return Center(
      child: PulsingButton(
        imagePath: 'assets/images/oceano_azul.jpg',
        label: '',
        size: 280,
        onTap: () async {
          try {
            provider.acceptCall();
          } catch (e) {
            _logger.e('❌ Erro ao atender: $e');
          }
        },
      ),
    );
  }

  Widget _buildConnectingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
          const SizedBox(height: 30),
          Text(
            'Conectando...',
            style: TextStyle(
              fontSize: 24,
              color: Colors.pink.shade900,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedState(CallProvider provider) {
    // Buttons standardized
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Mute
              _build3DButton(
                icon: provider.isMuted ? Icons.mic_off : Icons.mic,
                label: provider.isMuted ? 'Mudo' : 'Microfone',
                colors: [const Color(0xFFE0B0FF), const Color(0xFF9F70D8)],
                onTap: () => provider.toggleMute(),
              ),

              // Hangup
              _build3DButton(
                icon: Icons.call_end,
                label: 'Desligar',
                isCritical: true,
                colors: [const Color(0xFFFF6B6B), const Color(0xFFC92A2A)],
                onTap: () => provider.endCall(),
              ),

              // Speaker
              _build3DButton(
                icon: provider.isSpeakerOn ? Icons.volume_up : Icons.hearing,
                label: provider.isSpeakerOn ? 'Alto-falante' : 'Fone',
                colors: [const Color(0xFFFFB6C1), const Color(0xFFFF69B4)],
                onTap: () => provider.toggleSpeaker(),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildErrorState(CallProvider provider) {
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) context.go('/home');
    });

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 80, color: Colors.red.shade400),
          const SizedBox(height: 20),
          Text(
            'Erro na chamada',
            style: TextStyle(
              fontSize: 24,
              color: Colors.red.shade800,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              provider.errorMessage ?? 'Reiniciando sistema...',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.red.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEndedState(CallProvider provider) {
    // 🎨 FLUXO LÓGICO: Fim de Chamada -> Home
    // O Provider já deve lidar com o reset, mas garantimos aqui
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) context.go('/home');
    });

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.call_end, size: 80, color: Colors.pink.shade300),
          const SizedBox(height: 20),
          Text(
            'Chamada Encerrada',
            style: TextStyle(
              fontSize: 24,
              color: Colors.pink.shade800,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _build3DButton({
    required IconData icon,
    required String label,
    required List<Color> colors,
    required VoidCallback onTap,
    bool isCritical = false,
  }) {
    final size = isCritical ? 100.0 : 80.0;
    final iconSize = isCritical ? 50.0 : 40.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(size / 2),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: colors,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.last.withValues(alpha: 0.5),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(-4, -4),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: iconSize,
                  color: Colors.white,
                  shadows: const [
                    Shadow(
                      color: Colors.black26,
                      offset: Offset(1, 1),
                      blurRadius: 3,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: Colors.pink.shade900,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes);
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}
