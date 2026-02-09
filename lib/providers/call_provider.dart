import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart'; // ✅ Import CallKit
import 'package:permission_handler/permission_handler.dart';
import 'package:package_info_plus/package_info_plus.dart';

// ✅ Importar Native Audio Service
import '../data/services/native_audio_service.dart';
import '../data/services/storage_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../data/services/firebase_service.dart';
import 'dart:convert';
import '../data/services/websocket_service.dart';
import '../data/services/websocket_video_service.dart'; // ✅ DEDICATED Video WebSocket
import '../data/services/api_service.dart';
import '../data/services/webrtc_service.dart' show WebRTCService, WebRTCConnectionState;
import '../core/sentinela/iron_sentinel_service.dart';

enum CallStatus { idle, ringing, connecting, connected, ending, ended, error }

class CallProvider with ChangeNotifier {
  final Logger _logger = Logger();

  // ✅ Native Audio Service (Substitui WebView)
  final NativeAudioService _nativeAudio = NativeAudioService();
  // ✅ Audio WebSocket (port 8080, /ws/pcm)
  final WebSocketService _wsService = WebSocketService();
  StreamSubscription? _wsSubscription;

  // ✅ Video WebSocket (port 8090, /ws/video) - SEPARATE CHANNEL
  final WebSocketVideoService _wsVideoService = WebSocketVideoService();
  StreamSubscription? _wsVideoSubscription;

  final ApiService _apiService = ApiService();
  final _platformChannel = const MethodChannel(
    'com.eva.br/minimize',
  ); // ✅ Channel para minimizar
  AudioPlayer? _ringtonePlayer;

  CallStatus _status = CallStatus.idle;
  String? _currentSessionId;
  Map<String, dynamic>? _currentUserData;
  DateTime? _callStartTime;
  String? _errorMessage;

  Timer? _durationTimer;
  Duration _callDuration = Duration.zero;

  bool _isMuted = false;
  bool _isSpeakerOn = true;

  // Debug Stats
  int _totalPacketsReceived = 0;
  DateTime? _lastPacketTime;
  String? _debugStatus; // Status para exibir na tela
  String? _fcmToken; // Token para exibir na tela
  double get currentVolume => _currentVolume; // ✅ Getter para o visualizador
  double _currentVolume = 0.0; // ✅ Volume real para o visualizador

  // ✅ Track initialization state
  bool _isInitializing = false;
  Future<void>? _initializationFuture;

  // ✅ Mudança 2: Construtor privado (não mais público)
  CallProvider._internal() {
    _logger.i('🎬 CallProvider criado');

    // ✅ REGISTRAR CALLBACK DO FIREBASE (CRÍTICO!)
    // Fazemos isso no construtor para garantir que ouça chamadas
    // mesmo que o WebView demore a inicializar.
    FirebaseService.onVoiceCallReceived = (sessionId, userData) {
      _logger.i('📞 Callback do Firebase disparado no Provider!');
      receiveCall(sessionId, userData: userData);
    };
  }

  // ✅ Construtor de fallback para erros de inicialização
  CallProvider.fallback() {
    _logger.w('⚠️ CallProvider criado em modo FALLBACK');
  }

  // ✅ Mudança 2: Factory constructor assíncrono
  static Future<CallProvider> create() async {
    final provider = CallProvider._internal();
    // 🚀 Não esperar inicialização para não travar o app (runApp)
    // O WebView inicia em background
    provider.initialize();
    return provider;
  }

  // Getters
  CallStatus get status => _status;
  String? get currentSessionId => _currentSessionId;
  Map<String, dynamic>? get currentUserData => _currentUserData;
  bool get isCallActive => _status == CallStatus.connected;
  String? get errorMessage => _errorMessage;
  Duration get callDuration => _callDuration;
  bool get isMuted => _isMuted;
  bool get isSpeakerOn => _isSpeakerOn;
  bool get isSpeaking => false; // TODO: Implement VAD later if needed
  int get totalPacketsReceived => _totalPacketsReceived;
  DateTime? get lastPacketTime => _lastPacketTime;
  String? get debugStatus => _debugStatus;
  String? get fcmToken => _fcmToken;

  // ✅ Cache do Widget WebView (REMOVIDO MODO NATIVO)
  // Widget? _cachedWebView;

  // ✅ Método para obter o widget InAppWebView (COM CACHE)
  // Widget getWebViewWidget() {
  //   _cachedWebView ??= _evaService.createWebView();
  //   return _cachedWebView!;
  // }

  /// Inicializar o serviço (chamar no initState ou antes de usar)
  Future<void> initialize() async {
    // ✅ Se já está inicializando, retorna o Future existente
    if (_isInitializing) {
      _logger.w('⚠️ Inicialização já em andamento, aguardando...');
      return _initializationFuture!;
    }

    if (_nativeAudio.isInitialized) {
      _logger.w('⚠️ Audio Service já inicializado');
      return;
    }

    _isInitializing = true;
    _initializationFuture = _initializeInternal();
    await _initializationFuture;
  }

  Future<void> _initializeInternal() async {
    try {
      _logger.i('🎬 Inicializando CallProvider com Native Audio...');

      _nativeAudio.onAudioRecorded = (data) {
        // 🎤 Áudio NATIVO -> Dart -> WebSocket
        _wsService.sendBytes(data);
      };

      // ✅ Inicializar Native Audio
      await _nativeAudio.initialize();

      // ✅ Escutar Volume Real
      _nativeAudio.volumeStream.listen((vol) {
        _currentVolume = vol;
        notifyListeners();
      });

      _logger.i('✅ CallProvider inicializado com sucesso');
      _debugStatus = "Inicializado";

      // ✅ Tentar carregar token do Storage primeiro (cache)
      _fcmToken = await StorageService.getFcmToken();

      // ✅ SEMPRE verificar token real do Firebase para garantir que não está obsoleto
      try {
        final freshToken = await FirebaseMessaging.instance.getToken();
        if (freshToken != null) {
          if (_fcmToken != freshToken) {
            _logger.w('⚠️ Token mudou ou não estava salvo! Atualizando...');
            _fcmToken = freshToken;
            await StorageService.saveFcmToken(freshToken);
            _debugStatus = "Token Atualizado (Relogar sug.)";
          }
          _fcmToken = freshToken; // Garante que usa o mais recente
        }
      } catch (e) {
        _logger.e('❌ Erro ao validar token fresco: $e');
      }

      notifyListeners();
    } catch (e) {
      _logger.e('❌ Erro ao inicializar CallProvider: $e');
      _debugStatus = "Erro Init: $e";
      notifyListeners();
      rethrow;
    } finally {
      _isInitializing = false;
    }
  }

  // ✅ Método Debug para atualizar status externo
  void updateDebugStatus(String status) {
    _debugStatus = status;
    // Log também
    _logger.i('🐞 DEBUG STATUS: $status');
    notifyListeners();
  }

  // ✅ Atualizar token manualmente (usado no login)
  void updateFcmToken(String token) {
    _fcmToken = token;
    _logger.i('🔑 Token atualizado no provider: ${token.substring(0, 10)}...');
    notifyListeners();
  }

  /// Método disparado pelo FirebaseService
  Future<void> receiveCall(
    String sessionId, {
    Map<String, dynamic>? userData,
  }) async {
    _logger.i('📞 ========================================');
    _logger.i('📞 RECEBENDO CHAMADA');
    _logger.i('📞 Session ID: $sessionId');
    _logger.i('📞 ========================================');

    _currentSessionId = sessionId;
    _currentUserData = userData;
    _status = CallStatus.ringing;
    _logger.i('🔔 Provider Status changed to RINGING. Notifying listeners...');
    _errorMessage = null;

    // Tocar ringtone (Reativado a pedido do usuário)
    _playRingtone();

    notifyListeners();
  }

  /// ✅ Método para iniciar chamada ATIVA (Usuário ligando)
  /// Gera session_id e chama acceptCall() diretamente
  void startOutgoingCall() async {
    _logger.i('🚀 Iniciando chamada ativa (Outgoing)...');

    // ✅ Gerar session_id ANTES de tudo para consistência
    _currentSessionId = 'mobile-${DateTime.now().millisecondsSinceEpoch}';
    _logger.i('🔑 Session ID gerado: $_currentSessionId');

    // ✅ Define status ANTES de navegar
    _status = CallStatus.connecting;
    notifyListeners();

    // ✅ Chamar acceptCall diretamente (sem lógica de agendamento)
    acceptCall();
  }

  /// Método chamado pelo botão "Atender" ou por startOutgoingCall
  Future<void> acceptCall() async {
    _logger.i('✅ ========================================');
    _logger.i('✅ CHAMADA ACEITA PELO USUÁRIO');
    _logger.i('✅ Iniciando conexão via WebView...');
    _logger.i('✅ ========================================');

    // ✅ AGUARDAR inicialização se ainda estiver em andamento
    if (_initializationFuture != null) {
      _logger.i('⏳ Aguardando inicialização do WebView...');
      try {
        await _initializationFuture;
        _logger.i('✅ WebView inicializado, prosseguindo...');
      } catch (e) {
        _logger.e('❌ Erro na inicialização: $e');
        _status = CallStatus.error;
        _errorMessage = "Erro ao inicializar WebView: ${e.toString()}";

        _apiService.sendErrorLog(
          level: 'CRITICAL',
          message: 'Failed to initialize WebView during Call Accept',
          details: e.toString(),
        );

        notifyListeners();
        return;
      }
    }

    // ✅ Verificar se Native Audio está pronto
    if (!_nativeAudio.isInitialized) {
      await _nativeAudio.initialize();
    }

    // Parar ringtone
    await _stopRingtone();

    _status = CallStatus.connecting;
    notifyListeners();

    try {
      // ✅ Verificar permissão de microfone
      var status = await Permission.microphone.request();
      if (!status.isGranted) {
        _logger.e('❌ Permissão de microfone negada!');
        _status = CallStatus.error;
        _errorMessage = "Permissão de microfone necessária";

        _apiService.sendErrorLog(
          level: 'WARNING',
          message: 'Microphone Permission Denied',
          details: 'User denied permission',
        );

        notifyListeners();
        return;
      }

      // ✅ FIX P0: Pausar Monitoramento de Segundo Plano (Libera Mic)
      _logger.i('🛡️ Pausando Sentinela para chamada...');
      await IronSentinelService.pause();

      // ✅ FIX P0: Conectar WebSocket PRIMEIRO
      _logger.i('🔌 Conectando ao WebSocket via Dart...');
      await _wsService.connect();

      // ✅ Configurar listener de mensagens ANTES de enviar comandos
      _wsSubscription?.cancel();
      final sessionCreatedCompleter = Completer<void>();

      _wsSubscription = _wsService.messages.listen(
        (data) {
          if (data is List<int>) {
            // 🔊 Áudio recebido -> Native Player
            _nativeAudio.playChunk(Uint8List.fromList(data));

            _totalPacketsReceived++;
            _lastPacketTime = DateTime.now();
          } else if (data is String) {
            // 📨 Controle -> JSON
            try {
              final msg = jsonDecode(data);
              _logger.i('📨 MSG Dart: ${msg['type']}');

              if (msg['type'] == 'session_created') {
                _logger.i('🎉 SESSÃO CRIADA! Liberando captura de áudio.');
                if (!sessionCreatedCompleter.isCompleted) {
                  sessionCreatedCompleter.complete();
                }
                if (_status != CallStatus.connected) {
                  _status = CallStatus.connected;
                  _callStartTime = DateTime.now();
                  _startTimer();
                  notifyListeners();
                }
              } else if (msg['type'] == 'error') {
                _logger.e('❌ Erro recebido do Backend: ${msg['message']}');
                _status = CallStatus.error;
                _errorMessage =
                    msg['message'] ?? 'Erro desconhecido do servidor';
                notifyListeners();
              }
            } catch (e) {
              _logger.w('⚠️ Erro ao decodificar JSON: $e');
            }
          }
        },
        onError: (e) {
          _logger.e('❌ Erro no WebSocket: $e');
          _status = CallStatus.error;
          _errorMessage = "Erro na conexão: $e";

          _apiService.sendErrorLog(
            level: 'ERROR',
            message: 'WebSocket Error',
            details: e.toString(),
          );

          notifyListeners();
        },
      );

      // ✅ Enviar REGISTER com user_type
      final cpf = StorageService.getOperatorCpf();
      if (cpf == null) throw Exception('CPF não encontrado');

      // ✅ FIX CRÍTICO: Avisar ao CallKit que a chamada foi atendida
      // Usar _currentSessionId se existir (chamada agendada) ou gerar novo (chamada manual)
      if (_currentSessionId == null) {
        _currentSessionId = 'mobile-${DateTime.now().millisecondsSinceEpoch}';
        _logger.i('🔑 Session ID gerado: $_currentSessionId');
      }

      if (_currentSessionId != null) {
        _logger.i(
          '📞 Avisando CallKit que chamada foi conectada: $_currentSessionId',
        );
        await FlutterCallkitIncoming.setCallConnected(_currentSessionId!);
      }

      _logger.i('🔐 Registrando cliente: $cpf');
      _wsService.sendMessage(
          {'type': 'register', 'user_type': 'patient', 'cpf': cpf});

      await Future.delayed(const Duration(milliseconds: 500));

      // ✅ Enviar START_CALL com session_id consistente
      final sessionId = _currentSessionId!;
      _logger.i('🚀 Iniciando sessão: $sessionId');
      _wsService.sendMessage({
        'type': 'start_call',
        'cpf': cpf,
        'session_id': sessionId,
      });

      // ✅ FIX P0: AGUARDAR session_created ANTES de iniciar áudio
      _logger.i('⏳ Aguardando confirmação do backend...');
      await sessionCreatedCompleter.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw Exception('Timeout aguardando session_created');
        },
      );

      // ✅ SÓ AGORA iniciar captura de áudio
      _logger.i('🚀 Iniciando Captura de Áudio NATIVO...');
      await _nativeAudio.start();

      _logger.i('✅ ========================================');
      _logger.i('✅ EVA INICIADA COM SUCESSO!');
      _logger.i('✅ Motor de áudio web ativo');
      _logger.i('✅ ========================================');
    } catch (e, stackTrace) {
      _logger.e('❌ ========================================');
      _logger.e('❌ ERRO AO ATENDER CHAMADA');
      _logger.e('❌ Erro: $e');
      _logger.e('❌ Stack: $stackTrace');
      _logger.e('❌ ========================================');

      _status = CallStatus.error;
      _errorMessage = "Erro ao conectar: ${e.toString()}";

      _apiService.sendErrorLog(
        level: 'CRITICAL',
        message: 'Exception during Call Connection',
        details: '$e\n$stackTrace',
      );

      notifyListeners();
    }
  }

  // ✅ WebRTC Service (Exposed for VideoScreen)
  final WebRTCService _webrtcService = WebRTCService();
  WebRTCService get webrtcService => _webrtcService;

  // ✅ INICIAR CASCATA DE VÍDEO (Emergência) - WebSocket Only
  Future<void> startVideoCall() async {
    _logger.i('🎥 ========================================');
    _logger.i('🎥 INICIANDO CASCATA DE VÍDEO (WEBRTC)');
    _logger.i('🎥 ✅ CANAL SEPARADO (porta 8090)');
    _logger.i('🎥 ========================================');

    _status = CallStatus.connecting;
    notifyListeners();

    try {
      // ✅ FIX: Pausar Sentinela ANTES de abrir câmera/microfone
      _logger.i('🛡️ Pausando Sentinela para vídeo chamada...');
      final micReleased = await IronSentinelService.pause();
      if (!micReleased) {
        _logger.w('⚠️ Timeout aguardando liberação do mic, tentando mesmo assim...');
      }

      // 1. Inicializar WebRTC (Agora com mic/câmera livres)
      await _webrtcService.initialize();

      // ✅ Configurar callback de estado da conexão WebRTC
      _webrtcService.onConnectionStateChange = (state) {
        _logger.i('🔗 WebRTC State Changed: $state');
        if (state == WebRTCConnectionState.connected) {
          _status = CallStatus.connected;
          notifyListeners();
        } else if (state == WebRTCConnectionState.failed) {
          _status = CallStatus.error;
          _errorMessage = 'Conexão WebRTC falhou';
          notifyListeners();
        }
      };

      _webrtcService.onError = (error) {
        _logger.e('❌ WebRTC Error: $error');
        _errorMessage = error;
      };

      // 2. Gerar Oferta SDP
      String sdpOffer = await _webrtcService.createOffer();

      // 3. Gerar ID da Sessão
      final sessionId = 'video-${DateTime.now().millisecondsSinceEpoch}';
      final cpf = StorageService.getOperatorCpf();
      if (cpf == null) throw Exception('CPF não encontrado');

      // 4. ✅ Conectar ao WebSocket de VÍDEO (porta 8090, /ws/video)
      if (!_wsVideoService.isConnected) {
        await _wsVideoService.connect(sessionId: sessionId);
      }

      // ✅ Configurar callbacks de erro do WebSocket
      _wsVideoService.onError = (error) {
        _logger.e('❌ Video WebSocket Error: $error');
        if (_status == CallStatus.connecting) {
          _status = CallStatus.error;
          _errorMessage = 'Erro de conexão: $error';
          notifyListeners();
        }
      };

      // 5. ✅ Obter informações do dispositivo dinamicamente
      final packageInfo = await PackageInfo.fromPlatform();
      final devicePlatform = Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'unknown');

      // 6. ✅ Registrar cliente mobile e aguardar confirmação
      _logger.i('📝 Registrando cliente de vídeo...');
      final registerCompleter = Completer<bool>();

      // Escutar confirmação de registro
      late StreamSubscription regSubscription;
      regSubscription = _wsVideoService.messages.listen((data) {
        if (data is String) {
          try {
            final msg = jsonDecode(data);
            if (msg['type'] == 'register_ack' || msg['type'] == 'registered') {
              _logger.i('✅ Registro confirmado pelo servidor');
              if (!registerCompleter.isCompleted) {
                registerCompleter.complete(true);
              }
              regSubscription.cancel();
            } else if (msg['type'] == 'error' && msg['context'] == 'register') {
              _logger.e('❌ Erro no registro: ${msg['message']}');
              if (!registerCompleter.isCompleted) {
                registerCompleter.complete(false);
              }
              regSubscription.cancel();
            }
          } catch (e) {
            // Ignorar erros de parse aqui
          }
        }
      });

      _wsVideoService.sendMessage({
        'type': 'register',
        'session_id': sessionId,
        'client_type': 'mobile_patient',
        'cpf': cpf,
        'device_info': {
          'platform': devicePlatform,
          'app_version': packageInfo.version,
          'build_number': packageInfo.buildNumber,
        }
      });

      // Aguardar confirmação com timeout (mas não bloquear se não vier)
      try {
        await registerCompleter.future.timeout(
          const Duration(seconds: 2),
          onTimeout: () {
            _logger.w('⚠️ Timeout aguardando confirmação de registro, continuando...');
            return true; // Continuar mesmo sem confirmação
          },
        );
      } catch (e) {
        _logger.w('⚠️ Erro aguardando registro: $e');
      }

      // 7. ✅ Enviar Oferta via WebSocket (FORMATO PADRÃO WebRTC - simplificado)
      _logger.i('📤 Enviando SDP Offer...');
      _wsVideoService.sendMessage({
        'type': 'webrtc_signal',
        'session_id': sessionId,
        'payload': {
          'type': 'offer',
          'sdp': sdpOffer, // ✅ FIX: SDP direto, sem aninhamento duplo
        }
      });

      // 8. ✅ Notificar operadores web sobre chamada entrante
      final operatorName = StorageService.getOperatorNome();
      _wsVideoService.sendMessage({
        'type': 'incoming_call_notification',
        'session_id': sessionId,
        'caller': {
          'cpf': cpf,
          'name': operatorName ?? 'Operador',
        },
        'timestamp': DateTime.now().toIso8601String()
      });

      // 9. ✅ Configurar listener de ICE Candidates (via WebSocket de VÍDEO)
      _webrtcService.onIceCandidate = (candidate) {
        _wsVideoService.sendMessage({
          'type': 'webrtc_signal',
          'session_id': sessionId,
          'payload': {
            'type': 'candidate',
            'candidate': candidate.toMap(),
          }
        });
      };

      // 10. ✅ Escutar Answer e Candidates via WebSocket de VÍDEO
      _wsVideoSubscription?.cancel();
      _wsVideoSubscription = _wsVideoService.messages.listen((data) {
        if (data is String) {
          try {
            final msg = jsonDecode(data);

            if (msg['type'] == 'webrtc_signal') {
              _handleWebRTCSignal(msg['payload']);
            } else if (msg['type'] == 'call_accepted') {
              _logger.i('✅ Chamada aceita pelo operador');
            } else if (msg['type'] == 'call_rejected') {
              _logger.w('❌ Chamada rejeitada: ${msg['reason']}');
              _status = CallStatus.error;
              _errorMessage = msg['reason'] ?? 'Chamada rejeitada';
              notifyListeners();
            } else if (msg['type'] == 'pong') {
              _logger.d('📶 Pong received');
            }
          } catch (e) {
            _logger.w('⚠️ Erro ao processar mensagem WebSocket: $e');
          }
        }
      });

      _logger.i('🎥 ✅ Cliente registrado como mobile_patient');
      _logger.i('🎥 ✅ Oferta enviada no formato padrão WebRTC');
      _logger.i('🎥 ✅ Notificação enviada para operadores web');
      _logger.i('🎥 ✅ Canal de vídeo SEPARADO do canal de áudio');
    } catch (e) {
      _logger.e('❌ Erro ao iniciar vídeo: $e');
      _status = CallStatus.error;
      _errorMessage = "Erro ao iniciar: $e";
      notifyListeners();
    }
  }

  Future<void> _handleWebRTCSignal(Map<String, dynamic> payload) async {
    try {
      if (payload['type'] == 'answer') {
        _logger.i('✅ Answer recebido via WebSocket!');
        // ✅ FIX: Extrair SDP string do objeto RTCSessionDescription
        // Frontend envia: { type: 'answer', sdp: { type: 'answer', sdp: 'v=0...' } }
        final sdpData = payload['sdp'];
        String sdpString;
        if (sdpData is String) {
          sdpString = sdpData;
        } else if (sdpData is Map && sdpData['sdp'] != null) {
          sdpString = sdpData['sdp'];
        } else {
          throw Exception('Formato SDP inválido: $sdpData');
        }
        await _webrtcService.setRemoteAnswer(sdpString);
        // Status será atualizado via onConnectionStateChange do WebRTC
        _logger.i('✅ Remote Answer configurado!');
      } else if (payload['type'] == 'candidate') {
        _logger.i('📡 ICE Candidate recebido via WebSocket');
        await _webrtcService.addCandidate(payload['candidate']);
      }
    } catch (e) {
      _logger.e('❌ Erro ao processar sinal WebRTC: $e');
    }
  }

  // ❌ REMOVED: _startVideoPolling, _videoPollingTimer, _answerReceived, _lastCandidateId

  void _startTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_callStartTime != null) {
        _callDuration = DateTime.now().difference(_callStartTime!);
        notifyListeners();
      }
    });
  }

  void toggleMute() {
    // ✅ NOTA: Mute/unmute no WebView requer JavaScript personalizado
    // Por enquanto, apenas atualiza o estado visual
    _isMuted = !_isMuted;
    _logger.i(_isMuted ? '🔇 Mudo ativado' : '🔊 Mudo desativado');
    notifyListeners();
  }

  void toggleSpeaker() {
    _isSpeakerOn = !_isSpeakerOn;
    _logger.i(_isSpeakerOn ? '🔢 Alto-falante ativado' : '🎧 Fone ativado');
    notifyListeners();
  }

  /// Finaliza chamada (voz ou vídeo)
  Future<void> endCall() async {
    _logger.i('🛑 ========================================');
    _logger.i('🛑 FINALIZANDO CHAMADA');
    _logger.i('🛑 ========================================');

    _durationTimer?.cancel();
    await _stopRingtone();

    // ✅ Parar Native Audio
    if (_nativeAudio.isInitialized) {
      await _nativeAudio.stop();
    }

    // ✅ Parar WebRTC (se estava em videochamada)
    _webrtcService.dispose();

    // ✅ Retomar Sentinela
    _logger.i('🛡️ Retomando Sentinela...');
    await IronSentinelService.resume();

    // ✅ Desconectar WebSocket de Áudio
    _wsSubscription?.cancel();
    _wsService.disconnect();

    // ✅ Desconectar WebSocket de Vídeo
    _wsVideoSubscription?.cancel();
    _wsVideoService.disconnect();

    // Salvar log
    if (_currentSessionId != null && _callStartTime != null) {
      await _apiService.saveCallLog(
        sessionId: _currentSessionId!,
        idosoId: _currentUserData?['id'] ?? 0,
        startTime: _callStartTime!,
        endTime: DateTime.now(),
        duration: _callDuration,
        wasSuccessful: _errorMessage == null,
      );
    }

    _status = CallStatus.ended;
    notifyListeners();

    Future.delayed(const Duration(seconds: 2), () {
      _resetState();

      // ✅ Minimizar App após encerramento (Solicitação do usuário)
      try {
        _logger.i('📉 Minimizando app...');
        _platformChannel.invokeMethod('minimizeApp');
      } catch (e) {
        _logger.w('⚠️ Erro ao minimizar app: $e');
      }
    });
  }

  void _resetState() {
    _status = CallStatus.idle;
    _currentSessionId = null;
    _currentUserData = null;
    _callDuration = Duration.zero;
    _callStartTime = null;
    _totalPacketsReceived = 0;
    _lastPacketTime = null;
    // _cachedWebView = null; // ✅ Limpar cache do WebView
    notifyListeners();
  }

  // ==========================================
  // 🎵 CONTROLE DE RINGTONE
  // ==========================================
  Future<void> _playRingtone() async {
    try {
      _ringtonePlayer ??= AudioPlayer();
      // Configurar loop
      await _ringtonePlayer!.setReleaseMode(ReleaseMode.loop);

      // Tocar
      await _ringtonePlayer!.play(AssetSource('sounds/notifica.mp3'));

      _logger.i('🔔 Tocando ringtone (Loop)...');
    } catch (e) {
      _logger.w('⚠️ Erro ao tocar ringtone: $e');
    }
  }

  Future<void> _stopRingtone() async {
    try {
      if (_ringtonePlayer != null) {
        await _ringtonePlayer!.stop();
        // Não precisa dar dispose aqui se formos reutilizar,
        // mas para garantir limpeza total:
        await _ringtonePlayer!.dispose();
        _ringtonePlayer = null;
        _logger.i('🔕 Ringtone parado');
      }
    } catch (e) {
      _logger.e('❌ Erro ao parar ringtone: $e');
    }
  }

  /// 🧪 Teste de Diagnóstico (DEPRECATED - Native Mode)
  Future<void> testWebViewScripts() async {
    // ✅ DEPRECATED: JS Tests no longer relevant for Native Mode
    updateDebugStatus("JS Test: Disabled (Native Mode)");
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _stopRingtone();
    _nativeAudio.dispose();
    super.dispose();
  }
}
