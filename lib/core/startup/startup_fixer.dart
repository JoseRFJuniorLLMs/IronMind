import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_api_availability/google_api_availability.dart';
import 'package:health/health.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:url_launcher/url_launcher.dart';

/// Serviço que verifica e corrige problemas automaticamente na inicialização
/// Pensado para usuários idosos que não conseguem resolver problemas técnicos
class StartupFixer {
  static final StartupFixer _instance = StartupFixer._internal();
  factory StartupFixer() => _instance;
  StartupFixer._internal();

  /// Executa todas as verificações e correções necessárias
  /// Retorna true se tudo está OK, false se há problemas críticos
  Future<bool> runAllChecks(BuildContext context) async {
    // 1. Verificar e corrigir Google Play Services
    final playServicesOk = await _checkAndFixPlayServices(context);
    if (!playServicesOk) return false;

    // 2. Verificar e solicitar permissões do Health Connect
    await _checkAndRequestHealthPermissions(context);

    // 3. Tentar obter FCM Token (com retry)
    await _ensureFcmToken(context);

    return true;
  }

  /// Verifica Google Play Services e tenta corrigir automaticamente
  Future<bool> _checkAndFixPlayServices(BuildContext context) async {
    try {
      final availability = await GoogleApiAvailability.instance
          .checkGooglePlayServicesAvailability();

      if (availability == GooglePlayServicesAvailability.success) {
        return true;
      }

      // Mostrar dialog amigável e tentar corrigir
      if (context.mounted) {
        final shouldFix = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 32),
                SizedBox(width: 12),
                Text('Atualização Necessária'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'O EVA precisa que o Google Play Services esteja atualizado para funcionar corretamente.',
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 16),
                Text(
                  'Vou abrir a atualização para você. É rápido!',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Depois'),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(ctx, true),
                icon: Icon(Icons.update),
                label: Text('Atualizar Agora'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        );

        if (shouldFix == true) {
          // Tenta abrir a atualização do Google Play Services
          await GoogleApiAvailability.instance
              .makeGooglePlayServicesAvailable();

          // Aguarda um pouco e verifica novamente
          await Future.delayed(Duration(seconds: 2));
          final newStatus = await GoogleApiAvailability.instance
              .checkGooglePlayServicesAvailability();

          return newStatus == GooglePlayServicesAvailability.success;
        }
      }

      return false;
    } catch (e) {
      print('❌ Erro ao verificar Play Services: $e');
      // Em caso de erro, assume que está OK para não bloquear
      return true;
    }
  }

  /// Verifica e solicita permissões do Health Connect
  Future<void> _checkAndRequestHealthPermissions(BuildContext context) async {
    try {
      final health = Health();

      // Verificar se Health Connect está disponível
      final isAvailable = await health.hasPermissions(
        [HealthDataType.STEPS],
        permissions: [HealthDataAccess.READ],
      );

      // Se já tem permissões, OK
      if (isAvailable == true) return;

      // Verificar status do Health Connect
      final status = await health.getHealthConnectSdkStatus();

      if (status == HealthConnectSdkStatus.sdkUnavailable) {
        // Health Connect não instalado - oferecer instalação
        if (context.mounted) {
          await _showHealthConnectInstallDialog(context);
        }
        return;
      }

      // Health Connect disponível mas sem permissões - solicitar
      if (context.mounted) {
        final shouldRequest = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.favorite, color: Colors.red, size: 32),
                SizedBox(width: 12),
                Expanded(child: Text('Permissões de Saúde')),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Para monitorar sua saúde, o EVA precisa acessar seus dados do Health Connect.',
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 12),
                Text(
                  'Isso permite que eu acompanhe:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                _buildHealthItem(Icons.directions_walk, 'Passos diários'),
                _buildHealthItem(Icons.favorite, 'Frequência cardíaca'),
                _buildHealthItem(Icons.bedtime, 'Qualidade do sono'),
                _buildHealthItem(Icons.monitor_weight, 'Peso e medidas'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Agora não'),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(ctx, true),
                icon: Icon(Icons.check),
                label: Text('Permitir'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        );

        if (shouldRequest == true) {
          // Solicitar permissões do Health Connect
          final types = [
            HealthDataType.STEPS,
            HealthDataType.HEART_RATE,
            HealthDataType.SLEEP_ASLEEP,
            HealthDataType.WEIGHT,
            HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
            HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
            HealthDataType.BLOOD_GLUCOSE,
            HealthDataType.BLOOD_OXYGEN,
          ];

          final permissions = types.map((e) => HealthDataAccess.READ).toList();

          try {
            await health.requestAuthorization(types, permissions: permissions);
          } catch (e) {
            print('⚠️ Erro ao solicitar permissões Health: $e');
            // Tentar abrir Health Connect diretamente
            await _openHealthConnectSettings();
          }
        }
      }
    } catch (e) {
      print('❌ Erro ao verificar Health Connect: $e');
    }
  }

  Widget _buildHealthItem(IconData icon, String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          SizedBox(width: 8),
          Text(text, style: TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Future<void> _showHealthConnectInstallDialog(BuildContext context) async {
    final shouldInstall = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.health_and_safety, color: Colors.blue, size: 32),
            SizedBox(width: 12),
            Expanded(child: Text('Health Connect')),
          ],
        ),
        content: Text(
          'Para monitorar sua saúde, instale o app "Health Connect" da Google. É gratuito e seguro!',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Depois'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: Icon(Icons.download),
            label: Text('Instalar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (shouldInstall == true) {
      // Abrir Play Store na página do Health Connect
      final uri = Uri.parse(
        'https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata'
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  Future<void> _openHealthConnectSettings() async {
    try {
      // Tentar abrir configurações do Health Connect
      const platform = MethodChannel('com.eva.br/health_connect');
      await platform.invokeMethod('openHealthConnectSettings');
    } catch (e) {
      // Fallback: abrir Health Connect app
      final uri = Uri.parse('package:com.google.android.apps.healthdata');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  }

  /// Tenta obter FCM Token com retry automático
  Future<void> _ensureFcmToken(BuildContext context) async {
    try {
      final messaging = FirebaseMessaging.instance;

      // Solicitar permissão de notificações
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        // Usuário negou notificações
        return;
      }

      // Tentar obter token com retry
      String? token;
      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          token = await messaging.getToken();
          if (token != null && token.isNotEmpty) {
            print('✅ FCM Token obtido na tentativa $attempt');
            break;
          }
        } catch (e) {
          print('⚠️ Tentativa $attempt de obter FCM token falhou: $e');
          if (attempt < 3) {
            await Future.delayed(Duration(seconds: 2 * attempt));
          }
        }
      }

      if (token == null) {
        print('⚠️ Não foi possível obter FCM token após 3 tentativas');
        // Não bloqueia o app, apenas loga
      }
    } catch (e) {
      print('❌ Erro ao configurar FCM: $e');
    }
  }

  /// Limpa caches do app (útil para resolver problemas)
  Future<void> clearAppCaches() async {
    try {
      // Limpar cache de imagens
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      print('✅ Caches limpos');
    } catch (e) {
      print('⚠️ Erro ao limpar caches: $e');
    }
  }
}
