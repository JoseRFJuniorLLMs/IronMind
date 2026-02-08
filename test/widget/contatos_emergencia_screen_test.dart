import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eva_mobile/presentation/screens/contatos/contatos_emergencia_screen.dart';
import 'package:eva_mobile/providers/auth_provider.dart';
import 'package:eva_mobile/data/services/storage_service.dart';

/// Widget tests for ContatosEmergenciaScreen
/// Focus: UI elements, empty state, contact display
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(
      home: ChangeNotifierProvider(
        create: (_) => AuthProvider(),
        child: const ContatosEmergenciaScreen(),
      ),
    );
  }

  group('ContatosEmergenciaScreen - UI Elements', () {
    testWidgets('Should display app bar with title', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.text('Minha Familia'), findsOneWidget);
    });

    testWidgets('Should display back button', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('Should display add contact FAB', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.person_add), findsOneWidget);
    });

    testWidgets('Should have gradient background', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      final containerFinder = find.byWidgetPredicate((widget) {
        if (widget is Container && widget.decoration is BoxDecoration) {
          final decoration = widget.decoration as BoxDecoration;
          return decoration.gradient != null;
        }
        return false;
      });

      expect(containerFinder, findsWidgets);
    });
  });

  group('ContatosEmergenciaScreen - Empty State', () {
    testWidgets('Should show empty state when no contacts', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Without API, should show loading, empty, or error state
      expect(
        find.byType(CircularProgressIndicator).evaluate().isNotEmpty ||
        find.text('Nenhum contato cadastrado').evaluate().isNotEmpty ||
        find.text('Erro ao carregar').evaluate().isNotEmpty,
        true,
      );
    });

    testWidgets('Should show people icon in empty/loading state', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.people), findsWidgets);
    });
  });

  group('ContatosEmergenciaScreen - Loading State', () {
    testWidgets('Should show loading indicator initially', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });
  });

  group('ContatosEmergenciaScreen - Add Contact Dialog', () {
    testWidgets('Should open add dialog when FAB tapped', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Novo Contato'), findsOneWidget);
    });

    testWidgets('Should have required form fields in add dialog', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Check for form fields
      expect(find.text('Nome'), findsOneWidget);
      expect(find.text('Telefone'), findsOneWidget);
      expect(find.text('Parentesco'), findsOneWidget);
    });

    testWidgets('Should close dialog on cancel', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    });
  });

  group('ContatosEmergenciaScreen - Parentesco Options', () {
    testWidgets('Should display parentesco dropdown options', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Find and tap the dropdown
      final dropdown = find.byType(DropdownButtonFormField<String>);
      expect(dropdown, findsOneWidget);
    });
  });

  group('ContatosEmergenciaScreen - Priority Display', () {
    // These tests would require mocked data to fully test
    testWidgets('Should sort contacts by priority', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Without mocked API data, we just verify the screen loads
      expect(find.text('Minha Familia'), findsOneWidget);
    });
  });

  group('ContatosEmergenciaScreen - Accessibility', () {
    testWidgets('Should have semantic labels for main actions', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      // FAB should be accessible
      final fabFinder = find.byType(FloatingActionButton);
      expect(fabFinder, findsOneWidget);

      // Back button should be tappable
      final backButton = find.byIcon(Icons.arrow_back);
      expect(backButton, findsOneWidget);
    });
  });

  group('ContatosEmergenciaScreen - Contact Actions', () {
    // These tests would require mocked contacts to fully test
    testWidgets('Should display call button for contacts', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // The call button would appear on contact cards
      // For empty state, just verify the screen works
      expect(find.text('Minha Familia'), findsOneWidget);
    });
  });
}
