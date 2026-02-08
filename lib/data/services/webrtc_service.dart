import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:logger/logger.dart';

/// Estados da conexão WebRTC
enum WebRTCConnectionState {
  disconnected,
  connecting,
  connected,
  failed,
  closed,
}

class WebRTCService {
  final Logger _logger = Logger();
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  WebRTCConnectionState _connectionState = WebRTCConnectionState.disconnected;

  // Callbacks
  Function(MediaStream stream)? onRemoteStream;
  Function(RTCIceCandidate candidate)? onIceCandidate;
  Function(MediaStream stream)? onLocalStream;
  Function(WebRTCConnectionState state)? onConnectionStateChange;
  Function(String error)? onError;

  bool get isConnected => _connectionState == WebRTCConnectionState.connected;
  WebRTCConnectionState get connectionState => _connectionState;

  Future<void> initialize() async {
    _logger.i('🌐 Initializing WebRTC...');

    // 1. Get Local Media
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': {
        'facingMode': 'user', // Front camera
      },
    };

    try {
      _localStream = await navigator.mediaDevices.getUserMedia(
        mediaConstraints,
      );
      _logger.i('✅ Local Stream acquired');
      if (onLocalStream != null) onLocalStream!(_localStream!);
    } catch (e) {
      _logger.e('❌ Error getting user media: $e');
      rethrow;
    }
  }

  Future<String> createOffer() async {
    if (_localStream == null) await initialize();

    _updateConnectionState(WebRTCConnectionState.connecting);

    // 2. Create Peer Connection com STUN + TURN servers
    // TURN servers garantem conexão mesmo atrás de NAT simétrico
    final Map<String, dynamic> configuration = {
      'iceServers': [
        // STUN servers (gratuitos, para descoberta de IP público)
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
        {'urls': 'stun:stun2.l.google.com:19302'},
        {'urls': 'stun:stun3.l.google.com:19302'},
        {'urls': 'stun:stun4.l.google.com:19302'},
        // TURN servers (relay para NAT simétrico)
        // Usando servidores públicos do projeto OpenRelay
        {
          'urls': 'turn:openrelay.metered.ca:80',
          'username': 'openrelayproject',
          'credential': 'openrelayproject',
        },
        {
          'urls': 'turn:openrelay.metered.ca:443',
          'username': 'openrelayproject',
          'credential': 'openrelayproject',
        },
        {
          'urls': 'turn:openrelay.metered.ca:443?transport=tcp',
          'username': 'openrelayproject',
          'credential': 'openrelayproject',
        },
      ],
      'iceCandidatePoolSize': 10,
    };

    _peerConnection = await createPeerConnection(configuration);

    // Add Tracks
    _localStream!.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
    });

    // Handle Candidates
    _peerConnection!.onIceCandidate = (candidate) {
      if (onIceCandidate != null) onIceCandidate!(candidate);
    };

    // Handle Remote Stream
    _peerConnection!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _logger.i('📡 Remote Stream received!');
        _remoteStream = event.streams[0];
        if (onRemoteStream != null) onRemoteStream!(_remoteStream!);
      }
    };

    // ✅ Monitor Connection State
    _peerConnection!.onConnectionState = (state) {
      _logger.i('🔗 Connection State: $state');
      switch (state) {
        case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          _updateConnectionState(WebRTCConnectionState.connected);
          break;
        case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
          _updateConnectionState(WebRTCConnectionState.failed);
          if (onError != null) onError!('Conexão WebRTC falhou');
          break;
        case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
          _updateConnectionState(WebRTCConnectionState.disconnected);
          break;
        case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
          _updateConnectionState(WebRTCConnectionState.closed);
          break;
        default:
          break;
      }
    };

    // ✅ Monitor ICE Connection State (mais granular)
    _peerConnection!.onIceConnectionState = (state) {
      _logger.i('🧊 ICE Connection State: $state');
      if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        _logger.e('❌ ICE Connection Failed - Tentando restart...');
        _restartIce();
      }
    };

    // ✅ Monitor ICE Gathering State
    _peerConnection!.onIceGatheringState = (state) {
      _logger.i('🧊 ICE Gathering State: $state');
    };

    // 3. Create Offer
    RTCSessionDescription offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    _logger.i('📝 SDP Offer created');
    return offer.sdp ?? '';
  }

  void _updateConnectionState(WebRTCConnectionState state) {
    _connectionState = state;
    if (onConnectionStateChange != null) {
      onConnectionStateChange!(state);
    }
  }

  /// Tenta reiniciar ICE em caso de falha
  Future<void> _restartIce() async {
    if (_peerConnection == null) return;
    try {
      _logger.i('🔄 Reiniciando ICE...');
      await _peerConnection!.restartIce();
    } catch (e) {
      _logger.e('❌ Erro ao reiniciar ICE: $e');
    }
  }

  Future<void> setRemoteAnswer(String sdp) async {
    if (_peerConnection == null) return;

    final answer = RTCSessionDescription(sdp, 'answer');
    await _peerConnection!.setRemoteDescription(answer);
    _logger.i('✅ Remote Answer set!');
  }

  Future<void> addCandidate(Map<String, dynamic> candidateMap) async {
    if (_peerConnection == null) return;

    var candidate = RTCIceCandidate(
      candidateMap['candidate'],
      candidateMap['sdpMid'],
      candidateMap['sdpMLineIndex'],
    );
    await _peerConnection!.addCandidate(candidate);
  }

  void dispose() {
    _localStream?.dispose();
    _remoteStream?.dispose();
    _peerConnection?.close();
    _peerConnection = null;
    _localStream = null;
    _remoteStream = null;
    _updateConnectionState(WebRTCConnectionState.closed);
  }

  /// Reinicializa o serviço para nova chamada
  void reset() {
    dispose();
    _connectionState = WebRTCConnectionState.disconnected;
  }
}
