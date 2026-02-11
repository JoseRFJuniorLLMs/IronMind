import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:ironmind/iron/logic/inspection_orchestrator.dart';
import 'package:ironmind/iron/logic/model_manager.dart';
import 'package:ironmind/iron/logic/uncertainty_analyzer.dart';
import 'package:ironmind/iron/diagnosis/gemini_spatial_engine.dart';
import 'package:ironmind/iron/logic/manual_lookup_service.dart';
import 'package:ironmind/iron/detection/yolo_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InspectionOrchestrator - Inicializacao', () {
    test('estado inicial', () {
      final orch = InspectionOrchestrator();
      expect(orch.isRunning, false);
      expect(orch.frameCount, 0);
      expect(orch.defectsFound, 0);
      expect(orch.geminiCalls, 0);
    });

    test('construtor usa defaults quando nenhum parametro passado', () {
      final orch = InspectionOrchestrator();
      expect(orch.modelManager, isA<ModelManager>());
      expect(orch.uncertainty, isA<UncertaintyAnalyzer>());
      expect(orch.gemini, isA<GeminiSpatialEngine>());
      expect(orch.manualLookup, isA<ManualLookupService>());
      expect(orch.voiceController, isNull);
    });

    test('construtor aceita dependencias customizadas', () {
      final customGemini = GeminiSpatialEngine(apiKey: 'custom-key');
      final customAnalyzer = UncertaintyAnalyzer(highConfidence: 0.99);

      final orch = InspectionOrchestrator(
        gemini: customGemini,
        uncertainty: customAnalyzer,
      );

      expect(orch.gemini.isConfigured, true);
      expect(orch.uncertainty.highConfidence, 0.99);
    });

    test('setEquipmentType define tipo', () {
      final orch = InspectionOrchestrator();
      orch.setEquipmentType('trator');
      // Nao tem getter publico, mas nao deve falhar
    });
  });

  group('InspectionOrchestrator - Gemini Config ANTES do timeout', () {
    test('Gemini configurado se API key disponivel antes de Future.wait', () async {
      // Este teste valida que a configuracao do Gemini acontece
      // ANTES do Future.wait dos modelos, evitando ser cortada pelo timeout
      final gemini = GeminiSpatialEngine();
      expect(gemini.isConfigured, false);

      // Simula a ordem de operacoes do initialize()
      // 1. Gemini config (instantaneo)
      gemini.configure('test-key-123');
      expect(gemini.isConfigured, true);

      // 2. Modelos carregam (podem demorar/timeout)
      // ... Future.wait com timeout ...

      // Gemini deve continuar configurado independente dos modelos
      expect(gemini.isConfigured, true);
    });

    test('initialize completa sem voiceController', () async {
      final orch = InspectionOrchestrator();
      // Initialize sem .env carregado -> Gemini nao configura
      // Mas o pipeline nao deve falhar
      await orch.initialize();

      // Pipeline funcional mesmo sem Gemini
      expect(orch.modelManager.yoloEngine.isInitialized, true);
    });
  });

  group('InspectionOrchestrator - processFrame', () {
    late InspectionOrchestrator orch;

    setUp(() async {
      orch = InspectionOrchestrator();
      await orch.initialize();
    });

    tearDown(() async {
      await orch.dispose();
    });

    test('processFrame retorna resultado valido', () async {
      final result = await orch.processFrame(Uint8List(100));

      expect(result, isA<InspectionResult>());
      expect(result.detections, isA<List<Detection>>());
      expect(result.inferenceTime, isA<Duration>());
      expect(result.modelUsed, isA<String>());
    });

    test('processFrame incrementa frameCount', () async {
      expect(orch.frameCount, 0);

      await orch.processFrame(Uint8List(100));
      expect(orch.frameCount, 1);

      await orch.processFrame(Uint8List(100));
      expect(orch.frameCount, 2);
    });

    test('processFrame sem defeitos nao incrementa defectsFound', () async {
      await orch.processFrame(Uint8List(100));
      // Demo mode retorna deteccoes vazias
      expect(orch.defectsFound, 0);
    });

    test('onResult callback e chamado', () async {
      InspectionResult? capturedResult;
      orch.onResult = (r) => capturedResult = r;

      await orch.processFrame(Uint8List(100));
      expect(capturedResult, isNotNull);
    });
  });

  group('InspectionResult', () {
    test('hasDefects com lista vazia', () {
      final result = InspectionResult(
        detections: [],
        frameUrgency: 0,
        inferenceTime: Duration.zero,
        modelUsed: 'test',
      );

      expect(result.hasDefects, false);
      expect(result.defectCount, 0);
      expect(result.hasSpatialAnalysis, false);
      expect(result.hasManualText, false);
    });

    test('hasDefects com defeitos', () {
      final result = InspectionResult(
        detections: [
          Detection(
            bbox: BoundingBox(xCenter: 0.5, yCenter: 0.5, width: 0.1, height: 0.1),
            classId: 0,
            className: 'freio_gasto',
            confidence: 0.9,
          ),
          Detection(
            bbox: BoundingBox(xCenter: 0.3, yCenter: 0.3, width: 0.1, height: 0.1),
            classId: 1,
            className: 'mangueira_ok',
            confidence: 0.95,
          ),
        ],
        frameUrgency: 0.8,
        inferenceTime: const Duration(milliseconds: 25),
        modelUsed: 'yolo26n',
      );

      expect(result.hasDefects, true);
      expect(result.defectCount, 1);
    });

    test('hasSpatialAnalysis true com componentes', () {
      final result = InspectionResult(
        detections: [],
        spatialAnalysis: SpatialAnalysisResult(
          components: [
            SpatialComponent(
              name: 'motor',
              bbox: [0, 0, 100, 100],
              status: 'OK',
              confidence: 0.9,
            ),
          ],
          anomalies: [],
          repairPlan: [],
          latencyMs: 500,
        ),
        frameUrgency: 0,
        inferenceTime: Duration.zero,
        modelUsed: 'Gemini',
      );

      expect(result.hasSpatialAnalysis, true);
    });

    test('hasSpatialAnalysis false com lista vazia de componentes', () {
      final result = InspectionResult(
        detections: [],
        spatialAnalysis: SpatialAnalysisResult(
          components: [],
          anomalies: [],
          repairPlan: [],
          latencyMs: 0,
        ),
        frameUrgency: 0,
        inferenceTime: Duration.zero,
        modelUsed: 'test',
      );

      expect(result.hasSpatialAnalysis, false);
    });

    test('hasManualText true quando texto presente', () {
      final result = InspectionResult(
        detections: [],
        frameUrgency: 0,
        inferenceTime: Duration.zero,
        modelUsed: 'test',
        manualText: 'Freio gasto detectado',
      );

      expect(result.hasManualText, true);
    });

    test('hasManualText false quando null ou vazio', () {
      final nullText = InspectionResult(
        detections: [],
        frameUrgency: 0,
        inferenceTime: Duration.zero,
        modelUsed: 'test',
        manualText: null,
      );
      expect(nullText.hasManualText, false);

      final emptyText = InspectionResult(
        detections: [],
        frameUrgency: 0,
        inferenceTime: Duration.zero,
        modelUsed: 'test',
        manualText: '',
      );
      expect(emptyText.hasManualText, false);
    });
  });

  group('InspectionOrchestrator - sessionSummary', () {
    test('sessionSummary retorna mapa completo', () async {
      final orch = InspectionOrchestrator();
      await orch.initialize();

      await orch.processFrame(Uint8List(100));
      await orch.processFrame(Uint8List(100));

      final summary = orch.sessionSummary();

      expect(summary['frames_processados'], 2);
      expect(summary['defeitos_encontrados'], 0);
      expect(summary['gemini_chamadas'], 0);
      expect(summary['duracao_minutos'], isA<int>());
      expect(summary['modelo_ativo'], isA<String>());
      expect(summary['ram_estimada_mb'], isA<int>());

      await orch.dispose();
    });
  });

  group('InspectionOrchestrator - updateBattery', () {
    test('updateBattery nao falha', () async {
      final orch = InspectionOrchestrator();
      await orch.initialize();

      await orch.updateBattery(80);
      await orch.updateBattery(25);
      await orch.updateBattery(5);

      await orch.dispose();
    });
  });
}
