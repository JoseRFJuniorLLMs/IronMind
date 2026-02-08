import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Verifica se google-services.json existe e é válido', () async {
    final file = File('android/app/google-services.json');

    // 1. Verifica existência
    expect(file.existsSync(), isTrue,
        reason: 'Arquivo google-services.json NÃO encontrado em android/app/');

    // 2. Lê conteúdo
    final content = await file.readAsString();
    expect(content.isNotEmpty, isTrue, reason: 'Arquivo está vazio');

    // 3. Verifica JSON válido
    final Map<String, dynamic> json = jsonDecode(content);

    // 4. Verifica campos críticos
    expect(json.containsKey('project_info'), isTrue);
    expect(json['project_info']['project_id'], equals('eva-push-01'));

    final client = json['client'][0];
    final clientInfo = client['client_info'];
    final androidInfo = clientInfo['android_client_info'];

    // 5. Verifica Package Name
    expect(androidInfo['package_name'], equals('com.eva.br'),
        reason: 'Package name incorreto no JSON');

    print('✅ SUCESSO: google-services.json encontrado e validado!');
    print('   Project ID: ${json['project_info']['project_id']}');
    print('   Package: ${androidInfo['package_name']}');
  });
}
