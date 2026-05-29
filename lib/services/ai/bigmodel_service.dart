import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:owj_assistant/config/api_keys.dart';
import 'package:owj_assistant/config/app_config.dart';
import 'package:owj_assistant/models/ai_model.dart';

/// BigModel / ZhipuAI API service for the OWJ Assistant.
///
/// Supports chat models: glm-5.1, glm-5-turbo, glm-5, glm-4.7,
/// glm-4.6, glm-4.5, glm-4.5-air.
/// Also supports TTS for Arabic content.
class BigModelService {
  BigModelService({Dio? dio})
      : _dio = dio ?? Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 120),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${ApiKeys.bigmodelApiKey}',
          },
        ));

  final Dio _dio;

  static const String _chatBaseUrl =
      'https://open.bigmodel.cn/api/paas/v4/chat/completions';
  static const String _ttsBaseUrl =
      'https://open.bigmodel.cn/api/paas/v4/audio/speech';

  /// Supported BigModel chat models (from app_config registry).
  static List<AIModel> get supportedModels =>
      getModelsByProvider(AIProvider.bigmodel);

  /// Confirmed available BigModel chat model IDs.
  static const String modelGlm51 = 'glm-5.1';
  static const String modelGlm5Turbo = 'glm-5-turbo';
  static const String modelGlm5 = 'glm-5';
  static const String modelGlm47 = 'glm-4.7';
  static const String modelGlm46 = 'glm-4.6';
  static const String modelGlm45 = 'glm-4.5';
  static const String modelGlm45Air = 'glm-4.5-air';

  /// All confirmed available model IDs.
  static const List<String> availableModels = [
    modelGlm51,
    modelGlm5Turbo,
    modelGlm5,
    modelGlm47,
    modelGlm46,
    modelGlm45,
    modelGlm45Air,
  ];

  /// Default model for general use.
  static const String defaultModel = 'glm-5-turbo';

  /// Default TTS voice.
  static const String defaultVoice = 'male-qn-qingse';

  /// Supported TTS voices for BigModel.
  static const List<String> supportedVoices = [
    'male-qn-qingse',
    'male-qn-jingying',
    'female-shaonv',
    'female-yujie',
    'female-chengshu',
    'presenter_male',
    'presenter_female',
  ];

  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  /// Update the authorization header with the current API key.
  void _updateAuthHeader() {
    _dio.options.headers['Authorization'] =
        'Bearer ${ApiKeys.bigmodelApiKey}';
  }

  /// Send a non-streaming chat completion request.
  Future<AIResponse> chat({
    required List<ApiChatMessage> messages,
    String model = defaultModel,
    double temperature = 0.7,
    int maxTokens = 4096,
  }) async {
    _updateAuthHeader();
    final stopwatch = Stopwatch()..start();
    Exception? lastException;

    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final response = await _dio.post<Map<String, dynamic>>(
          _chatBaseUrl,
          data: jsonEncode({
            'model': model,
            'messages': messages.map((m) => m.toMap()).toList(),
            'temperature': temperature,
            'max_tokens': maxTokens,
          }),
        );

        stopwatch.stop();
        final data = response.data!;
        final choices = data['choices'] as List<dynamic>;
        if (choices.isEmpty) {
          throw Exception('No choices returned from BigModel');
        }

        final message = (choices[0] as Map<String, dynamic>)['message']
            as Map<String, dynamic>;
        final content = message['content'] as String? ?? '';
        final usage = data['usage'] as Map<String, dynamic>?;

        return AIResponse(
          content: content,
          model: model,
          provider: 'bigmodel',
          promptTokens: (usage?['prompt_tokens'] as int?) ?? 0,
          completionTokens: (usage?['completion_tokens'] as int?) ?? 0,
          latency: stopwatch.elapsed,
        );
      } on DioException catch (e) {
        lastException = e;
        if (!_shouldRetry(e)) rethrow;
        await _waitForRetry(attempt);
      } catch (e) {
        lastException = Exception(e.toString());
        rethrow;
      }
    }

    throw lastException ?? Exception('Max retries exceeded for BigModel');
  }

  /// Send a streaming chat completion request via SSE.
  Stream<StreamChunk> chatStream({
    required List<ApiChatMessage> messages,
    String model = defaultModel,
    double temperature = 0.7,
    int maxTokens = 4096,
  }) async* {
    _updateAuthHeader();

    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final response = await _dio.post<ResponseBody>(
          _chatBaseUrl,
          data: jsonEncode({
            'model': model,
            'messages': messages.map((m) => m.toMap()).toList(),
            'temperature': temperature,
            'max_tokens': maxTokens,
            'stream': true,
          }),
          options: Options(
            responseType: ResponseType.stream,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${ApiKeys.bigmodelApiKey}',
            },
          ),
        );

        final stream = response.data!.stream;
        String buffer = '';

        await for (final chunk in stream) {
          buffer += utf8.decode(chunk, allowMalformed: true);
          final lines = buffer.split('\n');
          buffer = lines.removeLast();

          for (final line in lines) {
            final trimmed = line.trim();
            if (trimmed.isEmpty) continue;

            if (trimmed.startsWith('data:')) {
              final jsonStr = trimmed.substring(5).trim();
              if (jsonStr == '[DONE]') {
                yield const StreamChunk(isDone: true, finishReason: 'stop');
                return;
              }

              try {
                final parsed =
                    jsonDecode(jsonStr) as Map<String, dynamic>;
                final choices = parsed['choices'] as List<dynamic>?;
                if (choices != null && choices.isNotEmpty) {
                  final delta = (choices[0] as Map<String, dynamic>)['delta']
                      as Map<String, dynamic>?;
                  final content = delta?['content'] as String?;
                  if (content != null) {
                    yield StreamChunk(text: content, model: model);
                  }

                  final finishReason =
                      (choices[0] as Map<String, dynamic>)['finish_reason']
                          as String?;
                  if (finishReason != null) {
                    yield StreamChunk(
                      isDone: true,
                      finishReason: finishReason,
                      model: model,
                    );
                    return;
                  }
                }
              } catch (_) {
                // Skip malformed JSON
              }
            }
          }
        }

        yield const StreamChunk(isDone: true, finishReason: 'stop');
        return;
      } on DioException catch (e) {
        if (!_shouldRetry(e) || attempt >= _maxRetries) rethrow;
        await _waitForRetry(attempt);
      }
    }
  }

  /// Generate speech audio using BigModel TTS.
  ///
  /// Returns the raw audio bytes (MP3 format).
  Future<Uint8List> textToSpeech({
    required String text,
    String voice = defaultVoice,
    String model = 'tts-1',
    double speed = 1.0,
  }) async {
    _updateAuthHeader();

    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final response = await _dio.post<List<int>>(
          _ttsBaseUrl,
          data: jsonEncode({
            'model': model,
            'input': text,
            'voice': voice,
            'speed': speed,
            'response_format': 'mp3',
          }),
          options: Options(
            responseType: ResponseType.bytes,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${ApiKeys.bigmodelApiKey}',
            },
          ),
        );

        return Uint8List.fromList(response.data!);
      } on DioException catch (e) {
        if (!_shouldRetry(e) || attempt >= _maxRetries) {
          throw _mapDioError(e);
        }
        await _waitForRetry(attempt);
      }
    }

    throw Exception('Max retries exceeded for BigModel TTS');
  }

  /// Stream speech audio using BigModel TTS.
  Stream<Uint8List> textToSpeechStream({
    required String text,
    String voice = defaultVoice,
    String model = 'tts-1',
    double speed = 1.0,
  }) async* {
    _updateAuthHeader();

    try {
      final response = await _dio.post<ResponseBody>(
        _ttsBaseUrl,
        data: jsonEncode({
          'model': model,
          'input': text,
          'voice': voice,
          'speed': speed,
          'response_format': 'mp3',
          'stream': true,
        }),
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${ApiKeys.bigmodelApiKey}',
          },
        ),
      );

      await for (final chunk in response.data!.stream) {
        yield Uint8List.fromList(chunk);
      }
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  /// Test connection to the BigModel API.
  Future<ProviderStatus> testConnection() async {
    if (ApiKeys.bigmodelApiKey.isEmpty) {
      return const ProviderStatus(
        provider: 'bigmodel',
        isAvailable: false,
        errorMessage: 'API key not configured',
      );
    }

    final stopwatch = Stopwatch()..start();
    try {
      final response = await chat(
        messages: [
          const ApiChatMessage(
            role: 'user',
            content: 'مرحبا، قل مرحبا بكلمة واحدة',
          ),
        ],
        model: 'glm-5-turbo',
        maxTokens: 50,
      );
      stopwatch.stop();
      return ProviderStatus(
        provider: 'bigmodel',
        isAvailable: response.content.isNotEmpty,
        latency: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return ProviderStatus(
        provider: 'bigmodel',
        isAvailable: false,
        errorMessage: e.toString(),
        latency: stopwatch.elapsed,
      );
    }
  }

  /// Check if the error is retryable.
  bool _shouldRetry(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return true;
    }
    if (e.response?.statusCode == 429 || e.response?.statusCode == 500) {
      return true;
    }
    return false;
  }

  /// Wait before retry with exponential backoff.
  Future<void> _waitForRetry(int attempt) async {
    final delay = _retryDelay * (1 << attempt);
    await Future.delayed(delay);
  }

  /// Map DioException to a user-friendly error message.
  Exception _mapDioError(DioException e) {
    switch (e.response?.statusCode) {
      case 401:
        return Exception('BigModel API: Invalid API key');
      case 429:
        return Exception('BigModel API: Rate limit exceeded');
      case 500:
        return Exception('BigModel API: Server error');
      default:
        return Exception('BigModel API error: ${e.message}');
    }
  }
}
