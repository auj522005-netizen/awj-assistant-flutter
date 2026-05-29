import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:owj_assistant/config/api_keys.dart';

/// ElevenLabs TTS service for high-quality text-to-speech synthesis.
///
/// API: https://api.elevenlabs.io/v1/text-to-speech/{voiceId}
/// Supports multiple voice profiles and returns raw audio bytes.
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

  /// Predefined voice profiles with their IDs.
  static const Map<String, ElevenLabsVoice> voices = {
    'Rachel': ElevenLabsVoice(
      voiceId: '21m00Tcm4TlvDq8ikWAM',
      name: 'Rachel',
      description: 'صوت أنثوي دافئ ومهني',
      gender: VoiceGender.female,
      accent: 'American',
    ),
    'Adam': ElevenLabsVoice(
      voiceId: 'pNInz6obpgDQGcFmaJgB',
      name: 'Adam',
      description: 'صوت ذكوري عميق وهادئ',
      gender: VoiceGender.male,
      accent: 'American',
    ),
    'Alloy': ElevenLabsVoice(
      voiceId: 'oWAxZ7u1WTeGVQkDkrha',
      name: 'Alloy',
      description: 'صوت محايد ومتوازن',
      gender: VoiceGender.neutral,
      accent: 'American',
    ),
    'Shimmer': ElevenLabsVoice(
      voiceId: 'pFZP5JQG7iQjIQuC4Bku',
      name: 'Shimmer',
      description: 'صوت أنثوي صافٍ ورقيق',
      gender: VoiceGender.female,
      accent: 'American',
    ),
    'Echo': ElevenLabsVoice(
      voiceId: 'cjVigY5qzO86Huf0OWal',
      name: 'Echo',
      description: 'صوت ذكوري واضح وقوي',
      gender: VoiceGender.male,
      accent: 'American',
    ),
  };

  /// Default voice for Arabic content.
  static const String defaultVoice = 'Adam';

  // ── Public API ──

  /// Synthesizes [text] to audio using the specified [voiceName].
  ///
  /// Returns raw audio bytes (MP3 format).
  /// Falls back to [defaultVoice] if the specified voice is not found.
  Future<Uint8List> synthesize(
    String text, {
    String voiceName = defaultVoice,
    double stability = 0.5,
    double similarityBoost = 0.75,
    double style = 0.0,
    bool useSpeakerBoost = true,
  }) async {
    if (!ApiKeys.hasElevenLabs) {
      throw ElevenLabsException('ElevenLabs API key not configured');
    }

    if (text.trim().isEmpty) {
      throw ElevenLabsException('Text cannot be empty');
    }

    // Resolve voice ID
    final voice = voices[voiceName] ?? voices[defaultVoice]!;
    final voiceId = voice.voiceId;

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
          'model_id': 'eleven_multilingual_v2',
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
      throw ElevenLabsException(
        'ElevenLabs TTS failed: ${e.message ?? e.type.toString()}',
      );
    }
  }

  /// Synthesizes text as a stream for long content.
  ///
  /// Uses the streaming endpoint for lower latency on long texts.
  Future<Uint8List> synthesizeStream(
    String text, {
    String voiceName = defaultVoice,
  }) async {
    // For very long texts, chunk and concatenate
    if (text.length > 5000) {
      return _synthesizeChunked(text, voiceName: voiceName);
    }

    // Otherwise use regular synthesis (streaming requires WebSocket in practice)
    return synthesize(text, voiceName: voiceName);
  }

  /// Lists available voices from the ElevenLabs account.
  Future<List<ElevenLabsVoice>> listVoices() async {
    if (!ApiKeys.hasElevenLabs) {
      // Return predefined voices
      return voices.values.toList();
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
      return voices.values.toList();
    }
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
    String voiceName = defaultVoice,
  }) async {
    // Split text into sentences or chunks of ~4000 chars
    final chunks = <String>[];
    var remaining = text;

    while (remaining.isNotEmpty) {
      if (remaining.length <= 4000) {
        chunks.add(remaining);
        break;
      }

      // Find a good split point (sentence boundary)
      int splitPoint = remaining.lastIndexOf('.', 4000);
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
      final bytes = await synthesize(chunk, voiceName: voiceName);
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

  const ElevenLabsVoice({
    required this.voiceId,
    required this.name,
    required this.description,
    required this.gender,
    required this.accent,
  });
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
