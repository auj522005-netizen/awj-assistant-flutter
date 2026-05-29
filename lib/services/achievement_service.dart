import 'dart:convert';

import 'package:owj_assistant/services/storage_service.dart';

/// Achievement service tracking 15 achievements across 6 categories.
///
/// Categories:
///   1. Communication (تواصل)     — Messaging and interaction milestones
///   2. Memory (ذاكرة)           — Memory and knowledge retention
///   3. Productivity (إنتاجية)    — Task and goal completion
///   4. Creativity (إبداع)        — Ideas and creative thinking
///   5. Consistency (استمرارية)   — Streaks and regular usage
///   6. Mastery (إتقان)          — Deep skill and feature mastery
///
/// Persists state via [StorageService]. All user-facing strings
/// are in Egyptian Arabic.
class AchievementService {
  AchievementService({StorageService? storage})
      : _storage = storage ?? StorageService.instance;

  final StorageService _storage;

  /// Storage keys
  static const _achievementsKey = 'owj_achievements_v2';
  static const _statsKey = 'owj_achievement_stats';

  /// The 15 achievement definitions.
  static final List<AchievementDefinition> _definitions = [
    // ─── Communication (تواصل) — 3 achievements ────────────────────────
    AchievementDefinition(
      id: 'first_message',
      titleAr: 'أول رسالة',
      titleEn: 'First Message',
      descriptionAr: 'ابعت أول رسالة لأوج',
      descriptionEn: 'Send your first message to OWJ',
      icon: '💬',
      category: AchievementServiceCategory.communication,
      target: 1,
    ),
    AchievementDefinition(
      id: 'conversation_starter',
      titleAr: 'بادئ المحادثة',
      titleEn: 'Conversation Starter',
      descriptionAr: 'ابعت 25 رسالة',
      descriptionEn: 'Send 25 messages',
      icon: '🗣️',
      category: AchievementServiceCategory.communication,
      target: 25,
    ),
    AchievementDefinition(
      id: 'social_butterfly',
      titleAr: 'فراشة اجتماعية',
      titleEn: 'Social Butterfly',
      descriptionAr: 'ابعت 100 رسالة',
      descriptionEn: 'Send 100 messages',
      icon: '🦋',
      category: AchievementServiceCategory.communication,
      target: 100,
    ),

    // ─── Memory (ذاكرة) — 3 achievements ───────────────────────────────
    AchievementDefinition(
      id: 'first_memory',
      titleAr: 'أول ذكرى',
      titleEn: 'First Memory',
      descriptionAr: 'احفظ أول ذكرى في الذاكرة',
      descriptionEn: 'Save your first memory',
      icon: '🧠',
      category: AchievementServiceCategory.memory,
      target: 1,
    ),
    AchievementDefinition(
      id: 'memory_keeper',
      titleAr: 'حارس الذكريات',
      titleEn: 'Memory Keeper',
      descriptionAr: 'احفظ 20 ذكرى',
      descriptionEn: 'Save 20 memories',
      icon: '💾',
      category: AchievementServiceCategory.memory,
      target: 20,
    ),
    AchievementDefinition(
      id: 'recall_master',
      titleAr: 'محترف الاسترجاع',
      titleEn: 'Recall Master',
      descriptionAr: 'ابحث في الذاكرة 10 مرات',
      descriptionEn: 'Search memory 10 times',
      icon: '🔍',
      category: AchievementServiceCategory.memory,
      target: 10,
    ),

    // ─── Productivity (إنتاجية) — 3 achievements ───────────────────────
    AchievementDefinition(
      id: 'first_task',
      titleAr: 'أول مهمة',
      titleEn: 'First Task',
      descriptionAr: 'أنشئ أول مهمة',
      descriptionEn: 'Create your first task',
      icon: '📋',
      category: AchievementServiceCategory.productivity,
      target: 1,
    ),
    AchievementDefinition(
      id: 'task_master',
      titleAr: 'محترف المهام',
      titleEn: 'Task Master',
      descriptionAr: 'أكمل 15 مهمة',
      descriptionEn: 'Complete 15 tasks',
      icon: '✅',
      category: AchievementServiceCategory.productivity,
      target: 15,
    ),
    AchievementDefinition(
      id: 'efficiency_expert',
      titleAr: 'خبير الكفاءة',
      titleEn: 'Efficiency Expert',
      descriptionAr: 'أنشئ وأكمل 30 مهمة',
      descriptionEn: 'Create and complete 30 tasks',
      icon: '⚡',
      category: AchievementServiceCategory.productivity,
      target: 30,
    ),

    // ─── Creativity (إبداع) — 2 achievements ───────────────────────────
    AchievementDefinition(
      id: 'first_idea',
      titleAr: 'أول فكرة',
      titleEn: 'First Idea',
      descriptionAr: 'احفظ أول فكرة',
      descriptionEn: 'Save your first idea',
      icon: '💡',
      category: AchievementServiceCategory.creativity,
      target: 1,
    ),
    AchievementDefinition(
      id: 'creative_mind',
      titleAr: 'عقل مبدع',
      titleEn: 'Creative Mind',
      descriptionAr: 'احفظ 10 أفكار واعمل 3 تأملات',
      descriptionEn: 'Save 10 ideas and write 3 reflections',
      icon: '🎨',
      category: AchievementServiceCategory.creativity,
      target: 13,
    ),

    // ─── Consistency (استمرارية) — 2 achievements ─────────────────────
    AchievementDefinition(
      id: 'three_day_streak',
      titleAr: 'سلسلة 3 أيام',
      titleEn: '3-Day Streak',
      descriptionAr: 'استخدم التطبيق 3 أيام ورا بعض',
      descriptionEn: 'Use the app for 3 consecutive days',
      icon: '🔗',
      category: AchievementServiceCategory.consistency,
      target: 3,
    ),
    AchievementDefinition(
      id: 'weekly_warrior',
      titleAr: 'محارب أسبوعي',
      titleEn: 'Weekly Warrior',
      descriptionAr: 'استخدم التطبيق 7 أيام ورا بعض',
      descriptionEn: 'Use the app for 7 consecutive days',
      icon: '⚔️',
      category: AchievementServiceCategory.consistency,
      target: 7,
    ),

    // ─── Mastery (إتقان) — 2 achievements ──────────────────────────────
    AchievementDefinition(
      id: 'skill_seeker',
      titleAr: 'باحث مهارة',
      titleEn: 'Skill Seeker',
      descriptionAr: 'جرب 5 مهارات مختلفة',
      descriptionEn: 'Try 5 different skills',
      icon: '🧭',
      category: AchievementServiceCategory.mastery,
      target: 5,
    ),
    AchievementDefinition(
      id: 'knowledge_sage',
      titleAr: 'حكيم المعرفة',
      titleEn: 'Knowledge Sage',
      descriptionAr: 'افتح 10 إنجازات تانية',
      descriptionEn: 'Unlock 10 other achievements',
      icon: '🏆',
      category: AchievementServiceCategory.mastery,
      target: 10,
    ),
  ];

  // ── Public API ──

  /// Check all achievements against the current stats and unlock any new ones.
  ///
  /// Returns a list of newly unlocked achievement IDs (may be empty).
  Future<List<String>> checkAchievements() async {
    final stats = _loadStats();
    final states = _loadAchievementStates();
    final newlyUnlocked = <String>[];

    for (final def in _definitions) {
      final currentState = states[def.id];
      if (currentState != null && currentState.isUnlocked) continue;

      final progress = _calculateProgress(def, stats);
      final isNowUnlocked = progress >= def.target;

      states[def.id] = AchievementState(
        id: def.id,
        progress: progress,
        isUnlocked: isNowUnlocked,
        unlockedAt: isNowUnlocked && (currentState?.isUnlocked != true)
            ? DateTime.now()
            : currentState?.unlockedAt,
      );

      if (isNowUnlocked && (currentState?.isUnlocked != true)) {
        newlyUnlocked.add(def.id);
      }
    }

    await _saveAchievementStates(states);
    return newlyUnlocked;
  }

  /// Manually unlock an achievement by [id].
  ///
  /// Returns true if the achievement was newly unlocked,
  /// false if already unlocked or not found.
  Future<bool> unlockAchievement(String id) async {
    final def = _definitions.where((d) => d.id == id).firstOrNull;
    if (def == null) return false;

    final states = _loadAchievementStates();
    final currentState = states[id];

    if (currentState?.isUnlocked == true) return false;

    states[id] = AchievementState(
      id: id,
      progress: def.target,
      isUnlocked: true,
      unlockedAt: DateTime.now(),
    );

    await _saveAchievementStates(states);
    return true;
  }

  /// Get the progress for a specific achievement.
  ///
  /// Returns an [AchievementProgress] with current progress,
  /// target, and percentage.
  AchievementProgress getProgress(String id) {
    final def = _definitions.where((d) => d.id == id).firstOrNull;
    if (def == null) {
      return AchievementProgress(
        id: id,
        progress: 0,
        target: 1,
        percent: 0.0,
        isUnlocked: false,
        label: 'إنجاز مش موجود',
      );
    }

    final stats = _loadStats();
    final states = _loadAchievementStates();
    final state = states[id];

    final progress = state?.progress ?? _calculateProgress(def, stats);
    final isUnlocked = state?.isUnlocked ?? false;
    final percent = def.target > 0
        ? (progress / def.target).clamp(0.0, 1.0)
        : 0.0;

    return AchievementProgress(
      id: id,
      progress: progress,
      target: def.target,
      percent: percent,
      isUnlocked: isUnlocked,
      label: _progressLabelAr(def, progress, isUnlocked),
    );
  }

  /// Get all achievements with their current state.
  ///
  /// Returns a list of [AchievementInfo] combining definition
  /// and current progress/unlock state.
  List<AchievementInfo> getAllAchievements() {
    final stats = _loadStats();
    final states = _loadAchievementStates();

    return _definitions.map((def) {
      final state = states[def.id];
      final progress = state?.progress ?? _calculateProgress(def, stats);
      final isUnlocked = state?.isUnlocked ?? false;

      return AchievementInfo(
        definition: def,
        progress: progress,
        isUnlocked: isUnlocked,
        unlockedAt: state?.unlockedAt,
      );
    }).toList();
  }

  /// Update a stat counter (e.g., increment message count).
  ///
  /// Call this whenever an action occurs that could contribute
  /// to achievement progress.
  Future<void> updateStat(String statKey, int value) async {
    final stats = _loadStats();
    stats[statKey] = value;
    await _saveStats(stats);
  }

  /// Increment a stat counter by 1.
  Future<void> incrementStat(String statKey) async {
    final stats = _loadStats();
    stats[statKey] = (stats[statKey] ?? 0) + 1;
    await _saveStats(stats);
  }

  /// Get the total number of unlocked achievements.
  int getUnlockedCount() {
    final states = _loadAchievementStates();
    return states.values.where((s) => s.isUnlocked).length;
  }

  /// Get achievements grouped by category.
  Map<AchievementServiceCategory, List<AchievementInfo>>
      getAchievementsByCategory() {
    final all = getAllAchievements();
    final grouped = <AchievementServiceCategory, List<AchievementInfo>>{};

    for (final info in all) {
      final cat = info.definition.category;
      grouped.putIfAbsent(cat, () => []).add(info);
    }

    return grouped;
  }

  /// Reset all achievement progress (for testing).
  Future<void> resetAll() async {
    await _storage.delete(_achievementsKey);
    await _storage.delete(_statsKey);
  }

  // ── Private helpers ──

  /// Calculate progress for a definition based on current stats.
  int _calculateProgress(AchievementDefinition def, Map<String, int> stats) {
    switch (def.id) {
      // Communication
      case 'first_message':
      case 'conversation_starter':
      case 'social_butterfly':
        return stats['message_count'] ?? 0;
      // Memory
      case 'first_memory':
      case 'memory_keeper':
        return stats['memories_saved'] ?? 0;
      case 'recall_master':
        return stats['memory_searches'] ?? 0;
      // Productivity
      case 'first_task':
        return stats['tasks_created'] ?? 0;
      case 'task_master':
        return stats['tasks_completed'] ?? 0;
      case 'efficiency_expert':
        return (stats['tasks_created'] ?? 0) + (stats['tasks_completed'] ?? 0);
      // Creativity
      case 'first_idea':
        return stats['ideas_saved'] ?? 0;
      case 'creative_mind':
        return (stats['ideas_saved'] ?? 0) + (stats['reflections_written'] ?? 0);
      // Consistency
      case 'three_day_streak':
      case 'weekly_warrior':
        return stats['consecutive_days'] ?? 0;
      // Mastery
      case 'skill_seeker':
        return stats['skills_tried'] ?? 0;
      case 'knowledge_sage':
        return getUnlockedCount();
      default:
        return 0;
    }
  }

  /// Generate an Arabic progress label.
  String _progressLabelAr(
    AchievementDefinition def,
    int progress,
    bool isUnlocked,
  ) {
    if (isUnlocked) {
      return 'تم فتحه! 🎉';
    }
    if (progress == 0) {
      return 'لسه بدأتش — ${def.descriptionAr}';
    }
    return '$progress من ${def.target}';
  }

  // ── Persistence ──

  /// Load achievement states from storage.
  Map<String, AchievementState> _loadAchievementStates() {
    final json = _storage.getMap(_achievementsKey);
    final states = <String, AchievementState>{};

    for (final entry in json.entries) {
      final value = entry.value;
      if (value is Map<String, dynamic>) {
        states[entry.key] = AchievementState(
          id: entry.key,
          progress: value['progress'] as int? ?? 0,
          isUnlocked: value['isUnlocked'] as bool? ?? false,
          unlockedAt: value['unlockedAt'] != null
              ? DateTime.tryParse(value['unlockedAt'] as String)
              : null,
        );
      }
    }

    return states;
  }

  /// Save achievement states to storage.
  Future<void> _saveAchievementStates(Map<String, AchievementState> states) async {
    final json = <String, dynamic>{};
    for (final entry in states.entries) {
      json[entry.key] = {
        'progress': entry.value.progress,
        'isUnlocked': entry.value.isUnlocked,
        'unlockedAt': entry.value.unlockedAt?.toIso8601String(),
      };
    }
    await _storage.setMap(_achievementsKey, json);
  }

  /// Load stats from storage.
  Map<String, int> _loadStats() {
    final json = _storage.getMap(_statsKey);
    final stats = <String, int>{};
    for (final entry in json.entries) {
      if (entry.value is int) {
        stats[entry.key] = entry.value;
      } else if (entry.value is num) {
        stats[entry.key] = (entry.value as num).toInt();
      }
    }
    return stats;
  }

  /// Save stats to storage.
  Future<void> _saveStats(Map<String, int> stats) async {
    await _storage.setMap(_statsKey, stats.map((k, v) => MapEntry(k, v)));
  }
}

// ── Data models ──

/// Achievement categories for the achievement service.
enum AchievementServiceCategory {
  communication,
  memory,
  productivity,
  creativity,
  consistency,
  mastery;

  /// Arabic label (Egyptian colloquial)
  String get labelAr {
    switch (this) {
      case AchievementServiceCategory.communication:
        return 'تواصل';
      case AchievementServiceCategory.memory:
        return 'ذاكرة';
      case AchievementServiceCategory.productivity:
        return 'إنتاجية';
      case AchievementServiceCategory.creativity:
        return 'إبداع';
      case AchievementServiceCategory.consistency:
        return 'استمرارية';
      case AchievementServiceCategory.mastery:
        return 'إتقان';
    }
  }

  /// English label
  String get labelEn {
    switch (this) {
      case AchievementServiceCategory.communication:
        return 'Communication';
      case AchievementServiceCategory.memory:
        return 'Memory';
      case AchievementServiceCategory.productivity:
        return 'Productivity';
      case AchievementServiceCategory.creativity:
        return 'Creativity';
      case AchievementServiceCategory.consistency:
        return 'Consistency';
      case AchievementServiceCategory.mastery:
        return 'Mastery';
    }
  }

  /// Category icon
  String get icon {
    switch (this) {
      case AchievementServiceCategory.communication:
        return '💬';
      case AchievementServiceCategory.memory:
        return '🧠';
      case AchievementServiceCategory.productivity:
        return '⚡';
      case AchievementServiceCategory.creativity:
        return '🎨';
      case AchievementServiceCategory.consistency:
        return '🔗';
      case AchievementServiceCategory.mastery:
        return '🏆';
    }
  }

  /// Category color hex
  String get colorHex {
    switch (this) {
      case AchievementServiceCategory.communication:
        return '#3B82F6';
      case AchievementServiceCategory.memory:
        return '#8B5CF6';
      case AchievementServiceCategory.productivity:
        return '#22C55E';
      case AchievementServiceCategory.creativity:
        return '#F59E0B';
      case AchievementServiceCategory.consistency:
        return '#EC4899';
      case AchievementServiceCategory.mastery:
        return '#FFB300';
    }
  }
}

/// Immutable definition of an achievement.
class AchievementDefinition {
  final String id;
  final String titleAr;
  final String titleEn;
  final String descriptionAr;
  final String descriptionEn;
  final String icon;
  final AchievementServiceCategory category;
  final int target;

  const AchievementDefinition({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.descriptionAr,
    required this.descriptionEn,
    required this.icon,
    required this.category,
    required this.target,
  });
}

/// Mutable state of an achievement (progress + unlock status).
class AchievementState {
  final String id;
  final int progress;
  final bool isUnlocked;
  final DateTime? unlockedAt;

  const AchievementState({
    required this.id,
    required this.progress,
    required this.isUnlocked,
    this.unlockedAt,
  });
}

/// Progress info for a single achievement.
class AchievementProgress {
  final String id;
  final int progress;
  final int target;
  final double percent;
  final bool isUnlocked;
  final String label;

  const AchievementProgress({
    required this.id,
    required this.progress,
    required this.target,
    required this.percent,
    required this.isUnlocked,
    required this.label,
  });

  /// Progress as a display string (e.g., "3/10").
  String get progressLabel => '$progress/$target';

  /// Whether progress has started but not completed.
  bool get isInProgress => progress > 0 && !isUnlocked;

  /// How many more points needed to unlock.
  int get remaining => isUnlocked ? 0 : target - progress;
}

/// Full achievement info combining definition and state.
class AchievementInfo {
  final AchievementDefinition definition;
  final int progress;
  final bool isUnlocked;
  final DateTime? unlockedAt;

  const AchievementInfo({
    required this.definition,
    required this.progress,
    required this.isUnlocked,
    this.unlockedAt,
  });

  /// Progress as a percentage (0.0 to 1.0).
  double get percent {
    if (definition.target == 0) return 0;
    return (progress / definition.target).clamp(0.0, 1.0);
  }

  /// Progress as a display string.
  String get progressLabel => '$progress/${definition.target}';

  /// Whether progress has started but not completed.
  bool get isInProgress => progress > 0 && !isUnlocked;

  /// Egyptian Arabic summary.
  String get summaryAr {
    if (isUnlocked) {
      return '${definition.icon} ${definition.titleAr} — تم فتحه! 🎉';
    }
    if (progress > 0) {
      return '${definition.icon} ${definition.titleAr} — $progressLabel';
    }
    return '${definition.icon} ${definition.titleAr} — ${definition.descriptionAr}';
  }

  /// Time since unlock in Egyptian Arabic.
  String get unlockedLabelAr {
    if (unlockedAt == null) return '';
    final duration = DateTime.now().difference(unlockedAt!);
    if (duration.inMinutes < 1) return 'دلوقتي';
    if (duration.inHours < 1) return 'من ${duration.inMinutes} دقيقة';
    if (duration.inDays < 1) return 'من ${duration.inHours} ساعة';
    if (duration.inDays < 7) return 'من ${duration.inDays} يوم';
    return 'من ${unlockedAt!.day}/${unlockedAt!.month}';
  }
}

/// Achievement service exception.
class AchievementException implements Exception {
  final String message;
  AchievementException(this.message);

  @override
  String toString() => 'AchievementException: $message';
}
