import 'package:permission_handler/permission_handler.dart';
import '../../data/services/health_service.dart';

class AppPermissions {
  static Future<bool> requestCallPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.microphone,
      Permission.camera,
    ].request();

    return statuses[Permission.microphone]!.isGranted;
  }

  /// Solicita permissões de saúde (Health Connect/HealthKit)
  static Future<bool> requestHealthPermissions() async {
    final healthService = HealthService();
    return await healthService.requestPermissions();
  }

  /// Solicita todas as permissões necessárias para o app
  static Future<Map<String, bool>> requestAllPermissions() async {
    final results = <String, bool>{};

    // PASSO 1: Permissões básicas do sistema (sem sensores de saúde)
    final basicPermissions = await [
      Permission.microphone,
      Permission.camera,
      Permission.notification,
      Permission.ignoreBatteryOptimizations,
      Permission.systemAlertWindow,
      Permission.phone,
      Permission.location,
      Permission.sms,
    ].request();

    basicPermissions.forEach((permission, status) {
      results[permission.toString()] = status.isGranted;
    });

    // PASSO 2: Permissões de sensores corporais (CRÍTICO para Health Connect)
    final sensorsStatus = await Permission.sensors.request();
    results['sensors'] = sensorsStatus.isGranted;

    final activityStatus = await Permission.activityRecognition.request();
    results['activityRecognition'] = activityStatus.isGranted;

    // PASSO 3: Só solicitar Health Connect se as permissões de sensores foram concedidas
    if (sensorsStatus.isGranted && activityStatus.isGranted) {
      results['health'] = await requestHealthPermissions();
    } else {
      results['health'] = false;
      print('⚠️ Permissões de sensores não concedidas. Health Connect ignorado.');
    }

    return results;
  }
}
