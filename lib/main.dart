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
import 'core/sentinela/iron_sentinel_service.dart';

// Providers
import 'providers/call_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/accessibility_provider.dart';

// Screens
import 'presentation/screens/setup_screen.dart';
import 'presentation/screens/home/home_screen.dart';
import 'presentation/screens/profile/profile_screen.dart';
import 'presentation/screens/call/call_screen.dart';
import 'presentation/screens/call/video_screen.dart';
import 'presentation/screens/complete_diagnostic_screen.dart';
import 'presentation/screens/schedule/schedule_screen.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/splash/splash_screen.dart';
import 'presentation/screens/settings/accessibility_settings_screen.dart';
import 'iron/ui/inspection_preview.dart';
import 'presentation/widgets/equipment_alert_overlay.dart';

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
      description: 'Canal para alertas urgentes do IronMind.',
      importance: Importance.max,
    );

    // Canal 2: IRON SENTINEL (FOREGROUND SERVICE)
    const AndroidNotificationChannel sentinelaChannel =
        AndroidNotificationChannel(
      'iron_sentinel_channel', // id
      'IronMind Sentinel', // title
      description: 'Monitoramento de equipamento em tempo real.',
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

    // Configurar callback de chamada recebida
    FirebaseService.onVoiceCallReceived = (sessionId, userData) {
      final logger = Logger();
      logger.i('[IronMind] Call received! Session: $sessionId');
      callProvider.receiveCall(sessionId, userData: userData);
    };

    // 👂 INICIAR LISTENERS AGORA (Seguro, pois o callback está registrado)
    logger.i('👂 Starting Firebase Listeners...');
    FirebaseService.startListening();

    // ✅ INICIAR LISTENERS DO CALLKIT (Atender/Recusar)
    logger.i('📞 Starting CallKit Listeners...');
    CallKitService.listenEvents();

    // Inicializar IronSentinel (monitoramento de equipamento em background)
    logger.i('[IronMind] Initializing IronSentinel...');
    await IronSentinelService.initialize();
    await Future.delayed(const Duration(seconds: 1));
    logger.i('[IronMind] IronSentinel configured (manual start via inspection)');

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
    String initialRoute = '/login';
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
          return PopScope(
            canPop: false,
            onPopInvoked: (bool didPop) async {
              if (!didPop) {
                SystemNavigator.pop();
              }
            },
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(accessibility.effectiveTextScale),
                boldText: accessibility.isBoldText,
              ),
              child: MaterialApp.router(
                title: 'IronMind - Inspeção Industrial',
                theme: accessibility.getTheme(context),
                darkTheme: accessibility.getDarkTheme(context),
                themeMode: ThemeMode.dark,
                routerConfig: _router,
                debugShowCheckedModeBanner: false,
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
          path: '/accessibility',
          name: 'accessibility',
          builder: (context, state) => const AccessibilitySettingsScreen(),
        ),
        GoRoute(
          path: '/inspection',
          name: 'inspection',
          builder: (context, state) => const InspectionPreviewScreen(
            machineType: 'equipamento',
          ),
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
