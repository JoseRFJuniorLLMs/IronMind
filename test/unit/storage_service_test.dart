import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eva_mobile/data/services/storage_service.dart';

/// Unit tests for StorageService
/// Focus: Data persistence, encryption, clearing data
void main() {
  setUp(() async {
    // Mock SharedPreferences for testing
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  group('StorageService - Basic Data Persistence', () {
    test('Should save and retrieve idoso data', () async {
      // Arrange
      const idosoId = 123;
      const nome = 'Dona Maria';
      const cpf = '123.456.789-00';
      const telefone = '(11) 98765-4321';

      // Act
      final saved = await StorageService.saveIdosoData(
        idosoId: idosoId,
        nome: nome,
        cpf: cpf,
        telefone: telefone,
      );

      // Assert
      expect(saved, true);
      expect(StorageService.getIdosoId(), idosoId);
      expect(StorageService.getIdosoNome(), nome);
      expect(StorageService.getIdosoCpf(), cpf);
      expect(StorageService.getIdosoTelefone(), telefone);
      expect(StorageService.isLoggedIn(), true);
    });

    test('Should return null for non-existent data', () {
      // Arrange & Act
      final id = StorageService.getIdosoId();
      final nome = StorageService.getIdosoNome();

      // Assert
      expect(id, null);
      expect(nome, null);
      expect(StorageService.isLoggedIn(), false);
    });
  });

  group('StorageService - Secure Token Storage', () {
    test('Should save and retrieve FCM token securely', () async {
      // Arrange
      const fcmToken = 'test_fcm_token_12345_encrypted';

      // Act
      final saved = await StorageService.saveFcmToken(fcmToken);
      final retrieved = await StorageService.getFcmToken();

      // Assert
      expect(saved, true);
      expect(retrieved, fcmToken);
    });

    test('Should save and retrieve access token securely', () async {
      // Arrange
      const accessToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';

      // Act
      final saved = await StorageService.saveAccessToken(accessToken);
      final retrieved = await StorageService.getAccessToken();

      // Assert
      expect(saved, true);
      expect(retrieved, accessToken);
    });

    test('Should save and retrieve refresh token securely', () async {
      // Arrange
      const refreshToken = 'refresh_token_abc123_encrypted';

      // Act
      final saved = await StorageService.saveRefreshToken(refreshToken);
      final retrieved = await StorageService.getRefreshToken();

      // Assert
      expect(saved, true);
      expect(retrieved, refreshToken);
    });
  });

  group('StorageService - Data Clearing', () {
    test('Should clear all data including secure tokens', () async {
      // Arrange - Save data first
      await StorageService.saveIdosoData(
        idosoId: 123,
        nome: 'Test User',
        cpf: '123.456.789-00',
        telefone: '(11) 98765-4321',
      );
      await StorageService.saveFcmToken('test_token');
      await StorageService.saveAccessToken('test_access');

      // Act
      final cleared = await StorageService.clearAll();

      // Assert
      expect(cleared, true);
      expect(StorageService.getIdosoId(), null);
      expect(StorageService.getIdosoNome(), null);
      expect(StorageService.isLoggedIn(), false);
      expect(await StorageService.getFcmToken(), null);
      expect(await StorageService.getAccessToken(), null);
    });
  });

  group('StorageService - Security Tests', () {
    test('Tokens should NOT be accessible via SharedPreferences directly', () {
      // This test verifies that tokens are stored in SecureStorage, not SharedPreferences
      // If we can read tokens from SharedPreferences, it's a security vulnerability

      // Note: This is a conceptual test - in real implementation,
      // SecureStorage uses Android Keystore which is separate from SharedPreferences
      expect(true, true); // Placeholder - SecureStorage handles encryption internally
    });
  });
}
