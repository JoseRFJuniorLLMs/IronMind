import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/constants/text_styles.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _cpfController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _cpfController.dispose();
    super.dispose();
  }

  String _formatCpf(String value) {
    final digitsOnly = value.replaceAll(RegExp(r'[^0-9]'), '');
    final buffer = StringBuffer();

    for (int i = 0; i < digitsOnly.length && i < 11; i++) {
      if (i == 3 || i == 6) buffer.write('.');
      if (i == 9) buffer.write('-');
      buffer.write(digitsOnly[i]);
    }

    return buffer.toString();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.loginByCpf(_cpfController.text);

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (success) {
      context.go('/home');
    } else {
      _showError(authProvider.errorMessage ?? 'Erro ao fazer login');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
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
              Color(0xFF9F70D8),
              Color(0xFFFFB6C1),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/icone.png',
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.favorite,
                            size: 60,
                            color: Color(0xFF9F70D8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Titulo
                    const Text(
                      'Bem-vindo',
                      style: AppTextStyles.elderlyTitle,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Digite seu CPF para entrar',
                      style: AppTextStyles.elderlyBody.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Campo CPF
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: _cpfController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(11),
                          TextInputFormatter.withFunction((oldValue, newValue) {
                            return TextEditingValue(
                              text: _formatCpf(newValue.text),
                              selection: TextSelection.collapsed(
                                offset: _formatCpf(newValue.text).length,
                              ),
                            );
                          }),
                        ],
                        style: AppTextStyles.elderlyNumber,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: '000.000.000-00',
                          hintStyle: AppTextStyles.elderlyNumber.copyWith(
                            color: Colors.grey[400],
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 20,
                          ),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(left: 16),
                            child: Icon(
                              Icons.person_outline,
                              color: Colors.grey[600],
                              size: 28,
                            ),
                          ),
                        ),
                        validator: (value) {
                          final digits = value?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
                          if (digits.isEmpty) {
                            return 'Digite seu CPF';
                          }
                          if (digits.length != 11) {
                            return 'CPF deve ter 11 digitos';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Botao Entrar - Alto contraste e facil de tocar
                    SizedBox(
                      width: double.infinity,
                      height: 70, // Maior para facilitar toque
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF9F70D8),
                          disabledBackgroundColor: Colors.white.withOpacity(0.7),
                          elevation: 5,
                          shadowColor: Colors.black.withOpacity(0.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF9F70D8),
                                  ),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.login, size: 32),
                                  SizedBox(width: 12),
                                  Text(
                                    'ENTRAR',
                                    style: AppTextStyles.elderlyButtonLarge,
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Ajuda
                    TextButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Precisa de ajuda?'),
                            content: const Text(
                              'Se voce nao tem um CPF cadastrado, entre em contato com seu cuidador ou familiar responsavel para solicitar o cadastro no sistema EVA.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Entendi'),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: Icon(
                        Icons.help_outline,
                        color: Colors.white.withOpacity(0.9),
                        size: 28,
                      ),
                      label: Text(
                        'Precisa de ajuda?',
                        style: AppTextStyles.elderlyLabel.copyWith(
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
