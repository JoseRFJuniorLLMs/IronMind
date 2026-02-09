import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../data/services/api_service.dart';
import '../data/services/storage_service.dart';
import '../data/models/operator.dart';

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

  AuthStatus _status = AuthStatus.initial;
  Operator? _operator;
  String? _errorMessage;
  String? _fcmToken;

  AuthStatus get status => _status;
  Operator? get operator_ => _operator;
  String? get errorMessage => _errorMessage;
  String? get fcmToken => _fcmToken;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  int? get operatorId => _operator?.id;
  String? get operatorNome => _operator?.nome;
  String? get operatorCpf => _operator?.cpf;

  /// Inicializa o provider verificando se ha sessao salva
  Future<void> initialize() async {
    _logger.i('🔐 Inicializando AuthProvider...');
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      // Verificar se ha dados salvos
      final savedCpf = StorageService.getOperatorCpf();
      final savedId = StorageService.getOperatorId();

      if (savedCpf != null && savedId != null) {
        _logger.i('[Auth] Sessao encontrada: CPF=$savedCpf, ID=$savedId');

        final operatorData = await _apiService.getOperator(savedId);

        if (operatorData != null) {
          _operator = Operator.fromJson(operatorData);
          _status = AuthStatus.authenticated;

          await _syncFcmToken();

          _logger.i('[Auth] Sessao validada: ${_operator?.nome}');
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

      var operatorData = await _apiService.getOperatorByCpf(cpfClean);

      // Modo demo/offline: se API indisponível, criar operador local
      if (operatorData == null) {
        _logger.w('⚠️ API indisponível - entrando em modo demo');
        operatorData = {
          'id': 0,
          'nome': 'Operador Demo',
          'cpf': cpfClean,
          'telefone': '00000000000',
        };
      }

      _operator = Operator.fromJson(operatorData);

      await StorageService.saveOperatorData(
        operatorId: _operator!.id,
        nome: _operator!.nome,
        cpf: cpfClean,
        telefone: _operator!.telefone,
      );

      await _syncFcmToken();

      _status = AuthStatus.authenticated;
      _logger.i('[Auth] Login bem-sucedido: ${_operator?.nome}');

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

      if (_fcmToken != null && _operator?.cpf != null) {
        await StorageService.saveFcmToken(_fcmToken!);

        final success = await _apiService.syncTokenByCpf(
          cpf: _operator!.cpf!,
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
    _operator = null;
    _fcmToken = null;
    _errorMessage = null;

    notifyListeners();
    _logger.i('✅ Logout realizado');
  }

  Future<void> _clearSession() async {
    await StorageService.clearAll();
  }

  Future<bool> refreshOperatorData() async {
    if (_operator?.id == null) return false;

    try {
      final data = await _apiService.getOperator(_operator!.id);
      if (data != null) {
        _operator = Operator.fromJson(data);
        notifyListeners();
        return true;
      }
    } catch (e) {
      _logger.e('[Auth] Erro ao atualizar dados: $e');
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
