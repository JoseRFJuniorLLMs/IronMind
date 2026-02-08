import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'dart:async';
import '../../core/sentinela/sentinela_service.dart';

class SentinelaStatusWidget extends StatefulWidget {
  final bool showLabel;
  final bool compact;

  const SentinelaStatusWidget({
    super.key,
    this.showLabel = false,
    this.compact = true,
  });

  @override
  State<SentinelaStatusWidget> createState() => _SentinelaStatusWidgetState();
}

class _SentinelaStatusWidgetState extends State<SentinelaStatusWidget>
    with SingleTickerProviderStateMixin {
  String _status = "Protegido";
  String _level = "SafetyLevel.SAFE";
  bool _isRunning = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  StreamSubscription? _updateSubscription;

  @override
  void initState() {
    super.initState();

    // Pulse animation for alert states
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _checkServiceStatus();
    _listenToUpdates();
  }

  Future<void> _checkServiceStatus() async {
    final running = await SentinelaService.isRunning();
    if (mounted) {
      setState(() {
        _isRunning = running;
      });
    }
  }

  void _listenToUpdates() {
    _updateSubscription = FlutterBackgroundService().on('update').listen((event) {
      if (event != null && mounted) {
        setState(() {
          _level = event['level'] ?? "SafetyLevel.SAFE";
          _updateStatusText();
          _updateAnimation();
        });
      }
    });
  }

  void _updateStatusText() {
    switch (_level) {
      case "SafetyLevel.SAFE":
        _status = "Protegido";
        break;
      case "SafetyLevel.MONITORING":
        _status = "Monitorando";
        break;
      case "SafetyLevel.PRE_ALERT":
        _status = "Atenção!";
        break;
      case "SafetyLevel.ALERT":
        _status = "ALERTA";
        break;
      case "SafetyLevel.EMERGENCY":
        _status = "EMERGÊNCIA";
        break;
      default:
        _status = "Iniciando...";
    }
    _isRunning = true;
  }

  void _updateAnimation() {
    if (_level == "SafetyLevel.ALERT" || _level == "SafetyLevel.EMERGENCY") {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  Color _getStatusColor() {
    if (!_isRunning) return Colors.grey;

    switch (_level) {
      case "SafetyLevel.SAFE":
        return Colors.green;
      case "SafetyLevel.MONITORING":
        return Colors.blue;
      case "SafetyLevel.PRE_ALERT":
        return Colors.orange;
      case "SafetyLevel.ALERT":
      case "SafetyLevel.EMERGENCY":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon() {
    if (!_isRunning) return Icons.shield_outlined;

    switch (_level) {
      case "SafetyLevel.SAFE":
        return Icons.verified_user;
      case "SafetyLevel.MONITORING":
        return Icons.remove_red_eye;
      case "SafetyLevel.PRE_ALERT":
        return Icons.warning_amber_rounded;
      case "SafetyLevel.ALERT":
      case "SafetyLevel.EMERGENCY":
        return Icons.emergency;
      default:
        return Icons.shield;
    }
  }

  @override
  void dispose() {
    _updateSubscription?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor();
    final icon = _getStatusIcon();

    if (widget.compact) {
      return Tooltip(
        message: "Sentinela: $_status",
        child: GestureDetector(
          onLongPress: () => _showSentinelaMenu(context),
          child: ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
          ),
        ),
      );
    }

    // Expanded version with label
    return GestureDetector(
      onTap: () => _showSentinelaMenu(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color, width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _pulseAnimation,
              child: Icon(icon, color: color, size: 24),
            ),
            if (widget.showLabel) ...[
              const SizedBox(width: 8),
              Text(
                _status,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showSentinelaMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Status indicator
              Icon(
                _getStatusIcon(),
                size: 64,
                color: _getStatusColor(),
              ),
              const SizedBox(height: 16),
              Text(
                'Sentinela: $_status',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isRunning
                    ? 'Monitoramento de emergência ativo'
                    : 'Serviço não está rodando',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),

              // Test button (for debugging)
              if (_isRunning) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      // Show confirmation before triggering test
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Teste de Alerta'),
                          content: const Text(
                            'Isso irá simular uma detecção de emergência.\n\n'
                            'Use apenas para testar o sistema.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('CANCELAR'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                              ),
                              child: const Text('TESTAR'),
                            ),
                          ],
                        ),
                      );

                      if (confirmed == true) {
                        await SentinelaService.triggerTestAlert();
                      }
                    },
                    icon: const Icon(Icons.science),
                    label: const Text('Testar Alerta'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),

              // Info text
              Text(
                'Palavras-chave monitoradas:\n'
                '"socorro", "ajuda", "caí", "emergência", "help", "eva", "acorda"',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
