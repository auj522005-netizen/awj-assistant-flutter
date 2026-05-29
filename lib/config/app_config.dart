/// ═══════════════════════════════════════════════════════════════════════════════
/// ⚙️ OWJ Assistant — App Configuration
/// ═══════════════════════════════════════════════════════════════════════════════
///
/// Central configuration for the OWJ (أوج) app: app metadata, default model
/// selections, AI task routing, and complete model definitions across all
/// providers (35+ models).
///
/// ═══════════════════════════════════════════════════════════════════════════════

library;

import '../models/ai_model.dart';

// ─── App Metadata ────────────────────────────────────────────────────────────

class AppConfig {
  AppConfig._();

  /// App display name (Arabic)
  static const String appNameAr = 'أوج';

  /// App display name (English)
  static const String appNameEn = 'OWJ';

  /// Full app name with tagline
  static const String appTaglineAr = 'أوج — مساعدك الذكي المصري';

  /// Current version
  static const String version = '2.1.0';

  /// Build number
  static const int buildNumber = 2;

  /// Default locale
  static const String defaultLocale = 'ar_EG';

  /// Supported locales
  static const List<String> supportedLocales = ['ar_EG', 'en_US'];

  /// Maximum chat history to keep in memory
  static const int maxChatHistoryMemory = 100;

  /// Maximum memories to fetch per request
  static const int maxMemoriesPerRequest = 10;

  /// Streaming chunk debounce (milliseconds)
  static const int streamDebounceMs = 50;

  /// Toast display duration (milliseconds)
  static const int toastDurationMs = 3000;

  /// Maximum file upload size (bytes) — 10 MB
  static const int maxFileUploadBytes = 10 * 1024 * 1024;
}

// ─── AI Task Routing ─────────────────────────────────────────────────────────
//
// Each task type maps to a preferred model. The router picks the best model
// based on the task, with automatic fallback if the primary is unavailable.

enum AiTask {
  quickResponse,
  mainConversation,
  deepAnalysis,
  patternDetection,
  weeklyReport,
  batchProcessing,
  longContext,
}

/// Human-readable Arabic labels for each AI task
const Map<AiTask, String> aiTaskLabelsAr = {
  AiTask.quickResponse: 'رد سريع',
  AiTask.mainConversation: 'محادثة رئيسية',
  AiTask.deepAnalysis: 'تحليل عميق',
  AiTask.patternDetection: 'كشف الأنماط',
  AiTask.weeklyReport: 'تقرير أسبوعي',
  AiTask.batchProcessing: 'معالجة دفعات',
  AiTask.longContext: 'سياق طويل',
};

/// Human-readable English labels for each AI task
const Map<AiTask, String> aiTaskLabelsEn = {
  AiTask.quickResponse: 'Quick Response',
  AiTask.mainConversation: 'Main Conversation',
  AiTask.deepAnalysis: 'Deep Analysis',
  AiTask.patternDetection: 'Pattern Detection',
  AiTask.weeklyReport: 'Weekly Report',
  AiTask.batchProcessing: 'Batch Processing',
  AiTask.longContext: 'Long Context',
};

/// Default model assignment for each AI task
/// Prioritizes confirmed working providers: BigModel and OpenRouter
const Map<AiTask, String> defaultTaskModels = {
  AiTask.quickResponse:     'bigmodel:glm-5-turbo',
  AiTask.mainConversation:  'bigmodel:glm-5-turbo',
  AiTask.deepAnalysis:      'openrouter:deepseek/deepseek-r1:free',
  AiTask.patternDetection:  'bigmodel:glm-4.5-air',
  AiTask.weeklyReport:      'openrouter:deepseek/deepseek-chat-v3-0324:free',
  AiTask.batchProcessing:   'openrouter:qwen/qwen3-32b:free',
  AiTask.longContext:       'bigmodel:glm-5-turbo',
};

/// Fallback order by provider — used when primary model is unavailable
const List<String> fallbackProviderOrder = [
  'bigmodel',
  'openrouter',
  'groq',
  'cerebras',
  'gemini',
  'openai',
];

// ─── Model Registry — 35+ Models Across All Providers ────────────────────────

/// All available AI models, organized by provider.
/// Updated May 2026 with latest model releases.
final List<AIModel> allModels = [
  // ═══ Google Gemini ═════════════════════════════════════════════════════════
  const AIModel(
    id: 'gemini:gemini-3.1-flash-lite',
    provider: AIProvider.gemini,
    modelId: 'gemini-3.1-flash-lite',
    name: 'Gemini 3.1 Flash Lite',
    nameAr: 'جيميناي 3.1 فلاش لايت',
    tier: ModelTier.free,
    speed: ModelSpeed.fast,
    quality: ModelQuality.excellent,
    supportsStreaming: true,
    supportsVision: true,
    contextWindow: '1M',
    maxTokens: 1048576,
    costPer1kTokens: 0.0,
    description: 'أحدث وأسرع موديل جوجل — جيل 3.1 فلاش لايت مجاني',
  ),
  const AIModel(
    id: 'gemini:gemini-3-flash-preview',
    provider: AIProvider.gemini,
    modelId: 'gemini-3-flash-preview',
    name: 'Gemini 3 Flash',
    nameAr: 'جيميناي 3 فلاش',
    tier: ModelTier.free,
    speed: ModelSpeed.fast,
    quality: ModelQuality.excellent,
    supportsStreaming: true,
    supportsVision: true,
    contextWindow: '1M',
    maxTokens: 1048576,
    costPer1kTokens: 0.0,
    description: 'جيل 3 فلاش — أحدث جيل من جوجل بتفكير عميق',
  ),
  const AIModel(
    id: 'gemini:gemini-2.5-pro',
    provider: AIProvider.gemini,
    modelId: 'gemini-2.5-pro',
    name: 'Gemini 2.5 Pro',
    nameAr: 'جيميناي 2.5 برو',
    tier: ModelTier.free,
    speed: ModelSpeed.medium,
    quality: ModelQuality.excellent,
    supportsStreaming: true,
    supportsVision: true,
    contextWindow: '1M',
    maxTokens: 1048576,
    costPer1kTokens: 0.0,
    description: 'أقوى موديل جيميناي مستقر — للتحليلات العميقة والكود',
  ),
  const AIModel(
    id: 'gemini:gemini-2.5-flash',
    provider: AIProvider.gemini,
    modelId: 'gemini-2.5-flash',
    name: 'Gemini 2.5 Flash',
    nameAr: 'جيميناي 2.5 فلاش',
    tier: ModelTier.free,
    speed: ModelSpeed.fast,
    quality: ModelQuality.excellent,
    supportsStreaming: true,
    supportsVision: true,
    contextWindow: '1M',
    maxTokens: 1048576,
    costPer1kTokens: 0.0,
    description: 'أفضل توازن بين السرعة والجودة — المستقر',
  ),
  const AIModel(
    id: 'gemini:gemini-3-pro',
    provider: AIProvider.gemini,
    modelId: 'gemini-3-pro',
    name: 'Gemini 3 Pro',
    nameAr: 'جيميناي 3 برو',
    tier: ModelTier.free,
    speed: ModelSpeed.medium,
    quality: ModelQuality.excellent,
    supportsStreaming: true,
    supportsVision: true,
    contextWindow: '1M',
    maxTokens: 1048576,
    costPer1kTokens: 0.0,
    description: 'جيل 3 برو — موديل تفكير عميق من جوجل',
  ),
  const AIModel(
    id: 'gemini:gemini-2.0-flash',
    provider: AIProvider.gemini,
    modelId: 'gemini-2.0-flash',
    name: 'Gemini 2.0 Flash',
    nameAr: 'جيميناي 2.0 فلاش',
    tier: ModelTier.free,
    speed: ModelSpeed.fast,
    quality: ModelQuality.great,
    supportsStreaming: true,
    supportsVision: true,
    contextWindow: '1M',
    maxTokens: 1048576,
    costPer1kTokens: 0.0,
    description: 'الموديل القديم — لسه شغال لكن بينتهي يونيو 2026',
  ),

  // ═══ Groq ══════════════════════════════════════════════════════════════════
  const AIModel(
    id: 'groq:meta-llama/llama-4-scout-17b-16e-instruct',
    provider: AIProvider.groq,
    modelId: 'meta-llama/llama-4-scout-17b-16e-instruct',
    name: 'Llama 4 Scout',
    nameAr: 'لاما 4 سكوت',
    tier: ModelTier.free,
    speed: ModelSpeed.fast,
    quality: ModelQuality.excellent,
    supportsStreaming: true,
    supportsVision: false,
    contextWindow: '131K',
    maxTokens: 131072,
    costPer1kTokens: 0.0,
    description: 'أحدث موديل ميتا على جروك — 109B MoE سريع جداً',
  ),
  const AIModel(
    id: 'groq:openai/gpt-oss-120b',
    provider: AIProvider.groq,
    modelId: 'openai/gpt-oss-120b',
    name: 'GPT-OSS 120B',
    nameAr: 'GPT-OSS 120B',
    tier: ModelTier.free,
    speed: ModelSpeed.fast,
    quality: ModelQuality.excellent,
    supportsStreaming: true,
    supportsVision: false,
    contextWindow: '131K',
    maxTokens: 131072,
    costPer1kTokens: 0.0,
    description: 'موديل OpenAI المفتوح على جروك — 120B ضخم ومجاني',
  ),
  const AIModel(
    id: 'groq:openai/gpt-oss-20b',
    provider: AIProvider.groq,
    modelId: 'openai/gpt-oss-20b',
    name: 'GPT-OSS 20B',
    nameAr: 'GPT-OSS 20B',
    tier: ModelTier.free,
    speed: ModelSpeed.fast,
    quality: ModelQuality.great,
    supportsStreaming: true,
    supportsVision: false,
    contextWindow: '131K',
    maxTokens: 131072,
    costPer1kTokens: 0.0,
    description: 'أخف نسخة GPT-OSS — أسرع بـ 1000 توكن/ثانية',
  ),
  const AIModel(
    id: 'groq:qwen/qwen3-32b',
    provider: AIProvider.groq,
    modelId: 'qwen/qwen3-32b',
    name: 'Qwen 3 32B',
    nameAr: 'كوين 3 32B',
    tier: ModelTier.free,
    speed: ModelSpeed.fast,
    quality: ModelQuality.great,
    supportsStreaming: true,
    supportsVision: false,
    contextWindow: '131K',
    maxTokens: 131072,
    costPer1kTokens: 0.0,
    description: 'موديل علي بابا على جروك — ممتاز بالعربية',
  ),
  const AIModel(
    id: 'groq:llama-3.3-70b-versatile',
    provider: AIProvider.groq,
    modelId: 'llama-3.3-70b-versatile',
    name: 'Llama 3.3 70B',
    nameAr: 'لاما 3.3 70B',
    tier: ModelTier.free,
    speed: ModelSpeed.fast,
    quality: ModelQuality.great,
    supportsStreaming: true,
    supportsVision: false,
    contextWindow: '128K',
    maxTokens: 131072,
    costPer1kTokens: 0.0,
    description: 'الموديل القديم الثابت — سريع وموثوق',
  ),
  const AIModel(
    id: 'groq:llama-3.1-8b-instant',
    provider: AIProvider.groq,
    modelId: 'llama-3.1-8b-instant',
    name: 'Llama 3.1 8B',
    nameAr: 'لاما 3.1 8B',
    tier: ModelTier.free,
    speed: ModelSpeed.fast,
    quality: ModelQuality.good,
    supportsStreaming: true,
    supportsVision: false,
    contextWindow: '128K',
    maxTokens: 131072,
    costPer1kTokens: 0.0,
    description: 'فائق السرعة — مثالي للمهام البسيطة والردود السريعة',
  ),
  const AIModel(
    id: 'groq:groq/compound',
    provider: AIProvider.groq,
    modelId: 'groq/compound',
    name: 'Groq Compound',
    nameAr: 'جروك كومباوند',
    tier: ModelTier.free,
    speed: ModelSpeed.fast,
    quality: ModelQuality.excellent,
    supportsStreaming: true,
    supportsVision: false,
    contextWindow: '131K',
    maxTokens: 131072,
    costPer1kTokens: 0.0,
    description: 'نظام عامل — بحث ويب وتنفيذ كود وأتمتة!',
  ),

  // ═══ BigModel (ZhipuAI) ════════════════════════════════════════════════════
  const AIModel(
    id: 'bigmodel:glm-5.1',
    provider: AIProvider.bigmodel,
    modelId: 'glm-5.1',
    name: 'GLM-5.1',
    nameAr: 'GLM-5.1',
    tier: ModelTier.free,
    speed: ModelSpeed.medium,
    quality: ModelQuality.excellent,
    supportsStreaming: false,
    supportsVision: true,
    contextWindow: '200K',
    maxTokens: 200000,
    costPer1kTokens: 0.0,
    description: 'أحدث وأقوى موديل ZhipuAI — يتنافس مع Claude Opus!',
  ),
  const AIModel(
    id: 'bigmodel:glm-5-turbo',
    provider: AIProvider.bigmodel,
    modelId: 'glm-5-turbo',
    name: 'GLM-5 Turbo',
    nameAr: 'GLM-5 تيربو',
    tier: ModelTier.free,
    speed: ModelSpeed.fast,
    quality: ModelQuality.excellent,
    supportsStreaming: false,
    supportsVision: false,
    contextWindow: '200K',
    maxTokens: 200000,
    costPer1kTokens: 0.0,
    description: 'نسخة GLM-5 الأسرع — محسّنة لسير العمل',
  ),
  const AIModel(
    id: 'bigmodel:glm-5',
    provider: AIProvider.bigmodel,
    modelId: 'glm-5',
    name: 'GLM-5',
    nameAr: 'GLM-5',
    tier: ModelTier.free,
    speed: ModelSpeed.medium,
    quality: ModelQuality.excellent,
    supportsStreaming: false,
    supportsVision: true,
    contextWindow: '200K',
    maxTokens: 200000,
    costPer1kTokens: 0.0,
    description: 'موديل الذكاء العالي — تفكير عميق وكود متقدم',
  ),
  const AIModel(
    id: 'bigmodel:glm-4.7',
    provider: AIProvider.bigmodel,
    modelId: 'glm-4.7',
    name: 'GLM-4.7',
    nameAr: 'GLM-4.7',
    tier: ModelTier.free,
    speed: ModelSpeed.medium,
    quality: ModelQuality.great,
    supportsStreaming: false,
    supportsVision: false,
    contextWindow: '200K',
    maxTokens: 200000,
    costPer1kTokens: 0.0,
    description: 'ترقية GLM-4 — أداء أقوى وأدوات أفضل',
  ),
  const AIModel(
    id: 'bigmodel:glm-4.5-air',
    provider: AIProvider.bigmodel,
    modelId: 'glm-4.5-air',
    name: 'GLM-4.5 Air',
    nameAr: 'GLM-4.5 إير',
    tier: ModelTier.free,
    speed: ModelSpeed.fast,
    quality: ModelQuality.great,
    supportsStreaming: false,
    supportsVision: false,
    contextWindow: '128K',
    maxTokens: 131072,
    costPer1kTokens: 0.0,
    description: 'سريع ومجاني — ممتاز في المنطق والكود',
  ),
  const AIModel(
    id: 'bigmodel:glm-4.6',
    provider: AIProvider.bigmodel,
    modelId: 'glm-4.6',
    name: 'GLM-4.6',
    nameAr: 'GLM-4.6',
    tier: ModelTier.free,
    speed: ModelSpeed.medium,
    quality: ModelQuality.great,
    supportsStreaming: false,
    supportsVision: false,
    contextWindow: '200K',
    maxTokens: 200000,
    costPer1kTokens: 0.0,
    description: 'موديل GLM-4.6 — أداء متوازن ومجاني',
  ),
  const AIModel(
    id: 'bigmodel:glm-4.5',
    provider: AIProvider.bigmodel,
    modelId: 'glm-4.5',
    name: 'GLM-4.5',
    nameAr: 'GLM-4.5',
    tier: ModelTier.free,
    speed: ModelSpeed.medium,
    quality: ModelQuality.great,
    supportsStreaming: false,
    supportsVision: false,
    contextWindow: '128K',
    maxTokens: 131072,
    costPer1kTokens: 0.0,
    description: 'موديل GLM-4.5 — ممتاز في المنطق والكود',
  ),

  // ═══ OpenRouter (Free Models) ══════════════════════════════════════════════
  const AIModel(
    id: 'openrouter:google/gemma-4-31b-it:free',
    provider: AIProvider.openrouter,
    modelId: 'google/gemma-4-31b-it:free',
    name: 'Gemma 4 31B',
    nameAr: 'جيما 4 31B',
    tier: ModelTier.free,
    speed: ModelSpeed.medium,
    quality: ModelQuality.excellent,
    supportsStreaming: false,
    supportsVision: true,
    contextWindow: '262K',
    maxTokens: 262144,
    costPer1kTokens: 0.0,
    description: 'أحدث موديل جوجل مفتوح المصدر — Gemma 4 مع رؤية وأدوات!',
  ),
  const AIModel(
    id: 'openrouter:google/gemma-4-12b-it:free',
    provider: AIProvider.openrouter,
    modelId: 'google/gemma-4-12b-it:free',
    name: 'Gemma 4 12B',
    nameAr: 'جيما 4 12B',
    tier: ModelTier.free,
    speed: ModelSpeed.fast,
    quality: ModelQuality.great,
    supportsStreaming: false,
    supportsVision: true,
    contextWindow: '262K',
    maxTokens: 262144,
    costPer1kTokens: 0.0,
    description: 'Gemma 4 النسخة الخفيفة — سريع ومجاني تماماً',
  ),
  const AIModel(
    id: 'openrouter:qwen/qwen3-coder:free',
    provider: AIProvider.openrouter,
    modelId: 'qwen/qwen3-coder:free',
    name: 'Qwen 3 Coder',
    nameAr: 'كوين 3 كودر',
    tier: ModelTier.free,
    speed: ModelSpeed.medium,
    quality: ModelQuality.excellent,
    supportsStreaming: false,
    supportsVision: false,
    contextWindow: '262K',
    maxTokens: 262144,
    costPer1kTokens: 0.0,
    description: 'أقوى موديل كود مجاني — 480B MoE من علي بابا',
  ),
  const AIModel(
    id: 'openrouter:deepseek/deepseek-r1:free',
    provider: AIProvider.openrouter,
    modelId: 'deepseek/deepseek-r1:free',
    name: 'DeepSeek R1',
    nameAr: 'ديبسيك R1',
    tier: ModelTier.free,
    speed: ModelSpeed.slow,
    quality: ModelQuality.excellent,
    supportsStreaming: false,
    supportsVision: false,
    contextWindow: '128K',
    maxTokens: 131072,
    costPer1kTokens: 0.0,
    description: 'موديل تفكير عميق — يحل المسائل المعقدة خطوة بخطوة',
  ),
  const AIModel(
    id: 'openrouter:deepseek/deepseek-chat-v3-0324:free',
    provider: AIProvider.openrouter,
    modelId: 'deepseek/deepseek-chat-v3-0324:free',
    name: 'DeepSeek V3',
    nameAr: 'ديبسيك V3',
    tier: ModelTier.free,
    speed: ModelSpeed.medium,
    quality: ModelQuality.excellent,
    supportsStreaming: false,
    supportsVision: false,
    contextWindow: '128K',
    maxTokens: 131072,
    costPer1kTokens: 0.0,
    description: 'أحدث نسخة DeepSeek V3 — أسرع وأذكى من R1',
  ),
  const AIModel(
    id: 'openrouter:qwen/qwen3-235b-a22b:free',
    provider: AIProvider.openrouter,
    modelId: 'qwen/qwen3-235b-a22b:free',
    name: 'Qwen 3 235B',
    nameAr: 'كوين 3 235B',
    tier: ModelTier.free,
    speed: ModelSpeed.slow,
    quality: ModelQuality.excellent,
    supportsStreaming: false,
    supportsVision: false,
    contextWindow: '128K',
    maxTokens: 131072,
    costPer1kTokens: 0.0,
    description: 'أكبر نسخة Qwen 3 — 235B MoE ممتاز بالعربية والكود',
  ),
  const AIModel(
    id: 'openrouter:nousresearch/hermes-3-llama-3.1-405b:free',
    provider: AIProvider.openrouter,
    modelId: 'nousresearch/hermes-3-llama-3.1-405b:free',
    name: 'Hermes 3 405B',
    nameAr: 'هيرمس 3 405B',
    tier: ModelTier.free,
    speed: ModelSpeed.slow,
    quality: ModelQuality.excellent,
    supportsStreaming: false,
    supportsVision: false,
    contextWindow: '131K',
    maxTokens: 131072,
    costPer1kTokens: 0.0,
    description: 'أضخم نسخة لاما — 405B مجاني مع تعليمات مخصصة',
  ),
  const AIModel(
    id: 'openrouter:qwen/qwen3-32b:free',
    provider: AIProvider.openrouter,
    modelId: 'qwen/qwen3-32b:free',
    name: 'Qwen 3 32B',
    nameAr: 'كوين 3 32B',
    tier: ModelTier.free,
    speed: ModelSpeed.medium,
    quality: ModelQuality.great,
    supportsStreaming: false,
    supportsVision: false,
    contextWindow: '128K',
    maxTokens: 131072,
    costPer1kTokens: 0.0,
    description: 'موديل علي بابا — ممتاز في العربية والمنطق',
  ),
  const AIModel(
    id: 'openrouter:mistralai/mistral-small-3.1-24b-instruct:free',
    provider: AIProvider.openrouter,
    modelId: 'mistralai/mistral-small-3.1-24b-instruct:free',
    name: 'Mistral Small 3.1',
    nameAr: 'ميسترال سمول 3.1',
    tier: ModelTier.free,
    speed: ModelSpeed.fast,
    quality: ModelQuality.great,
    supportsStreaming: false,
    supportsVision: true,
    contextWindow: '128K',
    maxTokens: 131072,
    costPer1kTokens: 0.0,
    description: 'موديل فرنسي سريع — جودة عالية مع رؤية',
  ),
  const AIModel(
    id: 'openrouter:microsoft/phi-4-reasoning:free',
    provider: AIProvider.openrouter,
    modelId: 'microsoft/phi-4-reasoning:free',
    name: 'Phi-4 Reasoning',
    nameAr: 'فاي-4 تفكير',
    tier: ModelTier.free,
    speed: ModelSpeed.medium,
    quality: ModelQuality.great,
    supportsStreaming: false,
    supportsVision: false,
    contextWindow: '128K',
    maxTokens: 131072,
    costPer1kTokens: 0.0,
    description: 'موديل مايكروسوفت — ممتاز في التفكير المنطقي',
  ),
  const AIModel(
    id: 'openrouter:nvidia/nemotron-3-super-120b-a12b:free',
    provider: AIProvider.openrouter,
    modelId: 'nvidia/nemotron-3-super-120b-a12b:free',
    name: 'Nemotron 3 Super',
    nameAr: 'نيموترون 3 سوبر',
    tier: ModelTier.free,
    speed: ModelSpeed.slow,
    quality: ModelQuality.excellent,
    supportsStreaming: false,
    supportsVision: false,
    contextWindow: '128K',
    maxTokens: 131072,
    costPer1kTokens: 0.0,
    description: 'أضخم موديل NVIDIA مجاني — 120B MoE مع أدوات',
  ),
  const AIModel(
    id: 'openrouter:inclusionai/ring-2.6-1t:free',
    provider: AIProvider.openrouter,
    modelId: 'inclusionai/ring-2.6-1t:free',
    name: 'Ring 2.6 1T',
    nameAr: 'رينج 2.6 1T',
    tier: ModelTier.free,
    speed: ModelSpeed.slow,
    quality: ModelQuality.excellent,
    supportsStreaming: false,
    supportsVision: false,
    contextWindow: '262K',
    maxTokens: 262144,
    costPer1kTokens: 0.0,
    description: 'أضخم موديل مجاني — 1 تريليون باراميتر!',
  ),
  const AIModel(
    id: 'openrouter:z-ai/glm-4.5-air:free',
    provider: AIProvider.openrouter,
    modelId: 'z-ai/glm-4.5-air:free',
    name: 'GLM-4.5 Air (OR)',
    nameAr: 'GLM-4.5 إير',
    tier: ModelTier.free,
    speed: ModelSpeed.fast,
    quality: ModelQuality.great,
    supportsStreaming: false,
    supportsVision: false,
    contextWindow: '128K',
    maxTokens: 131072,
    costPer1kTokens: 0.0,
    description: 'موديل ZhipuAI مجاني على أوبن روتر — ممتاز بالعربية',
  ),

  // ═══ Cerebras ══════════════════════════════════════════════════════════════
  const AIModel(
    id: 'cerebras:gpt-oss-120b',
    provider: AIProvider.cerebras,
    modelId: 'gpt-oss-120b',
    name: 'GPT-OSS 120B (Cerebras)',
    nameAr: 'GPT-OSS 120B سيريبراس',
    tier: ModelTier.free,
    speed: ModelSpeed.fast,
    quality: ModelQuality.excellent,
    supportsStreaming: true,
    supportsVision: false,
    contextWindow: '131K',
    maxTokens: 131072,
    costPer1kTokens: 0.0,
    description: 'أسرع موديل على Cerebras — 3000 توكن/ثانية! 120B MoE',
  ),
  const AIModel(
    id: 'cerebras:zai-glm-4.7',
    provider: AIProvider.cerebras,
    modelId: 'zai-glm-4.7',
    name: 'GLM-4.7 (Cerebras)',
    nameAr: 'GLM-4.7 سيريبراس',
    tier: ModelTier.free,
    speed: ModelSpeed.fast,
    quality: ModelQuality.excellent,
    supportsStreaming: true,
    supportsVision: false,
    contextWindow: '128K',
    maxTokens: 128000,
    costPer1kTokens: 0.0,
    description: 'موديل ZhipuAI على Cerebras — 1000 توكن/ثانية (Preview)',
  ),

  // ═══ OpenAI (Premium) ══════════════════════════════════════════════════════
  const AIModel(
    id: 'openai:gpt-4o',
    provider: AIProvider.openai,
    modelId: 'gpt-4o',
    name: 'GPT-4o',
    nameAr: 'GPT-4o',
    tier: ModelTier.pro,
    speed: ModelSpeed.medium,
    quality: ModelQuality.excellent,
    supportsStreaming: true,
    supportsVision: true,
    contextWindow: '128K',
    maxTokens: 131072,
    costPer1kTokens: 0.005,
    description: 'أقوى موديل OpenAI — للتحليلات العميقة والمهام المعقدة',
  ),
  const AIModel(
    id: 'openai:gpt-4o-mini',
    provider: AIProvider.openai,
    modelId: 'gpt-4o-mini',
    name: 'GPT-4o Mini',
    nameAr: 'GPT-4o ميني',
    tier: ModelTier.pro,
    speed: ModelSpeed.fast,
    quality: ModelQuality.excellent,
    supportsStreaming: true,
    supportsVision: true,
    contextWindow: '128K',
    maxTokens: 131072,
    costPer1kTokens: 0.00015,
    description: 'أسرع وأرخص — ممتاز للمحادثات والردود السريعة',
  ),
  const AIModel(
    id: 'openai:o4-mini',
    provider: AIProvider.openai,
    modelId: 'o4-mini',
    name: 'o4 Mini',
    nameAr: 'o4 ميني',
    tier: ModelTier.pro,
    speed: ModelSpeed.medium,
    quality: ModelQuality.excellent,
    supportsStreaming: true,
    supportsVision: false,
    contextWindow: '128K',
    maxTokens: 131072,
    costPer1kTokens: 0.003,
    description: 'موديل تفكير عميق من OpenAI — يحل المسائل خطوة بخطوة',
  ),
  const AIModel(
    id: 'openai:o3',
    provider: AIProvider.openai,
    modelId: 'o3',
    name: 'o3',
    nameAr: 'o3',
    tier: ModelTier.pro,
    speed: ModelSpeed.slow,
    quality: ModelQuality.excellent,
    supportsStreaming: true,
    supportsVision: false,
    contextWindow: '200K',
    maxTokens: 200000,
    costPer1kTokens: 0.015,
    description: 'أقوى موديل تفكير — للرياضيات والبرمجة والمنطق',
  ),
];

// ─── Helper Functions ────────────────────────────────────────────────────────

/// Find a model by its unique `id` (e.g., "gemini:gemini-3.1-flash-lite").
AIModel? findModelById(String id) {
  for (final model in allModels) {
    if (model.id == id) return model;
  }
  return null;
}

/// Get all models belonging to a specific provider.
List<AIModel> getModelsByProvider(AIProvider provider) {
  return allModels.where((m) => m.provider == provider).toList();
}

/// Get the default model for a given AI task.
AIModel? getDefaultModelForTask(AiTask task) {
  final modelId = defaultTaskModels[task];
  if (modelId == null) return null;
  return findModelById(modelId);
}

/// Resolve a fallback model when the primary is unavailable.
/// Iterates through providers in [fallbackProviderOrder] and returns the
/// first model matching the same speed/quality criteria.
AIModel? getFallbackModel(AIModel failedModel) {
  for (final providerId in fallbackProviderOrder) {
    if (providerId == failedModel.provider.name) continue;
    final provider = AIProvider.values.firstWhere(
      (p) => p.name == providerId,
      orElse: () => AIProvider.gemini,
    );
    final alternatives = getModelsByProvider(provider)
        .where((m) =>
            m.speed == failedModel.speed &&
            m.quality.qualityIndex >= failedModel.quality.qualityIndex)
        .toList();
    if (alternatives.isNotEmpty) return alternatives.first;
  }
  // Ultimate fallback: return the first free model
  return allModels.firstWhere(
    (m) => m.tier == ModelTier.free,
    orElse: () => allModels.first,
  );
}
