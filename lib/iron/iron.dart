/// IronMind - Motor de Inspeção Industrial com GPU/NPU
/// Barrel export de todos os módulos
library iron;

// Detection (YOLO26n + fallbacks)
export 'detection/yolo_engine.dart';

// Segmentation (EdgeSAM)
export 'segmentation/edgesam_segmenter.dart';

// Diagnosis (Gemini Spatial Engine)
export 'diagnosis/gemini_spatial_engine.dart';

// Voice (EVA + YAMNet)
export 'voice/eva_voice_controller.dart';
export 'voice/yamnet_classifier.dart';

// Logic (Orchestrator + Model Manager + Uncertainty)
export 'logic/inspection_orchestrator.dart';
export 'logic/model_manager.dart';
export 'logic/uncertainty_analyzer.dart';

// Data (Database + Sync)
export 'data/inspection_model.dart';
export 'data/local_database.dart';
export 'data/sync_manager.dart';

// UI (Overlays + Preview)
export 'ui/detection_overlay.dart';
export 'ui/inspection_preview.dart';
