import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:owj_assistant/services/storage_service.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Notification service using flutter_local_notifications.
///
/// Schedules recurring notifications:
///   - Daily brief at 8:00 AM (البريف اليومي)
///   - Night reflection at 10:00 PM (تأمل المساء)
///   - Weekly retro on Thursday at 8:00 PM (مراجعة الأسبوع)
///   - Habit reminders at 9:00 AM (تذكير العادات)
///
/// Also supports one-time task reminders with custom date/times.
/// All user-facing strings are in Egyptian Arabic.
class NotificationsService {
  NotificationsService({StorageService? storage})
      : _storage = storage ?? StorageService.instance,
        _plugin = FlutterLocalNotificationsPlugin();

  final StorageService _storage;
  final FlutterLocalNotificationsPlugin _plugin;

  bool _initialized = false;

  /// Notification channel IDs
  static const _channelDailyBrief = 'owj_daily_brief';
  static const _channelNightReflection = 'owj_night_reflection';
  static const _channelWeeklyRetro = 'owj_weekly_retro';
  static const _channelHabitReminder = 'owj_habit_reminder';
  static const _channelTaskReminder = 'owj_task_reminder';

  /// Notification IDs (fixed for recurring, offset for custom)
  static const _idDailyBrief = 1001;
  static const _idNightReflection = 1002;
  static const _idWeeklyRetro = 1003;
  static const _idHabitReminder = 1004;
  static const _idTaskReminderStart = 2000;

  /// Storage key for scheduled task reminders
  static const _taskRemindersKey = 'owj_task_reminders';

  // ── Initialization ──

  /// Initialize the notification service.
  ///
  /// Must be called before any scheduling methods.
  /// Sets up timezone data, notification channels, and permissions.
  Future<bool> initialize() async {
    if (_initialized) return true;

    // Initialize timezone database
    tz.initializeTimeZones();
    // Default to Africa/Cairo for Egyptian users
    tz.setLocalLocation(tz.getLocation('Africa/Cairo'));

    // Initialize the plugin
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    final result = await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _initialized = result ?? false;

    // Request Android 13+ notification permission
    if (_initialized) {
      await _requestPermissions();
    }

    return _initialized;
  }

  /// Request notification permissions (Android 13+, iOS).
  Future<bool> _requestPermissions() async {
    // Android
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
    }

    // iOS
    final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (iosPlugin != null) {
      await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    return true;
  }

  // ── Recurring Schedules ──

  /// Schedule daily brief notification at 8:00 AM.
  ///
  /// Shows: "صباح الخير! ☀️ وقت البريف اليومي"
  Future<void> scheduleDailyBrief() async {
    _ensureInitialized();

    const androidDetails = AndroidNotificationDetails(
      _channelDailyBrief,
      'البريف اليومي',
      channelDescription: 'إشعار البريف اليومي الساعة 8 الصبح',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Schedule daily at 8:00 AM
    await _plugin.zonedSchedule(
      _idDailyBrief,
      'صباح الخير! ☀️',
      'وقت البريف اليومي — تعالى شوف مهامك وأخبارك',
      _nextInstanceOfTime(8, 0),
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'daily_brief',
    );

    await _saveScheduleState('daily_brief', true);
  }

  /// Schedule night reflection notification at 10:00 PM.
  ///
  /// Shows: "مساء النور 🌙 وقت التأمل"
  Future<void> scheduleNightReflection() async {
    _ensureInitialized();

    const androidDetails = AndroidNotificationDetails(
      _channelNightReflection,
      'تأمل المساء',
      channelDescription: 'إشعار تأمل المساء الساعة 10',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Schedule daily at 10:00 PM
    await _plugin.zonedSchedule(
      _idNightReflection,
      'مساء النور 🌙',
      'وقت التأمل — فكّر في يومك واكتب تأملاتك',
      _nextInstanceOfTime(22, 0),
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'night_reflection',
    );

    await _saveScheduleState('night_reflection', true);
  }

  /// Schedule weekly retro notification on Thursday at 8:00 PM.
  ///
  /// Shows: "مراجعة الأسبوع 📊"
  Future<void> scheduleWeeklyRetro() async {
    _ensureInitialized();

    const androidDetails = AndroidNotificationDetails(
      _channelWeeklyRetro,
      'مراجعة الأسبوع',
      channelDescription: 'إشعار مراجعة الأسبوع كل خميس الساعة 8',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Schedule weekly on Thursday at 8:00 PM
    await _plugin.zonedSchedule(
      _idWeeklyRetro,
      'مراجعة الأسبوع 📊',
      'خلص الأسبوع! راجع إنجازاتك وخطط للأسبوع الجاي',
      _nextInstanceOfDayAndTime(DateTime.thursday, 20, 0),
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: 'weekly_retro',
    );

    await _saveScheduleState('weekly_retro', true);
  }

  /// Schedule habit reminder notification at 9:00 AM daily.
  ///
  /// Shows: "تذكير العادات 🔄"
  Future<void> scheduleHabitReminder() async {
    _ensureInitialized();

    const androidDetails = AndroidNotificationDetails(
      _channelHabitReminder,
      'تذكير العادات',
      channelDescription: 'إشعار تذكير العادات اليومية الساعة 9',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Schedule daily at 9:00 AM
    await _plugin.zonedSchedule(
      _idHabitReminder,
      'تذكير العادات 🔄',
      'ما تنساش عاداتك اليومية — سجلها دلوقتي!',
      _nextInstanceOfTime(9, 0),
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'habit_reminder',
    );

    await _saveScheduleState('habit_reminder', true);
  }

  // ── Task Reminders ──

  /// Schedule a one-time task reminder notification.
  ///
  /// [taskId] is the unique task identifier.
  /// [title] is the task title for the notification body.
  /// [dateTime] is when the notification should fire.
  ///
  /// Returns the notification ID assigned to this reminder.
  Future<int> scheduleTaskReminder({
    required String taskId,
    required String title,
    required DateTime dateTime,
  }) async {
    _ensureInitialized();

    final notificationId = await _getNextTaskNotificationId();

    final androidDetails = AndroidNotificationDetails(
      _channelTaskReminder,
      'تذكير المهام',
      channelDescription: 'إشعارات تذكير المهام',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails();
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final scheduledDate = tz.TZDateTime.from(dateTime, tz.local);

    // Don't schedule in the past
    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
      throw NotificationException(
        'الوقت ده عدى — اختار وقت في المستقبل ⏰',
      );
    }

    await _plugin.zonedSchedule(
      notificationId,
      'تذكير مهمة 📋',
      'متنساش: $title',
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'task:$taskId',
    );

    // Persist the reminder
    await _saveTaskReminder(
      taskId: taskId,
      title: title,
      notificationId: notificationId,
      scheduledAt: dateTime,
    );

    return notificationId;
  }

  // ── Cancel Operations ──

  /// Cancel a specific notification by ID.
  Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
    await _removeTaskReminderByNotificationId(id);
  }

  /// Cancel all scheduled notifications.
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
    await _storage.delete(_taskRemindersKey);
    await _saveScheduleState('daily_brief', false);
    await _saveScheduleState('night_reflection', false);
    await _saveScheduleState('weekly_retro', false);
    await _saveScheduleState('habit_reminder', false);
  }

  /// Cancel a task reminder by task ID.
  Future<void> cancelTaskReminder(String taskId) async {
    final reminders = _getTaskReminders();
    final reminder = reminders.firstWhere(
      (r) => r['taskId'] == taskId,
      orElse: () => <String, dynamic>{},
    );

    if (reminder.isNotEmpty) {
      final notificationId = reminder['notificationId'] as int?;
      if (notificationId != null) {
        await _plugin.cancel(notificationId);
      }
      reminders.remove(reminder);
      await _storage.setStringList(
        _taskRemindersKey,
        reminders.map((r) => jsonEncode(r)).toList(),
      );
    }
  }

  /// Reschedule all recurring notifications (e.g., after device reboot).
  Future<void> rescheduleAll() async {
    final state = _storage.getMap('owj_notification_schedules');
    if (state['daily_brief'] == true) await scheduleDailyBrief();
    if (state['night_reflection'] == true) await scheduleNightReflection();
    if (state['weekly_retro'] == true) await scheduleWeeklyRetro();
    if (state['habit_reminder'] == true) await scheduleHabitReminder();
  }

  /// Get all pending task reminders.
  List<TaskReminderInfo> getPendingTaskReminders() {
    final reminders = _getTaskReminders();
    return reminders.map((r) => TaskReminderInfo(
      taskId: r['taskId'] as String? ?? '',
      title: r['title'] as String? ?? '',
      notificationId: r['notificationId'] as int? ?? 0,
      scheduledAt: DateTime.tryParse(r['scheduledAt'] as String? ?? '') ??
          DateTime.now(),
    )).toList();
  }

  // ── Private helpers ──

  void _ensureInitialized() {
    if (!_initialized) {
      throw NotificationException(
        'خدمة الإشعارات مش شغالة — نادي initialize() الأول 🔔',
      );
    }
  }

  /// Get the next instance of a specific time today, or tomorrow if it passed.
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// Get the next instance of a specific weekday and time.
  tz.TZDateTime _nextInstanceOfDayAndTime(int day, int hour, int minute) {
    var scheduled = _nextInstanceOfTime(hour, minute);
    while (scheduled.weekday != day) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// Get the next available task notification ID.
  Future<int> _getNextTaskNotificationId() async {
    final reminders = _getTaskReminders();
    if (reminders.isEmpty) return _idTaskReminderStart;

    final usedIds = reminders
        .map((r) => r['notificationId'] as int? ?? 0)
        .toList();
    var nextId = _idTaskReminderStart;
    while (usedIds.contains(nextId)) {
      nextId++;
    }
    return nextId;
  }

  /// Save schedule state for a notification type.
  Future<void> _saveScheduleState(String type, bool enabled) async {
    final state = _storage.getMap('owj_notification_schedules');
    state[type] = enabled;
    await _storage.setMap('owj_notification_schedules', state);
  }

  /// Get all stored task reminders.
  List<Map<String, dynamic>> _getTaskReminders() {
    final list = _storage.getStringList(_taskRemindersKey);
    return list
        .map((s) {
          try {
            return jsonDecode(s) as Map<String, dynamic>;
          } catch (_) {
            return <String, dynamic>{};
          }
        })
        .where((m) => m.isNotEmpty)
        .toList();
  }

  /// Save a task reminder to storage.
  Future<void> _saveTaskReminder({
    required String taskId,
    required String title,
    required int notificationId,
    required DateTime scheduledAt,
  }) async {
    final reminders = _getTaskReminders();
    reminders.add({
      'taskId': taskId,
      'title': title,
      'notificationId': notificationId,
      'scheduledAt': scheduledAt.toIso8601String(),
    });
    await _storage.setStringList(
      _taskRemindersKey,
      reminders.map((r) => jsonEncode(r)).toList(),
    );
  }

  /// Remove a task reminder from storage by notification ID.
  Future<void> _removeTaskReminderByNotificationId(int notificationId) async {
    final reminders = _getTaskReminders();
    reminders.removeWhere(
      (r) => r['notificationId'] == notificationId,
    );
    await _storage.setStringList(
      _taskRemindersKey,
      reminders.map((r) => jsonEncode(r)).toList(),
    );
  }

  /// Handle notification tap.
  void _onNotificationTapped(NotificationResponse response) {
    // This can be extended to navigate to specific screens
    // based on the payload
    final payload = response.payload;
    if (payload == null) return;

    // Payload routing:
    // 'daily_brief' → Navigate to daily brief screen
    // 'night_reflection' → Navigate to journal/reflection screen
    // 'weekly_retro' → Navigate to weekly retro screen
    // 'habit_reminder' → Navigate to habits screen
    // 'task:<taskId>' → Navigate to task detail screen
  }
}

// ── Data models ──

/// Information about a scheduled task reminder.
class TaskReminderInfo {
  /// The task ID this reminder is for.
  final String taskId;

  /// Task title for display.
  final String title;

  /// The notification ID assigned.
  final int notificationId;

  /// When the reminder is scheduled to fire.
  final DateTime scheduledAt;

  const TaskReminderInfo({
    required this.taskId,
    required this.title,
    required this.notificationId,
    required this.scheduledAt,
  });

  /// Whether this reminder is in the past (should have already fired).
  bool get isOverdue => DateTime.now().isAfter(scheduledAt);

  /// Egyptian Arabic label.
  String get labelAr {
    final diff = scheduledAt.difference(DateTime.now());
    if (diff.isNegative) return 'فات الوقت';
    if (diff.inMinutes < 60) return 'بعد ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'بعد ${diff.inHours} ساعة';
    return 'بعد ${diff.inDays} يوم';
  }
}

/// Notification service exception.
class NotificationException implements Exception {
  final String message;
  NotificationException(this.message);

  @override
  String toString() => 'NotificationException: $message';
}
