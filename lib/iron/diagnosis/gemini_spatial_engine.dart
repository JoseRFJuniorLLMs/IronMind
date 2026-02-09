import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../detection/yolo_engine.dart';

/// Componente identificado espacialmente pelo Gemini
class SpatialComponent {
  final String name;
  final List<int> bbox; // [x1, y1, x2, y2] pixels
  final String status; // OK, WORN, DAMAGED, CRITICAL, MISSING
  final double confidence;
  final String? manualReference; // "Item 8, Pág 234"
  final String? affordance; // "removível com chave 19mm"

  SpatialComponent({
    required this.name,
    required this.bbox,
    required this.status,
    required this.confidence,
    this.manualReference,
    this.affordance,
  });

  factory SpatialComponent.fromJson(Map<String, dynamic> json) {
    return SpatialComponent(
      name: json['name'] as String? ?? 'unknown',
      bbox: (json['bbox'] as List?)?.cast<int>() ?? [0, 0, 0, 0],
      status: json['status'] as String? ?? 'UNKNOWN',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      manualReference: json['manual_reference'] as String?,
      affordance: json['affordance'] as String?,
    );
  }

  bool get isCritical => status == 'CRITICAL';
  bool get isDamaged => status == 'DAMAGED' || status == 'CRITICAL';
}

/// Anomalia detectada pelo Gemini
class SpatialAnomaly {
  final String type; // leak, wear, corrosion, misalignment, crack
  final String severity; // LOW, MEDIUM, HIGH, CRITICAL
  final String description;
  final List<int> location; // [x, y] pixel do centro
  final String? affectedComponent;

  SpatialAnomaly({
    required this.type,
    required this.severity,
    required this.description,
    required this.location,
    this.affectedComponent,
  });

  factory SpatialAnomaly.fromJson(Map<String, dynamic> json) {
    return SpatialAnomaly(
      type: json['type'] as String? ?? 'unknown',
      severity: json['severity'] as String? ?? 'LOW',
      description: json['description'] as String? ?? '',
      location: (json['location'] as List?)?.cast<int>() ?? [0, 0],
      affectedComponent: json['affected_component'] as String?,
    );
  }
}

/// Passo de reparo gerado pelo Gemini
class RepairStep {
  final int order;
  final String instruction;
  final String? tool; // "chave 19mm", "torquímetro 45Nm"
  final String? safetyWarning;
  final List<int>? pointTo; // [x, y] para AR overlay

  RepairStep({
    required this.order,
    required this.instruction,
    this.tool,
    this.safetyWarning,
    this.pointTo,
  });

  factory RepairStep.fromJson(Map<String, dynamic> json) {
    return RepairStep(
      order: json['order'] as int? ?? 0,
      instruction: json['instruction'] as String? ?? '',
      tool: json['tool'] as String?,
      safetyWarning: json['safety_warning'] as String?,
      pointTo: (json['point_to'] as List?)?.cast<int>(),
    );
  }
}

/// Resultado completo da análise espacial Gemini
class SpatialAnalysisResult {
  final List<SpatialComponent> components;
  final List<SpatialAnomaly> anomalies;
  final List<RepairStep> repairPlan;
  final int estimatedTimeMinutes;
  final List<String> requiredTools;
  final List<String> safetyWarnings;
  final int latencyMs;
  final String source;

  SpatialAnalysisResult({
    required this.components,
    required this.anomalies,
    required this.repairPlan,
    this.estimatedTimeMinutes = 0,
    this.requiredTools = const [],
    this.safetyWarnings = const [],
    required this.latencyMs,
    this.source = 'Gemini Robotics-ER 1.5',
  });

  bool get hasCritical => anomalies.any((a) => a.severity == 'CRITICAL');
  int get anomalyCount => anomalies.length;
  int get componentCount => components.length;

  /// Resumo em português para TTS
  String get ttsResume {
    if (anomalies.isEmpty) {
      return 'Análise completa. ${components.length} componentes identificados. '
          'Nenhuma anomalia detectada.';
    }

    final critical = anomalies.where((a) => a.severity == 'CRITICAL').length;
    final high = anomalies.where((a) => a.severity == 'HIGH').length;

    final buf = StringBuffer('Análise completa. ');
    buf.write('${anomalies.length} anomalias encontradas');
    if (critical > 0) buf.write(', $critical críticas');
    if (high > 0) buf.write(', $high graves');
    buf.write('. ');

    if (repairPlan.isNotEmpty) {
      buf.write('Plano de reparo com ${repairPlan.length} etapas, '
          'tempo estimado $estimatedTimeMinutes minutos.');
    }

    return buf.toString();
  }
}

/// Gemini Robotics-ER 1.5 - Motor de Análise Espacial
///
/// TIER 2 do IronMind: chamado apenas quando operador toca "Analisar"
/// ou quando YOLO detecta defeito com confiança 0.50-0.75 (cloudFallback)
///
/// Capacidades:
/// - Coordenadas 2D pixel-perfect de cada componente
/// - Cross-reference com diagrama do manual técnico
/// - Decomposição em passos de reparo
/// - Affordance reasoning (o que pode ser apertado, girado, removido)
/// - Tool calling (search_manual, check_inventory)
/// - Thinking budget (fast preview vs deep analysis)
class GeminiSpatialEngine {
  final String _apiKey;
  final String _modelId;
  final String _baseUrl;

  bool _isConfigured = false;
  int _totalCalls = 0;
  int _totalTokensUsed = 0;

  GeminiSpatialEngine({
    String? apiKey,
    String modelId = 'gemini-2.5-flash',
    String baseUrl = 'https://generativelanguage.googleapis.com/v1beta',
  })  : _apiKey = apiKey ?? '',
        _modelId = modelId,
        _baseUrl = baseUrl;

  bool get isConfigured => _isConfigured && _apiKey.isNotEmpty;
  int get totalCalls => _totalCalls;
  int get totalTokensUsed => _totalTokensUsed;

  /// Configura com API key (carregada do .env)
  void configure(String apiKey) {
    _isConfigured = apiKey.isNotEmpty;
  }

  /// Análise espacial completa de um frame com defeito
  ///
  /// [imageBytes] - Frame da câmera (JPEG/PNG)
  /// [detections] - Detecções YOLO locais (para contexto)
  /// [equipmentType] - Tipo de equipamento ("trator", "escavadeira", etc.)
  /// [thinkingBudget] - "small" (~200ms), "medium" (~800ms), "large" (~2s)
  Future<SpatialAnalysisResult> analyze({
    required Uint8List imageBytes,
    List<Detection> detections = const [],
    String equipmentType = 'equipamento pesado',
    String thinkingBudget = 'medium',
    Uint8List? manualDiagram,
  }) async {
    if (!isConfigured) {
      return _fallbackResult('API key não configurada');
    }

    final stopwatch = Stopwatch()..start();

    try {
      // Montar contexto das detecções locais do YOLO
      final yoloContext = detections.isNotEmpty
          ? detections
              .map((d) =>
                  '${d.className} (${(d.confidence * 100).toInt()}%) em '
                  '[${d.bbox.xCenter.toStringAsFixed(2)}, ${d.bbox.yCenter.toStringAsFixed(2)}]')
              .join(', ')
          : 'nenhuma detecção prévia';

      final prompt = _buildPrompt(
        equipmentType: equipmentType,
        yoloContext: yoloContext,
        hasManualDiagram: manualDiagram != null,
        thinkingBudget: thinkingBudget,
      );

      // Montar request multimodal
      final parts = <Map<String, dynamic>>[
        {'text': prompt},
        {
          'inline_data': {
            'mime_type': 'image/jpeg',
            'data': base64Encode(imageBytes),
          }
        },
      ];

      // Adicionar diagrama do manual se disponível
      if (manualDiagram != null) {
        parts.add({
          'inline_data': {
            'mime_type': 'image/png',
            'data': base64Encode(manualDiagram),
          }
        });
      }

      final body = {
        'contents': [
          {
            'parts': parts,
          }
        ],
        'generationConfig': {
          'temperature': 0.1, // Determinístico para diagnóstico
          'topP': 0.8,
          'maxOutputTokens': 2048,
          'responseMimeType': 'application/json',
        },
        'safetySettings': [
          {
            'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
            'threshold': 'BLOCK_NONE', // Conteúdo industrial pode parecer "perigoso"
          }
        ],
      };

      final url = '$_baseUrl/models/$_modelId:generateContent?key=$_apiKey';
      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      stopwatch.stop();
      _totalCalls++;

      if (response.statusCode != 200) {
        debugPrint('[GeminiSpatial] API error ${response.statusCode}: '
            '${response.body.substring(0, 200)}');
        return _fallbackResult(
          'API error ${response.statusCode}',
          latencyMs: stopwatch.elapsedMilliseconds,
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      // Extrair texto da resposta
      final candidates = json['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        return _fallbackResult(
          'Sem resposta do modelo',
          latencyMs: stopwatch.elapsedMilliseconds,
        );
      }

      final content = candidates[0]['content'] as Map<String, dynamic>?;
      final resParts = content?['parts'] as List?;
      final text = resParts?.first['text'] as String? ?? '{}';

      // Registrar tokens usados
      final usageMetadata = json['usageMetadata'] as Map<String, dynamic>?;
      _totalTokensUsed +=
          (usageMetadata?['totalTokenCount'] as int?) ?? 0;

      // Parse JSON estruturado
      return _parseResponse(text, stopwatch.elapsedMilliseconds);
    } catch (e) {
      stopwatch.stop();
      debugPrint('[GeminiSpatial] Error: $e');
      return _fallbackResult(
        e.toString(),
        latencyMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  /// Pointing mode: mecânico aponta o dedo e Gemini identifica o componente
  Future<SpatialComponent?> identifyPointed({
    required Uint8List imageBytes,
    required Offset fingerTip,
    String equipmentType = 'equipamento pesado',
  }) async {
    if (!isConfigured) return null;

    try {
      final prompt = '''
Você é um técnico especialista em $equipmentType.

O operador está apontando o dedo para a posição aproximada
(${fingerTip.dx.toInt()}, ${fingerTip.dy.toInt()}) na imagem.

Identifique o componente mais próximo dessa posição.

OUTPUT (JSON):
{
  "name": "nome do componente",
  "bbox": [x1, y1, x2, y2],
  "status": "OK|WORN|DAMAGED|CRITICAL",
  "confidence": 0.0-1.0,
  "manual_reference": "referência no manual se souber",
  "affordance": "como interagir (apertar, girar, remover, etc.)"
}''';

      final body = {
        'contents': [
          {
            'parts': [
              {'text': prompt},
              {
                'inline_data': {
                  'mime_type': 'image/jpeg',
                  'data': base64Encode(imageBytes),
                }
              },
            ],
          }
        ],
        'generationConfig': {
          'temperature': 0.1,
          'maxOutputTokens': 512,
          'responseMimeType': 'application/json',
        },
      };

      final url = '$_baseUrl/models/$_modelId:generateContent?key=$_apiKey';
      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 5));

      _totalCalls++;

      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final text = (json['candidates'] as List?)
              ?.first['content']['parts']
              ?.first['text'] as String? ??
          '{}';

      final parsed = jsonDecode(text) as Map<String, dynamic>;
      return SpatialComponent.fromJson(parsed);
    } catch (e) {
      debugPrint('[GeminiSpatial] identifyPointed error: $e');
      return null;
    }
  }

  /// Monta o prompt do sistema para análise completa
  String _buildPrompt({
    required String equipmentType,
    required String yoloContext,
    required bool hasManualDiagram,
    required String thinkingBudget,
  }) {
    final diagramInstruction = hasManualDiagram
        ? '''
A Imagem 2 é o diagrama técnico do manual de serviço.
Cross-reference os componentes reais com os do diagrama.'''
        : 'Não há diagrama do manual disponível. Identifique os componentes pela experiência.';

    final depthInstruction = switch (thinkingBudget) {
      'small' => 'Análise rápida: identifique apenas defeitos óbvios.',
      'large' =>
        'Análise profunda: examine cada componente, verifique desgaste sutil, '
            'micro-trincas, desalinhamentos e desgaste irregular.',
      _ => 'Análise padrão: identifique componentes principais e anomalias visíveis.',
    };

    return '''
Você é um técnico certificado especialista em $equipmentType.

CONTEXTO:
- Detecções automáticas (YOLO): $yoloContext
- $diagramInstruction
- $depthInstruction

TAREFA:
Analise a Imagem 1 (foto real do campo) e produza:

1. MAPEAMENTO ESPACIAL:
   - Identifique cada componente visível com bounding box [x1,y1,x2,y2] em pixels
   - Status: OK, WORN (desgastado), DAMAGED (danificado), CRITICAL (crítico), MISSING (faltando)
   - Confidence score 0.0-1.0

2. ANOMALIAS:
   - Tipo: leak, wear, corrosion, misalignment, crack, missing_part
   - Severidade: LOW, MEDIUM, HIGH, CRITICAL
   - Localização [x, y] do centro

3. PLANO DE REPARO (se houver anomalias):
   - Passos ordenados logicamente
   - Ferramentas necessárias para cada passo
   - Avisos de segurança (pressão, temperatura, peso)
   - Coordenada [x, y] para apontar na tela (AR guidance)

OUTPUT (JSON estrito):
{
  "components": [
    {
      "name": "string",
      "bbox": [x1, y1, x2, y2],
      "status": "OK|WORN|DAMAGED|CRITICAL|MISSING",
      "confidence": 0.0-1.0,
      "manual_reference": "string ou null",
      "affordance": "string ou null"
    }
  ],
  "anomalies": [
    {
      "type": "string",
      "severity": "LOW|MEDIUM|HIGH|CRITICAL",
      "description": "string em português",
      "location": [x, y],
      "affected_component": "string ou null"
    }
  ],
  "repair_plan": {
    "steps": [
      {
        "order": 1,
        "instruction": "string em português",
        "tool": "string ou null",
        "safety_warning": "string ou null",
        "point_to": [x, y]
      }
    ],
    "estimated_time_minutes": 0,
    "required_tools": ["string"],
    "safety_warnings": ["string"]
  }
}''';
  }

  /// Parse da resposta JSON do Gemini
  SpatialAnalysisResult _parseResponse(String text, int latencyMs) {
    try {
      final json = jsonDecode(text) as Map<String, dynamic>;

      final components = (json['components'] as List?)
              ?.map((c) =>
                  SpatialComponent.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [];

      final anomalies = (json['anomalies'] as List?)
              ?.map(
                  (a) => SpatialAnomaly.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [];

      final repairPlan = json['repair_plan'] as Map<String, dynamic>?;
      final steps = (repairPlan?['steps'] as List?)
              ?.map(
                  (s) => RepairStep.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [];

      final tools = (repairPlan?['required_tools'] as List?)
              ?.cast<String>() ??
          [];
      final warnings = (repairPlan?['safety_warnings'] as List?)
              ?.cast<String>() ??
          [];
      final estimatedTime =
          repairPlan?['estimated_time_minutes'] as int? ?? 0;

      return SpatialAnalysisResult(
        components: components,
        anomalies: anomalies,
        repairPlan: steps,
        estimatedTimeMinutes: estimatedTime,
        requiredTools: tools,
        safetyWarnings: warnings,
        latencyMs: latencyMs,
      );
    } catch (e) {
      debugPrint('[GeminiSpatial] Parse error: $e');
      return _fallbackResult('Parse error: $e', latencyMs: latencyMs);
    }
  }

  /// Resultado fallback quando API não disponível
  SpatialAnalysisResult _fallbackResult(
    String reason, {
    int latencyMs = 0,
  }) {
    return SpatialAnalysisResult(
      components: [],
      anomalies: [],
      repairPlan: [],
      latencyMs: latencyMs,
      source: 'fallback ($reason)',
    );
  }

  /// Custo estimado em USD da sessão atual
  double get estimatedCostUsd {
    // Gemini 2.5 Flash: ~$0.15 per 1M input tokens
    return (_totalTokensUsed / 1000000) * 0.15;
  }

  void dispose() {
    _isConfigured = false;
  }
}
