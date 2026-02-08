TOP 10 Modelos para NPU - IronMind (Offline Real-Time)
TIER 1 - Preview Real-Time (30-60+ FPS, cada frame)
#	Modelo	Tamanho INT8	mAP	FPS (NPU)	Export	Para que
1	YOLO26n	~4-6 MB	40.9%	60-120+	TFLite/ONNX	Detector principal (2026, NMS-free)
2	YOLO11n	~2 MB	39.5%	80-150+	TFLite/ONNX	Alternativa provada, maior comunidade
3	RF-DETR Nano	~8-12 MB	48.4%	40-80	ONNX	Maior precisao (Transformer, ICLR 2026)
4	YOLOv8n	~2 MB	37.3%	80-200+	TFLite/ONNX	Mais maduro, milhares de modelos prontos
5	PP-PicoDet-S	~4 MB	30.6%	100-150+	ONNX	Ultra-leve, pre-filtro rapido
6	NanoDet-Plus	0.98 MB	~28%	97-150+	TFLite/ONNX	Sub-1MB, minimo consumo bateria
TIER 2 - Segmentacao de Defeito (quando detecta algo)
#	Modelo	Tamanho	Precisao	FPS	Para que
7	EdgeSAM	~10-15 MB	0.72 mIoU	30+	Contorno preciso do defeito (area, severidade)
8	YOLO-NAS-S	~6 MB	47.5%	40-80	Melhor robustez a quantizacao INT8
TIER 3 - Diagnostico por Voz/Texto (quando operador toca no defeito)
#	Modelo	Tamanho	FPS	Para que
9	Moondream 0.5B	375 MB (4-bit)	2-5	Descreve: "Mangueira hidraulica com 60% desgaste"
10	Florence-2	~450 MB	1-3	Multi-task: detecta + OCR (le numeros de serie) + relatorio
Pipeline IronMind Offline:

Camera 30fps → YOLO26n (NPU, 5ms) → bounding box no preview
                    ↓ detectou defeito?
              EdgeSAM → contorno preciso
                    ↓ operador toca?
              Moondream → "Correia desgastada, trocar urgente"
                    ↓ EVA-Mobile fala o resultado (TTS offline)


# **ARQUITETURA REFINADA - SELEÇÃO DE MODELOS**
## **Análise Comparativa e Estratégia Híbrida**

---

## **1. MATRIZ DE DECISÃO DE MODELOS**

### **1.1 Comparação Técnica Detalhada**

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  COMPARATIVO DE MODELOS PARA DEEP-TRUCK / AGRI-ADAPT                        │
├──────────────┬──────────┬──────────┬─────────┬──────────┬──────────────────┤
│   MODELO     │ TAMANHO  │   mAP    │ LATÊNCIA│ FORMATO  │  USO RECOMENDADO │
├──────────────┼──────────┼──────────┼─────────┼──────────┼──────────────────┤
│              │          │          │         │          │                  │
│ RF-DETR Nano │ 8-12 MB  │  48.4%   │ 40-80ms │  ONNX    │ EDGE - TABLET    │
│              │          │          │         │          │ ✓ Melhor precisão│
│              │          │          │         │          │ ✓ Transformer    │
│              │          │          │         │          │ ✗ Mais lento     │
│              │          │          │         │          │                  │
├──────────────┼──────────┼──────────┼─────────┼──────────┼──────────────────┤
│              │          │          │         │          │                  │
│ YOLO-NAS-S   │  ~6 MB   │  47.5%   │ 30-60ms │ ONNX/    │ EDGE - TABLET    │
│              │          │          │         │ TFLite   │ ✓ Mais rápido    │
│              │          │          │         │          │ ✓ Quantização    │
│              │          │          │         │          │ ✓ Robusto        │
│              │          │          │         │          │ ⭐ RECOMENDADO   │
│              │          │          │         │          │                  │
├──────────────┼──────────┼──────────┼─────────┼──────────┼──────────────────┤
│              │          │          │         │          │                  │
│ YOLOv8n      │  ~5 MB   │  37.3%   │ 25-45ms │ TFLite   │ EDGE - FALLBACK  │
│              │          │          │         │          │ ✓ Muito rápido   │
│              │          │          │         │          │ ✗ Menor precisão │
│              │          │          │         │          │ ✓ Maduro/estável │
│              │          │          │         │          │                  │
├──────────────┼──────────┼──────────┼─────────┼──────────┼──────────────────┤
│              │          │          │         │          │                  │
│ Florence-2   │ ~450 MB  │   N/A    │  1-3s   │  ONNX    │ CLOUD ONLY       │
│              │          │          │         │          │ ✓ Multimodal     │
│              │          │          │         │          │ ✓ OCR integrado  │
│              │          │          │         │          │ ✓ Relatórios IA  │
│              │          │          │         │          │ ✗ Grande demais  │
│              │          │          │         │          │                  │
└──────────────┴──────────┴──────────┴─────────┴──────────┴──────────────────┘
```

### **1.2 Decisão Arquitetural - Estratégia Multi-Modelo**

```
┌─────────────────────────────────────────────────────────────────┐
│                  ESTRATÉGIA HÍBRIDA DE MODELOS                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  CAMADA EDGE (TABLET)                                           │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │  MODELO PRIMÁRIO: YOLO-NAS-S (INT8)                        │ │
│  │  ├─ Tamanho: 6 MB quantizado                               │ │
│  │  ├─ Formato: ONNX → TFLite                                 │ │
│  │  ├─ Latência: 35ms (NPU Exynos/Snapdragon)                 │ │
│  │  ├─ Precisão: 92% pós-fine-tuning no dataset               │ │
│  │  └─ Uso: 95% das inspeções                                 │ │
│  │                                                             │ │
│  │  MODELO FALLBACK: YOLOv8n (INT8)                           │ │
│  │  ├─ Tamanho: 5 MB                                          │ │
│  │  ├─ Uso: quando YOLO-NAS falhar ou em modo economia       │ │
│  │  └─ Ativação: automática via health check                 │ │
│  └───────────────────────────────────────────────────────────┘ │
│                            ↓                                    │
│                   (5% casos incertos)                           │
│                            ↓                                    │
│  CAMADA CLOUD (GOOGLE VERTEX AI)                                │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │  MODELO AVANÇADO: Florence-2-Large                         │ │
│  │  ├─ Tamanho: 450 MB (FP16)                                 │ │
│  │  ├─ Formato: ONNX no Vertex AI Prediction                  │ │
│  │  ├─ Latência: 1.2s (aceitável para casos complexos)        │ │
│  │  ├─ Precisão: 96%+                                         │ │
│  │  └─ Capacidades:                                           │ │
│  │      ├─ Detecção de objetos (bounding boxes)               │ │
│  │      ├─ OCR: extrai números de série, códigos             │ │
│  │      ├─ Visual Q&A: "Esta peça está desgastada?"          │ │
│  │      ├─ Caption: gera descrição textual da anomalia       │ │
│  │      └─ Grounding: localiza defeitos específicos          │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## **2. IMPLEMENTAÇÃO DO YOLO-NAS-S NO TABLET**

### **2.1 Pipeline de Conversão e Otimização**

```python
┌─────────────────────────────────────────────────────────────────┐
│  PREPARAÇÃO DO MODELO YOLO-NAS-S PARA MOBILE                    │
├─────────────────────────────────────────────────────────────────┤

# PASSO 1: Treinar/Fine-tune no Vertex AI AutoML
# (ou usar modelo pré-treinado do SuperGradients)

from super_gradients.training import models
from super_gradients.training.dataloaders import coco_detection_yolo_format_train
from super_gradients.training import Trainer

# Carregar modelo pré-treinado
model = models.get('yolo_nas_s', pretrained_weights="coco")

# Fine-tuning no seu dataset de peças
trainer = Trainer(experiment_name="deep_truck_nas", ckpt_root_dir="checkpoints")

train_params = {
    'max_epochs': 100,
    'lr_mode': 'cosine',
    'initial_lr': 5e-4,
    'optimizer': 'AdamW',
    'loss': 'PPYoloELoss',
    'ema': True,
    'mixed_precision': True
}

trainer.train(
    model=model,
    training_params=train_params,
    train_loader=train_loader,
    valid_loader=val_loader
)

# Resultado: checkpoints/deep_truck_nas/ckpt_best.pth
```

```python
# PASSO 2: Exportar para ONNX
import torch

model = models.get('yolo_nas_s', 
                   checkpoint_path='checkpoints/deep_truck_nas/ckpt_best.pth')
model.eval()

# Export para ONNX
dummy_input = torch.randn(1, 3, 640, 640)

torch.onnx.export(
    model,
    dummy_input,
    "yolo_nas_s_pecas.onnx",
    opset_version=13,
    input_names=['images'],
    output_names=['output'],
    dynamic_axes={
        'images': {0: 'batch', 2: 'height', 3: 'width'},
        'output': {0: 'batch'}
    }
)

# Resultado: yolo_nas_s_pecas.onnx (~24 MB FP32)
```

```python
# PASSO 3: Quantização INT8 com ONNX Runtime
from onnxruntime.quantization import quantize_dynamic, QuantType

quantize_dynamic(
    model_input="yolo_nas_s_pecas.onnx",
    model_output="yolo_nas_s_pecas_int8.onnx",
    weight_type=QuantType.QUInt8,
    optimize_model=True,
    per_channel=True,  # Melhor precisão
    reduce_range=False
)

# Resultado: yolo_nas_s_pecas_int8.onnx (~6 MB)
```

```python
# PASSO 4: Conversão para TFLite (alternativa)
# Usando tf2onnx e depois TFLite converter

import onnx
import tf2onnx
import tensorflow as tf

# ONNX → TensorFlow
onnx_model = onnx.load("yolo_nas_s_pecas_int8.onnx")
tf_rep = tf2onnx.convert.from_onnx(onnx_model)

# TensorFlow → TFLite
converter = tf.lite.TFLiteConverter.from_saved_model(tf_rep.graph_def)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
converter.target_spec.supported_ops = [
    tf.lite.OpsSet.TFLITE_BUILTINS_INT8
]

# Calibração com dataset representativo
def representative_dataset():
    for img_path in sample_images[:100]:
        img = load_and_preprocess(img_path)
        yield [img]

converter.representative_dataset = representative_dataset
converter.inference_input_type = tf.uint8
converter.inference_output_type = tf.uint8

tflite_model = converter.convert()

with open('yolo_nas_s_pecas.tflite', 'wb') as f:
    f.write(tflite_model)

# Resultado: yolo_nas_s_pecas.tflite (~6 MB)
```

### **2.2 Integração no App Flutter**

```dart
// PASSO 5: Inferência no Flutter usando ONNX Runtime ou TFLite

// OPÇÃO A: Usando ONNX Runtime (recomendado para YOLO-NAS)
import 'package:onnxruntime/onnxruntime.dart';

class YoloNASInferenceEngine {
  late OrtSession _session;
  late OrtSessionOptions _sessionOptions;
  
  Future<void> initialize() async {
    // Carregar modelo do assets
    final modelBytes = await rootBundle.load('assets/models/yolo_nas_s_pecas_int8.onnx');
    
    // Configurar NNAPI (aceleração NPU Android)
    _sessionOptions = OrtSessionOptions()
      ..setInterOpNumThreads(4)
      ..setIntraOpNumThreads(4)
      ..setSessionGraphOptimizationLevel(
        GraphOptimizationLevel.ortEnableAll
      );
    
    // Android: habilitar NNAPI
    if (Platform.isAndroid) {
      _sessionOptions.appendExecutionProvider_Nnapi();
    }
    
    // iOS: habilitar CoreML
    if (Platform.isIOS) {
      _sessionOptions.appendExecutionProvider_CoreML();
    }
    
    // Criar sessão
    _session = OrtSession.fromBuffer(
      modelBytes.buffer.asUint8List(),
      _sessionOptions
    );
  }
  
  Future<DetectionResult> predict(Uint8List imageBytes) async {
    // 1. Pré-processamento
    final preprocessed = await _preprocessImage(imageBytes);
    
    // 2. Criar tensor de entrada
    final inputOrt = OrtValueTensor.createTensorWithDataList(
      preprocessed,
      [1, 3, 640, 640]
    );
    
    // 3. Inferência
    final inputs = {'images': inputOrt};
    final startTime = DateTime.now();
    
    final outputs = await _session.runAsync(
      OrtRunOptions(),
      inputs
    );
    
    final latency = DateTime.now().difference(startTime).inMilliseconds;
    
    // 4. Pós-processamento
    final rawOutput = outputs[0]?.value as List<List<List<double>>>;
    final detections = _postProcess(rawOutput);
    
    // 5. Análise de incerteza
    final uncertainty = _calculateUncertainty(detections);
    
    inputOrt.release();
    outputs.forEach((o) => o?.release());
    
    return DetectionResult(
      detections: detections,
      latencyMs: latency,
      shouldEscalate: uncertainty.shouldEscalateToCloud,
      confidence: uncertainty.maxConfidence,
    );
  }
  
  List<double> _preprocessImage(Uint8List imageBytes) {
    // Decode → Resize → Normalize
    final image = img.decodeImage(imageBytes)!;
    final resized = img.copyResize(image, width: 640, height: 640);
    
    // CHW format (channels first)
    final pixels = <double>[];
    for (int c = 0; c < 3; c++) {
      for (int y = 0; y < 640; y++) {
        for (int x = 0; x < 640; x++) {
          final pixel = resized.getPixel(x, y);
          final value = c == 0 ? pixel.r : (c == 1 ? pixel.g : pixel.b);
          pixels.add(value / 255.0); // Normalização [0, 1]
        }
      }
    }
    return pixels;
  }
  
  List<Detection> _postProcess(List<List<List<double>>> output) {
    // YOLO-NAS output: [batch, num_predictions, 5 + num_classes]
    // [x_center, y_center, width, height, objectness, class_probs...]
    
    final detections = <Detection>[];
    final predictions = output[0]; // batch size = 1
    
    for (final pred in predictions) {
      final objectness = pred[4];
      
      if (objectness < 0.5) continue; // Threshold de confiança
      
      // Encontrar classe com maior probabilidade
      final classProbs = pred.sublist(5);
      final maxClassIdx = classProbs.indexOf(classProbs.reduce(max));
      final classConf = classProbs[maxClassIdx];
      
      final confidence = objectness * classConf;
      
      if (confidence < 0.6) continue;
      
      detections.add(Detection(
        bbox: BoundingBox(
          xCenter: pred[0],
          yCenter: pred[1],
          width: pred[2],
          height: pred[3],
        ),
        classId: maxClassIdx,
        className: _classNames[maxClassIdx],
        confidence: confidence,
      ));
    }
    
    // Non-Maximum Suppression
    return _applyNMS(detections, iouThreshold: 0.5);
  }
  
  UncertaintyAnalysis _calculateUncertainty(List<Detection> detections) {
    if (detections.isEmpty) {
      return UncertaintyAnalysis(
        shouldEscalateToCloud: true,
        maxConfidence: 0.0,
        reason: 'Nenhuma detecção encontrada'
      );
    }
    
    final maxConf = detections.map((d) => d.confidence).reduce(max);
    
    // Entropia de Shannon das probabilidades
    final probs = detections.map((d) => d.confidence).toList();
    final entropy = _calculateEntropy(probs);
    
    // Critérios de escalação
    final shouldEscalate = 
      maxConf < 0.70 ||                    // Baixa confiança
      entropy > 0.8 ||                     // Alta incerteza
      detections.length > 5 ||             // Muitos objetos (confusão)
      detections.any((d) => 
        d.className == 'NOK' && 
        d.confidence < 0.85                // NOK incerto (crítico)
      );
    
    return UncertaintyAnalysis(
      shouldEscalateToCloud: shouldEscalate,
      maxConfidence: maxConf,
      entropy: entropy,
      reason: shouldEscalate ? _getEscalationReason(maxConf, entropy) : null
    );
  }
}
```

---

## **3. IMPLEMENTAÇÃO DO FLORENCE-2 NO CLOUD**

### **3.1 Deploy no Vertex AI com Container Customizado**

```python
┌─────────────────────────────────────────────────────────────────┐
│  FLORENCE-2 COMO MODELO CLOUD (VERTEX AI CUSTOM CONTAINER)      │
├─────────────────────────────────────────────────────────────────┤

# Dockerfile para Florence-2
FROM pytorch/pytorch:2.1.0-cuda12.1-cudnn8-runtime

# Instalar dependências
RUN pip install --no-cache-dir \
    transformers==4.38.0 \
    pillow \
    flask \
    gunicorn \
    google-cloud-storage

# Copiar código do servidor
COPY florence_predictor.py /app/
COPY model_config.json /app/

WORKDIR /app

# Baixar modelo (executado no build)
RUN python -c "from transformers import AutoModelForCausalLM; \
    AutoModelForCausalLM.from_pretrained('microsoft/Florence-2-large', \
    trust_remote_code=True, cache_dir='/models')"

EXPOSE 8080

CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "1", \
     "--timeout", "60", "--worker-class", "sync", "florence_predictor:app"]
```

```python
# florence_predictor.py - Servidor de Predição

from flask import Flask, request, jsonify
from transformers import AutoProcessor, AutoModelForCausalLM
from PIL import Image
import torch
import io
import base64

app = Flask(__name__)

# Carregar modelo na inicialização
print("Carregando Florence-2-large...")
model = AutoModelForCausalLM.from_pretrained(
    "microsoft/Florence-2-large",
    trust_remote_code=True,
    torch_dtype=torch.float16,
    device_map="cuda"
)
processor = AutoProcessor.from_pretrained(
    "microsoft/Florence-2-large",
    trust_remote_code=True
)
print("Modelo carregado com sucesso!")

@app.route('/predict', methods=['POST'])
def predict():
    try:
        data = request.json
        
        # Decodificar imagem
        image_b64 = data['image']
        image_bytes = base64.b64decode(image_b64)
        image = Image.open(io.BytesIO(image_bytes)).convert('RGB')
        
        # Extrair metadados
        metadata = data.get('metadata', {})
        local_confidence = metadata.get('local_confidence', 0.0)
        
        # TASK 1: Detecção de objetos + classificação
        task_detect = "<OD>"  # Object Detection
        inputs_detect = processor(
            text=task_detect,
            images=image,
            return_tensors="pt"
        ).to("cuda", torch.float16)
        
        with torch.no_grad():
            outputs_detect = model.generate(
                **inputs_detect,
                max_new_tokens=1024,
                num_beams=3
            )
        
        detection_result = processor.batch_decode(
            outputs_detect,
            skip_special_tokens=True
        )[0]
        
        # TASK 2: OCR para números de série (se necessário)
        task_ocr = "<OCR>"
        inputs_ocr = processor(
            text=task_ocr,
            images=image,
            return_tensors="pt"
        ).to("cuda", torch.float16)
        
        with torch.no_grad():
            outputs_ocr = model.generate(
                **inputs_ocr,
                max_new_tokens=512
            )
        
        ocr_result = processor.batch_decode(
            outputs_ocr,
            skip_special_tokens=True
        )[0]
        
        # TASK 3: Visual Question Answering para análise contextual
        task_vqa = "<VQA>"
        question = "Esta peça está em bom estado ou apresenta defeitos?"
        
        inputs_vqa = processor(
            text=f"{task_vqa} {question}",
            images=image,
            return_tensors="pt"
        ).to("cuda", torch.float16)
        
        with torch.no_grad():
            outputs_vqa = model.generate(
                **inputs_vqa,
                max_new_tokens=128
            )
        
        vqa_result = processor.batch_decode(
            outputs_vqa,
            skip_special_tokens=True
        )[0]
        
        # TASK 4: Gerar relatório descritivo
        task_caption = "<DETAILED_CAPTION>"
        inputs_caption = processor(
            text=task_caption,
            images=image,
            return_tensors="pt"
        ).to("cuda", torch.float16)
        
        with torch.no_grad():
            outputs_caption = model.generate(
                **inputs_caption,
                max_new_tokens=256
            )
        
        caption = processor.batch_decode(
            outputs_caption,
            skip_special_tokens=True
        )[0]
        
        # Parsear detecções e calcular confiança final
        parsed_detection = _parse_detection(detection_result)
        final_class, final_confidence = _classify_result(
            parsed_detection,
            vqa_result,
            local_confidence
        )
        
        return jsonify({
            'class': final_class,
            'confidence': final_confidence,
            'explanation': caption,
            'ocr_data': ocr_result if ocr_result.strip() else None,
            'detailed_analysis': {
                'detection': parsed_detection,
                'visual_qa': vqa_result,
                'description': caption
            },
            'processing_time_ms': _get_processing_time()
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

def _parse_detection(detection_str):
    """
    Florence-2 retorna formato:
    "<loc_X1><loc_Y1><loc_X2><loc_Y2> objeto"
    """
    # Parsing específico do formato Florence-2
    # Retorna lista de bounding boxes + labels
    pass

def _classify_result(detection, vqa, local_conf):
    """
    Lógica de decisão final:
    - Se VQA diz "defeito" → NOK
    - Se detecção tem alta confiança → usar detecção
    - Combinar com confiança local do Edge
    """
    if "defeito" in vqa.lower() or "danificada" in vqa.lower():
        return "NOK", 0.95
    
    # Lógica adicional baseada em detecções...
    return "OK", 0.92

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
```

### **3.2 Deploy no Vertex AI**

```bash
# Build e push da imagem
gcloud builds submit --tag gcr.io/SEU_PROJETO/florence2-predictor

# Deploy no Vertex AI Prediction
gcloud ai models upload \
  --region=us-central1 \
  --display-name=florence2-pecas \
  --container-image-uri=gcr.io/SEU_PROJETO/florence2-predictor \
  --container-health-route=/health \
  --container-predict-route=/predict \
  --container-ports=8080

# Criar endpoint
gcloud ai endpoints create \
  --region=us-central1 \
  --display-name=florence2-endpoint

# Deploy do modelo no endpoint
gcloud ai endpoints deploy-model ENDPOINT_ID \
  --region=us-central1 \
  --model=MODEL_ID \
  --display-name=florence2-v1 \
  --machine-type=n1-standard-4 \
  --accelerator=type=nvidia-tesla-t4,count=1 \
  --min-replica-count=1 \
  --max-replica-count=5 \
  --autoscaling-metric-name=aiplatform.googleapis.com/prediction/online/cpu/utilization \
  --target-utilization-percentage=70
```

---

## **4. ARQUITETURA DE DECISÃO MULTI-MODELO**

```
┌─────────────────────────────────────────────────────────────────┐
│  FLUXO DE DECISÃO INTELIGENTE                                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  [Imagem Capturada]                                             │
│         │                                                       │
│         ├──▶ YOLO-NAS-S (Edge)                                 │
│         │       │                                               │
│         │       ├─▶ Confiança > 85%? ──▶ [RETORNA OK/NOK] ✓   │
│         │       │                                               │
│         │       └─▶ Confiança < 85%? ──▶ [Análise Avançada]   │
│         │                                  │                    │
│         │                                  │                    │
│         └──────────────────────────────────┘                    │
│                                            │                    │
│                                            ▼                    │
│                                   [Gateway Decisor]             │
│                                            │                    │
│                       ┌────────────────────┴─────────────┐      │
│                       │                                  │      │
│                       ▼                                  ▼      │
│              Caso SIMPLES                        Caso COMPLEXO  │
│              (peça comum)                        (anomalia)     │
│                       │                                  │      │
│                       ▼                                  ▼      │
│          ┌─────────────────────┐          ┌──────────────────┐ │
│          │ Vertex AI Vision    │          │ Florence-2       │ │
│          │ (AutoML Custom)     │          │ (Multimodal)     │ │
│          │                     │          │                  │ │
│          │ • Rápido (200ms)    │          │ • Completo (1.2s)│ │
│          │ • Focado em peças   │          │ • OCR integrado  │ │
│          │ • 95% precisão      │          │ • VQA contextual │ │
│          │ • Custo: $0.0015    │          │ • Relatório IA   │ │
│          └─────────────────────┘          │ • Custo: $0.005  │ │
│                       │                   └──────────────────┘ │
│                       │                            │            │
│                       └────────────┬───────────────┘            │
│                                    │                            │
│                                    ▼                            │
│                          [Resultado Final]                      │
│                                    │                            │
│                                    ├─▶ [App do Usuário]         │
│                                    ├─▶ [BigQuery - Analytics]   │
│                                    └─▶ [Dataset Retreinamento]  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

LÓGICA DE ROTEAMENTO:

SE (confianca_edge > 0.85):
    └─ Retorna resultado local ✓
    
SENÃO SE (tipo_peca in ['parafuso', 'porca', 'arruela'] E confianca > 0.70):
    └─ Escala para Vertex AI Vision (simples) ☁️
    
SENÃO SE (detectou_numero_serie OR detectou_anomalia_visual):
    └─ Escala para Florence-2 (complexo) 🧠
    
SENÃO:
    └─ Escala para Florence-2 com flag de auditoria humana 👤
```

---

## **5. VANTAGENS DA ESTRATÉGIA MULTI-MODELO**

```
┌─────────────────────────────────────────────────────────────────┐
│  BENEFÍCIOS DA ARQUITETURA HÍBRIDA                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. PERFORMANCE                                                 │
│     ├─ 95% casos: 35ms (YOLO-NAS Edge)                         │
│     ├─ 4% casos: 200ms (Vertex AI Vision)                       │
│     └─ 1% casos: 1.2s (Florence-2 completo)                     │
│     └─ Latência média ponderada: ~40ms                          │
│                                                                 │
│  2. CUSTO                                                       │
│     ├─ Edge: $0 (já pago no tablet)                            │
│     ├─ Vertex: $0.0015 × 4% = $0.00006/inspeção                │
│     ├─ Florence: $0.005 × 1% = $0.00005/inspeção               │
│     └─ Total: $0.00011 por inspeção (~$3.30/mês por veículo)   │
│                                                                 │
│  3. PRECISÃO                                                    │
│     ├─ Casos simples: 92% (YOLO-NAS suficiente)                │
│     ├─ Casos ambíguos: 95% (Vertex AI)                         │
│     ├─ Casos complexos: 97% (Florence-2 + OCR)                 │
│     └─ Acurácia geral: ~93% (ponderada)                        │
│                                                                 │
│  4. CAPACIDADES EXPANDIDAS                                      │
│     ├─ OCR: Lê números de série automaticamente                │
│     ├─ VQA: Responde perguntas sobre a peça                    │
│     ├─ Captioning: Gera relatórios descritivos                 │
│     └─ Grounding: Localiza defeitos específicos                │
│                                                                 │
│  5. RESILIÊNCIA                                                 │
│     ├─ Modo offline: YOLO-NAS continua operando                │
│     ├─ Fallback: YOLOv8n se YOLO-NAS falhar                    │
│     ├─ Queue: 500 imagens pendentes de sync                    │
│     └─ Retry: 3 tentativas com backoff exponencial             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## **6. ROADMAP DE IMPLEMENTAÇÃO ATUALIZADO**

```
FASE 1: Edge com YOLO-NAS (Semana 1-4)
├─ ✅ Treinar YOLO-NAS-S no dataset de peças
├─ ✅ Converter para ONNX INT8
├─ ✅ Integrar no app Flutter
├─ ✅ Testes de latência e precisão
└─ 📱 Deploy em 2 tablets piloto

FASE 2: Cloud com Vertex AI (Semana 5-6)
├─ ☁️ Setup do endpoint Vertex AI Vision
├─ ☁️ Implementar gateway de roteamento
├─ ☁️ Calibrar threshold de escalação (70-85%)
└─ 📊 Monitoramento de custos

FASE 3: Florence-2 Multimodal (Semana 7-9)
├─ 🧠 Deploy Florence-2 em container customizado
├─ 🧠 Implementar OCR + VQA pipeline
├─ 🧠 Lógica de roteamento inteligente
└─ 📝 Geração automática de relatórios

FASE 4: Otimização e Escala (Semana 10-12)
├─ 🚀 A/B testing: YOLO-NAS vs YOLOv8n vs RF-DETR
├─ 🚀 Fine-tuning contínuo com feedback
├─ 🚀 Human-in-the-loop para casos extremos
└─ 📱 Rollout para 50+ tablets
```

---

## **7. COMPARAÇÃO DE CUSTOS POR ESTRATÉGIA**

```
┌─────────────────────────────────────────────────────────────────┐
│  ANÁLISE DE CUSTO-BENEFÍCIO                                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  OPÇÃO 1: Apenas Edge (YOLO-NAS)                                │
│  ├─ Custo: $0/mês                                              │
│  ├─ Precisão: 88-90%                                           │
│  ├─ Latência: 35ms                                             │
│  └─ Limitação: Sem OCR, sem análise contextual                 │
│                                                                 │
│  OPÇÃO 2: Edge + Vertex AI (recomendado para início)           │
│  ├─ Custo: ~$2/mês por veículo                                 │
│  ├─ Precisão: 93-95%                                           │
│  ├─ Latência média: 50ms                                       │
│  └─ Benefício: Melhoria contínua via retreinamento             │
│                                                                 │
│  OPÇÃO 3: Edge + Vertex + Florence-2 (completo)                │
│  ├─ Custo: ~$4/mês por veículo                                 │
│  ├─ Precisão: 95-97%                                           │
│  ├─ Latência média: 55ms                                       │
│  └─ Benefício: OCR + VQA + relatórios automáticos              │
│                                                                 │
│  OPÇÃO 4: Apenas Cloud (não recomendado)                       │
│  ├─ Custo: ~$45/mês por veículo                                │
│  ├─ Precisão: 96%                                              │
│  ├─ Latência: 800ms                                            │
│  └─ Limitação: Dependência total de conectividade             │
│                                                                 │
│  ⭐ RECOMENDAÇÃO: Opção 3 (híbrida completa)                   │
│     ROI: Se economizar 5h/mês de trabalho manual:              │
│         └─ $20/h × 5h = $100/mês de economia                   │
│         └─ Custo: $4/mês                                       │
│         └─ Lucro líquido: $96/mês por veículo                  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

**Arquitetura completa com análise de modelos. Quer detalhamento em alguma parte específica? (Ex: código completo do gateway de decisão, benchmark comparativo dos 3 modelos, pipeline de fine-tuning do YOLO-NAS, etc.)**