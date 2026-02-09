import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';

/// Serviço para gerenciar dados locais persistentes do operador
/// 🔒 SECURITY: Tokens e credenciais são salvos com criptografia (SecureStorage)
/// 📝 Dados não-sensíveis (nome, settings) usam SharedPreferences
class StorageService {
  static final Logger _logger = Logger();
  static SharedPreferences? _prefs;
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  // Chaves de armazenamento - SharedPreferences (dados não-sensíveis)
  static const String _keyOperatorId = 'operator_id';
  static const String _keyOperatorNome = 'operator_nome';
  static const String _keyOperatorCpf = 'operator_cpf';
  static const String _keyOperatorTelefone = 'operator_telefone';
  static const String _keyIsLoggedIn = 'is_logged_in';

  // Chaves de armazenamento - SecureStorage (dados sensíveis)
  static const String _secureKeyFcmToken = 'secure_fcm_token';
  static const String _secureKeyAccessToken = 'secure_access_token';
  static const String _secureKeyRefreshToken = 'secure_refresh_token';

  /// Getter para acessar SharedPreferences (para diagnóstico)
  static SharedPreferences? get prefs => _prefs;

  /// Inicializa o SharedPreferences e SecureStorage
  static Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _logger.i('✅ StorageService initialized (SharedPreferences + SecureStorage)');
    } catch (e) {
      _logger.e('❌ Failed to initialize StorageService: $e');
    }
  }

  /// Salva os dados do operator após login/cadastro
  static Future<bool> saveOperatorData({
    required int operatorId,
    required String nome,
    required String cpf,
    required String telefone, // Telefone agora é obrigatório
  }) async {
    try {
      await _prefs?.setInt(_keyOperatorId, operatorId);
      await _prefs?.setString(_keyOperatorNome, nome);
      await _prefs?.setString(_keyOperatorCpf, cpf);
      await _prefs?.setString(_keyOperatorTelefone, telefone); // Salva o telefone
      await _prefs?.setBool(_keyIsLoggedIn, true);
      
      _logger.i('✅ Operator data saved: ID=$operatorId, Nome=$nome, CPF=$cpf, Telefone=$telefone');
      return true;
    } catch (e) {
      _logger.e('❌ Error saving operator data: $e');
      return false;
    }
  }

  /// Obtém o ID do operator
  static int? getOperatorId() {
    return _prefs?.getInt(_keyOperatorId);
  }

  /// Obtém o nome do operator
  static String? getOperatorNome() {
    return _prefs?.getString(_keyOperatorNome);
  }

  /// Obtém o CPF do operator
  static String? getOperatorCpf() {
    return _prefs?.getString(_keyOperatorCpf);
  }

  /// Obtém o Telefone do operator
  static String? getOperatorTelefone() {
    return _prefs?.getString(_keyOperatorTelefone);
  }

  /// Verifica se há um operator logado
  static bool isLoggedIn() {
    return _prefs?.getBool(_keyIsLoggedIn) ?? false;
  }

  /// 🔒 Salva o FCM Token com criptografia
  static Future<bool> saveFcmToken(String token) async {
    try {
      await _secureStorage.write(key: _secureKeyFcmToken, value: token);
      _logger.i('✅ FCM Token saved securely (encrypted)');
      return true;
    } catch (e) {
      _logger.e('❌ Error saving FCM token: $e');
      return false;
    }
  }

  /// 🔒 Obtém o FCM Token salvo (descriptografado)
  static Future<String?> getFcmToken() async {
    try {
      return await _secureStorage.read(key: _secureKeyFcmToken);
    } catch (e) {
      _logger.e('❌ Error reading FCM token: $e');
      return null;
    }
  }

  /// 🔒 Salva Access Token (OAuth/JWT)
  static Future<bool> saveAccessToken(String token) async {
    try {
      await _secureStorage.write(key: _secureKeyAccessToken, value: token);
      _logger.i('✅ Access Token saved securely (encrypted)');
      return true;
    } catch (e) {
      _logger.e('❌ Error saving access token: $e');
      return false;
    }
  }

  /// 🔒 Obtém Access Token
  static Future<String?> getAccessToken() async {
    try {
      return await _secureStorage.read(key: _secureKeyAccessToken);
    } catch (e) {
      _logger.e('❌ Error reading access token: $e');
      return null;
    }
  }

  /// 🔒 Salva Refresh Token (OAuth)
  static Future<bool> saveRefreshToken(String token) async {
    try {
      await _secureStorage.write(key: _secureKeyRefreshToken, value: token);
      _logger.i('✅ Refresh Token saved securely (encrypted)');
      return true;
    } catch (e) {
      _logger.e('❌ Error saving refresh token: $e');
      return false;
    }
  }

  /// 🔒 Obtém Refresh Token
  static Future<String?> getRefreshToken() async {
    try {
      return await _secureStorage.read(key: _secureKeyRefreshToken);
    } catch (e) {
      _logger.e('❌ Error reading refresh token: $e');
      return null;
    }
  }

  /// Limpa todos os dados (logout)
  static Future<bool> clearAll() async {
    try {
      // Limpa SharedPreferences (dados não-sensíveis)
      await _prefs?.remove(_keyOperatorId);
      await _prefs?.remove(_keyOperatorNome);
      await _prefs?.remove(_keyOperatorCpf);
      await _prefs?.remove(_keyOperatorTelefone);
      await _prefs?.remove(_keyIsLoggedIn);

      // 🔒 Limpa SecureStorage (tokens criptografados)
      await _secureStorage.delete(key: _secureKeyFcmToken);
      await _secureStorage.delete(key: _secureKeyAccessToken);
      await _secureStorage.delete(key: _secureKeyRefreshToken);

      _logger.i('🗑️ All user data cleared (SharedPreferences + SecureStorage)');
      return true;
    } catch (e) {
      _logger.e('❌ Error clearing data: $e');
      return false;
    }
  }

  /// Debug: Mostra todos os dados salvos
  static Future<void> debugPrintData() async {
    if (_prefs == null) {
      _logger.w('Storage not initialized, cannot print data.');
      return;
    }
    _logger.i('📊 Storage Data (SharedPreferences):');
    _logger.i('  - Operator ID: ${getOperatorId()}');
    _logger.i('  - Operator Nome: ${getOperatorNome()}');
    _logger.i('  - Operator CPF: ${getOperatorCpf()}');
    _logger.i('  - Operator Telefone: ${getOperatorTelefone()}');
    _logger.i('  - Is Logged In: ${isLoggedIn()}');

    _logger.i('🔒 Storage Data (SecureStorage - encrypted):');
    final fcmToken = await getFcmToken();
    final accessToken = await getAccessToken();
    final refreshToken = await getRefreshToken();
    _logger.i('  - FCM Token: ${fcmToken != null ? "✅ Present (${fcmToken.substring(0, 20)}...)" : "❌ Not set"}');
    _logger.i('  - Access Token: ${accessToken != null ? "✅ Present" : "❌ Not set"}');
    _logger.i('  - Refresh Token: ${refreshToken != null ? "✅ Present" : "❌ Not set"}');
  }
}
