import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Indicador visual de sincronização de dados de saúde
/// Mostra ícone de relógio animado quando sincronizando
class HealthSyncIndicator extends StatelessWidget {
  final bool isSyncing;
  final bool hasError;
  final bool permissionsDenied;
  final DateTime? lastSyncTime;
  final VoidCallback? onTap;

  const HealthSyncIndicator({
    super.key,
    required this.isSyncing,
    this.hasError = false,
    this.permissionsDenied = false,
    this.lastSyncTime,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isSyncing ? null : onTap,
      child: Tooltip(
        message: isSyncing
            ? "Sincronizando..."
            : permissionsDenied
                ? "Permissões de saúde negadas"
                : hasError
                    ? "Erro na última sincronia"
                    : "Sincronizar dados de saúde",
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: permissionsDenied || hasError
                ? Colors.red.withOpacity(0.3)
                : Colors.white.withOpacity(0.2), // ✅ Translúcido como Sentinela
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ícone de relógio com animação
              AnimatedOpacity(
                opacity: isSyncing ? 1.0 : 0.7,
                duration: const Duration(milliseconds: 300),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: isSyncing ? 1.0 : 0.0),
                  duration: const Duration(seconds: 2),
                  builder: (context, value, child) {
                    return Transform.rotate(
                      angle: value * 2 * 3.14159, // Rotação completa
                      child: Icon(
                        permissionsDenied
                            ? Icons.warning_amber_rounded
                            : hasError
                                ? Icons.sync_problem
                                : Icons.watch_later,
                        color: isSyncing
                            ? const Color(0xFF9F70D8) // Roxo EVA
                            : (permissionsDenied || hasError)
                                ? Colors.orangeAccent
                                : Colors
                                    .white, // ✅ Branco quando não sincronizando
                        size: 24,
                        shadows: const [
                          Shadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    );
                  },
                  onEnd: () {
                    // Repetir animação se ainda estiver sincronizando
                    if (isSyncing) {
                      (context as Element).markNeedsBuild();
                    }
                  },
                ),
              ),

              if (lastSyncTime != null && !isSyncing) ...[
                const SizedBox(width: 6),
                Text(
                  _formatLastSync(lastSyncTime!),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white, // ✅ Branco para contraste
                    fontWeight: FontWeight.w500,
                    shadows: [
                      Shadow(
                        color: Colors.black26,
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatLastSync(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'Agora';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else {
      return DateFormat('dd/MM').format(time);
    }
  }
}
