/// ═══════════════════════════════════════════════════════════════════════════════
/// 🏆 OWJ Assistant — Achievement Model
/// ═══════════════════════════════════════════════════════════════════════════════
///
/// Gamification system with 15 achievements across 6 categories.
/// Tracks user progress and unlocks achievements based on activity.
///
/// Categories:
///   1. Chat (محادثة)     — Messaging milestones
///   2. Tasks (مهام)      — Task creation and completion
///   3. Habits (عادات)    — Habit tracking
///   4. Pillars (محاور)   — Life pillar balance
///   5. Streaks (سلاسل)   — Consistency streaks
///   6. Special (خاص)     — Unique achievements
///
/// ═══════════════════════════════════════════════════════════════════════════════

library;

import 'dart:convert';

// ─── Achievement Category ─────────────────────────────────────────────────────

/// Achievement categories for grouping and filtering.
enum AchievementCategory {
  chat,
  tasks,
  habits,
  pillars,
  streaks,
  special;

  /// Arabic label (Egyptian colloquial)
  String get labelAr {
    switch (this) {
      case AchievementCategory.chat:
        return 'محادثة';
      case AchievementCategory.tasks:
        return 'مهام';
      case AchievementCategory.habits:
        return 'عادات';
      case AchievementCategory.pillars:
        return 'محاور';
      case AchievementCategory.streaks:
        return 'سلاسل';
      case AchievementCategory.special:
        return 'خاص';
    }
  }

  /// English label
  String get labelEn {
    switch (this) {
      case AchievementCategory.chat:
        return 'Chat';
      case AchievementCategory.tasks:
        return 'Tasks';
      case AchievementCategory.habits:
        return 'Habits';
      case AchievementCategory.pillars:
        return 'Pillars';
      case AchievementCategory.streaks:
        return 'Streaks';
      case AchievementCategory.special:
        return 'Special';
    }
  }

  /// Category icon
  String get icon {
    switch (this) {
      case AchievementCategory.chat:
        return '💬';
      case AchievementCategory.tasks:
        return '📋';
      case AchievementCategory.habits:
        return '🔄';
      case AchievementCategory.pillars:
        return '⚖️';
      case AchievementCategory.streaks:
        return '🔗';
      case AchievementCategory.special:
        return '⭐';
    }
  }

  /// Category color hex
  String get colorHex {
    switch (this) {
      case AchievementCategory.chat:
        return '#3B82F6';
      case AchievementCategory.tasks:
        return '#22C55E';
      case AchievementCategory.habits:
        return '#F59E0B';
      case AchievementCategory.pillars:
        return '#8B5CF6';
      case AchievementCategory.streaks:
        return '#EC4899';
      case AchievementCategory.special:
        return '#FFB300';
    }
  }
}

// ─── Achievement ─────────────────────────────────────────────────────────────

/// A single achievement that can be unlocked through user activity.
class Achievement {
  /// Unique identifier (e.g., "first_chat", "golden_chain")
  final String id;

  /// Title in Arabic (Egyptian colloquial)
  final String titleAr;

  /// Title in English
  final String titleEn;

  /// Description in Arabic (how to unlock)
  final String descriptionAr;

  /// Description in English
  final String descriptionEn;

  /// Emoji icon for the achievement
  final String icon;

  /// Achievement category
  final AchievementCategory category;

  /// When this achievement was unlocked (null if not unlocked yet)
  final DateTime? unlockedAt;

  /// Current progress toward the target
  final int progress;

  /// Target value to unlock
  final int target;

  /// Whether this achievement has been unlocked
  final bool isUnlocked;

  const Achievement({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.descriptionAr,
    required this.descriptionEn,
    required this.icon,
    required this.category,
    this.unlockedAt,
    this.progress = 0,
    this.target = 1,
    this.isUnlocked = false,
  });

  /// Progress as a percentage (0.0 to 1.0)
  double get progressPercent {
    if (target == 0) return 0;
    final pct = progress / target;
    return pct > 1.0 ? 1.0 : pct;
  }

  /// Progress as a display string (e.g., "3/10")
  String get progressLabel => '$progress/$target';

  /// Whether progress has started but not yet completed
  bool get isInProgress => progress > 0 && !isUnlocked;

  /// How many more points needed to unlock
  int get remaining => isUnlocked ? 0 : target - progress;

  /// Time since unlock (null if not unlocked)
  Duration? get timeSinceUnlock {
    if (unlockedAt == null) return null;
    return DateTime.now().difference(unlockedAt!);
  }

  /// Human-readable unlock time in Egyptian Arabic
  String get unlockedLabelAr {
    if (unlockedAt == null) return '';
    final duration = timeSinceUnlock!;
    if (duration.inMinutes < 1) return 'دلوقتي';
    if (duration.inHours < 1) return 'من ${duration.inMinutes} دقيقة';
    if (duration.inDays < 1) return 'من ${duration.inHours} ساعة';
    if (duration.inDays < 7) return 'من ${duration.inDays} يوم';
    return 'من ${unlockedAt!.day}/${unlockedAt!.month}';
  }

  Achievement copyWith({
    String? id,
    String? titleAr,
    String? titleEn,
    String? descriptionAr,
    String? descriptionEn,
    String? icon,
    AchievementCategory? category,
    DateTime? unlockedAt,
    int? progress,
    int? target,
    bool? isUnlocked,
  }) {
    return Achievement(
      id: id ?? this.id,
      titleAr: titleAr ?? this.titleAr,
      titleEn: titleEn ?? this.titleEn,
      descriptionAr: descriptionAr ?? this.descriptionAr,
      descriptionEn: descriptionEn ?? this.descriptionEn,
      icon: icon ?? this.icon,
      category: category ?? this.category,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      progress: progress ?? this.progress,
      target: target ?? this.target,
      isUnlocked: isUnlocked ?? this.isUnlocked,
    );
  }

  // ─── Serialization ──────────────────────────────────────────────────────

  factory Achievement.fromJson(Map<String, dynamic> json) => Achievement(
        id: json['id'] as String? ?? '',
        titleAr: json['titleAr'] as String? ?? '',
        titleEn: json['titleEn'] as String? ?? '',
        descriptionAr: json['descriptionAr'] as String? ?? '',
        descriptionEn: json['descriptionEn'] as String? ?? '',
        icon: json['icon'] as String? ?? '🏆',
        category: AchievementCategory.values.firstWhere(
          (c) => c.name == json['category'],
          orElse: () => AchievementCategory.special,
        ),
        unlockedAt: json['unlockedAt'] != null
            ? DateTime.parse(json['unlockedAt'] as String)
            : null,
        progress: json['progress'] as int? ?? 0,
        target: json['target'] as int? ?? 1,
        isUnlocked: json['isUnlocked'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'titleAr': titleAr,
        'titleEn': titleEn,
        'descriptionAr': descriptionAr,
        'descriptionEn': descriptionEn,
        'icon': icon,
        'category': category.name,
        'unlockedAt': unlockedAt?.toIso8601String(),
        'progress': progress,
        'target': target,
        'isUnlocked': isUnlocked,
      };

  factory Achievement.fromJsonString(String source) =>
      Achievement.fromJson(jsonDecode(source) as Map<String, dynamic>);

  String toJsonString() => jsonEncode(toJson());

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Achievement && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Achievement(id: $id, title: $titleAr, '
      'progress: $progress/$target, unlocked: $isUnlocked)';
}

// ─── Achievement Context ─────────────────────────────────────────────────────

/// Context data used to check and unlock achievements.
/// Passed to the achievement checking system with current user stats.
class AchievementContext {
  final int? messageCount;
  final int? tasksCreated;
  final int? tasksCompleted;
  final int? habitsCheckedToday;
  final int? habitStreak;
  final int? pillarScores;
  final int? webSearchCount;
  final int? youtubeSearchCount;
  final int? journalCount;
  final int? daysActive;
  final int? briefGenerated;
  final int? skillsTried;
  final int? deepThinkingUsed;
  final int? unlockedCount;

  const AchievementContext({
    this.messageCount,
    this.tasksCreated,
    this.tasksCompleted,
    this.habitsCheckedToday,
    this.habitStreak,
    this.pillarScores,
    this.webSearchCount,
    this.youtubeSearchCount,
    this.journalCount,
    this.daysActive,
    this.briefGenerated,
    this.skillsTried,
    this.deepThinkingUsed,
    this.unlockedCount,
  });
}

// ─── Default Achievement Definitions ─────────────────────────────────────────

/// All 15 achievement definitions (without progress/unlock state).
const List<Achievement> achievementDefinitions = [
  // ─── Chat Category ────────────────────────────────────────────────────
  Achievement(
    id: 'first_chat',
    titleAr: 'أول محادثة',
    titleEn: 'First Chat',
    descriptionAr: 'ابعت أول رسالة لأوج',
    descriptionEn: 'Send your first message to OWJ',
    icon: '💬',
    category: AchievementCategory.chat,
    target: 1,
  ),
  Achievement(
    id: 'active_chatter',
    titleAr: 'متحدث نشيط',
    titleEn: 'Active Chatter',
    descriptionAr: 'ابعت 50 رسالة',
    descriptionEn: 'Send 50 messages',
    icon: '🗣️',
    category: AchievementCategory.chat,
    target: 50,
  ),
  // ─── Tasks Category ───────────────────────────────────────────────────
  Achievement(
    id: 'planner_pro',
    titleAr: 'مخطط محترف',
    titleEn: 'Planner Pro',
    descriptionAr: 'أنشئ 10 مهام',
    descriptionEn: 'Create 10 tasks',
    icon: '📋',
    category: AchievementCategory.tasks,
    target: 10,
  ),
  Achievement(
    id: 'task_completer',
    titleAr: 'منجز المهام',
    titleEn: 'Task Completer',
    descriptionAr: 'أكمل 5 مهام',
    descriptionEn: 'Complete 5 tasks',
    icon: '✅',
    category: AchievementCategory.tasks,
    target: 5,
  ),
  // ─── Habits Category ──────────────────────────────────────────────────
  Achievement(
    id: 'daily_habits',
    titleAr: 'عادات يومية',
    titleEn: 'Daily Habits',
    descriptionAr: 'سجل 7 عادات في يوم واحد',
    descriptionEn: 'Log 7 habits in one day',
    icon: '🔄',
    category: AchievementCategory.habits,
    target: 7,
  ),
  // ─── Streaks Category ─────────────────────────────────────────────────
  Achievement(
    id: 'golden_chain',
    titleAr: 'سلسلة ذهبية',
    titleEn: 'Golden Chain',
    descriptionAr: 'حافظ على سلسلة عادات 7 أيام',
    descriptionEn: 'Maintain a 7-day habit streak',
    icon: '🔗',
    category: AchievementCategory.streaks,
    target: 7,
  ),
  Achievement(
    id: 'full_week',
    titleAr: 'أسبوع كامل',
    titleEn: 'Full Week',
    descriptionAr: 'استخدم التطبيق 7 أيام',
    descriptionEn: 'Use the app for 7 days',
    icon: '📅',
    category: AchievementCategory.streaks,
    target: 7,
  ),
  // ─── Pillars Category ─────────────────────────────────────────────────
  Achievement(
    id: 'balanced_pillar',
    titleAr: 'محور متوازن',
    titleEn: 'Balanced Pillar',
    descriptionAr: 'سجل نقاط في كل المحاور الخمسة',
    descriptionEn: 'Score in all five pillars',
    icon: '⚖️',
    category: AchievementCategory.pillars,
    target: 5,
  ),
  // ─── Special Category ─────────────────────────────────────────────────
  Achievement(
    id: 'researcher',
    titleAr: 'باحث متمكن',
    titleEn: 'Researcher',
    descriptionAr: 'قم بـ 10 عمليات بحث في الويب',
    descriptionEn: 'Perform 10 web searches',
    icon: '🔍',
    category: AchievementCategory.special,
    target: 10,
  ),
  Achievement(
    id: 'youtuber',
    titleAr: 'يوتيوبر',
    titleEn: 'YouTuber',
    descriptionAr: 'ابحث في يوتيوب 5 مرات',
    descriptionEn: 'Search YouTube 5 times',
    icon: '🎬',
    category: AchievementCategory.special,
    target: 5,
  ),
  Achievement(
    id: 'opinionated',
    titleAr: 'صاحب رأي',
    titleEn: 'Opinionated',
    descriptionAr: 'اكتب 3 تأملات في اليوميات',
    descriptionEn: 'Write 3 journal reflections',
    icon: '📝',
    category: AchievementCategory.special,
    target: 3,
  ),
  Achievement(
    id: 'first_brief',
    titleAr: 'أول بريف',
    titleEn: 'First Brief',
    descriptionAr: 'أنشئ أول بريف يومي',
    descriptionEn: 'Create your first daily brief',
    icon: '☀️',
    category: AchievementCategory.special,
    target: 1,
  ),
  Achievement(
    id: 'explorer',
    titleAr: 'مستكشف',
    titleEn: 'Explorer',
    descriptionAr: 'جرب 5 مهارات مختلفة',
    descriptionEn: 'Try 5 different skills',
    icon: '🧭',
    category: AchievementCategory.special,
    target: 5,
  ),
  Achievement(
    id: 'smart_thinker',
    titleAr: 'ذكي',
    titleEn: 'Smart Thinker',
    descriptionAr: 'استخدم التفكير العميق 3 مرات',
    descriptionEn: 'Use deep thinking 3 times',
    icon: '🧠',
    category: AchievementCategory.special,
    target: 3,
  ),
  Achievement(
    id: 'owj_expert',
    titleAr: 'أوج خبير',
    titleEn: 'OWJ Expert',
    descriptionAr: 'افتح 10 إنجازات تانية',
    descriptionEn: 'Unlock 10 other achievements',
    icon: '🏆',
    category: AchievementCategory.special,
    target: 10,
  ),
];

/// Create default achievements with zero progress for a new user.
List<Achievement> createDefaultAchievements() {
  return achievementDefinitions
      .map((def) => Achievement(
            id: def.id,
            titleAr: def.titleAr,
            titleEn: def.titleEn,
            descriptionAr: def.descriptionAr,
            descriptionEn: def.descriptionEn,
            icon: def.icon,
            category: def.category,
            target: def.target,
            progress: 0,
            isUnlocked: false,
          ))
      .toList();
}
