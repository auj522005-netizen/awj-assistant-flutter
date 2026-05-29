import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:owj_assistant/config/api_keys.dart';
import 'package:owj_assistant/services/voice/elevenlabs_tts_service.dart';

/// Voice service combining STT (Speech-to-Text) and TTS (Text-to-Speech).
///
/// STT: Uses Groq Whisper for transcription.
/// TTS: 5-level fallback chain:
///   1. Groq Orpheus Arabic → 2. ElevenLabs → 3. OpenAI TTS → 4. BigModel GLM-4 Voice → 5. System TTS (flutter_tts)
///
/// Supports language-aware voice selection and Arabic-optimized profiles.
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
  String _currentLanguage = 'ar'; // Default to Arabic
  TtsProvider _preferredProvider = TtsProvider.groqOrpheus;

  /// Whether TTS is currently speaking.
  bool get isSpeaking => _isSpeaking;

  /// The currently active TTS provider name.
  String? get currentProvider => _currentProvider;

  /// The currently active language code.
  String get currentLanguage => _currentLanguage;

  /// The preferred TTS provider (used as first choice in fallback chain).
  TtsProvider get preferredProvider => _preferredProvider;

  /// The underlying ElevenLabs service instance for direct access.
  ElevenLabsTtsService get elevenLabsService => _elevenLabsService;

  // ── Provider switching ──

  /// Switches the preferred TTS provider.
  ///
  /// This changes the first provider tried in the fallback chain.
  /// Use this to switch between ElevenLabs (high quality) and
  /// flutter_tts (offline/system fallback) as the primary provider.
  void setPreferredProvider(TtsProvider provider) {
    _preferredProvider = provider;
  }

  /// Switches to ElevenLabs as the TTS provider (online, high quality).
  void switchToElevenLabs() {
    _preferredProvider = TtsProvider.elevenLabs;
  }

  /// Switches to system TTS (flutter_tts) as the provider (offline fallback).
  void switchToSystemTts() {
    _preferredProvider = TtsProvider.system;
  }

  /// Sets the language for voice synthesis.
  void setLanguage(String languageCode) {
    _currentLanguage = languageCode;
  }

  /// Sets the Arabic voice profile for ElevenLabs synthesis.
  void setArabicVoiceProfile(ArabicVoiceProfile profile) {
    _elevenLabsService.setArabicVoiceProfile(profile);
  }

  /// Gets the current Arabic voice profile.
  ArabicVoiceProfile get arabicVoiceProfile => _elevenLabsService.arabicVoiceProfile;

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
        'model': 'whisper-large-v3-turbo',
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
  /// The fallback chain starts with the [preferredProvider] and falls
  /// through other providers in order:
  ///   1. Preferred provider (default: ElevenLabs)
  ///   2. ElevenLabs (highest quality)
  ///   3. OpenAI TTS
  ///   4. BigModel GLM-4 Voice
  ///   5. System TTS (flutter_tts)
  ///
  /// If [languageCode] is provided, it is used to select the best voice
  /// for that language. Otherwise, [_currentLanguage] is used.
  Future<TtsResult> speak(String text, {TtsProvider? provider, String? languageCode}) async {
    if (_isSpeaking) {
      await stopSpeaking();
    }

    _isSpeaking = true;
    final lang = languageCode ?? _currentLanguage;

    // Determine provider order — start with preferred, then fall through
    final providers = _buildProviderOrder(provider);

    for (final p in providers) {
      try {
        final result = await _speakWithProvider(text, p, languageCode: lang);
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

  /// Speaks [text] using Arabic-optimized voice settings via ElevenLabs.
  ///
  /// Convenience method that automatically selects the current Arabic voice
  /// profile and optimized settings for Arabic pronunciation.
  Future<TtsResult> speakArabic(
    String text, {
    ArabicVoiceProfile? voiceProfile,
    ArabicVoiceSettings? settings,
  }) async {
    if (_isSpeaking) {
      await stopSpeaking();
    }

    _isSpeaking = true;

    try {
      final audioBytes = await _elevenLabsService.synthesizeArabic(
        text,
        voiceProfile: voiceProfile,
        settings: settings,
      );

      _currentProvider = TtsProvider.elevenLabs.name;
      return TtsResult(
        provider: TtsProvider.elevenLabs,
        audioBytes: audioBytes,
        text: text,
        success: true,
        languageCode: 'ar',
        voiceName: (voiceProfile ?? _elevenLabsService.arabicVoiceProfile).defaultVoiceName,
      );
    } on ElevenLabsException catch (_) {
      // Fall back to general speak method
      return speak(text, languageCode: 'ar');
    }
  }

  /// Stops any currently playing speech.
  Future<void> stopSpeaking() async {
    _isSpeaking = false;
    _currentProvider = null;

    // Note: In a real implementation, this would also stop the audio player
    // and flutter_tts engine. This is a service-level abstraction.
  }

  // ── Private helpers ──

  /// Builds the provider fallback order, starting with the preferred provider.
  List<TtsProvider> _buildProviderOrder(TtsProvider? explicitProvider) {
    if (explicitProvider != null) {
      return [explicitProvider];
    }

    // Start with preferred, then add others in fallback order
    final order = <TtsProvider>[_preferredProvider];
    for (final p in TtsProvider.values) {
      if (!order.contains(p)) {
        order.add(p);
      }
    }
    return order;
  }

  // ── TTS provider implementations ──

  Future<TtsResult> _speakWithProvider(String text, TtsProvider provider, {String? languageCode}) async {
    switch (provider) {
      case TtsProvider.groqOrpheus:
        return _speakGroqOrpheus(text, languageCode: languageCode);
      case TtsProvider.elevenLabs:
        return _speakElevenLabs(text, languageCode: languageCode);
      case TtsProvider.openAI:
        return _speakOpenAI(text);
      case TtsProvider.bigModel:
        return _speakBigModel(text);
      case TtsProvider.system:
        return _speakSystem(text);
    }
  }

  /// Speak using Groq Orpheus Arabic Saudi TTS.
  /// This is the highest-quality Arabic TTS available, natively trained
  /// on Arabic Saudi dialect — perfect for Egyptian Arabic assistant.
  Future<TtsResult> _speakGroqOrpheus(String text, {String? languageCode}) async {
    if (!ApiKeys.hasGroq) throw VoiceException('Groq API key not configured for Orpheus TTS');

    final lang = languageCode ?? _currentLanguage;
    final bool isArabic = lang.toLowerCase().startsWith('ar');

    // Use Arabic Saudi model for Arabic, English model for English
    final model = isArabic
        ? 'canopylabs/orpheus-arabic-saudi'
        : 'canopylabs/orpheus-v1-english';

    try {
      final response = await _dio.post<List<int>>(
        'https://api.groq.com/openai/v1/audio/speech',
        options: Options(
          headers: {
            'Authorization': 'Bearer ${ApiKeys.groqApiKey}',
            'Content-Type': 'application/json',
          },
          responseType: ResponseType.bytes,
        ),
        data: {
          'model': model,
          'input': text,
          'voice': isArabic ? 'arabic_saudi' : 'alex',
          'response_format': 'wav',
        },
      );

      final audioBytes = Uint8List.fromList(response.data!);
      // In real implementation: play audioBytes via audioplayers

      return TtsResult(
        provider: TtsProvider.groqOrpheus,
        audioBytes: audioBytes,
        text: text,
        success: true,
        languageCode: lang,
        voiceName: isArabic ? 'Orpheus Arabic Saudi' : 'Orpheus English',
      );
    } on DioException catch (e) {
      throw VoiceException('Groq Orpheus TTS failed: ${e.message}');
    }
  }

  Future<TtsResult> _speakElevenLabs(String text, {String? languageCode}) async {
    if (!ApiKeys.hasElevenLabs) throw VoiceException('ElevenLabs not configured');

    final lang = languageCode ?? _currentLanguage;

    // Use the best voice for the language
    final voiceName = _elevenLabsService.getBestVoiceForLanguage(lang);

    // Use Arabic-optimized settings for Arabic content
    final bool isArabic = lang.toLowerCase().startsWith('ar');

    final audioBytes = isArabic
        ? await _elevenLabsService.synthesizeArabic(text)
        : await _elevenLabsService.synthesize(
            text,
            voiceName: voiceName,
            languageCode: lang,
          );

    return TtsResult(
      provider: TtsProvider.elevenLabs,
      audioBytes: audioBytes,
      text: text,
      success: true,
      languageCode: lang,
      voiceName: voiceName,
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

enum TtsProvider { groqOrpheus, elevenLabs, openAI, bigModel, system }

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

  /// The language code used for synthesis (e.g., 'ar', 'en').
  final String? languageCode;

  /// The voice name used for synthesis (e.g., 'Antoni', 'Rachel').
  final String? voiceName;

  const TtsResult({
    required this.provider,
    required this.audioBytes,
    required this.text,
    required this.success,
    this.note,
    this.languageCode,
    this.voiceName,
  });
}

class VoiceException implements Exception {
  final String message;
  VoiceException(this.message);
  @override
  String toString() => 'VoiceException: $message';
}
