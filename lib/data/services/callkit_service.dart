import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:go_router/go_router.dart';
import '../../main.dart';
import '../../providers/call_provider.dart';
import 'package:provider/provider.dart';

class CallKitService {
  static final Logger _logger = Logger();

  static Future<void> initialize() async {
    // Check permissions
    // await FlutterCallkitIncoming.requestNotificationPermission({
    //   "rationaleMessagePermission": "Notification permission is required, to show notification.",
    //   "postNotificationPermission": "Notification permission is required, to show notification."
    // });
  }

  // ✅ Verificar chamadas ativas
  static Future<dynamic> activeCalls() async {
    return await FlutterCallkitIncoming.activeCalls();
  }

  static Future<void> showIncomingCall({
    required String uuid,
    required String name,
    required String avatar,
    required String handle, // e.g. Phone number or ID
  }) async {
    final params = CallKitParams(
      id: uuid,
      nameCaller: name,
      appName: 'EVA',
      avatar: 'assets/images/eva_transparent.png', // ✅ Imagem Local da EVA
      handle: handle,
      type: 0,
      duration: 30000,
      textAccept: 'Atender',
      textDecline: '',
      missedCallNotification: const NotificationParams(
        id: 1,
        showNotification: true,
        isShowCallback: true,
        subtitle: 'Chamada perdida',
        callbackText: 'Retornar',
      ),
      extra: <String, dynamic>{'userId': handle},
      headers: <String, dynamic>{'apiKey': 'Abc@123!', 'platform': 'flutter'},
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        ringtonePath: 'notifica', // ✅ Som personalizado 'notifica'
        backgroundColor: '#4A148C', // Deep Purple (Brand)
        backgroundUrl: 'assets/images/eva_transparent.png', // ✅ Fundo EVA
        actionColor: '#EC4899', // Pink (Brand) - Substitui o Verde
        isShowFullLockedScreen: true, // ✅ Maximizar na tela de bloqueio
        // 🔴 P1 FIX: Force app to launch from background
        incomingCallNotificationChannelName: 'Incoming Call',
        isShowCallID: true,
      ),
      ios: const IOSParams(
        iconName: 'CallKitIcon',
        handleType: '',
        supportsVideo: true,
        maximumCallGroups: 2,
        maximumCallsPerCallGroup: 1,
        audioSessionMode: 'default',
        audioSessionActive: true,
        audioSessionPreferredSampleRate: 44100.0,
        audioSessionPreferredIOBufferDuration: 0.005,
        supportsDTMF: true,
        supportsHolding: true,
        supportsGrouping: false,
        supportsUngrouping: false,
        ringtonePath:
            'notifica.mp3', // ✅ Som personalizado (iOS requer extensão)
      ),
    );

    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }

  static void listenEvents() {
    FlutterCallkitIncoming.onEvent.listen((event) async {
      _logger.d('CallKit Event: ${event?.event}');
      switch (event!.event) {
        case Event.actionCallIncoming:
          // TODO: received an incoming call
          break;
        case Event.actionCallStart:
          // TODO: started an outgoing call
          // shows the call duration and set the initialization time
          break;
        case Event.actionCallAccept:
          // TODO: accepted an incoming call
          // Navigation to call screen
          _handleAcceptCall();
          break;
        case Event.actionCallDecline:
          // TODO: declined an incoming call
          await FlutterCallkitIncoming.endAllCalls();
          _handleDeclineCall();
          break;
        case Event.actionCallEnded:
          // TODO: ended an incoming/outgoing call
          break;
        case Event.actionCallTimeout:
          // TODO: missed an incoming call
          _handleDeclineCall(); // Treat as decline
          break;
        case Event.actionCallCallback:
          // TODO: only Android - click action `Call back` from missed call notification
          break;
        case Event.actionCallToggleHold:
          // TODO: only iOS
          break;
        case Event.actionCallToggleMute:
          // TODO: only iOS
          break;
        case Event.actionCallToggleDmtf:
          // TODO: only iOS
          break;
        case Event.actionCallToggleGroup:
          // TODO: only iOS
          break;
        case Event.actionCallToggleAudioSession:
          // TODO: only iOS
          break;
        case Event.actionDidUpdateDevicePushTokenVoip:
          // TODO: only iOS
          break;
        case Event.actionCallCustom:
          // TODO: for custom action
          break;
        case Event.actionCallConnected:
          // ✅ Missing case handling
          break;
      }
    });
  }

  static void _handleAcceptCall() {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    // Notify provider
    final provider = Provider.of<CallProvider>(context, listen: false);

    // We assume the call provider already has the session info from the push notification data
    // Or we might need to pass it back if CallKit supports storing it in 'extra'

    // Navigate to call screen
    context.push('/call');

    // Trigger accept logic
    provider.acceptCall();
  }

  static void _handleDeclineCall() {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    final provider = Provider.of<CallProvider>(context, listen: false);
    provider.endCall();
  }
}
