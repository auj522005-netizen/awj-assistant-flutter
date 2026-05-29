import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:owj_assistant/config/api_keys.dart';
import 'package:owj_assistant/services/voice/elevenlabs_tts_service.dart';

/// Voice service combining STT (Speech-to-Text) and TTS (Text-to-Speech).
///
/// STT: Uses Groq Whisper for transcription.
/// TTS: 4-level fallback chain:
///   1. ElevenLabs → 2. OpenAI TTS → 3. BigModel GLM-4 Voice → 4. System TTS (flutter_tts)
class VoiceService {
  VoiceService({Dio? dio, ElevenLabsTtsService? elevenLabsService})
      : _dio = dio ?? Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 60),
        )),
        _elevenLabsService = elevenLabsService ?? ElevenLabsTtsService();

  final Dio _dio;
  final ElevenLabsTtsService _elevenLabsService;

  bool _isSpeaking = false;
  String? _currentProvider;

  /// Whether TTS is currently speaking.
  bool get isSpeaking => _isSpeaking;

  /// The currently active TTS provider name.
  String? get currentProvider => _currentProvider;

  // ── STT: Speech-to-Text ──

  /// Transcribes an audio file at [audioPath] using Groq Whisper.
  ///
  /// Supports WAV, MP3, M4A, and WebM formats.
  /// Returns the transcribed text with detected language.
  Future<TranscriptionResult> transcribeAudio(String audioPath) async {
    final file = File(audioPath);
    if (!await file.exists()) {
      throw VoiceException('Audio file not found: $audioPath');
    }

    if (!ApiKeys.hasGroq) {
      throw VoiceException('Groq API key not configured for STT');
    }

    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(audioPath),
        'model': 'whisper-large-v3',
        'language': 'ar', // Default to Arabic, Whisper auto-detects anyway
        'response_format': 'verbose_json',
      });

      final response = await _dio.post<Map<String, dynamic>>(
        'https://api.groq.com/openai/v1/audio/transcriptions',
        options: Options(headers: {
          'Authorization': 'Bearer ${ApiKeys.groqApiKey}',
        }),
        data: formData,
      );

      final data = response.data!;
      final text = data['text'] as String? ?? '';
      final language = data['language'] as String? ?? 'ar';
      final duration = (data['duration'] as num?)?.toDouble() ?? 0.0;

      // Parse segments if available
      final segments = <TranscriptSegment>[];
      final segmentList = data['segments'] as List<dynamic>? ?? [];
      for (final seg in segmentList) {
        final s = seg as Map<String, dynamic>;
        segments.add(TranscriptSegment(
          start: (s['start'] as num?)?.toDouble() ?? 0.0,
          end: (s['end'] as num?)?.toDouble() ?? 0.0,
          text: s['text'] as String? ?? '',
        ));
      }

      return TranscriptionResult(
        text: text,
        language: language,
        durationSeconds: duration,
        segments: segments,
        provider: 'Groq Whisper',
      );
    } on DioException catch (e) {
      throw VoiceException('Transcription failed: ${e.message}');
    }
  }

  // ── TTS: Text-to-Speech ──

  /// Speaks [text] using the specified [provider] or auto-selects
  /// the best available provider from the fallback chain.
  ///
  /// The fallback chain is:
  ///   1. ElevenLabs (highest quality)
  ///   2. OpenAI TTS
  ///   3. BigModel GLM-4 Voice
  ///   4. System TTS (flutter_tts)
  Future<TtsResult> speak(String text, {TtsProvider? provider}) async {
    if (_isSpeaking) {
      await stopSpeaking();
    }

    _isSpeaking = true;

    // Determine provider order
    final providers = provider != null
        ? [provider]
        : [TtsProvider.elevenLabs, TtsProvider.openAI, TtsProvider.bigModel, TtsProvider.system];

    for (final p in providers) {
      try {
        final result = await _speakWithProvider(text, p);
        _currentProvider = p.name;
        return result;
      } catch (_) {
        // Try next provider
        continue;
      }
    }

    _isSpeaking = false;
    throw VoiceException('All TTS providers failed');
  }

  /// Stops any currently playing speech.
  Future<void> stopSpeaking() async {
    _isSpeaking = false;
    _currentProvider = null;

    // Note: In a real implementation, this would also stop the audio player
    // and flutter_tts engine. This is a service-level abstraction.
  }

  // ── TTS provider implementations ──

  Future<TtsResult> _speakWithProvider(String text, TtsProvider provider) async {
    switch (provider) {
      case TtsProvider.elevenLabs:
        return _speakElevenLabs(text);
      case TtsProvider.openAI:
        return _speakOpenAI(text);
      case TtsProvider.bigModel:
        return _speakBigModel(text);
      case TtsProvider.system:
        return _speakSystem(text);
    }
  }

  Future<TtsResult> _speakElevenLabs(String text) async {
    if (!ApiKeys.hasElevenLabs) throw VoiceException('ElevenLabs not configured');

    final audioBytes = await _elevenLabsService.synthesize(text);
    // In real implementation: play audioBytes via audioplayers
    return TtsResult(
      provider: TtsProvider.elevenLabs,
      audioBytes: audioBytes,
      text: text,
      success: true,
    );
  }

  Future<TtsResult> _speakOpenAI(String text) async {
    if (!ApiKeys.hasOpenAI) throw VoiceException('OpenAI not configured');

    try {
      final response = await _dio.post<List<int>>(
        'https://api.openai.com/v1/audio/speech',
        options: Options(
          headers: {
            'Authorization': 'Bearer ${ApiKeys.openaiApiKey}',
            'Content-Type': 'application/json',
          },
          responseType: ResponseType.bytes,
        ),
        data: {
          'model': 'tts-1',
          'input': text,
          'voice': 'alloy',
          'response_format': 'mp3',
          'speed': 1.0,
        },
      );

      final audioBytes = Uint8List.fromList(response.data!);
      // In real implementation: play audioBytes via audioplayers

      return TtsResult(
        provider: TtsProvider.openAI,
        audioBytes: audioBytes,
        text: text,
        success: true,
      );
    } on DioException catch (e) {
      throw VoiceException('OpenAI TTS failed: ${e.message}');
    }
  }

  Future<TtsResult> _speakBigModel(String text) async {
    if (!ApiKeys.hasBigModel) throw VoiceException('BigModel not configured');

    try {
      final response = await _dio.post<List<int>>(
        'https://open.bigmodel.cn/api/paas/v4/audio/speech',
        options: Options(
          headers: {
            'Authorization': 'Bearer ${ApiKeys.bigModelApiKey}',
            'Content-Type': 'application/json',
          },
          responseType: ResponseType.bytes,
        ),
        data: {
          'model': 'glm-4-voice',
          'input': text,
          'voice': 'male-1',
          'response_format': 'mp3',
        },
      );

      final audioBytes = Uint8List.fromList(response.data!);
      // In real implementation: play audioBytes via audioplayers

      return TtsResult(
        provider: TtsProvider.bigModel,
        audioBytes: audioBytes,
        text: text,
        success: true,
      );
    } on DioException catch (e) {
      throw VoiceException('BigModel TTS failed: ${e.message}');
    }
  }

  Future<TtsResult> _speakSystem(String text) async {
    // System TTS using flutter_tts
    // In a real implementation, this would initialize FlutterTts and speak
    // For the service abstraction, we return a result indicating system TTS
    return TtsResult(
      provider: TtsProvider.system,
      audioBytes: null,
      text: text,
      success: true,
      note: 'System TTS (flutter_tts) should be invoked from the UI layer',
    );
  }
}

// ── Data models ──

enum TtsProvider { elevenLabs, openAI, bigModel, system }

class TranscriptionResult {
  final String text;
  final String language;
  final double durationSeconds;
  final List<TranscriptSegment> segments;
  final String provider;

  const TranscriptionResult({
    required this.text,
    required this.language,
    required this.durationSeconds,
    required this.segments,
    required this.provider,
  });
}

class TranscriptSegment {
  final double start;
  final double end;
  final String text;

  const TranscriptSegment({
    required this.start,
    required this.end,
    required this.text,
  });
}

class TtsResult {
  final TtsProvider provider;
  final Uint8List? audioBytes;
  final String text;
  final bool success;
  final String? note;

  const TtsResult({
    required this.provider,
    required this.audioBytes,
    required this.text,
    required this.success,
    this.note,
  });
}

class VoiceException implements Exception {
  final String message;
  VoiceException(this.message);
  @override
  String toString() => 'VoiceException: $message';
}
