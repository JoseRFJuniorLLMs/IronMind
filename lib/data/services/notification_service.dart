import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../models/medicamento.dart';

/// Servico de notificacoes locais para lembretes de medicacao
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final Logger _logger = Logger();
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Callback quando usuario clica na notificacao
  Function(String? payload)? onNotificationTap;

  /// Inicializa o servico de notificacoes
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Inicializa timezone
      tz_data.initializeTimeZones();

      // Configuracoes Android
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

      // Configuracoes iOS
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        settings,
        onDidReceiveNotificationResponse: (response) {
          _logger.i('Notificacao clicada: ${response.payload}');
          onNotificationTap?.call(response.payload);
        },
      );

      // Solicitar permissao no Android 13+
      if (Platform.isAndroid) {
        await _notifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      }

      _isInitialized = true;
      _logger.i('NotificationService inicializado');
    } catch (e) {
      _logger.e('Erro ao inicializar NotificationService: $e');
    }
  }

  /// Agenda lembrete de medicamento
  Future<void> agendarLembreteMedicamento(Medicamento med) async {
    if (!_isInitialized) await initialize();

    // Cancela lembretes anteriores deste medicamento
    await cancelarLembretesMedicamento(med.id);

    // Agenda para cada horario
    for (int i = 0; i < med.horarios.length; i++) {
      final horario = med.horarios[i];
      final parts = horario.split(':');
      if (parts.length != 2) continue;

      final hora = int.tryParse(parts[0]) ?? 0;
      final minuto = int.tryParse(parts[1]) ?? 0;

      // ID unico: medicamento_id * 100 + indice do horario
      final notificationId = med.id * 100 + i;

      await _agendarNotificacaoDiaria(
        id: notificationId,
        titulo: 'Hora do Medicamento',
        corpo: '${med.nome} - ${med.dosagem} ${med.unidade}',
        hora: hora,
        minuto: minuto,
        payload: 'medicamento:${med.id}',
      );

      _logger.i('Lembrete agendado: ${med.nome} as $horario (ID: $notificationId)');
    }
  }

  /// Agenda notificacao diaria recorrente
  Future<void> _agendarNotificacaoDiaria({
    required int id,
    required String titulo,
    required String corpo,
    required int hora,
    required int minuto,
    String? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'medicamentos_channel',
      'Lembretes de Medicamentos',
      channelDescription: 'Notificacoes para lembrar de tomar medicamentos',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: BigTextStyleInformation(corpo),
      category: AndroidNotificationCategory.reminder,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Calcula o proximo horario
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hora,
      minuto,
    );

    // Se o horario ja passou hoje, agenda para amanha
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _notifications.zonedSchedule(
      id,
      titulo,
      corpo,
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // Repete diariamente
      payload: payload,
    );
  }

  /// Cancela lembretes de um medicamento
  Future<void> cancelarLembretesMedicamento(int medicamentoId) async {
    // Cancela ate 10 horarios possiveis por medicamento
    for (int i = 0; i < 10; i++) {
      await _notifications.cancel(medicamentoId * 100 + i);
    }
    _logger.i('Lembretes cancelados para medicamento $medicamentoId');
  }

  /// Mostra notificacao imediata
  Future<void> mostrarNotificacao({
    required int id,
    required String titulo,
    required String corpo,
    String? payload,
  }) async {
    if (!_isInitialized) await initialize();

    final androidDetails = AndroidNotificationDetails(
      'geral_channel',
      'Notificacoes Gerais',
      channelDescription: 'Notificacoes gerais do aplicativo',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(id, titulo, corpo, details, payload: payload);
  }

  /// Mostra notificacao de alerta urgente
  Future<void> mostrarAlertaUrgente({
    required String titulo,
    required String corpo,
    String? payload,
  }) async {
    if (!_isInitialized) await initialize();

    final androidDetails = AndroidNotificationDetails(
      'alertas_channel',
      'Alertas Urgentes',
      channelDescription: 'Alertas de emergencia',
      importance: Importance.max,
      priority: Priority.max,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 200, 500, 200, 500]),
      playSound: true,
      icon: '@mipmap/ic_launcher',
      fullScreenIntent: true, // Mostra em tela cheia
      category: AndroidNotificationCategory.alarm,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.critical,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000, // ID unico
      titulo,
      corpo,
      details,
      payload: payload,
    );
  }

  /// Lista notificacoes pendentes
  Future<List<PendingNotificationRequest>> getNotificacoesPendentes() async {
    return await _notifications.pendingNotificationRequests();
  }

  /// Cancela todas as notificacoes
  Future<void> cancelarTodas() async {
    await _notifications.cancelAll();
    _logger.i('Todas as notificacoes canceladas');
  }

  /// Cancela uma notificacao especifica
  Future<void> cancelar(int id) async {
    await _notifications.cancel(id);
  }
}
