import 'package:flutter_test/flutter_test.dart';
import 'package:ironmind/iron/logic/model_manager.dart';

void main() {
  group('ModelManager', () {
    late ModelManager manager;

    setUp(() {
      manager = ModelManager();
    });

    tearDown(() async {
      await manager.dispose();
    });

    test('RAM estimada inicia em 0', () {
      expect(manager.estimatedRAMUsage, 0);
    });

    test('initialize carrega modelos (modo demo)', () async {
      await manager.initialize();

      // YOLO cai em demo mode, YAMNet inicializa stub
      expect(manager.yoloEngine.isInitialized, isTrue);
      expect(manager.yamnet.isInitialized, isTrue);
    });

    test('initialize é idempotente', () async {
      await manager.initialize();
      await manager.initialize(); // segunda chamada não faz nada
      expect(manager.yoloEngine.isInitialized, isTrue);
    });

    test('dispose reseta estado', () async {
      await manager.initialize();
      await manager.dispose();

      expect(manager.yoloEngine.isInitialized, isFalse);
      expect(manager.yamnet.isInitialized, isFalse);
    });

    test('edgeSAM inicia descarregado', () {
      expect(manager.edgeSAM.isLoaded, isFalse);
    });

    test('ensureEdgeSAM carrega em modo full', () async {
      // modo full por padrão
      await manager.ensureEdgeSAM();
      expect(manager.edgeSAM.isLoaded, isTrue);
    });

    test('ensureEdgeSAM bloqueado em modo economy', () async {
      await manager.updateBatteryMode(25); // economy mode
      await manager.ensureEdgeSAM();
      expect(manager.edgeSAM.isLoaded, isFalse);
    });

    test('ensureEdgeSAM bloqueado em modo critical', () async {
      await manager.updateBatteryMode(5); // critical mode
      await manager.ensureEdgeSAM();
      expect(manager.edgeSAM.isLoaded, isFalse);
    });
  });

  group('Battery Mode', () {
    late ModelManager manager;

    setUp(() {
      manager = ModelManager();
    });

    tearDown(() async {
      await manager.dispose();
    });

    test('bateria > 30% → modo full', () async {
      await manager.updateBatteryMode(80);
      // EdgeSAM deveria ser acessível
      await manager.ensureEdgeSAM();
      expect(manager.edgeSAM.isLoaded, isTrue);
    });

    test('bateria 20-30% → modo economy descarrega EdgeSAM', () async {
      await manager.ensureEdgeSAM();
      expect(manager.edgeSAM.isLoaded, isTrue);

      await manager.updateBatteryMode(25);
      expect(manager.edgeSAM.isLoaded, isFalse);
    });

    test('bateria < 10% → modo critical descarrega EdgeSAM', () async {
      await manager.ensureEdgeSAM();
      expect(manager.edgeSAM.isLoaded, isTrue);

      await manager.updateBatteryMode(5);
      expect(manager.edgeSAM.isLoaded, isFalse);
    });

    test('transição de economy para full permite EdgeSAM', () async {
      await manager.updateBatteryMode(25); // economy
      await manager.ensureEdgeSAM();
      expect(manager.edgeSAM.isLoaded, isFalse);

      await manager.updateBatteryMode(80); // full
      await manager.ensureEdgeSAM();
      expect(manager.edgeSAM.isLoaded, isTrue);
    });

    test('mesmo nível de bateria não recalcula modo', () async {
      await manager.updateBatteryMode(80);
      await manager.updateBatteryMode(75); // ainda full, sem mudança
      await manager.ensureEdgeSAM();
      expect(manager.edgeSAM.isLoaded, isTrue);
    });
  });

  group('BatteryMode enum', () {
    test('valores existem', () {
      expect(BatteryMode.values.length, 3);
      expect(BatteryMode.values, contains(BatteryMode.full));
      expect(BatteryMode.values, contains(BatteryMode.economy));
      expect(BatteryMode.values, contains(BatteryMode.critical));
    });
  });

  group('ModelTier enum', () {
    test('valores existem', () {
      expect(ModelTier.values.length, 3);
      expect(ModelTier.values, contains(ModelTier.warm));
      expect(ModelTier.values, contains(ModelTier.lazy));
      expect(ModelTier.values, contains(ModelTier.economy));
    });
  });
}
