/// Modelos de dados para inspeções IronMind
class InspectionRecord {
  final String id;
  final DateTime timestamp;
  final String machineType; // trator, caminhao, mineracao
  final String? machineId;
  final String? operatorName;
  final List<DefectRecord> defects;
  final String? audioNote; // Transcrição de nota de voz
  final double latitude;
  final double longitude;
  final bool synced;

  InspectionRecord({
    required this.id,
    required this.timestamp,
    required this.machineType,
    this.machineId,
    this.operatorName,
    required this.defects,
    this.audioNote,
    required this.latitude,
    required this.longitude,
    this.synced = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'machine_type': machineType,
        'machine_id': machineId,
        'operator_name': operatorName,
        'defects': defects.map((d) => d.toJson()).toList(),
        'audio_note': audioNote,
        'latitude': latitude,
        'longitude': longitude,
        'synced': synced,
      };

  factory InspectionRecord.fromJson(Map<String, dynamic> json) {
    return InspectionRecord(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      machineType: json['machine_type'] as String,
      machineId: json['machine_id'] as String?,
      operatorName: json['operator_name'] as String?,
      defects: (json['defects'] as List)
          .map((d) => DefectRecord.fromJson(d as Map<String, dynamic>))
          .toList(),
      audioNote: json['audio_note'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      synced: json['synced'] as bool? ?? false,
    );
  }
}

class DefectRecord {
  final String className;
  final double confidence;
  final String severity; // leve, medio, grave, critico
  final String? diagnosis; // Descrição do Gemini Spatial
  final String? imagePath; // Path local do crop
  final double? maskArea; // Área da máscara EdgeSAM (%)
  final double bboxLeft;
  final double bboxTop;
  final double bboxRight;
  final double bboxBottom;

  DefectRecord({
    required this.className,
    required this.confidence,
    required this.severity,
    this.diagnosis,
    this.imagePath,
    this.maskArea,
    required this.bboxLeft,
    required this.bboxTop,
    required this.bboxRight,
    required this.bboxBottom,
  });

  Map<String, dynamic> toJson() => {
        'class_name': className,
        'confidence': confidence,
        'severity': severity,
        'diagnosis': diagnosis,
        'image_path': imagePath,
        'mask_area': maskArea,
        'bbox': [bboxLeft, bboxTop, bboxRight, bboxBottom],
      };

  factory DefectRecord.fromJson(Map<String, dynamic> json) {
    final bbox = json['bbox'] as List;
    return DefectRecord(
      className: json['class_name'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      severity: json['severity'] as String,
      diagnosis: json['diagnosis'] as String?,
      imagePath: json['image_path'] as String?,
      maskArea: (json['mask_area'] as num?)?.toDouble(),
      bboxLeft: (bbox[0] as num).toDouble(),
      bboxTop: (bbox[1] as num).toDouble(),
      bboxRight: (bbox[2] as num).toDouble(),
      bboxBottom: (bbox[3] as num).toDouble(),
    );
  }
}

class MachineProfile {
  final String id;
  final String name;
  final String type; // trator, caminhao, mineracao
  final String? model;
  final String? serialNumber;
  final int? yearManufactured;
  final DateTime lastInspection;
  final int totalInspections;
  final int totalDefects;

  MachineProfile({
    required this.id,
    required this.name,
    required this.type,
    this.model,
    this.serialNumber,
    this.yearManufactured,
    required this.lastInspection,
    this.totalInspections = 0,
    this.totalDefects = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'model': model,
        'serial_number': serialNumber,
        'year_manufactured': yearManufactured,
        'last_inspection': lastInspection.toIso8601String(),
        'total_inspections': totalInspections,
        'total_defects': totalDefects,
      };

  factory MachineProfile.fromJson(Map<String, dynamic> json) {
    return MachineProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      model: json['model'] as String?,
      serialNumber: json['serial_number'] as String?,
      yearManufactured: json['year_manufactured'] as int?,
      lastInspection: DateTime.parse(json['last_inspection'] as String),
      totalInspections: json['total_inspections'] as int? ?? 0,
      totalDefects: json['total_defects'] as int? ?? 0,
    );
  }
}
