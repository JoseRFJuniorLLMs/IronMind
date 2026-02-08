import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';

/// Serviço para gerenciar dados locais persistentes do idoso
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
  static const String _keyIdosoId = 'idoso_id';
  static const String _keyIdosoNome = 'idoso_nome';
  static const String _keyIdosoCpf = 'idoso_cpf';
  static const String _keyIdosoTelefone = 'idoso_telefone';
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

  /// Salva os dados do idoso após login/cadastro
  static Future<bool> saveIdosoData({
    required int idosoId,
    required String nome,
    required String cpf,
    required String telefone, // Telefone agora é obrigatório
  }) async {
    try {
      await _prefs?.setInt(_keyIdosoId, idosoId);
      await _prefs?.setString(_keyIdosoNome, nome);
      await _prefs?.setString(_keyIdosoCpf, cpf);
      await _prefs?.setString(_keyIdosoTelefone, telefone); // Salva o telefone
      await _prefs?.setBool(_keyIsLoggedIn, true);
      
      _logger.i('✅ Idoso data saved: ID=$idosoId, Nome=$nome, CPF=$cpf, Telefone=$telefone');
      return true;
    } catch (e) {
      _logger.e('❌ Error saving idoso data: $e');
      return false;
    }
  }

  /// Obtém o ID do idoso
  static int? getIdosoId() {
    return _prefs?.getInt(_keyIdosoId);
  }

  /// Obtém o nome do idoso
  static String? getIdosoNome() {
    return _prefs?.getString(_keyIdosoNome);
  }

  /// Obtém o CPF do idoso
  static String? getIdosoCpf() {
    return _prefs?.getString(_keyIdosoCpf);
  }

  /// Obtém o Telefone do idoso
  static String? getIdosoTelefone() {
    return _prefs?.getString(_keyIdosoTelefone);
  }

  /// Verifica se há um idoso logado
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
      await _prefs?.remove(_keyIdosoId);
      await _prefs?.remove(_keyIdosoNome);
      await _prefs?.remove(_keyIdosoCpf);
      await _prefs?.remove(_keyIdosoTelefone);
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
    _logger.i('  - Idoso ID: ${getIdosoId()}');
    _logger.i('  - Idoso Nome: ${getIdosoNome()}');
    _logger.i('  - Idoso CPF: ${getIdosoCpf()}');
    _logger.i('  - Idoso Telefone: ${getIdosoTelefone()}');
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
