/// ═══════════════════════════════════════════════════════════════════════════════
/// 🏛️ OWJ Assistant — Life Pillars Model
/// ═══════════════════════════════════════════════════════════════════════════════
///
/// The five life pillars that OWJ tracks and balances:
///   1. Career (المسيرة)     — Professional growth and work
///   2. Health (الصحة)       — Physical and mental wellbeing
///   3. Productivity (الإنتاجية) — Output, focus, and efficiency
///   4. Mood (المزاج)        — Emotional state and happiness
///   5. Creativity (الإبداع) — Creative expression and ideas
///
/// Each pillar has a score (0-10), notes, and tracking metadata.
///
/// ═══════════════════════════════════════════════════════════════════════════════

library;

import 'dart:convert';

/// The five life pillars tracked by OWJ.
enum PillarType {
  career,
  health,
  productivity,
  mood,
  creativity;

  String get id {
    switch (this) {
      case PillarType.career:
        return 'career';
      case PillarType.health:
        return 'health';
      case PillarType.productivity:
        return 'productivity';
      case PillarType.mood:
        return 'mood';
      case PillarType.creativity:
        return 'creativity';
    }
  }

  /// Arabic name (Egyptian colloquial)
  String get nameAr {
    switch (this) {
      case PillarType.career:
        return 'المسيرة';
      case PillarType.health:
        return 'الصحة';
      case PillarType.productivity:
        return 'الإنتاجية';
      case PillarType.mood:
        return 'المزاج';
      case PillarType.creativity:
        return 'الإبداع';
    }
  }

  /// English name
  String get nameEn {
    switch (this) {
      case PillarType.career:
        return 'Career';
      case PillarType.health:
        return 'Health';
      case PillarType.productivity:
        return 'Productivity';
      case PillarType.mood:
        return 'Mood';
      case PillarType.creativity:
        return 'Creativity';
    }
  }

  /// Icon identifier for UI rendering
  String get icon {
    switch (this) {
      case PillarType.career:
        return '💼';
      case PillarType.health:
        return '❤️';
      case PillarType.productivity:
        return '⚡';
      case PillarType.mood:
        return '😊';
      case PillarType.creativity:
        return '🎨';
    }
  }

  /// Color as hex string (matches OwjColors pillar colors)
  String get colorHex {
    switch (this) {
      case PillarType.career:
        return '#FFB300';
      case PillarType.health:
        return '#22C55E';
      case PillarType.productivity:
        return '#3B82F6';
      case PillarType.mood:
        return '#EC4899';
      case PillarType.creativity:
        return '#8B5CF6';
    }
  }

  /// Short description in Egyptian Arabic
  String get descriptionAr {
    switch (this) {
      case PillarType.career:
        return 'شغلك وتطورك المهني';
      case PillarType.health:
        return 'صحتك الجسدية والنفسية';
      case PillarType.productivity:
        return 'تركيزك وإنتاجيتك اليومية';
      case PillarType.mood:
        return 'مزاجك وحالتك النفسية';
      case PillarType.creativity:
        return 'إبداعك وأفكارك الجديدة';
    }
  }

  /// Suggested questions the AI can ask about this pillar
  List<String> get suggestedQuestions {
    switch (this) {
      case PillarType.career:
        return [
          'إيه أهم حاجة عايز تحققها في شغلك ده الشهر؟',
          'في حاجة بتزعلك في الشغل؟',
          'عايز تتعلم مهارة جديدة؟',
        ];
      case PillarType.health:
        return [
          'بتحس بتحسن في صحتك النهارده؟',
          'نمت كويس الليلة؟',
          'عملت رياضة النهارده؟',
        ];
      case PillarType.productivity:
        return [
          'إيه أهم حاجة عملتها النهارده؟',
          'في حاجة ضيعت وقتك؟',
          'عايز تركز على إيه بكرا؟',
        ];
      case PillarType.mood:
        return [
          'مزاجك إيه النهارده؟',
          'في حاجة فرحتك النهارده؟',
          'في حاجة قلقانك؟',
        ];
      case PillarType.creativity:
        return [
          'عندك فكرة جديدة عايز تجربها؟',
          'عملت حاجة إبداعية النهارده؟',
          'عايز تتعلم حاجة فنية جديدة؟',
        ];
    }
  }
}

/// Data for a single life pillar including score and history.
class PillarData {
  /// The pillar type
  final PillarType type;

  /// Current score (0-10, can be fractional)
  final double score;

  /// User notes about this pillar
  final String notes;

  /// When the score was last updated
  final DateTime lastUpdated;

  /// Score history entries (date → score)
  final List<PillarScoreEntry> history;

  const PillarData({
    required this.type,
    this.score = 5.0,
    this.notes = '',
    required this.lastUpdated,
    this.history = const [],
  });

  /// Pillar ID (delegates to type)
  String get id => type.id;

  /// Arabic name (delegates to type)
  String get nameAr => type.nameAr;

  /// English name (delegates to type)
  String get nameEn => type.nameEn;

  /// Icon (delegates to type)
  String get icon => type.icon;

  /// Color hex (delegates to type)
  String get colorHex => type.colorHex;

  /// Whether the score is considered "good" (≥ 7)
  bool get isGood => score >= 7.0;

  /// Whether the score needs attention (≤ 4)
  bool get needsAttention => score <= 4.0;

  /// Score as a percentage (0-100)
  double get scorePercent => (score / 10.0) * 100;

  /// Score trend: positive = improving, negative = declining, 0 = stable
  double get trend {
    if (history.length < 2) return 0;
    final recent = history[history.length - 1].score;
    final previous = history[history.length - 2].score;
    return recent - previous;
  }

  /// Human-readable trend in Egyptian Arabic
  String get trendLabelAr {
    if (trend > 1) return 'متحسن 👍';
    if (trend > 0) return 'متحسن شوية';
    if (trend < -1) return 'محتاج اهتمام ⚠️';
    if (trend < 0) return 'نزل شوية';
    return 'ثابت';
  }

  PillarData copyWith({
    PillarType? type,
    double? score,
    String? notes,
    DateTime? lastUpdated,
    List<PillarScoreEntry>? history,
  }) {
    return PillarData(
      type: type ?? this.type,
      score: score ?? this.score,
      notes: notes ?? this.notes,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      history: history ?? this.history,
    );
  }

  // ─── Serialization ──────────────────────────────────────────────────────

  factory PillarData.fromJson(Map<String, dynamic> json) => PillarData(
        type: PillarType.values.firstWhere(
          (t) => t.id == json['id'],
          orElse: () => PillarType.career,
        ),
        score: (json['score'] as num?)?.toDouble() ?? 5.0,
        notes: json['notes'] as String? ?? '',
        lastUpdated: json['lastUpdated'] != null
            ? DateTime.parse(json['lastUpdated'] as String)
            : DateTime.now(),
        history: (json['history'] as List<dynamic>?)
                ?.map((e) => PillarScoreEntry.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  Map<String, dynamic> toJson() => {
        'id': type.id,
        'score': score,
        'notes': notes,
        'lastUpdated': lastUpdated.toIso8601String(),
        'history': history.map((e) => e.toJson()).toList(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PillarData && type == other.type && score == other.score;

  @override
  int get hashCode => Object.hash(type, score);

  @override
  String toString() => 'PillarData(${type.nameAr}: $score/10)';
}

/// A single score entry in a pillar's history.
class PillarScoreEntry {
  final DateTime date;
  final double score;
  final String? note;

  const PillarScoreEntry({
    required this.date,
    required this.score,
    this.note,
  });

  factory PillarScoreEntry.fromJson(Map<String, dynamic> json) => PillarScoreEntry(
        date: json['date'] != null
            ? DateTime.parse(json['date'] as String)
            : DateTime.now(),
        score: (json['score'] as num?)?.toDouble() ?? 5.0,
        note: json['note'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'score': score,
        'note': note,
      };
}

/// Default pillar data for a new user.
List<PillarData> getDefaultPillars() {
  final now = DateTime.now();
  return PillarType.values
      .map((type) => PillarData(
            type: type,
            score: 5.0,
            notes: '',
            lastUpdated: now,
          ))
      .toList();
}
