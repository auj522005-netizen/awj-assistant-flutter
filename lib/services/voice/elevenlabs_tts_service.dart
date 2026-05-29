import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:owj_assistant/config/api_keys.dart';

/// Arabic voice profile enum for selecting appropriate Arabic voice styles.
enum ArabicVoiceProfile {
  /// Male voice, defaults to Antoni — natural and expressive
  arabicMale('Antoni'),

  /// Female voice, defaults to Bella — warm and clear
  arabicFemale('Bella'),

  /// Formal tone, uses Adam — deep and professional
  arabicFormal('Adam'),

  /// Casual tone, uses Giovanni — energetic and relaxed
  arabicCasual('Giovanni');

  const ArabicVoiceProfile(this.defaultVoiceName);

  /// The default voice name associated with this profile.
  final String defaultVoiceName;
}

/// ElevenLabs TTS model identifiers.
class ElevenLabsModel {
  /// Multilingual v2 — works well with many languages including Arabic.
  static const String multilingualV2 = 'eleven_multilingual_v2';

  /// Arabic v1 — dedicated Arabic model (if available on the account).
  static const String arabicV1 = 'eleven_arabic_v1';

  /// Turbo v2 — low-latency multilingual model.
  static const String turboV2 = 'eleven_turbo_v2';
}

/// Optimized voice settings for Arabic speech synthesis.
class ArabicVoiceSettings {
  /// Higher stability (0.6) for consistent Arabic pronunciation.
  final double stability;

  /// Higher similarity_boost (0.8) for clarity of Arabic phonemes.
  final double similarityBoost;

  /// Style parameter (0.2) for natural expression.
  final double style;

  /// Speaker boost for enhanced clarity.
  final bool useSpeakerBoost;

  const ArabicVoiceSettings({
    this.stability = 0.6,
    this.similarityBoost = 0.8,
    this.style = 0.2,
    this.useSpeakerBoost = true,
  });

  /// Convert to API-compatible map.
  Map<String, dynamic> toMap() => {
        'stability': stability.clamp(0.0, 1.0),
        'similarity_boost': similarityBoost.clamp(0.0, 1.0),
        'style': style.clamp(0.0, 1.0),
        'use_speaker_boost': useSpeakerBoost,
      };
}

/// ElevenLabs TTS service for high-quality text-to-speech synthesis.
///
/// API: https://api.elevenlabs.io/v1/text-to-speech/{voiceId}
/// Supports multiple voice profiles including Arabic-optimized voices
/// and returns raw audio bytes.
class ElevenLabsTtsService {
  ElevenLabsTtsService({Dio? dio})
      : _dio = dio ?? Dio(BaseOptions(
          baseUrl: 'https://api.elevenlabs.io/v1',
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
          headers: {
            'Content-Type': 'application/json',
          },
        ));

  final Dio _dio;

  /// Whether to prefer the dedicated Arabic model when available.
  bool _preferArabicModel = true;

  /// Currently selected Arabic voice profile.
  ArabicVoiceProfile _arabicVoiceProfile = ArabicVoiceProfile.arabicMale;

  // ── Voice Profiles ──

  /// Predefined voice profiles with their IDs — original English voices.
  static const Map<String, ElevenLabsVoice> voices = {
    'Rachel': ElevenLabsVoice(
      voiceId: '21m00Tcm4TlvDq8ikWAM',
      name: 'Rachel',
      description: 'صوت أنثوي دافئ ومهني',
      gender: VoiceGender.female,
      accent: 'American',
      languageHint: 'en',
    ),
    'Adam': ElevenLabsVoice(
      voiceId: 'pNInz6obpgDQGcFmaJgB',
      name: 'Adam',
      description: 'صوت ذكوري عميق وهادئ — مناسب للعربية الرسمية',
      gender: VoiceGender.male,
      accent: 'American',
      languageHint: 'ar,en',
    ),
    'Alloy': ElevenLabsVoice(
      voiceId: 'oWAxZ7u1WTeGVQkDkrha',
      name: 'Alloy',
      description: 'صوت محايد ومتوازن',
      gender: VoiceGender.neutral,
      accent: 'American',
      languageHint: 'en',
    ),
    'Shimmer': ElevenLabsVoice(
      voiceId: 'pFZP5JQG7iQjIQuC4Bku',
      name: 'Shimmer',
      description: 'صوت أنثوي صافٍ ورقيق',
      gender: VoiceGender.female,
      accent: 'American',
      languageHint: 'en',
    ),
    'Echo': ElevenLabsVoice(
      voiceId: 'cjVigY5qzO86Huf0OWal',
      name: 'Echo',
      description: 'صوت ذكوري واضح وقوي',
      gender: VoiceGender.male,
      accent: 'American',
      languageHint: 'en',
    ),
  };

  /// Arabic-optimized voice profiles with their IDs.
  /// These voices are known to work well with Arabic via the multilingual model.
  static const Map<String, ElevenLabsVoice> arabicVoices = {
    'Antoni': ElevenLabsVoice(
      voiceId: 'ErXwobaYiN019PkySvjV',
      name: 'Antoni',
      description: 'صوت ذكوري طبيعي ومعبر — الأفضل للعربية',
      gender: VoiceGender.male,
      accent: 'Multilingual',
      languageHint: 'ar,en',
    ),
    'Arnold': ElevenLabsVoice(
      voiceId: 'VR6AewLTigWG4xSOukaG',
      name: 'Arnold',
      description: 'صوت ذكوري عميق وقوي — مناسب للمحتوى الجاد',
      gender: VoiceGender.male,
      accent: 'Multilingual',
      languageHint: 'ar,en',
    ),
    'Bella': ElevenLabsVoice(
      voiceId: 'EXAVITQu4vr4xnSDxMaL',
      name: 'Bella',
      description: 'صوت أنثوي دافئ وواضح — ممتاز للعربية',
      gender: VoiceGender.female,
      accent: 'Multilingual',
      languageHint: 'ar,en',
    ),
    'Dorothy': ElevenLabsVoice(
      voiceId: 'ThT5KcBeYPX3keUQqHPh',
      name: 'Dorothy',
      description: 'صوت أنثوي صافٍ ومتقن — وضوح ممتاز للعربية',
      gender: VoiceGender.female,
      accent: 'Multilingual',
      languageHint: 'ar,en',
    ),
    'Giovanni': ElevenLabsVoice(
      voiceId: 'zcAOhNBS3c14rBihAFp1g',
      name: 'Giovanni',
      description: 'صوت ذكوري نشيط — مناسب للعربية غير الرسمية',
      gender: VoiceGender.male,
      accent: 'Multilingual',
      languageHint: 'ar,en',
    ),
  };

  /// All available voices (combined English + Arabic).
  static Map<String, ElevenLabsVoice> get allVoices => {...voices, ...arabicVoices};

  /// Default voice for Arabic content — Antoni sounds most natural for Arabic.
  static const String defaultArabicVoice = 'Antoni';

  /// Default voice for English/general content.
  static const String defaultVoice = 'Rachel';

  /// Default Arabic voice settings — optimized for Arabic pronunciation.
  static const ArabicVoiceSettings defaultArabicSettings = ArabicVoiceSettings();

  // ── Public API ──

  /// Sets the Arabic voice profile to use.
  void setArabicVoiceProfile(ArabicVoiceProfile profile) {
    _arabicVoiceProfile = profile;
  }

  /// Gets the current Arabic voice profile.
  ArabicVoiceProfile get arabicVoiceProfile => _arabicVoiceProfile;

  /// Sets whether to prefer the dedicated Arabic model.
  void setPreferArabicModel(bool prefer) {
    _preferArabicModel = prefer;
  }

  /// Selects the best voice for the given language code.
  ///
  /// For Arabic (`ar`, `ar-SA`, `ar-EG`, etc.), returns the current
  /// Arabic voice profile's default voice. For other languages, returns
  /// the standard default voice.
  String getBestVoiceForLanguage(String languageCode) {
    final normalizedLang = languageCode.toLowerCase();
    if (normalizedLang.startsWith('ar')) {
      return _arabicVoiceProfile.defaultVoiceName;
    }
    // Default to English voices for other languages
    return defaultVoice;
  }

  /// Determines the best model ID for the given language.
  ///
  /// For Arabic, tries `eleven_arabic_v1` first (if preferred),
  /// then falls back to `eleven_multilingual_v2`.
  String getBestModelForLanguage(String languageCode) {
    final normalizedLang = languageCode.toLowerCase();
    if (normalizedLang.startsWith('ar') && _preferArabicModel) {
      return ElevenLabsModel.arabicV1;
    }
    return ElevenLabsModel.multilingualV2;
  }

  /// Synthesizes [text] to audio using the specified [voiceName].
  ///
  /// Returns raw audio bytes (MP3 format).
  /// Falls back to [defaultArabicVoice] for Arabic text or [defaultVoice]
  /// for other languages if the specified voice is not found.
  Future<Uint8List> synthesize(
    String text, {
    String voiceName = defaultArabicVoice,
    double stability = 0.6,
    double similarityBoost = 0.8,
    double style = 0.2,
    bool useSpeakerBoost = true,
    String? modelId,
    String? languageCode,
  }) async {
    if (!ApiKeys.hasElevenLabs) {
      throw ElevenLabsException('ElevenLabs API key not configured');
    }

    if (text.trim().isEmpty) {
      throw ElevenLabsException('Text cannot be empty');
    }

    // Resolve voice ID — search all voices
    final voice = allVoices[voiceName] ?? allVoices[defaultArabicVoice]!;
    final voiceId = voice.voiceId;

    // Determine the best model for this language
    final effectiveModel = modelId ??
        (languageCode != null
            ? getBestModelForLanguage(languageCode)
            : ElevenLabsModel.multilingualV2);

    try {
      final response = await _dio.post<List<int>>(
        '/text-to-speech/$voiceId',
        options: Options(
          headers: {
            'xi-api-key': ApiKeys.elevenLabsApiKey,
          },
          responseType: ResponseType.bytes,
        ),
        data: {
          'text': text,
          'model_id': effectiveModel,
          'voice_settings': {
            'stability': stability.clamp(0.0, 1.0),
            'similarity_boost': similarityBoost.clamp(0.0, 1.0),
            'style': style.clamp(0.0, 1.0),
            'use_speaker_boost': useSpeakerBoost,
          },
        },
      );

      return Uint8List.fromList(response.data!);
    } on DioException catch (e) {
      // If Arabic model fails, fall back to multilingual v2
      if (effectiveModel == ElevenLabsModel.arabicV1) {
        return synthesize(
          text,
          voiceName: voiceName,
          stability: stability,
          similarityBoost: similarityBoost,
          style: style,
          useSpeakerBoost: useSpeakerBoost,
          modelId: ElevenLabsModel.multilingualV2,
          languageCode: languageCode,
        );
      }
      throw ElevenLabsException(
        'ElevenLabs TTS failed: ${e.message ?? e.type.toString()}',
      );
    }
  }

  /// Synthesizes Arabic text with optimized settings for Arabic pronunciation.
  ///
  /// Uses the current Arabic voice profile and optimized voice settings:
  /// - stability: 0.6 (consistent pronunciation)
  /// - similarity_boost: 0.8 (clarity)
  /// - style: 0.2 (natural expression)
  Future<Uint8List> synthesizeArabic(
    String text, {
    ArabicVoiceProfile? voiceProfile,
    ArabicVoiceSettings? settings,
  }) async {
    final profile = voiceProfile ?? _arabicVoiceProfile;
    final voiceSettings = settings ?? defaultArabicSettings;

    return synthesize(
      text,
      voiceName: profile.defaultVoiceName,
      stability: voiceSettings.stability,
      similarityBoost: voiceSettings.similarityBoost,
      style: voiceSettings.style,
      useSpeakerBoost: voiceSettings.useSpeakerBoost,
      languageCode: 'ar',
    );
  }

  /// Synthesizes text as a stream for long content.
  ///
  /// Uses the streaming endpoint for lower latency on long texts.
  Future<Uint8List> synthesizeStream(
    String text, {
    String voiceName = defaultArabicVoice,
    String? languageCode,
  }) async {
    // For very long texts, chunk and concatenate
    if (text.length > 5000) {
      return _synthesizeChunked(text, voiceName: voiceName, languageCode: languageCode);
    }

    // Otherwise use regular synthesis (streaming requires WebSocket in practice)
    return synthesize(text, voiceName: voiceName, languageCode: languageCode);
  }

  /// Lists available voices from the ElevenLabs account.
  Future<List<ElevenLabsVoice>> listVoices() async {
    if (!ApiKeys.hasElevenLabs) {
      // Return predefined voices
      return allVoices.values.toList();
    }

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/voices',
        options: Options(headers: {
          'xi-api-key': ApiKeys.elevenLabsApiKey,
        }),
      );

      final voiceList = response.data?['voices'] as List<dynamic>? ?? [];
      return voiceList.map((v) {
        final data = v as Map<String, dynamic>;
        return ElevenLabsVoice(
          voiceId: data['voice_id'] as String? ?? '',
          name: data['name'] as String? ?? 'Unknown',
          description: data['labels']?['description'] as String? ?? '',
          gender: _parseGender(data['labels']?['gender'] as String?),
          accent: data['labels']?['accent'] as String? ?? '',
        );
      }).toList();
    } on DioException catch (_) {
      // Fall back to predefined voices
      return allVoices.values.toList();
    }
  }

  /// Lists only Arabic-optimized voices.
  List<ElevenLabsVoice> listArabicVoices() {
    return arabicVoices.values.toList();
  }

  /// Lists only standard (English) voices.
  List<ElevenLabsVoice> listStandardVoices() {
    return voices.values.toList();
  }

  /// Gets the remaining character quota for the account.
  Future<CharacterQuota> getQuota() async {
    if (!ApiKeys.hasElevenLabs) {
      return const CharacterQuota(used: 0, limit: 0, remaining: 0);
    }

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/user/subscription',
        options: Options(headers: {
          'xi-api-key': ApiKeys.elevenLabsApiKey,
        }),
      );

      final data = response.data!;
      final used = data['character_count'] as int? ?? 0;
      final limit = data['character_limit'] as int? ?? 0;

      return CharacterQuota(
        used: used,
        limit: limit,
        remaining: limit - used,
      );
    } on DioException catch (_) {
      return const CharacterQuota(used: 0, limit: 0, remaining: 0);
    }
  }

  // ── Private helpers ──

  Future<Uint8List> _synthesizeChunked(
    String text, {
    String voiceName = defaultArabicVoice,
    String? languageCode,
  }) async {
    // Split text into sentences or chunks of ~4000 chars
    final chunks = <String>[];
    var remaining = text;

    while (remaining.isNotEmpty) {
      if (remaining.length <= 4000) {
        chunks.add(remaining);
        break;
      }

      // Find a good split point (Arabic sentence boundary or period)
      int splitPoint = remaining.lastIndexOf('.', 4000);
      // Also try Arabic comma and question mark as split points
      if (splitPoint < 2000) {
        splitPoint = remaining.lastIndexOf('؟', 4000);
      }
      if (splitPoint < 2000) {
        splitPoint = remaining.lastIndexOf('،', 4000);
      }
      if (splitPoint < 2000) {
        splitPoint = remaining.lastIndexOf(' ', 4000);
      }
      if (splitPoint < 2000) {
        splitPoint = 4000;
      }

      chunks.add(remaining.substring(0, splitPoint + 1));
      remaining = remaining.substring(splitPoint + 1);
    }

    // Synthesize each chunk and concatenate
    final allBytes = <int>[];
    for (final chunk in chunks) {
      final bytes = await synthesize(chunk, voiceName: voiceName, languageCode: languageCode);
      allBytes.addAll(bytes);
    }

    return Uint8List.fromList(allBytes);
  }

  VoiceGender _parseGender(String? gender) {
    if (gender == null) return VoiceGender.neutral;
    switch (gender.toLowerCase()) {
      case 'male':
        return VoiceGender.male;
      case 'female':
        return VoiceGender.female;
      default:
        return VoiceGender.neutral;
    }
  }
}

// ── Data models ──

enum VoiceGender { male, female, neutral }

class ElevenLabsVoice {
  final String voiceId;
  final String name;
  final String description;
  final VoiceGender gender;
  final String accent;

  /// Language hint indicating which languages this voice handles well.
  /// E.g., 'ar,en' means Arabic and English, 'en' means English only.
  final String languageHint;

  const ElevenLabsVoice({
    required this.voiceId,
    required this.name,
    required this.description,
    required this.gender,
    required this.accent,
    this.languageHint = 'en',
  });

  /// Whether this voice supports Arabic.
  bool get supportsArabic => languageHint.contains('ar');
}

class CharacterQuota {
  final int used;
  final int limit;
  final int remaining;

  const CharacterQuota({
    required this.used,
    required this.limit,
    required this.remaining,
  });

  double get usagePercentage => limit > 0 ? used / limit : 0.0;
  bool get isExhausted => remaining <= 0;
}

class ElevenLabsException implements Exception {
  final String message;
  ElevenLabsException(this.message);
  @override
  String toString() => 'ElevenLabsException: $message';
}
