import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../data/services/api_service.dart';
import '../data/services/storage_service.dart';
import '../data/services/notification_service.dart';
import '../data/models/idoso.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

class AuthProvider with ChangeNotifier {
  final Logger _logger = Logger();
  final ApiService _apiService = ApiService();
  final NotificationService _notificationService = NotificationService();

  AuthStatus _status = AuthStatus.initial;
  Idoso? _idoso;
  String? _errorMessage;
  String? _fcmToken;

  AuthStatus get status => _status;
  Idoso? get idoso => _idoso;
  String? get errorMessage => _errorMessage;
  String? get fcmToken => _fcmToken;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  // Getters de conveniencia
  int? get idosoId => _idoso?.id;
  String? get idosoNome => _idoso?.nome;
  String? get idosoCpf => _idoso?.cpf;

  /// Inicializa o provider verificando se ha sessao salva
  Future<void> initialize() async {
    _logger.i('🔐 Inicializando AuthProvider...');
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      // Verificar se ha dados salvos
      final savedCpf = StorageService.getIdosoCpf();
      final savedId = StorageService.getIdosoId();

      if (savedCpf != null && savedId != null) {
        _logger.i('📋 Sessao encontrada: CPF=$savedCpf, ID=$savedId');

        // Validar com o backend
        final idosoData = await _apiService.getIdoso(savedId);

        if (idosoData != null) {
          _idoso = Idoso.fromJson(idosoData);
          _status = AuthStatus.authenticated;

          // Sincronizar FCM token
          await _syncFcmToken();

          // Inicializar notificacoes
          await _notificationService.initialize();

          _logger.i('✅ Sessao validada: ${_idoso?.nome}');
        } else {
          _logger.w('⚠️ Sessao invalida, limpando dados...');
          await _clearSession();
        }
      } else {
        _logger.i('📋 Nenhuma sessao encontrada');
        _status = AuthStatus.unauthenticated;
      }
    } catch (e) {
      _logger.e('❌ Erro ao inicializar auth: $e');
      _status = AuthStatus.unauthenticated;
      _errorMessage = 'Erro ao verificar sessao';
    }

    notifyListeners();
  }

  /// Login por CPF
  Future<bool> loginByCpf(String cpf) async {
    _logger.i('🔐 Tentando login com CPF: $cpf');
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      // Limpar CPF
      final cpfClean = cpf.replaceAll(RegExp(r'[^0-9]'), '');

      if (cpfClean.length != 11) {
        throw Exception('CPF invalido. Digite 11 numeros.');
      }

      // Buscar idoso pelo CPF
      final idosoData = await _apiService.getIdosoByCpf(cpfClean);

      if (idosoData == null) {
        throw Exception('CPF nao cadastrado. Entre em contato com o suporte.');
      }

      // Salvar dados
      _idoso = Idoso.fromJson(idosoData);

      await StorageService.saveIdosoData(
        idosoId: _idoso!.id,
        nome: _idoso!.nome,
        cpf: cpfClean,
        telefone: _idoso!.telefone,
      );

      // Sincronizar FCM token
      await _syncFcmToken();

      // Inicializar notificacoes
      await _notificationService.initialize();

      _status = AuthStatus.authenticated;
      _logger.i('✅ Login bem-sucedido: ${_idoso?.nome}');

      notifyListeners();
      return true;
    } catch (e) {
      _logger.e('❌ Erro no login: $e');
      _status = AuthStatus.error;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Sincroniza o FCM token com o backend
  Future<void> _syncFcmToken() async {
    try {
      _fcmToken = await FirebaseMessaging.instance.getToken();

      if (_fcmToken != null && _idoso?.cpf != null) {
        await StorageService.saveFcmToken(_fcmToken!);

        final success = await _apiService.syncTokenByCpf(
          cpf: _idoso!.cpf!,
          token: _fcmToken!,
        );

        if (success) {
          _logger.i('✅ FCM token sincronizado');
        } else {
          _logger.w('⚠️ Falha ao sincronizar FCM token');
        }
      }
    } catch (e) {
      _logger.e('❌ Erro ao sincronizar FCM: $e');
    }
  }

  /// Logout
  Future<void> logout() async {
    _logger.i('🔐 Realizando logout...');

    await _clearSession();

    _status = AuthStatus.unauthenticated;
    _idoso = null;
    _fcmToken = null;
    _errorMessage = null;

    notifyListeners();
    _logger.i('✅ Logout realizado');
  }

  /// Limpa a sessao
  Future<void> _clearSession() async {
    await StorageService.clearAll();
    await _notificationService.cancelarTodas();
  }

  /// Atualiza dados do idoso
  Future<bool> refreshIdosoData() async {
    if (_idoso?.id == null) return false;

    try {
      final data = await _apiService.getIdoso(_idoso!.id);
      if (data != null) {
        _idoso = Idoso.fromJson(data);
        notifyListeners();
        return true;
      }
    } catch (e) {
      _logger.e('❌ Erro ao atualizar dados: $e');
    }
    return false;
  }

  /// Limpa mensagem de erro
  void clearError() {
    _errorMessage = null;
    if (_status == AuthStatus.error) {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }
}
