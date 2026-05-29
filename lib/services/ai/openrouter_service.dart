import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:owj_assistant/config/api_keys.dart';
import 'package:owj_assistant/config/app_config.dart';
import 'package:owj_assistant/models/ai_model.dart';

/// OpenRouter API service for the OWJ Assistant.
///
/// Supports 15+ models across multiple providers, providing access
/// to a wide range of AI capabilities through a single API.
class OpenRouterService {
  OpenRouterService({Dio? dio})
      : _dio = dio ?? Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 180),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${ApiKeys.openrouterApiKey}',
            'HTTP-Referer': 'https://owj.app',
            'X-Title': 'OWJ Assistant',
          },
        ));

  final Dio _dio;

  static const String _baseUrl =
      'https://openrouter.ai/api/v1/chat/completions';

  /// Supported OpenRouter models (from app_config registry).
  static List<AIModel> get supportedModels =>
      getModelsByProvider(AIProvider.openrouter);

  /// Default model for general use — confirmed free and reliable.
  static const String defaultModel = 'deepseek/deepseek-chat-v3-0324:free';

  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  /// Get the full OpenRouter model ID with provider prefix.
  /// If the model already contains a '/', it's already a full ID.
  String _fullModelId(String model) {
    // Already a full model ID with provider prefix
    if (model.contains('/')) return model;

    const modelMap = {
      'gemma-4-31b': 'google/gemma-4-31b-it:free',
      'gemma-4-12b': 'google/gemma-4-12b-it:free',
      'gemma-4-4b': 'google/gemma-4-4b-it:free',
      'qwen-3-coder': 'qwen/qwen3-coder:free',
      'ring-2.6-1t': 'inclusionai/ring-2.6-1t:free',
      'glm-4.5-air': 'z-ai/glm-4.5-air:free',
      'nemotron-3-super': 'nvidia/nemotron-3-super-120b-a12b:free',
      'gpt-oss-120b': 'openai/gpt-oss-120b:free',
      'gpt-oss-20b': 'openai/gpt-oss-20b:free',
      'deepseek-r1': 'deepseek/deepseek-r1:free',
      'deepseek-v3': 'deepseek/deepseek-chat-v3-0324:free',
      'qwen-3-235b': 'qwen/qwen3-235b-a22b:free',
      'qwen-3-32b': 'qwen/qwen3-32b:free',
      'hermes-3-405b': 'nousresearch/hermes-3-llama-3.1-405b:free',
      'mistral-small-3.1': 'mistralai/mistral-small-3.1-24b-instruct:free',
      'phi-4-reasoning': 'microsoft/phi-4-reasoning:free',
      'llama-3.3-70b': 'meta-llama/llama-3.3-70b-instruct:free',
      'llama-3.2-3b': 'meta-llama/llama-3.2-3b-instruct:free',
    };
    return modelMap[model] ?? model;
  }

  /// Update the authorization header with the current API key.
  void _updateAuthHeader() {
    _dio.options.headers['Authorization'] =
        'Bearer ${ApiKeys.openrouterApiKey}';
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
          throw Exception('No choices returned from OpenRouter');
        }

        final message = (choices[0] as Map<String, dynamic>)['message']
            as Map<String, dynamic>;
        final content = message['content'] as String? ?? '';
        final usage = data['usage'] as Map<String, dynamic>?;

        return AIResponse(
          content: content,
          model: model,
          provider: 'openrouter',
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

    throw lastException ?? Exception('Max retries exceeded for OpenRouter');
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
              'Authorization': 'Bearer ${ApiKeys.openrouterApiKey}',
              'HTTP-Referer': 'https://owj.app',
              'X-Title': 'OWJ Assistant',
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

  /// Test connection to the OpenRouter API.
  Future<ProviderStatus> testConnection() async {
    if (ApiKeys.openrouterApiKey.isEmpty) {
      return const ProviderStatus(
        provider: 'openrouter',
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
        model: 'gemma-4-4b',
        maxTokens: 50,
      );
      stopwatch.stop();
      return ProviderStatus(
        provider: 'openrouter',
        isAvailable: response.content.isNotEmpty,
        latency: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return ProviderStatus(
        provider: 'openrouter',
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
