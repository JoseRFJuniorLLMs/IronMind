import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import '../../core/config/app_config.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:logger/logger.dart';
import 'storage_service.dart';

class WebSocketService {
  // ✅ SINGLETON PATTERN - Garante mesma instância em todo o app
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  final Logger _logger = Logger();
  WebSocketChannel? _channel;
  final _messageController = StreamController<dynamic>.broadcast();

  // Stream específico para resultados de scan de medicamentos
  final _medicationScanController = StreamController<Map<String, dynamic>>.broadcast();

  // 🔴 P0 FIX: Reconnection tracking
  int _reconnectAttempts = 0;
  static const _maxReconnectAttempts = 10;
  static const _baseReconnectDelay = Duration(seconds: 3);

  // Busca a URL do AppConfig
  String get _wsUrl => AppConfig.wsUrl;

  bool get isConnected => _channel != null;

  Stream<dynamic> get messages => _messageController.stream;

  Stream<Map<String, dynamic>> get medicationScanStream => _medicationScanController.stream;

  Future<void> connect() async {
    if (_channel != null) {
      _logger.w('⚠️ WebSocket already connected');
      return;
    }

    try {
      _logger.i('🔌 Connecting to WebSocket: $_wsUrl');
      final uri = Uri.parse(_wsUrl);
      _channel = WebSocketChannel.connect(uri);

      // await _channel!.ready; // Removed for compatibility

      _logger.i('✅ WebSocket connected successfully');
      // ✅ Reset reconnection counter on successful connect
      _reconnectAttempts = 0;

      // ❌ REMOVIDO: Auto-registro (agora feito manualmente pelo CallProvider)
      // _registerClient();

      _channel!.stream.listen(
        (message) {
          _messageController.add(message);

          // Processar mensagens específicas de medicação
          try {
            final decoded = jsonDecode(message as String);
            if (decoded is Map<String, dynamic>) {
              final action = decoded['action'] as String?;

              // Filtrar mensagens relacionadas ao scanner de medicamentos
              if (action == 'medication_scan_result' ||
                  action == 'medication_identified' ||
                  action == 'medication_error') {
                _medicationScanController.add(decoded);
              }
            }
          } catch (e) {
            // Ignorar erros de parsing, não é JSON ou não é medicação
          }
        },
        onError: (error) async {
          _logger.e('❌ WebSocket error: $error');
          _messageController.addError(error);
          await _reconnect();
        },
        onDone: () async {
          _logger.w('⚠️ WebSocket connection closed');
          _channel = null;
          await _reconnect();
        },
      );

      _startPingTimer();
    } catch (e) {
      _logger.e('❌ Error connecting to WebSocket: $e');
      _channel = null;
      rethrow; // Permitir que quem chamou trate o erro inicial
    }
  }

  void _registerClient() {
    try {
      // Get CPF from storage
      final cpf = StorageService.getOperatorCpf();

      if (cpf == null || cpf.isEmpty) {
        _logger.e('❌ CPF não encontrado no storage, não é possível registrar');
        return;
      }

      sendMessage({
        'type': 'register',
        'user_type': 'patient',
        'cpf': cpf,
      });

      _logger.i('📝 Client registered as patient with CPF: $cpf');
    } catch (e) {
      _logger.e('❌ Error registering client: $e');
    }
  }

  Timer? _pingTimer;

  void _startPingTimer() {
    _pingTimer?.cancel();
    // Ping a cada 5 segundos para evitar timeout do servidor (10s)
    _pingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_channel != null) {
        try {
          // Enviar ping simples
          sendMessage({'type': 'ping'});
        } catch (e) {
          _logger.e('❌ Error sending ping: $e');
          // Se falhar o ping, força reconexão
          _reconnect();
        }
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _reconnect() async {
    // 🔴 P0 FIX: Check max attempts
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _logger.e(
        '❌ Max reconnection attempts ($_maxReconnectAttempts) reached. Giving up.',
      );
      _messageController.addError('Max reconnection attempts reached');
      return;
    }

    _reconnectAttempts++;
    _logger.i(
      '🔄 Reconnection attempt $_reconnectAttempts/$_maxReconnectAttempts',
    );

    // Limpar timer anterior para evitar múltiplos pings
    _pingTimer?.cancel();
    _pingTimer = null;

    // 🔴 P0 FIX: Exponential backoff (3s, 6s, 12s, 24s, 30s max)
    final delaySeconds =
        (_baseReconnectDelay.inSeconds * (1 << (_reconnectAttempts - 1))).clamp(
      3,
      30,
    );
    _logger.i('⏳ Waiting ${delaySeconds}s before reconnect...');
    await Future.delayed(Duration(seconds: delaySeconds));

    try {
      // Se estava conectado, fecha antes de abrir novo
      if (_channel != null) {
        try {
          await _channel!.sink.close();
        } catch (_) {}
        _channel = null;
      }
      await connect();
      // ✅ Reset counter on successful connection
      _reconnectAttempts = 0;
    } catch (e) {
      _logger.e('❌ Reconnection attempt $_reconnectAttempts failed: $e');
      // Will retry on next error or timeout
    }
  }

  void sendMessage(Map<String, dynamic> message) {
    if (_channel == null) {
      _logger.e('❌ Cannot send message: WebSocket not connected');
      // Tentar reconectar?
      _reconnect();
      return;
    }

    try {
      final jsonMessage = jsonEncode(message);
      _channel!.sink.add(jsonMessage);
      _logger.i('📤 Message sent: ${message['type']}');
    } catch (e) {
      _logger.e('❌ Error sending message: $e');
      _reconnect();
    }
  }

  void sendBytes(List<int> data) {
    if (_channel == null) return;

    // Fragmentar pacotes grandes (4KB)
    const int chunkSize = 4096;
    int offset = 0;
    while (offset < data.length) {
      final end =
          (offset + chunkSize > data.length) ? data.length : offset + chunkSize;
      final chunk = data.sublist(offset, end);
      try {
        _channel!.sink.add(chunk);
      } catch (e) {
        _logger.e('❌ Error sending bytes chunk: $e');
        _reconnect();
        break;
      }
      offset = end;
    }
  }

  Future<void> disconnect() async {
    _logger.i('🔌 Disconnecting WebSocket...');

    _pingTimer?.cancel();
    _pingTimer = null;

    if (_channel != null) {
      try {
        await _channel!.sink.close();
      } catch (e) {
        _logger.e('❌ Error closing WebSocket: $e');
      }
      _channel = null;
    }

    _logger.i('✅ WebSocket disconnected');
  }

  // =====================================================================
  // MEDICATION SCANNER METHODS
  // =====================================================================

  /// Envia imagem de medicamento para análise visual
  void sendMedicationImage({
    required String sessionId,
    required Uint8List imageBytes,
    required List<dynamic> candidateMedications,
  }) {
    if (_channel == null) {
      _logger.e('❌ Cannot send medication image: WebSocket not connected');
      return;
    }

    try {
      // Converter imagem para base64
      final base64Image = base64Encode(imageBytes);

      // Enviar mensagem estruturada
      sendMessage({
        'type': 'medication_scan',
        'action': 'identify',
        'session_id': sessionId,
        'image_data': base64Image,
        'image_format': 'jpeg',
        'candidate_medications': candidateMedications,
        'timestamp': DateTime.now().toIso8601String(),
      });

      _logger.i('📤 Medication image sent for analysis (${imageBytes.length} bytes)');
    } catch (e) {
      _logger.e('❌ Error sending medication image: $e');
    }
  }

  /// Confirma que o paciente tomou o medicamento
  void confirmMedicationTaken({
    required String sessionId,
    String? medicationId,
  }) {
    if (_channel == null) {
      _logger.e('❌ Cannot confirm medication: WebSocket not connected');
      return;
    }

    try {
      sendMessage({
        'type': 'medication_scan',
        'action': 'confirm_taken',
        'session_id': sessionId,
        'medication_id': medicationId,
        'confirmed_at': DateTime.now().toIso8601String(),
      });

      _logger.i('✅ Medication taken confirmed');
    } catch (e) {
      _logger.e('❌ Error confirming medication: $e');
    }
  }

  /// Cancela o scan de medicamento
  void cancelMedicationScan(String sessionId) {
    if (_channel == null) {
      _logger.e('❌ Cannot cancel scan: WebSocket not connected');
      return;
    }

    try {
      sendMessage({
        'type': 'medication_scan',
        'action': 'cancel',
        'session_id': sessionId,
        'cancelled_at': DateTime.now().toIso8601String(),
      });

      _logger.i('❌ Medication scan cancelled');
    } catch (e) {
      _logger.e('❌ Error cancelling scan: $e');
    }
  }

  /// Reporta feedback sobre identificação incorreta
  void reportIncorrectIdentification({
    required String sessionId,
    required String medicationId,
    required String feedback,
    String? correctMedicationName,
  }) {
    if (_channel == null) {
      _logger.e('❌ Cannot report feedback: WebSocket not connected');
      return;
    }

    try {
      sendMessage({
        'type': 'medication_scan',
        'action': 'report_incorrect',
        'session_id': sessionId,
        'medication_id': medicationId,
        'feedback': feedback,
        'correct_medication_name': correctMedicationName,
        'reported_at': DateTime.now().toIso8601String(),
      });

      _logger.i('📝 Incorrect identification reported');
    } catch (e) {
      _logger.e('❌ Error reporting feedback: $e');
    }
  }

  // =====================================================================

  void dispose() {
    _logger.i('🗑️ Disposing WebSocket service...');
    disconnect();
    _messageController.close();
    _medicationScanController.close();
    _logger.i('✅ WebSocket service disposed');
  }
}
