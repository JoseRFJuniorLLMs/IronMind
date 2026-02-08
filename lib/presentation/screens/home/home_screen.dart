import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:math';
import 'package:logger/logger.dart';

import '../../../providers/call_provider.dart';
import '../../widgets/pulsing_button.dart';
import '../../../data/services/health_service.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/storage_service.dart';
import '../../widgets/sentinela_status_widget.dart';
import '../../widgets/health_sync_indicator.dart';
import '../../../core/accessibility/accessibility_helper.dart';
import '../../../core/startup/startup_fixer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Logger _logger = Logger();
  // Health Sync
  final HealthService _healthService = HealthService();
  bool _isSyncingHealth = false;
  bool _healthSyncError = false;
  bool _healthPermissionsDenied = false;
  bool _healthConnectNotInstalled = false;
  DateTime? _lastSyncTime;

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

    // Depois do startup fixer, sincroniza saúde
    _checkHealthAndSync();
  }

  /// ✅ FIX: Verifica Health Connect ANTES de solicitar permissões
  Future<void> _checkHealthAndSync() async {
    if (_isSyncingHealth) return;

    setState(() {
      _isSyncingHealth = true;
      _healthSyncError = false;
      _healthPermissionsDenied = false;
      _healthConnectNotInstalled = false;
    });

    try {
      // PASSO 1: Verificar se Health Connect está disponível
      _logger.i('⌚ Verificando Health Connect...');
      final hcStatus = await _healthService.checkHealthConnectStatus();

      if (hcStatus == HealthConnectStatus.notInstalled) {
        _logger.w('⚠️ Health Connect não instalado - ignorando sync de saúde');
        setState(() {
          _healthConnectNotInstalled = true;
          _healthPermissionsDenied = false;
          _healthSyncError = false;
        });
        // Não mostra erro - Health Connect é opcional
        return;
      }

      if (hcStatus == HealthConnectStatus.updateRequired) {
        _logger.w('⚠️ Health Connect precisa de atualização');
        setState(() {
          _healthConnectNotInstalled = true;
          _healthSyncError = false;
        });
        return;
      }

      if (hcStatus != HealthConnectStatus.available) {
        _logger.w('⚠️ Health Connect não suportado neste dispositivo');
        setState(() => _healthConnectNotInstalled = true);
        return;
      }

      // PASSO 2: Verificar se já tem permissões (sem solicitar)
      _logger.i('⌚ Verificando permissões existentes...');
      final hasPermissions = await _healthService.hasPermissions();

      if (!hasPermissions) {
        _logger.i(
            '⌚ Permissões não concedidas ainda - aguardando ação do usuário');
        setState(() => _healthPermissionsDenied = true);
        return;
      }

      // PASSO 3: Sincronizar dados (já tem permissões)
      await _syncHealthDataInternal();
    } catch (e) {
      _logger.e('❌ Erro ao verificar saúde: $e');
      final errorMsg = e.toString().toLowerCase();

      // Classificar o erro
      if (errorMsg.contains('não instalado') ||
          errorMsg.contains('not installed')) {
        setState(() => _healthConnectNotInstalled = true);
      } else if (errorMsg.contains('permiss') || errorMsg.contains('denied')) {
        setState(() => _healthPermissionsDenied = true);
      } else {
        setState(() => _healthSyncError = true);
      }
    } finally {
      if (mounted) setState(() => _isSyncingHealth = false);
    }
  }

  /// Solicita permissões e sincroniza (chamado pelo usuário)
  Future<void> _syncHealthData() async {
    if (_isSyncingHealth) return;

    setState(() {
      _isSyncingHealth = true;
      _healthSyncError = false;
    });

    try {
      // Se Health Connect não está instalado, não tentar
      if (_healthConnectNotInstalled) {
        _showSyncSnackBar("Health Connect não disponível neste dispositivo.",
            isError: true);
        return;
      }

      _logger.i('⌚ Solicitando permissões de saúde...');
      final granted = await _healthService.requestPermissions();

      if (granted) {
        setState(() => _healthPermissionsDenied = false);
        await _syncHealthDataInternal();
      } else {
        _logger.w('⚠️ Permissões de saúde negadas');
        setState(() => _healthPermissionsDenied = true);
        _showSyncSnackBar("Permissão de saúde necessária.", isError: true);
      }
    } catch (e) {
      _logger.e('❌ Erro no sync de saúde: $e');
      final errorMsg = e.toString().toLowerCase();

      if (errorMsg.contains('não instalado') ||
          errorMsg.contains('not installed')) {
        setState(() => _healthConnectNotInstalled = true);
        _showSyncSnackBar("Instale o Health Connect da Play Store.",
            isError: true);
      } else {
        setState(() => _healthSyncError = true);
        _showSyncSnackBar("Erro ao sincronizar dados de saúde.", isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSyncingHealth = false);
    }
  }

  /// Lógica interna de sincronização (assume permissões OK)
  Future<void> _syncHealthDataInternal() async {
    _logger.i('⌚ Buscando dados de saúde...');

    // 1. Buscar dados
    final steps = await _healthService.fetchSteps();
    final heartRate = await _healthService.fetchHeartRate();
    final sleep = await _healthService.fetchSleep();

    // 2. Preparar payload
    List<Map<String, dynamic>> vitalSigns = [];

    // Passos
    if (steps > 0) {
      vitalSigns.add({
        'tipo': 'passos',
        'valor': steps.toString(),
        'unidade': 'count',
        'data_hora': DateTime.now().toIso8601String(),
      });
    }

    // Batimentos (pegar o mais recente)
    if (heartRate.isNotEmpty) {
      final lastHeartRate = heartRate.last;
      vitalSigns.add({
        'tipo': 'bpm',
        'valor': lastHeartRate.value.toString(),
        'unidade': 'bpm',
        'data_hora': lastHeartRate.dateFrom.toIso8601String(),
      });
    }

    // Sono
    if (sleep.isNotEmpty) {
      final lastSleep = sleep.last;
      final durationHours =
          lastSleep.dateTo.difference(lastSleep.dateFrom).inHours;
      vitalSigns.add({
        'tipo': 'sono',
        'valor': durationHours.toString(),
        'unidade': 'horas',
        'data_hora': lastSleep.dateFrom.toIso8601String(),
      });
    }

    // ✅ Pegar ID real do usuário logado
    final savedId = StorageService.getIdosoId();
    if (vitalSigns.isNotEmpty && savedId != null) {
      final api = ApiService();
      final success =
          await api.sendVitalSigns(idosoId: savedId, vitalSigns: vitalSigns);

      if (success) {
        // ✅ Atualizar timestamp da última sincronização
        setState(() {
          _lastSyncTime = DateTime.now();
          _healthSyncError = false;
        });
        _showSyncSnackBar("Dados de saúde sincronizados!", isError: false);
      } else {
        setState(() => _healthSyncError = true);
        // ✅ Mostrar erro específico se disponível
        final errorDetail = api.lastVitalSignsError ?? "Erro desconhecido";
        _showSyncSnackBar("Falha: $errorDetail", isError: true);
        _logger.e('❌ Erro de sincronização: $errorDetail');
      }
    } else if (vitalSigns.isEmpty) {
      _logger.i('ℹ️ Nenhum dado novo para sincronizar');
      setState(() {
        _lastSyncTime = DateTime.now();
      });
    }
  }

  void _showSyncSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  /// Banner visível para solicitar permissões de saúde
  Widget _buildHealthPermissionBanner() {
    final isNotInstalled = _healthConnectNotInstalled;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                isNotInstalled ? Icons.download : Icons.favorite,
                color: isNotInstalled ? Colors.blue : Colors.red,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isNotInstalled
                      ? 'Instale o Health Connect'
                      : 'Permissão de Saúde',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isNotInstalled
                ? 'Para monitorar sua saúde, instale o app Health Connect da Google Play Store.'
                : 'Para sincronizar seus dados de saúde, precisamos da sua permissão.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isSyncingHealth
                      ? null
                      : () async {
                          if (isNotInstalled) {
                            // Abrir Play Store para instalar Health Connect
                            await _healthService.openHealthConnectSettings();
                          } else {
                            // Solicitar permissões
                            await _syncHealthData();
                          }
                        },
                  icon: Icon(
                    isNotInstalled ? Icons.download : Icons.check,
                    size: 20,
                  ),
                  label: Text(
                    isNotInstalled ? 'INSTALAR' : 'PERMITIR',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isNotInstalled ? Colors.blue : Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              if (!isNotInstalled) ...[
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () async {
                    // Abrir configurações do Health Connect diretamente
                    await _healthService.openHealthConnectSettings();
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('ABRIR CONFIG'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
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

            // Health Sync Indicator (ao lado do Sentinela)
            Positioned(
              top: 50,
              right: 80, // Ao lado do Sentinela
              child: HealthSyncIndicator(
                isSyncing: _isSyncingHealth,
                hasError: _healthSyncError,
                permissionsDenied: _healthPermissionsDenied,
                lastSyncTime: _lastSyncTime,
                onTap: _syncHealthData, // ✅ Sincroniza ao clicar
              ),
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

                          // BANNER DE PERMISSÕES DE SAÚDE
                          if (_healthPermissionsDenied ||
                              _healthConnectNotInstalled) ...[
                            _buildHealthPermissionBanner(),
                            const SizedBox(height: 20),
                          ],

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

                          // SEGUNDA FILEIRA: Agenda, Medicamentos, Contatos
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // 3. Botão AGENDAMENTO
                              _buildActionButton(
                                icon: Icons.calendar_month,
                                label: 'Agenda',
                                colors: [Color(0xFF9F70D8), Color(0xFF6B8DD6)],
                                onTap: () {
                                  _logger.i('📅 Abrindo agendamento...');
                                  context.push('/schedule');
                                },
                              ),
                              if (false) const SizedBox(width: 20),
                              // 4. Botão MEDICAMENTOS
                              if (false)
                                _buildActionButton(
                                  icon: Icons.medication,
                                  label: 'Remedios',
                                  colors: [
                                    Color(0xFF10B981),
                                    Color(0xFF059669)
                                  ],
                                  onTap: () {
                                    _logger.i('💊 Abrindo medicamentos...');
                                    context.push('/medicamentos');
                                  },
                                ),
                              if (false) const SizedBox(width: 20),
                              // 5. Botão CONTATOS
                              if (false)
                                _buildActionButton(
                                  icon: Icons.people,
                                  label: 'Familia',
                                  colors: [
                                    Color(0xFFF59E0B),
                                    Color(0xFFD97706)
                                  ],
                                  onTap: () {
                                    _logger.i('👪 Abrindo contatos...');
                                    context.push('/contatos-emergencia');
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
