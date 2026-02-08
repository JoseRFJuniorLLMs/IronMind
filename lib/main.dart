import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logger/logger.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // ✅ NOVO
import 'firebase_options.dart';

// Services
import 'data/services/firebase_service.dart';
import 'data/services/callkit_service.dart';
import 'data/services/storage_service.dart';
import 'core/sentinela/sentinela_service.dart';
// import 'data/workers/health_sync_worker.dart'; // ✅ TEMPORARIAMENTE COMENTADO - depende de workmanager

// Providers
import 'providers/call_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/accessibility_provider.dart';

// Screens
import 'presentation/screens/permissions_screen.dart';
import 'presentation/screens/setup_screen.dart';
import 'presentation/screens/home/home_screen.dart';
import 'presentation/screens/profile/profile_screen.dart';
import 'presentation/screens/call/call_screen.dart';
import 'presentation/screens/call/video_screen.dart'; // ✅ Video Screen Import
import 'presentation/screens/complete_diagnostic_screen.dart';
import 'presentation/screens/schedule/schedule_screen.dart'; // ✅ Agendamento Import
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/splash/splash_screen.dart';
import 'presentation/screens/medicamentos/medicamentos_screen.dart';
import 'presentation/screens/contatos/contatos_emergencia_screen.dart';
import 'screens/medication_scanner_screen.dart';
import 'presentation/screens/settings/accessibility_settings_screen.dart';
import 'presentation/widgets/sentinela_alert_overlay.dart';

// 🔑 CHAVE GLOBAL PARA NAVEGAÇÃO
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Inicializar Localização (pt_BR) para calendário
  await initializeDateFormatting('pt_BR', null);

  final logger = Logger();

  try {
    // 1. Carregar variáveis de ambiente
    logger.i('📂 Loading environment variables...');
    await dotenv.load(fileName: ".env");
    logger.i('✅ Environment loaded');

    // 2. Inicializar Storage Local
    logger.i('💾 Initializing local storage...');
    await StorageService.init();
    logger.i('✅ Storage initialized');

    // 3. Inicializar Firebase
    logger.i('🔥 Initializing Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    logger.i('✅ Firebase initialized');

    // 4. Inicializar Firebase Messaging
    logger.i('📱 Initializing Firebase Messaging...');
    await FirebaseService.initialize();

    // 🔥 CRIAR CANAIS DE NOTIFICAÇÃO ANDROID (CRÍTICO PARA EXIBIR PUSH E FOREGROUND SERVICE)
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    // Canal 1: PUSH NOTIFICATIONS
    const AndroidNotificationChannel highChannel = AndroidNotificationChannel(
      'high_importance_channel', // id
      'Notificações Importantes', // title
      description: 'Canal para alertas urgentes da EVA.',
      importance: Importance.max,
    );

    // Canal 2: SENTINELA (FOREGROUND SERVICE)
    const AndroidNotificationChannel sentinelaChannel =
        AndroidNotificationChannel(
      'sentinela_channel', // id
      'Sentinela EVA', // title
      description: 'Monitoramento de segurança em tempo real.',
      importance: Importance
          .low, // Prioridade baixa para não incomodar mas manter ativo
    );

    final androidImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(highChannel);
      await androidImplementation.createNotificationChannel(sentinelaChannel);
    }

    // 🟢 INICIALIZAR PLUGIN PARA TRATAR CLIQUES
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        logger.i('🔔 Notification clicked: ${response.payload}');
      },
    );

    logger.i('✅ Notification Channels (High & Sentinela) initialized');

    // 🛑 SOLICITAR PERMISSÃO EM TEMPO DE EXECUÇÃO (RUNTIME)
    // Necessário para Android 13+
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // Debug: Mostrar dados salvos
    StorageService.debugPrintData();

    // ✅ Mudança 2: Criar e inicializar CallProvider de forma assíncrona
    logger.i('🎬 Criando CallProvider...');
    final callProvider = await CallProvider.create();
    logger.i('✅ CallProvider criado e inicializado');

    // ✅ Configurar callback APÓS inicialização
    FirebaseService.onVoiceCallReceived = (sessionId, idosoData) {
      final logger = Logger();
      logger.i('🎯 BACKEND triggered call! Session: $sessionId');
      logger.i('📞 Updating CallProvider state to RINGING...');
      callProvider.receiveCall(sessionId, idosoData: idosoData);
      logger.i('✅ CallProvider updated. User must click ANSWER button.');
    };

    // 👂 INICIAR LISTENERS AGORA (Seguro, pois o callback está registrado)
    logger.i('👂 Starting Firebase Listeners...');
    FirebaseService.startListening();

    // ✅ INICIAR LISTENERS DO CALLKIT (Atender/Recusar)
    logger.i('📞 Starting CallKit Listeners...');
    CallKitService.listenEvents();

    // ✅ INICIAR SENTINELA (Always-On Fall Detection)
    logger.i('🛡️ Initializing Sentinela...');
    await SentinelaService.initialize();

    // Aguardar um pouco para garantir que os canais estão prontos antes do start
    await Future.delayed(const Duration(seconds: 1));
    await SentinelaService.start();
    logger.i('✅ Sentinela ACTIVE - Fall detection monitoring started');

    // ✅ TEMPORARIAMENTE DESABILITADO - INICIAR HEALTH SYNC WORKER (Sincronização periódica a cada 6h)
    // logger.i('⏰ Initializing HealthSyncWorker...');
    // await HealthSyncWorker.initialize();
    // logger.i('✅ HealthSyncWorker ACTIVE - Periodic sync every 6 hours');

    runApp(MyApp(callProvider: callProvider));
  } catch (e, stackTrace) {
    logger.e('❌ Error during initialization: $e');
    logger.e('Stack trace: $stackTrace');
    // Criar CallProvider de fallback em caso de erro
    final fallbackProvider = CallProvider.fallback();
    runApp(MyApp(callProvider: fallbackProvider));
  }
}

class MyApp extends StatefulWidget {
  final CallProvider callProvider;

  const MyApp({super.key, required this.callProvider});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    // ✅ FIX: Criar router UMA VEZ no initState para evitar recriação no build
    String initialRoute = '/permissions';
    if (StorageService.isLoggedIn()) {
      initialRoute = '/home';
    }
    _router = _createRouter(initialRoute);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Auth Provider
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        // Notification Provider
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        // Accessibility Provider
        ChangeNotifierProvider(create: (_) => AccessibilityProvider()..loadPreferences()),
        // ✅ Mudança 2: Usar .value para provider já criado
        ChangeNotifierProvider.value(value: widget.callProvider),
      ],
      child: Consumer<AccessibilityProvider>(
        builder: (context, accessibility, child) {
          return SentinelaAlertOverlay(
            child: PopScope(
              canPop: false,
              onPopInvoked: (bool didPop) async {
                if (!didPop) {
                  // Minimiza o app em vez de fechar
                  SystemNavigator.pop();
                }
              },
              child: MediaQuery(
              // Aplica escala de texto do provider
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(accessibility.effectiveTextScale),
                boldText: accessibility.isBoldText,
              ),
              child: MaterialApp.router(
                title: 'EVA - Assistente para Idosos',
                // Tema dinamico baseado nas configuracoes de acessibilidade
                theme: accessibility.getTheme(context),
                darkTheme: accessibility.getDarkTheme(context),
                themeMode: ThemeMode.light, // EVA usa tema claro com gradiente
                routerConfig: _router,
                debugShowCheckedModeBanner: false,
                // ✅ Tradução para Calendário (Fix White Screen)
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                supportedLocales: const [
                  Locale('pt', 'BR'),
                ],
              ),
            ),
          ),
          );
        },
      ),
    );
  }

  GoRouter _createRouter(String initialRoute) {
    return GoRouter(
      navigatorKey: navigatorKey, // ✅ CHAVE GLOBAL ADICIONADA
      initialLocation: initialRoute,
      routes: [
        GoRoute(
          path: '/permissions',
          name: 'permissions',
          builder: (context, state) => const PermissionsScreen(),
        ),
        GoRoute(
          path: '/setup',
          name: 'setup',
          builder: (context, state) => const SetupScreen(),
        ),
        GoRoute(
          path: '/home',
          name: 'home',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/profile',
          name: 'profile',
          builder: (context, state) => const ProfileScreen(),
        ),
        GoRoute(
          path: '/call',
          name: 'call',
          builder: (context, state) => const CallScreen(),
        ),
        GoRoute(
          path: '/diagnostic',
          name: 'diagnostic',
          builder: (context, state) => const CompleteDiagnosticScreen(),
        ),
        GoRoute(
          path: '/video',
          name: 'video',
          builder: (context, state) => const VideoScreen(),
        ),
        GoRoute(
          path: '/schedule',
          name: 'schedule',
          builder: (context, state) => const ScheduleScreen(),
        ),
        GoRoute(
          path: '/login',
          name: 'login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/splash',
          name: 'splash',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: '/medicamentos',
          name: 'medicamentos',
          builder: (context, state) => const MedicamentosScreen(),
        ),
        GoRoute(
          path: '/contatos-emergencia',
          name: 'contatos-emergencia',
          builder: (context, state) => const ContatosEmergenciaScreen(),
        ),
        GoRoute(
          path: '/medication-scanner',
          name: 'medication-scanner',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            return MedicationScannerScreen(
              sessionId: extra?['sessionId'] ?? 'manual-scan-${DateTime.now().millisecondsSinceEpoch}',
              candidateMedications: extra?['candidateMedications'] ?? [],
              instructions: extra?['instructions'] ?? 'Aponte a camera para o medicamento',
            );
          },
        ),
        GoRoute(
          path: '/accessibility',
          name: 'accessibility',
          builder: (context, state) => const AccessibilitySettingsScreen(),
        ),
      ],
      errorBuilder: (context, state) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 80, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Rota não encontrada: ${state.matchedLocation}',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/home'),
                child: const Text('Voltar para Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
