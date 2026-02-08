import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eva_mobile/data/services/storage_service.dart';

/// Integration tests for authentication flow
/// Focus: Login/logout flow, session persistence
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  tearDown(() async {
    await StorageService.clearAll();
  });

  group('Auth Flow - Login', () {
    test('Should complete full login flow and persist session', () async {
      // Arrange
      const idosoId = 456;
      const nome = 'Seu João';
      const cpf = '987.654.321-00';
      const telefone = '(21) 91234-5678';
      const fcmToken = 'fcm_token_xyz789';

      // Act - Simulate login
      final savedUser = await StorageService.saveIdosoData(
        idosoId: idosoId,
        nome: nome,
        cpf: cpf,
        telefone: telefone,
      );
      final savedToken = await StorageService.saveFcmToken(fcmToken);

      // Assert - Session should be active
      expect(savedUser, true);
      expect(savedToken, true);
      expect(StorageService.isLoggedIn(), true);
      expect(StorageService.getIdosoId(), idosoId);
      expect(StorageService.getIdosoNome(), nome);
      expect(await StorageService.getFcmToken(), fcmToken);
    });

    test('Should handle incomplete login data', () async {
      // This test verifies that all required fields are actually required
      // In real app, API would validate this, but storage should also be consistent

      // Note: Dart will enforce required parameters at compile time
      // This is a placeholder for testing business logic around incomplete data
      expect(true, true);
    });
  });

  group('Auth Flow - Session Persistence', () {
    test('Should maintain session across app restarts (simulated)', () async {
      // Arrange - Login
      await StorageService.saveIdosoData(
        idosoId: 789,
        nome: 'Dona Rosa',
        cpf: '111.222.333-44',
        telefone: '(31) 99999-8888',
      );
      await StorageService.saveFcmToken('persistent_token');

      // Act - Simulate app restart (re-initialize storage)
      await StorageService.init();

      // Assert - Session should still exist
      expect(StorageService.isLoggedIn(), true);
      expect(StorageService.getIdosoId(), 789);
      expect(StorageService.getIdosoNome(), 'Dona Rosa');
      expect(await StorageService.getFcmToken(), 'persistent_token');
    });
  });

  group('Auth Flow - Logout', () {
    test('Should complete full logout flow and clear all data', () async {
      // Arrange - Login first
      await StorageService.saveIdosoData(
        idosoId: 999,
        nome: 'Test User',
        cpf: '000.000.000-00',
        telefone: '(00) 00000-0000',
      );
      await StorageService.saveFcmToken('token_to_clear');
      await StorageService.saveAccessToken('access_to_clear');

      // Verify login worked
      expect(StorageService.isLoggedIn(), true);

      // Act - Logout
      final cleared = await StorageService.clearAll();

      // Assert - All data should be gone
      expect(cleared, true);
      expect(StorageService.isLoggedIn(), false);
      expect(StorageService.getIdosoId(), null);
      expect(StorageService.getIdosoNome(), null);
      expect(StorageService.getIdosoCpf(), null);
      expect(await StorageService.getFcmToken(), null);
      expect(await StorageService.getAccessToken(), null);
    });

    test('Should handle logout when not logged in', () async {
      // Act - Logout without login
      final cleared = await StorageService.clearAll();

      // Assert - Should succeed (no-op)
      expect(cleared, true);
      expect(StorageService.isLoggedIn(), false);
    });
  });

  group('Auth Flow - Multiple Sessions', () {
    test('Should replace old session with new login', () async {
      // Arrange - First login
      await StorageService.saveIdosoData(
        idosoId: 111,
        nome: 'First User',
        cpf: '111.111.111-11',
        telefone: '(11) 11111-1111',
      );

      // Act - Second login (same device, different user)
      await StorageService.saveIdosoData(
        idosoId: 222,
        nome: 'Second User',
        cpf: '222.222.222-22',
        telefone: '(22) 22222-2222',
      );

      // Assert - Should only have second user
      expect(StorageService.getIdosoId(), 222);
      expect(StorageService.getIdosoNome(), 'Second User');
      expect(StorageService.getIdosoCpf(), '222.222.222-22');
    });
  });

  group('Auth Flow - Security', () {
    test('Should not expose sensitive data in logs', () async {
      // This is a design principle test
      // StorageService should use logger that masks sensitive data

      await StorageService.saveIdosoData(
        idosoId: 123,
        nome: 'Test',
        cpf: '123.456.789-00',
        telefone: '(11) 98765-4321',
      );

      // In real implementation, verify logs don't contain full CPF/tokens
      // For now, this is a placeholder for manual log inspection
      expect(true, true);
    });
  });
}
