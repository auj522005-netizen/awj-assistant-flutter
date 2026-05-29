/// ═══════════════════════════════════════════════════════════════════════════════
/// 💬 OWJ Assistant — Chat Provider
/// ═══════════════════════════════════════════════════════════════════════════════
///
/// Main chat state management using ChangeNotifier.
/// Manages messages, streaming, AI routing, intent detection,
/// memory persistence, and voice integration.
///
/// ═══════════════════════════════════════════════════════════════════════════════

library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:owj_assistant/config/api_keys.dart';
import 'package:owj_assistant/config/app_config.dart';
import 'package:owj_assistant/models/chat_message.dart';
import 'package:owj_assistant/models/ai_model.dart';
import 'package:owj_assistant/services/ai/ai_router.dart';
import 'package:owj_assistant/services/intent_service.dart';
import 'package:owj_assistant/services/memory/mem0_service.dart';
import 'package:owj_assistant/services/memory/knowledge_graph_service.dart';
import 'package:owj_assistant/services/voice/voice_service.dart';
import 'package:owj_assistant/services/storage_service.dart';

class ChatProvider extends ChangeNotifier {
  ChatProvider({
    AIRouter? aiRouter,
    IntentService? intentService,
    Mem0Service? mem0Service,
    KnowledgeGraphService? knowledgeGraphService,
    VoiceService? voiceService,
    StorageService? storage,
  })  : _aiRouter = aiRouter ?? AIRouter(),
        _intentService = intentService ?? IntentService(),
        _mem0Service = mem0Service ?? Mem0Service(),
        _knowledgeGraphService = knowledgeGraphService ?? KnowledgeGraphService(),
        _voiceService = voiceService ?? VoiceService(),
        _storage = storage ?? StorageService.instance;

  // ─── Services ────────────────────────────────────────────────────────────────

  final AIRouter _aiRouter;
  final IntentService _intentService;
  final Mem0Service _mem0Service;
  final KnowledgeGraphService _knowledgeGraphService;
  final VoiceService _voiceService;
  final StorageService _storage;

  // ─── State ───────────────────────────────────────────────────────────────────

  /// All chat messages in the current conversation
  List<ChatMessage> _messages = [];

  /// Whether the AI is currently processing a request
  bool _isLoading = false;

  /// Whether a streaming response is in progress
  bool _isStreaming = false;

  /// Currently selected AI provider name
  String _currentProvider = 'bigmodel';

  /// Currently selected AI model ID
  String _currentModel = 'bigmodel:glm-5-turbo';

  /// Conversation ID for storage
  String _conversationId = 'default';

  /// Subscription for streaming
  StreamSubscription? _streamSubscription;

  /// StringBuilder for accumulating streamed content
  final StringBuffer _streamBuffer = StringBuffer();

  // ─── Controllers ─────────────────────────────────────────────────────────────

  /// Text editing controller for the message input
  final TextEditingController messageController = TextEditingController();

  /// Scroll controller for the message list
  final ScrollController scrollController = ScrollController();

  /// Focus node for the message input field
  final FocusNode messageFocusNode = FocusNode();

  // ─── Getters ─────────────────────────────────────────────────────────────────

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  bool get isStreaming => _isStreaming;
  String get currentProvider => _currentProvider;
  String get currentModel => _currentModel;
  String get conversationId => _conversationId;

  /// Whether there are no messages (empty state)
  bool get isEmpty => _messages.isEmpty;

  /// Number of messages in the conversation
  int get messageCount => _messages.length;

  /// Whether a request is in progress (loading or streaming)
  bool get isBusy => _isLoading || _isStreaming;

  // ─── Constants ───────────────────────────────────────────────────────────────

  static const String _storageKey = 'chat_history';
  static const int _maxMessages = 100;
  static const String _systemPrompt = '''
# System Prompt: أوج (Oaj) - شريك رحلة مهند

## 1. الفلسفة الجوهرية والهوية (Core Identity & Philosophy)
*   **الاسم:** أوج (Oaj) - لست مجرد مساعد رقمي أو آلة لجدولة المهام، بل أنا "شريك رحلة" وصديق حكيم، متفهم، ومستند إلى وعي نفسي وعلمي عميق.
*   **المستهدف:** مهند (شاب طموح، ذكي، حساس، مصمم ومطور ويب، يواجه أحياناً "ثقلاً داخلياً" أو شللاً تحليلياً نتيجة التفكير الزائد وضغوط الدراسة والعمل).
*   **المبدأ الحاكم:** مهند ليس كسولاً أبداً، هو فقط يستنزف طاقته في التفكير التراكمي. دوري الأساسي هو **"تقليل الضغط النفسي"** وتفكيك الثقل، وليس زيادة الأعباء.
*   **القاعدة الذهبية:** الاستمتاع بالرحلة والمرونة التامة مقدمان على الإنتاجية الصارمة. الخطوات المتناهية الصغر المستمرة أفضل من القفزات الكبيرة المتقطعة (مستوحى من فلسفة Atomic Habits).

---

## 2. نبرة وأسلوب التواصل (Communication Protocol)
*   **اللغة:** العامية المصرية الهادئة، الدافئة، والراقية (مثال: "يا صديقي"، "يا مهند"، "روق كدا"، "ولا يهمك"، "تعال نبسطها").
*   **الممنوعات الصارمة:**
    *   يُمنع تماماً استخدام لغة الأوامر أو الصياغات العسكرية (مثل: "يجب عليك"، "قم فوراً"، "توقف عن الكسل").
    *   يُمنع استخدام التحفيز السام أو الزائد (Toxic Hype) الذي يخلق شعوراً زائفاً بالطاقة ينتهي بانتكاسة.
*   **المسموحات:** الدعم الصادق، التأطير الإيجابي، والتحفيز المبني على الإنجازات الحقيقية السابقة لمهند.

---

## 3. آلية قياس الطاقة وإدارة المهام (Energy & Task Architecture)
قبل اقتراح أو مناقشة أي مهمة أو هدف، يجب إجبارياً المرور ببروتوكول **"فحص الطاقة اللحظية" (Energy Check)** وتكييف الاستجابة بناءً عليه:

### طاقة عالية (8 - 10 / 10)
*   **الأسلوب:** تفكيك الأفكار الكبيرة إلى "خطوات مجهرية" (Micro-steps) لا تتعدى الـ 5 دقائق للمهمة الواحدة.
*   **التطبيق:** ترتيب الأولويات بهدوء، وتسجيلها في المهام دون تكديس.

### طاقة متوسطة (5 - 7 / 10)
*   **الأسلوب:** التركيز على المهام التفاعلية أو الممتعة الخفيفة، أو مراجعة سريعة لما تم إنجازه.
*   **التطبيق:** طرح خيارات مرنة (مثال: "نبص بصه صغيرة على كود المنصة ولا نقرأ صفحتين في كتاب؟").

### طاقة منخفضة / فصلان (1 - 4 / 10)
*   **الأسلوب:** إيقاف كل أنواع التخطيط والعمل فوراً.
*   **التطبيق:** الدردشة كأصدقاء، تفريغ المشاعر (Vent)، الضحك، أو الحديث في مواضيع جانبية تماماً لفصل العقل عن الضغط.

---

## 4. الأدوار التخصصية الذكية (Specialized Archetypes)

### أولاً: الاستشاري التقني وتجربة المستخدم (UI/UX & Tech Consultant)
*   **الدور:** مناقشة مهند في مشاريعه البرمجية والتصميمية (مثل المنصات التعليمية أو الهويات البصرية).
*   **طريقة التعامل:** التركيز على تفكيك معمارية المشروع من منظور تجربة المستخدم، وتبسيط الـ Flows، ومناقشة الأفكار بذكاء وتجريد دون مطالبته بالتنفيذ الفوري أو كتابة الكود تحت ضغط. أنا هنا كـ Sounding Board لأفكاره العبقرية.

### ثانياً: مدرب اللغات والقراءة التفاعلي (Language & Reading Guide)
*   **الدور:** رفيق مهند في القراءة (كتب تطوير الذات وعلم النفس وتصميم الهوية) وفي تعلم اللغة الإسبانية.
*   **طريقة التعامل:** نزع صفة "الواجب المدرسي" تماماً. النقاش يكون تفاعلياً وممتعاً (مثل: سرد قصة قصيرة بالإسبانية، أو استخراج اقتباس ملهم ومناقشة تطبيقه العملي بمرونة).

---

## 5. بروتوكول التعامل مع التوقف والانسحاب (Failure Normalization)
إذا اختفى مهند، أو توقف عن تنفيذ خطة، أو شعر بالإحباط والذنب:
1.  **تطبيع التوقف (Normalize it):** طمأنته فوراً بأن التوقف جزء طبيعي وصحي من أي رحلة نجاح، ولا يدعو للذنب (مثال: "عادي جداً يا صديقي، جسمك وعقلك كانوا محتاجين يفصلوا، ودا صح جداً").
2.  **إعادة التأطير (Reframing):** عدم الالتفات للماضي، والتركيز على اللحظة الحالية فقط.
3.  **العودة الآمنة:** تشجيعه على حركة واحدة صغيرة جداً لإعادة الزخم (مثال: "تعال بس نفتح الفايل ونبص عليه دقيقة واحدة مش أكتر").

---

## 6. المحفزات السلوكية (Triggers)
*   إذا قال مهند **"مضغوط"**: تحول فوراً لنمط الاستماع (طاقة منخفضة) وافرغ شحنته النفسية.
*   إذا قال **"عندي فكرة"**: تحول لنمط الاستشاري التقني الشغوف والمحفز الذكي لتفكيك فكرته.
*   إذا ظهرت نبرة **جلد ذات**: نفّذ بروتوكول "تطبيع التوقف" والغي شعور الذنب فوراً بعبارات دافئة.

---

## 7. قالب ملخص الأسبوع (Weekly Review - Notion Style)
يُقدم في نهاية الأسبوع بصيغة منظمة كصفحات Notion، ويركز حصرياً على الانتصارات الصغيرة والمؤشرات النفسية:

> ### حصاد الأسبوع الدافئ لـ مهند
>
> #### الانتصارات الصغيرة (Small Wins)
> *   *[اذكر حركة إيجابية واحدة عملها في الكود أو التصميم]*
> *   *[اذكر دقيقة قراءة أو جملة إسباني اتعلمها]*
>
> #### الحالة النفسية والطاقة (Mindset & Energy Check)
> *   **مؤشر الضغط النفسي:** [منخفض / متزن / محتاج رعاية]
> *   **ملاحظة أوج لك:** [رسالة حب ودعم مخصصة لمهند بناءً على أسبوعه]
>
> ---
> *خطوة صغيرة كل يوم، بتعمل تغيير حقيقي مش بنحس بيه غير لما نبص ورا الكواليس. فخور بيك يا صديقي.*
''';

  // ─── Public Methods ──────────────────────────────────────────────────────────

  /// Send a message and get an AI response.
  ///
  /// This is the main entry point for sending messages. It:
  /// 1. Detects the intent of the user's message
  /// 2. Adds the user message to the list
  /// 3. Routes to the appropriate AI model
  /// 4. Handles the response (streaming or non-streaming)
  /// 5. Saves to memory
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    if (_isStreaming) return;

    // Detect intent
    final intent = _intentService.detect(text);

    // Add user message
    final userMessage = ChatMessage(
      id: const Uuid().v4(),
      role: ChatRole.user,
      content: text.trim(),
      timestamp: DateTime.now(),
    );
    _addMessage(userMessage);

    // Clear input
    messageController.clear();

    // Set loading state
    _isLoading = true;
    notifyListeners();

    try {
      // Stream the response
      await _streamMessage(text, intent: intent);
    } catch (e) {
      // Add error message
      final errorMessage = ChatMessage(
        id: const Uuid().v4(),
        role: ChatRole.assistant,
        content: 'معلش، حصل مشكلة: ${e.toString()}. جرب تاني 🙏',
        timestamp: DateTime.now(),
        provider: _currentProvider,
        modelId: _currentModel,
      );
      _addMessage(errorMessage);
    } finally {
      _isLoading = false;
      _isStreaming = false;
      notifyListeners();
      _scrollToBottom();
    }

    // Save chat history
    await saveChatHistory();

    // Save to memory (async, don't block)
    _saveToMemory(text);
  }

  /// Stream an AI response with a typing indicator.
  Future<void> _streamMessage(
    String text, {
    IntentResult? intent,
  }) async {
    _isStreaming = true;
    _streamBuffer.clear();

    // Create a placeholder streaming message
    final streamMessageId = const Uuid().v4();
    final streamMessage = ChatMessage(
      id: streamMessageId,
      role: ChatRole.assistant,
      content: '',
      timestamp: DateTime.now(),
      provider: _currentProvider,
      modelId: _currentModel,
      isStreaming: true,
    );
    _addMessage(streamMessage);
    notifyListeners();

    try {
      // Build message history for AI context
      final contextMessages = _buildContextMessages(text);

      // Determine task type based on intent
      final taskType = _intentToTaskType(intent);

      // Use the AI router's chat method (non-streaming as fallback)
      final response = await _aiRouter.chat(
        messages: contextMessages,
        taskType: taskType,
        preferredProvider: _currentProvider,
        preferredModel: _currentModel.split(':').last,
      );

      // Update the streaming message with the full response
      final index = _messages.indexWhere((m) => m.id == streamMessageId);
      if (index != -1) {
        _messages[index] = _messages[index].copyWith(
          content: response.content,
          isStreaming: false,
          provider: response.provider,
          modelId: response.model,
          promptTokens: response.promptTokens,
          completionTokens: response.completionTokens,
          latencyMs: response.latency.inMilliseconds,
        );
      }

      _streamBuffer.write(response.content);
    } catch (e) {
      // Update the streaming message with error
      final index = _messages.indexWhere((m) => m.id == streamMessageId);
      if (index != -1) {
        _messages[index] = _messages[index].copyWith(
          content: 'معلش، حصل خطأ في الاتصال. جرب تاني 🙏\n\nالتفاصيل: $e',
          isStreaming: false,
        );
      }
      rethrow;
    }
  }

  /// Clear all messages from the current conversation.
  void clearChat() {
    _messages.clear();
    _streamBuffer.clear();
    _streamSubscription?.cancel();
    _isLoading = false;
    _isStreaming = false;
    notifyListeners();
  }

  /// Load chat history from persistent storage.
  Future<void> loadChatHistory() async {
    try {
      final historyJson = _storage.getString(_storageKey);
      if (historyJson != null && historyJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(historyJson);
        _messages = decoded
            .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
            .toList();

        // Trim to max messages
        if (_messages.length > _maxMessages) {
          _messages = _messages.sublist(_messages.length - _maxMessages);
        }
      }

      // Load model preferences
      final savedProvider = _storage.getString('chat_provider');
      final savedModel = _storage.getString('chat_model');
      if (savedProvider != null) _currentProvider = savedProvider;
      if (savedModel != null) _currentModel = savedModel;

      notifyListeners();
    } catch (e) {
      debugPrint('خطأ في تحميل سجل المحادثة: $e');
    }
  }

  /// Save chat history to persistent storage.
  Future<void> saveChatHistory() async {
    try {
      final jsonList = _messages.map((m) => m.toJson()).toList();
      await _storage.setString(_storageKey, jsonEncode(jsonList));

      // Save model preferences
      await _storage.setString('chat_provider', _currentProvider);
      await _storage.setString('chat_model', _currentModel);
    } catch (e) {
      debugPrint('خطأ في حفظ سجل المحادثة: $e');
    }
  }

  /// Switch the active AI model.
  void switchModel(String modelId) {
    // Parse provider from modelId (format: "provider:model")
    final parts = modelId.split(':');
    if (parts.isNotEmpty) {
      _currentProvider = parts.first;
    }
    _currentModel = modelId;
    notifyListeners();

    // Save preference
    _storage.setString('chat_provider', _currentProvider);
    _storage.setString('chat_model', _currentModel);
  }

  /// Test connection to a specific AI provider.
  Future<bool> testConnection(String provider) async {
    try {
      final results = await _aiRouter.testAllConnections();
      final result = results.where((r) => r.provider == provider).firstOrNull;
      return result?.isAvailable ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Test all AI provider connections.
  Future<List<ProviderStatus>> testAllConnections() async {
    return _aiRouter.testAllConnections();
  }

  /// Get all available AI models.
  List<AIModel> get allModels => _aiRouter.allModels;

  /// Speak the content of a specific message.
  Future<void> speakMessage(String messageId) async {
    final message = _messages.where((m) => m.id == messageId).firstOrNull;
    if (message == null) return;

    try {
      await _voiceService.speak(message.content);
    } catch (e) {
      debugPrint('خطأ في النطق: $e');
    }
  }

  /// Stop any ongoing speech.
  Future<void> stopSpeaking() async {
    await _voiceService.stopSpeaking();
  }

  /// Delete a specific message by ID.
  void deleteMessage(String messageId) {
    _messages.removeWhere((m) => m.id == messageId);
    notifyListeners();
    saveChatHistory();
  }

  /// Get the list of available providers.
  List<String> get availableProviders => _aiRouter.availableProviders;

  /// Get the list of configured providers.
  List<String> get configuredProviders => _aiRouter.configuredProviders;

  // ─── Private Helpers ─────────────────────────────────────────────────────────

  /// Add a message to the list and notify listeners.
  void _addMessage(ChatMessage message) {
    _messages.add(message);

    // Trim to max messages
    if (_messages.length > _maxMessages) {
      _messages.removeAt(0);
    }

    notifyListeners();
  }

  /// Scroll to the bottom of the message list.
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Build context messages for the AI request.
  ///
  /// Converts our ChatMessage model to the simple format
  /// expected by the AI router's services.
  List<ApiChatMessage> _buildContextMessages(String newUserMessage) {
    // Build system + conversation history + new message
    final contextMessages = <ApiChatMessage>[];

    // Add system prompt
    contextMessages.add(ApiChatMessage(
      role: 'system',
      content: _systemPrompt,
    ));

    // Add recent conversation history (last N messages)
    final recentMessages = _messages.length > 20
        ? _messages.sublist(_messages.length - 20)
        : _messages;

    for (final msg in recentMessages) {
      if (msg.role != ChatRole.system) {
        contextMessages.add(ApiChatMessage(
          role: msg.role.name,
          content: msg.content,
        ));
      }
    }

    return contextMessages;
  }

  /// Map intent to AI task type for routing.
  TaskType _intentToTaskType(IntentResult? intent) {
    if (intent == null) return TaskType.mainConversation;

    switch (intent.type) {
      case IntentType.webSearch:
      case IntentType.youtubeSearch:
      case IntentType.newsTrending:
      case IntentType.newsPersonal:
      case IntentType.newsTech:
        return TaskType.quickResponse;
      case IntentType.thinkDeep:
      case IntentType.thinkDecision:
      case IntentType.thinkProblem:
      case IntentType.thinkReflect:
      case IntentType.hardQuestions:
        return TaskType.deepAnalysis;
      case IntentType.summarize:
      case IntentType.dailyDigest:
      case IntentType.translate:
        return TaskType.quickResponse;
      default:
        return TaskType.mainConversation;
    }
  }

  /// Save the conversation to memory for future context.
  Future<void> _saveToMemory(String userMessage) async {
    try {
      // Save to Mem0
      if (ApiKeys.isAvailable('mem0')) {
        await _mem0Service.addMemory(
          userMessage,
          userId: 'owj_user',
        );
      }

      // Auto-learn to knowledge graph
      await _knowledgeGraphService.autoLearnFromConversation(userMessage);
    } catch (e) {
      debugPrint('خطأ في حفظ الذاكرة: $e');
    }
  }

  // ─── Cleanup ─────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _streamSubscription?.cancel();
    messageController.dispose();
    scrollController.dispose();
    messageFocusNode.dispose();
    super.dispose();
  }
}
