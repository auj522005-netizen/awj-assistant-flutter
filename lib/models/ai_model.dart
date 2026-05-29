/// ═══════════════════════════════════════════════════════════════════════════════
/// 🤖 OWJ Assistant — AI Model & Provider Definitions
/// ═══════════════════════════════════════════════════════════════════════════════
///
/// Defines the AI provider enum, model tier/speed/quality enums,
/// the core AIModel data class, and ModelConfig for task-based routing.
///
/// This file is the single source of truth for all model-related types.
/// The actual model instances are defined in `app_config.dart`.
///
/// ═══════════════════════════════════════════════════════════════════════════════

library;

import 'dart:convert';

// ─── AI Provider Enum ────────────────────────────────────────────────────────

/// Supported AI providers in the OWJ ecosystem.
enum AIProvider {
  gemini,
  groq,
  bigmodel,
  openrouter,
  openai,
  cerebras;

  /// Arabic display name
  String get nameAr {
    switch (this) {
      case AIProvider.gemini:
        return 'جوجل جيميناي';
      case AIProvider.groq:
        return 'جروك';
      case AIProvider.bigmodel:
        return 'بيج موديل';
      case AIProvider.openrouter:
        return 'أوبن روتر';
      case AIProvider.openai:
        return 'أوبن إيه آي';
      case AIProvider.cerebras:
        return 'سيريبراس';
    }
  }

  /// English display name
  String get nameEn {
    switch (this) {
      case AIProvider.gemini:
        return 'Google Gemini';
      case AIProvider.groq:
        return 'Groq';
      case AIProvider.bigmodel:
        return 'BigModel (ZhipuAI)';
      case AIProvider.openrouter:
        return 'OpenRouter';
      case AIProvider.openai:
        return 'OpenAI';
      case AIProvider.cerebras:
        return 'Cerebras';
    }
  }

  /// Icon identifier for UI rendering
  String get iconKey {
    switch (this) {
      case AIProvider.gemini:
        return 'activity';
      case AIProvider.groq:
        return 'zap';
      case AIProvider.bigmodel:
        return 'box';
      case AIProvider.openrouter:
        return 'globe';
      case AIProvider.openai:
        return 'cpu';
      case AIProvider.cerebras:
        return 'chip';
    }
  }

  /// Brand color as hex string
  String get colorHex {
    switch (this) {
      case AIProvider.gemini:
        return '#22c55e';
      case AIProvider.groq:
        return '#14b8a6';
      case AIProvider.bigmodel:
        return '#7c3aed';
      case AIProvider.openrouter:
        return '#f97316';
      case AIProvider.openai:
        return '#10b981';
      case AIProvider.cerebras:
        return '#ef4444';
    }
  }

  /// API key environment variable name
  String get apiKeyEnvKey {
    switch (this) {
      case AIProvider.gemini:
        return 'GEMINI_API_KEY';
      case AIProvider.groq:
        return 'GROQ_API_KEY';
      case AIProvider.bigmodel:
        return 'BIGMODEL_API_KEY';
      case AIProvider.openrouter:
        return 'OPENROUTER_API_KEY';
      case AIProvider.openai:
        return 'OPENAI_API_KEY';
      case AIProvider.cerebras:
        return 'CEREBRAS_API_KEY';
    }
  }

  /// Base API URL for this provider
  String get baseUrl {
    switch (this) {
      case AIProvider.gemini:
        return 'https://generativelanguage.googleapis.com/v1beta';
      case AIProvider.groq:
        return 'https://api.groq.com/openai/v1';
      case AIProvider.bigmodel:
        return 'https://open.bigmodel.cn/api/paas/v4';
      case AIProvider.openrouter:
        return 'https://openrouter.ai/api/v1';
      case AIProvider.openai:
        return 'https://api.openai.com/v1';
      case AIProvider.cerebras:
        return 'https://api.cerebras.ai/v1';
    }
  }
}

// ─── Model Tier Enum ─────────────────────────────────────────────────────────

/// Pricing tier for a model.
enum ModelTier {
  free,
  pro;

  String get labelAr {
    switch (this) {
      case ModelTier.free:
        return 'مجاني';
      case ModelTier.pro:
        return 'مدفوع';
    }
  }

  String get labelEn {
    switch (this) {
      case ModelTier.free:
        return 'Free';
      case ModelTier.pro:
        return 'Pro';
    }
  }
}

// ─── Model Speed Enum ────────────────────────────────────────────────────────

/// Relative inference speed of a model.
enum ModelSpeed {
  fast,
  medium,
  slow;

  String get labelAr {
    switch (this) {
      case ModelSpeed.fast:
        return 'سريع';
      case ModelSpeed.medium:
        return 'متوسط';
      case ModelSpeed.slow:
        return 'بطيء';
    }
  }

  String get labelEn {
    switch (this) {
      case ModelSpeed.fast:
        return 'Fast';
      case ModelSpeed.medium:
        return 'Medium';
      case ModelSpeed.slow:
        return 'Slow';
    }
  }

  /// Speed rating as a number (for sorting/comparison)
  int get rating {
    switch (this) {
      case ModelSpeed.fast:
        return 3;
      case ModelSpeed.medium:
        return 2;
      case ModelSpeed.slow:
        return 1;
    }
  }
}

// ─── Model Quality Enum ──────────────────────────────────────────────────────

/// Output quality level of a model.
enum ModelQuality {
  good,
  great,
  excellent;

  String get labelAr {
    switch (this) {
      case ModelQuality.good:
        return 'كويس';
      case ModelQuality.great:
        return 'ممتاز';
      case ModelQuality.excellent:
        return 'استثنائي';
    }
  }

  String get labelEn {
    switch (this) {
      case ModelQuality.good:
        return 'Good';
      case ModelQuality.great:
        return 'Great';
      case ModelQuality.excellent:
        return 'Excellent';
    }
  }

  /// Quality rating as a number (for sorting/comparison)
  int get qualityIndex {
    switch (this) {
      case ModelQuality.good:
        return 1;
      case ModelQuality.great:
        return 2;
      case ModelQuality.excellent:
        return 3;
    }
  }
}

// ─── AI Model Data Class ─────────────────────────────────────────────────────

/// A complete definition of an AI model available in the OWJ ecosystem.
class AIModel {
  /// Unique identifier in "provider:modelId" format
  final String id;

  /// Which provider hosts this model
  final AIProvider provider;

  /// The actual model string sent to the API
  final String modelId;

  /// Display name (English)
  final String name;

  /// Display name (Arabic)
  final String nameAr;

  /// Pricing tier
  final ModelTier tier;

  /// Relative inference speed
  final ModelSpeed speed;

  /// Output quality level
  final ModelQuality quality;

  /// Whether this model supports streaming responses
  final bool supportsStreaming;

  /// Whether this model supports image/vision input
  final bool supportsVision;

  /// Context window size as human-readable string (e.g., "128K", "1M")
  final String contextWindow;

  /// Maximum output tokens
  final int maxTokens;

  /// Cost per 1K tokens in USD (0.0 for free models)
  final double costPer1kTokens;

  /// Short Arabic description
  final String description;

  const AIModel({
    required this.id,
    required this.provider,
    required this.modelId,
    required this.name,
    required this.nameAr,
    required this.tier,
    required this.speed,
    required this.quality,
    required this.supportsStreaming,
    required this.supportsVision,
    required this.contextWindow,
    required this.maxTokens,
    required this.costPer1kTokens,
    required this.description,
  });

  /// Whether this model is free to use
  bool get isFree => tier == ModelTier.free;

  /// Whether this model is a premium/paid model
  bool get isPro => tier == ModelTier.pro;

  /// Parse context window string to approximate token count
  int get contextWindowTokens {
    if (contextWindow.endsWith('M')) {
      return int.tryParse(contextWindow.replaceAll('M', '')) ?? 1 * 1048576;
    }
    if (contextWindow.endsWith('K')) {
      return (int.tryParse(contextWindow.replaceAll('K', '')) ?? 128) * 1024;
    }
    return int.tryParse(contextWindow) ?? 128000;
  }

  // ─── Serialization ──────────────────────────────────────────────────────

  factory AIModel.fromJson(Map<String, dynamic> json) => AIModel(
        id: json['id'] as String? ?? '',
        provider: AIProvider.values.firstWhere(
          (p) => p.name == json['provider'],
          orElse: () => AIProvider.gemini,
        ),
        modelId: json['modelId'] as String? ?? '',
        name: json['name'] as String? ?? '',
        nameAr: json['nameAr'] as String? ?? '',
        tier: ModelTier.values.firstWhere(
          (t) => t.name == json['tier'],
          orElse: () => ModelTier.free,
        ),
        speed: ModelSpeed.values.firstWhere(
          (s) => s.name == json['speed'],
          orElse: () => ModelSpeed.medium,
        ),
        quality: ModelQuality.values.firstWhere(
          (q) => q.name == json['quality'],
          orElse: () => ModelQuality.great,
        ),
        supportsStreaming: json['supportsStreaming'] as bool? ?? false,
        supportsVision: json['supportsVision'] as bool? ?? false,
        contextWindow: json['contextWindow'] as String? ?? '128K',
        maxTokens: json['maxTokens'] as int? ?? 128000,
        costPer1kTokens: (json['costPer1kTokens'] as num?)?.toDouble() ?? 0.0,
        description: json['description'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'provider': provider.name,
        'modelId': modelId,
        'name': name,
        'nameAr': nameAr,
        'tier': tier.name,
        'speed': speed.name,
        'quality': quality.name,
        'supportsStreaming': supportsStreaming,
        'supportsVision': supportsVision,
        'contextWindow': contextWindow,
        'maxTokens': maxTokens,
        'costPer1kTokens': costPer1kTokens,
        'description': description,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AIModel && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'AIModel(id: $id, name: $name, provider: ${provider.name})';
}

// ─── Model Config (Task-Based Routing) ───────────────────────────────────────

/// Configuration for AI model selection per task type.
/// Used by the AI router to pick the best model for each operation.
class ModelConfig {
  /// Selected model for main conversation (chat)
  final String chatModel;

  /// Selected model for quick responses (tasks, intents)
  final String quickModel;

  /// Selected model for deep analysis
  final String deepModel;

  /// Selected model for pattern detection
  final String patternModel;

  /// Selected model for weekly report generation
  final String weeklyReportModel;

  /// Selected model for batch processing
  final String batchModel;

  /// Selected model for long context tasks
  final String longContextModel;

  /// Auto-fallback enabled (if primary fails, try next provider)
  final bool autoFallback;

  /// Fallback chain order (provider names)
  final List<String> fallbackOrder;

  const ModelConfig({
    this.chatModel = 'gemini:gemini-3.1-flash-lite',
    this.quickModel = 'groq:openai/gpt-oss-20b',
    this.deepModel = 'openrouter:google/gemma-4-31b-it:free',
    this.patternModel = 'groq:meta-llama/llama-4-scout-17b-16e-instruct',
    this.weeklyReportModel = 'openrouter:deepseek/deepseek-chat-v3-0324:free',
    this.batchModel = 'groq:qwen/qwen3-32b',
    this.longContextModel = 'bigmodel:glm-4-long',
    this.autoFallback = true,
    this.fallbackOrder = const [
      'gemini',
      'groq',
      'openrouter',
      'bigmodel',
      'openai',
    ],
  });

  /// Get the model ID for a specific task type
  String modelForTask(String taskType) {
    switch (taskType) {
      case 'quick_response':
        return quickModel;
      case 'main_conversation':
        return chatModel;
      case 'deep_analysis':
        return deepModel;
      case 'pattern_detection':
        return patternModel;
      case 'weekly_report':
        return weeklyReportModel;
      case 'batch_processing':
        return batchModel;
      case 'long_context':
        return longContextModel;
      default:
        return chatModel;
    }
  }

  ModelConfig copyWith({
    String? chatModel,
    String? quickModel,
    String? deepModel,
    String? patternModel,
    String? weeklyReportModel,
    String? batchModel,
    String? longContextModel,
    bool? autoFallback,
    List<String>? fallbackOrder,
  }) {
    return ModelConfig(
      chatModel: chatModel ?? this.chatModel,
      quickModel: quickModel ?? this.quickModel,
      deepModel: deepModel ?? this.deepModel,
      patternModel: patternModel ?? this.patternModel,
      weeklyReportModel: weeklyReportModel ?? this.weeklyReportModel,
      batchModel: batchModel ?? this.batchModel,
      longContextModel: longContextModel ?? this.longContextModel,
      autoFallback: autoFallback ?? this.autoFallback,
      fallbackOrder: fallbackOrder ?? this.fallbackOrder,
    );
  }

  // ─── Serialization ──────────────────────────────────────────────────────

  factory ModelConfig.fromJson(Map<String, dynamic> json) => ModelConfig(
        chatModel: json['chatModel'] as String? ?? 'gemini:gemini-3.1-flash-lite',
        quickModel: json['quickModel'] as String? ?? 'groq:openai/gpt-oss-20b',
        deepModel: json['deepModel'] as String? ??
            'openrouter:google/gemma-4-31b-it:free',
        patternModel: json['patternModel'] as String? ??
            'groq:meta-llama/llama-4-scout-17b-16e-instruct',
        weeklyReportModel: json['weeklyReportModel'] as String? ??
            'openrouter:deepseek/deepseek-chat-v3-0324:free',
        batchModel: json['batchModel'] as String? ?? 'groq:qwen/qwen3-32b',
        longContextModel:
            json['longContextModel'] as String? ?? 'bigmodel:glm-4-long',
        autoFallback: json['autoFallback'] as bool? ?? true,
        fallbackOrder: (json['fallbackOrder'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const ['gemini', 'groq', 'openrouter', 'bigmodel', 'openai'],
      );

  Map<String, dynamic> toJson() => {
        'chatModel': chatModel,
        'quickModel': quickModel,
        'deepModel': deepModel,
        'patternModel': patternModel,
        'weeklyReportModel': weeklyReportModel,
        'batchModel': batchModel,
        'longContextModel': longContextModel,
        'autoFallback': autoFallback,
        'fallbackOrder': fallbackOrder,
      };

  factory ModelConfig.fromJsonString(String source) =>
      ModelConfig.fromJson(jsonDecode(source) as Map<String, dynamic>);

  String toJsonString() => jsonEncode(toJson());

  @override
  String toString() => 'ModelConfig(chat: $chatModel, quick: $quickModel, '
      'deep: $deepModel, fallback: $autoFallback)';
}

// ─── API Chat Message ─────────────────────────────────────────────────────────
// Note: The full ChatMessage class is in chat_message.dart.
// This is a lightweight API-facing version used by AI service layers.

/// A lightweight chat message for API communication with AI providers.
class ApiChatMessage {
  final String role;
  final String content;

  const ApiChatMessage({required this.role, required this.content});

  Map<String, dynamic> toMap() => {'role': role, 'content': content};

  factory ApiChatMessage.fromMap(Map<String, dynamic> map) => ApiChatMessage(
        role: map['role'] as String? ?? 'user',
        content: map['content'] as String? ?? '',
      );
}

// ─── AI Response ──────────────────────────────────────────────────────────────

/// Response from an AI chat completion.
class AIResponse {
  final String content;
  final String model;
  final String provider;
  final int promptTokens;
  final int completionTokens;
  final Duration latency;

  const AIResponse({
    required this.content,
    required this.model,
    required this.provider,
    this.promptTokens = 0,
    this.completionTokens = 0,
    this.latency = Duration.zero,
  });

  int get totalTokens => promptTokens + completionTokens;
}

// ─── Stream Chunk ────────────────────────────────────────────────────────────

/// A chunk of a streaming AI response.
class StreamChunk {
  final String text;
  final String model;
  final bool isDone;
  final String? finishReason;

  const StreamChunk({
    this.text = '',
    this.model = '',
    this.isDone = false,
    this.finishReason,
  });
}

// ─── Provider Status ─────────────────────────────────────────────────────────

/// Status of an AI provider connection test.
class ProviderStatus {
  final String provider;
  final bool isAvailable;
  final String? errorMessage;
  final Duration latency;

  const ProviderStatus({
    required this.provider,
    required this.isAvailable,
    this.errorMessage,
    this.latency = Duration.zero,
  });
}

// ─── Task Type ───────────────────────────────────────────────────────────────

/// Types of AI tasks for routing decisions.
enum TaskType {
  quickResponse,
  mainConversation,
  deepAnalysis,
  codeGeneration,
  translation,
  summarization,
  creativeWriting,
  tts,
  stt,
}

// ─── Daily Usage ─────────────────────────────────────────────────────────────

/// Daily usage statistics for a provider.
class DailyUsage {
  final String provider;
  final DateTime date;
  final int requestCount;
  final int totalTokens;

  const DailyUsage({
    required this.provider,
    required this.date,
    this.requestCount = 0,
    this.totalTokens = 0,
  });

  DailyUsage copyWith({int? requestCount, int? totalTokens}) => DailyUsage(
        provider: provider,
        date: date,
        requestCount: requestCount ?? this.requestCount,
        totalTokens: totalTokens ?? this.totalTokens,
      );
}

// ─── STT Result ──────────────────────────────────────────────────────────────

/// Speech-to-text transcription result.
class STTResult {
  final String text;
  final String language;
  final double duration;

  const STTResult({
    required this.text,
    required this.language,
    required this.duration,
  });
}
