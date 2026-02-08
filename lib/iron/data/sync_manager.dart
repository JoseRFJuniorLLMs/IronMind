import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'local_database.dart';
import 'inspection_model.dart';

/// Gerencia sincronização em background quando conectividade disponível
/// IronMind é OFFLINE FIRST - sync é oportunista, nunca bloqueia operação
class SyncManager {
  final LocalDatabase database;
  final String? cloudEndpoint; // Google Cloud Functions endpoint

  Timer? _syncTimer;
  bool _isSyncing = false;
  StreamSubscription? _connectivitySub;
  bool _isOnline = false;

  // Callbacks
  void Function(int synced, int total)? onSyncProgress;
  void Function(String error)? onSyncError;

  SyncManager({
    required this.database,
    this.cloudEndpoint,
  });

  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;

  /// Inicia monitoramento de conectividade
  Future<void> initialize() async {
    // Check conectividade atual
    final result = await Connectivity().checkConnectivity();
    _isOnline = !result.contains(ConnectivityResult.none);

    // Monitora mudanças
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final wasOnline = _isOnline;
      _isOnline = !results.contains(ConnectivityResult.none);

      if (!wasOnline && _isOnline) {
        debugPrint('[SyncManager] Conectividade restaurada - iniciando sync');
        syncPending();
      }
    });

    // Sync periódico a cada 5 minutos (quando online)
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (_isOnline && !_isSyncing) {
        syncPending();
      }
    });

    // Sync inicial se online
    if (_isOnline) {
      syncPending();
    }

    debugPrint('[SyncManager] Inicializado. Online: $_isOnline');
  }

  /// Sincroniza inspeções pendentes com cloud
  Future<void> syncPending() async {
    if (_isSyncing || !_isOnline) return;
    if (cloudEndpoint == null) {
      debugPrint('[SyncManager] Sem endpoint configurado - sync desabilitado');
      return;
    }

    _isSyncing = true;
    debugPrint('[SyncManager] Iniciando sincronização...');

    try {
      final pending = await database.getUnsyncedInspections();
      if (pending.isEmpty) {
        debugPrint('[SyncManager] Nada para sincronizar');
        _isSyncing = false;
        return;
      }

      debugPrint('[SyncManager] ${pending.length} inspeções pendentes');
      int synced = 0;

      for (final inspection in pending) {
        try {
          final success = await _uploadInspection(inspection);
          if (success) {
            await database.markSynced(inspection.id);
            synced++;
            onSyncProgress?.call(synced, pending.length);
          }
        } catch (e) {
          debugPrint('[SyncManager] Falha ao sincronizar ${inspection.id}: $e');
          onSyncError?.call('Falha: ${inspection.id}');
          // Continua com próxima inspeção
        }
      }

      debugPrint('[SyncManager] Sync completo: $synced/${pending.length}');
    } finally {
      _isSyncing = false;
    }
  }

  /// Upload individual de inspeção para Google Cloud
  Future<bool> _uploadInspection(InspectionRecord inspection) async {
    // TODO: Implementar HTTP POST para Cloud Functions
    // Endpoint: $cloudEndpoint/api/v1/inspections
    // Body: inspection.toJson()
    // Headers: Authorization: Bearer <firebase_token>

    final payload = jsonEncode(inspection.toJson());
    debugPrint('[SyncManager] Upload: ${inspection.id} (${payload.length} bytes)');

    // Placeholder - será implementado com http package
    await Future.delayed(const Duration(milliseconds: 100));
    return true;
  }

  /// Força sync imediato (chamado por comando de voz "sincronizar")
  Future<void> forceSync() async {
    if (!_isOnline) {
      debugPrint('[SyncManager] Sem conexão - sync impossível');
      return;
    }
    await syncPending();
  }

  Future<void> dispose() async {
    _syncTimer?.cancel();
    await _connectivitySub?.cancel();
    _isSyncing = false;
  }
}
