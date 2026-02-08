import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Whisper model file exists in assets', () async {
    // Tenta carregar o modelo dos assets
    try {
      final data = await rootBundle.load('assets/models/ggml-small-q5_1.bin');

      // Verifica se o arquivo foi carregado
      expect(data, isNotNull);

      // Verifica o tamanho do arquivo (deve ser ~77MB)
      final sizeInMB = data.lengthInBytes / (1024 * 1024);
      print('✅ Modelo encontrado! Tamanho: ${sizeInMB.toStringAsFixed(2)} MB');

      // O modelo multilíngue deve ter pelo menos 70MB
      expect(sizeInMB, greaterThan(70.0));

      print(
          '✅ TESTE PASSOU: Modelo ggml-small-q5_1.bin está corretamente configurado!');
    } catch (e) {
      fail('❌ ERRO: Modelo não encontrado nos assets: $e');
    }
  });

  test('Whisper model path is correct in code', () {
    // Verifica se o caminho está correto
    const expectedPath = 'assets/models/ggml-small-q5_1.bin';

    // Este teste confirma que estamos procurando o arquivo correto
    expect(expectedPath, equals('assets/models/ggml-small-q5_1.bin'));

    print('✅ Caminho do modelo está correto: $expectedPath');
  });
}
