/// ═══════════════════════════════════════════════════════════════════════════════
/// 📔 OWJ Assistant — Journal Entry Model
/// ═══════════════════════════════════════════════════════════════════════════════
///
/// Daily journal entry model with AI-powered analysis.
/// Users can write reflections and receive automated insights about
/// their mood, productivity, and life pillar alignment.
///
/// ═══════════════════════════════════════════════════════════════════════════════

library;

import 'dart:convert';

// ─── Mood Enum ────────────────────────────────────────────────────────────────

/// Detected or user-selected mood for a journal entry.
enum JournalMood {
  great,
  good,
  okay,
  low,
  bad;

  /// Arabic label (Egyptian colloquial)
  String get labelAr {
    switch (this) {
      case JournalMood.great:
        return 'ممتاز';
      case JournalMood.good:
        return 'كويس';
      case JournalMood.okay:
        return 'عادي';
      case JournalMood.low:
        return 'وحش شوية';
      case JournalMood.bad:
        return 'وحش';
    }
  }

  /// English label
  String get labelEn {
    switch (this) {
      case JournalMood.great:
        return 'Great';
      case JournalMood.good:
        return 'Good';
      case JournalMood.okay:
        return 'Okay';
      case JournalMood.low:
        return 'Low';
      case JournalMood.bad:
        return 'Bad';
    }
  }

  /// Emoji representation
  String get emoji {
    switch (this) {
      case JournalMood.great:
        return '😄';
      case JournalMood.good:
        return '🙂';
      case JournalMood.okay:
        return '😐';
      case JournalMood.low:
        return '😔';
      case JournalMood.bad:
        return '😢';
    }
  }

  /// Numeric value for calculations (5=best, 1=worst)
  int get value {
    switch (this) {
      case JournalMood.great:
        return 5;
      case JournalMood.good:
        return 4;
      case JournalMood.okay:
        return 3;
      case JournalMood.low:
        return 2;
      case JournalMood.bad:
        return 1;
    }
  }

  /// Color hex for UI display
  String get colorHex {
    switch (this) {
      case JournalMood.great:
        return '#22C55E';
      case JournalMood.good:
        return '#86EFAC';
      case JournalMood.okay:
        return '#FDE68A';
      case JournalMood.low:
        return '#FCA5A5';
      case JournalMood.bad:
        return '#EF4444';
    }
  }

  /// Create from numeric value (1-5)
  static JournalMood fromValue(int value) {
    return JournalMood.values.firstWhere(
      (m) => m.value == value,
      orElse: () => JournalMood.okay,
    );
  }
}

// ─── Journal Analysis ────────────────────────────────────────────────────────

/// AI-generated analysis of a journal entry.
class JournalAnalysis {
  /// Detected mood
  final JournalMood? detectedMood;

  /// AI-generated summary in Arabic
  final String? summary;

  /// Key themes identified (Arabic)
  final List<String> themes;

  /// Affected pillars (pillar IDs)
  final List<String> affectedPillars;

  /// AI suggestions in Arabic
  final List<String> suggestions;

  /// Sentiment score (-1.0 to 1.0)
  final double sentimentScore;

  /// Key phrases extracted
  final List<String> keyPhrases;

  /// Which model performed the analysis
  final String? analysisModel;

  const JournalAnalysis({
    this.detectedMood,
    this.summary,
    this.themes = const [],
    this.affectedPillars = const [],
    this.suggestions = const [],
    this.sentimentScore = 0.0,
    this.keyPhrases = const [],
    this.analysisModel,
  });

  /// Whether this entry has a positive sentiment
  bool get isPositive => sentimentScore > 0.2;

  /// Whether this entry has a negative sentiment
  bool get isNegative => sentimentScore < -0.2;

  /// Whether the analysis is empty (not yet generated)
  bool get isEmpty =>
      summary == null && themes.isEmpty && suggestions.isEmpty;

  JournalAnalysis copyWith({
    JournalMood? detectedMood,
    String? summary,
    List<String>? themes,
    List<String>? affectedPillars,
    List<String>? suggestions,
    double? sentimentScore,
    List<String>? keyPhrases,
    String? analysisModel,
  }) {
    return JournalAnalysis(
      detectedMood: detectedMood ?? this.detectedMood,
      summary: summary ?? this.summary,
      themes: themes ?? this.themes,
      affectedPillars: affectedPillars ?? this.affectedPillars,
      suggestions: suggestions ?? this.suggestions,
      sentimentScore: sentimentScore ?? this.sentimentScore,
      keyPhrases: keyPhrases ?? this.keyPhrases,
      analysisModel: analysisModel ?? this.analysisModel,
    );
  }

  // ─── Serialization ──────────────────────────────────────────────────────

  factory JournalAnalysis.fromJson(Map<String, dynamic> json) =>
      JournalAnalysis(
        detectedMood: json['detectedMood'] != null
            ? JournalMood.values.firstWhere(
                (m) => m.name == json['detectedMood'],
                orElse: () => JournalMood.okay,
              )
            : null,
        summary: json['summary'] as String?,
        themes: (json['themes'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        affectedPillars: (json['affectedPillars'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        suggestions: (json['suggestions'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        sentimentScore: (json['sentimentScore'] as num?)?.toDouble() ?? 0.0,
        keyPhrases: (json['keyPhrases'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        analysisModel: json['analysisModel'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'detectedMood': detectedMood?.name,
        'summary': summary,
        'themes': themes,
        'affectedPillars': affectedPillars,
        'suggestions': suggestions,
        'sentimentScore': sentimentScore,
        'keyPhrases': keyPhrases,
        'analysisModel': analysisModel,
      };

  @override
  String toString() => 'JournalAnalysis(mood: ${detectedMood?.labelAr}, '
      'sentiment: $sentimentScore, themes: ${themes.length})';
}

// ─── Journal Entry ───────────────────────────────────────────────────────────

/// A daily journal entry with optional AI analysis.
class JournalEntry {
  /// Unique identifier
  final String id;

  /// Date of this journal entry (may differ from creation date)
  final DateTime date;

  /// The journal content (user's reflection text)
  final String content;

  /// AI-generated analysis (may be null if not yet analyzed)
  final JournalAnalysis? analysis;

  /// User-selected mood (optional, may differ from AI-detected)
  final JournalMood? userMood;

  /// When this entry was created
  final DateTime createdAt;

  /// When this entry was last edited
  final DateTime? updatedAt;

  /// Optional: Tags/categories
  final List<String> tags;

  /// Optional: Associated pillar IDs
  final List<String> pillarIds;

  /// Optional: Word count
  final int? wordCount;

  /// Optional: Whether this entry has been shared/exported
  final bool isShared;

  const JournalEntry({
    required this.id,
    required this.date,
    required this.content,
    this.analysis,
    this.userMood,
    required this.createdAt,
    this.updatedAt,
    this.tags = const [],
    this.pillarIds = const [],
    this.wordCount,
    this.isShared = false,
  });

  /// Effective mood (user-selected takes priority over AI-detected)
  JournalMood? get effectiveMood => userMood ?? analysis?.detectedMood;

  /// Whether this entry has been analyzed by AI
  bool get isAnalyzed => analysis != null && !analysis!.isEmpty;

  /// Whether this entry has been edited
  bool get isEdited => updatedAt != null;

  /// Content length in characters
  int get charCount => content.length;

  /// Calculate word count from content
  int get calculatedWordCount {
    if (content.isEmpty) return 0;
    return content.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }

  /// Date as YYYY-MM-DD key
  String get dateKey =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// Human-readable date in Egyptian Arabic
  String get dateLabelAr {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final entryDate = DateTime(date.year, date.month, date.day);

    if (entryDate == today) return 'النهارده';
    if (entryDate == today.subtract(const Duration(days: 1))) return 'امبارح';
    return '${date.day}/${date.month}/${date.year}';
  }

  /// Short preview of content (first 100 characters)
  String get preview {
    if (content.length <= 100) return content;
    return '${content.substring(0, 100)}...';
  }

  JournalEntry copyWith({
    String? id,
    DateTime? date,
    String? content,
    JournalAnalysis? analysis,
    JournalMood? userMood,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? tags,
    List<String>? pillarIds,
    int? wordCount,
    bool? isShared,
  }) {
    return JournalEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      content: content ?? this.content,
      analysis: analysis ?? this.analysis,
      userMood: userMood ?? this.userMood,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tags: tags ?? this.tags,
      pillarIds: pillarIds ?? this.pillarIds,
      wordCount: wordCount ?? this.wordCount,
      isShared: isShared ?? this.isShared,
    );
  }

  // ─── Serialization ──────────────────────────────────────────────────────

  factory JournalEntry.fromJson(Map<String, dynamic> json) => JournalEntry(
        id: json['id'] as String? ?? '',
        date: json['date'] != null
            ? DateTime.parse(json['date'] as String)
            : DateTime.now(),
        content: json['content'] as String? ?? '',
        analysis: json['analysis'] != null
            ? JournalAnalysis.fromJson(json['analysis'] as Map<String, dynamic>)
            : null,
        userMood: json['userMood'] != null
            ? JournalMood.values.firstWhere(
                (m) => m.name == json['userMood'],
                orElse: () => JournalMood.okay,
              )
            : null,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'] as String)
            : null,
        tags: (json['tags'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        pillarIds: (json['pillarIds'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        wordCount: json['wordCount'] as int?,
        isShared: json['isShared'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'content': content,
        'analysis': analysis?.toJson(),
        'userMood': userMood?.name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        'tags': tags,
        'pillarIds': pillarIds,
        'wordCount': wordCount,
        'isShared': isShared,
      };

  factory JournalEntry.fromJsonString(String source) =>
      JournalEntry.fromJson(jsonDecode(source) as Map<String, dynamic>);

  String toJsonString() => jsonEncode(toJson());

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is JournalEntry && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'JournalEntry(id: $id, date: $dateKey, '
      'mood: ${effectiveMood?.labelAr ?? "N/A"}, '
      'chars: $charCount, analyzed: $isAnalyzed)';
}
