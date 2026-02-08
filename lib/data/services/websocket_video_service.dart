import 'dart:async';
import 'dart:convert';
import '../../core/config/app_config.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:logger/logger.dart';

/// ✅ DEDICATED WebSocket Service for VIDEO CALLS ONLY
/// This service connects to port 8090 (/ws/video) and handles ONLY video signaling
/// NEVER mix with audio WebSocket (port 8080)
class WebSocketVideoService {
  final Logger _logger = Logger();
  WebSocketChannel? _channel;
  final _messageController = StreamController<dynamic>.broadcast();

  // Reconnection settings
  static const int _maxReconnectAttempts = 3;
  static const Duration _reconnectDelay = Duration(seconds: 2);
  int _reconnectAttempts = 0;
  bool _intentionalDisconnect = false;
  String? _lastSessionId;

  // Callbacks
  Function()? onConnected;
  Function(String error)? onError;
  Function()? onDisconnected;

  // Video WebSocket URL (port 8090)
  String get _wsVideoUrl {
    try {
      return AppConfig.wsVideoUrl;
    } catch (e) {
      // Fallback se .env não tiver WS_VIDEO_URL
      _logger.w('⚠️ WS_VIDEO_URL não encontrado no .env, usando fallback');
      return 'wss://eva-ia.org:8090/ws/video';
    }
  }

  bool get isConnected => _channel != null;

  Stream<dynamic> get messages => _messageController.stream;

  Future<void> connect({String? sessionId}) async {
    if (_channel != null) {
      _logger.w('⚠️ Video WebSocket already connected');
      return;
    }

    _intentionalDisconnect = false;
    _lastSessionId = sessionId;

    try {
      _logger.i('🎥 Connecting to Video WebSocket: $_wsVideoUrl');
      final uri = Uri.parse(_wsVideoUrl);
      _channel = WebSocketChannel.connect(uri);

      _logger.i('✅ Video WebSocket connected successfully');
      _reconnectAttempts = 0;

      if (onConnected != null) onConnected!();

      _channel!.stream.listen(
        (message) {
          _messageController.add(message);
        },
        onError: (error) {
          _logger.e('❌ Video WebSocket error: $error');
          _messageController.addError(error);
          _handleDisconnection('Error: $error');
        },
        onDone: () {
          _logger.w('⚠️ Video WebSocket connection closed');
          _handleDisconnection('Connection closed');
        },
      );
    } catch (e) {
      _logger.e('❌ Error connecting to Video WebSocket: $e');
      _channel = null;
      if (onError != null) onError!(e.toString());

      // Tentar reconectar
      _attemptReconnect();
    }
  }

  void _handleDisconnection(String reason) {
    _channel = null;

    if (_intentionalDisconnect) {
      _logger.i('🔌 Disconnection was intentional');
      if (onDisconnected != null) onDisconnected!();
      return;
    }

    _logger.w('⚠️ Unexpected disconnection: $reason');
    _attemptReconnect();
  }

  Future<void> _attemptReconnect() async {
    if (_intentionalDisconnect) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _logger.e('❌ Max reconnection attempts reached');
      if (onError != null) {
        onError!('Falha ao reconectar após $_maxReconnectAttempts tentativas');
      }
      return;
    }

    _reconnectAttempts++;
    _logger.i('🔄 Attempting reconnection $_reconnectAttempts/$_maxReconnectAttempts...');

    await Future.delayed(_reconnectDelay * _reconnectAttempts);

    if (!_intentionalDisconnect) {
      await connect(sessionId: _lastSessionId);
    }
  }

  void sendMessage(Map<String, dynamic> message) {
    if (_channel == null) {
      _logger.e('❌ Cannot send message: Video WebSocket not connected');
      return;
    }

    try {
      final jsonMessage = jsonEncode(message);
      _channel!.sink.add(jsonMessage);
      _logger.d('📤 Video message sent: ${message['type']}');
    } catch (e) {
      _logger.e('❌ Error sending video message: $e');
    }
  }

  /// Envia ping para manter conexão viva
  void sendPing() {
    sendMessage({'type': 'ping', 'timestamp': DateTime.now().millisecondsSinceEpoch});
  }

  void disconnect() {
    _logger.i('🔌 Disconnecting Video WebSocket');
    _intentionalDisconnect = true;
    _channel?.sink.close();
    _channel = null;
    _reconnectAttempts = 0;
    if (onDisconnected != null) onDisconnected!();
  }

  void dispose() {
    disconnect();
    _messageController.close();
  }
}
