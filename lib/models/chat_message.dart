/// ═══════════════════════════════════════════════════════════════════════════════
/// 💬 OWJ Assistant — Chat Message Model
/// ═══════════════════════════════════════════════════════════════════════════════
///
/// Represents a single message in the chat conversation.
/// Supports user, assistant, and system roles with rich metadata
/// including provider info, pillar tracking, YouTube results, and action results.
///
/// ═══════════════════════════════════════════════════════════════════════════════

library;

import 'dart:convert';

/// The role of a chat message participant.
enum ChatRole {
  user,
  assistant,
  system;

  String get nameAr {
    switch (this) {
      case ChatRole.user:
        return 'أنت';
      case ChatRole.assistant:
        return 'أوج';
      case ChatRole.system:
        return 'النظام';
    }
  }
}

/// A YouTube search result embedded in a chat message.
class YouTubeResult {
  final String videoId;
  final String title;
  final String channelName;
  final String thumbnailUrl;
  final String? duration;
  final String? publishedAt;

  const YouTubeResult({
    required this.videoId,
    required this.title,
    required this.channelName,
    required this.thumbnailUrl,
    this.duration,
    this.publishedAt,
  });

  /// YouTube watch URL
  String get url => 'https://www.youtube.com/watch?v=$videoId';

  factory YouTubeResult.fromJson(Map<String, dynamic> json) => YouTubeResult(
        videoId: json['videoId'] as String? ?? '',
        title: json['title'] as String? ?? '',
        channelName: json['channelName'] as String? ?? '',
        thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
        duration: json['duration'] as String?,
        publishedAt: json['publishedAt'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'videoId': videoId,
        'title': title,
        'channelName': channelName,
        'thumbnailUrl': thumbnailUrl,
        'duration': duration,
        'publishedAt': publishedAt,
      };
}

/// An action result from a tool/skill invocation (e.g., web search, file op).
class ActionResult {
  final String actionType;
  final bool success;
  final String? data;
  final String? error;

  const ActionResult({
    required this.actionType,
    required this.success,
    this.data,
    this.error,
  });

  factory ActionResult.fromJson(Map<String, dynamic> json) => ActionResult(
        actionType: json['actionType'] as String? ?? '',
        success: json['success'] as bool? ?? false,
        data: json['data'] as String?,
        error: json['error'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'actionType': actionType,
        'success': success,
        'data': data,
        'error': error,
      };
}

/// A single chat message in the conversation.
class ChatMessage {
  /// Unique identifier
  final String id;

  /// Who sent this message (user, assistant, system)
  final ChatRole role;

  /// The text content of the message
  final String content;

  /// When the message was created
  final DateTime timestamp;

  /// The AI provider that generated this response (e.g., "gemini", "groq")
  final String? provider;

  /// The model ID used for this response (e.g., "gemini-3.1-flash-lite")
  final String? modelId;

  /// Which life pillar this message relates to (if any)
  final String? pillar;

  /// YouTube search results embedded in the message
  final List<YouTubeResult> youtubeResults;

  /// Action/tool results from skill invocations
  final List<ActionResult> actionResults;

  /// Whether the message is currently being streamed (partial)
  final bool isStreaming;

  /// Optional: Token usage for this response
  final int? promptTokens;
  final int? completionTokens;

  /// Optional: Response latency in milliseconds
  final int? latencyMs;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.provider,
    this.modelId,
    this.pillar,
    this.youtubeResults = const [],
    this.actionResults = const [],
    this.isStreaming = false,
    this.promptTokens,
    this.completionTokens,
    this.latencyMs,
  });

  /// Create a copy with updated fields (useful for streaming updates)
  ChatMessage copyWith({
    String? id,
    ChatRole? role,
    String? content,
    DateTime? timestamp,
    String? provider,
    String? modelId,
    String? pillar,
    List<YouTubeResult>? youtubeResults,
    List<ActionResult>? actionResults,
    bool? isStreaming,
    int? promptTokens,
    int? completionTokens,
    int? latencyMs,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      provider: provider ?? this.provider,
      modelId: modelId ?? this.modelId,
      pillar: pillar ?? this.pillar,
      youtubeResults: youtubeResults ?? this.youtubeResults,
      actionResults: actionResults ?? this.actionResults,
      isStreaming: isStreaming ?? this.isStreaming,
      promptTokens: promptTokens ?? this.promptTokens,
      completionTokens: completionTokens ?? this.completionTokens,
      latencyMs: latencyMs ?? this.latencyMs,
    );
  }

  /// Total tokens used (if available)
  int? get totalTokens {
    if (promptTokens != null && completionTokens != null) {
      return promptTokens! + completionTokens!;
    }
    return null;
  }

  /// Whether this message has YouTube results
  bool get hasYouTubeResults => youtubeResults.isNotEmpty;

  /// Whether this message has action results
  bool get hasActionResults => actionResults.isNotEmpty;

  // ─── Serialization ──────────────────────────────────────────────────────

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String? ?? '',
        role: ChatRole.values.firstWhere(
          (r) => r.name == json['role'],
          orElse: () => ChatRole.user,
        ),
        content: json['content'] as String? ?? '',
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'] as String)
            : DateTime.now(),
        provider: json['provider'] as String?,
        modelId: json['modelId'] as String?,
        pillar: json['pillar'] as String?,
        youtubeResults: (json['youtubeResults'] as List<dynamic>?)
                ?.map((e) => YouTubeResult.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        actionResults: (json['actionResults'] as List<dynamic>?)
                ?.map((e) => ActionResult.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        isStreaming: json['isStreaming'] as bool? ?? false,
        promptTokens: json['promptTokens'] as int?,
        completionTokens: json['completionTokens'] as int?,
        latencyMs: json['latencyMs'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.name,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        'provider': provider,
        'modelId': modelId,
        'pillar': pillar,
        'youtubeResults': youtubeResults.map((e) => e.toJson()).toList(),
        'actionResults': actionResults.map((e) => e.toJson()).toList(),
        'isStreaming': isStreaming,
        'promptTokens': promptTokens,
        'completionTokens': completionTokens,
        'latencyMs': latencyMs,
      };

  /// Serialize to JSON string
  String toJsonString() => jsonEncode(toJson());

  /// Deserialize from JSON string
  factory ChatMessage.fromJsonString(String source) =>
      ChatMessage.fromJson(jsonDecode(source) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMessage && id == other.id && content == other.content;

  @override
  int get hashCode => Object.hash(id, content);

  @override
  String toString() => 'ChatMessage(id: $id, role: ${role.name}, '
      'content: ${content.length > 50 ? '${content.substring(0, 50)}...' : content}, '
      'provider: $provider, isStreaming: $isStreaming)';
}
