import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:vibration/vibration.dart';
import '../../core/sentinela/sentinela_service.dart';

/// Overlay widget that shows when Sentinela detects a potential emergency
/// Allows user to confirm they are safe or trigger emergency manually
class SentinelaAlertOverlay extends StatefulWidget {
  final Widget child;

  const SentinelaAlertOverlay({super.key, required this.child});

  @override
  State<SentinelaAlertOverlay> createState() => _SentinelaAlertOverlayState();
}

class _SentinelaAlertOverlayState extends State<SentinelaAlertOverlay>
    with SingleTickerProviderStateMixin {
  bool _showConfirmation = false;
  bool _showEmergency = false;
  String _source = '';
  String _details = '';
  int _countdown = 15;
  Timer? _countdownTimer;
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Animation for pulsing effect
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Listen for Sentinela events
    _listenToSentinelaEvents();
  }

  void _listenToSentinelaEvents() {
    final service = FlutterBackgroundService();

    // Show confirmation dialog
    service.on('show_confirmation_dialog').listen((event) {
      if (event != null && mounted) {
        setState(() {
          _showConfirmation = true;
          _showEmergency = false;
          _source = event['source'] ?? 'Desconhecido';
          _details = event['details'] ?? '';
          _countdown = event['timeout'] ?? 15;
        });
        _startCountdown();
      }
    });

    // Dismiss confirmation dialog
    service.on('dismiss_confirmation_dialog').listen((event) {
      if (mounted) {
        _dismissDialog();
      }
    });

    // Emergency triggered
    service.on('emergency_triggered').listen((event) {
      if (event != null && mounted) {
        setState(() {
          _showConfirmation = false;
          _showEmergency = true;
          _source = event['source'] ?? 'Desconhecido';
          _details = event['details'] ?? '';
        });
        _countdownTimer?.cancel();
      }
    });
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _countdown--;
        });
        if (_countdown <= 0) {
          timer.cancel();
        }
      }
    });
  }

  void _dismissDialog() {
    _countdownTimer?.cancel();
    Vibration.cancel();
    setState(() {
      _showConfirmation = false;
      _showEmergency = false;
    });
  }

  Future<void> _confirmSafe() async {
    await SentinelaService.confirmUserSafe();
    _dismissDialog();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,

        // Confirmation Dialog Overlay
        if (_showConfirmation) _buildConfirmationOverlay(),

        // Emergency Active Overlay
        if (_showEmergency) _buildEmergencyOverlay(),
      ],
    );
  }

  Widget _buildConfirmationOverlay() {
    return Material(
      color: Colors.black.withOpacity(0.8),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: ScaleTransition(
              scale: _pulseAnimation,
              child: Card(
                elevation: 16,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: const BorderSide(color: Colors.orange, width: 4),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Warning Icon
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 80,
                        color: Colors.orange,
                      ),
                      const SizedBox(height: 24),

                      // Title
                      const Text(
                        'ATENÇÃO!',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Message
                      Text(
                        'Detectamos: $_source',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),

                      const Text(
                        'Você está bem?',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),

                      // Countdown
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: _countdown <= 5
                              ? Colors.red.withOpacity(0.2)
                              : Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Emergência em $_countdown segundos',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _countdown <= 5 ? Colors.red : Colors.orange,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Safe Button
                      SizedBox(
                        width: double.infinity,
                        height: 80,
                        child: ElevatedButton.icon(
                          onPressed: _confirmSafe,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: const Icon(Icons.check_circle, size: 40),
                          label: const Text(
                            'ESTOU BEM',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Help Button
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            // Skip countdown and trigger emergency immediately
                            _countdownTimer?.cancel();
                            setState(() {
                              _countdown = 0;
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red, width: 2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: const Icon(Icons.emergency, size: 28),
                          label: const Text(
                            'PRECISO DE AJUDA',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmergencyOverlay() {
    return Material(
      color: Colors.red.withOpacity(0.9),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Emergency Icon
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: const Icon(
                    Icons.emergency,
                    size: 120,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 32),

                // Title
                const Text(
                  'EMERGÊNCIA',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),

                // Status
                const Text(
                  'Acionando seus contatos de emergência...',
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                Text(
                  'Detecção: $_source',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 48),

                // Loading indicator
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 4,
                ),
                const SizedBox(height: 48),

                // Cancel Button (if false alarm)
                SizedBox(
                  width: 250,
                  height: 60,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await SentinelaService.resetAlertState();
                      _dismissDialog();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.cancel, size: 28),
                    label: const Text(
                      'CANCELAR\n(Falso Alarme)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
