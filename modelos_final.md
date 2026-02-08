# IRONMIND - ARQUITETURA DEFINITIVA DE MODELOS
## 95% OFFLINE NPU | PREVIEW REAL-TIME | VOZ + VISÃO + SOM

---

## FILOSOFIA

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
│   99% processado na NPU do tablet.                             │
│   1% escala para cloud (e SÓ se tiver rede).                   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 1. STACK COMPLETA DE MODELOS

```
┌─────────────────────────────────────────────────────────────────┐
│                 IRONMIND MODEL STACK - FINAL                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ╔═══════════════════════════════════════════════════════════╗  │
│  ║  TIER 1 - PREVIEW REAL-TIME (cada frame, 30-60 FPS)      ║  │
│  ║  ─────────────────────────────────────────────────────    ║  │
│  ║  YOLO26n (INT8)           ← DETECTOR PRINCIPAL            ║  │
│  ║  ├─ 4.2 MB quantizado                                    ║  │
│  ║  ├─ NMS-free (end-to-end, zero pós-processamento)        ║  │
│  ║  ├─ 22ms latência / 60-120 FPS na NPU                    ║  │
│  ║  ├─ mAP: 51.3% COCO (pré fine-tune)                      ║  │
│  ║  ├─ Export: ONNX + TFLite (NNAPI)                         ║  │
│  ║  ├─ 43% mais rápido que YOLO11n                           ║  │
│  ║  └─ 95% das inspeções resolvidas aqui                     ║  │
│  ║                                                            ║  │
│  ║  YOLO-NAS-S (INT8)        ← FALLBACK 1 (robusto)         ║  │
│  ║  ├─ 6 MB quantizado                                      ║  │
│  ║  ├─ 35ms latência / 40-80 FPS                             ║  │
│  ║  ├─ mAP: 47.5% (melhor robustez a quantização)           ║  │
│  ║  └─ Ativa automaticamente se YOLO26n falhar               ║  │
│  ║                                                            ║  │
│  ║  YOLOv8n (INT8)           ← FALLBACK 2 (último recurso)  ║  │
│  ║  ├─ 5 MB quantizado                                      ║  │
│  ║  ├─ 25ms latência / 80-200 FPS                            ║  │
│  ║  ├─ mAP: 37.3% (menor precisão, maior velocidade)        ║  │
│  ║  └─ Ecossistema mais maduro, modo economia de bateria     ║  │
│  ╚═══════════════════════════════════════════════════════════╝  │
│                          ↓                                      │
│  ╔═══════════════════════════════════════════════════════════╗  │
│  ║  TIER 2 - SEGMENTAÇÃO (quando detecta defeito)            ║  │
│  ║  ─────────────────────────────────────────────────────    ║  │
│  ║  EdgeSAM (INT8)           ← CONTORNO DO DEFEITO           ║  │
│  ║  ├─ 9.4 MB                                               ║  │
│  ║  ├─ 80ms latência / 30+ FPS                               ║  │
│  ║  ├─ RepViT encoder (CNN, NPU-friendly)                    ║  │
│  ║  ├─ 37x mais rápido que SAM original                      ║  │
│  ║  ├─ mIoU: 0.72 (95% qualidade do SAM completo)           ║  │
│  ║  └─ Calcula: área (cm²), perímetro, severidade do dano   ║  │
│  ╚═══════════════════════════════════════════════════════════╝  │
│                          ↓                                      │
│  ╔═══════════════════════════════════════════════════════════╗  │
│  ║  TIER 3 - DIAGNÓSTICO LOCAL (operador toca ou pergunta)   ║  │
│  ║  ─────────────────────────────────────────────────────    ║  │
│  ║  Moondream 0.5B (INT8)    ← CÉREBRO LOCAL                ║  │
│  ║  ├─ 187 MB quantizado (INT8)                              ║  │
│  ║  ├─ 450ms latência (sob demanda, não real-time)           ║  │
│  ║  ├─ ~500 MB RAM pico                                      ║  │
│  ║  ├─ ONNX export + NNAPI                                   ║  │
│  ║  ├─ Descreve defeitos em português natural                ║  │
│  ║  ├─ "Mangueira hidráulica com abrasão, 60% desgaste"     ║  │
│  ║  ├─ Compara com peça de referência                        ║  │
│  ║  └─ 100% OFFLINE - zero cloud                             ║  │
│  ╚═══════════════════════════════════════════════════════════╝  │
│                          ↓                                      │
│  ╔═══════════════════════════════════════════════════════════╗  │
│  ║  TIER 4 - VOZ + SOM (EVA-Mobile integrado)                ║  │
│  ║  ─────────────────────────────────────────────────────    ║  │
│  ║  Whisper Small Q5 (ONNX)  ← OUVE O OPERADOR              ║  │
│  ║  ├─ 140 MB (sherpa_onnx)                                  ║  │
│  ║  ├─ 16kHz mono PCM                                        ║  │
│  ║  ├─ Português BR nativo                                   ║  │
│  ║  └─ 100% OFFLINE                                          ║  │
│  ║                                                            ║  │
│  ║  Piper TTS (ONNX)         ← FALA O RESULTADO             ║  │
│  ║  ├─ 15 MB modelo pt-BR                                    ║  │
│  ║  ├─ ~50ms síntese                                         ║  │
│  ║  ├─ Voz masculina clara (campo ruidoso)                   ║  │
│  ║  └─ 100% OFFLINE (não depende de engine Android)          ║  │
│  ║                                                            ║  │
│  ║  YAMNet (TFLite)          ← CLASSIFICA SONS DE MÁQUINA   ║  │
│  ║  ├─ 3 MB                                                  ║  │
│  ║  ├─ 521 classes base + fine-tune industrial               ║  │
│  ║  ├─ Detecta: motor batendo, vazamento, rolamento          ║  │
│  ║  └─ Background contínuo (sempre ouvindo)                  ║  │
│  ╚═══════════════════════════════════════════════════════════╝  │
│                          ↓                                      │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │  TIER 5 - CLOUD FALLBACK (só com internet, só 1%)         │ │
│  │  ─────────────────────────────────────────────────────    │ │
│  │  Gemini 2.0 Flash        ← ANÁLISE AVANÇADA               │ │
│  │  ├─ API Google (multimodal: imagem + texto + voz)         │ │
│  │  ├─ Latência: 500-1200ms                                  │ │
│  │  └─ Só quando Moondream local não resolve                 │ │
│  │                                                            │ │
│  │  Florence-2-Large        ← OCR + RELATÓRIOS               │ │
│  │  ├─ Vertex AI Custom Container                            │ │
│  │  ├─ Lê números de série, placas, códigos                  │ │
│  │  └─ Gera relatório de inspeção completo                   │ │
│  │                                                            │ │
│  │  Vertex AI AutoML        ← RETREINAMENTO CONTÍNUO         │ │
│  │  ├─ Fine-tune automático a cada 5000 imagens              │ │
│  │  ├─ A/B testing + OTA para tablets                        │ │
│  │  └─ Pipeline batch noturno                                │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. TABELA COMPARATIVA DOS MODELOS SELECIONADOS

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│  MODELOS DEFINITIVOS - IRONMIND                                                 │
├────┬─────────────────┬──────────┬─────────┬─────────┬────────┬─────────────────┤
│ #  │ MODELO          │ TAMANHO  │ LATÊNCIA│ FORMATO │ ONDE   │ FUNÇÃO          │
├────┼─────────────────┼──────────┼─────────┼─────────┼────────┼─────────────────┤
│ 1  │ YOLO26n         │ 4.2 MB   │ 22ms    │ ONNX    │ LOCAL  │ Detector        │
│    │                 │          │         │ TFLite  │ NPU    │ real-time       │
├────┼─────────────────┼──────────┼─────────┼─────────┼────────┼─────────────────┤
│ 2  │ YOLO-NAS-S      │ 6 MB     │ 35ms    │ ONNX    │ LOCAL  │ Fallback 1      │
│    │                 │          │         │ TFLite  │ NPU    │ (mais robusto)  │
├────┼─────────────────┼──────────┼─────────┼─────────┼────────┼─────────────────┤
│ 3  │ YOLOv8n         │ 5 MB     │ 25ms    │ ONNX    │ LOCAL  │ Fallback 2      │
│    │                 │          │         │ TFLite  │ NPU    │ (economia)      │
├────┼─────────────────┼──────────┼─────────┼─────────┼────────┼─────────────────┤
│ 4  │ EdgeSAM         │ 9.4 MB   │ 80ms    │ ONNX    │ LOCAL  │ Segmentação     │
│    │                 │          │         │         │ NPU    │ do defeito      │
├────┼─────────────────┼──────────┼─────────┼─────────┼────────┼─────────────────┤
│ 5  │ Moondream 0.5B  │ 187 MB   │ 450ms   │ ONNX    │ LOCAL  │ Diagnóstico     │
│    │                 │ (INT8)   │         │         │ NPU    │ em texto        │
├────┼─────────────────┼──────────┼─────────┼─────────┼────────┼─────────────────┤
│ 6  │ Whisper Small   │ 140 MB   │ ~180ms  │ ONNX    │ LOCAL  │ Voz → Texto     │
│    │ Q5              │          │         │ sherpa  │ CPU    │ (comandos)      │
├────┼─────────────────┼──────────┼─────────┼─────────┼────────┼─────────────────┤
│ 7  │ Piper TTS       │ 15 MB    │ ~50ms   │ ONNX    │ LOCAL  │ Texto → Voz     │
│    │ pt-BR           │          │         │         │ CPU    │ (respostas)     │
├────┼─────────────────┼──────────┼─────────┼─────────┼────────┼─────────────────┤
│ 8  │ YAMNet          │ 3 MB     │ RT      │ TFLite  │ LOCAL  │ Sons de         │
│    │                 │          │         │         │ NPU    │ máquina         │
├────┼─────────────────┼──────────┼─────────┼─────────┼────────┼─────────────────┤
│ 9  │ Gemini 2.0 Flash│ Cloud    │ 500ms+  │ API     │ CLOUD  │ Análise         │
│    │                 │          │         │ Google  │        │ avançada        │
├────┼─────────────────┼──────────┼─────────┼─────────┼────────┼─────────────────┤
│ 10 │ Florence-2-L    │ Cloud    │ 1-3s    │ ONNX    │ CLOUD  │ OCR +           │
│    │                 │          │         │ Vertex  │        │ Relatórios      │
├────┼─────────────────┼──────────┼─────────┼─────────┼────────┼─────────────────┤
│ 11 │ Vertex AI AutoML│ Cloud    │ Batch   │ AutoML  │ CLOUD  │ Retreinamento   │
│    │                 │          │         │         │        │ contínuo        │
├────┴─────────────────┴──────────┴─────────┴─────────┴────────┴─────────────────┤
│                                                                                 │
│  STORAGE LOCAL TOTAL: ~370 MB (todos os modelos offline)                       │
│  RAM NORMAL: ~250 MB (YOLO26n + Whisper + YAMNet + Piper)                     │
│  RAM PICO: ~850 MB (quando Moondream + EdgeSAM ativos)                        │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### Por que YOLO26n é o Primário

```
┌──────────────┬──────────┬──────────┬──────────┬────────────────┐
│   MODELO     │ TAMANHO  │  LATÊNCIA│   mAP    │  DIFERENCIAL   │
├──────────────┼──────────┼──────────┼──────────┼────────────────┤
│ YOLO26n      │  4.2 MB  │   22ms   │  51.3%   │ NMS-free       │
│ (Jan 2026)   │          │          │          │ End-to-end     │
│              │          │          │          │ ⭐ PRIMÁRIO    │
├──────────────┼──────────┼──────────┼──────────┼────────────────┤
│ YOLO-NAS-S   │  6.0 MB  │   35ms   │  47.5%   │ Quantização    │
│              │          │          │          │ mais robusta   │
│              │          │          │          │ Fallback 1     │
├──────────────┼──────────┼──────────┼──────────┼────────────────┤
│ YOLOv8n      │  5.0 MB  │   25ms   │  37.3%   │ Ecossistema    │
│              │          │          │          │ mais maduro    │
│              │          │          │          │ Fallback 2     │
└──────────────┴──────────┴──────────┴──────────┴────────────────┘

VANTAGENS DO YOLO26n:
├─ NMS-Free: Não precisa de Non-Maximum Suppression
│  └─ Reduz latência em 30% (de 35ms → 22ms)
├─ End-to-End: Uma única passada pela rede
│  └─ Menos código, menos erros
├─ Melhor mAP: 51.3% vs 47.5% (NAS) e 37.3% (v8n)
│  └─ Menos falsos positivos
└─ Arquitetura otimizada para NPUs mobile
```

---

## 3. 40 CLASSES DE DETECÇÃO

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
│  Modelo treinado com pares OK/DEFEITO para cada componente.    │
│  Operador aponta → sistema diz OK (verde) ou DEFEITO           │
│  (vermelho) + tipo específico do defeito.                      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 4. PIPELINE REAL-TIME - PREVIEW COM OVERLAY

```
┌─────────────────────────────────────────────────────────────────┐
│  PIPELINE DE CÂMERA - 30+ FPS COM DETECÇÃO AO VIVO            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  FRAME DA CÂMERA (30fps contínuo)                              │
│       │                                                         │
│       ├──→ [Buffer Circular - 3 frames]                        │
│       │         │                                               │
│       │         ▼                                               │
│       │    ┌─────────────────────────────────┐                 │
│       │    │  YOLO26n na NPU (22ms/frame)    │                 │
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
│       │    │  │   Vermelho = Defeito           │                 │
│       │    │  └─ FPS counter + status NPU      │                 │
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

### Pipeline Técnico - 3 Threads

```
THREAD 1 - CÂMERA (isolate Dart)
├─ CameraController.startImageStream()
├─ Formato: YUV420 → RGB888
├─ Resolução: 1920x1080 (captura) → 640x640 (inferência)
└─ Envia para Thread 2 via Isolate.spawn()

THREAD 2 - INFERÊNCIA NPU (isolate nativo)
├─ Recebe frame RGB 640x640
├─ ONNX Runtime + NNAPI delegate (NPU)
├─ YOLO26n.onnx (INT8, NMS-free)
├─ Inferência: 22ms
├─ Output: List<Detection> {box, class, confidence}
└─ Envia resultado para Thread 1

THREAD 1 - RENDER (UI thread)
├─ Recebe List<Detection>
├─ CustomPainter desenha overlay
├─ Bounding boxes + labels + cores
├─ Atualiza a cada frame (30fps)
└─ Zero jank (compositing nativo)

THREAD 3 - ÁUDIO (isolate background)
├─ YAMNet contínuo (som ambiente industrial)
├─ Whisper sob demanda (comando de voz)
└─ Piper TTS para respostas faladas
```

---

## 5. FLUXO COMPLETO DE DIAGNÓSTICO OFFLINE

```
┌─────────────────────────────────────────────────────────────────┐
│  JORNADA DO OPERADOR - 100% OFFLINE                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. OPERADOR LIGA O APP                                        │
│     ├─ Carrega YOLO26n na NPU (~500ms)                         │
│     ├─ Carrega Whisper na memória (~1s)                        │
│     ├─ YAMNet começa a ouvir (background)                      │
│     ├─ Piper TTS inicializa                                    │
│     └─ Camera preview inicia com overlay                       │
│                                                                 │
│  2. APONTA PARA A MÁQUINA                                      │
│     ├─ YOLO26n detecta componentes em tempo real (22ms)        │
│     ├─ Overlay mostra: "MOTOR", "CORREIA", "FILTRO", "PNEU"   │
│     ├─ Cores indicam estado: verde/amarelo/vermelho            │
│     └─ Operador VÊ os problemas no preview ao vivo            │
│                                                                 │
│  3. OPERADOR TOCA NUM DEFEITO (ou fala "diagnosticar")         │
│     │                                                           │
│     ├─ PASSO 3a: EdgeSAM segmenta o defeito (80ms)            │
│     │   ├─ Contorno preciso pixel-a-pixel                      │
│     │   ├─ Calcula área do dano (cm²)                          │
│     │   ├─ Calcula percentual de desgaste                      │
│     │   └─ Overlay: máscara semitransparente vermelha          │
│     │                                                           │
│     ├─ PASSO 3b: Moondream analisa a região (450ms)            │
│     │   ├─ Input: crop da região detectada                     │
│     │   ├─ Prompt: "Descreva o defeito desta peça mecânica"    │
│     │   ├─ Output: "Correia do alternador apresenta           │
│     │   │           fissuras laterais e desgaste de ~70%.      │
│     │   │           Risco de ruptura. Substituir."             │
│     │   └─ Texto aparece na tela                               │
│     │                                                           │
│     └─ PASSO 3c: Piper TTS fala o resultado (50ms)            │
│         ├─ "Atenção: correia do alternador com 70% de          │
│         │   desgaste. Risco de ruptura. Substituir."           │
│         └─ Operador ouve sem olhar para tela                   │
│                                                                 │
│  4. OPERADOR CONFIRMA OU CORRIGE (voz)                         │
│     ├─ "EVA, está correto" → salva diagnóstico                 │
│     ├─ "EVA, não é correia, é mangueira" → corrige label       │
│     └─ Correção vai para fila de retreinamento (sync futuro)   │
│                                                                 │
│  5. RELATÓRIO LOCAL                                            │
│     ├─ Salva em Hive/SQLite local                              │
│     ├─ Foto + segmentação + diagnóstico + GPS + timestamp      │
│     └─ Fila de sync para quando tiver internet                 │
│                                                                 │
│  6. SYNC QUANDO HOUVER INTERNET (background)                   │
│     ├─ Envia diagnósticos para BigQuery                        │
│     ├─ Imagens corrigidas → dataset de retreinamento           │
│     ├─ Verifica se há modelo novo (OTA)                        │
│     └─ Baixa atualizações só em Wi-Fi                          │
│                                                                 │
│  LATÊNCIA TOTAL DO DIAGNÓSTICO COMPLETO:                       │
│  22ms (YOLO) + 80ms (SAM) + 450ms (Moondream) + 50ms (TTS)   │
│  = ~600ms do toque ao operador ouvir o diagnóstico             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 6. ÁRVORE DE DECISÃO COMPLETA

```
┌─────────────────────────────────────────────────────────────────┐
│  DECISOR INTELIGENTE - QUANDO USAR CADA MODELO                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  [Frame da câmera - contínuo 30fps]                            │
│       │                                                         │
│       ▼                                                         │
│  ┌──────────────────┐                                          │
│  │  YOLO26n (22ms)  │ ← SEMPRE ATIVO (cada frame)             │
│  └──────────┬───────┘                                          │
│             │                                                   │
│             ├─── Nada detectado ──→ Preview limpo, continua    │
│             │                                                   │
│             ├─── Detectou OK (conf > 90%) ──→ Box VERDE        │
│             │    └─ 85% dos casos                              │
│             │    └─ TTS: "Aprovado"                            │
│             │    └─ Nenhuma ação adicional                     │
│             │                                                   │
│             ├─── Detectou DEFEITO (conf > 90%) ──→ Box VERM.  │
│             │    │  └─ 4% dos casos                            │
│             │    │                                              │
│             │    ├─ Vibração + som de alerta                    │
│             │    ├─ TTS: "Defeito detectado em [componente]"    │
│             │    │                                              │
│             │    └─ Operador toca ou fala "diagnosticar"?      │
│             │         │                                         │
│             │         ├─ SIM ──→ EdgeSAM (segmenta, 80ms)      │
│             │         │          └──→ Moondream (descreve,450ms)│
│             │         │               └──→ TTS fala diagnóstico│
│             │         │                                         │
│             │         └─ NÃO ──→ Continua preview, log local   │
│             │                                                   │
│             └─── INCERTO (conf 75-90%) ──→ Box AMARELO        │
│                  │  └─ 10% dos casos                           │
│                  │                                              │
│                  ├─ Moondream local (450ms)                     │
│                  │   └─ VQA: "Descreva o defeito"              │
│                  │   └─ AINDA 100% OFFLINE                     │
│                  │                                              │
│                  └─ Confiança < 75%? (1% dos casos)            │
│                       │                                         │
│                       ├─ Tem internet?                          │
│                       │    ├─ SIM ──→ Gemini 2.0 Flash (500ms) │
│                       │    │          └──→ Resultado cloud      │
│                       │    │                                    │
│                       │    └─ NÃO ──→ Retorna melhor palpite   │
│                       │               └──→ Flag "pendente"     │
│                       │                                         │
│                       └─ Confiança < 50%?                      │
│                            └─ TTS: "Não consigo identificar.   │
│                               Aproxime a câmera."              │
│                                                                 │
│  [YAMNet em paralelo - background contínuo]                    │
│       │                                                         │
│       └─── Som anormal detectado ──→ Alerta independente       │
│            ├─ TTS: "Som anormal: [tipo de som]"                │
│            ├─ Sugere inspeção visual                           │
│            └─ Grava 10s de áudio no relatório                  │
│                                                                 │
│  RESUMO DE LATÊNCIAS:                                          │
│  ├─ 85% casos: 22ms (YOLO só)                                 │
│  ├─ 10% casos: 472ms (YOLO + Moondream)                       │
│  ├─  4% casos: 552ms (YOLO + SAM + Moondream)                 │
│  └─  1% casos: 522ms (cloud) ou 472ms (offline fallback)      │
│                                                                 │
│  LATÊNCIA MÉDIA PONDERADA: ~70ms                               │
│  TAXA OFFLINE: 99%                                             │
│  TAXA CLOUD: 1% (e só se tiver rede)                          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 7. DETECÇÃO POR SOM - YAMNET INDUSTRIAL

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

## 8. COMANDOS DE VOZ - EVA-MOBILE INTEGRADO

```
┌─────────────────────────────────────────────────────────────────┐
│  COMANDOS DE VOZ DO OPERADOR (Whisper + Piper TTS)             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  WAKE WORD: "EVA" ou "IRON"                                   │
│                                                                 │
│  INSPEÇÃO:                                                     │
│  ├─ "EVA, diagnosticar"      → EdgeSAM + Moondream            │
│  ├─ "EVA, o que é isso?"     → Moondream descreve              │
│  ├─ "EVA, está bom?"         → Confiança do YOLO26n em voz    │
│  ├─ "EVA, capturar"          → Congela frame + analisa         │
│  ├─ "EVA, próxima peça"      → Reset overlay, novo scan       │
│  └─ "EVA, gravar defeito"    → Foto + diagnóstico → log       │
│                                                                 │
│  CORREÇÃO:                                                     │
│  ├─ "EVA, está correto"      → Confirma diagnóstico           │
│  ├─ "EVA, não é isso"        → Marca para revisão             │
│  ├─ "EVA, é uma mangueira"   → Corrige classe                 │
│  └─ "EVA, gravidade alta"    → Override severidade             │
│                                                                 │
│  RELATÓRIO:                                                    │
│  ├─ "EVA, resumo do dia"     → TTS com estatísticas           │
│  ├─ "EVA, quantos defeitos?" → Conta defeitos encontrados     │
│  ├─ "EVA, explicar"          → Moondream re-explica último    │
│  ├─ "EVA, por quê?"          → Moondream justifica reprovação │
│  └─ "EVA, enviar dados"      → Força sync (se tiver internet) │
│                                                                 │
│  NAVEGAÇÃO:                                                    │
│  ├─ "EVA, histórico"         → Abre tela de histórico         │
│  ├─ "EVA, estatísticas"      → Dashboard com métricas         │
│  ├─ "EVA, configurações"     → Abre settings                  │
│  └─ "EVA, repetir"           → Repete última resposta TTS     │
│                                                                 │
│  PROCESSAMENTO (100% local):                                   │
│  ├─ Whisper Small Q5 converte voz → texto (180ms)              │
│  ├─ Regex + intent matching local (sem cloud)                  │
│  ├─ Executa ação correspondente                                │
│  └─ Piper TTS responde com resultado (50ms)                    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 9. GESTÃO DE MEMÓRIA NPU

```
┌─────────────────────────────────────────────────────────────────┐
│  ESTRATÉGIA DE MEMÓRIA - TABLET 8-12GB RAM                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  SEMPRE CARREGADOS (warm):                                     │
│  ├─ YOLO26n (INT8)        →   ~20 MB RAM                      │
│  ├─ Whisper Small Q5      →  ~200 MB RAM                      │
│  ├─ YAMNet (TFLite)       →   ~10 MB RAM                      │
│  ├─ Piper TTS pt-BR       →   ~30 MB RAM                      │
│  └─ App + UI + Camera     →  ~150 MB RAM                      │
│  ─────────────────────────────────────────                     │
│  SUBTOTAL WARM:               ~410 MB RAM                      │
│                                                                 │
│  CARREGADOS SOB DEMANDA (lazy load):                           │
│  ├─ EdgeSAM              →  ~100 MB RAM (carrega em ~200ms)   │
│  ├─ Moondream 0.5B INT8  →  ~500 MB RAM (carrega em ~1s)      │
│  ├─ YOLO-NAS-S fallback  →   ~30 MB RAM                       │
│  └─ YOLOv8n fallback     →   ~15 MB RAM                       │
│                                                                 │
│  PICO MÁXIMO (tudo ativo):    ~1.0 GB RAM                      │
│  DISPONÍVEL (8GB tablet):     ~5 GB livres                     │
│  DISPONÍVEL (12GB tablet):    ~9 GB livres                     │
│                                                                 │
│  ESTRATÉGIA DE SWAP:                                           │
│  ├─ YOLO26n NUNCA descarrega (sempre em preview real-time)     │
│  ├─ Moondream carrega APENAS quando operador pede diagnóstico  │
│  ├─ Moondream descarrega após 30s de inatividade               │
│  ├─ EdgeSAM carrega quando YOLO detecta defeito                │
│  ├─ EdgeSAM descarrega após 10s sem detecção                   │
│  └─ Fallbacks só carregam se primário falhar (health check)    │
│                                                                 │
│  PRIORIDADE DE NPU:                                            │
│  ├─ 1º YOLO26n (real-time, não pode parar)                     │
│  ├─ 2º EdgeSAM (quando ativo, divide NPU com YOLO)            │
│  ├─ 3º Moondream (quando ativo, YOLO baixa para CPU temp.)    │
│  └─ 4º Whisper + YAMNet (sempre em CPU, NPU para visão)       │
│                                                                 │
│  FALLBACK AUTOMÁTICO:                                          │
│  ├─ YOLO26n falha? → YOLO-NAS-S assume (35ms, mais robusto)   │
│  ├─ YOLO-NAS-S falha? → YOLOv8n assume (25ms, maduro)         │
│  ├─ Bateria < 20%? → só YOLO26n, desliga Moondream/SAM        │
│  └─ Bateria < 10%? → só YOLOv8n (mais leve de todos)          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 10. ACELERAÇÃO NPU POR CHIPSET

```
┌─────────────────────────────────────────────────────────────────┐
│  COMO ATIVAR NPU EM CADA PLATAFORMA                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  QUALCOMM SNAPDRAGON (8 Gen 2/3, 8 Elite):                    │
│  ├─ SDK: QNN (Qualcomm Neural Network)                         │
│  ├─ Via: LiteRT com QNN Accelerator                            │
│  ├─ Ou: ONNX Runtime com QNN Execution Provider               │
│  ├─ NPU: Hexagon DSP (até 73 TOPS no 8 Elite)                 │
│  └─ Quantização: INT8 W8A8 (melhor performance)               │
│                                                                 │
│  SAMSUNG EXYNOS (1380, 2400):                                  │
│  ├─ SDK: Samsung ONE (On-device Neural Engine)                 │
│  ├─ Via: NNAPI (Android Neural Networks API)                   │
│  ├─ NPU: até 34.7 TOPS (Exynos 2400)                          │
│  └─ Quantização: INT8                                          │
│                                                                 │
│  MEDIATEK DIMENSITY (8300, 9300):                              │
│  ├─ SDK: NeuroPilot                                            │
│  ├─ Via: NNAPI                                                 │
│  ├─ NPU: APU 790 (até 46 TOPS)                                │
│  └─ Quantização: INT8/INT4                                     │
│                                                                 │
│  GOOGLE TENSOR (G4):                                           │
│  ├─ SDK: LiteRT nativo                                         │
│  ├─ Via: LiteRT com Google TPU delegate                        │
│  └─ Melhor integração TFLite do mercado                        │
│                                                                 │
│  CÓDIGO UNIVERSAL (funciona em todos via NNAPI):               │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  // ONNX Runtime - detecta NPU automaticamente          │  │
│  │  final sessionOptions = OrtSessionOptions()              │  │
│  │    ..appendExecutionProvider_Nnapi()                      │  │
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

## 11. TREINAMENTO: YOLO26n PARA MÁQUINAS PESADAS

### 11.1 Preparação do Dataset

```python
# Estrutura de pastas (formato YOLO)
dataset/
├── images/
│   ├── train/       # 80% (16.000 imagens)
│   ├── val/         # 10% (2.000 imagens)
│   └── test/        # 10% (2.000 imagens)
├── labels/
│   ├── train/
│   │   ├── img_001.txt  # <class> <x_center> <y_center> <w> <h>
│   │   └── ...
│   └── val/
└── data.yaml

# data.yaml
"""
train: ../images/train
val: ../images/val
test: ../images/test

nc: 40
names: [
  'correia_ok', 'correia_desgastada',
  'mangueira_ok', 'mangueira_vazando',
  'filtro_ok', 'filtro_sujo',
  'parafuso_ok', 'parafuso_solto',
  'pneu_ok', 'pneu_careca',
  'oleo_ok', 'oleo_vazando',
  'corrosao_leve', 'corrosao_grave',
  'solda_ok', 'solda_trincada',
  'vedacao_ok', 'vedacao_comprometida',
  'conexao_eletrica_ok', 'conexao_eletrica_solta',
  'implemento_ok', 'implemento_danificado',
  'eixo_carda_ok', 'eixo_carda_desgastado',
  'hidraulico_ok', 'hidraulico_vazando',
  'lamina_ok', 'lamina_gasta',
  'freio_ok', 'freio_gasto',
  'suspensao_ok', 'suspensao_danificada',
  'escapamento_ok', 'escapamento_furado',
  'carroceria_ok', 'carroceria_amassada',
  'esteira_ok', 'esteira_desgastada',
  'cacamba_ok', 'cacamba_trincada',
  'cilindro_ok', 'cilindro_vazando',
  'rolamento_ok', 'rolamento_ruidoso',
  'britador_ok', 'britador_desgastado'
]
"""

# Fontes de imagens (datasets.md):
# ├─ Construction Machines Images Dataset
# ├─ Heavy Equipment Construction Benchmark
# ├─ Damaged Car Parts (Roboflow)
# ├─ PPE and Heavy Machinery Detection
# ├─ Roboflow Universe: "truck parts", "mining equipment"
# └─ Imagens próprias de campo
#
# Quantidade mínima: 500 imagens por classe × 40 = 20.000 base
# Com augmentação 3x = 60.000 imagens de treino
```

### 11.2 Fine-Tuning

```python
from ultralytics import YOLO

model = YOLO('yolo26n.pt')  # pré-treinado COCO

results = model.train(
    data='dataset/data.yaml',
    epochs=200,
    imgsz=640,
    batch=32,
    device=0,

    # Early stopping
    patience=50,

    # Augmentações otimizadas para peças mecânicas
    augment=True,
    hsv_h=0.015,
    hsv_s=0.7,
    hsv_v=0.4,
    degrees=10,        # Rotação leve (peças em ângulos)
    translate=0.1,
    scale=0.5,
    flipud=0.0,        # SEM flip vertical (orientação importa)
    fliplr=0.5,
    mosaic=1.0,
    mixup=0.1,

    # Otimizador
    optimizer='AdamW',
    lr0=0.001,
    lrf=0.01,
    momentum=0.937,
    weight_decay=0.0005,

    # Regularização
    label_smoothing=0.05,

    # Salvar
    save=True,
    save_period=10,
    cache=True,
    workers=8,

    project='ironmind',
    name='yolo26n_v1'
)

# Melhor modelo: ironmind/yolo26n_v1/weights/best.pt
```

### 11.3 Validação e Benchmark

```python
# Avaliar no test set
metrics = model.val(
    data='dataset/data.yaml',
    split='test',
    imgsz=640,
    batch=1,
    conf=0.5,
    iou=0.6
)

print(f"mAP50: {metrics.box.map50:.3f}")
print(f"mAP50-95: {metrics.box.map:.3f}")
print(f"Precision: {metrics.box.mp:.3f}")
print(f"Recall: {metrics.box.mr:.3f}")

# Benchmark de velocidade
import time, numpy as np

for _ in range(100):  # Warmup
    model.predict('test_image.jpg', verbose=False)

times = []
for _ in range(1000):
    start = time.time()
    model.predict('test_image.jpg', verbose=False, device=0)
    times.append((time.time() - start) * 1000)

print(f"Latência média: {np.mean(times):.1f}ms")
print(f"FPS: {1000/np.mean(times):.1f}")
```

### 11.4 Export para NPU Mobile

```python
# Export ONNX (para NNAPI/QNN)
model.export(
    format='onnx',
    imgsz=640,
    simplify=True,
    opset=13,
    dynamic=False     # Shape fixo = melhor NPU
)

# Export TFLite INT8 (alternativa)
model.export(
    format='tflite',
    imgsz=640,
    int8=True,
    data='dataset/data.yaml',  # Calibração
    nms=False                  # YOLO26 já é NMS-free!
)
# Saída: ~4.2 MB (best_int8.tflite)

# Verificar modelo
import tensorflow as tf

interpreter = tf.lite.Interpreter(model_path="best_int8.tflite")
interpreter.allocate_tensors()

input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()

print("Input:", input_details[0]['shape'], input_details[0]['dtype'])
print("Output:", output_details[0]['shape'])
print("Size:", os.path.getsize("best_int8.tflite") / 1024**2, "MB")
```

---

## 12. IMPLEMENTAÇÃO FLUTTER - CÓDIGO COMPLETO

### 12.1 Motor de Inferência YOLO26n

```dart
class YoloInferenceEngine {
  late OrtSession _session;

  Future<void> initialize() async {
    final modelBytes = await rootBundle.load(
      'assets/models/yolo26n_ironmind_int8.onnx'
    );

    final options = OrtSessionOptions()
      ..setInterOpNumThreads(4)
      ..setIntraOpNumThreads(4)
      ..setSessionGraphOptimizationLevel(
        GraphOptimizationLevel.ortEnableAll
      );

    // Ativar NPU via NNAPI (funciona em Snapdragon/Exynos/MediaTek)
    if (Platform.isAndroid) {
      options.appendExecutionProvider_Nnapi();
    }
    if (Platform.isIOS) {
      options.appendExecutionProvider_CoreML();
    }

    _session = OrtSession.fromBuffer(
      modelBytes.buffer.asUint8List(),
      options
    );
  }

  Future<List<Detection>> predict(Uint8List imageBytes) async {
    // 1. Pré-processamento
    final preprocessed = _preprocessImage(imageBytes);

    // 2. Criar tensor de entrada
    final inputOrt = OrtValueTensor.createTensorWithDataList(
      preprocessed,
      [1, 3, 640, 640]
    );

    // 3. Inferência NPU (22ms)
    final startTime = DateTime.now();
    final outputs = await _session.runAsync(
      OrtRunOptions(),
      {'images': inputOrt}
    );
    final latency = DateTime.now().difference(startTime).inMilliseconds;

    // 4. Pós-processamento (NMS-free no YOLO26)
    final rawOutput = outputs[0]?.value as List<List<List<double>>>;
    final detections = _postProcess(rawOutput);

    inputOrt.release();
    outputs.forEach((o) => o?.release());

    return detections;
  }

  List<double> _preprocessImage(Uint8List imageBytes) {
    final image = img.decodeImage(imageBytes)!;
    final resized = img.copyResize(image, width: 640, height: 640);

    // CHW format (channels first), normalizado [0,1]
    final pixels = <double>[];
    for (int c = 0; c < 3; c++) {
      for (int y = 0; y < 640; y++) {
        for (int x = 0; x < 640; x++) {
          final pixel = resized.getPixel(x, y);
          final value = c == 0 ? pixel.r : (c == 1 ? pixel.g : pixel.b);
          pixels.add(value / 255.0);
        }
      }
    }
    return pixels;
  }

  List<Detection> _postProcess(List<List<List<double>>> output) {
    // YOLO26 NMS-free: output já é final
    final detections = <Detection>[];
    final predictions = output[0];

    for (final pred in predictions) {
      final objectness = pred[4];
      if (objectness < 0.5) continue;

      final classProbs = pred.sublist(5);
      final maxClassIdx = classProbs.indexOf(classProbs.reduce(max));
      final confidence = objectness * classProbs[maxClassIdx];

      if (confidence < 0.6) continue;

      detections.add(Detection(
        bbox: BoundingBox(
          xCenter: pred[0], yCenter: pred[1],
          width: pred[2], height: pred[3],
        ),
        classId: maxClassIdx,
        className: _classNames[maxClassIdx],
        confidence: confidence,
      ));
    }

    return detections;
    // NMS não necessário - YOLO26 é end-to-end
  }
}
```

### 12.2 Moondream VLM - Diagnóstico Local

```dart
class MoondreamDiagnostic {
  late OrtSession _session;
  late Tokenizer _tokenizer;
  bool _isLoaded = false;

  /// Lazy load - só carrega quando operador pede diagnóstico
  Future<void> ensureLoaded() async {
    if (_isLoaded) return;

    final modelBytes = await rootBundle.load(
      'assets/models/moondream_mobile_int8.onnx'
    );

    _session = OrtSession.fromBuffer(
      modelBytes.buffer.asUint8List(),
      OrtSessionOptions()..appendExecutionProvider_Nnapi()
    );

    _tokenizer = await Tokenizer.fromAsset('assets/tokenizers/moondream.json');
    _isLoaded = true;
  }

  /// Descarrega após 30s sem uso (economia de RAM)
  Future<void> unload() async {
    if (!_isLoaded) return;
    _session.release();
    _isLoaded = false;
  }

  Future<DiagnosticResult> diagnose(
    Uint8List imageBytes,
    String question
  ) async {
    await ensureLoaded();

    // 1. Processar imagem (378×378 para Moondream)
    final processedImage = await _preprocessImage(imageBytes);

    // 2. Tokenizar pergunta em português
    final prompt =
      "<|im_start|>user\n<image>\n$question<|im_end|>\n<|im_start|>assistant\n";
    final tokens = _tokenizer.encode(prompt);

    // 3. Criar tensores
    final inputIds = OrtValueTensor.createTensorWithDataList(
      tokens.map((t) => t.toDouble()).toList(),
      [1, tokens.length]
    );
    final pixelValues = OrtValueTensor.createTensorWithDataList(
      processedImage,
      [1, 3, 378, 378]
    );

    // 4. Inferência (450ms)
    final startTime = DateTime.now();
    final outputs = await _session.runAsync(
      OrtRunOptions(),
      {'input_ids': inputIds, 'pixel_values': pixelValues}
    );
    final latency = DateTime.now().difference(startTime).inMilliseconds;

    // 5. Decodificar resposta
    final logits = outputs[0]?.value as List<List<List<double>>>;
    final generatedTokens = _sample(logits[0], maxTokens: 100);
    final response = _tokenizer.decode(generatedTokens);

    inputIds.release();
    pixelValues.release();
    outputs.forEach((o) => o?.release());

    return DiagnosticResult(
      description: response,
      latencyMs: latency,
      confidence: _estimateConfidence(logits)
    );
  }

  List<int> _sample(List<List<double>> logits, {int maxTokens = 100}) {
    final tokens = <int>[];
    for (int i = 0; i < maxTokens; i++) {
      final probs = _softmax(logits.last);
      final nextToken = _topKSampling(probs, k: 10);
      if (nextToken == _tokenizer.eosTokenId) break;
      tokens.add(nextToken);
    }
    return tokens;
  }
}
```

### 12.3 EdgeSAM - Segmentação de Defeitos

```dart
class EdgeSAMSegmenter {
  late OrtSession _session;
  bool _isLoaded = false;

  /// Lazy load - só quando YOLO detecta defeito
  Future<void> ensureLoaded() async {
    if (_isLoaded) return;
    final modelBytes = await rootBundle.load(
      'assets/models/edge_sam_mobile_int8.onnx'
    );
    _session = OrtSession.fromBuffer(
      modelBytes.buffer.asUint8List(),
      OrtSessionOptions()..appendExecutionProvider_Nnapi()
    );
    _isLoaded = true;
  }

  Future<void> unload() async {
    if (!_isLoaded) return;
    _session.release();
    _isLoaded = false;
  }

  Future<SegmentationMask> segment(
    Uint8List imageBytes,
    Point defectCenter  // Centro do bounding box do YOLO
  ) async {
    await ensureLoaded();

    // 1. Pré-processar (1024×1024 para SAM)
    final image = await _preprocessForSAM(imageBytes);

    // 2. Ponto de prompt (centro do defeito)
    final coordsOrt = OrtValueTensor.createTensorWithDataList(
      [defectCenter.x.toDouble(), defectCenter.y.toDouble()],
      [1, 1, 2]
    );
    final labelsOrt = OrtValueTensor.createTensorWithDataList(
      [1.0],  // 1 = foreground
      [1, 1]
    );
    final imageOrt = OrtValueTensor.createTensorWithDataList(
      image, [1, 3, 1024, 1024]
    );

    // 3. Inferência (80ms)
    final outputs = await _session.runAsync(
      OrtRunOptions(),
      {'image': imageOrt, 'point_coords': coordsOrt, 'point_labels': labelsOrt}
    );

    // 4. Extrair melhor máscara
    final masks = outputs[0]?.value as List<List<List<List<double>>>>;
    final iouScores = outputs[1]?.value as List<double>;
    final bestIdx = iouScores.indexOf(iouScores.reduce(max));

    imageOrt.release();
    coordsOrt.release();
    labelsOrt.release();
    outputs.forEach((o) => o?.release());

    return SegmentationMask(
      mask: _binaryMask(masks[0][bestIdx]),
      iouScore: iouScores[bestIdx],
      boundingBox: _maskToBBox(masks[0][bestIdx])
    );
  }

  Uint8List _binaryMask(List<List<double>> mask) {
    final binary = Uint8List(mask.length * mask[0].length);
    int idx = 0;
    for (final row in mask) {
      for (final value in row) {
        binary[idx++] = value > 0.5 ? 255 : 0;
      }
    }
    return binary;
  }
}
```

### 12.4 Controlador de Voz EVA

```dart
class EVAVoiceController {
  late WhisperSTT _stt;       // Whisper Small Q5 (140MB)
  late PiperTTS _tts;         // Piper pt-BR (15MB)
  final MoondreamDiagnostic _moondream;

  final Map<String, VoiceCommand> _commands = {
    'diagnosticar': VoiceCommand.diagnose,
    'capturar': VoiceCommand.capture,
    'inspecionar': VoiceCommand.inspect,
    'repetir': VoiceCommand.repeat,
    'histórico': VoiceCommand.history,
    'explicar': VoiceCommand.explain,
    'por que': VoiceCommand.why,
    'por quê': VoiceCommand.why,
    'estatísticas': VoiceCommand.stats,
    'resumo': VoiceCommand.stats,
    'está correto': VoiceCommand.confirm,
    'correto': VoiceCommand.confirm,
    'não é isso': VoiceCommand.reject,
    'gravar defeito': VoiceCommand.save,
    'enviar dados': VoiceCommand.sync,
    'próxima peça': VoiceCommand.next,
    'gravidade alta': VoiceCommand.severityHigh,
  };

  Future<void> processVoice() async {
    final audioStream = await _captureAudio();  // 16kHz mono
    final transcription = await _stt.transcribe(audioStream);  // 180ms
    final command = _parseCommand(transcription);

    if (command != null) {
      await _executeCommand(command, context: transcription);
    } else {
      await speak("Comando não reconhecido. Repita por favor.");
    }
  }

  Future<void> _executeCommand(VoiceCommand cmd, {String? context}) async {
    switch (cmd) {
      case VoiceCommand.diagnose:
        await _triggerDiagnosis();
        break;

      case VoiceCommand.explain:
        final lastResult = await _getLastInspection();
        if (lastResult.className != 'OK') {
          final explanation = await _moondream.diagnose(
            lastResult.imageBytes,
            "Explique em detalhes por que esta peça foi reprovada"
          );
          await speak(explanation.description);
        } else {
          await speak("Última peça aprovada. Sem defeitos.");
        }
        break;

      case VoiceCommand.stats:
        final stats = await _getTodayStats();
        await speak(
          "Hoje: ${stats.total} inspeções. "
          "${stats.approved} aprovadas, ${stats.rejected} reprovadas. "
          "Taxa: ${stats.approvalRate.toStringAsFixed(1)}%"
        );
        break;

      case VoiceCommand.confirm:
        await _confirmLastInspection();
        await speak("Diagnóstico confirmado e salvo.");
        break;

      case VoiceCommand.reject:
        await _rejectLastInspection();
        await speak("Marcado para revisão.");
        break;

      default:
        await speak("Comando em desenvolvimento.");
    }
  }

  Future<void> speak(String text) async {
    final audioBytes = await _tts.synthesize(
      text,
      voice: 'pt-BR-male',
      speed: 1.0
    );
    await _playAudio(audioBytes);  // ~50ms
  }
}
```

### 12.5 Widget Principal - Preview Real-Time

```dart
class InspectionPreviewWidget extends StatefulWidget {
  @override
  _InspectionPreviewState createState() => _InspectionPreviewState();
}

class _InspectionPreviewState extends State<InspectionPreviewWidget> {
  CameraController? _camera;
  YoloInferenceEngine? _yolo;
  EdgeSAMSegmenter? _sam;
  MoondreamDiagnostic? _moondream;
  EVAVoiceController? _eva;

  List<Detection> _detections = [];
  SegmentationMask? _mask;
  String? _diagnosis;
  int _fps = 0;

  @override
  void initState() {
    super.initState();
    _initializeAll();
  }

  Future<void> _initializeAll() async {
    _yolo = YoloInferenceEngine();
    _sam = EdgeSAMSegmenter();
    _moondream = MoondreamDiagnostic();
    _eva = EVAVoiceController(_moondream!);

    await _yolo!.initialize();
    // SAM e Moondream são lazy-loaded

    _camera = CameraController(
      cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
    );
    await _camera!.initialize();
    _startRealTimeInference();
  }

  void _startRealTimeInference() {
    int frameCount = 0;
    DateTime lastFpsUpdate = DateTime.now();

    Timer.periodic(Duration(milliseconds: 33), (timer) async {
      if (_camera == null || !_camera!.value.isInitialized) return;

      final image = await _camera!.takePicture();
      final bytes = await image.readAsBytes();

      // YOLO inference na NPU (22ms)
      final detections = await _yolo!.predict(bytes);

      // FPS counter
      frameCount++;
      if (DateTime.now().difference(lastFpsUpdate).inSeconds >= 1) {
        setState(() => _fps = frameCount);
        frameCount = 0;
        lastFpsUpdate = DateTime.now();
      }

      // Se detectou defeito, segmentar (lazy load EdgeSAM)
      SegmentationMask? mask;
      if (detections.any((d) => d.className.contains('desgast') ||
                                d.className.contains('vazando') ||
                                d.className.contains('gast') ||
                                d.className.contains('trincad'))) {
        final defect = detections.firstWhere(
          (d) => d.confidence > 0.7 && !d.className.contains('_ok')
        );
        mask = await _sam!.segment(bytes, defect.bbox.center);
      }

      setState(() {
        _detections = detections;
        _mask = mask;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Camera preview
        if (_camera != null && _camera!.value.isInitialized)
          CameraPreview(_camera!)
        else
          Center(child: CircularProgressIndicator()),

        // Bounding boxes YOLO
        CustomPaint(
          painter: DetectionOverlayPainter(_detections),
          child: Container(),
        ),

        // Máscara de segmentação SAM
        if (_mask != null)
          CustomPaint(
            painter: SegmentationOverlayPainter(_mask!),
            child: Container(),
          ),

        // HUD
        Positioned(
          top: 16, left: 16,
          child: Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('FPS: $_fps', style: TextStyle(color: Colors.white)),
                Text('NPU: ATIVO', style: TextStyle(color: Colors.green)),
                Text('OFFLINE', style: TextStyle(color: Colors.cyan)),
                if (_detections.isNotEmpty)
                  Text('${_detections.length} detecções',
                    style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ),

        // Diagnóstico texto
        if (_diagnosis != null)
          Positioned(
            bottom: 120, left: 16, right: 16,
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_diagnosis!,
                style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ),

        // Botões
        Positioned(
          bottom: 32, left: 0, right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Botão diagnosticar
              FloatingActionButton(
                onPressed: _triggerDiagnosis,
                backgroundColor: Colors.orange,
                child: Icon(Icons.search),
                tooltip: 'Diagnosticar',
              ),
              // Botão voz
              FloatingActionButton(
                onPressed: () => _eva!.processVoice(),
                backgroundColor: Colors.blue,
                child: Icon(Icons.mic),
                tooltip: 'Comando de voz',
              ),
              // Botão histórico
              FloatingActionButton(
                onPressed: _openHistory,
                backgroundColor: Colors.grey,
                child: Icon(Icons.history),
                tooltip: 'Histórico',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _triggerDiagnosis() async {
    if (_detections.isEmpty) {
      _eva!.speak("Nenhum componente detectado. Aponte a câmera.");
      return;
    }

    // Pegar frame atual
    final image = await _camera!.takePicture();
    final bytes = await image.readAsBytes();

    // EdgeSAM + Moondream
    final defect = _detections.firstWhere(
      (d) => !d.className.contains('_ok'),
      orElse: () => _detections.first,
    );

    final mask = await _sam!.segment(bytes, defect.bbox.center);
    final diagnosis = await _moondream!.diagnose(
      bytes,
      "Descreva o defeito desta peça mecânica e recomende ação"
    );

    setState(() {
      _mask = mask;
      _diagnosis = diagnosis.description;
    });

    // Falar resultado
    _eva!.speak(diagnosis.description);
  }
}

// Painter para bounding boxes
class DetectionOverlayPainter extends CustomPainter {
  final List<Detection> detections;
  DetectionOverlayPainter(this.detections);

  @override
  void paint(Canvas canvas, Size size) {
    for (final det in detections) {
      final isDefect = !det.className.contains('_ok');

      final paint = Paint()
        ..color = isDefect
          ? Colors.red.withOpacity(0.7)
          : Colors.green.withOpacity(0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;

      final rect = Rect.fromCenter(
        center: Offset(
          det.bbox.xCenter * size.width,
          det.bbox.yCenter * size.height,
        ),
        width: det.bbox.width * size.width,
        height: det.bbox.height * size.height,
      );
      canvas.drawRect(rect, paint);

      // Label
      final textSpan = TextSpan(
        text: '${det.className} ${(det.confidence * 100).toStringAsFixed(0)}%',
        style: TextStyle(
          color: Colors.white, fontSize: 14,
          backgroundColor: isDefect ? Colors.red : Colors.green,
        ),
      );
      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset(rect.left, rect.top - 18));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Painter para máscara de segmentação
class SegmentationOverlayPainter extends CustomPainter {
  final SegmentationMask mask;
  SegmentationOverlayPainter(this.mask);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red.withOpacity(0.4)
      ..style = PaintingStyle.fill;

    final path = _maskToPath(mask.mask, size);
    canvas.drawPath(path, paint);

    // Contorno
    final border = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(path, border);
  }

  Path _maskToPath(Uint8List mask, Size size) {
    // Marching squares para converter máscara binária em Path
    final path = Path();
    // ... implementação
    return path;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
```

### 12.6 Fluxo de Inspeção Completo

```dart
class InspectionOrchestrator {
  final YoloInferenceEngine _yolo;
  final MoondreamDiagnostic _moondream;
  final EdgeSAMSegmenter _sam;
  final EVAVoiceController _eva;

  Future<InspectionResult> inspect(Uint8List imageBytes) async {
    // 1. YOLO detection (22ms)
    final yoloResult = await _yolo.predict(imageBytes);

    // 2. Se confiança > 90%, retorna imediato
    if (yoloResult.isNotEmpty &&
        yoloResult.first.confidence > 0.90 &&
        yoloResult.first.className.contains('_ok')) {
      _eva.speak("Peça aprovada");
      return InspectionResult.approved(yoloResult);
    }

    // 3. Se defeito detectado com alta confiança
    final defects = yoloResult.where(
      (d) => !d.className.contains('_ok') && d.confidence > 0.75
    ).toList();

    if (defects.isNotEmpty) {
      // EdgeSAM segmenta (80ms)
      final mask = await _sam.segment(
        imageBytes, defects.first.bbox.center
      );

      // Moondream diagnostica (450ms)
      final diagnosis = await _moondream.diagnose(
        imageBytes,
        "Qual o defeito principal nesta peça?"
      );

      // TTS fala (50ms)
      _eva.speak("Peça reprovada. ${diagnosis.description}");

      return InspectionResult(
        classification: defects.first.className,
        confidence: defects.first.confidence,
        explanation: diagnosis.description,
        defectMask: mask,
        latencyMs: 22 + 80 + 450,  // ~552ms total
        source: 'YOLO26n + EdgeSAM + Moondream',
        isOffline: true,
      );
    }

    // 4. Se incerto (75-90%), Moondream analisa
    if (yoloResult.isNotEmpty && yoloResult.first.confidence > 0.65) {
      final diagnosis = await _moondream.diagnose(
        imageBytes,
        "Descreva qualquer defeito visível nesta peça mecânica"
      );
      return InspectionResult(
        classification: yoloResult.first.className,
        confidence: yoloResult.first.confidence,
        explanation: diagnosis.description,
        latencyMs: 22 + 450,
        source: 'YOLO26n + Moondream',
        isOffline: true,
      );
    }

    // 5. Se confiança muito baixa, pedir confirmação
    _eva.speak("Não tenho certeza. Aproxime a câmera ou confirme por voz.");
    return InspectionResult(
      classification: 'Incerto',
      confidence: yoloResult.isEmpty ? 0.0 : yoloResult.first.confidence,
      requiresReview: true,
      isOffline: true,
    );
  }
}
```

---

## 13. CLOUD FALLBACK - GOOGLE ALL-IN

```
┌─────────────────────────────────────────────────────────────────┐
│  CLOUD (SÓ COM INTERNET, SÓ 1% DOS CASOS)                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  REGRA: Cloud é LUXO. Sistema funciona 100% sem ele.           │
│                                                                 │
│  TRIGGER PARA CLOUD:                                           │
│  ├─ Operador pede: "EVA, consultar na nuvem"                   │
│  ├─ Confiança local < 50% E internet disponível               │
│  ├─ Sync automático em background (Wi-Fi only)                 │
│  └─ Retreinamento batch (5000+ imagens acumuladas)             │
│                                                                 │
│  SERVIÇOS GOOGLE:                                              │
│  ├─ Gemini 2.0 Flash → Análise multimodal avançada             │
│  │   └─ Custo: ~$0.003/consulta, ~$1.50/mês                   │
│  ├─ Florence-2-Large → OCR + relatórios (Vertex AI)            │
│  │   └─ Custo: ~$0.005/consulta, ~$0.50/mês                   │
│  ├─ Vertex AI AutoML → Retreinamento contínuo do YOLO26n       │
│  ├─ BigQuery → Analytics de toda frota                         │
│  ├─ Cloud Storage → Backup + dataset versionado                │
│  ├─ Firebase → Auth + Crashlytics + FCM                        │
│  └─ Looker Studio → Dashboard de gestão                        │
│                                                                 │
│  CUSTO CLOUD TOTAL: ~$4.50/mês por veículo                     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 14. ESTRUTURA DE FICHEIROS NO TABLET

```
ironmind_app/
├── assets/
│   ├── models/
│   │   ├── yolo26n_ironmind_int8.onnx       #  4.2 MB  ⭐ PRIMÁRIO
│   │   ├── yolo_nas_s_int8.onnx             #  6.0 MB  fallback 1
│   │   ├── yolov8n_int8.tflite              #  5.0 MB  fallback 2
│   │   ├── moondream_mobile_int8.onnx       # 187  MB  diagnóstico
│   │   ├── edge_sam_mobile_int8.onnx        #  9.4 MB  segmentação
│   │   ├── whisper_small_q5.onnx            # 140  MB  STT
│   │   ├── piper_tts_pt_br.onnx            #  15  MB  TTS
│   │   └── yamnet.tflite                    #   3  MB  sons
│   │
│   │   TOTAL: ~370 MB
│   │
│   ├── tokenizers/
│   │   ├── moondream_tokenizer.json
│   │   └── whisper_tokenizer.json
│   │
│   └── config/
│       ├── classes_ironmind.yaml            # 40 classes
│       ├── thresholds.yaml                  # confiança por classe
│       └── voice_commands_pt.yaml           # 16 comandos
│
├── lib/
│   ├── models/
│   │   ├── yolo26n_engine.dart              # Inferência YOLO26n
│   │   ├── yolo_nas_fallback.dart           # Fallback YOLO-NAS-S
│   │   ├── moondream_vlm.dart               # VLM diagnóstico
│   │   ├── edgesam_segmenter.dart           # Segmentação
│   │   └── model_manager.dart               # Lazy load + fallback
│   │
│   ├── voice/
│   │   ├── eva_controller.dart              # Orquestrador de voz
│   │   ├── whisper_stt.dart                 # Speech-to-text
│   │   ├── piper_tts.dart                   # Text-to-speech
│   │   ├── yamnet_classifier.dart           # Sons industriais
│   │   └── voice_commands.dart              # Parser + intent
│   │
│   ├── ui/
│   │   ├── inspection_preview.dart          # Preview 30fps
│   │   ├── detection_overlay.dart           # Bounding boxes
│   │   ├── segmentation_overlay.dart        # Máscaras
│   │   └── hud_widget.dart                  # FPS, status, NPU
│   │
│   ├── logic/
│   │   ├── inspection_orchestrator.dart     # Fluxo principal
│   │   ├── uncertainty_analyzer.dart        # Shannon entropy
│   │   ├── offline_queue.dart               # Fila sem rede
│   │   └── cloud_fallback.dart              # Gemini + Florence
│   │
│   └── data/
│       ├── local_database.dart              # Hive/SQLite
│       ├── inspection_repository.dart       # CRUD inspeções
│       └── sync_manager.dart                # Sync background
│
└── pubspec.yaml
    dependencies:
      camera, onnxruntime, tflite_flutter, hive,
      dio, flutter_bloc, image, path_provider,
      permission_handler, audioplayers, record
```

---

## 15. CUSTOS

```
┌─────────────────────────────────────────────────────────────────┐
│  CUSTO MENSAL POR VEÍCULO                                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  EDGE (99% dos casos): $0.00 (pago no CAPEX)                  │
│  Cloud (1% fallback):  $0.05/mês                               │
│  Conectividade 4G/5G:  $25/mês (sync, OTA, telemetria)        │
│  Storage cloud:        $1/mês                                  │
│  ──────────────────────────────────────────                    │
│  TOTAL: $26.05/mês por veículo                                 │
│                                                                 │
│  ROI: Economiza 5h/mês × $20/h = $100/mês                     │
│  Lucro líquido: $73.95/mês                                     │
│  Payback CAPEX ($985): ~13 meses                               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 16. ROADMAP (12 SEMANAS)

```
SEMANA 1-2: YOLO26n EDGE
├─ Setup dataset (anotações, 40 classes, formato YOLO)
├─ Fine-tune YOLO26n (Vertex AI ou Colab)
├─ Export ONNX INT8 + TFLite INT8
├─ Benchmark no tablet real
└─ Meta: 22ms @ 90%+ precisão

SEMANA 3-4: APP FLUTTER + PREVIEW REAL-TIME
├─ Copiar EVA-Mobile → IronMobile (base)
├─ Remover módulos saúde/idosos
├─ Camera preview + loop 30fps
├─ Overlay bounding boxes (CustomPainter)
├─ HUD (FPS, confiança, status NPU)
└─ Meta: Preview fluido sem jank

SEMANA 5-6: MOONDREAM VLM + EDGESAM
├─ Converter Moondream para ONNX INT8 (187MB)
├─ Integrar diagnóstico sob demanda (450ms)
├─ Exportar EdgeSAM para ONNX INT8
├─ Segmentação on-demand + overlay de máscara
├─ Gestão de memória (lazy load/unload)
└─ Meta: Diagnóstico completo 100% offline

SEMANA 7-8: VOZ EVA-MOBILE
├─ Adaptar Whisper Small Q5 (comandos PT-BR)
├─ Integrar Piper TTS (respostas faladas)
├─ Parser de 16 comandos de voz
├─ Fine-tune YAMNet para sons industriais
└─ Meta: Mãos-livres completo

SEMANA 9-10: FALLBACKS + POLIMENTO
├─ Integrar YOLO-NAS-S (fallback 1)
├─ Integrar YOLOv8n (fallback 2 / economia bateria)
├─ Health check automático + switch
├─ Modo bateria baixa (< 20%: só YOLO26n)
└─ Meta: Zero downtime

SEMANA 11: CLOUD FALLBACK
├─ API Gemini 2.0 Flash (análise avançada)
├─ Florence-2 no Vertex AI (OCR + relatórios)
├─ Sync background (Wi-Fi only)
├─ Fila offline para casos sem rede
└─ Meta: < 1% escalação cloud

SEMANA 12: TESTES DE CAMPO
├─ Deploy em 5 veículos piloto
├─ Calibração de thresholds por tipo de máquina
├─ Otimização de bateria
├─ Documentação completa
└─ Meta: Produção-ready

SEMANA 13+: ROLLOUT
└─ Deploy para frota (100+ tablets)
```

---

**ESTE É O DOCUMENTO DEFINITIVO. O melhor dos dois mundos: arquitetura completa + código implementável. Offline first, NPU always.**
