import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:owj_assistant/config/api_keys.dart';
import 'package:owj_assistant/config/app_config.dart';
import 'package:owj_assistant/models/ai_model.dart';

/// Cerebras API service for the OWJ Assistant.
///
/// Supports model: llama-4-scout-17b.
/// Ultra-fast inference for quick responses.
class CerebrasService {
  CerebrasService({Dio? dio})
      : _dio = dio ?? Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 120),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${ApiKeys.cerebrasApiKey}',
          },
        ));

  final Dio _dio;

  static const String _baseUrl =
      'https://api.cerebras.ai/v1/chat/completions';

  /// Supported Cerebras models (from app_config registry).
  static List<AIModel> get supportedModels =>
      getModelsByProvider(AIProvider.cerebras);

  /// Default model.
  static const String defaultModel = 'llama-4-scout-17b';

  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  /// Get the full Cerebras model ID.
  String _fullModelId(String model) {
    const modelMap = {
      'llama-4-scout-17b': 'llama-4-scout-17b-16e-instruct',
    };
    return modelMap[model] ?? model;
  }

  /// Update the authorization header with the current API key.
  void _updateAuthHeader() {
    _dio.options.headers['Authorization'] =
        'Bearer ${ApiKeys.cerebrasApiKey}';
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
          _baseUrl,
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
          throw Exception('No choices returned from Cerebras');
        }

        final message = (choices[0] as Map<String, dynamic>)['message']
            as Map<String, dynamic>;
        final content = message['content'] as String? ?? '';
        final usage = data['usage'] as Map<String, dynamic>?;

        return AIResponse(
          content: content,
          model: model,
          provider: 'cerebras',
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

    throw lastException ?? Exception('Max retries exceeded for Cerebras');
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
          _baseUrl,
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
              'Authorization': 'Bearer ${ApiKeys.cerebrasApiKey}',
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

  /// Test connection to the Cerebras API.
  Future<ProviderStatus> testConnection() async {
    if (ApiKeys.cerebrasApiKey.isEmpty) {
      return const ProviderStatus(
        provider: 'cerebras',
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
        maxTokens: 50,
      );
      stopwatch.stop();
      return ProviderStatus(
        provider: 'cerebras',
        isAvailable: response.content.isNotEmpty,
        latency: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return ProviderStatus(
        provider: 'cerebras',
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
}
