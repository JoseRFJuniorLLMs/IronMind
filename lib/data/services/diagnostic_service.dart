import 'dart:io';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../core/config/app_config.dart';
import 'package:logger/logger.dart';
import 'api_service.dart';
import 'storage_service.dart';

class DiagnosticService {
  final Logger _logger = Logger();
  final StringBuffer _logBuffer = StringBuffer();

  void _log(String message) {
    _logBuffer.writeln(message);
    _logger.i('[Diagnostic] $message');
  }

  Future<void> sendReport() async {
    _logBuffer.clear();
    _log('📊 RELATÓRIO DE DIAGNÓSTICO EVA - ${DateTime.now()}');
    _log('--------------------------------------------------');

    try {
      await _checkDevice();
      await _checkFirebase();
      await _checkFcmToken();
      await _checkStorage();
      await _checkApi();
    } catch (e) {
      _log('❌ ERRO CRÍTICO DURANTE DIAGNÓSTICO: $e');
    }

    await _sendToDatabase();
  }

  Future<void> _checkDevice() async {
    _log('\n📱 DISPOSITIVO');
    if (Platform.isAndroid) {
      _log('Sistema: Android');
    } else if (Platform.isIOS) {
      _log('Sistema: iOS');
    } else {
      _log('Sistema: ${Platform.operatingSystem}');
    }

    try {
      final info = await PackageInfo.fromPlatform();
      _log('App Name: ${info.appName}');
      _log('Package: ${info.packageName}');
      _log('Version: ${info.version} build ${info.buildNumber}');
    } catch (e) {
      _log('Erro ao obter info do app: $e');
    }
  }

  Future<void> _checkFirebase() async {
    _log('\n🔥 FIREBASE');
    try {
      final apps = Firebase.apps;
      _log('Apps inicializados: ${apps.length}');
      if (apps.isNotEmpty) {
        final app = apps.first;
        _log('Projeto: ${app.options.projectId}');
        _log('App ID: ${app.options.appId}');
      }
    } catch (e) {
      _log('Erro Firebase: $e');
    }
  }

  Future<void> _checkFcmToken() async {
    _log('\n🔑 FCM TOKEN');
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      _log('Permissões: ${settings.authorizationStatus}');

      final token = await messaging.getToken();
      if (token != null) {
        _log('✅ Token obtido: ${token.substring(0, 20)}...');
        _log('Token completo: $token');

        final saved = StorageService.getFcmToken();
        _log('Storage Token: ${saved != null ? "Salvo" : "Vazio"}');
        if (saved != null && saved != token) {
          _log('⚠️ ATENÇÃO: Token no storage DIFERENTE do atual');
        }
      } else {
        _log('❌ Token é NULL');
      }
    } catch (e) {
      _log('Erro FCM: $e');
    }
  }

  Future<void> _checkStorage() async {
    _log('\n💾 STORAGE');
    try {
      final cpf = StorageService.getIdosoCpf();
      _log('CPF salvo: $cpf');
      final idosoId = StorageService.getIdosoId();
      _log('ID salvo: $idosoId');
    } catch (e) {
      _log('Erro Storage: $e');
    }
  }

  Future<void> _checkApi() async {
    _log('\n🌐 API');
    try {
      final api = ApiService();
      _log('Base URL: ${api.baseUrl}');
      _log('\n🔌 WEBSOCKET');
      // ✅ Use WS_URL
      final wsUrl = AppConfig.wsUrl;
      _log('WS URL: $wsUrl');
    } catch (e) {
      _log('Erro API: $e');
    }
  }

  Future<void> _sendToDatabase() async {
    try {
      final cpf = StorageService.getIdosoCpf();
      String deviceInfo = 'Unknown';
      String appVersion = 'Unknown';

      // Tentar obter info real
      try {
        if (Platform.isAndroid) deviceInfo = 'Android';
        final info = await PackageInfo.fromPlatform();
        appVersion = '${info.version}+${info.buildNumber}';
      } catch (_) {}

      final api = ApiService();
      // Enviar como ERROR para garantir que seja notado, ou INFO se for apenas diagnóstico
      // Vou usar INFO/WARNING já que é um reporte manual
      final success = await api.sendErrorLog(
        level: 'DIAGNOSTIC_REPORT',
        message: 'Relatório de Diagnóstico Mobile',
        details: _logBuffer.toString(),
        deviceInfo: deviceInfo,
        appVersion: appVersion,
        userCpf: cpf,
      );

      if (success) {
        _log('✅ Relatório enviado para o servidor com sucesso!');
      } else {
        _log('❌ Falha ao enviar para o servidor. Copiando para clipboard...');
        await Clipboard.setData(ClipboardData(text: _logBuffer.toString()));
      }
    } catch (e) {
      _logger.e('Erro ao enviar para DB: $e');
      // Fallback
      await Clipboard.setData(ClipboardData(text: _logBuffer.toString()));
    }
  }
}
