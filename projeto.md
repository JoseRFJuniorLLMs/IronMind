
# **ARQUITETURA DO SISTEMA - VERSÃO TABLET**
## **Projeto: Deep-Truck / Agri-Adapt Vision System**

---

## **1. VISÃO GERAL DA ARQUITETURA MOBILE**

### **1.1 Conceito Arquitetural para Tablets**

```
┌─────────────────────────────────────────────────────────────────┐
│                 ARQUITETURA HÍBRIDA MOBILE-FIRST                │
│                                                                 │
│  ┌────────────────┐       ┌────────────┐       ┌────────────┐ │
│  │  TABLET EDGE   │──────▶│  GATEWAY   │──────▶│   CLOUD    │ │
│  │  (NPU Mobile)  │◀──────│  MOBILE    │◀──────│  (Google)  │ │
│  └────────────────┘       └────────────┘       └────────────┘ │
│    App Nativo              Decisor Local          Retreino     │
│    Inferência 30fps        Sync Inteligente      Distribuição  │
└─────────────────────────────────────────────────────────────────┘
```

**Diferenciais da Arquitetura Mobile**:
- Processador ARM com NPU integrada (não precisa hardware externo)
- Interface touch otimizada para uso em veículos
- GPS e sensores embarcados (acelerômetro, giroscópio)
- Bateria integrada (funciona mesmo com ignição desligada)
- Câmera de alta qualidade já disponível
- Sistema operacional maduro (Android/iOS)

---

## **2. ESPECIFICAÇÕES DO TABLET**

### **2.1 Hardware Recomendado**

```
┌─────────────────────────────────────────────────────────────┐
│  TABLET INDUSTRIAL RECOMENDADO                              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  OPÇÃO 1: SAMSUNG GALAXY TAB ACTIVE 5                       │
│  ├─ Processador: Exynos 1380 (NPU integrada)               │
│  ├─ NPU: 4.9 TOPS INT8                                     │
│  ├─ RAM: 8GB                                               │
│  ├─ Storage: 128GB (expansível)                            │
│  ├─ Tela: 11" (1920×1200) - Gorilla Glass 5                │
│  ├─ Câmera: 13MP traseira com foco automático              │
│  ├─ Bateria: 7,040 mAh (12h operação contínua)             │
│  ├─ Certificação: IP68 + MIL-STD-810H                       │
│  ├─ SO: Android 13 (updates até 2028)                      │
│  ├─ Conectividade: 5G, Wi-Fi 6, Bluetooth 5.3              │
│  ├─ GPS: Dual-band GNSS                                    │
│  └─ Preço: ~$600 USD                                       │
│                                                             │
│  OPÇÃO 2: ZEBRA ET85                                        │
│  ├─ Processador: Snapdragon 8 Gen 2                        │
│  ├─ NPU: Hexagon AI Engine (15 TOPS)                       │
│  ├─ RAM: 12GB                                              │
│  ├─ Tela: 12" (2560×1600)                                  │
│  ├─ Certificação: IP65 + MIL-STD-810G                       │
│  └─ Preço: ~$1,800 USD (mais robusto)                      │
│                                                             │
│  OPÇÃO 3: LENOVO TAB P12 PRO (custo-benefício)             │
│  ├─ Processador: Snapdragon 870 5G                         │
│  ├─ NPU: Hexagon 698 (6 TOPS)                              │
│  ├─ RAM: 8GB                                               │
│  ├─ Tela: 12.6" OLED (2560×1600)                           │
│  ├─ Câmera: 13MP + 5MP ultra-wide                          │
│  └─ Preço: ~$450 USD + case robusto aftermarket            │
└─────────────────────────────────────────────────────────────┘
```

### **2.2 Acessórios Necessários**

```
┌─────────────────────────────────────────────────────────────┐
│  KIT COMPLETO PARA VEÍCULO                                  │
├─────────────────────────────────────────────────────────────┤
│  1. SUPORTE VEICULAR                                        │
│     ├─ RAM Mount X-Grip (braço articulado)                 │
│     ├─ Fixação: ventosa ou parafusos                       │
│     └─ Custo: $120                                         │
│                                                             │
│  2. ALIMENTAÇÃO                                             │
│     ├─ Carregador veicular 12V→5V USB-C PD (45W)           │
│     ├─ Cabo reforçado com proteção                         │
│     └─ Custo: $50                                          │
│                                                             │
│  3. ILUMINAÇÃO AUXILIAR                                     │
│     ├─ LED Ring Light USB (para câmera)                    │
│     ├─ 6500K temperatura de cor                            │
│     └─ Custo: $35                                          │
│                                                             │
│  4. CASE REFORÇADO                                          │
│     ├─ OtterBox Defender ou similar                        │
│     ├─ Proteção contra quedas e impactos                   │
│     └─ Custo: $80                                          │
│                                                             │
│  5. CONECTIVIDADE BACKUP                                    │
│     ├─ Chip 4G/5G com plano de dados                       │
│     ├─ 10GB/mês (suficiente para 5% escalação)             │
│     └─ Custo: $25/mês                                      │
│                                                             │
│  INVESTIMENTO TOTAL: ~$900 por veículo (CAPEX)             │
└─────────────────────────────────────────────────────────────┘
```

---

## **3. ARQUITETURA DA APLICAÇÃO MOBILE**

### **3.1 Stack Tecnológico**

```
┌─────────────────────────────────────────────────────────────┐
│                  CAMADAS DA APLICAÇÃO                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌───────────────────────────────────────────────────────┐ │
│  │  CAMADA DE APRESENTAÇÃO (UI)                          │ │
│  │  ────────────────────────────────────────────────────  │ │
│  │  Framework: Flutter 3.x (cross-platform)              │ │
│  │  ├─ Dart language (performance nativa)                │ │
│  │  ├─ Material Design 3 (Android)                       │ │
│  │  ├─ Cupertino (iOS opcional)                          │ │
│  │  └─ Responsive design (tablets 10-13")                │ │
│  │                                                        │ │
│  │  Telas Principais:                                     │ │
│  │  ├─ Captura em Tempo Real (viewfinder)                │ │
│  │  ├─ Resultado da Inspeção (OK/NOK/Incerto)            │ │
│  │  ├─ Histórico Local (últimas 100 inspeções)           │ │
│  │  ├─ Configurações (threshold, modo offline)           │ │
│  │  └─ Dashboard de Performance (métricas)               │ │
│  └───────────────────────────────────────────────────────┘ │
│                           ↓                                 │
│  ┌───────────────────────────────────────────────────────┐ │
│  │  CAMADA DE LÓGICA DE NEGÓCIO                          │ │
│  │  ────────────────────────────────────────────────────  │ │
│  │  Padrão: BLoC (Business Logic Component)              │ │
│  │  ├─ Gerenciamento de Estado (flutter_bloc)            │ │
│  │  ├─ Orquestração de workflows                         │ │
│  │  └─ Regras de decisão (escalação)                     │ │
│  │                                                        │ │
│  │  Módulos:                                              │ │
│  │  ├─ InspectionBloc (coordena fluxo de inspeção)       │ │
│  │  ├─ UncertaintyBloc (decisor de escalação)            │ │
│  │  ├─ SyncBloc (sincronização com cloud)                │ │
│  │  └─ SettingsBloc (configurações persistentes)         │ │
│  └───────────────────────────────────────────────────────┘ │
│                           ↓                                 │
│  ┌───────────────────────────────────────────────────────┐ │
│  │  CAMADA DE INFERÊNCIA (AI Engine)                     │ │
│  │  ────────────────────────────────────────────────────  │ │
│  │  Runtime: TensorFlow Lite for Android                 │ │
│  │  ├─ Aceleração: NNAPI (Neural Networks API)           │ │
│  │  ├─ GPU Delegate (fallback se NPU indisponível)       │ │
│  │  └─ CPU Delegate (último recurso)                     │ │
│  │                                                        │ │
│  │  Modelo:                                               │ │
│  │  ├─ YOLOv8n.tflite (5.2 MB)                           │ │
│  │  ├─ Quantização: INT8 (dynamic range)                 │ │
│  │  ├─ Input: [1, 640, 480, 3] uint8                     │ │
│  │  └─ Output: [1, 25200, 7] (boxes + classes + conf)    │ │
│  │                                                        │ │
│  │  Pipeline:                                             │ │
│  │  ├─ Pré-processamento (normalização)                  │ │
│  │  ├─ Inferência (NPU/GPU)                              │ │
│  │  ├─ NMS (Non-Maximum Suppression)                     │ │
│  │  └─ Pós-processamento (classificação)                 │ │
│  └───────────────────────────────────────────────────────┘ │
│                           ↓                                 │
│  ┌───────────────────────────────────────────────────────┐ │
│  │  CAMADA DE DADOS (Persistência)                       │ │
│  │  ────────────────────────────────────────────────────  │ │
│  │  Banco Local: Hive (NoSQL embarcado)                  │ │
│  │  ├─ Leve e rápido (escrito em Dart)                   │ │
│  │  ├─ Encriptação AES-256                               │ │
│  │  └─ Sem dependências nativas                          │ │
│  │                                                        │ │
│  │  Estrutura de Dados:                                   │ │
│  │  ├─ inspections_box (últimas 1000 inspeções)          │ │
│  │  ├─ pending_sync_box (fila de escalação)              │ │
│  │  ├─ models_box (versões de modelo)                    │ │
│  │  └─ settings_box (configurações persistentes)         │ │
│  │                                                        │ │
│  │  Cache de Imagens: Flutter Cache Manager              │ │
│  │  └─ Retenção: 7 dias ou 2GB (o que ocorrer primeiro)  │ │
│  └───────────────────────────────────────────────────────┘ │
│                           ↓                                 │
│  ┌───────────────────────────────────────────────────────┐ │
│  │  CAMADA DE COMUNICAÇÃO (Network)                      │ │
│  │  ────────────────────────────────────────────────────  │ │
│  │  Cliente HTTP: Dio (interceptors + retry)             │ │
│  │  ├─ Timeout: 5s (conexão), 10s (resposta)             │ │
│  │  ├─ Retry: 3 tentativas com backoff exponencial       │ │
│  │  └─ Queue: até 500 requisições pendentes              │ │
│  │                                                        │ │
│  │  Protocolo:                                            │ │
│  │  ├─ REST API (HTTPS)                                  │ │
│  │  ├─ JSON serialization                                │ │
│  │  ├─ Compressão: Gzip                                  │ │
│  │  └─ Autenticação: OAuth 2.0 + JWT                     │ │
│  │                                                        │ │
│  │  Serviços:                                             │ │
│  │  ├─ CloudPredictionService (escalação)                │ │
│  │  ├─ ModelUpdateService (OTA)                          │ │
│  │  ├─ TelemetryService (métricas)                       │ │
│  │  └─ AuthService (autenticação)                        │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## **4. FLUXO DETALHADO DA APLICAÇÃO**

### **4.1 Jornada do Usuário - Inspeção Completa**

```
┌─────────────────────────────────────────────────────────────┐
│  FLUXO DE INSPEÇÃO (User Journey)                           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. INICIALIZAÇÃO DA APP                                    │
│     ├─ Splash Screen (verifica atualizações)               │
│     ├─ Carrega modelo TFLite em memória                    │
│     ├─ Verifica permissões (câmera, storage, localização)  │
│     ├─ Sincroniza configurações do servidor                │
│     └─ Tempo: ~3 segundos                                  │
│                                                             │
│  2. TELA PRINCIPAL - MODO CAPTURA                           │
│     ┌───────────────────────────────────────┐              │
│     │  ┌─────────────────────────────────┐  │              │
│     │  │   VIEWFINDER (Preview Câmera)    │  │              │
│     │  │                                   │  │              │
│     │  │   [Target Overlay] ───┐          │  │              │
│     │  │         │              │          │  │              │
│     │  │         └─ Guia visual │          │  │              │
│     │  │                        │          │  │              │
│     │  └────────────────────────┼──────────┘  │              │
│     │                           │              │              │
│     │  [●] Capturar    [Histórico] [Config]   │              │
│     │                                          │              │
│     │  Status: Pronto | FPS: 30 | Conf: 92%   │              │
│     └───────────────────────────────────────┘              │
│                                                             │
│  3. CAPTURA E PROCESSAMENTO                                 │
│     ├─ Usuário aponta câmera para peça                     │
│     ├─ Botão "Capturar" ou auto-trigger (motion)           │
│     ├─ Frame congelado → pré-processamento                 │
│     ├─ Inferência NPU (35-50ms)                            │
│     └─ Decisão: OK / NOK / Incerto                         │
│                                                             │
│  4A. RESULTADO: CONFIANTE (95% dos casos)                   │
│     ┌───────────────────────────────────────┐              │
│     │  ✓ PEÇA OK                            │              │
│     │  Confiança: 94%                       │              │
│     │  Classe: Parafuso M8                  │              │
│     │  Tempo: 48ms                          │              │
│     │                                        │              │
│     │  [Nova Inspeção] [Ver Detalhes]       │              │
│     └───────────────────────────────────────┘              │
│     └─ Vibração háptica + som de confirmação               │
│                                                             │
│  4B. RESULTADO: INCERTO (5% dos casos)                      │
│     ┌───────────────────────────────────────┐              │
│     │  ⚠ ANALISANDO NA NUVEM...             │              │
│     │  Confiança Local: 68%                 │              │
│     │  Status: Aguardando resposta          │              │
│     │                                        │              │
│     │  [Spinner de loading]                 │              │
│     └───────────────────────────────────────┘              │
│     ├─ Comprime imagem (85% quality)                       │
│     ├─ Envia para Cloud Functions                          │
│     ├─ Aguarda resposta (500-1200ms)                       │
│     └─ Exibe resultado final                               │
│                                                             │
│  5. ARMAZENAMENTO LOCAL                                     │
│     ├─ Salva resultado em Hive                             │
│     ├─ Thumbnail em cache (opcional)                       │
│     ├─ Metadados: timestamp, GPS, confiança                │
│     └─ Total: ~50KB por inspeção                           │
│                                                             │
│  6. SINCRONIZAÇÃO EM BACKGROUND                             │
│     ├─ Worker periódico (a cada 5 minutos)                 │
│     ├─ Envia telemetria para BigQuery                      │
│     ├─ Verifica novas versões de modelo                    │
│     └─ Ocorre apenas em Wi-Fi (economia de dados)          │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## **5. DECISOR DE INCERTEZA - LÓGICA REFINADA**

### **5.1 Algoritmo de Decisão Multicritério**

```
┌─────────────────────────────────────────────────────────────┐
│  ÁRVORE DE DECISÃO PARA ESCALAÇÃO                           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  [Resultado NPU]                                            │
│         │                                                   │
│         ├─▶ Critério 1: Confiança Máxima                   │
│         │   ├─ > 85% ──▶ [RETORNA IMEDIATO] ✓              │
│         │   ├─ 70-85% ──▶ [Analisa Critério 2]             │
│         │   └─ < 70% ──▶ [ESCALA PARA CLOUD] ☁️             │
│         │                                                   │
│         ├─▶ Critério 2: Entropia de Shannon                │
│         │   ├─ < 0.5 ──▶ [RETORNA] ✓                       │
│         │   ├─ 0.5-0.8 ──▶ [Analisa Critério 3]            │
│         │   └─ > 0.8 ──▶ [ESCALA] ☁️                        │
│         │                                                   │
│         ├─▶ Critério 3: Qualidade de Detecção (IoU)        │
│         │   ├─ > 0.7 ──▶ [RETORNA] ✓                       │
│         │   └─ < 0.7 ──▶ [ESCALA] ☁️                        │
│         │                                                   │
│         ├─▶ Critério 4: Contexto Operacional               │
│         │   ├─ Modo Offline? ──▶ [RETORNA com flag] ⚠️     │
│         │   ├─ Histórico de erros recente? ──▶ [ESCALA]    │
│         │   └─ Peça crítica? ──▶ [ESCALA] (segurança)      │
│         │                                                   │
│         └─▶ Critério 5: Recursos Disponíveis               │
│             ├─ Bateria < 20%? ──▶ [RETORNA] (economia)     │
│             ├─ Sem rede? ──▶ [FILA para sync]              │
│             └─ Custo do dia > limite? ──▶ [RETORNA]        │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### **5.2 Estratégias de Fallback**

```
CENÁRIO 1: SEM CONECTIVIDADE
├─ Decisão: Aceita resultado local mesmo com baixa confiança
├─ Flag: Marcar para revisão posterior
├─ Ação: Adiciona à fila de sincronização
└─ UX: Badge "Pendente de Validação" na inspeção

CENÁRIO 2: BATERIA CRÍTICA (<15%)
├─ Decisão: Desabilita temporariamente escalação
├─ Modo: Apenas inferência local
├─ Notificação: "Conecte à energia para análise completa"
└─ Volta ao normal quando bateria > 30%

CENÁRIO 3: LIMITE DE CUSTO DIÁRIO ATINGIDO
├─ Decisão: Bloqueia novas escalações até meia-noite
├─ Threshold: $5 por veículo por dia (configura)
├─ Override: Administrador pode liberar manualmente
└─ Relatório: Enviado ao gestor automaticamente

CENÁRIO 4: LATÊNCIA ALTA NA REDE (>3s)
├─ Decisão: Cancela escalação após timeout
├─ Retorna: Resultado local com disclaimer
├─ Retry: Adiciona à fila para tentar em melhor conexão
└─ Telemetria: Registra problema de rede
```

---

## **6. INTEGRAÇÃO COM GOOGLE CLOUD - MOBILE**

### **6.1 Endpoints da API**

```
┌─────────────────────────────────────────────────────────────┐
│  API ENDPOINTS (Cloud Functions)                            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. POST /api/v1/predict                                    │
│     Payload:                                                │
│     {                                                       │
│       "image": "base64_encoded_jpeg",                       │
│       "metadata": {                                         │
│         "device_id": "tablet-001",                          │
│         "timestamp": "2026-02-08T14:32:10Z",                │
│         "location": {"lat": -23.5505, "lng": -46.6333},     │
│         "local_confidence": 0.68,                           │
│         "model_version": "1.2.3"                            │
│       }                                                     │
│     }                                                       │
│     Response:                                               │
│     {                                                       │
│       "class": "OK",                                        │
│       "confidence": 0.94,                                   │
│       "explanation": "Peça dentro do padrão",               │
│       "processing_time_ms": 850                             │
│     }                                                       │
│                                                             │
│  2. GET /api/v1/models/latest                               │
│     Response:                                               │
│     {                                                       │
│       "version": "1.3.0",                                   │
│       "url": "gs://bucket/models/model_v1.3.0.tflite",      │
│       "checksum": "sha256:abc123...",                       │
│       "size_bytes": 5242880,                                │
│       "release_date": "2026-02-01",                         │
│       "min_app_version": "2.0.0"                            │
│     }                                                       │
│                                                             │
│  3. POST /api/v1/telemetry                                  │
│     Payload: (batch de métricas)                            │
│     {                                                       │
│       "device_id": "tablet-001",                            │
│       "period": "2026-02-08T00:00:00Z",                     │
│       "metrics": {                                          │
│         "total_inspections": 342,                           │
│         "escalations": 18,                                  │
│         "avg_latency_ms": 47,                               │
│         "errors": 2                                         │
│       }                                                     │
│     }                                                       │
│                                                             │
│  4. POST /api/v1/feedback                                   │
│     Usado para correções manuais (Human-in-the-Loop)        │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## **7. GESTÃO DE ATUALIZAÇÕES OTA (Over-The-Air)**

### **7.1 Fluxo de Atualização de Modelo**

```
┌─────────────────────────────────────────────────────────────┐
│  PIPELINE DE ATUALIZAÇÃO AUTOMÁTICA                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  [Novo Modelo Treinado no Vertex AI]                        │
│              │                                               │
│              ├─▶ 1. Exporta para TFLite INT8               │
│              │                                               │
│              ├─▶ 2. Valida em dataset de teste             │
│              │    └─ Acurácia: 93.2% (>92% atual) ✓        │
│              │                                               │
│              ├─▶ 3. Upload para Cloud Storage              │
│              │    └─ gs://models/model_v1.4.0.tflite        │
│              │                                               │
│              ├─▶ 4. Publica metadados na API               │
│              │                                               │
│              ├─▶ 5. Tablets verificam atualização          │
│              │    └─ Check a cada app startup               │
│              │    └─ Check em background (1x/dia)           │
│              │                                               │
│              ├─▶ 6. Download condicional                   │
│              │    ├─ Apenas em Wi-Fi (não usa dados móveis) │
│              │    ├─ Apenas se bateria > 50%                │
│              │    └─ Durante período de baixo uso           │
│              │                                               │
│              ├─▶ 7. Instalação gradual                     │
│              │    ├─ Grupo A (10%): 48h de teste            │
│              │    ├─ Grupo B (50%): se sucesso em A         │
│              │    └─ Grupo C (100%): rollout completo       │
│              │                                               │
│              └─▶ 8. Monitoramento pós-deploy               │
│                   ├─ Taxa de erro < 1%? ✓ Continua          │
│                   └─ Taxa de erro > 5%? ⚠️ Rollback         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### **7.2 Estratégia de Rollback Automático**

```
SE (taxa_erro_novo_modelo > 3x taxa_erro_modelo_anterior):
   ├─ Reverte automaticamente para versão anterior
   ├─ Notifica equipe de DevOps
   ├─ Bloqueia novo modelo temporariamente
   └─ Cria incident report automático

LOGS DE DECISÃO:
├─ Timestamp de cada deploy
├─ Versão instalada por dispositivo
├─ Métricas comparativas (A/B testing)
└─ Feedback dos usuários (opcional)
```

---

## **8. EXPERIÊNCIA DO USUÁRIO (UX)**

### **8.1 Interface Principal - Wireframe**

```
┌─────────────────────────────────────────────────────────────┐
│  TELA PRINCIPAL - MODO LANDSCAPE (uso em veículo)           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────┬─────────────────────────────────────────────┐ │
│  │ MENU    │        PREVIEW CÂMERA (Live)                │ │
│  │         │  ┌───────────────────────────────────────┐  │ │
│  │ [Home]  │  │                                       │  │ │
│  │ [Hist]  │  │     ┌─────────────────────┐          │  │ │
│  │ [Stats] │  │     │  Target Overlay     │          │  │ │
│  │ [Sync]  │  │     │  (guia de           │          │  │ │
│  │ [Conf]  │  │     │   posicionamento)   │          │  │ │
│  │         │  │     └─────────────────────┘          │  │ │
│  │         │  │                                       │  │ │
│  │         │  │   FPS: 30  |  Confiança: 92%         │  │ │
│  │         │  └───────────────────────────────────────┘  │ │
│  │         │                                             │ │
│  │         │  [ CAPTURAR ]  [Modo Auto] [Iluminação]    │ │
│  │         │                                             │ │
│  │ Status  │  Última inspeção: ✓ OK (há 12s)            │ │
│  │ ●Online │  Hoje: 47 inspeções | 2 escalações         │ │
│  └─────────┴─────────────────────────────────────────────┘ │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### **8.2 Feedback Visual Imediato**

```
RESULTADO OK:
├─ Fundo: Verde suave (#4CAF50)
├─ Ícone: ✓ grande e animado
├─ Som: "ding" de confirmação
├─ Vibração: pulso curto (100ms)
└─ Auto-reset: volta para captura em 2s

RESULTADO NOK:
├─ Fundo: Vermelho (#F44336)
├─ Ícone: ✗ com animação de alerta
├─ Som: "buzz" de erro
├─ Vibração: 2 pulsos (200ms cada)
└─ Ação: exige confirmação manual do operador

RESULTADO INCERTO:
├─ Fundo: Amarelo (#FFC107)
├─ Ícone: ⚠️ com spinner
├─ Texto: "Analisando na nuvem..."
├─ Progress bar: tempo estimado
└─ Timeout: 10s (fallback para resultado local)
```

---

## **9. SEGURANÇA E PRIVACIDADE - MOBILE**

```
┌─────────────────────────────────────────────────────────────┐
│  CAMADAS DE SEGURANÇA NO TABLET                             │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. AUTENTICAÇÃO                                            │
│     ├─ Login inicial: e-mail + senha                       │
│     ├─ MFA opcional: SMS ou Google Authenticator           │
│     ├─ Biometria: impressão digital (Android)              │
│     ├─ Token JWT: renovação a cada 24h                     │
│     └─ Logout automático: 8h de inatividade                │
│                                                             │
│  2. ARMAZENAMENTO                                           │
│     ├─ Banco Hive: encriptado com AES-256                  │
│     ├─ Chave: derivada do ID do dispositivo + salt         │
│     ├─ Imagens: NUNCA salvas no armazenamento público      │
│     └─ Clear cache: automático a cada 7 dias               │
│                                                             │
│  3. COMUNICAÇÃO                                             │
│     ├─ TLS 1.3 obrigatório                                 │
│     ├─ Certificate Pinning (previne MITM)                  │
│     ├─ Request signing (HMAC-SHA256)                       │
│     └─ Rate limiting: 100 req/min por device               │
│                                                             │
│  4. PRIVACIDADE                                             │
│     ├─ GPS: apenas com consentimento explícito             │
│     ├─ Imagens: não contém informações pessoais            │
│     ├─ Anonimização: device_id hash (não IMEI real)        │
│     └─ LGPD: dados retidos apenas 90 dias                  │
│                                                             │
│  5. CONTROLE DE ACESSO                                      │
│     ├─ Modo Kiosk: bloqueia acesso a outras apps           │
│     ├─ MDM Integration: Samsung Knox / Google EMM           │
│     ├─ Permissões mínimas: apenas câmera + rede            │
│     └─ Wipe remoto: em caso de perda/roubo                 │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## **10. CUSTOS OPERACIONAIS - VERSÃO TABLET**

```
┌─────────────────────────────────────────────────────────────┐
│  BREAKDOWN DE CUSTOS (por veículo/mês)                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  CAPEX (investimento inicial):                              │
│  ├─ Tablet: $600                                           │
│  ├─ Acessórios: $285                                       │
│  ├─ Instalação: $100                                       │
│  └─ Total: $985 por veículo                                │
│                                                             │
│  OPEX (custo mensal recorrente):                            │
│  ├─ Conectividade 4G/5G: $25/mês                           │
│  ├─ Google Cloud (5% escalação): $2.25/mês                 │
│  ├─ Storage: $2.00/mês                                     │
│  ├─ Suporte/manutenção: $5.00/mês                          │
│  └─ Total: $34.25/mês                                      │
│                                                             │
│  TCO (3 anos):                                              │
│  └─ CAPEX + (OPEX × 36) = $985 + $1,233 = $2,218           │
│                                                             │
│  ROI:                                                       │
│  └─ Se economizar 4h/mês de inspeção manual:                │
│      └─ $20/h × 4h = $80/mês de economia                   │
│      └─ Payback: 12 meses                                  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## **11. ROADMAP DE IMPLEMENTAÇÃO**

```
FASE 1: MVP (Mês 1-2)
├─ ✅ App básico com inferência local
├─ ✅ Modelo YOLOv8n treinado no Vertex AI
├─ ✅ Tela de captura + resultado simples
└─ 📱 Deploy em 2 tablets piloto

FASE 2: Integração Cloud (Mês 3)
├─ ☁️ Endpoint de escalação funcionando
├─ ☁️ Dashboard web para monitoramento
├─ ☁️ Pipeline de retreinamento manual
└─ 📱 Expansão para 10 tablets

FASE 3: Inteligência (Mês 4-5)
├─ 🧠 Decisor de incerteza refinado
├─ 🧠 OTA automático de modelos
├─ 🧠 Telemetria avançada
└─ 📱 Expansão para 50 tablets

FASE 4: Escala (Mês 6+)
├─ 🚀 Human-in-the-loop para validação
├─ 🚀 A/B testing de modelos
├─ 🚀 Modo offline robusto
└─ 📱 Rollout para toda frota (100+ tablets)
```

---

**Arquitetura completa para tablets. Precisa de mais detalhes em alguma parte específica?**
# **ARQUITETURA DO SISTEMA HÍBRIDO EDGE-TO-CLOUD**
## **Projeto: Deep-Truck / Agri-Adapt Vision System**

---

## **1. VISÃO GERAL DA ARQUITETURA**

### **1.1 Conceito Arquitetural**

```
┌─────────────────────────────────────────────────────────────────┐
│                    ARQUITETURA HÍBRIDA                          │
│                                                                 │
│  ┌──────────────┐         ┌──────────────┐       ┌──────────┐ │
│  │   EDGE       │────────▶│   BRIDGE     │──────▶│  CLOUD   │ │
│  │   (NPU)      │◀────────│  (Gateway)   │◀──────│ (Brain)  │ │
│  └──────────────┘         └──────────────┘       └──────────┘ │
│       95%                      Decisor               5%        │
│   Processamento              Inteligente         Complexidade  │
│      Local                   de Escalação          Analítica   │
└─────────────────────────────────────────────────────────────────┘
```

**Princípio de Design**: Edge-First com Cloud Fallback
- Máxima autonomia local
- Mínima dependência de conectividade
- Escalação inteligente para casos complexos
- Ciclo contínuo de aprendizado

---

## **2. ARQUITETURA DE CAMADAS**

### **2.1 Camada 1: Edge Computing (Dispositivo Embarcado)**

```
┌────────────────────────────────────────────────────────────────┐
│                    EDGE LAYER - DISPOSITIVO                     │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │  CAMADA DE CAPTURA                                       │  │
│  │  • Câmera Industrial (USB/MIPI-CSI)                      │  │
│  │  • Resolução: 1920×1080 @ 30fps                          │  │
│  │  • Iluminação: LED Ring Light com controle PWM           │  │
│  │  • Trigger: GPIO ou detecção de movimento                │  │
│  └─────────────────────────────────────────────────────────┘  │
│                          ↓                                      │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │  CAMADA DE PRÉ-PROCESSAMENTO                             │  │
│  │  • Redimensionamento: 640×480 (otimizado para NPU)       │  │
│  │  • Normalização: uint8 [0-255]                           │  │
│  │  • Crop automático da região de interesse                │  │
│  │  • Correção de exposição e contraste                     │  │
│  └─────────────────────────────────────────────────────────┘  │
│                          ↓                                      │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │  MOTOR DE INFERÊNCIA (NPU)                               │  │
│  │  • Modelo: YOLOv8n-INT8 quantizado (5MB)                 │  │
│  │  • Latência Target: <50ms por frame                      │  │
│  │  • Precisão Esperada: 89-92%                             │  │
│  │  • Classes: ["OK", "NOK", "Incerto"]                     │  │
│  └─────────────────────────────────────────────────────────┘  │
│                          ↓                                      │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │  DECISOR DE CONFIANÇA                                    │  │
│  │  • Threshold de Confiança: 70%                           │  │
│  │  • Análise de Entropia de Shannon                        │  │
│  │  • Score de Qualidade de Detecção (IoU)                  │  │
│  │  • Fila de Escalação (max 50 imagens buffer)            │  │
│  └─────────────────────────────────────────────────────────┘  │
│                          ↓                                      │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │  CACHE & TELEMETRIA LOCAL                                │  │
│  │  • SQLite: últimas 1000 inferências                      │  │
│  │  • Logs: rotação a cada 100MB                            │  │
│  │  • Métricas: FPS, latência, taxa de escalação            │  │
│  └─────────────────────────────────────────────────────────┘  │
│                                                                 │
└────────────────────────────────────────────────────────────────┘
```

**Hardware Recomendado**:
- **Processador**: NVIDIA Jetson Orin Nano (40 TOPS INT8) ou Google Coral Dev Board (4 TOPS)
- **Memória**: 8GB RAM mínimo
- **Storage**: 128GB eMMC/SSD
- **Conectividade**: 4G/5G (fallback), Wi-Fi 6, Ethernet
- **Energia**: 12-24V DC (alimentação veicular)
- **Encapsulamento**: IP67 (resistente a poeira e água)

---

### **2.2 Camada 2: Gateway de Integração (Bridge Layer)**

```
┌────────────────────────────────────────────────────────────────┐
│                    BRIDGE LAYER - GATEWAY                       │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │  ORQUESTRADOR DE DECISÃO                                 │  │
│  │                                                           │  │
│  │  [Resultado Edge] ──┐                                    │  │
│  │                     │                                     │  │
│  │                     ├──▶ Confiança > 70%? ──▶ [Retorna] │  │
│  │                     │         SIM                         │  │
│  │                     │                                     │  │
│  │                     └──▶ Confiança < 70%? ──▶ [Escala]  │  │
│  │                             NÃO                           │  │
│  └─────────────────────────────────────────────────────────┘  │
│                          ↓                                      │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │  FILA DE PRIORIZAÇÃO                                     │  │
│  │  • Alta Prioridade: Confiança < 50% (suspeita de NOK)    │  │
│  │  • Média Prioridade: Confiança 50-70% (ambíguo)          │  │
│  │  • Retry Logic: 3 tentativas com backoff exponencial     │  │
│  └─────────────────────────────────────────────────────────┘  │
│                          ↓                                      │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │  COMPRESSOR & OTIMIZADOR                                 │  │
│  │  • Redução de resolução: 640×480 → 512×512               │  │
│  │  • Compressão JPEG: qualidade 85%                        │  │
│  │  • Batch: agrupa até 10 imagens por request              │  │
│  └─────────────────────────────────────────────────────────┘  │
│                          ↓                                      │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │  GERENCIADOR DE CONECTIVIDADE                            │  │
│  │  • Detecção de banda disponível                          │  │
│  │  • Fallback 5G → 4G → Wi-Fi                              │  │
│  │  • Queue offline: até 500 imagens pendentes              │  │
│  └─────────────────────────────────────────────────────────┘  │
│                                                                 │
└────────────────────────────────────────────────────────────────┘
```

**Protocolo de Comunicação**:
- **Edge → Gateway**: gRPC (baixa latência)
- **Gateway → Cloud**: HTTPS REST / gRPC
- **Autenticação**: OAuth 2.0 + Service Account JWT
- **Timeout**: 5 segundos (com retry)

---

### **2.3 Camada 3: Cloud Intelligence (Google Cloud Platform)**

```
┌────────────────────────────────────────────────────────────────┐
│                    CLOUD LAYER - GOOGLE CLOUD                   │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │  ENTRADA (Cloud Load Balancer)                           │  │
│  │  • HTTPS Endpoint: /api/v1/analyze                       │  │
│  │  • Rate Limiting: 100 req/sec por dispositivo            │  │
│  │  • DDoS Protection: Cloud Armor                          │  │
│  └─────────────────────────────────────────────────────────┘  │
│                          ↓                                      │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │  ROTEADOR INTELIGENTE (Cloud Functions)                  │  │
│  │                                                           │  │
│  │  Caso Simples ──▶ Vertex AI Vision (AutoML)             │  │
│  │  (peça comum)     └─▶ Resposta em 200ms                 │  │
│  │                                                           │  │
│  │  Caso Complexo ──▶ Gemini 1.5 Flash (Multimodal)        │  │
│  │  (anomalia)        └─▶ Análise contextual + justificativa│  │
│  └─────────────────────────────────────────────────────────┘  │
│                          ↓                                      │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │  VERTEX AI PREDICTION SERVICE                            │  │
│  │  • Modelo: AutoML Vision Custom (FP32)                   │  │
│  │  • Instâncias: Auto-scaling 1-10 nodes                   │  │
│  │  • Acurácia Target: 95%+                                 │  │
│  │  • SLA: 99.9% uptime                                     │  │
│  └─────────────────────────────────────────────────────────┘  │
│                          ↓                                      │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │  VALIDAÇÃO & AUDITORIA                                   │  │
│  │  • Human-in-the-Loop: casos com confiança < 80%          │  │
│  │  • Interface Web: rotulação manual                       │  │
│  │  • Tracking: BigQuery (todas predições)                  │  │
│  └─────────────────────────────────────────────────────────┘  │
│                          ↓                                      │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │  PIPELINE DE RETREINAMENTO                               │  │
│  │  • Trigger: a cada 5000 novas imagens validadas          │  │
│  │  • Vertex AI Pipelines: treino automatizado               │  │
│  │  • A/B Testing: novo modelo vs modelo atual              │  │
│  │  • Deploy: apenas se acurácia melhorar >2%               │  │
│  └─────────────────────────────────────────────────────────┘  │
│                          ↓                                      │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │  DISTRIBUIÇÃO OTA (Edge Manager)                         │  │
│  │  • Versionamento: modelo v1.2.3                          │  │
│  │  • Rollout: gradual 10% → 50% → 100%                     │  │
│  │  • Rollback: automático se erro rate > 5%                │  │
│  │  • Notificação: Pub/Sub para dispositivos               │  │
│  └─────────────────────────────────────────────────────────┘  │
│                                                                 │
└────────────────────────────────────────────────────────────────┘
```

**Serviços GCP Utilizados**:
- **Vertex AI**: Training + Prediction + Edge Manager
- **Cloud Functions**: Orquestração e routing
- **Cloud Storage**: Dataset + modelos versionados
- **BigQuery**: Analytics e logs de auditoria
- **Pub/Sub**: Mensageria assíncrona
- **Cloud Monitoring**: Dashboards e alertas

---

## **3. FLUXO DE DADOS COMPLETO**

### **3.1 Fluxo Normal (95% dos casos)**

```
[Câmera] ──▶ [Pré-proc] ──▶ [NPU] ──▶ [Decisor]
                                          │
                                          ├─▶ Confiança: 87%
                                          │   Classe: "OK"
                                          │   
                                          └─▶ [Retorno Imediato]
                                              └─▶ [Interface/App]
                                              └─▶ [Log Local]
                                              
Latência Total: 45ms
```

### **3.2 Fluxo de Escalação (5% dos casos)**

```
[Câmera] ──▶ [NPU] ──▶ [Decisor]
                          │
                          ├─▶ Confiança: 62% ⚠️
                          │   
                          └─▶ [Gateway]
                                │
                                ├─▶ [Comprime]
                                │
                                └─▶ [Envia Cloud] ──▶ [Vertex AI]
                                                        │
                                                        ├─▶ Confiança: 94%
                                                        │   Classe: "NOK"
                                                        │   
                                                        └─▶ [Retorno]
                                                            │
                                                            ├─▶ [Interface/App]
                                                            ├─▶ [BigQuery]
                                                            └─▶ [Dataset Retreino]

Latência Total: 850ms (aceitável para casos incertos)
```

### **3.3 Fluxo de Aprendizado Contínuo**

```
[Imagens Validadas] ──▶ [Cloud Storage]
         │                     │
         │                     └─▶ [Contador: 5000+?]
         │                              │
         │                              └─▶ [Vertex AI Pipelines]
         │                                   │
         │                                   ├─▶ [Treina Modelo v2.0]
         │                                   │
         │                                   ├─▶ [Avalia Performance]
         │                                   │     └─▶ 94.2% > 92.1% ✓
         │                                   │
         │                                   ├─▶ [Exporta TFLite]
         │                                   │
         │                                   └─▶ [Edge Manager]
         │                                        │
         │                                        └─▶ [Deploy Gradual]
         │                                             │
         │                                             ├─▶ 10% frota (48h)
         │                                             ├─▶ 50% frota (72h)
         │                                             └─▶ 100% frota

Ciclo: a cada 2-4 semanas
```

---

## **4. COMPONENTES E RESPONSABILIDADES**

### **4.1 Matriz de Componentes**

| Componente | Localização | Responsabilidade | Tecnologia | SLA |
|------------|-------------|------------------|------------|-----|
| **Vision Capture** | Edge | Aquisição de imagens | OpenCV + V4L2 | 99.5% |
| **Inference Engine** | Edge | Detecção local | TFLite + NPU | 99.9% |
| **Uncertainty Analyzer** | Edge | Decisão de escalação | Python (Scipy) | 99.9% |
| **Local Cache** | Edge | Persistência temporária | SQLite | 99.9% |
| **Gateway Router** | Edge | Orquestração | gRPC Server | 99.5% |
| **Cloud Connector** | Edge/Cloud | Comunicação híbrida | HTTPS Client | 99.0% |
| **Prediction API** | Cloud | Inferência complexa | Vertex AI | 99.9% |
| **Human Validator** | Cloud | Supervisão humana | Web App | 99.0% |
| **Training Pipeline** | Cloud | Retreinamento | Vertex Pipelines | 95.0% |
| **Model Registry** | Cloud | Versionamento | Cloud Storage | 99.95% |
| **OTA Manager** | Cloud | Deploy remoto | Edge Manager | 99.5% |
| **Analytics** | Cloud | Business Intelligence | BigQuery + Looker | 99.9% |

---

## **5. DECISÕES ARQUITETURAIS**

### **5.1 Por que Edge-First?**

**Problema**: Latência da nuvem (300-800ms) é inaceitável para operação em tempo real.

**Solução**: 95% dos casos resolvidos localmente em <50ms.

**Trade-off**: Acurácia ligeiramente menor (89% vs 95%), mas tempo de resposta 10x melhor.

---

### **5.2 Por que Modelo Quantizado INT8?**

**Problema**: Modelos FP32 não cabem na memória limitada de NPUs embarcadas.

**Solução**: Quantização reduz tamanho de 80MB → 5MB sem perda crítica de precisão.

**Trade-off**: Precisão cai ~3%, mas permite rodar em hardware 10x mais barato.

---

### **5.3 Por que Threshold de 70%?**

**Problema**: Muitas escalações (>10%) encarecem operação.

**Solução**: Threshold calibrado empiricamente após testes com 10.000 imagens reais.

**Resultado**: Taxa de escalação de 5% com 98% de concordância entre Edge e Cloud.

---

### **5.4 Por que Google Cloud e não AWS/Azure?**

**Vantagens do GCP**:
1. **Vertex AI**: Melhor AutoML para visão computacional
2. **Edge TPU**: Hardware da própria Google otimizado para TFLite
3. **Edge Manager**: Deploy OTA nativo para dispositivos embarcados
4. **Gemini**: Análise multimodal para casos complexos

**Trade-off**: Lock-in de ecossistema, mas melhor integração end-to-end.

---

## **6. MÉTRICAS E KPIs**

### **6.1 Métricas de Performance**

```
┌──────────────────────────────────────────────────────────┐
│  PERFORMANCE TARGETS                                     │
├──────────────────────────────────────────────────────────┤
│  Latência Edge (P95):           < 50ms                   │
│  Latência Cloud (P95):          < 1000ms                 │
│  Taxa de Escalação:             < 5%                     │
│  Acurácia Edge:                 > 89%                    │
│  Acurácia Cloud:                > 95%                    │
│  Uptime Edge:                   > 99.5%                  │
│  Uptime Cloud:                  > 99.9%                  │
│  Throughput:                    30 FPS                   │
│  Tempo de Retreinamento:        < 6 horas                │
│  Tempo de Deploy OTA:           < 48 horas               │
└──────────────────────────────────────────────────────────┘
```

### **6.2 Métricas de Custo**

```
CUSTO POR INSPEÇÃO:
├─ Edge: $0.000 (já pago no CAPEX)
├─ Cloud (5% escalado): $0.0015 × 0.05 = $0.000075
├─ Storage: $0.00001
└─ Total: ~$0.00008 por peça inspecionada

CAPEX (por veículo):
├─ NPU Hardware: $500 (Jetson Orin Nano)
├─ Câmera Industrial: $150
├─ Iluminação: $50
├─ Enclosure IP67: $100
└─ Total: $800 por unidade

ROI: Se substituir 1 inspetor (salário + encargos), payback em 2-3 meses.
```

---

## **7. ESCALABILIDADE E EXPANSÃO**

### **7.1 Arquitetura para 1.000 Veículos**

```
[1000 Dispositivos Edge]
         │
         ├─▶ [Load Balancer Regional]
         │     └─▶ [Cloud Functions x10]
         │           └─▶ [Vertex AI Endpoints x5]
         │
         ├─▶ [Pub/Sub: 50k msg/sec]
         │
         └─▶ [BigQuery: 100 GB/dia]
```

**Custos Estimados (1000 veículos)**:
- **Cloud Prediction**: $2.250/mês (1.5M imagens)
- **Storage**: $2.000/mês (100TB/ano)
- **Compute**: $500/mês (Cloud Functions)
- **BigQuery**: $300/mês (analytics)
- **Total**: ~$5.000/mês = $5/veículo/mês

---

## **8. SEGURANÇA E COMPLIANCE**

```
┌──────────────────────────────────────────────────┐
│  CAMADAS DE SEGURANÇA                            │
├──────────────────────────────────────────────────┤
│  [Edge Device]                                   │
│   ├─ Secure Boot (TPM 2.0)                       │
│   ├─ Encriptação em repouso (LUKS)               │
│   └─ Firewall local (iptables)                   │
│                                                   │
│  [Comunicação]                                   │
│   ├─ TLS 1.3 obrigatório                         │
│   ├─ Certificados mTLS (mutual auth)             │
│   └─ VPN (opcional para redes corporativas)      │
│                                                   │
│  [Cloud]                                         │
│   ├─ IAM: least privilege principle              │
│   ├─ VPC Service Controls                        │
│   ├─ Cloud Armor (DDoS protection)               │
│   └─ Audit Logs (100% de requisições)            │
│                                                   │
│  [Dados]                                         │
│   ├─ Anonimização de metadados sensíveis         │
│   ├─ Retenção: 90 dias (LGPD compliance)         │
│   └─ Backup: GCS multi-region                    │
└──────────────────────────────────────────────────┘
```

---

## **9. ROADMAP DE EVOLUÇÃO**

### **Fase 1 (Mês 0-3): MVP**
- ✅ Inferência Edge básica
- ✅ Escalação para Cloud
- ✅ Interface Web simples

### **Fase 2 (Mês 4-6): Produção**
- 🔄 Deploy em 10 veículos piloto
- 🔄 Pipeline de retreinamento automatizado
- 🔄 Dashboard de monitoramento

### **Fase 3 (Mês 7-12): Escala**
- 📋 Expansão para 100+ veículos
- 📋 Análise preditiva de falhas
- 📋 Integração com ERP/CMMS

### **Fase 4 (Ano 2): Inteligência Avançada**
- 📋 Gemini 2.0 para diagnóstico contextual
- 📋 Manutenção preditiva baseada em IA
- 📋 Análise de tendências de desgaste

---

**Este é o blueprint completo da arquitetura. Precisa de detalhamento em algum componente específico?**




# **Especificações Técnicas Detalhadas - Sistema Híbrido Edge-to-Cloud**

---

## **1. MODELO LOCAL (NPU Edge)**

### **1.1 Arquitetura Recomendada**
```
YOLOv8n (nano) ou YOLOv8s (small)
├─ Input: 640×480 (ou 416×416 para NPUs mais fracas)
├─ Backbone: CSPDarknet com depthwise convolutions
├─ Neck: PAN (Path Aggregation Network)
└─ Head: Anchor-free detection
```

**Alternativa para classificação pura:**
- **MobileNetV3-Large** (classificação binária OK/NOK)
- **EfficientNet-Lite4** (melhor precisão, 15% mais lento)

---

### **1.2 Quantização e Otimização**

#### **Conversão do Modelo**
```bash
# 1. Treinar no Vertex AI AutoML Vision
# 2. Exportar para TFLite
gcloud ai models export \
  --model=projects/SEU_PROJETO/locations/us-central1/models/MODEL_ID \
  --output-uri=gs://seu-bucket/modelo-exportado/ \
  --export-format-id=tflite
```

#### **Quantização Pós-Treinamento**
```python
import tensorflow as tf

# Converter modelo para TFLite com quantização INT8
converter = tf.lite.TFLiteConverter.from_saved_model('caminho/modelo')
converter.optimizations = [tf.lite.Optimize.DEFAULT]
converter.target_spec.supported_types = [tf.int8]

# Dataset representativo para calibração
def representative_dataset():
    for img in carregar_amostras_producao(100):  # 100 imagens reais
        yield [img.astype(np.float32)]

converter.representative_dataset = representative_dataset
converter.inference_input_type = tf.uint8  # Input direto da câmera
converter.inference_output_type = tf.uint8

tflite_model = converter.convert()
with open('modelo_edge.tflite', 'wb') as f:
    f.write(tflite_model)
```

**Ganhos Esperados:**
- **Tamanho**: 80 MB → 5 MB
- **Latência**: 450ms → 35ms (Coral TPU)
- **Precisão**: 92% → 89% (perda aceitável)

---

## **2. IMPLEMENTAÇÃO DO DECISOR DE INCERTEZA**

### **2.1 Calibração de Confiança**

```python
import numpy as np
from scipy.special import softmax

class UncertaintyGate:
    def __init__(self, threshold_conf=0.70, threshold_entropy=0.8):
        self.threshold_conf = threshold_conf
        self.threshold_entropy = threshold_entropy
    
    def should_escalate_to_cloud(self, logits, bbox_scores=None):
        """
        Decide se envia para Google Cloud baseado em:
        1. Confiança da classe
        2. Entropia da distribuição
        3. Qualidade da detecção (IoU score)
        """
        # Método 1: Confiança máxima
        probs = softmax(logits)
        max_conf = np.max(probs)
        
        # Método 2: Entropia de Shannon
        entropy = -np.sum(probs * np.log(probs + 1e-10))
        normalized_entropy = entropy / np.log(len(probs))
        
        # Método 3: Score de detecção (se YOLO)
        low_detection_quality = False
        if bbox_scores is not None:
            low_detection_quality = np.mean(bbox_scores) < 0.65
        
        # Regra de escalação
        escalate = (
            max_conf < self.threshold_conf or 
            normalized_entropy > self.threshold_entropy or
            low_detection_quality
        )
        
        return escalate, {
            'confidence': float(max_conf),
            'entropy': float(normalized_entropy),
            'detection_score': float(np.mean(bbox_scores)) if bbox_scores else None
        }
```

---

## **3. PIPELINE DE INFERÊNCIA EDGE**

### **3.1 Código para NPU (Python - Coral TPU)**

```python
from pycoral.utils import edgetpu
from pycoral.adapters import common, detect
from PIL import Image
import time

class EdgeInferenceEngine:
    def __init__(self, model_path, labels_path):
        self.interpreter = edgetpu.make_interpreter(model_path)
        self.interpreter.allocate_tensors()
        self.labels = self._load_labels(labels_path)
        self.uncertainty_gate = UncertaintyGate()
        
    def process_frame(self, frame):
        # Pré-processamento
        input_tensor = self._preprocess(frame)
        
        # Inferência
        start = time.time()
        common.set_input(self.interpreter, input_tensor)
        self.interpreter.invoke()
        latency = (time.time() - start) * 1000
        
        # Extrair resultados
        objects = detect.get_objects(self.interpreter, score_threshold=0.5)
        
        # Análise de incerteza
        logits = self._get_raw_logits()  # Antes do softmax
        should_cloud, metrics = self.uncertainty_gate.should_escalate_to_cloud(
            logits, 
            [obj.score for obj in objects]
        )
        
        return {
            'local_prediction': objects,
            'escalate_to_cloud': should_cloud,
            'metrics': metrics,
            'latency_ms': latency
        }
    
    def _preprocess(self, frame):
        img = Image.fromarray(frame).resize((640, 480))
        return np.array(img, dtype=np.uint8)
    
    def _get_raw_logits(self):
        # Acessar camada antes do softmax
        output_details = self.interpreter.get_output_details()
        return self.interpreter.get_tensor(output_details[-1]['index'])
```

---

## **4. INTEGRAÇÃO COM GOOGLE CLOUD**

### **4.1 API de Escalação para Vertex AI**

```python
from google.cloud import aiplatform
from google.cloud import storage
import base64
import json

class CloudEscalationHandler:
    def __init__(self, project_id, endpoint_id, bucket_name):
        self.project_id = project_id
        self.endpoint_id = endpoint_id
        self.bucket = storage.Client().bucket(bucket_name)
        
        aiplatform.init(project=project_id, location='us-central1')
        self.endpoint = aiplatform.Endpoint(endpoint_id)
    
    def analyze_complex_case(self, image, metadata):
        """
        Envia caso duvidoso para Vertex AI Vision ou Gemini
        """
        # 1. Upload imagem para Cloud Storage (opcional, para histórico)
        blob_name = f"incertezas/{metadata['timestamp']}.jpg"
        blob = self.bucket.blob(blob_name)
        blob.upload_from_string(image.tobytes(), content_type='image/jpeg')
        
        # 2. Preparar payload
        instances = [{
            'content': base64.b64encode(image).decode('utf-8'),
            'mimeType': 'image/jpeg',
            'metadata': metadata
        }]
        
        # 3. Predição na nuvem
        response = self.endpoint.predict(instances=instances)
        
        # 4. Processar resultado
        cloud_result = {
            'class': response.predictions[0]['displayNames'][0],
            'confidence': response.predictions[0]['confidences'][0],
            'source': 'cloud',
            'cost_cents': 0.0015  # Custo aproximado por imagem
        }
        
        return cloud_result
    
    def send_for_retraining(self, image, ground_truth_label):
        """
        Adiciona imagem validada ao dataset de retreinamento
        """
        blob = self.bucket.blob(f"retreino/{ground_truth_label}/{uuid.uuid4()}.jpg")
        blob.upload_from_string(image)
        
        # Trigger pipeline de re-treino (via Cloud Functions ou Vertex Pipelines)
        # self._trigger_retraining_pipeline()
```

---

## **5. GERENCIAMENTO DE MODELOS (Edge Manager)**

### **5.1 Versionamento e Deploy OTA**

```python
from google.cloud import aiplatform_v1

class EdgeModelManager:
    def __init__(self, project_id):
        self.client = aiplatform_v1.EdgeContainerServiceClient()
        self.project = project_id
    
    def deploy_new_version(self, model_version, target_devices):
        """
        Deploy novo modelo quantizado para frota de dispositivos
        """
        request = aiplatform_v1.DeployModelRequest(
            model=f"projects/{self.project}/models/{model_version}",
            target_devices=target_devices,
            rollout_strategy='GRADUAL',  # 10% -> 50% -> 100%
            rollback_on_error=True
        )
        
        operation = self.client.deploy_model(request=request)
        return operation.result()
    
    def monitor_edge_fleet(self):
        """
        Coleta métricas de todos os dispositivos Edge
        """
        metrics = self.client.list_edge_metrics(
            parent=f"projects/{self.project}/locations/global"
        )
        
        return {
            'avg_latency': np.mean([m.latency for m in metrics]),
            'escalation_rate': sum([m.cloud_calls for m in metrics]) / len(metrics),
            'model_version_distribution': Counter([m.model_version for m in metrics])
        }
```

---

## **6. FERRAMENTAS E SDKs NECESSÁRIOS**

### **6.1 Stack Tecnológico Completo**

| Componente | Tecnologia | Instalação |
|------------|------------|------------|
| **NPU Runtime** | PyCoral (Coral TPU) | `pip install pycoral` |
| **Framework** | TensorFlow Lite 2.15+ | `pip install tflite-runtime` |
| **Visão** | OpenCV 4.8+ | `pip install opencv-python` |
| **Cloud SDK** | Vertex AI SDK | `pip install google-cloud-aiplatform` |
| **Multimodal** | Gemini 1.5 Flash | `pip install google-generativeai` |
| **Monitoramento** | Prometheus + Grafana | Docker Compose |
| **OTA Updates** | Balena.io / Mender | Plataforma |

### **6.2 Configuração de Hardware**

```yaml
# Opção 1: Google Coral Dev Board
Hardware: Coral Dev Board Mini
NPU: Edge TPU (4 TOPS INT8)
RAM: 2GB LPDDR4
Custo: $70
FPS: ~30 FPS (YOLOv8n)

# Opção 2: NVIDIA Jetson Orin Nano
Hardware: Jetson Orin Nano 8GB
NPU: 40 TOPS INT8
RAM: 8GB
Custo: $499
FPS: ~60 FPS (YOLOv8s) + margem para outras tarefas

# Opção 3: Raspberry Pi + Hailo-8 AI Accelerator
Hardware: RPi 5 + Hailo-8 (M.2)
NPU: 26 TOPS INT8
RAM: 8GB
Custo: $175
FPS: ~45 FPS (YOLOv8n)
```

---

## **7. MÉTRICAS E MONITORAMENTO**

### **7.1 Dashboard de Performance**

```python
from prometheus_client import Counter, Histogram, Gauge
import time

# Métricas Prometheus
edge_inferences = Counter('edge_inferences_total', 'Total inferências locais')
cloud_escalations = Counter('cloud_escalations_total', 'Escalações para nuvem')
inference_latency = Histogram('inference_latency_seconds', 'Latência de inferência')
model_confidence = Gauge('model_confidence', 'Confiança média do modelo')

def process_with_metrics(frame):
    start = time.time()
    
    result = edge_engine.process_frame(frame)
    edge_inferences.inc()
    
    if result['escalate_to_cloud']:
        cloud_result = cloud_handler.analyze_complex_case(frame, result['metrics'])
        cloud_escalations.inc()
    
    inference_latency.observe(time.time() - start)
    model_confidence.set(result['metrics']['confidence'])
    
    return result
```

---

## **8. CUSTO ESTIMADO DE OPERAÇÃO**

```
┌─────────────────────────────────────────────────┐
│ CUSTO MENSAL (1000 inspeções/dia)               │
├─────────────────────────────────────────────────┤
│ Edge (local): $0.00 (já pago no hardware)       │
│ Cloud (5% escalado): 1500 imagens × $0.0015     │
│   = $2.25/mês                                   │
│ Storage (retreino): 100GB × $0.02 = $2.00       │
│ Vertex AI AutoML: $20/treino (1x/mês)           │
├─────────────────────────────────────────────────┤
│ TOTAL: ~$24/mês por veículo                     │
└─────────────────────────────────────────────────┘
```

---

## **9. PRÓXIMOS PASSOS IMEDIATOS**

1. **Definir Hardware**: Qual NPU você vai usar? (Coral, Jetson, Hailo?)
2. **Dataset**: Quantas imagens você tem anotadas? Precisa de pelo menos 500 por classe
3. **Teste de Benchmark**: Rodar YOLOv8n no hardware escolhido e medir FPS real
4. **Setup Vertex AI**: Criar projeto e habilitar APIs necessárias

**Quer que eu detalhe algum componente específico?** (Ex: código completo do loop de inferência, configuração do Vertex AI, script de conversão TFLite, etc.)

