import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eva_mobile/presentation/screens/profile/profile_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:eva_mobile/providers/auth_provider.dart';


void main() {
  testWidgets('ProfileScreen has a logout button and user info', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/profile',
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
      ),
    ));

    // Verify that our screen has a title.
    expect(find.text('Meu Perfil'), findsOneWidget);

    // Verify that there is a logout button.
    expect(find.byIcon(Icons.logout), findsOneWidget);
  });
}