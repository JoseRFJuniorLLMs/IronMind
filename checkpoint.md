# CHECKPOINT - IronMind
**Data:** 2026-02-19
**Status:** ~45% funcional - UI e Gemini API funcionam, YOLO/EdgeSAM sao stubs, modelos AI ausentes

---

## O QUE E O PROJETO
App Flutter para inspecao industrial em tempo real usando AI on-device (GPU/NPU). Pipeline: Camera 30fps -> YOLO26n (NPU) -> EdgeSAM -> Gemini Spatial (cloud) -> TTS Alert. Para tecnicos inspecionando maquinas pesadas (tratores, caminhoes, mineracao, escavadeiras) em ambientes potencialmente offline.

**Origem:** Refatorado/rebrandado de EVA-Mobile (app saude idosos). Vestiges do EVA permanecem (Health Connect permissions, cores EVA, "patient" user_type, referencias evacare.com).

**Tech Stack:** Flutter/Dart SDK >=3.0, ONNX Runtime, TFLite, Gemini 2.5 Flash API, Provider, GoRouter, Hive (NoSQL offline-first), WebSocket PCM, WebRTC, Firebase FCM, FastAPI + Go backend (GCP VM 136.113.25.218)

---

## O QUE FUNCIONA
- Login CPF com fallback demo offline
- Home Screen com botoes "Inspecionar" e "Falar" + Sentinela status
- Camera Inspection UI: preview real, fps counter, tipo equipamento, botoes captura/diagnostico/voz
- **Gemini Spatial Engine**: analise imagem via Gemini 2.5 Flash, resposta JSON estruturada, plano reparo, "pointing mode"
- **Uncertainty Analyzer**: Shannon entropy, severity multipliers, frame urgency scoring
- **Inspection Orchestrator**: coordenador pipeline com error isolation e timeouts
- **Manual Lookup Service**: parser YAML com priorizacao por tipo equipamento + geracao texto TTS
- **EVA Voice Controller (TTS)**: flutter_tts pt-BR, 16+ voice commands, priority interrupt
- **Model Manager**: lifecycle com battery modes (full/economy/critical)
- **Vibration Detector FSM**: FSM completa com calibracao baseline, estimacao frequencia, confidence scoring
- **IronSentinel Service**: monitoramento background acelerometro/giroscopio, niveis alerta escalating, TTS + vibracao
- **Local Database (Hive)**: inspections, machines, config, sync_queue
- **Sync Manager**: offline-first connectivity monitoring, retry logic (mas upload e placeholder)
- **Detection Overlay**: custom painters para bounding boxes + segmentation masks
- Audio Call (WebSocket PCM) + Video Call (WebRTC)
- Acessibilidade: alto contraste, bold, text scale, filtros daltonismo, voice navigation
- Firebase FCM push notifications
- Complete Diagnostic Screen (dev tool)

---

## O QUE FALTA (Core AI NAO Funcional)
1. **YOLO Engine** - `_loadModel()` throws UnsupportedError intencional. `_runInference()` TODO comentado. Modelos AUSENTES de assets (so .gitkeep). **Deteccao sempre retorna lista vazia**
2. **EdgeSAM Segmenter** - `ensureLoaded()` marca loaded sem carregar modelo. `segment()` retorna mask placeholder (zeros) e IoU hardcoded 0.85. Modelo AUSENTE
3. **YAMNet Classifier** - `initialize()` stub. `classify()` sempre retorna null. yamnet.tflite PRESENTE mas loading nao implementado
4. **STT / Voice Commands** - `processVoice()` usa string vazia como transcricao. Whisper Small Q5 comentado
5. **SyncManager upload** - `_uploadInspection()` e `Future.delayed(100ms); return true`. Nenhum HTTP POST real
6. **StartupFixer** - `_checkPermissions()` e `_checkConnectivity()` stubs vazios
7. **VLM models** - diretorio vazio (so .gitkeep)
8. **_getDailyStats()** - retorna stats zerados hardcoded
9. **Voice Note** - mostra "em desenvolvimento" snackbar

---

## BUGS
1. **SEGURANCA: Gemini API key em .env** - `AIzaSyBlem2g_EFVLTt3Fb1AofF1EOAf05YPo3U` presente
2. **v1.apk (163MB) commitado no repo** - binario nao deveria estar no git
3. **classes_ironmind.yaml nc:40 mas 55 classes listadas** - YOLO output parsing vai dar erro quando inferencia real implementada
4. **toggleMute() visual only** - nao muta microfone real
5. **_convertYUV420toRGB extrai so Y plane (grayscale)** - YOLO precisa RGB 3-channel
6. **VibrationDetectorFSM sem case para escavadeira** - usa defaults de trator
7. **ModelManager compara 'yolov8n' vs filename 'yolov8n_int8.tflite'** - sempre falha
8. **SpatialComponent.fromJson casta bbox para List<int>** - Gemini pode retornar floats, throw cast exception
9. **WS_PCM_URL nao declarado no .env** - DiagnosticScreen le WS_PCM_URL mas .env tem WS_URL. Fallback para endpoint EVA antigo
10. **Health Connect permissions (40+)** - leftover EVA-Mobile, irrelevante para inspecao industrial. Problemas no Play Store
11. **CPF hardcoded** - `64525430249` no CompleteDiagnosticScreen
12. **CallProvider.fallback() nao registra callback Firebase** - incoming calls nao trigam provider

---

## DEPENDENCIAS PRINCIPAIS
provider 6.1.1, go_router 13.0.0, onnxruntime 1.4.1, tflite_flutter 0.10.4, camera 0.10.5, flutter_tts 4.0.2, sound_stream 0.4.2, hive_flutter 1.1.0, firebase_core 2.24.2, firebase_messaging 14.7.9, flutter_webrtc 0.12.0, sensors_plus 4.0.2, geolocator 10.1.0, flutter_background_service 5.0.5

---

## DEAD CODE
- flutter_inappwebview no pubspec (WebView removido, modo nativo)
- google_sign_in no pubspec (nao usado no IronMind)
- Botoes audio/video call em HomeScreen em `if (false)`
- assets/videos/EVA.mp4, EVA2.mp4, EVA4.mp4 (leftover EVA-Mobile)
- DebugScreen sem rota no router
- test_agendamento.py / test_agendamento.sh (leftover EVA)

### Lixo na Raiz
- v1.apk (163MB)
- 00009f7d.pdf (13MB, desconhecido)
- analysis.json, analysis_utf8.json, analysis_full.txt
- build_output.txt, build_log.txt, critical_errors.txt, errors_only.txt
- txt/ inteiro (logs debug)

---

## .md PARA DELETAR
- MD/MEDICATION_SCANNER_INTEGRATION.md (EVA-Mobile healthcare leftover)
- MD/PERMISSOES_SAUDE_CORRECAO.md (EVA-Mobile healthcare leftover)
- MD/CORRECAO_AGENDAMENTO.md (EVA leftover)
- MD/ACCESSIBILITY_SPRINT1_COMPLETED.md (historico sprint)
- MD/ACCESSIBILITY_SPRINT2_COMPLETED.md (historico sprint)
- MD/ACESSIBILIDADE.md (notas design)
- MD/SECURITY_FIXES_2026-01-25.md (log fixes antigo)
