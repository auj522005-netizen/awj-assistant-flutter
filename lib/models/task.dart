/// ═══════════════════════════════════════════════════════════════════════════════
/// ✅ OWJ Assistant — Task & Appointment Models
/// ═══════════════════════════════════════════════════════════════════════════════
///
/// Task management and appointment scheduling models.
/// Tasks support priority levels and completion tracking.
/// Appointments support reminders and recurrence.
///
/// ═══════════════════════════════════════════════════════════════════════════════

library;

import 'dart:convert';

// ─── Priority Enum ───────────────────────────────────────────────────────────

/// Task priority levels.
enum TaskPriority {
  low,
  medium,
  high,
  urgent;

  /// Arabic label (Egyptian colloquial)
  String get labelAr {
    switch (this) {
      case TaskPriority.low:
        return 'منخفضة';
      case TaskPriority.medium:
        return 'متوسطة';
      case TaskPriority.high:
        return 'عالية';
      case TaskPriority.urgent:
        return 'عاجلة';
    }
  }

  /// English label
  String get labelEn {
    switch (this) {
      case TaskPriority.low:
        return 'Low';
      case TaskPriority.medium:
        return 'Medium';
      case TaskPriority.high:
        return 'High';
      case TaskPriority.urgent:
        return 'Urgent';
    }
  }

  /// Color hex for UI display
  String get colorHex {
    switch (this) {
      case TaskPriority.low:
        return '#6B7B8D';
      case TaskPriority.medium:
        return '#3B82F6';
      case TaskPriority.high:
        return '#F59E0B';
      case TaskPriority.urgent:
        return '#EF4444';
    }
  }

  /// Emoji icon
  String get icon {
    switch (this) {
      case TaskPriority.low:
        return '🟢';
      case TaskPriority.medium:
        return '🔵';
      case TaskPriority.high:
        return '🟡';
      case TaskPriority.urgent:
        return '🔴';
    }
  }

  /// Numeric value for sorting (higher = more urgent)
  int get value {
    switch (this) {
      case TaskPriority.low:
        return 1;
      case TaskPriority.medium:
        return 2;
      case TaskPriority.high:
        return 3;
      case TaskPriority.urgent:
        return 4;
    }
  }
}

// ─── Task Item ────────────────────────────────────────────────────────────────

/// A single task item with priority, due date, and completion status.
class TaskItem {
  /// Unique identifier
  final String id;

  /// Task title (e.g., "خلص التقرير", "ابعت الإيميل")
  final String title;

  /// Optional detailed notes
  final String? notes;

  /// When the task is due (null = no deadline)
  final DateTime? dueDate;

  /// Whether the task is completed
  final bool completed;

  /// Priority level
  final TaskPriority priority;

  /// When the task was created
  final DateTime createdAt;

  /// Optional: When the task was completed
  final DateTime? completedAt;

  /// Optional: Associated pillar ID
  final String? pillarId;

  /// Optional: Tags/categories
  final List<String> tags;

  const TaskItem({
    required this.id,
    required this.title,
    this.notes,
    this.dueDate,
    this.completed = false,
    this.priority = TaskPriority.medium,
    required this.createdAt,
    this.completedAt,
    this.pillarId,
    this.tags = const [],
  });

  /// Whether the task is overdue
  bool get isOverdue {
    if (completed || dueDate == null) return false;
    return DateTime.now().isAfter(dueDate!);
  }

  /// Whether the task is due today
  bool get isDueToday {
    if (dueDate == null) return false;
    final now = DateTime.now();
    return dueDate!.year == now.year &&
        dueDate!.month == now.month &&
        dueDate!.day == now.day;
  }

  /// Whether the task is due this week
  bool get isDueThisWeek {
    if (dueDate == null) return false;
    final now = DateTime.now();
    final endOfWeek = now.add(Duration(days: 7 - now.weekday));
    return dueDate!.isBefore(endOfWeek) && dueDate!.isAfter(now);
  }

  /// Days until due (negative if overdue)
  int? get daysUntilDue {
    if (dueDate == null) return null;
    return dueDate!.difference(DateTime.now()).inDays;
  }

  /// Human-readable due date in Egyptian Arabic
  String get dueDateLabelAr {
    if (dueDate == null) return 'مفيش موعد';
    if (isDueToday) return 'النهارده';
    final days = daysUntilDue!;
    if (days == 1) return 'بكرا';
    if (days == -1) return 'امبارح';
    if (days > 0 && days <= 7) return 'بعد $days أيام';
    if (days < 0) return 'فات بـ ${-days} يوم';
    return '${dueDate!.day}/${dueDate!.month}';
  }

  /// Mark the task as complete
  TaskItem markComplete() => copyWith(
        completed: true,
        completedAt: DateTime.now(),
      );

  /// Mark the task as incomplete
  TaskItem markIncomplete() => copyWith(
        completed: false,
        completedAt: null,
      );

  TaskItem copyWith({
    String? id,
    String? title,
    String? notes,
    DateTime? dueDate,
    bool? completed,
    TaskPriority? priority,
    DateTime? createdAt,
    DateTime? completedAt,
    String? pillarId,
    List<String>? tags,
  }) {
    return TaskItem(
      id: id ?? this.id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      dueDate: dueDate ?? this.dueDate,
      completed: completed ?? this.completed,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      pillarId: pillarId ?? this.pillarId,
      tags: tags ?? this.tags,
    );
  }

  // ─── Serialization ──────────────────────────────────────────────────────

  factory TaskItem.fromJson(Map<String, dynamic> json) => TaskItem(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        notes: json['notes'] as String?,
        dueDate: json['dueDate'] != null
            ? DateTime.parse(json['dueDate'] as String)
            : null,
        completed: json['completed'] as bool? ?? false,
        priority: TaskPriority.values.firstWhere(
          (p) => p.name == json['priority'],
          orElse: () => TaskPriority.medium,
        ),
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
        completedAt: json['completedAt'] != null
            ? DateTime.parse(json['completedAt'] as String)
            : null,
        pillarId: json['pillarId'] as String?,
        tags: (json['tags'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'notes': notes,
        'dueDate': dueDate?.toIso8601String(),
        'completed': completed,
        'priority': priority.name,
        'createdAt': createdAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'pillarId': pillarId,
        'tags': tags,
      };

  factory TaskItem.fromJsonString(String source) =>
      TaskItem.fromJson(jsonDecode(source) as Map<String, dynamic>);

  String toJsonString() => jsonEncode(toJson());

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TaskItem && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'TaskItem(id: $id, title: $title, '
      'priority: ${priority.name}, completed: $completed)';
}

// ─── Appointment ─────────────────────────────────────────────────────────────

/// A scheduled appointment with optional reminder.
class Appointment {
  /// Unique identifier
  final String id;

  /// Appointment title (e.g., "اجتماع مع الفريق", "دكتور")
  final String title;

  /// When the appointment starts
  final DateTime dateTime;

  /// Optional notes about the appointment
  final String? notes;

  /// Minutes before the appointment to trigger a reminder (0 = no reminder)
  final int reminderMinutes;

  /// When this appointment was created
  final DateTime createdAt;

  /// Optional: End time (null = default 1 hour)
  final DateTime? endDateTime;

  /// Optional: Location
  final String? location;

  /// Optional: Associated pillar ID
  final String? pillarId;

  /// Optional: Whether a reminder has been sent
  final bool reminderSent;

  const Appointment({
    required this.id,
    required this.title,
    required this.dateTime,
    this.notes,
    this.reminderMinutes = 15,
    required this.createdAt,
    this.endDateTime,
    this.location,
    this.pillarId,
    this.reminderSent = false,
  });

  /// Whether the appointment is today
  bool get isToday {
    final now = DateTime.now();
    return dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day;
  }

  /// Whether the appointment is in the past
  bool get isPast => DateTime.now().isAfter(dateTime);

  /// Whether the appointment is upcoming (within the next 24 hours)
  bool get isUpcoming {
    final now = DateTime.now();
    return dateTime.isAfter(now) &&
        dateTime.isBefore(now.add(const Duration(hours: 24)));
  }

  /// When the reminder should fire (null if no reminder)
  DateTime? get reminderTime {
    if (reminderMinutes <= 0) return null;
    return dateTime.subtract(Duration(minutes: reminderMinutes));
  }

  /// Whether the reminder should be shown now
  bool get shouldShowReminder {
    final rTime = reminderTime;
    if (rTime == null || reminderSent) return false;
    return DateTime.now().isAfter(rTime);
  }

  /// Duration until the appointment
  Duration? get timeUntil {
    if (isPast) return null;
    return dateTime.difference(DateTime.now());
  }

  /// Human-readable time until in Egyptian Arabic
  String get timeUntilLabelAr {
    final duration = timeUntil;
    if (duration == null) return 'فات';
    if (duration.inMinutes < 1) return 'دلوقتي';
    if (duration.inMinutes < 60) return 'بعد ${duration.inMinutes} دقيقة';
    if (duration.inHours < 24) return 'بعد ${duration.inHours} ساعة';
    return 'بعد ${duration.inDays} يوم';
  }

  /// Human-readable date in Egyptian Arabic
  String get dateLabelAr {
    if (isToday) return 'النهارده';
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    if (dateTime.year == tomorrow.year &&
        dateTime.month == tomorrow.month &&
        dateTime.day == tomorrow.day) {
      return 'بكرا';
    }
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  /// Formatted time (HH:mm)
  String get timeLabel {
    return '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Appointment copyWith({
    String? id,
    String? title,
    DateTime? dateTime,
    String? notes,
    int? reminderMinutes,
    DateTime? createdAt,
    DateTime? endDateTime,
    String? location,
    String? pillarId,
    bool? reminderSent,
  }) {
    return Appointment(
      id: id ?? this.id,
      title: title ?? this.title,
      dateTime: dateTime ?? this.dateTime,
      notes: notes ?? this.notes,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      createdAt: createdAt ?? this.createdAt,
      endDateTime: endDateTime ?? this.endDateTime,
      location: location ?? this.location,
      pillarId: pillarId ?? this.pillarId,
      reminderSent: reminderSent ?? this.reminderSent,
    );
  }

  // ─── Serialization ──────────────────────────────────────────────────────

  factory Appointment.fromJson(Map<String, dynamic> json) => Appointment(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        dateTime: json['dateTime'] != null
            ? DateTime.parse(json['dateTime'] as String)
            : DateTime.now(),
        notes: json['notes'] as String?,
        reminderMinutes: json['reminderMinutes'] as int? ?? 15,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
        endDateTime: json['endDateTime'] != null
            ? DateTime.parse(json['endDateTime'] as String)
            : null,
        location: json['location'] as String?,
        pillarId: json['pillarId'] as String?,
        reminderSent: json['reminderSent'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'dateTime': dateTime.toIso8601String(),
        'notes': notes,
        'reminderMinutes': reminderMinutes,
        'createdAt': createdAt.toIso8601String(),
        'endDateTime': endDateTime?.toIso8601String(),
        'location': location,
        'pillarId': pillarId,
        'reminderSent': reminderSent,
      };

  factory Appointment.fromJsonString(String source) =>
      Appointment.fromJson(jsonDecode(source) as Map<String, dynamic>);

  String toJsonString() => jsonEncode(toJson());

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Appointment && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Appointment(id: $id, title: $title, dateTime: $dateTime)';
}
