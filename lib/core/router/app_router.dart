import 'package:go_router/go_router.dart';
import '../../presentation/screens/home/home_screen.dart';
import '../../presentation/screens/profile/profile_screen.dart';
import '../../presentation/screens/call/call_screen.dart';
import '../../presentation/screens/splash/splash_screen.dart';
import '../../presentation/screens/video/video_call_screen.dart';
import '../../presentation/screens/schedule/schedule_screen.dart';
import '../../presentation/screens/medicamentos/medicamentos_screen.dart';
import '../../presentation/screens/contatos/contatos_emergencia_screen.dart';
import '../../presentation/screens/settings/accessibility_settings_screen.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../screens/medication_scanner_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(path: '/call', builder: (context, state) => const CallScreen()),
    GoRoute(
      path: '/video',
      builder: (context, state) => const VideoCallScreen(),
    ),
    GoRoute(
      path: '/schedule',
      builder: (context, state) => const ScheduleScreen(),
    ),
    GoRoute(
      path: '/medicamentos',
      builder: (context, state) => const MedicamentosScreen(),
    ),
    GoRoute(
      path: '/contatos-emergencia',
      builder: (context, state) => const ContatosEmergenciaScreen(),
    ),
    GoRoute(
      path: '/medication-scanner',
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
      builder: (context, state) => const AccessibilitySettingsScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
  ],
);
