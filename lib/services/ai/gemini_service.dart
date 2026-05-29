import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:owj_assistant/config/api_keys.dart';
import 'package:owj_assistant/config/app_config.dart';
import 'package:owj_assistant/models/ai_model.dart';

/// Google Gemini API service for the OWJ Assistant.
///
/// Supports models: gemini-2.5-flash, gemini-2.5-pro, gemini-2.0-flash,
/// gemini-3-flash-preview, gemini-3-pro.
/// Provides streaming via SSE and proper Arabic content handling.
class GeminiService {
  GeminiService({Dio? dio})
      : _dio = dio ?? Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 120),
          headers: {'Content-Type': 'application/json'},
        ));

  final Dio _dio;
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  /// Supported Gemini models (from app_config registry).
  static List<AIModel> get supportedModels =>
      getModelsByProvider(AIProvider.gemini);

  /// Default model for general use.
  static const String defaultModel = 'gemini-2.5-flash';

  int _retryCount = 0;
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  /// Build the request URL for a given model.
  String _buildUrl(String model, {bool stream = false}) {
    final action = stream ? 'streamGenerateContent' : 'generateContent';
    return '$_baseUrl/$model:$action?key=${ApiKeys.geminiApiKey}';
  }

  /// Convert chat messages to Gemini format.
  List<Map<String, dynamic>> _buildContents(List<ApiChatMessage> messages) {
    final contents = <Map<String, dynamic>>[];
    for (final msg in messages) {
      if (msg.role == 'system') continue; // System handled separately
      final role = msg.role == 'assistant' ? 'model' : 'user';
      contents.add({
        'role': role,
        'parts': [
          {'text': msg.content}
        ],
      });
    }
    return contents;
  }

  /// Extract system instruction from messages.
  String? _extractSystemInstruction(List<ApiChatMessage> messages) {
    final systemMsg = messages.where((m) => m.role == 'system').toList();
    if (systemMsg.isEmpty) return null;
    return systemMsg.map((m) => m.content).join('\n');
  }

  /// Send a non-streaming chat completion request.
  Future<AIResponse> chat({
    required List<ApiChatMessage> messages,
    String model = defaultModel,
    double temperature = 0.7,
    int maxTokens = 8192,
  }) async {
    final stopwatch = Stopwatch()..start();
    Exception? lastException;

    for (_retryCount = 0; _retryCount <= _maxRetries; _retryCount++) {
      try {
        final url = _buildUrl(model);
        final body = <String, dynamic>{
          'contents': _buildContents(messages),
          'generationConfig': {
            'temperature': temperature,
            'maxOutputTokens': maxTokens,
          },
        };

        final systemInstruction = _extractSystemInstruction(messages);
        if (systemInstruction != null) {
          body['systemInstruction'] = {
            'parts': [
              {'text': systemInstruction}
            ],
          };
        }

        final response = await _dio.post<Map<String, dynamic>>(
          url,
          data: jsonEncode(body),
        );

        stopwatch.stop();

        final data = response.data!;
        final candidates = data['candidates'] as List<dynamic>?;
        if (candidates == null || candidates.isEmpty) {
          throw Exception('No candidates returned from Gemini');
        }

        final content = ((candidates[0] as Map<String, dynamic>)['content']
                as Map<String, dynamic>)['parts'] as List<dynamic>;
        final text =
            (content[0] as Map<String, dynamic>)['text'] as String? ?? '';

        final usage = data['usageMetadata'] as Map<String, dynamic>?;

        return AIResponse(
          content: text,
          model: model,
          provider: 'gemini',
          promptTokens: (usage?['promptTokenCount'] as int?) ?? 0,
          completionTokens: (usage?['candidatesTokenCount'] as int?) ?? 0,
          latency: stopwatch.elapsed,
        );
      } on DioException catch (e) {
        lastException = e;
        if (!_shouldRetry(e)) rethrow;
        await _waitForRetry();
      } catch (e) {
        lastException = Exception(e.toString());
        rethrow;
      }
    }

    throw lastException ?? Exception('Max retries exceeded for Gemini');
  }

  /// Send a streaming chat completion request via SSE.
  Stream<StreamChunk> chatStream({
    required List<ApiChatMessage> messages,
    String model = defaultModel,
    double temperature = 0.7,
    int maxTokens = 8192,
  }) async* {
    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final url = _buildUrl(model, stream: true);
        final body = <String, dynamic>{
          'contents': _buildContents(messages),
          'generationConfig': {
            'temperature': temperature,
            'maxOutputTokens': maxTokens,
          },
        };

        final systemInstruction = _extractSystemInstruction(messages);
        if (systemInstruction != null) {
          body['systemInstruction'] = {
            'parts': [
              {'text': systemInstruction}
            ],
          };
        }

        final response = await _dio.post<ResponseBody>(
          url,
          data: jsonEncode(body),
          options: Options(
            responseType: ResponseType.stream,
            headers: {'Content-Type': 'application/json'},
          ),
        );

        final stream = response.data!.stream;
        String buffer = '';

        await for (final chunk in stream) {
          buffer += utf8.decode(chunk, allowMalformed: true);
          final lines = buffer.split('\n');
          buffer = lines.removeLast(); // Keep incomplete line in buffer

          for (final line in lines) {
            final trimmed = line.trim();
            if (trimmed.isEmpty || trimmed.startsWith(':')) continue;

            if (trimmed.startsWith('data: ')) {
              final jsonStr = trimmed.substring(6).trim();
              if (jsonStr == '[DONE]') {
                yield const StreamChunk(isDone: true, finishReason: 'stop');
                return;
              }

              try {
                final parsed =
                    jsonDecode(jsonStr) as Map<String, dynamic>;
                final candidates =
                    parsed['candidates'] as List<dynamic>?;
                if (candidates != null && candidates.isNotEmpty) {
                  final parts =
                      ((candidates[0] as Map<String, dynamic>)['content']
                              as Map<String, dynamic>?)?['parts']
                          as List<dynamic>?;
                  if (parts != null && parts.isNotEmpty) {
                    final text =
                        (parts[0] as Map<String, dynamic>)['text'] as String?;
                    if (text != null) {
                      yield StreamChunk(
                        text: text,
                        model: model,
                      );
                    }
                  }

                  // Check finish reason
                  final finishReason =
                      (candidates[0] as Map<String, dynamic>)['finishReason']
                          as String?;
                  if (finishReason == 'STOP' || finishReason == 'MAX_TOKENS') {
                    yield StreamChunk(
                      isDone: true,
                      finishReason: finishReason,
                      model: model,
                    );
                    return;
                  }
                }
              } catch (_) {
                // Skip malformed JSON chunks
              }
            }
          }
        }

        // Stream ended without explicit done signal
        yield const StreamChunk(isDone: true, finishReason: 'stop');
        return;
      } on DioException catch (e) {
        if (!_shouldRetry(e) || attempt >= _maxRetries) rethrow;
        await _waitForRetry();
      }
    }
  }

  /// Test connection to the Gemini API.
  Future<ProviderStatus> testConnection() async {
    if (ApiKeys.geminiApiKey.isEmpty) {
      return const ProviderStatus(
        provider: 'gemini',
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
        model: defaultModel,
        maxTokens: 50,
      );
      stopwatch.stop();
      return ProviderStatus(
        provider: 'gemini',
        isAvailable: response.content.isNotEmpty,
        latency: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return ProviderStatus(
        provider: 'gemini',
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
  Future<void> _waitForRetry() async {
    final delay = _retryDelay * (1 << _retryCount);
    await Future.delayed(delay);
  }
}
