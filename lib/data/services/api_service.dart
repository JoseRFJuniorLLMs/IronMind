import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logger/logger.dart';
import '../../core/config/app_config.dart';

class ApiService {
  final Logger _logger = Logger();

  // 🔴 P0 FIX: Global timeout for all HTTP requests
  static const _defaultTimeout = Duration(seconds: 30);

  String get baseUrl => AppConfig.apiBaseUrl;
  String get audioUrl => AppConfig.apiAudioUrl;

  /// Busca idoso pelo CPF usando o endpoint específico
  Future<Map<String, dynamic>?> getOperatorByCpf(String cpf) async {
    try {
      _logger.i('🔍 Buscando idoso por CPF: $cpf');

      // Limpar CPF (remover pontos e traços)
      final cpfClean = cpf.replaceAll(RegExp(r'[^0-9]'), '');

      final url = Uri.parse('$baseUrl/operators/by-cpf/$cpfClean');
      _logger.i('📤 Request URL: $url');

      final response = await http.get(url).timeout(_defaultTimeout);

      _logger.i('📥 Response status: ${response.statusCode}');
      _logger.i('📥 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final idoso = jsonDecode(response.body);
        _logger.i('✅ Idoso encontrado!');
        _logger.i('📦 Data: $idoso');
        _logger.i('🔑 ID: ${idoso['id']} (${idoso['id'].runtimeType})');
        _logger.i('👤 Nome: ${idoso['nome']}');
        _logger.i('📞 Telefone: ${idoso['telefone']}');
        return idoso;
      } else if (response.statusCode == 404) {
        _logger.w('⚠️ CPF não encontrado');
        return null;
      } else {
        _logger.e(
          '❌ Erro ao buscar idoso: ${response.statusCode} - ${response.body}',
        );
        throw Exception(
          'Erro no servidor (${response.statusCode}). Tente novamente.',
        );
      }
    } catch (e) {
      _logger.e('❌ Erro ao buscar idoso por CPF: $e');
      return null;
    }
  }

  /// Sincroniza o token de notificação via CPF
  /// Retorna true se sincronizado com sucesso
  Future<bool> syncTokenByCpf({
    required String cpf,
    required String token,
  }) async {
    try {
      _logger.i('🔄 Sincronizando token para CPF: $cpf');
      final url = Uri.parse(
        '$baseUrl/operators/sync-token-by-cpf?cpf=$cpf&token=$token',
      );

      _logger.i('📤 Request URL: $url');

      final response = await http.patch(url, headers: {
        'Content-Type': 'application/json'
      }).timeout(_defaultTimeout);

      _logger.i('📥 Response status: ${response.statusCode}');
      _logger.i('📥 Response body: ${response.body}');

      if (response.statusCode == 200) {
        _logger.i('✅ Token sincronizado com sucesso');
        return true;
      } else {
        final errorBody = jsonDecode(response.body);
        _logger.e('❌ Falha ao sincronizar: ${response.statusCode}');
        _logger.e('❌ Error: ${errorBody['detail']}');
        return false;
      }
    } catch (e) {
      _logger.e('❌ Erro ao sincronizar token: $e');
      return false;
    }
  }

  /// [DEPRECATED] Use getOperatorByCpf() e syncTokenByCpf() separadamente

  /// Busca a lista completa de idosos
  Future<List<Map<String, dynamic>>> listOperators() async {
    try {
      _logger.i('🔍 Buscando idosos em: $baseUrl/idosos');
      final response = await http
          .get(Uri.parse('$baseUrl/idosos'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _logger.i('✅ ${data.length} idosos encontrados');
        return data.cast<Map<String, dynamic>>();
      }

      _logger.w('⚠️ Status ${response.statusCode} ao buscar idosos');
      return [];
    } catch (e) {
      _logger.e('❌ Erro ao listar idosos: $e');
      return [];
    }
  }

  /// Atualiza o token FCM do dispositivo
  Future<bool> updateDeviceToken(String cpf, String token) async {
    try {
      _logger.i('🔄 Sincronizando FCM token para CPF $cpf');
      final url = Uri.parse(
        '$baseUrl/operators/sync-token-by-cpf?cpf=$cpf&token=$token',
      );

      final response = await http.patch(url, headers: {
        'Content-Type': 'application/json'
      }).timeout(_defaultTimeout);

      if (response.statusCode == 200) {
        _logger.i('✅ Token sincronizado com sucesso');
        return true;
      } else {
        _logger.e('❌ Falha ao sincronizar: ${response.statusCode}');
        _logger.e('Body: ${response.body}');
        return false;
      }
    } catch (e) {
      _logger.e('❌ Erro de conexão: $e');
      return false;
    }
  }

  /// Obtém dados detalhados de um idoso
  Future<Map<String, dynamic>?> getOperator(int operatorId) async {
    try {
      _logger.i('🔍 Buscando dados do idoso: $operatorId');
      final response = await http
          .get(Uri.parse('$baseUrl/operators/$operatorId'))
          .timeout(_defaultTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _logger.i('✅ Dados do idoso obtidos');
        return data;
      }

      _logger.w('⚠️ Idoso não encontrado: status ${response.statusCode}');
      return null;
    } catch (e) {
      _logger.e('❌ Erro ao obter dados do idoso: $e');
      return null;
    }
  }

  /// Busca agendamentos pendentes
  Future<List<Map<String, dynamic>>> getUpcomingSchedules(int operatorId) async {
    try {
      _logger.i('📅 Buscando agendamentos para idoso: $operatorId');
      final response = await http
          .get(
            Uri.parse(
              '$baseUrl/agendamentos?operator_id=$operatorId&status=agendado',
            ),
          )
          .timeout(_defaultTimeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _logger.i('✅ ${data.length} agendamentos encontrados');
        return data.cast<Map<String, dynamic>>();
      }

      _logger.w('⚠️ Status ${response.statusCode} ao buscar agendamentos');
      return [];
    } catch (e) {
      _logger.e('❌ Erro ao buscar agendamentos: $e');
      return [];
    }
  }

  /// Lista todos os agendamentos de um idoso (qualquer status)
  Future<List<Map<String, dynamic>>> listAgendamentos(int operatorId) async {
    try {
      _logger.i('📅 Listando todos os agendamentos para idoso: $operatorId');
      final response = await http
          .get(
            Uri.parse('$baseUrl/agendamentos?operator_id=$operatorId'),
          )
          .timeout(_defaultTimeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _logger.i('✅ ${data.length} agendamentos encontrados');
        return data.cast<Map<String, dynamic>>();
      }

      _logger.w('⚠️ Status ${response.statusCode} ao listar agendamentos');
      return [];
    } catch (e) {
      _logger.e('❌ Erro ao listar agendamentos: $e');
      return [];
    }
  }

  /// Cria um novo agendamento
  Future<Map<String, dynamic>?> createAgendamento({
    required int operatorId,
    required DateTime dataHoraAgendada,
    String tipo = 'chamada_voz',
    String prioridade = 'normal',
    Map<String, dynamic>? dadosTarefa,
  }) async {
    try {
      _logger.i('📅 Criando novo agendamento para idoso: $operatorId');
      _logger.i('📞 Tipo: $tipo | Prioridade: $prioridade');
      _logger.i('🕐 Data/Hora: ${dataHoraAgendada.toIso8601String()}');

      final body = {
        'operator_id': operatorId,
        'tipo': tipo,
        'data_hora_agendada': dataHoraAgendada.toIso8601String(),
        'prioridade': prioridade,
        'status': 'agendado',
      };

      if (dadosTarefa != null) {
        body['dados_tarefa'] = jsonEncode(dadosTarefa);
      }

      _logger.i('📤 Request Body: ${jsonEncode(body)}');
      final url = Uri.parse('$baseUrl/agendamentos/');
      _logger.i('📤 Request URL: $url');

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_defaultTimeout);

      _logger.i('📥 Response Status: ${response.statusCode}');
      _logger.i('📥 Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        _logger.i('✅ Agendamento criado com ID: ${data['id']}');
        return data;
      }

      // ✅ Melhor tratamento de erros
      _logger.e('❌ Erro ao criar agendamento: ${response.statusCode}');
      _logger.e('❌ Response Body: ${response.body}');

      // Tentar parsear erro do backend
      try {
        final errorData = jsonDecode(response.body);
        if (errorData is Map && errorData.containsKey('detail')) {
          throw Exception(errorData['detail']);
        } else if (errorData is Map && errorData.containsKey('message')) {
          throw Exception(errorData['message']);
        } else {
          throw Exception('Erro ${response.statusCode}: ${response.body}');
        }
      } catch (e) {
        if (response.statusCode == 400) {
          throw Exception('Dados inválidos. Verifique as informações fornecidas.');
        } else if (response.statusCode == 404) {
          throw Exception('Endpoint não encontrado. Verifique a URL da API.');
        } else if (response.statusCode == 422) {
          throw Exception('Erro de validação: ${response.body}');
        } else if (response.statusCode == 500) {
          throw Exception('Erro interno do servidor. Tente novamente mais tarde.');
        } else {
          throw Exception('Erro ${response.statusCode}: ${response.body}');
        }
      }
    } on Exception {
      rethrow; // Re-throw para manter a mensagem de erro específica
    } catch (e) {
      _logger.e('❌ Erro ao criar agendamento: $e');
      if (e.toString().contains('TimeoutException')) {
        throw Exception('Timeout: Servidor não respondeu em 30 segundos');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('Erro de conexão: Verifique sua internet');
      }
      throw Exception('Erro ao conectar com o servidor: $e');
    }
  }

  /// Obtém detalhes de um agendamento específico
  Future<Map<String, dynamic>?> getAgendamento(int agendamentoId) async {
    try {
      _logger.i('📅 Buscando agendamento ID: $agendamentoId');
      final response = await http
          .get(
            Uri.parse('$baseUrl/agendamentos/$agendamentoId'),
          )
          .timeout(_defaultTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _logger.i('✅ Agendamento encontrado');
        return data;
      }

      _logger.w('⚠️ Agendamento não encontrado: ${response.statusCode}');
      return null;
    } catch (e) {
      _logger.e('❌ Erro ao buscar agendamento: $e');
      return null;
    }
  }

  /// Atualiza um agendamento completo
  Future<bool> updateAgendamento({
    required int agendamentoId,
    DateTime? dataHoraAgendada,
    String? tipo,
    String? status,
    String? prioridade,
    Map<String, dynamic>? dadosTarefa,
  }) async {
    try {
      _logger.i('📅 Atualizando agendamento ID: $agendamentoId');

      final body = <String, dynamic>{};

      if (dataHoraAgendada != null) {
        body['data_hora_agendada'] = dataHoraAgendada.toIso8601String();
      }
      if (tipo != null) body['tipo'] = tipo;
      if (status != null) body['status'] = status;
      if (prioridade != null) body['prioridade'] = prioridade;
      if (dadosTarefa != null) body['dados_tarefa'] = jsonEncode(dadosTarefa);

      final response = await http
          .put(
            Uri.parse('$baseUrl/agendamentos/$agendamentoId'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_defaultTimeout);

      if (response.statusCode == 200) {
        _logger.i('✅ Agendamento atualizado com sucesso');
        return true;
      }

      _logger.e('❌ Erro ao atualizar agendamento: ${response.statusCode}');
      return false;
    } catch (e) {
      _logger.e('❌ Erro ao atualizar agendamento: $e');
      return false;
    }
  }

  /// Atualiza apenas o status de um agendamento
  Future<bool> updateAgendamentoStatus({
    required int agendamentoId,
    required String status,
  }) async {
    try {
      _logger.i(
          '📅 Atualizando status do agendamento $agendamentoId para: $status');

      final response = await http
          .patch(
            Uri.parse('$baseUrl/agendamentos/$agendamentoId/status'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'status': status}),
          )
          .timeout(_defaultTimeout);

      if (response.statusCode == 200) {
        _logger.i('✅ Status atualizado com sucesso');
        return true;
      }

      _logger.e('❌ Erro ao atualizar status: ${response.statusCode}');
      return false;
    } catch (e) {
      _logger.e('❌ Erro ao atualizar status: $e');
      return false;
    }
  }

  /// Cancela um agendamento (atualiza status para 'cancelado')
  Future<bool> cancelAgendamento(int agendamentoId) async {
    return updateAgendamentoStatus(
      agendamentoId: agendamentoId,
      status: 'cancelado',
    );
  }

  /// Obter histórico de chamadas (Migrado do CallRepository)
  Future<List<Map<String, dynamic>>> getCallHistory(int operatorId) async {
    try {
      _logger.i('📚 Fetching call history for idoso: $operatorId');

      final url = Uri.parse('$audioUrl/call-logs?operator_id=$operatorId');
      final response = await http.get(url).timeout(_defaultTimeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _logger.i('✅ Fetched ${data.length} call logs');
        return data.cast<Map<String, dynamic>>();
      } else {
        _logger.e('❌ Failed to fetch call history: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      _logger.e('❌ Error fetching call history: $e');
      return [];
    }
  }

  /// Marcar agendamento como realizado (Migrado do CallRepository)
  Future<bool> markScheduleAsCompleted(int agendamentoId) async {
    try {
      _logger.i('✅ Marking schedule as completed: $agendamentoId');

      final url = Uri.parse('$baseUrl/agendamentos/$agendamentoId');
      final response = await http
          .patch(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'status': 'concluido',
              'data_hora_realizada': DateTime.now().toIso8601String(),
            }),
          )
          .timeout(_defaultTimeout);

      if (response.statusCode == 200) {
        _logger.i('✅ Schedule marked as completed');
        return true;
      } else {
        _logger.e('❌ Failed to mark schedule: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      _logger.e('❌ Error marking schedule: $e');
      return false;
    }
  }

  /// Salva o histórico da chamada
  Future<bool> saveCallLog({
    required String sessionId,
    required int operatorId,
    required DateTime startTime,
    required DateTime endTime,
    required Duration duration,
    required bool wasSuccessful,
    String? errorMessage,
  }) async {
    try {
      _logger.i('💾 Salvando log de chamada: $sessionId');

      // 🎯 MODIFICADO: Usa audioUrl (Porta 8080)
      final response = await http.post(
        Uri.parse('$audioUrl/call-logs'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'session_id': sessionId,
          'operator_id': operatorId,
          'start_time': startTime.toIso8601String(),
          'end_time': endTime.toIso8601String(),
          'duration_seconds': duration.inSeconds,
          'was_successful': wasSuccessful,
          'error_message': errorMessage,
        }),
      );

      final success = response.statusCode == 200 || response.statusCode == 201;

      if (success) {
        _logger.i('✅ Log de chamada salvo');
      } else {
        _logger.e('❌ Erro ao salvar log: ${response.statusCode}');
      }

      return success;
    } catch (e) {
      _logger.e('❌ Erro ao salvar log de chamada: $e');
      return false;
    }
  }

  /// Reporta erros críticos
  Future<bool> reportError(
    String sessionId,
    String type,
    String message,
  ) async {
    try {
      _logger.i('⚠️ Reportando erro: $type');

      final response = await http.post(
        Uri.parse('$audioUrl/call-errors'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'session_id': sessionId,
          'error_type': type,
          'error_message': message,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      final success = response.statusCode == 201;

      if (success) {
        _logger.i('✅ Erro reportado');
      } else {
        _logger.e('❌ Falha ao reportar: ${response.statusCode}');
      }

      return success;
    } catch (e) {
      _logger.e('❌ Erro ao reportar falha: $e');
      return false;
    }
  }

  /// Verifica se o servidor está online
  Future<bool> checkHealth() async {
    try {
      _logger.i('🏥 Verificando saúde do servidor...');
      final rootUrl = baseUrl.endsWith('/api/v1')
          ? baseUrl.substring(0, baseUrl.length - 7)
          : baseUrl;

      final response = await http
          .get(Uri.parse('$rootUrl/health'))
          .timeout(const Duration(seconds: 5));

      final isHealthy = response.statusCode == 200;

      if (isHealthy) {
        _logger.i('✅ Servidor online');
      } else {
        _logger.w('⚠️ Servidor retornou: ${response.statusCode}');
      }

      return isHealthy;
    } catch (e) {
      _logger.e('❌ Servidor offline ou erro: $e');
      return false;
    }
  }

  /// Inicia uma vídeo chamada
  Future<Map<String, dynamic>> startVideoCall(int operatorId) async {
    try {
      _logger.i('📞 Iniciando vídeo chamada para idoso ID: $operatorId');

      final response = await http
          .post(
            Uri.parse('$baseUrl/video-calls/start'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'operator_id': operatorId}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _logger.i('✅ Vídeo chamada iniciada: ${data['session_id']}');
        return data;
      } else {
        _logger.e('❌ Erro ao iniciar vídeo chamada: ${response.statusCode}');
        throw Exception(
          'Erro ao iniciar vídeo chamada: ${response.statusCode}',
        );
      }
    } catch (e) {
      _logger.e('❌ Erro ao iniciar vídeo chamada: $e');
      rethrow;
    }
  }

  /// Envia logs de erro do app para o backend
  Future<bool> sendErrorLog({
    required String level,
    required String message,
    String? details,
    String? deviceInfo,
    String? appVersion,
    String? userCpf,
  }) async {
    try {
      _logger.i('📤 Enviando log de erro para backend...');
      final url = Uri.parse('$baseUrl/logs/mobile');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'level': level,
          'message': message,
          'details': details,
          'device_info': deviceInfo,
          'app_version': appVersion,
          'user_cpf': userCpf,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      _logger.e('❌ Erro crítico ao enviar log: $e');
      return false;
    }
  }

  /// Último erro de sincronização para exibir na UI
  String? lastVitalSignsError;

  /// Sincroniza sinais vitais (Watch Data)
  /// Retorna true se enviou com sucesso
  /// Endpoint correto: /api/v1/saude/sinais-vitais/bulk
  ///
  /// Campos aceitos pelo backend:
  /// - bpm: frequência cardíaca
  /// - bpm_repouso: FC em repouso
  /// - pressao_sistolica, pressao_diastolica: pressão arterial
  /// - spo2: saturação de oxigênio
  /// - glicose_sangue: glicemia
  /// - frequencia_respiratoria: freq. respiratória
  Future<bool> sendVitalSigns({
    required int operatorId,
    required List<Map<String, dynamic>> vitalSigns,
  }) async {
    lastVitalSignsError = null;

    try {
      _logger.i(
        '⌚ Enviando ${vitalSigns.length} sinais vitais para backend...',
      );
      _logger.i('📡 URL: $baseUrl/saude/sinais-vitais/bulk');
      _logger.i('👤 Cliente ID: $operatorId');

      // Endpoint correto: /api/v1/saude/sinais-vitais/bulk
      final url = Uri.parse('$baseUrl/saude/sinais-vitais/bulk');

      // Agrupa sinais vitais por timestamp para enviar em um único registro
      final registros = _groupVitalSignsByTimestamp(operatorId, vitalSigns);

      final body = jsonEncode({'registros': registros});

      _logger.d('📦 Payload: $body');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 201 || response.statusCode == 200) {
        _logger.i('✅ Sinais vitais sincronizados com sucesso!');
        return true;
      } else if (response.statusCode == 404) {
        lastVitalSignsError = 'Endpoint não encontrado (404). Verifique o backend.';
        _logger.e('❌ Endpoint /saude/sinais-vitais/bulk não existe no backend');
        return false;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        lastVitalSignsError = 'Não autorizado. Faça login novamente.';
        _logger.e('❌ Erro de autenticação: ${response.statusCode}');
        return false;
      } else if (response.statusCode >= 500) {
        lastVitalSignsError = 'Erro no servidor (${response.statusCode})';
        _logger.e('❌ Erro do servidor: ${response.statusCode} - ${response.body}');
        return false;
      } else {
        lastVitalSignsError = 'Erro ${response.statusCode}';
        _logger.e(
          '❌ Erro ao sincronizar sinais: ${response.statusCode} - ${response.body}',
        );
        return false;
      }
    } on TimeoutException {
      lastVitalSignsError = 'Timeout - servidor não respondeu';
      _logger.e('❌ Timeout ao enviar sinais vitais');
      return false;
    } catch (e) {
      // Detectar erros de conexão
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('socket') || errorStr.contains('connection') ||
          errorStr.contains('network') || errorStr.contains('host')) {
        lastVitalSignsError = 'Sem conexão com servidor';
      } else {
        lastVitalSignsError = 'Erro: ${e.runtimeType}';
      }
      _logger.e('❌ Erro ao enviar sinais: $e');
      return false;
    }
  }

  /// Agrupa sinais vitais por timestamp e converte para o formato do backend
  /// O backend espera campos específicos (bpm, spo2, etc.) ao invés de tipo/valor genérico
  List<Map<String, dynamic>> _groupVitalSignsByTimestamp(
    int clienteId,
    List<Map<String, dynamic>> vitalSigns,
  ) {
    // Agrupa por timestamp (minuto)
    final Map<String, Map<String, dynamic>> grouped = {};

    for (final v in vitalSigns) {
      final timestamp = v['data_hora'] ?? v['timestamp_coleta'] ?? DateTime.now().toIso8601String();
      // Normaliza para o minuto (ignora segundos para agrupar)
      final key = timestamp.toString().substring(0, 16);

      grouped.putIfAbsent(key, () => {
        'cliente_id': clienteId,
        'timestamp_coleta': timestamp,
      });

      // Mapeia tipo genérico para campo específico do backend
      final tipo = (v['tipo'] ?? '').toString().toLowerCase();
      final valor = v['valor'];

      switch (tipo) {
        case 'heart_rate':
        case 'heartrate':
        case 'bpm':
        case 'frequencia_cardiaca':
          grouped[key]!['bpm'] = valor;
          break;
        case 'resting_heart_rate':
        case 'bpm_repouso':
          grouped[key]!['bpm_repouso'] = valor;
          break;
        case 'blood_pressure_systolic':
        case 'systolic':
        case 'pressao_sistolica':
          grouped[key]!['pressao_sistolica'] = valor;
          break;
        case 'blood_pressure_diastolic':
        case 'diastolic':
        case 'pressao_diastolica':
          grouped[key]!['pressao_diastolica'] = valor;
          break;
        case 'blood_oxygen':
        case 'spo2':
        case 'oxygen_saturation':
        case 'saturacao':
          grouped[key]!['spo2'] = valor;
          break;
        case 'blood_glucose':
        case 'glucose':
        case 'glicose':
        case 'glicose_sangue':
          grouped[key]!['glicose_sangue'] = valor;
          break;
        case 'respiratory_rate':
        case 'frequencia_respiratoria':
          grouped[key]!['frequencia_respiratoria'] = valor;
          break;
        case 'steps':
        case 'passos':
          // Passos vão para outra tabela (atividades), mas podemos enviar aqui também
          grouped[key]!['passos'] = valor;
          break;
        default:
          _logger.w('⚠️ Tipo de sinal vital desconhecido: $tipo');
      }
    }

    final result = grouped.values.toList();
    _logger.i('📊 Agrupados ${vitalSigns.length} sinais em ${result.length} registros');
    return result;
  }

  // ✅ Send ICE Candidate (WebRTC)
  Future<void> sendIceCandidate(
    String sessionId,
    Map<String, dynamic> candidate,
  ) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/video/candidate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'session_id': sessionId,
          'sender': 'mobile',
          'type': 'candidate',
          'payload': candidate,
        }),
      );
    } catch (e) {
      _logger.e('❌ Failed to send ICE candidate: $e');
    }
  }

  // ✅ Get Video Answer (SDP Answer from operator)
  Future<String?> getVideoAnswer(String sessionId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/video/session/$sessionId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['sdp_answer']; // Pode ser null se ainda não respondeu
      }
      return null;
    } catch (e) {
      _logger.e('❌ Failed to get video answer: $e');
      return null;
    }
  }

  // ✅ Get Operator ICE Candidates
  Future<List<Map<String, dynamic>>> getOperatorCandidates(
    String sessionId,
    int sinceId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/video/session/$sessionId/candidates?since=$sinceId',
        ),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((e) => e as Map<String, dynamic>).toList();
      }
      return [];
    } catch (e) {
      _logger.e('❌ Failed to get operator candidates: $e');
      return [];
    }
  }

  // =====================================================================
  // MEDICAMENTOS
  // =====================================================================

  /// Lista medicamentos de um idoso
  Future<Map<String, dynamic>> getMedicamentos(int operatorId) async {
    try {
      _logger.i('💊 Buscando medicamentos para idoso: $operatorId');
      final response = await http
          .get(Uri.parse('$baseUrl/medicamentos?operator_id=$operatorId'))
          .timeout(_defaultTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _logger.i('✅ Medicamentos carregados');
        return {'success': true, 'medicamentos': data};
      }

      return {'success': false, 'message': 'Erro ${response.statusCode}'};
    } catch (e) {
      _logger.e('❌ Erro ao buscar medicamentos: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Cria um novo medicamento
  Future<Map<String, dynamic>> criarMedicamento(dynamic medicamento) async {
    try {
      _logger.i('💊 Criando medicamento: ${medicamento.nome}');
      final response = await http
          .post(
            Uri.parse('$baseUrl/medicamentos'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(medicamento.toJson()),
          )
          .timeout(_defaultTimeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        _logger.i('✅ Medicamento criado');
        return {'success': true, 'medicamento': data};
      }

      return {'success': false, 'message': 'Erro ${response.statusCode}'};
    } catch (e) {
      _logger.e('❌ Erro ao criar medicamento: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Atualiza um medicamento
  Future<Map<String, dynamic>> atualizarMedicamento(dynamic medicamento) async {
    try {
      _logger.i('💊 Atualizando medicamento: ${medicamento.nome}');
      final response = await http
          .put(
            Uri.parse('$baseUrl/medicamentos/${medicamento.id}'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(medicamento.toJson()),
          )
          .timeout(_defaultTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _logger.i('✅ Medicamento atualizado');
        return {'success': true, 'medicamento': data};
      }

      return {'success': false, 'message': 'Erro ${response.statusCode}'};
    } catch (e) {
      _logger.e('❌ Erro ao atualizar medicamento: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Registra tomada de medicamento
  Future<Map<String, dynamic>> registrarTomadaMedicamento({
    required int medicamentoId,
    required String status,
    String? observacao,
  }) async {
    try {
      _logger.i('💊 Registrando tomada: $medicamentoId ($status)');
      final response = await http
          .post(
            Uri.parse('$baseUrl/medicamentos/$medicamentoId/registros'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'status': status,
              'data_hora': DateTime.now().toIso8601String(),
              'observacao': observacao,
            }),
          )
          .timeout(_defaultTimeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        _logger.i('✅ Tomada registrada');
        return {'success': true};
      }

      return {'success': false, 'message': 'Erro ${response.statusCode}'};
    } catch (e) {
      _logger.e('❌ Erro ao registrar tomada: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // =====================================================================
  // CONTATOS DE EMERGENCIA
  // =====================================================================

  /// Lista contatos de emergencia de um idoso
  Future<Map<String, dynamic>> getContatosEmergencia(int operatorId) async {
    try {
      _logger.i('📞 Buscando contatos de emergencia para idoso: $operatorId');
      final response = await http
          .get(Uri.parse('$baseUrl/contatos-emergencia?operator_id=$operatorId'))
          .timeout(_defaultTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _logger.i('✅ Contatos carregados');
        return {'success': true, 'contatos': data};
      }

      return {'success': false, 'message': 'Erro ${response.statusCode}'};
    } catch (e) {
      _logger.e('❌ Erro ao buscar contatos: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Cria um novo contato de emergencia
  Future<Map<String, dynamic>> criarContatoEmergencia(dynamic contato) async {
    try {
      _logger.i('📞 Criando contato: ${contato.nome}');
      final response = await http
          .post(
            Uri.parse('$baseUrl/contatos-emergencia'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(contato.toJson()),
          )
          .timeout(_defaultTimeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        _logger.i('✅ Contato criado');
        return {'success': true, 'contato': data};
      }

      return {'success': false, 'message': 'Erro ${response.statusCode}'};
    } catch (e) {
      _logger.e('❌ Erro ao criar contato: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Atualiza um contato de emergencia
  Future<Map<String, dynamic>> atualizarContatoEmergencia(dynamic contato) async {
    try {
      _logger.i('📞 Atualizando contato: ${contato.nome}');
      final response = await http
          .put(
            Uri.parse('$baseUrl/contatos-emergencia/${contato.id}'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(contato.toJson()),
          )
          .timeout(_defaultTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _logger.i('✅ Contato atualizado');
        return {'success': true, 'contato': data};
      }

      return {'success': false, 'message': 'Erro ${response.statusCode}'};
    } catch (e) {
      _logger.e('❌ Erro ao atualizar contato: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Remove um contato de emergencia
  Future<Map<String, dynamic>> removerContatoEmergencia(int contatoId) async {
    try {
      _logger.i('📞 Removendo contato: $contatoId');
      final response = await http
          .delete(Uri.parse('$baseUrl/contatos-emergencia/$contatoId'))
          .timeout(_defaultTimeout);

      if (response.statusCode == 200 || response.statusCode == 204) {
        _logger.i('✅ Contato removido');
        return {'success': true};
      }

      return {'success': false, 'message': 'Erro ${response.statusCode}'};
    } catch (e) {
      _logger.e('❌ Erro ao remover contato: $e');
      return {'success': false, 'message': e.toString()};
    }
  }
}
