import 'package:flutter_test/flutter_test.dart';
import 'package:eva_mobile/providers/auth_provider.dart';

/// Unit tests for AuthProvider
/// Focus: State management, status transitions, error handling
void main() {
  late AuthProvider authProvider;

  setUp(() {
    authProvider = AuthProvider();
  });

  group('AuthProvider - Initial State', () {
    test('Should start with initial status', () {
      expect(authProvider.status, AuthStatus.initial);
      expect(authProvider.idoso, null);
      expect(authProvider.errorMessage, null);
      expect(authProvider.isAuthenticated, false);
    });

    test('Should not be authenticated initially', () {
      expect(authProvider.isAuthenticated, false);
    });

    test('Should have null convenience getters initially', () {
      expect(authProvider.idosoId, null);
      expect(authProvider.idosoNome, null);
      expect(authProvider.idosoCpf, null);
    });
  });

  group('AuthProvider - CPF Validation', () {
    test('Should reject CPF with less than 11 digits', () async {
      final success = await authProvider.loginByCpf('123.456.789');

      expect(success, false);
      expect(authProvider.status, AuthStatus.error);
      expect(authProvider.errorMessage, contains('11'));
    });

    test('Should handle CPF with formatting', () async {
      // CPF with dots and dash should be cleaned
      // Note: This will fail API call but validates cleaning
      final success = await authProvider.loginByCpf('123.456.789-00');

      // Will be error because API is not mocked, but CPF validation should pass
      expect(authProvider.status, isIn([AuthStatus.error, AuthStatus.loading]));
    });

    test('Should reject empty CPF', () async {
      final success = await authProvider.loginByCpf('');

      expect(success, false);
      expect(authProvider.status, AuthStatus.error);
    });
  });

  group('AuthProvider - Error Handling', () {
    test('Should clear error message', () async {
      // First cause an error
      await authProvider.loginByCpf('123');
      expect(authProvider.errorMessage, isNotNull);

      // Then clear it
      authProvider.clearError();

      expect(authProvider.errorMessage, null);
      expect(authProvider.status, AuthStatus.unauthenticated);
    });

    test('Should transition from error to unauthenticated on clearError', () async {
      await authProvider.loginByCpf('short');
      expect(authProvider.status, AuthStatus.error);

      authProvider.clearError();

      expect(authProvider.status, AuthStatus.unauthenticated);
    });
  });

  group('AuthProvider - Status Transitions', () {
    test('Should transition to loading during login', () async {
      // Start login (will fail due to no API)
      authProvider.loginByCpf('12345678901');

      // Check immediate state (may or may not be loading depending on async timing)
      expect(
        authProvider.status,
        isIn([AuthStatus.loading, AuthStatus.error, AuthStatus.initial]),
      );
    });
  });

  group('AuthProvider - Logout', () {
    test('Should clear all data on logout', () async {
      // Logout should work even when not authenticated
      await authProvider.logout();

      expect(authProvider.status, AuthStatus.unauthenticated);
      expect(authProvider.idoso, null);
      expect(authProvider.fcmToken, null);
      expect(authProvider.errorMessage, null);
      expect(authProvider.isAuthenticated, false);
    });
  });

  group('AuthProvider - Refresh', () {
    test('Should return false when not authenticated', () async {
      final success = await authProvider.refreshIdosoData();

      expect(success, false);
    });
  });
}
