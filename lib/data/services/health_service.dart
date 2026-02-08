import 'dart:io';
import 'dart:convert';
import 'package:health/health.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'storage_service.dart';

/// Status do Health Connect
enum HealthConnectStatus {
  available,          // Health Connect instalado e pronto
  notInstalled,       // Health Connect nao instalado
  notSupported,       // Dispositivo nao suporta (Android < 14 sem app)
  updateRequired,     // Health Connect precisa de atualizacao
}

class HealthService {
  final Logger _logger = Logger();
  final Health _health = Health();

  /// Define os tipos de dados que queremos capturar
  static const List<HealthDataType> _dataTypesAndroid = [
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.SLEEP_SESSION,
  ];

  static const List<HealthDataType> _dataTypesIOS = [
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.SLEEP_SESSION,
  ];

  /// Verifica se o Health Connect esta disponivel (Android)
  /// Retorna o status atual do Health Connect
  Future<HealthConnectStatus> checkHealthConnectStatus() async {
    if (!Platform.isAndroid) {
      // iOS usa HealthKit que vem pre-instalado
      return HealthConnectStatus.available;
    }

    try {
      _logger.i('🔍 Verificando status do Health Connect...');

      // Usar o metodo getHealthConnectSdkStatus do plugin health
      final status = await _health.getHealthConnectSdkStatus();

      _logger.i('📱 Health Connect SDK Status: $status');

      switch (status) {
        case HealthConnectSdkStatus.sdkAvailable:
          _logger.i('✅ Health Connect disponivel');
          return HealthConnectStatus.available;

        case HealthConnectSdkStatus.sdkUnavailable:
          _logger.w('⚠️ Health Connect nao instalado');
          return HealthConnectStatus.notInstalled;

        case HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired:
          _logger.w('⚠️ Health Connect precisa de atualizacao');
          return HealthConnectStatus.updateRequired;

        default:
          _logger.w('⚠️ Status desconhecido: $status');
          return HealthConnectStatus.notSupported;
      }
    } catch (e) {
      _logger.e('❌ Erro ao verificar Health Connect: $e');
      // Se der erro, assumir que nao esta instalado
      return HealthConnectStatus.notInstalled;
    }
  }

  /// Verifica se o Health Connect esta disponivel (metodo simples)
  Future<bool> isHealthConnectAvailable() async {
    final status = await checkHealthConnectStatus();
    return status == HealthConnectStatus.available;
  }

  /// Solicita permissões ao usuário
  /// Retorna true se as permissoes foram concedidas
  /// Lanca excecao se Health Connect nao estiver disponivel
  Future<bool> requestPermissions() async {
    try {
      // PASSO 1: Verificar se Health Connect esta disponivel (Android)
      if (Platform.isAndroid) {
        final hcStatus = await checkHealthConnectStatus();

        if (hcStatus == HealthConnectStatus.notInstalled) {
          _logger.e('❌ Health Connect nao instalado');
          throw Exception('Health Connect nao esta instalado. Por favor, instale da Play Store.');
        }

        if (hcStatus == HealthConnectStatus.updateRequired) {
          _logger.e('❌ Health Connect precisa de atualizacao');
          throw Exception('Health Connect precisa ser atualizado. Por favor, atualize na Play Store.');
        }

        if (hcStatus != HealthConnectStatus.available) {
          _logger.e('❌ Health Connect nao suportado');
          throw Exception('Health Connect nao e suportado neste dispositivo.');
        }

        // PASSO 2: Verificar permissao de Activity Recognition
        final activityStatus = await Permission.activityRecognition.request();
        if (activityStatus != PermissionStatus.granted) {
          _logger.w('⚠️ Permissão de Activity Recognition negada');
        }

        // PASSO 3: Verificar permissao de Sensors
        final sensorsStatus = await Permission.sensors.request();
        if (sensorsStatus != PermissionStatus.granted) {
          _logger.w('⚠️ Permissão de Sensores negada');
        }
      }

      // PASSO 4: Solicitar permissões do Health Connect / HealthKit
      _logger.i('📋 Solicitando autorizacao do Health Connect...');

      bool requested = await _health.requestAuthorization(
        Platform.isAndroid ? _dataTypesAndroid : _dataTypesIOS,
        permissions: Platform.isAndroid
            ? _dataTypesAndroid.map((e) => HealthDataAccess.READ).toList()
            : _dataTypesIOS.map((e) => HealthDataAccess.READ).toList(),
      );

      if (requested) {
        _logger.i('✅ Permissões de saúde concedidas');
      } else {
        _logger.w('⚠️ Permissões de saúde negadas ou parcialmente concedidas');
      }

      return requested;
    } catch (e) {
      _logger.e('❌ Erro ao solicitar permissões de saúde: $e');
      rethrow; // Propagar excecao para a UI tratar
    }
  }

  /// Verifica se as permissoes ja foram concedidas
  Future<bool> hasPermissions() async {
    try {
      if (Platform.isAndroid) {
        final status = await checkHealthConnectStatus();
        if (status != HealthConnectStatus.available) {
          return false;
        }
      }

      // Verificar se temos autorizacao para ler os dados
      final types = Platform.isAndroid ? _dataTypesAndroid : _dataTypesIOS;
      final permissions = types.map((e) => HealthDataAccess.READ).toList();

      final hasAuth = await _health.hasPermissions(types, permissions: permissions);
      return hasAuth ?? false;
    } catch (e) {
      _logger.e('❌ Erro ao verificar permissoes: $e');
      return false;
    }
  }

  /// Abre as configurações do Health Connect no Android
  Future<void> openHealthConnectSettings() async {
    if (!Platform.isAndroid) return;

    try {
      _logger.i('🔧 Abrindo configurações do Health Connect...');
      await _health.installHealthConnect();
    } catch (e) {
      _logger.e('❌ Erro ao abrir Health Connect: $e');
    }
  }

  /// Busca passos das últimas 24 horas
  Future<int> fetchSteps() async {
    try {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);

      int? steps = await _health.getTotalStepsInInterval(midnight, now);
      _logger.i('👣 Passos hoje: ${steps ?? 0}');
      return steps ?? 0;
    } catch (e) {
      _logger.e('❌ Erro ao buscar passos: $e');
      return 0;
    }
  }

  /// Busca os últimos registros de batimentos cardíacos
  Future<List<HealthDataPoint>> fetchHeartRate() async {
    try {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(hours: 24));

      List<HealthDataPoint> healthData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE],
        startTime: yesterday,
        endTime: now,
      );

      // Limpar duplicatas
      healthData = _health.removeDuplicates(healthData);

      _logger.i('❤️ ${healthData.length} registros de batimentos encontrados');
      return healthData;
    } catch (e) {
      _logger.e('❌ Erro ao buscar batimentos: $e');
      return [];
    }
  }

  /// Busca sessões de sono
  Future<List<HealthDataPoint>> fetchSleep() async {
    try {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(hours: 24));

      List<HealthDataPoint> healthData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.SLEEP_SESSION],
        startTime: yesterday,
        endTime: now,
      );

      healthData = _health.removeDuplicates(healthData);

      _logger.i('😴 ${healthData.length} sessões de sono encontradas');
      return healthData;
    } catch (e) {
      _logger.e('❌ Erro ao buscar sono: $e');
      return [];
    }
  }

  /// Sincroniza dados agora (Usado em Foreground e Background)
  Future<void> syncNow() async {
    _logger.i('🔄 syncNow triggered...');
    try {
      // 1. Tentar reenviar dados salvos anteriormente
      await _retrySavedQueue();

      // 2. Verificar permissões (Em background isso pode falhar se não tiver concedido antes)
      // Assumimos que o usuário já concedeu na UI

      // 3. Buscar dados
      final steps = await fetchSteps();
      final heartRate = await fetchHeartRate();
      final sleep = await fetchSleep();

      // 4. Preparar payload
      List<Map<String, dynamic>> vitalSigns = [];

      if (steps > 0) {
        vitalSigns.add({
          'tipo': 'passos',
          'valor': steps.toString(),
          'unidade': 'count',
          'data_hora': DateTime.now().toIso8601String(),
        });
      }

      if (heartRate.isNotEmpty) {
        final lastHeartRate = heartRate.last;
        vitalSigns.add({
          'tipo': 'bpm',
          'valor': lastHeartRate.value.toString(),
          'unidade': 'bpm',
          'data_hora': lastHeartRate.dateFrom.toIso8601String(),
        });
      }

      if (sleep.isNotEmpty) {
        final lastSleep = sleep.last;
        final durationHours =
            lastSleep.dateTo.difference(lastSleep.dateFrom).inHours;
        vitalSigns.add({
          'tipo': 'sono',
          'valor': durationHours.toString(),
          'unidade': 'horas',
          'data_hora': lastSleep.dateFrom.toIso8601String(),
        });
      }

      // 5. Enviar para API via ApiService
      if (vitalSigns.isNotEmpty) {
        final idosoId = StorageService.getIdosoId();

        if (idosoId != null) {
          _logger.i(
              '📤 Sending ${vitalSigns.length} vital signs to API for ID: $idosoId...');

          final success = await ApiService()
              .sendVitalSigns(idosoId: idosoId, vitalSigns: vitalSigns);

          if (!success) {
            // ✅ RETRY: Salvar na fila local se falhar
            _logger.w('⚠️ Failed to send, saving to local queue...');
            await _saveToLocalQueue(idosoId, vitalSigns);
          }
        } else {
          _logger.w(
              '⚠️ syncNow: idosoId não encontrado no Storage. Sincronização cancelada.');
        }
      } else {
        _logger.i('ℹ️ No new health data to sync.');
      }
    } catch (e) {
      _logger.e('❌ Error in syncNow: $e');
    }
  }

  /// Salva dados na fila local para retry posterior
  Future<void> _saveToLocalQueue(
    int idosoId,
    List<Map<String, dynamic>> vitalSigns,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString('pending_vital_signs') ?? '[]';
      final List<dynamic> queue = jsonDecode(queueJson);

      queue.add({
        'timestamp': DateTime.now().toIso8601String(),
        'idoso_id': idosoId,
        'data': vitalSigns,
      });

      await prefs.setString('pending_vital_signs', jsonEncode(queue));
      _logger.i('💾 Saved ${vitalSigns.length} vital signs to local queue');
    } catch (e) {
      _logger.e('❌ Error saving to local queue: $e');
    }
  }

  /// Tenta reenviar dados salvos na fila local
  Future<void> _retrySavedQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString('pending_vital_signs');

      if (queueJson == null || queueJson == '[]') {
        return; // Fila vazia
      }

      final List<dynamic> queue = jsonDecode(queueJson);
      if (queue.isEmpty) return;

      _logger.i('🔄 Retrying ${queue.length} pending sync(s)...');

      final List<dynamic> failedItems = [];

      for (final item in queue) {
        final idosoId = item['idoso_id'] as int;
        final vitalSigns = (item['data'] as List)
            .map((e) => e as Map<String, dynamic>)
            .toList();

        final success = await ApiService()
            .sendVitalSigns(idosoId: idosoId, vitalSigns: vitalSigns);

        if (!success) {
          failedItems.add(item); // Manter na fila se falhar novamente
        } else {
          _logger.i('✅ Retry successful for ${vitalSigns.length} items');
        }
      }

      // Atualizar fila apenas com itens que falharam
      await prefs.setString('pending_vital_signs', jsonEncode(failedItems));

      if (failedItems.isEmpty) {
        _logger.i('✅ All pending syncs completed!');
      } else {
        _logger.w('⚠️ ${failedItems.length} sync(s) still pending');
      }
    } catch (e) {
      _logger.e('❌ Error retrying queue: $e');
    }
  }
}
