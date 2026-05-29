/// ═══════════════════════════════════════════════════════════════════════════════
/// 🔄 OWJ Assistant — Habit Model
/// ═══════════════════════════════════════════════════════════════════════════════
///
/// Represents a habit the user wants to track.
/// Includes streak tracking, completion history, and color coding.
///
/// ═══════════════════════════════════════════════════════════════════════════════

library;

import 'dart:convert';

/// A habit entry for tracking daily routines and behaviors.
class HabitEntry {
  /// Unique identifier
  final String id;

  /// Habit name (e.g., "مشيت 30 دقيقة", "قريت كتاب")
  final String name;

  /// Color as hex string for UI theming
  final String color;

  /// Current streak in days
  final int streak;

  /// Date the habit was last marked as done
  final DateTime? lastDone;

  /// Completion history: map of date string (YYYY-MM-DD) → completed (bool)
  final Map<String, bool> history;

  /// Optional: Description of the habit
  final String? description;

  /// Optional: Target frequency (e.g., "daily", "3x/week")
  final String? frequency;

  /// Optional: Reminder time (HH:mm format)
  final String? reminderTime;

  /// When this habit was created
  final DateTime createdAt;

  const HabitEntry({
    required this.id,
    required this.name,
    this.color = '#FFB300',
    this.streak = 0,
    this.lastDone,
    this.history = const {},
    this.description,
    this.frequency,
    this.reminderTime,
    required this.createdAt,
  });

  /// Whether the habit was completed today
  bool get isDoneToday {
    if (lastDone == null) return false;
    final now = DateTime.now();
    return lastDone!.year == now.year &&
        lastDone!.month == now.month &&
        lastDone!.day == now.day;
  }

  /// Whether the streak is still active (last done yesterday or today)
  bool get isStreakActive {
    if (lastDone == null) return false;
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    return lastDone!.isAfter(yesterday) || isDoneToday;
  }

  /// Longest streak calculated from history
  int get longestStreak {
    if (history.isEmpty) return streak;

    final completedDates = history.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList()
      ..sort();

    int longest = 0;
    int current = 0;
    String? prevDate;

    for (final dateStr in completedDates) {
      if (prevDate == null) {
        current = 1;
      } else {
        final prev = DateTime.parse(prevDate);
        final curr = DateTime.parse(dateStr);
        final diff = curr.difference(prev).inDays;
        if (diff == 1) {
          current++;
        } else {
          current = 1;
        }
      }
      longest = longest > current ? longest : current;
      prevDate = dateStr;
    }

    return longest > streak ? longest : streak;
  }

  /// Completion rate for the last N days (0.0 to 1.0)
  double completionRate(int days) {
    if (history.isEmpty) return 0.0;
    final now = DateTime.now();
    int completed = 0;
    int total = 0;

    for (int i = 0; i < days; i++) {
      final date = DateTime(now.year, now.month, now.day - i);
      final key = _dateKey(date);
      if (history.containsKey(key)) {
        total++;
        if (history[key]!) completed++;
      }
    }

    return total == 0 ? 0.0 : completed / total;
  }

  /// Mark the habit as done for a specific date
  HabitEntry markDone({DateTime? date}) {
    final targetDate = date ?? DateTime.now();
    final key = _dateKey(targetDate);
    final newHistory = Map<String, bool>.from(history);
    newHistory[key] = true;

    // Calculate new streak
    int newStreak = streak;
    if (!isDoneToday && date == null) {
      newStreak = isStreakActive ? streak + 1 : 1;
    } else if (date != null) {
      newStreak = _recalculateStreak(newHistory);
    }

    return copyWith(
      lastDone: targetDate,
      streak: newStreak,
      history: newHistory,
    );
  }

  /// Mark the habit as NOT done for a specific date
  HabitEntry markUndone({DateTime? date}) {
    final targetDate = date ?? DateTime.now();
    final key = _dateKey(targetDate);
    final newHistory = Map<String, bool>.from(history);
    newHistory[key] = false;

    return copyWith(
      streak: _recalculateStreak(newHistory),
      history: newHistory,
    );
  }

  /// Recalculate streak from history
  int _recalculateStreak(Map<String, bool> hist) {
    int count = 0;
    final now = DateTime.now();

    for (int i = 0; i < 365; i++) {
      final date = DateTime(now.year, now.month, now.day - i);
      final key = _dateKey(date);
      if (hist[key] == true) {
        count++;
      } else {
        break;
      }
    }
    return count;
  }

  /// Format date as YYYY-MM-DD key
  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  HabitEntry copyWith({
    String? id,
    String? name,
    String? color,
    int? streak,
    DateTime? lastDone,
    Map<String, bool>? history,
    String? description,
    String? frequency,
    String? reminderTime,
    DateTime? createdAt,
  }) {
    return HabitEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      streak: streak ?? this.streak,
      lastDone: lastDone ?? this.lastDone,
      history: history ?? this.history,
      description: description ?? this.description,
      frequency: frequency ?? this.frequency,
      reminderTime: reminderTime ?? this.reminderTime,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // ─── Serialization ──────────────────────────────────────────────────────

  factory HabitEntry.fromJson(Map<String, dynamic> json) => HabitEntry(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        color: json['color'] as String? ?? '#FFB300',
        streak: json['streak'] as int? ?? 0,
        lastDone: json['lastDone'] != null
            ? DateTime.parse(json['lastDone'] as String)
            : null,
        history: (json['history'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, v as bool)) ??
            {},
        description: json['description'] as String?,
        frequency: json['frequency'] as String?,
        reminderTime: json['reminderTime'] as String?,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': color,
        'streak': streak,
        'lastDone': lastDone?.toIso8601String(),
        'history': history,
        'description': description,
        'frequency': frequency,
        'reminderTime': reminderTime,
        'createdAt': createdAt.toIso8601String(),
      };

  factory HabitEntry.fromJsonString(String source) =>
      HabitEntry.fromJson(jsonDecode(source) as Map<String, dynamic>);

  String toJsonString() => jsonEncode(toJson());

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is HabitEntry && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'HabitEntry(id: $id, name: $name, streak: $streak)';
}
