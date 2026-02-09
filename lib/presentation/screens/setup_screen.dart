import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../data/services/firebase_service.dart';
import '../../data/services/storage_service.dart';
import '../../data/services/api_service.dart';
import 'package:provider/provider.dart';
import '../../providers/call_provider.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final Logger _logger = Logger();
  final _formKey = GlobalKey<FormState>();
  final _cpfController = TextEditingController();

  // Novos controllers

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSavedCpf();
  }

  Future<void> _loadSavedCpf() async {
    final savedCpf = StorageService.getOperatorCpf();
    if (savedCpf != null && savedCpf.isNotEmpty) {
      setState(() {
        _cpfController.text = savedCpf; // O formatter vai aplicar a máscara
      });
      _logger.i('✅ CPF carregado do storage: $savedCpf');
    }
  }

  @override
  void dispose() {
    _cpfController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final cpf = _cpfController.text.trim();
      _logger.i('🔐 Login iniciado: $cpf');

      // ✅ PASSO 1: Verificar permissões ANTES de pedir token
      _logger.i('🔔 Verificando permissões...');
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        announcement: true,
        criticalAlert: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        throw Exception(
          'Permissões de notificação negadas.\n\n'
          'Por favor, vá em:\n'
          'Configurações > Apps > EVA > Notificações\n'
          'E ative as notificações.',
        );
      }

      // ✅ PASSO 2: Obter token com retry robusto
      _logger.i('📱 Obtendo FCM token...');
      String? token = await FirebaseService.getTokenWithRetry(
        maxAttempts: 5,
        initialDelay: const Duration(seconds: 1),
      );

      if (token == null || token.isEmpty) {
        _logger.w('⚠️ Token null, forçando refresh...');
        token = await FirebaseService.forceRefreshToken();
      }

      if (token == null || token.isEmpty) {
        throw Exception('Não foi possível obter o token de notificação.');
      }

      _logger.i('✅ Token: ${token.substring(0, 30)}...');

      // ✅ PASSO 3: Buscar dados do operador (Tradicional)
      _logger.i('🔍 Buscando dados do operador...');
      final apiService = ApiService();
      final operatorData = await apiService.getOperatorByCpf(cpf);

      if (operatorData == null) {
        throw Exception('CPF não encontrado no sistema');
      }

      _logger.i('✅ Operador encontrado: ${operatorData['nome']}');
      final operatorId = _parseOperatorId(operatorData['id']);

      if (operatorId == null) {
        throw Exception('ID do operador inválido');
      }

      // ✅ PASSO 4: Sincronizar token
      _logger.i('🔄 Sincronizando token...');
      await apiService.syncTokenByCpf(cpf: cpf, token: token);

      // ✅ PASSO 5: Salvar localmente
      final nome = _parseString(operatorData['nome']) ?? 'Sem nome';
      final telefone = _parseString(operatorData['telefone']) ?? '';

      await StorageService.saveOperatorData(
        operatorId: operatorId,
        nome: nome,
        cpf: cpf,
        telefone: telefone,
      );
      await StorageService.saveFcmToken(token);

      if (mounted) {
        Provider.of<CallProvider>(context, listen: false).updateFcmToken(token);
      }

      _logger.i('🎉 Login completo!');

      // ✅ PASSO 7: Navegar
      if (mounted) {
        context.go('/home');
      }
    } catch (e, stackTrace) {
      _logger.e('❌ Erro no login: $e');
      _logger.e('Stack: $stackTrace');

      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });

      if (mounted) {
        _showErrorDialog(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('Erro no Login'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(error),
              const SizedBox(height: 16),
              const Text(
                '💡 O que fazer?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('• Reinicie o aplicativo'),
              const Text('• Verifique sua internet'),
              const Text('• Toque em "Diagnóstico" para mais detalhes'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/diagnostic');
            },
            child: const Text('DIAGNÓSTICO'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _handleLogin(); // Tentar novamente
            },
            child: const Text('TENTAR NOVAMENTE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF9F70D8), // Roxo
              Color(0xFFFFB6C1), // Rosa claro
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo EVA - Premium Presentation
                  Center(
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.3),
                            blurRadius: 40,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/images/logox.png',
                        width: 250,
                        height: 250,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Center(
                    child: Text(
                      'eva-ia.org',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                        shadows: [
                          Shadow(
                            color: Colors.black26,
                            offset: Offset(0, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Campo CPF - Styled
                  TextFormField(
                    controller: _cpfController,
                    style: const TextStyle(color: Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'DIGITE SEU CPF',
                      labelStyle: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                      hintText: '000.000.000-00',
                      hintStyle: const TextStyle(color: Colors.black26),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.9),
                      prefixIcon: const Icon(
                        Icons.person,
                        color: Color(0xFF9F70D8),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 20,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(11),
                      _CpfInputFormatter(),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty)
                        return 'Informe o CPF';
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  // Botão ENTRAR - Premium 3D
                  _buildPremiumButton(
                    label: 'ENTRAR',
                    colors: [const Color(0xFFE0B0FF), const Color(0xFF9F70D8)],
                    isLoading: _isLoading,
                    onPressed: _handleLogin,
                  ),

                  const SizedBox(height: 20),

                  // Botão EMERGÊNCIA - Distinctive Red 3D
                  _buildPremiumButton(
                    label: 'EMERGÊNCIA',
                    colors: [const Color(0xFFFF6B6B), const Color(0xFFC92A2A)],
                    icon: Icons.phone_in_talk,
                    onPressed: _handleEmergency,
                  ),

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 24),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleEmergency() async {
    try {
      final cpf = StorageService.getOperatorCpf();
      if (cpf == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('CPF não configurado. Faça login primeiro.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🛑 Enviando ALERTA DE EMERGÊNCIA...'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );

      final apiService = ApiService();
      await apiService.sendVitalSigns(
        operatorId: StorageService.getOperatorId() ?? 0,
        vitalSigns: [
          {
            'tipo': 'emergencia',
            'valor': 'disparado_pelo_usuario',
            'unidade': 'evento',
            'data_hora': DateTime.now().toIso8601String(),
          },
        ],
      );
    } catch (e) {
      _logger.e('Erro ao disparar emergência: $e');
    }
  }

  Widget _buildPremiumButton({
    required String label,
    required List<Color> colors,
    required VoidCallback onPressed,
    IconData? icon,
    bool isLoading = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onPressed,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.last.withValues(alpha: 0.5),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: Colors.white, size: 24),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  int? _parseOperatorId(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value);
    }
    try {
      return int.parse(value.toString());
    } catch (_) {
      return null;
    }
  }

  String? _parseString(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      return value.trim().isEmpty ? null : value.trim();
    }
    return value.toString().trim();
  }
}

class _CpfInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) {
      return newValue;
    }
    final digitsOnly = text.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.isEmpty) {
      return newValue.copyWith(text: '');
    }
    final buffer = StringBuffer();
    for (int i = 0; i < digitsOnly.length && i < 11; i++) {
      if (i == 3 || i == 6) {
        buffer.write('.');
      } else if (i == 9) {
        buffer.write('-');
      }
      buffer.write(digitsOnly[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
