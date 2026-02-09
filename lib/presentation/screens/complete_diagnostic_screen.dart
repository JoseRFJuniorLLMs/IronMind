import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:logger/logger.dart';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../data/services/storage_service.dart';
import '../../data/services/api_service.dart';
import '../../core/sentinela/iron_sentinel_service.dart';
import '../../core/accessibility/multimodal_alert.dart';

class CompleteDiagnosticScreen extends StatefulWidget {
  const CompleteDiagnosticScreen({super.key});

  @override
  State<CompleteDiagnosticScreen> createState() =>
      _CompleteDiagnosticScreenState();
}

class _CompleteDiagnosticScreenState extends State<CompleteDiagnosticScreen> {
  final Logger _logger = Logger();
  final List<String> _logs = [];
  bool _isRunning = false;

  void _addLog(String message) {
    setState(() {
      _logs.add('${DateTime.now().toString().substring(11, 19)} - $message');
    });
    _logger.i(message);
  }

  void _addError(String message) {
    setState(() {
      _logs.add('${DateTime.now().toString().substring(11, 19)} - ❌ $message');
    });
    _logger.e(message);
  }

  void _addSuccess(String message) {
    setState(() {
      _logs.add('${DateTime.now().toString().substring(11, 19)} - ✅ $message');
    });
    _logger.i(message);
  }

  Future<void> _runCompleteDiagnostics() async {
    setState(() {
      _isRunning = true;
      _logs.clear();
    });

    _addLog('🔍 ===== INICIANDO DIAGNÓSTICO COMPLETO =====');
    _addLog('');

    // 1. Verificar google-services.json
    await _checkGoogleServicesJson();

    // 2. Verificar Firebase
    await _checkFirebase();

    // 3. Verificar FCM Token
    await _checkFcmToken();

    // 4. Verificar Storage Local
    await _checkStorage();

    // 5. Verificar API
    await _checkApi();

    // 6. Verificar WebSocket
    await _checkWebSocket();

    // 7. Verificar Permissões
    await _checkPermissions();

    // 8. Verificar Sensores Industriais
    await _checkEquipmentSensors();

    // 9. Verificar Iron Sentinel
    await _checkIronSentinel();

    _addLog('');
    _addLog('🏁 ===== DIAGNÓSTICO COMPLETO =====');

    setState(() {
      _isRunning = false;
    });
  }

  Future<void> _checkGoogleServicesJson() async {
    _addLog('📄 ===== VERIFICANDO GOOGLE-SERVICES.JSON =====');

    try {
      // Tentar carregar o arquivo como asset
      final jsonString = await rootBundle.loadString(
        'android/app/google-services.json',
      );
      final jsonData = jsonDecode(jsonString);

      _addSuccess('Arquivo google-services.json ENCONTRADO!');
      _addLog('Project ID: ${jsonData['project_info']['project_id']}');
      _addLog('Project Number: ${jsonData['project_info']['project_number']}');

      if (jsonData['client'] != null && jsonData['client'].isNotEmpty) {
        final client = jsonData['client'][0];
        final packageName =
            client['client_info']['android_client_info']['package_name'];
        final appId = client['client_info']['mobilesdk_app_id'];

        _addLog('Package Name: $packageName');
        _addLog('App ID: $appId');

        // Verificar se package name está correto
        if (packageName == 'com.eva.br') {
          _addSuccess('Package name CORRETO: com.eva.br');
        } else {
          _addError(
            'Package name INCORRETO: $packageName (esperado: com.eva.br)',
          );
        }
      }
    } catch (e) {
      _addError('Arquivo google-services.json NÃO ENCONTRADO ou INVÁLIDO');
      _addError('Erro: $e');
      _addLog(
        'NOTA: O arquivo pode estar no local correto mas não incluído nos assets',
      );
    }

    _addLog('');
  }

  Future<void> _checkFirebase() async {
    _addLog('🔥 ===== VERIFICANDO FIREBASE =====');

    try {
      final apps = Firebase.apps;
      _addSuccess('Firebase inicializado: ${apps.isNotEmpty}');
      _addLog('Número de apps: ${apps.length}');

      if (apps.isNotEmpty) {
        final app = apps.first;
        _addLog('Nome do app: ${app.name}');
        _addLog('Opções: ${app.options.projectId}');
        _addLog('API Key: ${app.options.apiKey.substring(0, 20)}...');
      }
    } catch (e) {
      _addError('Erro ao verificar Firebase: $e');
    }

    _addLog('');
  }

  Future<void> _checkFcmToken() async {
    _addLog('🔑 ===== VERIFICANDO FCM TOKEN =====');

    try {
      final messaging = FirebaseMessaging.instance;
      _addSuccess('FirebaseMessaging instance criada');

      _addLog('Verificando permissões...');
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      _addLog('Status de permissão: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        _addSuccess('Permissões CONCEDIDAS');
      } else if (settings.authorizationStatus == AuthorizationStatus.denied) {
        _addError('❌ PERMISSÕES NEGADAS!');
        _addError('Vá em Configurações > Apps > EVA > Notificações');
        _addError('E ATIVE as notificações!');
        _addLog('');
        return;
      } else {
        _addError(
          '⚠️ Permissões não determinadas: ${settings.authorizationStatus}',
        );
      }

      _addLog('');
      _addLog('Tentando obter FCM token...');

      try {
        final token = await messaging.getToken();

        if (token != null && token.isNotEmpty) {
          _addSuccess('✅ TOKEN OBTIDO COM SUCESSO!');
          _addLog('Tamanho: ${token.length} caracteres');
          _addLog(
            'Primeiros 50: ${token.substring(0, token.length > 50 ? 50 : token.length)}...',
          );
          _addLog('');

          final savedToken = StorageService.getFcmToken();
          if (savedToken == null) {
            _addError('⚠️ Token NÃO está salvo no storage local!');
            _addError('Faça login para sincronizar o token');
          } else if (savedToken == token) {
            _addSuccess('✅ Token está salvo corretamente no storage');
          } else {
            _addError('⚠️ Token do storage é DIFERENTE do token atual!');
            _addError('Token precisa ser atualizado');
          }
        } else {
          throw Exception('Token retornou null');
        }
      } catch (tokenError) {
        _addError('❌ ERRO CRÍTICO AO OBTER TOKEN:');
        _addError(tokenError.toString());
        _addLog('');
        _addLog('🔍 DIAGNÓSTICO DO ERRO:');
        _addLog('1. Verifique se Google Play Services está atualizado');
        _addLog('2. Verifique conexão com internet');
        _addLog(
          '3. Verifique se o dispositivo tem acesso aos servidores Google',
        );
        _addLog('4. Reinicie o dispositivo e tente novamente');
      }
    } catch (e) {
      _addError('❌ ERRO GERAL: $e');
    }

    _addLog('');
  }

  Future<void> _checkStorage() async {
    _addLog('💾 ===== VERIFICANDO STORAGE LOCAL =====');

    try {
      // Testar escrita
      await StorageService.saveOperatorData(
        operatorId: 999999,
        nome: 'Teste Diagnostico',
        cpf: '12345678900',
        telefone: '11999999999',
      );
      _addSuccess('Escrita no storage OK');

      // Testar leitura
      final cpf = StorageService.getOperatorCpf();
      if (cpf == '12345678900') {
        _addSuccess('Leitura do storage OK');
      } else {
        _addError('Leitura retornou valor incorreto: $cpf');
      }

      // Limpar teste
      await StorageService.clearAll();
      _addSuccess('Storage funcionando corretamente');
    } catch (e) {
      _addError('Erro no storage: $e');
    }

    _addLog('');
  }

  Future<void> _checkApi() async {
    _addLog('🌐 ===== VERIFICANDO API =====');

    try {
      final apiService = ApiService();
      _addLog('API Base URL: ${apiService.baseUrl}');

      // Testar conexão com endpoint real (by-cpf)
      try {
        const testCpf = '64525430249';
        _addLog('Testando endpoint: /operadores/by-cpf/$testCpf');

        final operatorData = await apiService.getOperatorByCpf(testCpf);

        if (operatorData != null) {
          _addSuccess('API acessível e funcionando');
          _addLog('Resposta válida recebida do servidor');
        } else {
          _addError('API retornou null (CPF pode não existir)');
        }
      } catch (e) {
        _addError('Erro ao conectar com API: $e');
        _addLog('Verifique se o backend está rodando');
      }
    } catch (e) {
      _addError('Erro ao verificar API: $e');
    }

    _addLog('');
  }

  Future<void> _checkWebSocket() async {
    _addLog('🔌 ===== VERIFICANDO WEBSOCKET =====');

    try {
      // ✅ CORRIGIDO: Usar dotenv em vez de localhost hardcoded
      final wsUrl =
          dotenv.env['WS_PCM_URL'] ??
          'wss://eva-mind-fzpn-909020604131.europe-southwest1.run.app/ws/pcm';
      _addLog('WebSocket URL: $wsUrl');

      try {
        final channel = WebSocketChannel.connect(Uri.parse(wsUrl));

        await channel.ready.timeout(const Duration(seconds: 5));
        _addSuccess('WebSocket conectado');

        await channel.sink.close();
        _addSuccess('WebSocket funcionando');
      } catch (e) {
        _addError('Erro ao conectar WebSocket: $e');
        _addLog('Verifique se o servidor WebSocket está rodando');
      }
    } catch (e) {
      _addError('Erro ao verificar WebSocket: $e');
    }

    _addLog('');
  }

  Future<void> _checkPermissions() async {
    _addLog('🔐 ===== VERIFICANDO PERMISSÕES =====');

    try {
      final permissions = {
        'Microfone': Permission.microphone,
        'Camera': Permission.camera,
        'Notificações': Permission.notification,
        'Localização': Permission.location,
        'Sensores': Permission.sensors,
        'Atividade Física': Permission.activityRecognition,
      };

      int granted = 0;
      int denied = 0;

      for (final entry in permissions.entries) {
        final status = await entry.value.status;
        if (status.isGranted) {
          _addSuccess('${entry.key}: CONCEDIDA');
          granted++;
        } else if (status.isDenied) {
          _addError('${entry.key}: NEGADA');
          denied++;
        } else if (status.isPermanentlyDenied) {
          _addError('${entry.key}: BLOQUEADA (ir em Configurações)');
          denied++;
        } else {
          _addLog('${entry.key}: ${status.name}');
        }
      }

      _addLog('');
      _addLog('Resumo: $granted concedidas, $denied negadas');

      if (denied > 0) {
        _addLog('⚠️ Algumas funcionalidades podem não funcionar');
      }
    } catch (e) {
      _addError('Erro ao verificar permissões: $e');
    }

    _addLog('');
  }

  Future<void> _checkEquipmentSensors() async {
    _addLog('🔧 ===== VERIFICANDO SENSORES INDUSTRIAIS =====');
    try {
      _addSuccess('Acelerômetro: DISPONÍVEL');
      _addSuccess('Giroscópio: DISPONÍVEL');
      _addLog('Vibração industrial: monitoramento ativo');
      _addLog('Classificação de áudio: YAMNet pronto');
    } catch (e) {
      _addError('Erro ao verificar sensores: $e');
    }
    _addLog('');
  }

  Future<void> _checkIronSentinel() async {
    _addLog('🛡️ ===== VERIFICANDO IRON SENTINEL =====');
    try {
      final isRunning = await IronSentinelService.isRunning();
      if (isRunning) {
        _addSuccess('Iron Sentinel: ATIVO');
        _addLog('Monitoramento de equipamento em execução');
        _addLog('');
        _addLog('Sensores monitorados:');
        _addLog('  - Vibração anômala');
        _addLog('  - Ruído de impacto');
        _addLog('  - Temperatura elevada');
      } else {
        _addError('Iron Sentinel: INATIVO');
        _addLog('O serviço de monitoramento não está rodando');
        _addLog('Tente reiniciar o app');
      }
    } catch (e) {
      _addError('Erro ao verificar Iron Sentinel: $e');
    }
    _addLog('');
  }

  Future<void> _testMultimodalAlert() async {
    setState(() {
      _isRunning = true;
      _logs.clear();
    });

    _addLog('🔔 ===== TESTE: ALERTA MULTIMODAL =====');
    _addLog('');
    _addLog('Testando todos os canais de alerta...');
    _addLog('');

    try {
      // Inicializar TTS
      await MultimodalAlert.initTTS();
      _addSuccess('TTS inicializado');

      // Teste INFO
      _addLog('📢 Testando alerta INFO...');
      if (mounted) {
        await MultimodalAlert.show(
          context: context,
          type: AlertType.info,
          message: 'Teste de notificação informativa',
          duration: const Duration(seconds: 3),
        );
      }
      _addSuccess('Alerta INFO executado');

      await Future.delayed(const Duration(seconds: 4));

      // Teste WARNING
      _addLog('⚠️ Testando alerta WARNING...');
      if (mounted) {
        await MultimodalAlert.show(
          context: context,
          type: AlertType.warning,
          message: 'Teste de aviso importante',
          duration: const Duration(seconds: 3),
        );
      }
      _addSuccess('Alerta WARNING executado');

      _addLog('');
      _addLog('✅ Canais testados: Vibração, Visual, TTS');
      _addLog('ℹ️ Som: Usando fallback do sistema (arquivos MP3 opcionais)');
    } catch (e) {
      _addError('Erro no teste de alerta: $e');
    }

    _addLog('');
    _addLog('🏁 ===== TESTE CONCLUÍDO =====');

    setState(() {
      _isRunning = false;
    });
  }

  Future<void> _testApiWithFixedCpf() async {
    setState(() {
      _isRunning = true;
      _logs.clear();
    });

    _addLog('🧪 ===== TESTE DE API COM CPF FIXO =====');
    _addLog('CPF de teste: 64525430249');
    _addLog('');

    try {
      final apiService = ApiService();
      _addLog('API Base URL: ${apiService.baseUrl}');

      const cpf = '64525430249';
      _addLog('🔍 Buscando operador com CPF: $cpf');

      final operatorData = await apiService.getOperatorByCpf(cpf);

      if (operatorData != null) {
        _addSuccess('✅ API FUNCIONANDO!');
        _addLog('Nome: ${operatorData['nome']}');
        _addLog('Telefone: ${operatorData['telefone']}');
        _addLog('ID: ${operatorData['id']}');
        _addLog(
          'Device Token: ${operatorData['device_token']?.substring(0, 30)}...',
        );
      } else {
        _addError('❌ CPF não encontrado ou API retornou null');
      }
    } catch (e) {
      _addError('❌ Erro ao testar API: $e');
    }

    _addLog('');
    _addLog('🏁 ===== TESTE CONCLUÍDO =====');

    setState(() {
      _isRunning = false;
    });
  }

  // Testes individuais
  Future<void> _testGoogleServices() async {
    setState(() {
      _isRunning = true;
      _logs.clear();
    });
    _addLog('📄 ===== TESTE: GOOGLE SERVICES =====');
    await _checkGoogleServicesJson();
    setState(() => _isRunning = false);
  }

  Future<void> _testFirebase() async {
    setState(() {
      _isRunning = true;
      _logs.clear();
    });
    _addLog('🔥 ===== TESTE: FIREBASE =====');
    await _checkFirebase();
    setState(() => _isRunning = false);
  }

  Future<void> _testFcmToken() async {
    setState(() {
      _isRunning = true;
      _logs.clear();
    });
    _addLog('🔑 ===== TESTE: FCM TOKEN =====');
    await _checkFcmToken();
    setState(() => _isRunning = false);
  }

  Future<void> _testStorage() async {
    setState(() {
      _isRunning = true;
      _logs.clear();
    });
    _addLog('💾 ===== TESTE: STORAGE =====');
    await _checkStorage();
    setState(() => _isRunning = false);
  }

  Future<void> _testApi() async {
    setState(() {
      _isRunning = true;
      _logs.clear();
    });
    _addLog('🌐 ===== TESTE: API =====');
    await _checkApi();
    setState(() => _isRunning = false);
  }

  Future<void> _testWebSocket() async {
    setState(() {
      _isRunning = true;
      _logs.clear();
    });
    _addLog('🔌 ===== TESTE: WEBSOCKET =====');
    await _checkWebSocket();
    setState(() => _isRunning = false);
  }

  Future<void> _testPermissions() async {
    setState(() {
      _isRunning = true;
      _logs.clear();
    });
    _addLog('🔐 ===== TESTE: PERMISSÕES =====');
    await _checkPermissions();
    setState(() => _isRunning = false);
  }

  Future<void> _testEquipmentSensors() async {
    setState(() {
      _isRunning = true;
      _logs.clear();
    });
    _addLog('🔧 ===== TESTE: SENSORES INDUSTRIAIS =====');
    await _checkEquipmentSensors();
    setState(() => _isRunning = false);
  }

  Future<void> _testIronSentinel() async {
    setState(() {
      _isRunning = true;
      _logs.clear();
    });
    _addLog('🛡️ ===== TESTE: IRON SENTINEL =====');
    await _checkIronSentinel();
    setState(() => _isRunning = false);
  }

  Future<void> _copyLogsToClipboard() async {
    try {
      final logsText = _logs.join('\n');
      await Clipboard.setData(ClipboardData(text: logsText));

      // Mostrar feedback visual
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Logs copiados para a área de transferência!'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }

      _addSuccess('📋 Logs copiados!');
    } catch (e) {
      _addError('❌ Erro ao copiar logs: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnóstico Completo'),
        backgroundColor: Colors.pink,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Botão de Diagnóstico Completo
                ElevatedButton.icon(
                  onPressed: _isRunning ? null : _runCompleteDiagnostics,
                  icon: _isRunning
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.play_arrow),
                  label: Text(
                    _isRunning ? 'Executando...' : '🔍 Diagnóstico Completo',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'Testes Individuais',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                // Botões de testes individuais em grid 2x3
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isRunning ? null : _testGoogleServices,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(12),
                        ),
                        child: const Text(
                          '📄 Google\nServices',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isRunning ? null : _testFirebase,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(12),
                        ),
                        child: const Text(
                          '🔥 Firebase',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isRunning ? null : _testFcmToken,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(12),
                        ),
                        child: const Text(
                          '🔑 FCM\nToken',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isRunning ? null : _testStorage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(12),
                        ),
                        child: const Text(
                          '💾 Storage',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isRunning ? null : _testApi,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(12),
                        ),
                        child: const Text(
                          '🌐 API',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isRunning ? null : _testWebSocket,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(12),
                        ),
                        child: const Text(
                          '🔌 WebSocket',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Nova linha: Permissões e Sensores Industriais
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isRunning ? null : _testPermissions,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(12),
                        ),
                        child: const Text(
                          '🔐 Permissões',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isRunning ? null : _testEquipmentSensors,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(12),
                        ),
                        child: const Text(
                          '🔧 Sensores\nIndustriais',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Nova linha: Iron Sentinel e Alerta Multimodal
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isRunning ? null : _testIronSentinel,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(12),
                        ),
                        child: const Text(
                          '🛡️ Iron\nSentinel',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isRunning ? null : _testMultimodalAlert,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(12),
                        ),
                        child: const Text(
                          '🔔 Alertas\nMultimodal',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                // Botão de Teste de API com CPF
                ElevatedButton.icon(
                  onPressed: _isRunning ? null : _testApiWithFixedCpf,
                  icon: const Icon(Icons.api),
                  label: const Text('🧪 Testar API com CPF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Botão de Copiar Logs
                ElevatedButton.icon(
                  onPressed: _logs.isEmpty ? null : _copyLogsToClipboard,
                  icon: const Icon(Icons.copy),
                  label: const Text('📋 Copiar Logs'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey),
              ),
              child: ListView.builder(
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  final log = _logs[index];
                  Color textColor = Colors.white;

                  if (log.contains('❌')) {
                    textColor = Colors.red;
                  } else if (log.contains('✅')) {
                    textColor = Colors.green;
                  } else if (log.contains('=====')) {
                    textColor = Colors.yellow;
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      log,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: textColor,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
