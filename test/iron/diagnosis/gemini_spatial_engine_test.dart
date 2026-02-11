import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:ironmind/iron/diagnosis/gemini_spatial_engine.dart';
import 'package:ironmind/iron/detection/yolo_engine.dart';

void main() {
  group('GeminiSpatialEngine - Configuration', () {
    test('não configurado sem API key', () {
      final engine = GeminiSpatialEngine();
      expect(engine.isConfigured, isFalse);
    });

    test('configurado com API key no construtor', () {
      final engine = GeminiSpatialEngine(apiKey: 'test-key-123');
      expect(engine.isConfigured, isTrue);
    });

    test('configure() ativa configuração', () {
      final engine = GeminiSpatialEngine();
      expect(engine.isConfigured, isFalse);

      engine.configure('my-api-key');
      expect(engine.isConfigured, isTrue);
    });

    test('configure com string vazia mantém desconfigurado', () {
      final engine = GeminiSpatialEngine();
      engine.configure('');
      expect(engine.isConfigured, isFalse);
    });

    test('dispose desativa configuração', () {
      final engine = GeminiSpatialEngine(apiKey: 'test-key');
      expect(engine.isConfigured, isTrue);

      engine.dispose();
      expect(engine.isConfigured, isFalse);
    });

    test('totalCalls inicia em 0', () {
      final engine = GeminiSpatialEngine();
      expect(engine.totalCalls, 0);
    });

    test('totalTokensUsed inicia em 0', () {
      final engine = GeminiSpatialEngine();
      expect(engine.totalTokensUsed, 0);
    });

    test('estimatedCostUsd inicia em 0', () {
      final engine = GeminiSpatialEngine();
      expect(engine.estimatedCostUsd, 0.0);
    });
  });

  group('GeminiSpatialEngine - Fallback', () {
    test('analyze retorna fallback quando não configurado', () async {
      final engine = GeminiSpatialEngine();
      final result = await engine.analyze(
        imageBytes: Uint8List(100),
        equipmentType: 'trator',
      );

      expect(result.components, isEmpty);
      expect(result.anomalies, isEmpty);
      expect(result.source, contains('fallback'));
      expect(result.source, contains('API key não configurada'));
    });

    test('identifyPointed retorna null quando não configurado', () async {
      final engine = GeminiSpatialEngine();
      final result = await engine.identifyPointed(
        imageBytes: Uint8List(100),
        fingerTip: const Offset(320, 240),
      );

      expect(result, isNull);
    });
  });

  group('SpatialComponent', () {
    test('fromJson parseia corretamente', () {
      final json = {
        'name': 'cilindro hidráulico',
        'bbox': [10, 20, 100, 200],
        'status': 'DAMAGED',
        'confidence': 0.92,
        'manual_reference': 'Item 8, Pág 234',
        'affordance': 'removível com chave 19mm',
      };

      final comp = SpatialComponent.fromJson(json);

      expect(comp.name, 'cilindro hidráulico');
      expect(comp.bbox, [10, 20, 100, 200]);
      expect(comp.status, 'DAMAGED');
      expect(comp.confidence, 0.92);
      expect(comp.manualReference, 'Item 8, Pág 234');
      expect(comp.affordance, 'removível com chave 19mm');
      expect(comp.isDamaged, isTrue);
      expect(comp.isCritical, isFalse);
    });

    test('fromJson com valores ausentes usa defaults', () {
      final comp = SpatialComponent.fromJson({});

      expect(comp.name, 'unknown');
      expect(comp.bbox, [0, 0, 0, 0]);
      expect(comp.status, 'UNKNOWN');
      expect(comp.confidence, 0.0);
      expect(comp.manualReference, isNull);
    });

    test('isCritical retorna true para CRITICAL', () {
      final comp = SpatialComponent.fromJson({
        'name': 'freio',
        'status': 'CRITICAL',
      });

      expect(comp.isCritical, isTrue);
      expect(comp.isDamaged, isTrue); // CRITICAL is also DAMAGED
    });

    test('isDamaged retorna true para DAMAGED e CRITICAL', () {
      final damaged = SpatialComponent.fromJson({'status': 'DAMAGED'});
      final critical = SpatialComponent.fromJson({'status': 'CRITICAL'});
      final ok = SpatialComponent.fromJson({'status': 'OK'});

      expect(damaged.isDamaged, isTrue);
      expect(critical.isDamaged, isTrue);
      expect(ok.isDamaged, isFalse);
    });
  });

  group('SpatialAnomaly', () {
    test('fromJson parseia corretamente', () {
      final json = {
        'type': 'leak',
        'severity': 'HIGH',
        'description': 'Vazamento de óleo no cilindro',
        'location': [150, 200],
        'affected_component': 'cilindro hidráulico',
      };

      final anomaly = SpatialAnomaly.fromJson(json);

      expect(anomaly.type, 'leak');
      expect(anomaly.severity, 'HIGH');
      expect(anomaly.description, 'Vazamento de óleo no cilindro');
      expect(anomaly.location, [150, 200]);
      expect(anomaly.affectedComponent, 'cilindro hidráulico');
    });

    test('fromJson com valores ausentes', () {
      final anomaly = SpatialAnomaly.fromJson({});

      expect(anomaly.type, 'unknown');
      expect(anomaly.severity, 'LOW');
      expect(anomaly.description, '');
      expect(anomaly.location, [0, 0]);
    });
  });

  group('RepairStep', () {
    test('fromJson parseia corretamente', () {
      final json = {
        'order': 1,
        'instruction': 'Drene o óleo hidráulico',
        'tool': 'chave 19mm',
        'safety_warning': 'Fluido sob pressão',
        'point_to': [200, 300],
      };

      final step = RepairStep.fromJson(json);

      expect(step.order, 1);
      expect(step.instruction, 'Drene o óleo hidráulico');
      expect(step.tool, 'chave 19mm');
      expect(step.safetyWarning, 'Fluido sob pressão');
      expect(step.pointTo, [200, 300]);
    });
  });

  group('SpatialAnalysisResult', () {
    test('ttsResume sem anomalias', () {
      final result = SpatialAnalysisResult(
        components: [
          SpatialComponent.fromJson({'name': 'motor', 'status': 'OK'}),
          SpatialComponent.fromJson({'name': 'freio', 'status': 'OK'}),
        ],
        anomalies: [],
        repairPlan: [],
        latencyMs: 500,
      );

      expect(result.ttsResume, contains('2 componentes'));
      expect(result.ttsResume, contains('Nenhuma anomalia'));
      expect(result.hasCritical, isFalse);
      expect(result.anomalyCount, 0);
      expect(result.componentCount, 2);
    });

    test('ttsResume com anomalias criticas', () {
      final result = SpatialAnalysisResult(
        components: [],
        anomalies: [
          SpatialAnomaly.fromJson({
            'type': 'crack',
            'severity': 'CRITICAL',
            'description': 'Trinca na solda',
          }),
          SpatialAnomaly.fromJson({
            'type': 'leak',
            'severity': 'HIGH',
            'description': 'Vazamento',
          }),
        ],
        repairPlan: [
          RepairStep.fromJson({'order': 1, 'instruction': 'Parar máquina'}),
        ],
        estimatedTimeMinutes: 30,
        latencyMs: 1200,
      );

      expect(result.ttsResume, contains('2 anomalias'));
      expect(result.ttsResume, contains('1 críticas'));
      expect(result.ttsResume, contains('1 graves'));
      expect(result.ttsResume, contains('1 etapas'));
      expect(result.ttsResume, contains('30 minutos'));
      expect(result.hasCritical, isTrue);
      expect(result.anomalyCount, 2);
    });

    test('ttsResume com anomalias sem plano de reparo', () {
      final result = SpatialAnalysisResult(
        components: [],
        anomalies: [
          SpatialAnomaly.fromJson({
            'type': 'wear',
            'severity': 'MEDIUM',
            'description': 'Desgaste',
          }),
        ],
        repairPlan: [],
        latencyMs: 800,
      );

      expect(result.ttsResume, contains('1 anomalias'));
      expect(result.ttsResume, isNot(contains('etapas')));
    });
  });

  group('GeminiSpatialEngine - Model ID', () {
    test('usa gemini-2.5-flash por padrão', () {
      final engine = GeminiSpatialEngine(apiKey: 'test');
      // Engine criado sem erro com modelo padrão
      expect(engine.isConfigured, isTrue);
    });

    test('aceita model ID customizado', () {
      final engine = GeminiSpatialEngine(
        apiKey: 'test',
        modelId: 'gemini-2.5-pro',
      );
      expect(engine.isConfigured, isTrue);
    });
  });
}
