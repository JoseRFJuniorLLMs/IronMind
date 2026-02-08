import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'inspection_model.dart';

/// Banco de dados local usando Hive (NoSQL, zero-config)
/// Armazena inspeções, máquinas e configurações offline
class LocalDatabase {
  static const String _inspectionsBox = 'inspections';
  static const String _machinesBox = 'machines';
  static const String _configBox = 'config';
  static const String _syncQueueBox = 'sync_queue';

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    final dir = await getApplicationDocumentsDirectory();
    await Hive.initFlutter('${dir.path}/ironmind_db');

    await Hive.openBox<String>(_inspectionsBox);
    await Hive.openBox<String>(_machinesBox);
    await Hive.openBox<String>(_configBox);
    await Hive.openBox<String>(_syncQueueBox);

    _isInitialized = true;
    debugPrint('[LocalDB] Inicializado em ${dir.path}/ironmind_db');
  }

  // ─── INSPEÇÕES ───

  Future<void> saveInspection(InspectionRecord record) async {
    final box = Hive.box<String>(_inspectionsBox);
    await box.put(record.id, jsonEncode(record.toJson()));

    // Adiciona à fila de sync se não sincronizado
    if (!record.synced) {
      await _addToSyncQueue('inspection', record.id);
    }

    debugPrint('[LocalDB] Inspeção salva: ${record.id}');
  }

  Future<InspectionRecord?> getInspection(String id) async {
    final box = Hive.box<String>(_inspectionsBox);
    final json = box.get(id);
    if (json == null) return null;
    return InspectionRecord.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }

  Future<List<InspectionRecord>> getAllInspections() async {
    final box = Hive.box<String>(_inspectionsBox);
    return box.values.map((json) {
      return InspectionRecord.fromJson(
          jsonDecode(json) as Map<String, dynamic>);
    }).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  Future<List<InspectionRecord>> getInspectionsByMachine(
      String machineId) async {
    final all = await getAllInspections();
    return all.where((i) => i.machineId == machineId).toList();
  }

  Future<List<InspectionRecord>> getUnsyncedInspections() async {
    final all = await getAllInspections();
    return all.where((i) => !i.synced).toList();
  }

  Future<void> markSynced(String inspectionId) async {
    final record = await getInspection(inspectionId);
    if (record == null) return;

    final updated = InspectionRecord(
      id: record.id,
      timestamp: record.timestamp,
      machineType: record.machineType,
      machineId: record.machineId,
      operatorName: record.operatorName,
      defects: record.defects,
      audioNote: record.audioNote,
      latitude: record.latitude,
      longitude: record.longitude,
      synced: true,
    );

    await saveInspection(updated);
    await _removeFromSyncQueue(inspectionId);
  }

  // ─── MÁQUINAS ───

  Future<void> saveMachine(MachineProfile machine) async {
    final box = Hive.box<String>(_machinesBox);
    await box.put(machine.id, jsonEncode(machine.toJson()));
  }

  Future<MachineProfile?> getMachine(String id) async {
    final box = Hive.box<String>(_machinesBox);
    final json = box.get(id);
    if (json == null) return null;
    return MachineProfile.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }

  Future<List<MachineProfile>> getAllMachines() async {
    final box = Hive.box<String>(_machinesBox);
    return box.values.map((json) {
      return MachineProfile.fromJson(
          jsonDecode(json) as Map<String, dynamic>);
    }).toList();
  }

  // ─── CONFIG ───

  Future<void> setConfig(String key, String value) async {
    final box = Hive.box<String>(_configBox);
    await box.put(key, value);
  }

  Future<String?> getConfig(String key) async {
    final box = Hive.box<String>(_configBox);
    return box.get(key);
  }

  // ─── SYNC QUEUE ───

  Future<void> _addToSyncQueue(String type, String id) async {
    final box = Hive.box<String>(_syncQueueBox);
    await box.put(id, jsonEncode({'type': type, 'id': id, 'added': DateTime.now().toIso8601String()}));
  }

  Future<void> _removeFromSyncQueue(String id) async {
    final box = Hive.box<String>(_syncQueueBox);
    await box.delete(id);
  }

  Future<List<Map<String, dynamic>>> getSyncQueue() async {
    final box = Hive.box<String>(_syncQueueBox);
    return box.values.map((json) {
      return jsonDecode(json) as Map<String, dynamic>;
    }).toList();
  }

  // ─── STATS ───

  Future<Map<String, int>> getStats() async {
    final inspections = await getAllInspections();
    final machines = await getAllMachines();
    final unsynced = await getUnsyncedInspections();

    int totalDefects = 0;
    for (final i in inspections) {
      totalDefects += i.defects.length;
    }

    return {
      'total_inspections': inspections.length,
      'total_machines': machines.length,
      'total_defects': totalDefects,
      'pending_sync': unsynced.length,
    };
  }

  Future<void> dispose() async {
    await Hive.close();
    _isInitialized = false;
  }
}
