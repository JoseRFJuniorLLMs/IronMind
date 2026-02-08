import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:sound_stream/sound_stream.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';

class NativeAudioService {
  final Logger _logger = Logger();

  // Streams
  final RecorderStream _recorder = RecorderStream();
  final PlayerStream _player = PlayerStream();

  // Config
  // Gemini Input: 16kHz
  static const int INPUT_SAMPLE_RATE = 16000;
  // Gemini Output: 24kHz
  static const int OUTPUT_SAMPLE_RATE = 24000;

  StreamSubscription? _audioSubscription;
  Function(List<int>)? onAudioRecorded;

  // ✅ New: Volume Stream for Visualizer
  final _volumeController = StreamController<double>.broadcast();
  Stream<double> get volumeStream => _volumeController.stream;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _logger.i('🎙️ Initializing Native Audio Service...');

      // Request Permissions
      var status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        throw Exception("Microphone permission denied");
      }

      // Init Recorder (16kHz Mono PCM16)
      // sound_stream 0.4.x API - simplified params
      await _recorder.initialize(
        sampleRate: INPUT_SAMPLE_RATE,
      );

      // Init Player (24kHz Mono PCM16)
      await _player.initialize(
        sampleRate: OUTPUT_SAMPLE_RATE,
      );

      _isInitialized = true;
      _logger.i(
          '✅ Native Audio Initialized (In: ${INPUT_SAMPLE_RATE}Hz / Out: ${OUTPUT_SAMPLE_RATE}Hz)');
    } catch (e) {
      _logger.e('❌ Native Audio Init Error: $e');
      rethrow;
    }
  }

  Future<void> start() async {
    if (!_isInitialized) await initialize();

    _logger.i('▶️ Starting Audio Capture...');

    // Listen to mic stream
    _audioSubscription = _recorder.audioStream.listen((data) {
      if (onAudioRecorded != null) {
        // data is Uint8List (PCM bytes)
        onAudioRecorded!(data);
      }

      // ✅ Calculate RMS for Volume Visualizer
      _calculateVolume(data);
    });

    await _recorder.start();
    await _player.start(); // ✅ FIX: Start the player stream to hear audio
    _logger.i('mic and player started');
  }

  void _calculateVolume(Uint8List data) {
    if (data.isEmpty) return;

    // Convert PCM16 bytes to samples and calculate RMS
    double sum = 0;
    int sampleCount = data.length ~/ 2;
    ByteData byteData = ByteData.view(data.buffer);

    for (int i = 0; i < sampleCount; i++) {
      int sample = byteData.getInt16(i * 2, Endian.little);
      sum += sample * sample;
    }

    double rms = math.sqrt(sum / sampleCount);

    // Normalize to 0.0 - 1.0 (Approximate max for speech)
    // 32768 is max for Int16, but speech is usually lower
    double normalized = (rms / 32768.0).clamp(0.0, 1.0);
    _volumeController.add(normalized);
  }

  Future<void> stop() async {
    _logger.i('mn️ Stopping Audio...');
    await _recorder.stop();
    await _player.stop(); // ✅ FIX: Stop the player stream
    _audioSubscription?.cancel();
    _volumeController.add(0.0); // Reset volume
  }

  /// Play raw PCM chunk (Uint8List)
  Future<void> playChunk(Uint8List chunk) async {
    if (!_isInitialized) return;
    try {
      if (chunk.isNotEmpty) {
        await _player.writeChunk(chunk);
      }
    } catch (e) {
      _logger.w('⚠️ Error playing chunk: $e');
    }
  }

  void dispose() {
    stop();
    _recorder.dispose();
    _player.dispose();
    _volumeController.close();
  }
}
