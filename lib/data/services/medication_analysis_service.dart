import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import '../../core/config/app_config.dart';

/// Serviço de análise de medicamentos usando Gemini Vision
/// Identifica medicamentos pela imagem e fala informações sobre eles
class MedicationAnalysisService {
  static final MedicationAnalysisService _instance = MedicationAnalysisService._internal();
  factory MedicationAnalysisService() => _instance;
  MedicationAnalysisService._internal();

  final FlutterTts _tts = FlutterTts();
  bool _ttsInitialized = false;

  // Cache simples para evitar chamadas repetidas
  final Map<String, MedicationAnalysisResult> _cache = {};

  Future<void> _initTts() async {
    if (_ttsInitialized) return;

    await _tts.setLanguage('pt-BR');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _ttsInitialized = true;
  }

  /// Analisa uma imagem de medicamento usando Gemini Vision
  /// Retorna informações estruturadas sobre o medicamento
  Future<MedicationAnalysisResult> analyzeImage(Uint8List imageBytes) async {
    try {
      final apiKey = AppConfig.geminiApiKey;
      if (apiKey.isEmpty) {
        return MedicationAnalysisResult.error('API Key não configurada. Adicione GEMINI_API_KEY no .env');
      }

      final base64Image = base64Encode(imageBytes);

      // Verificar cache (usando hash simplificado dos primeiros bytes)
      final cacheKey = '${imageBytes.length}_${imageBytes.take(100).fold(0, (a, b) => a + b)}';
      if (_cache.containsKey(cacheKey)) {
        print('✅ Usando resultado do cache');
        return _cache[cacheKey]!;
      }

      // Tentar com retry para erros 429 (rate limit)
      final response = await _makeRequestWithRetry(apiKey, base64Image);

      if (response == null) {
        return MedicationAnalysisResult.error('Servidor ocupado. Tente novamente em alguns segundos.');
      }

      if (response.statusCode != 200) {
        print('❌ Gemini API error: ${response.statusCode} - ${response.body}');
        if (response.statusCode == 429) {
          return MedicationAnalysisResult.error('Muitas requisições. Aguarde alguns segundos e tente novamente.');
        }
        return MedicationAnalysisResult.error('Erro na API: ${response.statusCode}');
      }

      final jsonResponse = jsonDecode(response.body);
      final text = jsonResponse['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';

      // Limpar resposta (remover markdown se houver)
      String cleanJson = text.trim();
      if (cleanJson.startsWith('```json')) {
        cleanJson = cleanJson.substring(7);
      }
      if (cleanJson.startsWith('```')) {
        cleanJson = cleanJson.substring(3);
      }
      if (cleanJson.endsWith('```')) {
        cleanJson = cleanJson.substring(0, cleanJson.length - 3);
      }
      cleanJson = cleanJson.trim();

      final data = jsonDecode(cleanJson);

      MedicationAnalysisResult result;
      if (data['identified'] == true) {
        result = MedicationAnalysisResult(
          identified: true,
          name: data['name'] ?? 'Não identificado',
          activePrinciple: data['active_principle'],
          dosage: data['dosage'],
          type: data['type'],
          manufacturer: data['manufacturer'],
          usage: data['usage'],
          warnings: (data['warnings'] as List?)?.cast<String>() ?? [],
          instructions: data['instructions'],
          sideEffects: (data['side_effects'] as List?)?.cast<String>() ?? [],
          interactions: (data['interactions'] as List?)?.cast<String>() ?? [],
          confidence: (data['confidence'] ?? 0.8).toDouble(),
        );
      } else {
        result = MedicationAnalysisResult.notFound(data['reason'] ?? 'Não foi possível identificar');
      }

      // Guardar no cache
      _cache[cacheKey] = result;

      return result;
    } catch (e) {
      print('❌ Erro ao analisar medicamento: $e');
      return MedicationAnalysisResult.error('Erro: $e');
    }
  }

  /// Faz requisição com retry automático para erros 429
  Future<http.Response?> _makeRequestWithRetry(String apiKey, String base64Image) async {
    const maxRetries = 3;
    const baseDelaySeconds = 2;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('📡 Tentativa $attempt de $maxRetries...');

        final response = await http.post(
          Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {
                    'text': '''Analise esta imagem de medicamento e PESQUISE NA INTERNET informações atualizadas sobre ele.

Retorne APENAS um JSON válido com as seguintes informações:
{
  "identified": true/false,
  "name": "nome do medicamento",
  "active_principle": "princípio ativo",
  "dosage": "dosagem encontrada na embalagem",
  "type": "comprimido/cápsula/líquido/pomada/outro",
  "manufacturer": "fabricante se visível",
  "usage": "para que serve (pesquise na bula oficial)",
  "warnings": ["lista de contraindicações e avisos importantes da bula"],
  "instructions": "como tomar (posologia da bula)",
  "side_effects": ["efeitos colaterais mais comuns"],
  "interactions": ["interações medicamentosas importantes"],
  "confidence": 0.0 a 1.0
}

Se não conseguir identificar, retorne: {"identified": false, "reason": "motivo"}

IMPORTANTE:
- Use o Google Search para buscar informações da bula oficial
- Retorne APENAS o JSON, sem markdown ou texto adicional.'''
                  },
                  {
                    'inline_data': {
                      'mime_type': 'image/jpeg',
                      'data': base64Image
                    }
                  }
                ]
              }
            ],
            'tools': [
              {
                'google_search': {}
              }
            ],
            'generationConfig': {
              'temperature': 0.2,
              'maxOutputTokens': 2048,
            }
          }),
        );

        // Se não for 429, retorna (sucesso ou outro erro)
        if (response.statusCode != 429) {
          return response;
        }

        // Erro 429 - aguardar e tentar novamente
        final delay = baseDelaySeconds * attempt;
        print('⏳ Rate limit (429). Aguardando ${delay}s antes de tentar novamente...');
        await Future.delayed(Duration(seconds: delay));

      } catch (e) {
        print('❌ Erro na tentativa $attempt: $e');
        if (attempt == maxRetries) {
          rethrow;
        }
        await Future.delayed(Duration(seconds: baseDelaySeconds));
      }
    }

    return null;
  }

  /// Fala informações sobre o medicamento usando TTS
  Future<void> speakMedicationInfo(MedicationAnalysisResult result) async {
    await _initTts();

    if (!result.identified) {
      await _tts.speak('Não consegui identificar o medicamento. Por favor, tente novamente com melhor iluminação.');
      return;
    }

    // Construir texto para falar
    final buffer = StringBuffer();

    buffer.write('Medicamento identificado: ${result.name}. ');

    if (result.activePrinciple != null && result.activePrinciple!.isNotEmpty) {
      buffer.write('Princípio ativo: ${result.activePrinciple}. ');
    }

    if (result.dosage != null && result.dosage!.isNotEmpty) {
      buffer.write('Dosagem: ${result.dosage}. ');
    }

    if (result.usage != null && result.usage!.isNotEmpty) {
      buffer.write('Indicação: ${result.usage}. ');
    }

    if (result.instructions != null && result.instructions!.isNotEmpty) {
      buffer.write('Como tomar: ${result.instructions}. ');
    }

    if (result.warnings.isNotEmpty) {
      buffer.write('Atenção: ${result.warnings.first}. ');
    }

    if (result.sideEffects.isNotEmpty) {
      buffer.write('Efeitos colaterais comuns: ${result.sideEffects.take(2).join(", ")}. ');
    }

    if (result.interactions.isNotEmpty) {
      buffer.write('Cuidado com interações: ${result.interactions.first}. ');
    }

    await _tts.speak(buffer.toString());
  }

  /// Para a fala atual
  Future<void> stopSpeaking() async {
    await _tts.stop();
  }

  /// Limpa o cache
  void clearCache() {
    _cache.clear();
  }
}

/// Resultado da análise de medicamento
class MedicationAnalysisResult {
  final bool identified;
  final String name;
  final String? activePrinciple;
  final String? dosage;
  final String? type;
  final String? manufacturer;
  final String? usage;
  final List<String> warnings;
  final String? instructions;
  final List<String> sideEffects;
  final List<String> interactions;
  final double confidence;
  final String? errorMessage;
  final bool isError;

  MedicationAnalysisResult({
    required this.identified,
    required this.name,
    this.activePrinciple,
    this.dosage,
    this.type,
    this.manufacturer,
    this.usage,
    this.warnings = const [],
    this.instructions,
    this.sideEffects = const [],
    this.interactions = const [],
    this.confidence = 0.0,
    this.errorMessage,
    this.isError = false,
  });

  factory MedicationAnalysisResult.error(String message) {
    return MedicationAnalysisResult(
      identified: false,
      name: 'Erro',
      errorMessage: message,
      isError: true,
    );
  }

  factory MedicationAnalysisResult.notFound(String reason) {
    return MedicationAnalysisResult(
      identified: false,
      name: 'Não identificado',
      errorMessage: reason,
    );
  }
}
