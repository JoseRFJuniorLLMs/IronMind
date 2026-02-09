import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:math';
import 'package:logger/logger.dart';

import '../../../providers/call_provider.dart';
import '../../widgets/pulsing_button.dart';
import '../../../data/services/storage_service.dart';
import '../../widgets/sentinela_status_widget.dart';
import '../../../core/accessibility/accessibility_helper.dart';
import '../../../core/startup/startup_fixer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Logger _logger = Logger();

  bool _startupCheckDone = false;

  @override
  void initState() {
    super.initState();
    // Executa verificações de startup após o primeiro frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runStartupChecks();
    });
  }

  /// Executa verificações automáticas e correções para o usuário
  Future<void> _runStartupChecks() async {
    if (_startupCheckDone) return;
    _startupCheckDone = true;

    _logger.i('🚀 Executando verificações de startup...');

    // Executa o StartupFixer que resolve problemas automaticamente
    await StartupFixer().runAllChecks(context);
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: 'Botao $label',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(40),
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: colors,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.last.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(icon, size: 36, color: Colors.white),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  shadows: [
                    Shadow(
                      color: Colors.black26,
                      offset: Offset(1, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {}
      },
      child: Scaffold(
        // backgroundColor: Colors.white, // Removido para usar gradiente
        body: Stack(
          children: [
            // 1. Background Layer (Purple-Pink Gradient)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF9F70D8), // Roxo
                      Color(0xFFFFB6C1), // Rosa claro
                    ],
                  ),
                ),
              ),
            ),

            // 2. Content Layer
            // Sentinela Status (direita)
            Positioned(
              top: 50,
              right: 20,
              child: const SentinelaStatusWidget(),
            ),

            // Botao de Configuracoes (esquerda)
            Positioned(
              top: 50,
              left: 20,
              child: Semantics(
                button: true,
                label: 'Configuracoes de acessibilidade',
                hint: 'Toque para ajustar tamanho de fonte e contraste',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => context.push('/accessibility'),
                    borderRadius: BorderRadius.circular(25),
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.settings,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            Consumer<CallProvider>(
              builder: (context, callProvider, child) {
                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // ESTADO NORMAL (AGUARDANDO) - Oculta se estiver tocando
                        if (callProvider.status != CallStatus.ringing) ...[
                          // LOGO X (Native Audio - sem WebView)
                          Image.asset(
                            'assets/images/logox.png',
                            height: 350,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 20),

                          // BOTÕES DE AÇÃO (LADO A LADO)
                          if (false) // OCULTADO POR SOLICITAÇÃO DO USUÁRIO
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // 1. Botão LIGAR (Áudio) - Roxo Claro (EVA Theme)
                                Semantics(
                                  button: true,
                                  label: 'Botão de chamada de voz com a EVA',
                                  hint:
                                      'Toque duas vezes para iniciar uma ligação de áudio com a assistente virtual',
                                  excludeSemantics: true,
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        _logger.i(
                                            '🎤 Iniciando Chamada de Áudio...');
                                        callProvider.startOutgoingCall();
                                        context.go('/call');
                                      },
                                      borderRadius: BorderRadius.circular(60),
                                      child: Container(
                                        width: 120,
                                        height: 120,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: const LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              Color(0xFFE0B0FF),
                                              Color(0xFF9F70D8),
                                            ],
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF9F70D8)
                                                  .withValues(alpha: 0.5),
                                              blurRadius: 15,
                                              offset: const Offset(0, 8),
                                            ),
                                          ],
                                        ),
                                        child: const Center(
                                          child: Icon(
                                            Icons.phone,
                                            size: 50,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 40),
                                // 2. Botão VÍDEO (Câmera) - Rosa Claro (EVA Theme)
                                Semantics(
                                  button: true,
                                  label: 'Botão de chamada de vídeo com a EVA',
                                  hint:
                                      'Toque duas vezes para iniciar uma videochamada com a assistente virtual',
                                  excludeSemantics: true,
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        _logger.i(
                                            '📹 Iniciando Chamada de Vídeo...');
                                        context.push('/video');
                                      },
                                      borderRadius: BorderRadius.circular(60),
                                      child: Container(
                                        width: 120,
                                        height: 120,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: const LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              Color(0xFFFFB6C1),
                                              Color(0xFFFF69B4),
                                            ],
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFFFF69B4)
                                                  .withValues(alpha: 0.5),
                                              blurRadius: 15,
                                              offset: const Offset(0, 8),
                                            ),
                                          ],
                                        ),
                                        child: const Center(
                                          child: Icon(
                                            Icons.videocam,
                                            size: 50,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                          const SizedBox(height: 30),

                          // BOTÕES PRINCIPAIS: Inspecionar + Falar
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // 1. Botão INSPECIONAR (Câmera + IA)
                              _buildActionButton(
                                icon: Icons.camera_alt,
                                label: 'Inspecionar',
                                colors: [Color(0xFF00BCD4), Color(0xFF0097A7)],
                                onTap: () {
                                  _logger.i('[IronMind] Abrindo camera de inspecao...');
                                  context.push('/inspection');
                                },
                              ),
                              const SizedBox(width: 40),
                              // 2. Botão FALAR (Comando de voz)
                              _buildActionButton(
                                icon: Icons.mic,
                                label: 'Falar',
                                colors: [Color(0xFFFF6B35), Color(0xFFE55100)],
                                onTap: () {
                                  _logger.i('[IronMind] Iniciando comando de voz...');
                                  context.push('/call');
                                },
                              ),
                            ],
                          ),
                        ],

                        if (callProvider.status == CallStatus.ringing)
                          Semantics(
                            button: true,
                            label: 'Botão para atender chamada recebida da EVA',
                            hint: 'Toque duas vezes para atender a ligação',
                            excludeSemantics: true,
                            child: PulsingButton(
                              imagePath: 'assets/images/oceano_azul.jpg',
                              label: '',
                              size: 400,
                              onTap: () async {
                                try {
                                  if (mounted) {
                                    // ✅ Botão "ATENDER" -> Fluxo de ÁUDIO (WebSocket AI)
                                    context.go('/call');
                                  }
                                  await Future.delayed(
                                    const Duration(milliseconds: 100),
                                  );
                                  // ✅ Inicia motor de áudio
                                  callProvider.acceptCall();
                                } catch (e) {
                                  _logger.e('❌ Erro ao atender: $e');
                                }
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
