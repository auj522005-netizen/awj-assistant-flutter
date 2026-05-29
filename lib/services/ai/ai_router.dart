import 'dart:async';

import 'package:owj_assistant/config/api_keys.dart';
import 'package:owj_assistant/models/ai_model.dart';
import 'package:owj_assistant/services/ai/gemini_service.dart';
import 'package:owj_assistant/services/ai/groq_service.dart';
import 'package:owj_assistant/services/ai/cerebras_service.dart';
import 'package:owj_assistant/services/ai/openrouter_service.dart';
import 'package:owj_assistant/services/ai/openai_service.dart';
import 'package:owj_assistant/services/ai/bigmodel_service.dart';

/// AI Router that intelligently routes requests to the best provider
/// based on task type, with automatic fallback chains and daily usage tracking.
class AIRouter {
  AIRouter()
      : gemini = GeminiService(),
        groq = GroqService(),
        cerebras = CerebrasService(),
        openrouter = OpenRouterService(),
        openai = OpenAIService(),
        bigmodel = BigModelService();

  /// Service instances.
  final GeminiService gemini;
  final GroqService groq;
  final CerebrasService cerebras;
  final OpenRouterService openrouter;
  final OpenAIService openai;
  final BigModelService bigmodel;

  /// Fallback chain order for provider selection.
  /// Prioritizes confirmed working providers: BigModel and OpenRouter.
  static const List<String> _fallbackChain = [
    'bigmodel',
    'openrouter',
    'groq',
    'gemini',
    'openai',
    'cerebras',
  ];

  /// Task type to preferred provider mapping.
  /// Prioritizes confirmed working providers: BigModel and OpenRouter.
  static const Map<TaskType, String> _taskProviderMap = {
    TaskType.quickResponse: 'bigmodel',
    TaskType.mainConversation: 'bigmodel',
    TaskType.deepAnalysis: 'openrouter',
    TaskType.codeGeneration: 'openrouter',
    TaskType.translation: 'bigmodel',
    TaskType.summarization: 'bigmodel',
    TaskType.creativeWriting: 'bigmodel',
    TaskType.tts: 'bigmodel',
    TaskType.stt: 'groq',
  };

  /// Task type to model mapping per provider.
  /// Uses confirmed working model IDs for each provider.
  static const Map<TaskType, Map<String, String>> _taskModelMap = {
    TaskType.quickResponse: {
      'bigmodel': 'glm-5-turbo',
      'openrouter': 'deepseek/deepseek-chat-v3-0324:free',
      'groq': 'llama-3.1-8b-instant',
      'gemini': 'gemini-2.5-flash',
      'cerebras': 'gpt-oss-120b',
    },
    TaskType.mainConversation: {
      'bigmodel': 'glm-5-turbo',
      'openrouter': 'deepseek/deepseek-chat-v3-0324:free',
      'groq': 'openai/gpt-oss-120b',
      'gemini': 'gemini-2.5-flash',
      'cerebras': 'gpt-oss-120b',
      'openai': 'gpt-4o-mini',
    },
    TaskType.deepAnalysis: {
      'openrouter': 'deepseek/deepseek-r1:free',
      'bigmodel': 'glm-5.1',
      'gemini': 'gemini-2.5-pro',
      'openai': 'o3',
    },
    TaskType.codeGeneration: {
      'openrouter': 'qwen/qwen3-coder:free',
      'bigmodel': 'glm-5.1',
      'groq': 'qwen-3-32b',
      'gemini': 'gemini-2.5-pro',
    },
    TaskType.translation: {
      'bigmodel': 'glm-5-turbo',
      'openrouter': 'qwen/qwen3-32b:free',
      'groq': 'llama-3.3-70b',
      'gemini': 'gemini-2.5-flash',
    },
    TaskType.summarization: {
      'bigmodel': 'glm-4.5-air',
      'openrouter': 'google/gemma-4-12b-it:free',
      'groq': 'openai/gpt-oss-20b',
      'gemini': 'gemini-2.5-flash',
      'cerebras': 'gpt-oss-120b',
    },
    TaskType.creativeWriting: {
      'bigmodel': 'glm-5',
      'openrouter': 'nousresearch/hermes-3-llama-3.1-405b:free',
      'gemini': 'gemini-2.5-pro',
    },
  };

  /// Daily usage tracking: provider -> date string -> usage data.
  final Map<String, Map<String, DailyUsage>> _dailyUsage = {};

  /// Provider availability cache.
  final Map<String, bool> _availabilityCache = {};

  /// Maximum daily requests per provider.
  static const int _maxDailyRequestsPerProvider = 500;

  /// Get today's date key.
  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Record a usage event for a provider.
  void _recordUsage(String provider, int tokens) {
    final today = _todayKey();
    _dailyUsage.putIfAbsent(provider, () => {});
    _dailyUsage[provider]!.putIfAbsent(
      today,
      () => DailyUsage(provider: provider, date: DateTime.now()),
    );
    final current = _dailyUsage[provider]![today]!;
    _dailyUsage[provider]![today] = current.copyWith(
      requestCount: current.requestCount + 1,
      totalTokens: current.totalTokens + tokens,
    );
  }

  /// Check if a provider is available (has API key and hasn't exceeded limits).
  bool _isProviderAvailable(String provider) {
    // Check API key
    if (!ApiKeys.hasKey(provider)) return false;

    // Check daily limit
    final today = _todayKey();
    final usage = _dailyUsage[provider]?[today];
    if (usage != null && usage.requestCount >= _maxDailyRequestsPerProvider) {
      return false;
    }

    // Check availability cache
    return _availabilityCache[provider] ?? true;
  }

  /// Get the preferred provider for a task type, considering availability.
  String _getProviderForTask(TaskType taskType) {
    // Check task-specific provider first
    final preferred = _taskProviderMap[taskType];
    if (preferred != null && _isProviderAvailable(preferred)) {
      return preferred;
    }

    // Fall back through the chain
    for (final provider in _fallbackChain) {
      if (_isProviderAvailable(provider)) {
        return provider;
      }
    }

    // If nothing is available, return the first configured provider
    final configured = ApiKeys.configuredProviders;
    if (configured.isNotEmpty) return configured.first;

    return 'gemini'; // Ultimate fallback
  }

  /// Get the best model for a task type and provider.
  String _getModelForTask(TaskType taskType, String provider) {
    final modelMap = _taskModelMap[taskType];
    if (modelMap != null && modelMap.containsKey(provider)) {
      return modelMap[provider]!;
    }

    // Default models per provider
    switch (provider) {
      case 'gemini':
        return GeminiService.defaultModel;
      case 'groq':
        return GroqService.defaultModel;
      case 'cerebras':
        return CerebrasService.defaultModel;
      case 'openrouter':
        return OpenRouterService.defaultModel;
      case 'openai':
        return OpenAIService.defaultModel;
      case 'bigmodel':
        return BigModelService.defaultModel;
      default:
        return 'gemini-2.5-flash';
    }
  }

  /// Send a chat request routed to the best provider for the task type.
  /// Automatically falls back through the chain on failure.
  Future<AIResponse> chat({
    required List<ApiChatMessage> messages,
    TaskType taskType = TaskType.mainConversation,
    String? preferredProvider,
    String? preferredModel,
    double temperature = 0.7,
    int maxTokens = 4096,
  }) async {
    // Build provider order
    final providers = _buildProviderOrder(taskType, preferredProvider);

    Exception? lastException;

    for (final provider in providers) {
      if (!_isProviderAvailable(provider)) continue;

      final model = preferredModel ?? _getModelForTask(taskType, provider);

      try {
        final response = await _chatWithProvider(
          provider: provider,
          model: model,
          messages: messages,
          temperature: temperature,
          maxTokens: maxTokens,
        );

        _recordUsage(provider, response.totalTokens);
        return response;
      } catch (e) {
        lastException = Exception('$provider: $e');
        // Mark provider as potentially unavailable
        _availabilityCache[provider] = false;
        // Reset after 30 seconds
        Future.delayed(const Duration(seconds: 30), () {
          _availabilityCache.remove(provider);
        });
        continue;
      }
    }

    throw lastException ??
        Exception('No available AI provider. Please configure API keys.');
  }

  /// Send a streaming chat request routed to the best provider.
  Stream<StreamChunk> chatStream({
    required List<ApiChatMessage> messages,
    TaskType taskType = TaskType.mainConversation,
    String? preferredProvider,
    String? preferredModel,
    double temperature = 0.7,
    int maxTokens = 4096,
  }) async* {
    final providers = _buildProviderOrder(taskType, preferredProvider);

    for (final provider in providers) {
      if (!_isProviderAvailable(provider)) continue;

      final model = preferredModel ?? _getModelForTask(taskType, provider);

      try {
        int tokenCount = 0;
        await for (final chunk in _chatStreamWithProvider(
          provider: provider,
          model: model,
          messages: messages,
          temperature: temperature,
          maxTokens: maxTokens,
        )) {
          if (chunk.text.isNotEmpty) {
            tokenCount += (chunk.text.length / 4).ceil(); // Rough estimate
          }
          yield chunk;

          if (chunk.isDone) {
            _recordUsage(provider, tokenCount);
            return;
          }
        }
        return; // Successfully completed
      } catch (e) {
        // Mark provider as potentially unavailable
        _availabilityCache[provider] = false;
        Future.delayed(const Duration(seconds: 30), () {
          _availabilityCache.remove(provider);
        });
        // Try next provider
        continue;
      }
    }

    yield const StreamChunk(
      isDone: true,
      finishReason: 'error',
      text: '',
    );
  }

  /// Build the ordered list of providers to try.
  List<String> _buildProviderOrder(
    TaskType taskType,
    String? preferredProvider,
  ) {
    final order = <String>[];

    // Add preferred provider first if specified
    if (preferredProvider != null) {
      order.add(preferredProvider);
    }

    // Add task-specific provider
    final taskProvider = _taskProviderMap[taskType];
    if (taskProvider != null && !order.contains(taskProvider)) {
      order.add(taskProvider);
    }

    // Add the rest from fallback chain
    for (final provider in _fallbackChain) {
      if (!order.contains(provider)) {
        order.add(provider);
      }
    }

    return order;
  }

  /// Execute a non-streaming chat with a specific provider.
  Future<AIResponse> _chatWithProvider({
    required String provider,
    required String model,
    required List<ApiChatMessage> messages,
    required double temperature,
    required int maxTokens,
  }) async {
    switch (provider) {
      case 'gemini':
        return gemini.chat(
          messages: messages,
          model: model,
          temperature: temperature,
          maxTokens: maxTokens,
        );
      case 'groq':
        return groq.chat(
          messages: messages,
          model: model,
          temperature: temperature,
          maxTokens: maxTokens,
        );
      case 'cerebras':
        return cerebras.chat(
          messages: messages,
          model: model,
          temperature: temperature,
          maxTokens: maxTokens,
        );
      case 'openrouter':
        return openrouter.chat(
          messages: messages,
          model: model,
          temperature: temperature,
          maxTokens: maxTokens,
        );
      case 'openai':
        return openai.chat(
          messages: messages,
          model: model,
          temperature: temperature,
          maxTokens: maxTokens,
        );
      case 'bigmodel':
        return bigmodel.chat(
          messages: messages,
          model: model,
          temperature: temperature,
          maxTokens: maxTokens,
        );
      default:
        throw Exception('Unknown provider: $provider');
    }
  }

  /// Execute a streaming chat with a specific provider.
  Stream<StreamChunk> _chatStreamWithProvider({
    required String provider,
    required String model,
    required List<ApiChatMessage> messages,
    required double temperature,
    required int maxTokens,
  }) {
    switch (provider) {
      case 'gemini':
        return gemini.chatStream(
          messages: messages,
          model: model,
          temperature: temperature,
          maxTokens: maxTokens,
        );
      case 'groq':
        return groq.chatStream(
          messages: messages,
          model: model,
          temperature: temperature,
          maxTokens: maxTokens,
        );
      case 'cerebras':
        return cerebras.chatStream(
          messages: messages,
          model: model,
          temperature: temperature,
          maxTokens: maxTokens,
        );
      case 'openrouter':
        return openrouter.chatStream(
          messages: messages,
          model: model,
          temperature: temperature,
          maxTokens: maxTokens,
        );
      case 'openai':
        return openai.chatStream(
          messages: messages,
          model: model,
          temperature: temperature,
          maxTokens: maxTokens,
        );
      case 'bigmodel':
        return bigmodel.chatStream(
          messages: messages,
          model: model,
          temperature: temperature,
          maxTokens: maxTokens,
        );
      default:
        return Stream.error(Exception('Unknown provider: $provider'));
    }
  }

  /// Get daily usage statistics for all providers.
  Map<String, DailyUsage?> getDailyUsage() {
    final today = _todayKey();
    return {
      for (final provider in _fallbackChain)
        provider: _dailyUsage[provider]?[today],
    };
  }

  /// Get total requests made today across all providers.
  int getTodayTotalRequests() {
    final today = _todayKey();
    int total = 0;
    for (final provider in _fallbackChain) {
      total += _dailyUsage[provider]?[today]?.requestCount ?? 0;
    }
    return total;
  }

  /// Reset the availability cache for a specific provider or all providers.
  void resetAvailabilityCache({String? provider}) {
    if (provider != null) {
      _availabilityCache.remove(provider);
    } else {
      _availabilityCache.clear();
    }
  }

  /// Get the list of available providers.
  List<String> get availableProviders {
    return _fallbackChain
        .where((p) => _isProviderAvailable(p))
        .toList();
  }

  /// Get the list of all configured providers (have API keys).
  List<String> get configuredProviders => ApiKeys.configuredProviders;

  /// Test connection to all configured providers.
  Future<List<ProviderStatus>> testAllConnections() async {
    final futures = <Future<ProviderStatus>>[];

    if (ApiKeys.hasKey('gemini')) futures.add(gemini.testConnection());
    if (ApiKeys.hasKey('groq')) futures.add(groq.testConnection());
    if (ApiKeys.hasKey('cerebras')) futures.add(cerebras.testConnection());
    if (ApiKeys.hasKey('openrouter')) futures.add(openrouter.testConnection());
    if (ApiKeys.hasKey('openai')) futures.add(openai.testConnection());
    if (ApiKeys.hasKey('bigmodel')) futures.add(bigmodel.testConnection());

    if (futures.isEmpty) {
      return [
        const ProviderStatus(
          provider: 'none',
          isAvailable: false,
          errorMessage: 'No API keys configured',
        ),
      ];
    }

    final results = await Future.wait(futures);

    // Update availability cache based on test results
    for (final status in results) {
      _availabilityCache[status.provider] = status.isAvailable;
    }

    return results;
  }

  /// Get the recommended provider for a given task type.
  String getRecommendedProvider(TaskType taskType) {
    return _getProviderForTask(taskType);
  }

  /// Get the recommended model for a given task type.
  String getRecommendedModel(TaskType taskType) {
    final provider = _getProviderForTask(taskType);
    return _getModelForTask(taskType, provider);
  }

  /// Get all supported models across all providers.
  List<AIModel> get allModels => [
        ...GeminiService.supportedModels,
        ...GroqService.supportedModels,
        ...CerebrasService.supportedModels,
        ...OpenRouterService.supportedModels,
        ...OpenAIService.supportedModels,
        ...BigModelService.supportedModels,
      ];

  /// Get models for a specific provider.
  List<AIModel> getModelsForProvider(String provider) {
    switch (provider) {
      case 'gemini':
        return GeminiService.supportedModels;
      case 'groq':
        return GroqService.supportedModels;
      case 'cerebras':
        return CerebrasService.supportedModels;
      case 'openrouter':
        return OpenRouterService.supportedModels;
      case 'openai':
        return OpenAIService.supportedModels;
      case 'bigmodel':
        return BigModelService.supportedModels;
      default:
        return [];
    }
  }
}
