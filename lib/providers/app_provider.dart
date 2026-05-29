/// ═══════════════════════════════════════════════════════════════════════════════
/// 🌐 OWJ Assistant — App Provider
/// ═══════════════════════════════════════════════════════════════════════════════
///
/// Global app state management using ChangeNotifier.
/// Manages pillars, habits, tasks, appointments, journals,
/// characters, achievements, and user settings.
///
/// ═══════════════════════════════════════════════════════════════════════════════

library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:owj_assistant/models/pillar.dart';
import 'package:owj_assistant/models/habit.dart';
import 'package:owj_assistant/models/task.dart';
import 'package:owj_assistant/models/journal.dart';
import 'package:owj_assistant/models/character.dart';
import 'package:owj_assistant/models/achievement.dart';
import 'package:owj_assistant/models/ai_model.dart';
import 'package:owj_assistant/services/storage_service.dart';

class AppProvider extends ChangeNotifier {
  AppProvider({StorageService? storage})
      : _storage = storage ?? StorageService.instance;

  final StorageService _storage;
  static const _uuid = Uuid();

  // ─── State ───────────────────────────────────────────────────────────────────

  /// Life pillars data
  List<PillarData> _pillars = [];

  /// User habits
  List<HabitEntry> _habits = [];

  /// Task items
  List<TaskItem> _tasks = [];

  /// Appointments
  List<Appointment> _appointments = [];

  /// Journal entries
  List<JournalEntry> _journals = [];

  /// AI characters
  List<Character> _characters = [];

  /// Achievements
  List<Achievement> _achievements = [];

  /// User settings
  Map<String, dynamic> _settings = {};

  /// Whether onboarding is complete
  bool _isOnboarded = false;

  /// User's name
  String _userName = '';

  /// Whether data is loaded
  bool _isLoaded = false;

  // ─── Getters ─────────────────────────────────────────────────────────────────

  List<PillarData> get pillars => List.unmodifiable(_pillars);
  List<HabitEntry> get habits => List.unmodifiable(_habits);
  List<TaskItem> get tasks => List.unmodifiable(_tasks);
  List<Appointment> get appointments => List.unmodifiable(_appointments);
  List<JournalEntry> get journals => List.unmodifiable(_journals);
  List<Character> get characters => List.unmodifiable(_characters);
  List<Achievement> get achievements => List.unmodifiable(_achievements);
  Map<String, dynamic> get settings => Map.unmodifiable(_settings);
  bool get isOnboarded => _isOnboarded;
  String get userName => _userName;
  bool get isLoaded => _isLoaded;

  /// Get today's tasks
  List<TaskItem> get todayTasks =>
      _tasks.where((t) => t.isDueToday || !t.completed).toList();

  /// Get today's appointments
  List<Appointment> get todayAppointments =>
      _appointments.where((a) => a.isToday).toList();

  /// Get completed task count
  int get completedTaskCount =>
      _tasks.where((t) => t.completed).length;

  /// Get active (incomplete) task count
  int get activeTaskCount =>
      _tasks.where((t) => !t.completed).length;

  /// Get unlocked achievement count
  int get unlockedAchievementCount =>
      _achievements.where((a) => a.isUnlocked).length;

  /// Get overall pillar average score
  double get overallPillarScore {
    if (_pillars.isEmpty) return 0;
    return _pillars.fold(0.0, (sum, p) => sum + p.score) / _pillars.length;
  }

  /// Get model config from settings
  ModelConfig get modelConfig {
    final mc = _settings['modelConfig'];
    if (mc is Map<String, dynamic>) {
      return ModelConfig.fromJson(mc);
    }
    return const ModelConfig();
  }

  // ─── Initialization ──────────────────────────────────────────────────────────

  /// Load all data from persistent storage.
  Future<void> loadAll() async {
    await Future.wait([
      _loadPillars(),
      _loadHabits(),
      _loadTasks(),
      _loadAppointments(),
      _loadJournals(),
      _loadCharacters(),
      _loadAchievements(),
      _loadSettings(),
      _loadOnboardingStatus(),
    ]);
    _isLoaded = true;
    notifyListeners();
  }

  // ─── Pillar Methods ──────────────────────────────────────────────────────────

  void _initDefaultPillars() {
    _pillars = getDefaultPillars();
  }

  Future<void> _loadPillars() async {
    final json = _storage.getString('pillars');
    if (json != null && json.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(json);
        _pillars = decoded
            .map((p) => PillarData.fromJson(p as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _initDefaultPillars();
      }
    } else {
      _initDefaultPillars();
    }
  }

  Future<void> _savePillars() async {
    final json = jsonEncode(_pillars.map((p) => p.toJson()).toList());
    await _storage.setString('pillars', json);
  }

  Future<void> updatePillarScore(PillarType type, double score) async {
    final index = _pillars.indexWhere((p) => p.type == type);
    if (index != -1) {
      _pillars[index] = _pillars[index].copyWith(
        score: score,
        lastUpdated: DateTime.now(),
      );
      notifyListeners();
      await _savePillars();
    }
  }

  Future<void> updatePillarNotes(PillarType type, String notes) async {
    final index = _pillars.indexWhere((p) => p.type == type);
    if (index != -1) {
      _pillars[index] = _pillars[index].copyWith(
        notes: notes,
        lastUpdated: DateTime.now(),
      );
      notifyListeners();
      await _savePillars();
    }
  }

  PillarData? getPillar(PillarType type) {
    return _pillars.where((p) => p.type == type).firstOrNull;
  }

  // ─── Habit Methods ───────────────────────────────────────────────────────────

  Future<void> _loadHabits() async {
    final json = _storage.getString('habits');
    if (json != null && json.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(json);
        _habits = decoded
            .map((h) => HabitEntry.fromJson(h as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _habits = [];
      }
    }
  }

  Future<void> _saveHabits() async {
    final json = jsonEncode(_habits.map((h) => h.toJson()).toList());
    await _storage.setString('habits', json);
  }

  Future<void> addHabit(HabitEntry habit) async {
    _habits.add(habit);
    notifyListeners();
    await _saveHabits();
  }

  Future<void> updateHabit(HabitEntry habit) async {
    final index = _habits.indexWhere((h) => h.id == habit.id);
    if (index != -1) {
      _habits[index] = habit;
      notifyListeners();
      await _saveHabits();
    }
  }

  Future<void> deleteHabit(String id) async {
    _habits.removeWhere((h) => h.id == id);
    notifyListeners();
    await _saveHabits();
  }

  Future<void> toggleHabit(String id) async {
    final index = _habits.indexWhere((h) => h.id == id);
    if (index != -1) {
      if (_habits[index].isDoneToday) {
        _habits[index] = _habits[index].markUndone();
      } else {
        _habits[index] = _habits[index].markDone();
      }
      notifyListeners();
      await _saveHabits();
    }
  }

  // ─── Task Methods ────────────────────────────────────────────────────────────

  Future<void> _loadTasks() async {
    final json = _storage.getString('tasks');
    if (json != null && json.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(json);
        _tasks = decoded
            .map((t) => TaskItem.fromJson(t as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _tasks = [];
      }
    }
  }

  Future<void> _saveTasks() async {
    final json = jsonEncode(_tasks.map((t) => t.toJson()).toList());
    await _storage.setString('tasks', json);
  }

  Future<void> addTask(TaskItem task) async {
    _tasks.add(task);
    notifyListeners();
    await _saveTasks();
  }

  Future<void> addTaskFromText(String title) async {
    final task = TaskItem(
      id: _uuid.v4(),
      title: title,
      createdAt: DateTime.now(),
    );
    await addTask(task);
  }

  Future<void> updateTask(TaskItem task) async {
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index != -1) {
      _tasks[index] = task;
      notifyListeners();
      await _saveTasks();
    }
  }

  Future<void> deleteTask(String id) async {
    _tasks.removeWhere((t) => t.id == id);
    notifyListeners();
    await _saveTasks();
  }

  Future<void> toggleTask(String id) async {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      if (_tasks[index].completed) {
        _tasks[index] = _tasks[index].markIncomplete();
      } else {
        _tasks[index] = _tasks[index].markComplete();
      }
      notifyListeners();
      await _saveTasks();
    }
  }

  // ─── Appointment Methods ─────────────────────────────────────────────────────

  Future<void> _loadAppointments() async {
    final json = _storage.getString('appointments');
    if (json != null && json.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(json);
        _appointments = decoded
            .map((a) => Appointment.fromJson(a as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _appointments = [];
      }
    }
  }

  Future<void> _saveAppointments() async {
    final json = jsonEncode(_appointments.map((a) => a.toJson()).toList());
    await _storage.setString('appointments', json);
  }

  Future<void> addAppointment(Appointment appointment) async {
    _appointments.add(appointment);
    notifyListeners();
    await _saveAppointments();
  }

  Future<void> updateAppointment(Appointment appointment) async {
    final index = _appointments.indexWhere((a) => a.id == appointment.id);
    if (index != -1) {
      _appointments[index] = appointment;
      notifyListeners();
      await _saveAppointments();
    }
  }

  Future<void> deleteAppointment(String id) async {
    _appointments.removeWhere((a) => a.id == id);
    notifyListeners();
    await _saveAppointments();
  }

  // ─── Journal Methods ─────────────────────────────────────────────────────────

  Future<void> _loadJournals() async {
    final json = _storage.getString('journals');
    if (json != null && json.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(json);
        _journals = decoded
            .map((j) => JournalEntry.fromJson(j as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _journals = [];
      }
    }
  }

  Future<void> _saveJournals() async {
    final json = jsonEncode(_journals.map((j) => j.toJson()).toList());
    await _storage.setString('journals', json);
  }

  Future<void> addJournal(JournalEntry journal) async {
    _journals.insert(0, journal); // Newest first
    notifyListeners();
    await _saveJournals();
  }

  Future<void> addJournalFromText(String content, {JournalMood? mood}) async {
    final journal = JournalEntry(
      id: _uuid.v4(),
      date: DateTime.now(),
      content: content,
      userMood: mood,
      createdAt: DateTime.now(),
    );
    await addJournal(journal);
  }

  Future<void> updateJournal(JournalEntry journal) async {
    final index = _journals.indexWhere((j) => j.id == journal.id);
    if (index != -1) {
      _journals[index] = journal;
      notifyListeners();
      await _saveJournals();
    }
  }

  Future<void> deleteJournal(String id) async {
    _journals.removeWhere((j) => j.id == id);
    notifyListeners();
    await _saveJournals();
  }

  // ─── Character Methods ───────────────────────────────────────────────────────

  Future<void> _loadCharacters() async {
    final json = _storage.getString('characters');
    if (json != null && json.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(json);
        _characters = decoded
            .map((c) => Character.fromJson(c as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _characters = getDefaultCharacters();
      }
    } else {
      _characters = getDefaultCharacters();
    }
  }

  Future<void> _saveCharacters() async {
    final json = jsonEncode(_characters.map((c) => c.toJson()).toList());
    await _storage.setString('characters', json);
  }

  Future<void> addCharacter(Character character) async {
    _characters.add(character);
    notifyListeners();
    await _saveCharacters();
  }

  Future<void> updateCharacter(Character character) async {
    final index = _characters.indexWhere((c) => c.id == character.id);
    if (index != -1) {
      _characters[index] = character;
      notifyListeners();
      await _saveCharacters();
    }
  }

  Future<void> deleteCharacter(String id) async {
    _characters.removeWhere((c) => c.id == id);
    notifyListeners();
    await _saveCharacters();
  }

  // ─── Achievement Methods ─────────────────────────────────────────────────────

  Future<void> _loadAchievements() async {
    final json = _storage.getString('achievements');
    if (json != null && json.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(json);
        _achievements = decoded
            .map((a) => Achievement.fromJson(a as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _achievements = createDefaultAchievements();
      }
    } else {
      _achievements = createDefaultAchievements();
    }
  }

  Future<void> _saveAchievements() async {
    final json = jsonEncode(_achievements.map((a) => a.toJson()).toList());
    await _storage.setString('achievements', json);
  }

  Future<void> updateAchievement(Achievement achievement) async {
    final index = _achievements.indexWhere((a) => a.id == achievement.id);
    if (index != -1) {
      _achievements[index] = achievement;
      notifyListeners();
      await _saveAchievements();
    }
  }

  /// Check and update achievements based on current context.
  Future<void> checkAchievements({
    int? messageCount,
    int? tasksCompleted,
    int? habitsStreak,
  }) async {
    bool changed = false;

    for (int i = 0; i < _achievements.length; i++) {
      final a = _achievements[i];
      if (a.isUnlocked) continue;

      int? newProgress;
      switch (a.id) {
        case 'first_chat':
          newProgress = (messageCount ?? 0) > 0 ? 1 : 0;
          break;
        case 'active_chatter':
          newProgress = messageCount ?? 0;
          break;
        case 'task_completer':
          newProgress = tasksCompleted ?? 0;
          break;
        case 'golden_chain':
          newProgress = habitsStreak ?? 0;
          break;
      }

      if (newProgress != null && newProgress > a.progress) {
        _achievements[i] = a.copyWith(
          progress: newProgress,
          isUnlocked: newProgress >= a.target,
          unlockedAt: newProgress >= a.target ? DateTime.now() : null,
        );
        changed = true;
      }
    }

    if (changed) {
      notifyListeners();
      await _saveAchievements();
    }
  }

  // ─── Settings Methods ────────────────────────────────────────────────────────

  Future<void> _loadSettings() async {
    _settings = _storage.getMap('app_settings');
    if (_settings.isEmpty) {
      _settings = _defaultSettings();
    }
  }

  Future<void> _saveSettings() async {
    await _storage.setMap('app_settings', _settings);
  }

  Map<String, dynamic> _defaultSettings() {
    return {
      'language': 'ar',
      'ttsProvider': 'elevenLabs',
      'ttsSpeed': 1.0,
      'modelConfig': const ModelConfig().toJson(),
      'theme': 'dark',
      'notificationsEnabled': true,
      'dailyBriefEnabled': true,
      'dailyBriefTime': '07:00',
    };
  }

  T getSetting<T>(String key, T defaultValue) {
    final value = _settings[key];
    if (value is T) return value;
    return defaultValue;
  }

  Future<void> setSetting(String key, dynamic value) async {
    _settings[key] = value;
    notifyListeners();
    await _saveSettings();
  }

  Future<void> updateModelConfig(ModelConfig config) async {
    _settings['modelConfig'] = config.toJson();
    notifyListeners();
    await _saveSettings();
  }

  // ─── Onboarding ──────────────────────────────────────────────────────────────

  Future<void> _loadOnboardingStatus() async {
    _isOnboarded = _storage.getSetting('isOnboarded', false);
    _userName = _storage.getSetting('userName', '');
  }

  Future<void> completeOnboarding(String name) async {
    _isOnboarded = true;
    _userName = name;
    notifyListeners();
    await _storage.setSetting('isOnboarded', true);
    await _storage.setSetting('userName', name);
  }

  Future<void> setUserName(String name) async {
    _userName = name;
    notifyListeners();
    await _storage.setSetting('userName', name);
  }

  // ─── Greeting Helper ─────────────────────────────────────────────────────────

  /// Get time-appropriate greeting in Egyptian Arabic.
  String get greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'صباح الخير';
    } else if (hour < 17) {
      return 'مساء الخير';
    } else {
      return 'مساء النور';
    }
  }

  /// Get greeting with user name.
  String get personalizedGreeting {
    if (_userName.isNotEmpty) {
      return '$greeting، $_userName 👋';
    }
    return '$greeting 👋';
  }
}
