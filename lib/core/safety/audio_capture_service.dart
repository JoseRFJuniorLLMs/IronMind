import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'audio_classifier.dart';

class AudioCaptureService {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioEventClassifier _classifier = AudioEventClassifier();

  StreamController<AudioClassificationResult>? _resultStream;
  Timer? _captureTimer;

  bool _isRunning = false;

  Future<void> startMonitoring() async {
    if (_isRunning) return;

    await _classifier.initialize();
    _resultStream = StreamController<AudioClassificationResult>.broadcast();

    // Start continuous recording
    await _startRecording();

    // Process chunks every 975ms (frame length)
    _captureTimer = Timer.periodic(
      const Duration(milliseconds: 975),
      (_) => _processAudioChunk(),
    );

    _isRunning = true;
    print('🎤 Monitoring started');
  }

  Future<void> _startRecording() async {
    final tempDir = await getTemporaryDirectory();
    final path = '${tempDir.path}/temp_audio_chunk.pcm';

    // Ensure file is deleted if exists
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );
  }

  Future<void> _processAudioChunk() async {
    try {
      // Stop creates the file
      final path = await _recorder.stop();

      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          // Read bytes
          final bytes = await file.readAsBytes();
          // Convert to Float32
          final float32Samples = _convertToFloat32(bytes);

          // Classify
          final result = await _classifier.classifyAudio(float32Samples);

          if (result != null && result.isDanger) {
            _resultStream?.add(result);
          }

          // Delete temp file
          await file.delete();
        }

        // Restart recording
        await _startRecording();
      }
    } catch (e) {
      print('❌ Error processing audio: $e');
    }
  }

  Float32List _convertToFloat32(Uint8List bytes) {
    // PCM 16-bit to Float32 [-1.0, 1.0]
    final numSamples = bytes.length ~/ 2;
    final samples = Float32List(numSamples);
    final data = ByteData.view(bytes.buffer);

    for (int i = 0; i < numSamples; i++) {
      // Little Endian
      if ((i * 2 + 1) < bytes.length) {
        // Safety check
        int sample = data.getInt16(i * 2, Endian.little);
        samples[i] = sample / 32768.0;
      }
    }

    // Resize or pad to required length (15600)
    if (samples.length == 15600) {
      return samples;
    } else if (samples.length > 15600) {
      return Float32List.sublistView(samples, 0, 15600);
    } else {
      // Pad with zeros
      final padded = Float32List(15600);
      for (int i = 0; i < samples.length; i++) padded[i] = samples[i];
      return padded;
    }
  }

  Stream<AudioClassificationResult> get dangerStream {
    if (_resultStream == null) {
      _resultStream = StreamController<AudioClassificationResult>.broadcast();
    }
    return _resultStream!.stream;
  }

  Future<void> stopMonitoring() async {
    _isRunning = false;
    _captureTimer?.cancel();
    await _recorder.stop();
    await _resultStream?.close();
    _classifier.dispose();
  }

  /// ✅ PAUSE monitoring
  Future<void> pauseMonitoring() async {
    if (!_isRunning) return;
    _isRunning = false;
    _captureTimer?.cancel();
    await _recorder.stop();
    print('🎤 Monitoring PAUSED (Mic released)');
  }

  /// ✅ RESUME monitoring
  Future<void> resumeMonitoring() async {
    if (_isRunning) return;
    await startMonitoring();
  }

  bool get isRunning => _isRunning;
}
