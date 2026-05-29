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
  String _currentProvider = 'gemini';

  /// Currently selected AI model ID
  String _currentModel = 'gemini:gemini-2.5-flash';

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
أنت أوج (OWJ)، المساعد الذكي المصري. بتتكلم بالمصري بطريقة طبيعية وودودة.
بتحب تساعد الناس وبتكون صبور ومتفهم. دايماً بتحاول تقدم حلول عملية وبسيطة.
ممكن تتكلم إنجليزي لو المستخدم بيكلمني إنجليزي.
استخدم المعلومات اللي عندك عن المستخدم عشان تقدم ردود مخصصة.
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
