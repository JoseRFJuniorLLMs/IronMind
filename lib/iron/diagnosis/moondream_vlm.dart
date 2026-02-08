import 'dart:typed_data';

/// Resultado do diagnóstico por VLM
class DiagnosticResult {
  final String description;
  final int latencyMs;
  final double confidence;
  final String source;

  DiagnosticResult({
    required this.description,
    required this.latencyMs,
    this.confidence = 0.0,
    this.source = 'Moondream',
  });
}

/// Moondream 0.5B - Vision-Language Model para diagnóstico offline
///
/// 187MB INT8, 450ms latência, ONNX + NNAPI
/// Lazy-loaded: só carrega quando operador pede diagnóstico
/// Descarrega após 30s de inatividade para liberar ~500MB RAM
class MoondreamDiagnostic {
  dynamic _session;
  // dynamic _tokenizer;
  bool _isLoaded = false;
  DateTime? _lastUsed;

  static const int imageSize = 378;
  static const int maxTokens = 100;
  static const int _unloadAfterSeconds = 30;

  bool get isLoaded => _isLoaded;

  /// Lazy load - carrega modelo ONNX em ~1s
  Future<void> ensureLoaded() async {
    if (_isLoaded) return;

    // TODO: Implementar com onnxruntime_flutter
    // final modelBytes = await rootBundle.load(
    //   'assets/models/vlm/moondream_0.5b_int8.onnx');
    // _session = OrtSession.fromBuffer(
    //   modelBytes.buffer.asUint8List(),
    //   OrtSessionOptions()..appendExecutionProvider_Nnapi());
    // _tokenizer = await Tokenizer.fromAsset('assets/tokenizers/moondream.json');

    _isLoaded = true;
    _lastUsed = DateTime.now();
  }

  /// Descarrega para liberar ~500MB RAM
  Future<void> unload() async {
    if (!_isLoaded) return;
    // _session?.release();
    _session = null;
    _isLoaded = false;
  }

  /// Verifica se deve descarregar por inatividade
  bool shouldUnload() {
    if (!_isLoaded || _lastUsed == null) return false;
    return DateTime.now().difference(_lastUsed!).inSeconds > _unloadAfterSeconds;
  }

  /// Diagnostica um defeito em linguagem natural
  ///
  /// [imageBytes] - Crop da região com defeito
  /// [question] - Pergunta em português
  ///
  /// Retorna texto descritivo: "Correia com fissuras laterais, 70% desgaste"
  Future<DiagnosticResult> diagnose(
    Uint8List imageBytes,
    String question,
  ) async {
    await ensureLoaded();
    _lastUsed = DateTime.now();

    final startTime = DateTime.now();

    // 1. Pré-processar imagem (378×378 para Moondream)
    final processedImage = _preprocessImage(imageBytes);

    // 2. Tokenizar pergunta em português
    final prompt =
        '<|im_start|>user\n<image>\n$question<|im_end|>\n<|im_start|>assistant\n';
    // final tokens = _tokenizer.encode(prompt);

    // 3. Inferência ONNX (450ms)
    // TODO: Implementar inferência real
    // final inputIds = OrtValueTensor.createTensorWithDataList(
    //   tokens.map((t) => t.toDouble()).toList(), [1, tokens.length]);
    // final pixelValues = OrtValueTensor.createTensorWithDataList(
    //   processedImage.toList(), [1, 3, imageSize, imageSize]);
    //
    // final outputs = await _session.runAsync(OrtRunOptions(), {
    //   'input_ids': inputIds,
    //   'pixel_values': pixelValues
    // });
    //
    // final logits = outputs[0]?.value as List<List<List<double>>>;
    // final generatedTokens = _sample(logits[0], maxTokens: maxTokens);
    // final response = _tokenizer.decode(generatedTokens);

    final response = 'Diagnóstico pendente - modelo ainda não carregado';

    final latency = DateTime.now().difference(startTime).inMilliseconds;

    return DiagnosticResult(
      description: response,
      latencyMs: latency,
      confidence: 0.0,
      source: 'Moondream 0.5B (offline)',
    );
  }

  /// Prompts pré-definidos para diagnóstico industrial
  static const Map<String, String> diagnosticPrompts = {
    'defect': 'Descreva o defeito visível nesta peça mecânica e sua gravidade.',
    'compare':
        'Compare esta peça com uma peça em bom estado. Quais as diferenças?',
    'severity':
        'Qual a severidade do dano? Classifique: leve, moderado, grave ou crítico.',
    'action':
        'Qual ação recomendada? Substituir, reparar, monitorar ou aprovar?',
    'identify': 'Identifique esta peça mecânica e seu estado atual.',
    'explain': 'Explique em detalhes por que esta peça foi reprovada.',
  };

  Float32List _preprocessImage(Uint8List imageBytes) {
    // Decode → Resize 378x378 → CHW → Normalize [0,1]
    // TODO: implementar com package:image
    return Float32List(3 * imageSize * imageSize);
  }

  void dispose() {
    unload();
  }
}
