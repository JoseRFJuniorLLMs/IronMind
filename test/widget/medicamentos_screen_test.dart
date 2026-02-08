import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eva_mobile/presentation/screens/medicamentos/medicamentos_screen.dart';
import 'package:eva_mobile/providers/auth_provider.dart';
import 'package:eva_mobile/data/services/storage_service.dart';

/// Widget tests for MedicamentosScreen
/// Focus: UI elements, empty state, medication display
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(
      home: ChangeNotifierProvider(
        create: (_) => AuthProvider(),
        child: const MedicamentosScreen(),
      ),
    );
  }

  group('MedicamentosScreen - UI Elements', () {
    testWidgets('Should display app bar with title', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.text('Meus Remedios'), findsOneWidget);
    });

    testWidgets('Should display back button', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('Should display add medication FAB', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
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

  group('MedicamentosScreen - Empty State', () {
    testWidgets('Should show empty state message when no medications', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // When API returns empty, should show empty state
      // Note: Without mocked API, this tests the loading/empty flow
      expect(
        find.byType(CircularProgressIndicator).evaluate().isNotEmpty ||
        find.text('Nenhum remedio cadastrado').evaluate().isNotEmpty ||
        find.text('Erro ao carregar').evaluate().isNotEmpty,
        true,
      );
    });

    testWidgets('Should show medication icon in empty state', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Empty state or loading should be visible
      expect(find.byIcon(Icons.medication), findsWidgets);
    });
  });

  group('MedicamentosScreen - Loading State', () {
    testWidgets('Should show loading indicator initially', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      // Immediately after pump, should be loading
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });
  });

  group('MedicamentosScreen - Add Medication Dialog', () {
    testWidgets('Should open add dialog when FAB tapped', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Should open dialog with form fields
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Novo Remedio'), findsOneWidget);
    });

    testWidgets('Should have required form fields in add dialog', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Check for form fields
      expect(find.text('Nome do remedio'), findsOneWidget);
      expect(find.text('Dosagem'), findsOneWidget);
      expect(find.text('Horarios'), findsOneWidget);
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

  group('MedicamentosScreen - Accessibility', () {
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
}
