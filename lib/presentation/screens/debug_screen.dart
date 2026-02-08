import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:logger/logger.dart';
import 'dart:io';

import '../../../data/services/storage_service.dart';

class DebugScreen extends StatefulWidget {
  final bool showBackButton;

  const DebugScreen({super.key, this.showBackButton = false});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  final Logger _logger = Logger();
  final List<String> _logs = [];
  bool _isLoading = false;
  String? _token;
  String? _error;
  bool? _tokenSynced;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _addLog('🔧 Debug Screen inicializada');
    _runDiagnostics();
  }

  void _addLog(String message) {
    setState(() {
      _logs.add('${DateTime.now().toString().substring(11, 19)} - $message');
    });
    _logger.i(message);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _copyLogsToClipboard() async {
    final logsText = _logs.join('\n');
    await Clipboard.setData(ClipboardData(text: logsText));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Logs copiados para área de transferência'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _runDiagnostics() async {
    setState(() {
      _isLoading = true;
      _logs.clear();
      _error = null;
      _token = null;
      _tokenSynced = null;
    });

    try {
      _addLog('📱 ===== INFORMAÇÕES DO DISPOSITIVO =====');
      _addLog('Sistema: ${Platform.operatingSystem}');
      _addLog('Versão: ${Platform.operatingSystemVersion}');
      await Future.delayed(const Duration(milliseconds: 500));

      _addLog('');
      _addLog('🔥 ===== STATUS FIREBASE =====');

      if (Firebase.apps.isEmpty) {
        _addLog('❌ Firebase NÃO inicializado!');
        throw Exception('Firebase não inicializado');
      }

      _addLog('✅ Firebase inicializado');
      _addLog('Apps: ${Firebase.apps.length}');
      _addLog('Nome: ${Firebase.app().name}');
      _addLog('Projeto: ${Firebase.app().options.projectId}');
      _addLog('App ID: ${Firebase.app().options.appId}');

      final apiKey = Firebase.app().options.apiKey;
      _addLog('API Key: ${apiKey.substring(0, 20)}...');

      await Future.delayed(const Duration(milliseconds: 500));

      _addLog('');
      _addLog('💬 ===== FIREBASE MESSAGING =====');

      FirebaseMessaging messaging;
      try {
        messaging = FirebaseMessaging.instance;
        _addLog('✅ FirebaseMessaging instance criada');
      } catch (e) {
        _addLog('❌ Erro ao criar instance: $e');
        rethrow;
      }

      await Future.delayed(const Duration(milliseconds: 500));

      _addLog('');
      _addLog('🔐 ===== VERIFICANDO PERMISSÕES =====');

      try {
        final settings = await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          announcement: true,
          criticalAlert: true,
          provisional: false,
        );

        _addLog('✅ Permissões verificadas');
        _addLog('Status: ${settings.authorizationStatus}');
        _addLog('Alert: ${settings.alert}');
        _addLog('Badge: ${settings.badge}');
        _addLog('Sound: ${settings.sound}');

        if (settings.authorizationStatus == AuthorizationStatus.denied) {
          throw Exception('Permissões NEGADAS pelo usuário');
        }
      } catch (e) {
        _addLog('❌ Erro nas permissões: $e');
        rethrow;
      }

      await Future.delayed(const Duration(milliseconds: 500));

      _addLog('');
      _addLog('🔑 ===== OBTENDO FCM TOKEN =====');

      try {
        _addLog('Chamando getToken()...');
        final token = await messaging.getToken();

        if (token != null && token.isNotEmpty) {
          _addLog('✅ TOKEN OBTIDO COM SUCESSO!');
          _addLog('Tamanho: ${token.length} caracteres');
          _addLog('Primeiros 50: ${token.substring(0, 50)}...');
          _addLog('Últimos 50: ...${token.substring(token.length - 50)}');
          setState(() => _token = token);
        } else {
          _addLog('⚠️ Token retornou NULL ou vazio');
          throw Exception('Token não disponível');
        }
      } catch (e) {
        _addLog('❌ Erro ao obter token: $e');
        rethrow;
      }

      await Future.delayed(const Duration(milliseconds: 500));

      _addLog('');
      _addLog('💾 ===== VERIFICANDO STORAGE LOCAL =====');

      final storedToken = StorageService.getFcmToken();
      final idosoNome = StorageService.getIdosoNome();
      final idosoCpf = StorageService.getIdosoCpf();
      final idosoId = StorageService.getIdosoId();

      if (storedToken != null) {
        _addLog('✅ Token salvo localmente');
        _addLog('Match: ${storedToken == _token ? "✅ SIM" : "❌ NÃO"}');
      } else {
        _addLog('⚠️ Nenhum token no storage local');
      }

      if (idosoNome != null) {
        _addLog('✅ Usuário logado: $idosoNome');
        _addLog('   CPF: $idosoCpf');
        _addLog('   ID: $idosoId');
        _tokenSynced = true;
      } else {
        _addLog('⚠️ Nenhum usuário logado');
        _tokenSynced = false;
      }

      await Future.delayed(const Duration(milliseconds: 500));

      _addLog('');
      _addLog('🎉 ===== DIAGNÓSTICO COMPLETO =====');
      _addLog('✅ Tudo funcionando corretamente!');
      _addLog('');
      _addLog('📊 Resumo:');
      _addLog('  ✅ Firebase: Inicializado');
      _addLog('  ✅ Permissões: Concedidas');
      _addLog('  ✅ Token: Obtido');
      if (_tokenSynced == true) {
        _addLog('  ✅ Sincronização: Token sincronizado');
      } else {
        _addLog('  ⚠️ Sincronização: Pendente (faça login)');
      }
    } catch (e) {
      _addLog('');
      _addLog('💥 ===== ERRO CRÍTICO =====');
      _addLog('Erro: $e');
      _addLog('Tipo: ${e.runtimeType}');

      setState(() => _error = e.toString());

      _addLog('');
      _addLog('🔍 ===== POSSÍVEIS CAUSAS =====');
      _addLog('1. google-services.json ausente ou inválido');
      _addLog('2. Nome do pacote não corresponde ao Firebase');
      _addLog('3. App não registrado no Firebase Console');
      _addLog('4. Google Play Services indisponível');
      _addLog('5. Firewall/Rede bloqueando FCM');
      _addLog('6. Permissões negadas pelo usuário');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _goToHome() {
    if (StorageService.isLoggedIn()) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Faça login primeiro'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = StorageService.isLoggedIn();
    final userName = StorageService.getIdosoNome();

    return Scaffold(
      appBar: AppBar(
        title: const Text('🔧 Diagnóstico Firebase'),
        backgroundColor: Colors.red,
        leading: widget.showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _runDiagnostics,
            tooltip: 'Reexecutar diagnóstico',
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: _copyLogsToClipboard,
            tooltip: 'Copiar logs',
          ),
        ],
      ),
      body: Column(
        children: [
          // Header com status
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: _token != null
                ? Colors.green
                : (_error != null ? Colors.red : Colors.orange),
            child: Column(
              children: [
                Icon(
                  _token != null
                      ? Icons.check_circle
                      : (_isLoading ? Icons.hourglass_empty : Icons.error),
                  color: Colors.white,
                  size: 48,
                ),
                const SizedBox(height: 8),
                Text(
                  _token != null
                      ? 'TUDO OK ✅'
                      : (_isLoading ? 'Diagnosticando...' : 'ERRO ❌'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_token != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Token: ${_token!.substring(0, 30)}...',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
                if (isLoggedIn) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '👤 Logado como: $userName',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Logs em tempo real
          Expanded(
            child: Container(
              color: Colors.black,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(8),
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  final log = _logs[index];
                  Color textColor = Colors.white;

                  if (log.contains('✅')) {
                    textColor = Colors.green;
                  } else if (log.contains('❌')) {
                    textColor = Colors.red;
                  } else if (log.contains('⚠️')) {
                    textColor = Colors.orange;
                  } else if (log.contains('=====')) {
                    textColor = Colors.cyan;
                  } else if (log.contains('🔍') || log.contains('💡')) {
                    textColor = Colors.yellow;
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      log,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Botões de ação
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _copyLogsToClipboard,
                        icon: const Icon(Icons.copy),
                        label: const Text('Copiar Logs'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                          backgroundColor: Colors.blue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _runDiagnostics,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reexecutar'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (isLoggedIn && _token != null)
                  ElevatedButton.icon(
                    onPressed: _goToHome,
                    icon: const Icon(Icons.home),
                    label: const Text('Ir para Home'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      backgroundColor: Colors.green,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Voltar para Login'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      backgroundColor: Colors.grey,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
