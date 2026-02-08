import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/services/health_service.dart'; // Importa HealthConnectStatus tambem

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  final Logger _logger = Logger();
  final HealthService _healthService = HealthService();
  bool _isRequesting = false;
  final Map<String, bool> _permissionStatus = {};

  final List<Permission> _requiredPermissions = [
    Permission.microphone,
    Permission.camera,
    Permission.notification,
    Permission.ignoreBatteryOptimizations,
    Permission.sensors,
    Permission.activityRecognition,
    // Sentinela Background & Call Permissions
    Permission.systemAlertWindow,
    Permission.phone,
    Permission.location,
    Permission.sms,
  ];

  // Chave especial para permissões de saúde
  static const String _healthPermissionKey = 'health';

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    // Verificar permissões básicas
    for (var permission in _requiredPermissions) {
      final status = await permission.status;
      setState(() {
        _permissionStatus[permission.toString()] = status.isGranted;
      });
    }

    // Verificar permissões de saúde
    if (Platform.isAndroid) {
      // Primeiro verificar se Health Connect esta disponivel
      final hcStatus = await _healthService.checkHealthConnectStatus();
      _logger.i('📱 Health Connect Status inicial: $hcStatus');

      if (hcStatus == HealthConnectStatus.available) {
        // Health Connect disponivel, verificar se ja temos permissao
        final hasHealthPermission = await _healthService.hasPermissions();
        setState(() {
          _permissionStatus[_healthPermissionKey] = hasHealthPermission;
        });
      } else {
        // Health Connect nao disponivel - nao bloquear o usuario
        // Marcar como false, mas o usuario pode pular
        setState(() {
          _permissionStatus[_healthPermissionKey] = false;
        });
      }
    } else {
      // iOS - verificar HealthKit
      final hasHealthPermission = await _healthService.hasPermissions();
      setState(() {
        _permissionStatus[_healthPermissionKey] = hasHealthPermission;
      });
    }
  }

  Future<void> _requestSinglePermission(Permission permission) async {
    try {
      final status = await permission.request();
      setState(() {
        _permissionStatus[permission.toString()] = status.isGranted;
      });

      if (status.isPermanentlyDenied) {
        _showOpenSettingsDialog(permission.toString());
      }
    } catch (e) {
      _logger.e('Error requesting permission: $e');
    }
  }

  Future<void> _requestHealthPermission() async {
    try {
      _logger.i('🏥 Solicitando permissões de saúde...');

      // PASSO 1: Verificar se Health Connect esta disponivel (Android)
      if (Platform.isAndroid) {
        final hcStatus = await _healthService.checkHealthConnectStatus();
        _logger.i('📱 Health Connect Status: $hcStatus');

        if (hcStatus == HealthConnectStatus.notInstalled) {
          _logger.w('⚠️ Health Connect nao instalado');
          _showHealthConnectNotInstalledDialog();
          setState(() {
            _permissionStatus[_healthPermissionKey] = false;
          });
          return;
        }

        if (hcStatus == HealthConnectStatus.updateRequired) {
          _logger.w('⚠️ Health Connect precisa de atualizacao');
          _showHealthConnectUpdateDialog();
          setState(() {
            _permissionStatus[_healthPermissionKey] = false;
          });
          return;
        }

        if (hcStatus != HealthConnectStatus.available) {
          _logger.w('⚠️ Health Connect nao suportado');
          // Pular verificacao de saude se nao suportado
          setState(() {
            _permissionStatus[_healthPermissionKey] = true; // Marcar como OK para nao travar
          });
          return;
        }
      }

      // PASSO 2: Verificar se sensores básicos foram concedidos primeiro
      final sensorsGranted = _permissionStatus[Permission.sensors.toString()] ?? false;
      final activityGranted = _permissionStatus[Permission.activityRecognition.toString()] ?? false;

      if (!sensorsGranted || !activityGranted) {
        _logger.w('⚠️ Sensores básicos não concedidos. Health Connect requer sensores primeiro.');
        _showHealthPermissionRequirementsDialog();
        setState(() {
          _permissionStatus[_healthPermissionKey] = false;
        });
        return;
      }

      // PASSO 3: Solicitar permissoes do Health Connect
      final granted = await _healthService.requestPermissions();
      setState(() {
        _permissionStatus[_healthPermissionKey] = granted;
      });

      if (!granted && Platform.isAndroid) {
        // Mostrar diálogo explicando sobre Health Connect
        _showHealthConnectDialog();
      }

      _logger.i('🏥 Permissões de saúde: ${granted ? "Concedidas" : "Negadas"}');
    } catch (e) {
      _logger.e('❌ Erro ao solicitar permissões de saúde: $e');
      setState(() {
        _permissionStatus[_healthPermissionKey] = false;
      });

      final errorMsg = e.toString().toLowerCase();

      // Tratar erros especificos
      if (errorMsg.contains('nao esta instalado') || errorMsg.contains('not installed')) {
        _showHealthConnectNotInstalledDialog();
      } else if (errorMsg.contains('atualizado') || errorMsg.contains('update')) {
        _showHealthConnectUpdateDialog();
      } else {
        _showHealthConnectDialog();
      }
    }
  }

  void _showHealthConnectNotInstalledDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.app_shortcut, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Expanded(child: Text('Instalar Health Connect')),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'O Health Connect nao esta instalado no seu dispositivo.\n',
              style: TextStyle(fontSize: 15),
            ),
            Text(
              'O EVA precisa do Health Connect para:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('• Monitorar seus passos'),
            Text('• Verificar batimentos cardiacos'),
            Text('• Acompanhar seu sono'),
            SizedBox(height: 16),
            Text(
              'Clique em "Instalar" para baixar da Play Store.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Permitir continuar sem Health Connect
              setState(() {
                _permissionStatus[_healthPermissionKey] = true;
              });
            },
            child: const Text('Pular'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _openHealthConnectInPlayStore();
            },
            icon: const Icon(Icons.download),
            label: const Text('Instalar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showHealthConnectUpdateDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.system_update, color: Colors.blue, size: 28),
            SizedBox(width: 12),
            Expanded(child: Text('Atualizar Health Connect')),
          ],
        ),
        content: const Text(
          'O Health Connect precisa ser atualizado para funcionar com o EVA.\n\n'
          'Por favor, atualize o app na Play Store e volte aqui.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _permissionStatus[_healthPermissionKey] = true;
              });
            },
            child: const Text('Pular'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _openHealthConnectInPlayStore();
            },
            icon: const Icon(Icons.update),
            label: const Text('Atualizar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showHealthPermissionRequirementsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.health_and_safety, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('Sensores Necessários'),
          ],
        ),
        content: const Text(
          'Para monitorar sua saúde, o EVA precisa primeiro acessar os sensores do dispositivo.\n\n'
          'Por favor, conceda as permissões de:\n'
          '• Sensores Corporais\n'
          '• Reconhecimento de Atividade\n\n'
          'Depois, tente novamente a permissão de saúde.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }

  void _showHealthConnectDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.healing, color: Colors.blue, size: 28),
            SizedBox(width: 12),
            Expanded(child: Text('Health Connect Necessário')),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'O EVA precisa do app Health Connect para monitorar sua saúde.\n',
              style: TextStyle(fontSize: 15),
            ),
            SizedBox(height: 12),
            Text(
              'O que fazer:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text('1. Instale o Health Connect da Play Store'),
            SizedBox(height: 4),
            Text('2. Abra o Health Connect e configure'),
            SizedBox(height: 4),
            Text('3. Volte ao EVA e tente novamente'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Depois'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _openHealthConnectInPlayStore();
            },
            icon: const Icon(Icons.download),
            label: const Text('Instalar Agora'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openHealthConnectInPlayStore() async {
    const playStoreUrl = 'https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata';
    final uri = Uri.parse(playStoreUrl);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _logger.e('❌ Não foi possível abrir a Play Store');
      }
    } catch (e) {
      _logger.e('❌ Erro ao abrir Play Store: $e');
    }
  }

  void _showOpenSettingsDialog(String permissionKey) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permissão Negada'),
        content: Text(
          'A permissão de ${_getPermissionName(permissionKey)} foi negada permanentemente.\n'
          'Por favor, ative nas configurações do app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Abrir Configurações'),
          ),
        ],
      ),
    );
  }

  Future<void> _proceedIfAllGranted() async {
    final allGranted = _permissionStatus.values.every((granted) => granted);
    if (allGranted) {
      context.go('/setup');
    } else {
      await _requestAllPermissions();
    }
  }

  Future<void> _requestAllPermissions() async {
    setState(() {
      _isRequesting = true;
    });

    _logger.i('🔐 Solicitando todas as permissões...');

    // Solicitar permissões básicas uma por uma
    for (var permission in _requiredPermissions) {
      try {
        final status = await permission.request();
        setState(() {
          _permissionStatus[permission.toString()] = status.isGranted;
        });
        _logger.i(
          '✅ ${_getPermissionName(permission.toString())}: ${status.isGranted ? "Concedida" : "Negada"}',
        );
      } catch (e) {
        _logger.e('❌ Erro ao solicitar ${_getPermissionName(permission.toString())}: $e');
      }
    }

    // Solicitar permissões de saúde (Health Connect/HealthKit)
    await _requestHealthPermission();

    setState(() {
      _isRequesting = false;
    });

    // Verificar se todas foram concedidas
    final allGranted = _permissionStatus.values.every((granted) => granted);

    if (allGranted) {
      _logger.i('✅ Todas as permissões concedidas!');
      if (mounted) {
        context.go('/setup');
      }
    } else {
      _logger.w('⚠️ Algumas permissões foram negadas');
      _showPermissionsDeniedDialog();
    }
  }

  void _showPermissionsDeniedDialog() {
    // Verificar quais permissoes criticas estao faltando
    final criticalMissing = <String>[];
    final optionalMissing = <String>[];

    for (var entry in _permissionStatus.entries) {
      if (!entry.value) {
        final name = _getPermissionName(entry.key);
        // Health e alguns outros sao opcionais
        if (entry.key == _healthPermissionKey ||
            entry.key.contains('sms') ||
            entry.key.contains('systemAlertWindow')) {
          optionalMissing.add(name);
        } else {
          criticalMissing.add(name);
        }
      }
    }

    // Se apenas permissoes opcionais faltam, permitir continuar
    if (criticalMissing.isEmpty) {
      _logger.i('✅ Todas permissoes criticas concedidas. Opcionais faltando: $optionalMissing');
      context.go('/setup');
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permissões Necessárias'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'O EVA precisa de algumas permissões para funcionar.\n',
            ),
            if (criticalMissing.isNotEmpty) ...[
              const Text(
                'Obrigatórias (faltando):',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
              ),
              ...criticalMissing.map((p) => Text('• $p')),
              const SizedBox(height: 12),
            ],
            if (optionalMissing.isNotEmpty) ...[
              const Text(
                'Opcionais (podem ser concedidas depois):',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
              ),
              ...optionalMissing.map((p) => Text('• $p')),
            ],
          ],
        ),
        actions: [
          if (criticalMissing.isEmpty)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                context.go('/setup');
              },
              child: const Text('Continuar Mesmo Assim'),
            ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Abrir Configurações'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _requestAllPermissions();
            },
            child: const Text('Tentar Novamente'),
          ),
        ],
      ),
    );
  }

  String _getPermissionName(String permissionKey) {
    if (permissionKey == _healthPermissionKey) return 'Dados de Saúde';
    if (permissionKey.contains('microphone')) return 'Microfone';
    if (permissionKey.contains('camera')) return 'Câmera';
    if (permissionKey.contains('notification')) return 'Notificações';
    if (permissionKey.contains('ignoreBatteryOptimizations')) {
      return 'Otimização de Bateria';
    }
    if (permissionKey.contains('sensors')) return 'Sensores';
    if (permissionKey.contains('activityRecognition')) return 'Atividade Física';
    // Sentinela Permissions
    if (permissionKey.contains('systemAlertWindow')) return 'Tela Sobreposta';
    if (permissionKey.contains('phone')) return 'Telefone';
    if (permissionKey.contains('location')) return 'Localização';
    if (permissionKey.contains('sms')) return 'SMS Emergência';
    return 'Desconhecida';
  }

  IconData _getPermissionIcon(String permissionKey) {
    if (permissionKey == _healthPermissionKey) return Icons.health_and_safety;
    if (permissionKey.contains('microphone')) return Icons.mic;
    if (permissionKey.contains('camera')) return Icons.videocam;
    if (permissionKey.contains('notification')) return Icons.notifications;
    if (permissionKey.contains('ignoreBatteryOptimizations')) {
      return Icons.battery_charging_full;
    }
    if (permissionKey.contains('sensors')) return Icons.watch;
    if (permissionKey.contains('activityRecognition')) return Icons.favorite;
    // Sentinela Icons
    if (permissionKey.contains('systemAlertWindow')) return Icons.open_in_new;
    if (permissionKey.contains('phone')) return Icons.phone;
    if (permissionKey.contains('location')) return Icons.location_on;
    if (permissionKey.contains('sms')) return Icons.sms;
    return Icons.help;
  }

  List<String> _getAllPermissionKeys() {
    final keys = _requiredPermissions.map((p) => p.toString()).toList();
    keys.add(_healthPermissionKey);
    return keys;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFF1493), Color(0xFFFF69B4), Color(0xFFFFB6C1)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo
                Image.asset(
                  'assets/images/eva_transparent.png',
                  width: 150,
                  height: 150,
                ),
                const SizedBox(height: 32),

                // Título
                const Text(
                  'Permissões Necessárias',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 48),

                const SizedBox(height: 48),

                // Ícones das permissões (Visual apenas)
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 16,
                  runSpacing: 16,
                  children: _getAllPermissionKeys()
                      .where((key) => key != _healthPermissionKey)
                      .map((permissionKey) {
                    final isGranted = _permissionStatus[permissionKey] ?? false;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isGranted
                                ? Colors.white.withValues(alpha: 0.9)
                                : Colors.white.withValues(alpha: 0.3),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Icon(
                            _getPermissionIcon(permissionKey),
                            size: 26,
                            color: isGranted ? Colors.green : Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (isGranted)
                          const Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 18,
                          )
                        else
                          const SizedBox(height: 18),
                      ],
                    );
                  }).toList(),
                ),

                const SizedBox(height: 32),

                // Health Permission Card (Destaque especial)
                GestureDetector(
                  onTap: () async {
                    if (!(_permissionStatus[_healthPermissionKey] ?? false)) {
                      await _requestHealthPermission();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white,
                        width: _permissionStatus[_healthPermissionKey] ?? false ? 2 : 3,
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (_permissionStatus[_healthPermissionKey] ?? false)
                                ? Colors.white.withValues(alpha: 0.9)
                                : Colors.white.withValues(alpha: 0.4),
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: Icon(
                            Icons.health_and_safety,
                            size: 36,
                            color: (_permissionStatus[_healthPermissionKey] ?? false)
                                ? Colors.green
                                : Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Dados de Saúde',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (_permissionStatus[_healthPermissionKey] ?? false)
                          const Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 20,
                          )
                        else
                          Text(
                            'Toque para ativar',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // Botão Único de Ação
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isRequesting
                        ? null
                        : (_permissionStatus.values.every((granted) => granted)
                              ? _proceedIfAllGranted
                              : _requestAllPermissions),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: _isRequesting
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _permissionStatus.values.every((granted) => granted)
                                ? 'Continuar'
                                : 'Todas',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
