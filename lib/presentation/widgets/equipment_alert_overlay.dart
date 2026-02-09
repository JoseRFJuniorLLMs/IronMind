import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:vibration/vibration.dart';

/// Overlay de alerta industrial - aparece sobre a tela de inspeção
/// Refatorado do SentinelaAlertOverlay (idosos) para equipamentos
class EquipmentAlertOverlay extends StatefulWidget {
  final VoidCallback? onDismiss;

  const EquipmentAlertOverlay({super.key, this.onDismiss});

  @override
  State<EquipmentAlertOverlay> createState() => _EquipmentAlertOverlayState();
}

class _EquipmentAlertOverlayState extends State<EquipmentAlertOverlay>
    with SingleTickerProviderStateMixin {
  bool _showConfirmation = false;
  bool _emergencyActive = false;
  int _countdown = 20;
  Timer? _countdownTimer;
  String _alertType = '';
  String _alertDetails = '';

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  StreamSubscription? _alertSub;
  StreamSubscription? _dismissSub;
  StreamSubscription? _criticalSub;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(_pulseController);

    _listenToService();
  }

  void _listenToService() {
    final service = FlutterBackgroundService();

    _alertSub = service.on('show_equipment_alert').listen((event) {
      if (event == null) return;
      setState(() {
        _showConfirmation = true;
        _emergencyActive = false;
        _alertType = event['type'] as String? ?? '';
        _alertDetails = event['details'] as String? ?? '';
        _countdown = event['timeout'] as int? ?? 20;
      });
      _startCountdown();
    });

    _dismissSub = service.on('dismiss_equipment_alert').listen((_) {
      _dismiss();
    });

    _criticalSub = service.on('critical_alert').listen((event) {
      setState(() {
        _showConfirmation = false;
        _emergencyActive = true;
      });
    });
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _countdown--;
        if (_countdown <= 0) {
          timer.cancel();
          _emergencyActive = true;
          _showConfirmation = false;
        }
      });
    });
  }

  void _confirmSafe() {
    _countdownTimer?.cancel();
    Vibration.cancel();
    FlutterBackgroundService().invoke('user_confirmed_safe');
    _dismiss();
  }

  void _dismiss() {
    _countdownTimer?.cancel();
    if (mounted) {
      setState(() {
        _showConfirmation = false;
        _emergencyActive = false;
      });
    }
    widget.onDismiss?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (!_showConfirmation && !_emergencyActive) {
      return const SizedBox.shrink();
    }

    if (_emergencyActive) {
      return _buildCriticalOverlay();
    }

    return _buildWarningOverlay();
  }

  Widget _buildWarningOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.85),
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) => Transform.scale(
                  scale: _pulseAnimation.value,
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange,
                    size: 80,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'ANOMALIA DETECTADA',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              if (_alertType.isNotEmpty)
                Text(
                  _alertType.replaceAll('_', ' ').toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              if (_alertDetails.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                  child: Text(
                    _alertDetails,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                '$_countdown',
                style: TextStyle(
                  color: _countdown < 5 ? Colors.red : Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Tudo OK
                  ElevatedButton.icon(
                    onPressed: _confirmSafe,
                    icon: const Icon(Icons.check_circle, size: 28),
                    label: const Text('TUDO OK', style: TextStyle(fontSize: 18)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  // Parar máquina
                  ElevatedButton.icon(
                    onPressed: () {
                      _countdownTimer?.cancel();
                      setState(() {
                        _emergencyActive = true;
                        _showConfirmation = false;
                      });
                    },
                    icon: const Icon(Icons.dangerous, size: 28),
                    label: const Text('PARAR', style: TextStyle(fontSize: 18)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
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

  Widget _buildCriticalOverlay() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) => Container(
        color: Colors.red.withOpacity(0.3 + (_pulseAnimation.value * 0.2)),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 100),
                const SizedBox(height: 16),
                const Text(
                  'ALERTA CRITICO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'PARE A OPERACAO IMEDIATAMENTE',
                  style: TextStyle(color: Colors.red, fontSize: 16),
                ),
                const SizedBox(height: 32),
                const CircularProgressIndicator(color: Colors.white),
                const SizedBox(height: 16),
                const Text(
                  'Registrando incidente...',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _confirmSafe,
                  icon: const Icon(Icons.check),
                  label: const Text('FALSO ALARME - Cancelar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white24,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseController.dispose();
    _alertSub?.cancel();
    _dismissSub?.cancel();
    _criticalSub?.cancel();
    super.dispose();
  }
}

/// Widget compacto de status do IronSentinel (para HUD)
class IronSentinelStatusWidget extends StatelessWidget {
  final String level; // normal, attention, warning, critical
  final int anomalyCount;

  const IronSentinelStatusWidget({
    super.key,
    required this.level,
    this.anomalyCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final color = _colorForLevel(level);
    final icon = _iconForLevel(level);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.6), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(
            level.toUpperCase(),
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
          ),
          if (anomalyCount > 0) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: color.withOpacity(0.3),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$anomalyCount',
                style: TextStyle(color: color, fontSize: 9),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _colorForLevel(String level) {
    switch (level) {
      case 'critical': return Colors.red;
      case 'warning': return Colors.orange;
      case 'attention': return Colors.yellow;
      default: return Colors.green;
    }
  }

  IconData _iconForLevel(String level) {
    switch (level) {
      case 'critical': return Icons.error;
      case 'warning': return Icons.warning;
      case 'attention': return Icons.info;
      default: return Icons.shield;
    }
  }
}
