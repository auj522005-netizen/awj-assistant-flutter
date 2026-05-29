import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import 'package:owj_assistant/config/api_keys.dart';
import 'package:owj_assistant/config/app_config.dart';
import 'package:owj_assistant/models/ai_model.dart';

/// Groq API service for the OWJ Assistant.
///
/// Supports chat models: llama-4-scout-17b, gpt-oss-120b, gpt-oss-20b,
/// qwen-3-32b, llama-3.3-70b, llama-3.1-8b.
/// Also supports Whisper STT for Arabic speech-to-text.
class GroqService {
  GroqService({Dio? dio})
      : _dio = dio ?? Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 120),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${ApiKeys.groqApiKey}',
          },
        ));

  final Dio _dio;

  static const String _chatBaseUrl =
      'https://api.groq.com/openai/v1/chat/completions';
  static const String _sttBaseUrl =
      'https://api.groq.com/openai/v1/audio/transcriptions';

  /// Supported Groq models (from app_config registry).
  static List<AIModel> get supportedModels =>
      getModelsByProvider(AIProvider.groq);

  /// Default model for quick responses.
  static const String defaultModel = 'llama-3.1-8b';

  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  /// Get the full Groq model ID (with prefix if needed).
  String _fullModelId(String model) {
    const prefixMap = {
      'llama-4-scout-17b': 'meta-llama/llama-4-scout-17b-16e-instruct',
      'gpt-oss-120b': 'openai/gpt-oss-120b',
      'gpt-oss-20b': 'openai/gpt-oss-20b',
      'qwen-3-32b': 'qwen/qwen3-32b',
      'llama-3.3-70b': 'meta-llama/llama-3.3-70b-versatile',
      'llama-3.1-8b': 'meta-llama/llama-3.1-8b-instant',
    };
    return prefixMap[model] ?? model;
  }

  /// Update the authorization header with the current API key.
  void _updateAuthHeader() {
    _dio.options.headers['Authorization'] = 'Bearer ${ApiKeys.groqApiKey}';
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
            'model': _fullModelId(model),
            'messages': messages.map((m) => m.toMap()).toList(),
            'temperature': temperature,
            'max_tokens': maxTokens,
          }),
        );

        stopwatch.stop();
        final data = response.data!;
        final choices = data['choices'] as List<dynamic>;
        if (choices.isEmpty) {
          throw Exception('No choices returned from Groq');
        }

        final message =
            (choices[0] as Map<String, dynamic>)['message'] as Map<String, dynamic>;
        final content = message['content'] as String? ?? '';
        final usage = data['usage'] as Map<String, dynamic>?;

        return AIResponse(
          content: content,
          model: model,
          provider: 'groq',
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

    throw lastException ?? Exception('Max retries exceeded for Groq');
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
            'model': _fullModelId(model),
            'messages': messages.map((m) => m.toMap()).toList(),
            'temperature': temperature,
            'max_tokens': maxTokens,
            'stream': true,
          }),
          options: Options(
            responseType: ResponseType.stream,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${ApiKeys.groqApiKey}',
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

            if (trimmed.startsWith('data: ')) {
              final jsonStr = trimmed.substring(6).trim();
              if (jsonStr == '[DONE]') {
                yield const StreamChunk(isDone: true, finishReason: 'stop');
                return;
              }

              try {
                final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
                final choices = parsed['choices'] as List<dynamic>?;
                if (choices != null && choices.isNotEmpty) {
                  final delta =
                      (choices[0] as Map<String, dynamic>)['delta']
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

  /// Transcribe audio using Groq Whisper with Arabic language support.
  Future<STTResult> transcribe({
    required String filePath,
    String language = 'ar',
  }) async {
    _updateAuthHeader();

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Audio file not found: $filePath');
      }

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
        'model': 'whisper-large-v3',
        'language': language,
        'response_format': 'json',
      });

      final response = await _dio.post<Map<String, dynamic>>(
        _sttBaseUrl,
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${ApiKeys.groqApiKey}',
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      final data = response.data!;
      return STTResult(
        text: data['text'] as String? ?? '',
        language: language,
        duration: (data['duration'] as num?)?.toDouble() ?? 0.0,
      );
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  /// Test connection to the Groq API.
  Future<ProviderStatus> testConnection() async {
    if (ApiKeys.groqApiKey.isEmpty) {
      return const ProviderStatus(
        provider: 'groq',
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
        model: 'llama-3.1-8b',
        maxTokens: 50,
      );
      stopwatch.stop();
      return ProviderStatus(
        provider: 'groq',
        isAvailable: response.content.isNotEmpty,
        latency: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return ProviderStatus(
        provider: 'groq',
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
        return Exception('Groq API: Invalid API key');
      case 429:
        return Exception('Groq API: Rate limit exceeded');
      case 500:
        return Exception('Groq API: Server error');
      default:
        return Exception('Groq API error: ${e.message}');
    }
  }
}
