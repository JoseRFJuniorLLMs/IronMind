# IRONMIND - ARQUITETURA DE MODELOS v2.0
## OFFLINE FIRST | NPU PRIORITY | PREVIEW REAL-TIME

---

## FILOSOFIA: 95% OFFLINE, 5% CLOUD

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│   "SE NÃO FUNCIONA SEM INTERNET, NÃO FUNCIONA."               │
│                                                                 │
│   O operador está no meio do campo, dentro de uma mina,        │
│   debaixo de um camião. Não tem Wi-Fi. Não tem 4G.             │
│   O sistema TEM QUE FUNCIONAR 100% LOCAL.                      │
│                                                                 │
│   Cloud é LUXO, não NECESSIDADE.                               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 1. STACK DEFINITIVA DE MODELOS

```
┌─────────────────────────────────────────────────────────────────┐
│                 IRONMIND MODEL STACK v2.0                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ╔═══════════════════════════════════════════════════════════╗  │
│  ║  TIER 1 - PREVIEW REAL-TIME (cada frame, 30-60 FPS)      ║  │
│  ║  ─────────────────────────────────────────────────────    ║  │
│  ║  YOLO26n (INT8)           ← DETECTOR PRINCIPAL            ║  │
│  ║  ├─ 4-6 MB quantizado                                    ║  │
│  ║  ├─ NMS-free (zero pós-processamento)                     ║  │
│  ║  ├─ 60-120 FPS na NPU                                    ║  │
│  ║  ├─ Export: ONNX + TFLite (NNAPI)                         ║  │
│  ║  ├─ mAP: 40.9% COCO (pré fine-tune)                      ║  │
│  ║  └─ 43% mais rápido que YOLO11n no CPU                   ║  │
│  ║                                                            ║  │
│  ║  YOLOv8n (INT8)           ← FALLBACK (se YOLO26 falhar)  ║  │
│  ║  ├─ 2 MB quantizado                                      ║  │
│  ║  ├─ 80-200 FPS na NPU                                    ║  │
│  ║  └─ Ecossistema mais maduro, milhares de modelos prontos  ║  │
│  ╚═══════════════════════════════════════════════════════════╝  │
│                          ↓                                      │
│  ╔═══════════════════════════════════════════════════════════╗  │
│  ║  TIER 2 - SEGMENTAÇÃO (quando detecta defeito)            ║  │
│  ║  ─────────────────────────────────────────────────────    ║  │
│  ║  EdgeSAM (INT8)           ← CONTORNO DO DEFEITO           ║  │
│  ║  ├─ 10-15 MB                                             ║  │
│  ║  ├─ 30+ FPS na NPU                                       ║  │
│  ║  ├─ RepViT encoder (CNN, NPU-friendly)                    ║  │
│  ║  ├─ 37x mais rápido que SAM original                      ║  │
│  ║  ├─ mIoU: 0.72                                           ║  │
│  ║  └─ Calcula: área, perímetro, severidade do dano          ║  │
│  ╚═══════════════════════════════════════════════════════════╝  │
│                          ↓                                      │
│  ╔═══════════════════════════════════════════════════════════╗  │
│  ║  TIER 3 - DIAGNÓSTICO LOCAL (operador toca ou pergunta)   ║  │
│  ║  ─────────────────────────────────────────────────────    ║  │
│  ║  Moondream 0.5B (4-bit)   ← CÉREBRO LOCAL                ║  │
│  ║  ├─ 375 MB quantizado                                    ║  │
│  ║  ├─ 2-5 FPS (não real-time, sob demanda)                  ║  │
│  ║  ├─ 816 MB RAM (4-bit)                                    ║  │
│  ║  ├─ ONNX export                                           ║  │
│  ║  ├─ Descreve defeitos em linguagem natural                ║  │
│  ║  ├─ "Mangueira hidráulica com abrasão, 60% desgaste"     ║  │
│  ║  └─ 100% OFFLINE - zero cloud                             ║  │
│  ╚═══════════════════════════════════════════════════════════╝  │
│                          ↓                                      │
│  ╔═══════════════════════════════════════════════════════════╗  │
│  ║  TIER 4 - VOZ (EVA-Mobile integrado)                      ║  │
│  ║  ─────────────────────────────────────────────────────    ║  │
│  ║  Whisper Small Q5 (ONNX)  ← OUVE O OPERADOR              ║  │
│  ║  ├─ ~140 MB (sherpa_onnx)                                 ║  │
│  ║  ├─ 16kHz mono PCM                                        ║  │
│  ║  ├─ Português BR nativo                                   ║  │
│  ║  └─ 100% OFFLINE                                          ║  │
│  ║                                                            ║  │
│  ║  Flutter TTS              ← FALA O RESULTADO              ║  │
│  ║  ├─ Engine nativa Android/iOS                             ║  │
│  ║  ├─ Velocidade reduzida (campo ruidoso)                   ║  │
│  ║  └─ 100% OFFLINE                                          ║  │
│  ║                                                            ║  │
│  ║  YAMNet (TFLite)          ← CLASSIFICA SONS               ║  │
│  ║  ├─ 521 classes de áudio                                  ║  │
│  ║  ├─ Detecta: motor falhando, vazamento, impacto           ║  │
│  ║  └─ Background contínuo                                   ║  │
│  ╚═══════════════════════════════════════════════════════════╝  │
│                          ↓                                      │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │  TIER 5 - CLOUD FALLBACK (só com internet, só se preciso) │ │
│  │  ─────────────────────────────────────────────────────    │ │
│  │  Gemini 2.0 Flash        ← ANÁLISE AVANÇADA               │ │
│  │  ├─ API Google (multimodal: imagem + texto + voz)         │ │
│  │  ├─ Latência: 500-1200ms                                  │ │
│  │  ├─ Diagnóstico contextual avançado                       │ │
│  │  └─ Só quando Moondream local não resolve                 │ │
│  │                                                            │ │
│  │  Florence-2-Large        ← OCR + RELATÓRIOS               │ │
│  │  ├─ Vertex AI Custom Container                            │ │
│  │  ├─ Lê números de série, placas, códigos                  │ │
│  │  ├─ Gera relatório de inspeção completo                   │ │
│  │  └─ Latência: 1-3s                                        │ │
│  │                                                            │ │
│  │  Vertex AI Vision        ← RETREINAMENTO                  │ │
│  │  ├─ AutoML para fine-tune contínuo                        │ │
│  │  ├─ Novo modelo → OTA para tablets                        │ │
│  │  └─ Pipeline automático a cada 5000 imagens               │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. TABELA COMPARATIVA DEFINITIVA

### Modelos que VAMOS USAR (decisão final)

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│  MODELOS SELECIONADOS - IRONMIND v2.0                                           │
├────┬─────────────────┬──────────┬────────┬─────────┬────────┬──────────────────┤
│ #  │ MODELO          │ TAMANHO  │ FPS    │ FORMATO │ ONDE   │ FUNÇÃO           │
│    │                 │ (INT8)   │ (NPU)  │         │        │                  │
├────┼─────────────────┼──────────┼────────┼─────────┼────────┼──────────────────┤
│ 1  │ YOLO26n         │ 4-6 MB   │ 60-120 │ ONNX    │ LOCAL  │ Detector         │
│    │                 │          │        │ TFLite  │ NPU    │ real-time        │
├────┼─────────────────┼──────────┼────────┼─────────┼────────┼──────────────────┤
│ 2  │ YOLOv8n         │ 2 MB     │ 80-200 │ ONNX    │ LOCAL  │ Fallback         │
│    │                 │          │        │ TFLite  │ NPU    │ detector         │
├────┼─────────────────┼──────────┼────────┼─────────┼────────┼──────────────────┤
│ 3  │ EdgeSAM         │ 10-15 MB │ 30+    │ ONNX    │ LOCAL  │ Segmentação      │
│    │                 │          │        │         │ NPU    │ do defeito       │
├────┼─────────────────┼──────────┼────────┼─────────┼────────┼──────────────────┤
│ 4  │ Moondream 0.5B  │ 375 MB   │ 2-5    │ ONNX    │ LOCAL  │ Diagnóstico      │
│    │                 │ (4-bit)  │        │         │ NPU    │ em texto         │
├────┼─────────────────┼──────────┼────────┼─────────┼────────┼──────────────────┤
│ 5  │ Whisper Small   │ 140 MB   │ RT     │ ONNX    │ LOCAL  │ Voz → Texto      │
│    │ Q5              │          │        │ sherpa  │ NPU    │ (comandos)       │
├────┼─────────────────┼──────────┼────────┼─────────┼────────┼──────────────────┤
│ 6  │ YAMNet          │ 3 MB     │ RT     │ TFLite  │ LOCAL  │ Classificação    │
│    │                 │          │        │         │ NPU    │ de sons          │
├────┼─────────────────┼──────────┼────────┼─────────┼────────┼──────────────────┤
│ 7  │ Flutter TTS     │ 0 MB     │ RT     │ Nativo  │ LOCAL  │ Texto → Voz      │
│    │                 │ (engine) │        │ Android │ CPU    │ (respostas)      │
├────┼─────────────────┼──────────┼────────┼─────────┼────────┼──────────────────┤
│ 8  │ Gemini 2.0 Flash│ Cloud    │ N/A    │ API     │ CLOUD  │ Análise          │
│    │                 │          │        │ Google  │        │ avançada         │
├────┼─────────────────┼──────────┼────────┼─────────┼────────┼──────────────────┤
│ 9  │ Florence-2-L    │ Cloud    │ N/A    │ ONNX    │ CLOUD  │ OCR +            │
│    │                 │          │        │ Vertex  │        │ Relatórios       │
├────┼─────────────────┼──────────┼────────┼─────────┼────────┼──────────────────┤
│ 10 │ Vertex AI Vision│ Cloud    │ N/A    │ AutoML  │ CLOUD  │ Retreinamento    │
│    │                 │          │        │         │        │ contínuo         │
├────┴─────────────────┴──────────┴────────┴─────────┴────────┴──────────────────┤
│                                                                                 │
│  STORAGE LOCAL TOTAL: ~550 MB (todos os modelos offline)                       │
│  RAM PICO: ~1.5 GB (quando Moondream ativo)                                   │
│  RAM NORMAL: ~200 MB (YOLO26n + Whisper + YAMNet)                             │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. PIPELINE REAL-TIME - PREVIEW COM OVERLAY

```
┌─────────────────────────────────────────────────────────────────┐
│  PIPELINE DE CÂMERA - 30 FPS COM DETECÇÃO AO VIVO             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  FRAME DA CÂMERA (30fps contínuo)                              │
│       │                                                         │
│       ├──→ [Buffer Circular - 3 frames]                        │
│       │         │                                               │
│       │         ▼                                               │
│       │    ┌─────────────────────────────────┐                 │
│       │    │  YOLO26n na NPU (5ms/frame)     │                 │
│       │    │  ├─ Input: 640x640 UINT8         │                 │
│       │    │  ├─ NMS-free (end-to-end)        │                 │
│       │    │  └─ Output: boxes + classes      │                 │
│       │    └──────────────┬──────────────────┘                 │
│       │                   │                                     │
│       │                   ▼                                     │
│       │    ┌─────────────────────────────────┐                 │
│       │    │  OVERLAY RENDERER (UI Thread)    │                 │
│       │    │  ├─ Bounding boxes coloridos     │                 │
│       │    │  ├─ Labels: "CORREIA GASTA 87%"  │                 │
│       │    │  ├─ Cor por severidade:           │                 │
│       │    │  │   Verde = OK                   │                 │
│       │    │  │   Amarelo = Atenção             │                 │
│       │    │  │   Vermelho = Crítico           │                 │
│       │    │  └─ FPS counter no canto          │                 │
│       │    └──────────────┬──────────────────┘                 │
│       │                   │                                     │
│       ▼                   ▼                                     │
│  ┌──────────────────────────────────────┐                      │
│  │         TELA DO TABLET               │                      │
│  │  ┌────────────────────────────────┐  │                      │
│  │  │   PREVIEW CÂMERA AO VIVO      │  │                      │
│  │  │                                │  │                      │
│  │  │    ┌─────────┐                 │  │                      │
│  │  │    │ CORREIA │ ← box vermelho  │  │                      │
│  │  │    │ GASTA   │   87% conf      │  │                      │
│  │  │    └─────────┘                 │  │                      │
│  │  │                                │  │                      │
│  │  │    ┌───────┐                   │  │                      │
│  │  │    │ PNEU  │ ← box verde      │  │                      │
│  │  │    │  OK   │   94% conf        │  │                      │
│  │  │    └───────┘                   │  │                      │
│  │  │                                │  │                      │
│  │  │  FPS: 47 │ NPU │ OFFLINE      │  │                      │
│  │  └────────────────────────────────┘  │                      │
│  │                                      │                      │
│  │  [DIAGNOSTICAR]  [HISTÓRICO]  [VOZ]  │                      │
│  └──────────────────────────────────────┘                      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Pipeline Técnico Frame-a-Frame

```
THREAD 1 - CÂMERA (isolate Dart)
├─ CameraController.startImageStream()
├─ Formato: YUV420 → RGB888
├─ Resolução: 1920x1080 (captura) → 640x640 (inferência)
└─ Envia para Thread 2 via Isolate.spawn()

THREAD 2 - INFERÊNCIA NPU (isolate nativo)
├─ Recebe frame RGB 640x640
├─ ONNX Runtime + NNAPI delegate
├─ YOLO26n.onnx (INT8, NMS-free)
├─ Inferência: 5-8ms
├─ Output: List<Detection> {box, class, confidence}
└─ Envia resultado para Thread 1

THREAD 1 - RENDER (UI thread)
├─ Recebe List<Detection>
├─ CustomPainter desenha overlay
├─ Bounding boxes + labels + cores
├─ Atualiza a cada frame (30fps)
└─ Zero jank (GPU compositing)

THREAD 3 - ÁUDIO (isolate background)
├─ YAMNet contínuo (som ambiente)
├─ Whisper sob demanda (comando de voz)
└─ TTS para respostas faladas
```

---

## 4. FLUXO COMPLETO DE DIAGNÓSTICO OFFLINE

```
┌─────────────────────────────────────────────────────────────────┐
│  JORNADA DO OPERADOR - 100% OFFLINE                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. OPERADOR LIGA O APP                                        │
│     ├─ Carrega YOLO26n na NPU (~500ms)                         │
│     ├─ Carrega Whisper na memória (~1s)                        │
│     ├─ YAMNet começa a ouvir (background)                      │
│     └─ Camera preview inicia com overlay                       │
│                                                                 │
│  2. APONTA PARA A MÁQUINA                                      │
│     ├─ YOLO26n detecta componentes em tempo real               │
│     ├─ Overlay mostra: "MOTOR", "CORREIA", "FILTRO", "PNEU"   │
│     ├─ Cores indicam estado: verde/amarelo/vermelho            │
│     └─ Operador VÊ os problemas no preview ao vivo            │
│                                                                 │
│  3. OPERADOR TOCA NUM DEFEITO (ou fala "diagnosticar")         │
│     │                                                           │
│     ├─ TRIGGER: toque na bounding box OU comando de voz        │
│     │                                                           │
│     ├─ PASSO 3a: EdgeSAM segmenta o defeito (~30ms)            │
│     │   ├─ Contorno preciso pixel-a-pixel                      │
│     │   ├─ Calcula área do dano (cm²)                          │
│     │   ├─ Calcula percentual de desgaste                      │
│     │   └─ Overlay: máscara semitransparente vermelha          │
│     │                                                           │
│     ├─ PASSO 3b: Moondream analisa a região (~500ms)           │
│     │   ├─ Input: crop da região detectada                     │
│     │   ├─ Prompt: "Descreva o defeito desta peça mecânica"    │
│     │   ├─ Output: "Correia do alternador apresenta           │
│     │   │           fissuras laterais e desgaste de ~70%.      │
│     │   │           Risco de ruptura. Substituir."             │
│     │   └─ Texto aparece na tela                               │
│     │                                                           │
│     └─ PASSO 3c: TTS fala o resultado                          │
│         ├─ "Atenção: correia do alternador com 70% de          │
│         │   desgaste. Risco de ruptura. Substituir."           │
│         └─ Operador ouve sem olhar para tela                   │
│                                                                 │
│  4. OPERADOR CONFIRMA OU CORRIGE                               │
│     ├─ "EVA, está correto" → salva diagnóstico                 │
│     ├─ "EVA, não é correia, é mangueira" → corrige label       │
│     └─ Correção vai para fila de retreinamento (sync futuro)   │
│                                                                 │
│  5. RELATÓRIO LOCAL                                            │
│     ├─ Salva em SQLite/Hive local                              │
│     ├─ Foto + segmentação + diagnóstico + GPS + timestamp      │
│     ├─ PDF gerado localmente (opcional)                        │
│     └─ Fila de sync para quando tiver internet                 │
│                                                                 │
│  6. SYNC QUANDO HOUVER INTERNET (background)                   │
│     ├─ Envia diagnósticos para BigQuery                        │
│     ├─ Imagens corrigidas → dataset de retreinamento           │
│     ├─ Verifica se há modelo novo (OTA)                        │
│     └─ Baixa atualizações só em Wi-Fi                          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 5. CLASSES DE DETECÇÃO - O QUE YOLO26n VAI DETECTAR

```
┌─────────────────────────────────────────────────────────────────┐
│  CLASSES DO MODELO FINE-TUNED (por tipo de máquina)            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  UNIVERSAL (todas as máquinas):                                │
│  ├─ correia_ok          correia_desgastada                     │
│  ├─ mangueira_ok        mangueira_vazando                      │
│  ├─ filtro_ok           filtro_sujo                            │
│  ├─ parafuso_ok         parafuso_solto                         │
│  ├─ pneu_ok             pneu_careca                            │
│  ├─ óleo_ok             óleo_vazando                           │
│  ├─ corrosão_leve       corrosão_grave                         │
│  ├─ solda_ok            solda_trincada                         │
│  ├─ vedação_ok          vedação_comprometida                   │
│  └─ conexão_elétrica_ok conexão_elétrica_solta                 │
│                                                                 │
│  TRATORES:                                                     │
│  ├─ implemento_ok       implemento_danificado                  │
│  ├─ eixo_cardã_ok       eixo_cardã_desgastado                  │
│  ├─ sistema_hidráulico_ok  hidráulico_vazando                  │
│  └─ lâmina_ok           lâmina_gasta                           │
│                                                                 │
│  CAMINHÕES:                                                    │
│  ├─ freio_ok            freio_gasto                            │
│  ├─ suspensão_ok        suspensão_danificada                   │
│  ├─ escapamento_ok      escapamento_furado                     │
│  └─ carroceria_ok       carroceria_amassada                    │
│                                                                 │
│  MINERAÇÃO:                                                    │
│  ├─ esteira_ok          esteira_desgastada                     │
│  ├─ caçamba_ok          caçamba_trincada                        │
│  ├─ cilindro_ok         cilindro_vazando                       │
│  ├─ rolamento_ok        rolamento_ruidoso                      │
│  └─ britador_ok         britador_desgastado                    │
│                                                                 │
│  TOTAL: ~40 classes (20 pares OK/DEFEITO)                      │
│                                                                 │
│  NOTA: Modelo treinado com pares OK/DEFEITO para cada          │
│  componente. O operador aponta e o sistema diz se está         │
│  OK (verde) ou com DEFEITO (vermelho) + o tipo de defeito.     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 6. DETECÇÃO POR SOM - YAMNET CUSTOMIZADO

```
┌─────────────────────────────────────────────────────────────────┐
│  CLASSIFICAÇÃO DE SONS DE MÁQUINAS (background contínuo)       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  YAMNet base (521 classes) + Fine-tune para sons industriais:  │
│                                                                 │
│  SONS DE ALERTA (confidence > 0.70):                           │
│  ├─ motor_batendo         → "Motor com batida anormal"         │
│  ├─ vazamento_ar          → "Possível vazamento pneumático"    │
│  ├─ rolamento_rangendo    → "Rolamento com desgaste"           │
│  ├─ correia_guinchando    → "Correia solta ou gasta"           │
│  ├─ metal_raspando        → "Contato metal-metal"              │
│  ├─ escapamento_falhando  → "Problema no escapamento"          │
│  └─ impacto_anormal       → "Impacto detectado"                │
│                                                                 │
│  SONS NORMAIS (ignorar):                                       │
│  ├─ motor_diesel_normal                                        │
│  ├─ hidráulico_operando                                        │
│  ├─ vento                                                      │
│  └─ conversa_humana                                            │
│                                                                 │
│  AÇÃO AUTOMÁTICA:                                              │
│  ├─ Som anormal detectado → alerta visual + vibração           │
│  ├─ TTS: "Atenção: som de rolamento com desgaste detectado"    │
│  ├─ Grava 10s de áudio para relatório                          │
│  └─ Sugere inspeção visual do componente                       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 7. COMANDOS DE VOZ - INTEGRAÇÃO EVA-MOBILE

```
┌─────────────────────────────────────────────────────────────────┐
│  COMANDOS DE VOZ DO OPERADOR (Whisper + VoiceNavigation)       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  WAKE WORD: "EVA" ou "IRON"                                   │
│                                                                 │
│  INSPEÇÃO:                                                     │
│  ├─ "EVA, diagnosticar"      → Tier 2+3 (EdgeSAM + Moondream) │
│  ├─ "EVA, o que é isso?"     → Moondream descreve o que vê     │
│  ├─ "EVA, está bom?"         → Confiança do YOLO26n em voz     │
│  ├─ "EVA, próxima peça"      → Reset overlay, novo scan        │
│  └─ "EVA, gravar defeito"    → Captura foto + diagnóstico      │
│                                                                 │
│  CORREÇÃO:                                                     │
│  ├─ "EVA, está correto"      → Confirma diagnóstico            │
│  ├─ "EVA, não é isso"        → Marca para revisão              │
│  ├─ "EVA, é uma mangueira"   → Corrige classe                  │
│  └─ "EVA, gravidade alta"    → Override severidade              │
│                                                                 │
│  RELATÓRIO:                                                    │
│  ├─ "EVA, resumo do dia"     → TTS com estatísticas            │
│  ├─ "EVA, quantos defeitos?" → Conta defeitos encontrados      │
│  ├─ "EVA, gerar relatório"   → PDF local                       │
│  └─ "EVA, enviar dados"      → Força sync (se tiver internet)  │
│                                                                 │
│  NAVEGAÇÃO:                                                    │
│  ├─ "EVA, histórico"         → Abre tela de histórico          │
│  ├─ "EVA, configurações"     → Abre settings                   │
│  └─ "EVA, modo noturno"      → Ativa tema escuro + LED         │
│                                                                 │
│  PROCESSAMENTO:                                                │
│  ├─ Whisper (sherpa_onnx) converte voz → texto                 │
│  ├─ Regex + intent matching local (sem cloud)                  │
│  ├─ Executa ação correspondente                                │
│  └─ TTS responde com resultado                                 │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 8. GESTÃO DE MEMÓRIA NPU

```
┌─────────────────────────────────────────────────────────────────┐
│  ESTRATÉGIA DE MEMÓRIA - TABLET 8-12GB RAM                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  SEMPRE CARREGADOS (warm):                                     │
│  ├─ YOLO26n (INT8)        →   ~20 MB RAM                      │
│  ├─ Whisper Small Q5      →  ~200 MB RAM                      │
│  ├─ YAMNet (TFLite)       →   ~10 MB RAM                      │
│  ├─ Flutter TTS engine    →   ~30 MB RAM                      │
│  └─ App + UI + Camera     →  ~150 MB RAM                      │
│  ─────────────────────────────────────────                     │
│  SUBTOTAL WARM:               ~410 MB RAM                      │
│                                                                 │
│  CARREGADOS SOB DEMANDA (lazy):                                │
│  ├─ EdgeSAM              →  ~100 MB RAM (carrega em ~200ms)   │
│  ├─ Moondream 0.5B       →  ~816 MB RAM (carrega em ~1s)      │
│  └─ YOLOv8n fallback     →   ~15 MB RAM                       │
│                                                                 │
│  PICO MÁXIMO (tudo ativo):    ~1.3 GB RAM                      │
│  DISPONÍVEL (8GB tablet):     ~5 GB livres                     │
│  DISPONÍVEL (12GB tablet):    ~9 GB livres                     │
│                                                                 │
│  ESTRATÉGIA DE SWAP:                                           │
│  ├─ Moondream carrega APENAS quando operador pede diagnóstico  │
│  ├─ Moondream descarrega após 30s de inatividade               │
│  ├─ EdgeSAM carrega quando YOLO detecta defeito                │
│  ├─ EdgeSAM descarrega após 10s sem detecção                   │
│  └─ YOLO26n NUNCA descarrega (sempre em preview)               │
│                                                                 │
│  PRIORIDADE DE NPU:                                            │
│  ├─ 1º YOLO26n (real-time, não pode parar)                     │
│  ├─ 2º EdgeSAM (quando ativo, divide NPU com YOLO)            │
│  ├─ 3º Moondream (quando ativo, YOLO cai para CPU temp.)      │
│  └─ 4º Whisper (sempre em CPU, NPU para visão)                │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 9. ACELERAÇÃO NPU POR PLATAFORMA

```
┌─────────────────────────────────────────────────────────────────┐
│  COMO ATIVAR NPU EM CADA CHIPSET                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  QUALCOMM SNAPDRAGON (8 Gen 2/3, 8 Elite):                    │
│  ├─ SDK: QNN (Qualcomm Neural Network)                         │
│  ├─ Via: LiteRT (ex-TFLite) com QNN Accelerator               │
│  ├─ Ou: ONNX Runtime com QNN Execution Provider               │
│  ├─ NPU: Hexagon DSP (até 73 TOPS no 8 Elite)                 │
│  ├─ Quantização: INT8 W8A8 (melhor performance)                │
│  └─ Flutter: onnxruntime_flutter + NNAPI delegate              │
│                                                                 │
│  SAMSUNG EXYNOS (1380, 2400):                                  │
│  ├─ SDK: Samsung ONE (On-device Neural Engine)                 │
│  ├─ Via: NNAPI (Android Neural Networks API)                   │
│  ├─ NPU: até 34.7 TOPS (Exynos 2400)                          │
│  ├─ Quantização: INT8                                          │
│  └─ Flutter: tflite_flutter + NNAPI delegate                   │
│                                                                 │
│  MEDIATEK DIMENSITY (8300, 9300):                              │
│  ├─ SDK: NeuroPilot                                            │
│  ├─ Via: NNAPI                                                 │
│  ├─ NPU: APU 790 (até 46 TOPS)                                │
│  ├─ Quantização: INT8/INT4                                     │
│  └─ Flutter: tflite_flutter + NNAPI delegate                   │
│                                                                 │
│  GOOGLE TENSOR (G4):                                           │
│  ├─ SDK: LiteRT nativo (Google fez o chip)                     │
│  ├─ Via: LiteRT com Google TPU delegate                        │
│  ├─ NPU: Edge TPU integrado                                   │
│  └─ Melhor integração TFLite do mercado                        │
│                                                                 │
│  CÓDIGO FLUTTER UNIVERSAL (funciona em todos):                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  // ONNX Runtime - detecta NPU automaticamente          │  │
│  │  final sessionOptions = OrtSessionOptions()              │  │
│  │    ..addNnapi()           // Android NNAPI (qualquer NPU)│  │
│  │    ..setIntraOpNumThreads(4);                            │  │
│  │                                                          │  │
│  │  // OU TFLite - delegate automático                      │  │
│  │  final interpreter = Interpreter.fromAsset(              │  │
│  │    'yolo26n_int8.tflite',                                │  │
│  │    options: InterpreterOptions()..useNnApiForAndroid      │  │
│  │  );                                                      │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 10. FINE-TUNING DO YOLO26n

```
┌─────────────────────────────────────────────────────────────────┐
│  PIPELINE DE TREINO - YOLO26n PARA MÁQUINAS PESADAS            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  PASSO 1: DATASET                                              │
│  ├─ Fontes (datasets.md):                                      │
│  │   ├─ Construction Machines Images Dataset                   │
│  │   ├─ Heavy Equipment Construction Benchmark                 │
│  │   ├─ Damaged Car Parts (Roboflow)                           │
│  │   ├─ PPE and Heavy Machinery Detection                      │
│  │   └─ Roboflow Universe: "truck parts", "mining equipment"  │
│  │                                                              │
│  ├─ Quantidade mínima:                                         │
│  │   ├─ 500 imagens por classe (OK + DEFEITO)                  │
│  │   ├─ 40 classes × 500 = 20.000 imagens base                │
│  │   ├─ Augmentation 3x = 60.000 imagens treino               │
│  │   └─ 80% treino / 10% validação / 10% teste                │
│  │                                                              │
│  ├─ Augmentações:                                              │
│  │   ├─ Rotação ±15° (peças em ângulos diferentes)             │
│  │   ├─ Brilho/contraste (campo aberto vs garagem escura)      │
│  │   ├─ Blur (vibração do operador)                            │
│  │   ├─ Crop aleatório                                         │
│  │   └─ Flip horizontal                                        │
│  │                                                              │
│  └─ Anotação: Roboflow (web) ou CVAT (local)                  │
│                                                                 │
│  PASSO 2: TREINO                                               │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  from ultralytics import YOLO                            │  │
│  │                                                          │  │
│  │  model = YOLO("yolo26n.pt")  # pré-treinado COCO        │  │
│  │                                                          │  │
│  │  results = model.train(                                  │  │
│  │      data="ironmind_dataset.yaml",                       │  │
│  │      epochs=100,                                         │  │
│  │      imgsz=640,                                          │  │
│  │      batch=16,                                           │  │
│  │      device="0",        # ou "npu" se disponível         │  │
│  │      optimizer="AdamW",                                  │  │
│  │      lr0=0.001,                                          │  │
│  │      patience=20,       # early stopping                 │  │
│  │      augment=True,                                       │  │
│  │      mosaic=1.0,                                         │  │
│  │      mixup=0.1,                                          │  │
│  │      project="ironmind",                                 │  │
│  │      name="yolo26n_v1"                                   │  │
│  │  )                                                       │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  PASSO 3: EXPORT PARA NPU                                      │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  # Export ONNX (para NNAPI/QNN)                          │  │
│  │  model.export(                                           │  │
│  │      format="onnx",                                      │  │
│  │      imgsz=640,                                          │  │
│  │      int8=True,          # quantização INT8              │  │
│  │      dynamic=False,      # tamanho fixo (melhor NPU)    │  │
│  │      simplify=True       # ONNX simplifier              │  │
│  │  )                                                       │  │
│  │                                                          │  │
│  │  # Export TFLite (alternativa)                           │  │
│  │  model.export(                                           │  │
│  │      format="tflite",                                    │  │
│  │      imgsz=640,                                          │  │
│  │      int8=True                                           │  │
│  │  )                                                       │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  PASSO 4: VALIDAR NO TABLET                                    │
│  ├─ Benchmark FPS real na NPU do tablet alvo                   │
│  ├─ Medir latência P50/P95/P99                                 │
│  ├─ Testar com imagens de campo reais                          │
│  ├─ Ajustar threshold de confiança (70-85%)                    │
│  └─ Se FPS < 30: reduzir imgsz para 416x416                   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 11. ÁRVORE DE DECISÃO COMPLETA

```
┌─────────────────────────────────────────────────────────────────┐
│  DECISOR INTELIGENTE - QUANDO USAR CADA MODELO                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  [Frame da câmera]                                             │
│       │                                                         │
│       ▼                                                         │
│  ┌─────────────┐                                               │
│  │  YOLO26n    │ ← SEMPRE ATIVO (cada frame)                  │
│  │  NPU 5ms   │                                               │
│  └──────┬──────┘                                               │
│         │                                                       │
│         ├─── Nada detectado ──→ Preview limpo, continua        │
│         │                                                       │
│         ├─── Detectou OK (conf > 85%) ──→ Box VERDE            │
│         │                                  └─ Nenhuma ação     │
│         │                                                       │
│         ├─── Detectou DEFEITO (conf > 85%) ──→ Box VERMELHO   │
│         │    │                                                  │
│         │    ├─ Vibração + som de alerta                        │
│         │    ├─ TTS: "Defeito detectado em [componente]"        │
│         │    │                                                  │
│         │    └─ Operador toca ou fala "diagnosticar"?          │
│         │         │                                             │
│         │         ├─ SIM ──→ EdgeSAM (segmenta, 30ms)          │
│         │         │          └──→ Moondream (descreve, 500ms)  │
│         │         │               └──→ TTS fala diagnóstico    │
│         │         │                                             │
│         │         └─ NÃO ──→ Continua preview, log local       │
│         │                                                       │
│         └─── INCERTO (conf 50-85%) ──→ Box AMARELO            │
│              │                                                  │
│              ├─ Tem internet?                                   │
│              │    │                                              │
│              │    ├─ SIM ──→ Gemini 2.0 Flash (500ms)          │
│              │    │          └──→ Resultado cloud               │
│              │    │               └──→ Atualiza overlay         │
│              │    │                                              │
│              │    └─ NÃO ──→ Moondream local (500ms)           │
│              │               └──→ Melhor análise possível      │
│              │                    └──→ Flag "pendente cloud"   │
│              │                                                  │
│              └─ Confiança < 50%?                                │
│                   └─ TTS: "Não consigo identificar.            │
│                      Aproxime a câmera ou mude o ângulo."      │
│                                                                 │
│  [YAMNet em paralelo - background]                             │
│       │                                                         │
│       └─── Som anormal detectado ──→ Alerta independente       │
│            ├─ TTS: "Som anormal detectado: [tipo]"              │
│            ├─ Sugere inspeção visual                            │
│            └─ Grava 10s de áudio no relatório                  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 12. CLOUD FALLBACK - SÓ QUANDO NECESSÁRIO

```
┌─────────────────────────────────────────────────────────────────┐
│  QUANDO E COMO USAR CLOUD (Google All-In)                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  REGRA: Cloud é LUXO. Sistema funciona 100% sem ele.           │
│                                                                 │
│  TRIGGER PARA CLOUD (todos opcionais):                         │
│  ├─ Operador pede: "EVA, consultar na nuvem"                   │
│  ├─ Confiança local < 50% E internet disponível               │
│  ├─ Sync automático em background (Wi-Fi only)                 │
│  └─ Retreinamento (5000+ imagens acumuladas)                   │
│                                                                 │
│  SERVIÇOS GOOGLE CLOUD:                                        │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Gemini 2.0 Flash (API)                                  │  │
│  │  ├─ Análise multimodal: foto + contexto + pergunta       │  │
│  │  ├─ "Esta correia de trator precisa ser trocada?"        │  │
│  │  ├─ Resposta em 500-1200ms                               │  │
│  │  ├─ Custo: ~$0.003 por consulta                          │  │
│  │  └─ Usado: quando Moondream local não resolve            │  │
│  ├──────────────────────────────────────────────────────────┤  │
│  │  Florence-2-Large (Vertex AI)                            │  │
│  │  ├─ OCR: lê números de série, placas, códigos            │  │
│  │  ├─ Gera relatório de inspeção estruturado               │  │
│  │  ├─ VQA: responde perguntas técnicas sobre a peça        │  │
│  │  ├─ Custo: ~$0.005 por consulta                          │  │
│  │  └─ Usado: relatórios formais, auditorias                │  │
│  ├──────────────────────────────────────────────────────────┤  │
│  │  Vertex AI AutoML Vision                                 │  │
│  │  ├─ Retreinamento automático do YOLO26n                  │  │
│  │  ├─ A/B testing de modelos novos                         │  │
│  │  ├─ OTA: deploy novo modelo → tablets                    │  │
│  │  └─ Trigger: a cada 5000 imagens validadas               │  │
│  ├──────────────────────────────────────────────────────────┤  │
│  │  BigQuery                                                │  │
│  │  ├─ Analytics de toda a frota                            │  │
│  │  ├─ Tendências de desgaste por máquina                   │  │
│  │  └─ Dashboard em Looker Studio                           │  │
│  ├──────────────────────────────────────────────────────────┤  │
│  │  Cloud Storage                                           │  │
│  │  ├─ Backup de imagens e relatórios                       │  │
│  │  ├─ Dataset versionado para retreinamento                │  │
│  │  └─ Modelos versionados para OTA                         │  │
│  ├──────────────────────────────────────────────────────────┤  │
│  │  Firebase                                                │  │
│  │  ├─ Auth (login dos operadores)                          │  │
│  │  ├─ Crashlytics (bugs do app)                            │  │
│  │  └─ FCM (push notifications: "modelo novo disponível")  │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  CUSTO CLOUD MENSAL (por veículo, uso mínimo):                 │
│  ├─ Gemini: ~$1.50/mês (500 consultas × $0.003)               │
│  ├─ Florence: ~$0.50/mês (100 relatórios × $0.005)            │
│  ├─ Storage: ~$2.00/mês                                        │
│  ├─ BigQuery: ~$0.50/mês                                       │
│  └─ TOTAL: ~$4.50/mês por veículo                              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 13. STORAGE LOCAL DOS MODELOS

```
┌─────────────────────────────────────────────────────────────────┐
│  ORGANIZAÇÃO DE FICHEIROS NO TABLET                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  assets/models/                                                │
│  ├─ detection/                                                 │
│  │   ├─ yolo26n_ironmind_v1.onnx        (6 MB)   ← primário  │
│  │   ├─ yolo26n_ironmind_v1.tflite       (6 MB)   ← alt      │
│  │   ├─ yolov8n_fallback.onnx            (2 MB)   ← fallback  │
│  │   └─ labels_ironmind.txt              (1 KB)   ← classes   │
│  │                                                              │
│  ├─ segmentation/                                              │
│  │   └─ edgesam_int8.onnx                (15 MB)  ← lazy load │
│  │                                                              │
│  ├─ vlm/                                                       │
│  │   └─ moondream-0.5b-q4.onnx           (375 MB) ← lazy load │
│  │                                                              │
│  ├─ audio/                                                     │
│  │   ├─ yamnet.tflite                     (3 MB)   ← always   │
│  │   └─ whisper-small-q5.onnx            (140 MB) ← always    │
│  │                                                              │
│  └─ metadata/                                                  │
│      ├─ model_versions.json              ← controle OTA        │
│      └─ calibration_data.json            ← thresholds          │
│                                                                 │
│  TOTAL: ~547 MB                                                │
│  STORAGE DISPONÍVEL (128GB tablet): ~127 GB livres             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 14. COMPARAÇÃO v1 vs v2

```
┌─────────────────────────────────────────────────────────────────┐
│  O QUE MUDOU: modelos.md (v1) → modelos2.md (v2)              │
├──────────────────────┬──────────────────┬───────────────────────┤
│  ASPECTO             │  v1 (modelos.md) │  v2 (modelos2.md)    │
├──────────────────────┼──────────────────┼───────────────────────┤
│  Detector primário   │  YOLO-NAS-S      │  YOLO26n (2026)      │
│  Preview real-time   │  Não             │  Sim, 30-60 FPS      │
│  Segmentação         │  Não             │  EdgeSAM             │
│  Diagnóstico offline │  Não (cloud)     │  Moondream 0.5B      │
│  Voz integrada       │  Não             │  Whisper + TTS       │
│  Sons de máquina     │  Não             │  YAMNet customizado  │
│  Foco                │  50% cloud       │  95% offline         │
│  Comandos de voz     │  Não             │  15+ comandos        │
│  Gestão de memória   │  Não             │  Swap inteligente    │
│  Classes             │  Genérico        │  40 classes + som    │
│  Pipeline câmera     │  Captura-analisa │  Frame-a-frame RT    │
│  EVA-Mobile          │  Não integrado   │  Totalmente integrado│
│  NPU multi-chip      │  Só NNAPI        │  QNN+ONE+NeuroPilot │
│  Fine-tune guide     │  YOLO-NAS        │  YOLO26n Ultralytics │
└──────────────────────┴──────────────────┴───────────────────────┘
```

---

## 15. ROADMAP DE IMPLEMENTAÇÃO

```
FASE 0: SETUP (Semana 1)
├─ Copiar EVA-Mobile-FZPN → IronMobile
├─ Remover módulos de saúde/idosos (Health Connect, Medicamentos)
├─ Manter: voz (Whisper, TTS, YAMNet), câmera, UI base
├─ Adaptar VoiceNavigationService para comandos industriais
└─ Configurar projeto Flutter limpo

FASE 1: DETECÇÃO REAL-TIME (Semana 2-4)
├─ Coletar/anotar dataset (mínimo 20.000 imagens)
├─ Fine-tune YOLO26n no Vertex AI ou local
├─ Export ONNX INT8 + validar no tablet
├─ Implementar pipeline câmera com overlay
├─ Testar FPS real na NPU do tablet alvo
└─ Meta: preview com bounding boxes a 30+ FPS

FASE 2: DIAGNÓSTICO LOCAL (Semana 5-6)
├─ Integrar EdgeSAM (segmentação sob demanda)
├─ Integrar Moondream 0.5B (descrição de defeitos)
├─ Implementar gestão de memória (lazy load/unload)
├─ Conectar com TTS (falar diagnósticos)
└─ Meta: diagnóstico completo 100% offline

FASE 3: AUDIO INDUSTRIAL (Semana 7-8)
├─ Fine-tune YAMNet para sons de máquinas
├─ Coletar áudio de motores, vazamentos, impactos
├─ Integrar alertas de som no pipeline
└─ Meta: detecção visual + auditiva simultânea

FASE 4: CLOUD + POLISH (Semana 9-12)
├─ Integrar Gemini 2.0 Flash API (fallback)
├─ Implementar sync em background
├─ Deploy Florence-2 no Vertex AI (relatórios)
├─ Pipeline de retreinamento OTA
├─ Testes de campo reais
└─ Meta: sistema completo híbrido
```

---

**Este documento é a VERDADE do IronMind. Offline first, NPU always, cloud never... unless needed.**
