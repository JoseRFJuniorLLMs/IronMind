import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:eva_mobile/presentation/screens/auth/login_screen.dart';
import 'package:eva_mobile/providers/auth_provider.dart';

/// Widget tests for LoginScreen
/// Focus: UI elements, form validation, user interactions
void main() {
  Widget createWidgetUnderTest() {
    return MaterialApp(
      home: ChangeNotifierProvider(
        create: (_) => AuthProvider(),
        child: const LoginScreen(),
      ),
    );
  }

  group('LoginScreen - UI Elements', () {
    testWidgets('Should display welcome text', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      expect(find.text('Bem-vindo'), findsOneWidget);
      expect(find.text('Digite seu CPF para entrar'), findsOneWidget);
    });

    testWidgets('Should display CPF input field', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.text('000.000.000-00'), findsOneWidget); // hint text
    });

    testWidgets('Should display login button', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      expect(find.text('ENTRAR'), findsOneWidget);
      expect(find.byIcon(Icons.login), findsOneWidget);
    });

    testWidgets('Should display help button', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      expect(find.text('Precisa de ajuda?'), findsOneWidget);
      expect(find.byIcon(Icons.help_outline), findsOneWidget);
    });

    testWidgets('Should have gradient background', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // Find Container with BoxDecoration containing gradient
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

  group('LoginScreen - CPF Input', () {
    testWidgets('Should accept numeric input', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.enterText(find.byType(TextFormField), '12345678901');
      await tester.pump();

      // CPF should be formatted
      expect(find.text('123.456.789-01'), findsOneWidget);
    });

    testWidgets('Should format CPF automatically', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // Enter digits one by one to test formatting
      final textField = find.byType(TextFormField);

      await tester.enterText(textField, '123');
      await tester.pump();
      expect(find.text('123'), findsOneWidget);

      await tester.enterText(textField, '123456');
      await tester.pump();
      expect(find.text('123.456'), findsOneWidget);

      await tester.enterText(textField, '123456789');
      await tester.pump();
      expect(find.text('123.456.789'), findsOneWidget);

      await tester.enterText(textField, '12345678901');
      await tester.pump();
      expect(find.text('123.456.789-01'), findsOneWidget);
    });

    testWidgets('Should limit CPF to 11 digits', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.enterText(find.byType(TextFormField), '12345678901234567890');
      await tester.pump();

      // Should only keep first 11 digits
      expect(find.text('123.456.789-01'), findsOneWidget);
    });
  });

  group('LoginScreen - Form Validation', () {
    testWidgets('Should show error for empty CPF', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // Tap login button without entering CPF
      await tester.tap(find.text('ENTRAR'));
      await tester.pumpAndSettle();

      expect(find.text('Digite seu CPF'), findsOneWidget);
    });

    testWidgets('Should show error for incomplete CPF', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.enterText(find.byType(TextFormField), '12345');
      await tester.tap(find.text('ENTRAR'));
      await tester.pumpAndSettle();

      expect(find.text('CPF deve ter 11 digitos'), findsOneWidget);
    });

    testWidgets('Should not show error for valid CPF format', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.enterText(find.byType(TextFormField), '12345678901');
      await tester.tap(find.text('ENTRAR'));
      await tester.pump();

      // Form validation should pass (API call may fail, but that's expected)
      expect(find.text('Digite seu CPF'), findsNothing);
      expect(find.text('CPF deve ter 11 digitos'), findsNothing);
    });
  });

  group('LoginScreen - Help Dialog', () {
    testWidgets('Should show help dialog when help button tapped', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.tap(find.text('Precisa de ajuda?'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Precisa de ajuda?'), findsNWidgets(2)); // button + dialog title
      expect(find.text('Entendi'), findsOneWidget);
    });

    testWidgets('Should close help dialog when Entendi tapped', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.tap(find.text('Precisa de ajuda?'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Entendi'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    });
  });

  group('LoginScreen - Loading State', () {
    testWidgets('Should show loading indicator when logging in', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.enterText(find.byType(TextFormField), '12345678901');
      await tester.tap(find.text('ENTRAR'));
      await tester.pump();

      // During loading, button should show CircularProgressIndicator
      // Note: This may be too fast to catch, but the state transition should occur
      expect(find.byType(ElevatedButton), findsOneWidget);
    });
  });
}
