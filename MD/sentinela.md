# Plano Completo: Integração Whisper Small no Flutter

## Fase 1: Escolha da Implementação

### Opção A: whisper.cpp (Recomendada) ⭐
- Mais rápida e otimizada
- Menor uso de bateria
- Suporta quantização (reduz tamanho)

### Opção B: whisper_flutter (Package pronto)
- Mais fácil de implementar
- Menos controle sobre otimizações

**Recomendo: Opção A (whisper.cpp via FFI)**

---

## Fase 2: Setup do Ambiente

### 2.1 Clonar whisper.cpp
```bash
git clone https://github.com/ggerganov/whisper.cpp
cd whisper.cpp
```

### 2.2 Baixar Modelo Whisper Small
```bash
# Baixar modelo original
bash ./models/download-ggml-model.sh small

# Ou baixar versão quantizada (menor, ~140 MB)
bash ./models/download-ggml-model.sh small-q5_1
```

**Modelos disponíveis:**
- `ggml-small.bin` (~466 MB)
- `ggml-small-q5_1.bin` (~140 MB) - 70% menor, ~5% perda precisão

### 2.3 Compilar para Android
```bash
cd whisper.cpp
mkdir build-android && cd build-android

# Configurar NDK
export ANDROID_NDK=/path/to/android-ndk

# Compilar para ARM64
cmake -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK/build/cmake/android.toolchain.cmake \
      -DANDROID_ABI=arm64-v8a \
      -DANDROID_PLATFORM=android-24 \
      ..
      
make
```

---

## Fase 3: Estrutura do Projeto Flutter

```
seu_projeto_flutter/
├── android/
│   └── app/src/main/
│       ├── jniLibs/
│       │   └── arm64-v8a/
│       │       └── libwhisper.so
│       └── assets/
│           └── models/
│               └── ggml-small-q5_1.bin
├── lib/
│   ├── services/
│   │   └── whisper_service.dart
│   └── bindings/
│       └── whisper_bindings.dart
└── pubspec.yaml
```

---

## Fase 4: Configuração Flutter

### 4.1 pubspec.yaml
```yaml
dependencies:
  flutter:
    sdk: flutter
  ffi: ^2.1.0
  path_provider: ^2.1.1
  record: ^5.0.4  # Para gravação de áudio
  permission_handler: ^11.0.1

flutter:
  assets:
    - assets/models/ggml-small-q5_1.bin
```

### 4.2 android/app/build.gradle
```gradle
android {
    // ...
    
    sourceSets {
        main {
            jniLibs.srcDirs = ['src/main/jniLibs']
        }
    }
    
    // Evitar compressão do modelo
    aaptOptions {
        noCompress "bin"
    }
}
```

---

## Fase 5: Implementação Dart/FFI

### 5.1 whisper_bindings.dart
```dart
import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart';

// Definir estruturas C
class WhisperContext extends ffi.Opaque {}

typedef WhisperInitNative = ffi.Pointer<WhisperContext> Function(
  ffi.Pointer<ffi.Char> modelPath,
);
typedef WhisperInitDart = ffi.Pointer<WhisperContext> Function(
  ffi.Pointer<ffi.Char> modelPath,
);

typedef WhisperFullNative = ffi.Int32 Function(
  ffi.Pointer<WhisperContext> ctx,
  ffi.Pointer<ffi.Float> samples,
  ffi.Int32 nSamples,
);
typedef WhisperFullDart = int Function(
  ffi.Pointer<WhisperContext> ctx,
  ffi.Pointer<ffi.Float> samples,
  int nSamples,
);

typedef WhisperGetTextNative = ffi.Pointer<ffi.Char> Function(
  ffi.Pointer<WhisperContext> ctx,
);
typedef WhisperGetTextDart = ffi.Pointer<ffi.Char> Function(
  ffi.Pointer<WhisperContext> ctx,
);

class WhisperBindings {
  late final ffi.DynamicLibrary _lib;
  late final WhisperInitDart whisperInit;
  late final WhisperFullDart whisperFull;
  late final WhisperGetTextDart whisperGetText;

  WhisperBindings() {
    _lib = Platform.isAndroid
        ? ffi.DynamicLibrary.open('libwhisper.so')
        : ffi.DynamicLibrary.process();

    whisperInit = _lib
        .lookup<ffi.NativeFunction<WhisperInitNative>>('whisper_init')
        .asFunction();

    whisperFull = _lib
        .lookup<ffi.NativeFunction<WhisperFullNative>>('whisper_full')
        .asFunction();

    whisperGetText = _lib
        .lookup<ffi.NativeFunction<WhisperGetTextNative>>('whisper_get_text')
        .asFunction();
  }
}
```

### 5.2 whisper_service.dart
```dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'whisper_bindings.dart';
import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';

class WhisperService {
  WhisperBindings? _bindings;
  ffi.Pointer<WhisperContext>? _context;
  bool _initialized = false;

  // Singleton
  static final WhisperService _instance = WhisperService._internal();
  factory WhisperService() => _instance;
  WhisperService._internal();

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // 1. Copiar modelo para diretório acessível
      final modelPath = await _copyModelToLocal();
      
      // 2. Inicializar bindings
      _bindings = WhisperBindings();
      
      // 3. Inicializar contexto Whisper
      final pathPointer = modelPath.toNativeUtf8();
      _context = _bindings!.whisperInit(pathPointer.cast());
      calloc.free(pathPointer);

      if (_context == ffi.nullptr) {
        throw Exception('Falha ao inicializar Whisper');
      }

      _initialized = true;
      print('✅ Whisper inicializado com sucesso');
    } catch (e) {
      print('❌ Erro ao inicializar Whisper: $e');
      rethrow;
    }
  }

  Future<String> _copyModelToLocal() async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelFile = File('${appDir.path}/ggml-small-q5_1.bin');

    // Copiar apenas se não existir
    if (!await modelFile.exists()) {
      print('📥 Copiando modelo (pode demorar)...');
      final data = await rootBundle.load('assets/models/ggml-small-q5_1.bin');
      await modelFile.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      print('✅ Modelo copiado');
    }

    return modelFile.path;
  }

  Future<String> transcribe(String audioPath) async {
    if (!_initialized || _context == ffi.nullptr) {
      throw Exception('Whisper não inicializado');
    }

    // 1. Ler áudio WAV (16kHz, mono, 16-bit PCM)
    final samples = await _loadAudioSamples(audioPath);
    
    // 2. Alocar memória para samples
    final samplesPointer = calloc<ffi.Float>(samples.length);
    for (int i = 0; i < samples.length; i++) {
      samplesPointer[i] = samples[i];
    }

    // 3. Executar transcrição
    final result = _bindings!.whisperFull(
      _context!,
      samplesPointer,
      samples.length,
    );

    if (result != 0) {
      calloc.free(samplesPointer);
      throw Exception('Erro na transcrição: código $result');
    }

    // 4. Obter texto
    final textPointer = _bindings!.whisperGetText(_context!);
    final text = textPointer.cast<Utf8>().toDartString();

    // 5. Limpar memória
    calloc.free(samplesPointer);

    return text;
  }

  Future<List<double>> _loadAudioSamples(String path) async {
    // Aqui você precisa converter o áudio para:
    // - 16kHz sample rate
    // - Mono
    // - Float32 normalizado [-1.0, 1.0]
    
    final file = File(path);
    final bytes = await file.readAsBytes();
    
    // Assumindo WAV 16-bit PCM já no formato correto
    final samples = <double>[];
    for (int i = 44; i < bytes.length; i += 2) {
      final sample = bytes[i] | (bytes[i + 1] << 8);
      final normalized = sample / 32768.0;
      samples.add(normalized);
    }
    
    return samples;
  }

  void dispose() {
    // Liberar recursos (implementar whisper_free no C)
    _context = ffi.nullptr;
    _initialized = false;
  }
}
```

---

## Fase 6: UI de Exemplo

### main.dart
```dart
import 'package:flutter/material.dart';
import 'services/whisper_service.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar Whisper (pode demorar)
  await WhisperService().initialize();
  
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _recorder = AudioRecorder();
  final _whisper = WhisperService();
  
  bool _isRecording = false;
  bool _isTranscribing = false;
  String _transcription = '';

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      // Parar gravação
      final path = await _recorder.stop();
      if (path != null) {
        setState(() {
          _isRecording = false;
          _isTranscribing = true;
        });
        
        // Transcrever
        try {
          final text = await _whisper.transcribe(path);
          setState(() {
            _transcription = text;
            _isTranscribing = false;
          });
        } catch (e) {
          setState(() {
            _transcription = 'Erro: $e';
            _isTranscribing = false;
          });
        }
      }
    } else {
      // Iniciar gravação
      final tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/recording.wav';
      
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: path,
      );
      
      setState(() {
        _isRecording = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('Whisper Flutter')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isTranscribing)
                CircularProgressIndicator()
              else
                Text(
                  _transcription.isEmpty 
                    ? 'Pressione o botão para gravar' 
                    : _transcription,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18),
                ),
              SizedBox(height: 40),
              FloatingActionButton(
                onPressed: _isTranscribing ? null : _toggleRecording,
                backgroundColor: _isRecording ? Colors.red : Colors.blue,
                child: Icon(_isRecording ? Icons.stop : Icons.mic),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

---

## Fase 7: Otimizações

### 7.1 Usar modelo quantizado
```bash
# Em vez de small.bin (466 MB)
# Use small-q5_1.bin (~140 MB)
# Perda mínima de precisão
```

### 7.2 Implementar streaming
```dart
// Processar áudio em chunks ao invés de arquivo completo
// Usar whisper_full_parallel para múltiplos segmentos
```

### 7.3 Cache inteligente
```dart
// Não recarregar modelo a cada transcrição
// Manter contexto em memória
```

---

## Fase 8: Testes

### 8.1 Testar performance
- Tempo de inicialização
- Tempo de transcrição (segundos de áudio / segundo real)
- Uso de memória RAM
- Impacto na bateria

### 8.2 Testar qualidade
- Sotaques diferentes (PT-PT vs PT-BR)
- Ruído de fundo
- Múltiplos falantes

---

## Cronograma Estimado

- **Dia 1-2**: Setup e compilação (Fases 1-2)
- **Dia 3-4**: Implementação FFI (Fase 5)
- **Dia 5**: UI e integração (Fase 6)
- **Dia 6-7**: Testes e otimização (Fases 7-8)

---

## Alternativa Mais Rápida 🚀

Se quiser pular a implementação FFI, use o package pronto:

```yaml
dependencies:
  whisper_flutter: ^1.0.0
```

Mas terá menos controle sobre otimizações.

---
