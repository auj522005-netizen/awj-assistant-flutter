import 'dart:math';
import 'package:owj_assistant/services/storage_service.dart';

/// MCP Time service with Islamic prayer time calculations and scheduling.
///
/// Provides current time, prayer times using astronomical calculations,
/// natural language time parsing, and task scheduling.
class McpTimeService {
  McpTimeService({StorageService? storage})
      : _storage = storage ?? StorageService.instance;

  final StorageService _storage;

  // ── Public API ──

  /// Returns current time with timezone and Islamic date info.
  CurrentTimeResult getCurrentTime() {
    final now = DateTime.now();
    final hijriDate = _gregorianToHijri(now);

    return CurrentTimeResult(
      dateTime: now,
      timezone: now.timeZoneName,
      timezoneOffset: now.timeZoneOffset,
      weekdayAr: _weekdayArabic(now.weekday),
      hijriDate: hijriDate,
      greeting: _getGreeting(now.hour),
      isRamadan: hijriDate.month == 9,
    );
  }

  /// Calculates prayer times for given [latitude] and [longitude].
  ///
  /// Uses simplified astronomical calculations based on the
  /// Muslim World League convention (Fajr: 18°, Isha: 17°).
  Future<PrayerTimesResult> getPrayerTimes(double lat, double lng) async {
    final now = DateTime.now();
    final doy = _dayOfYear(now);
    final timezoneOffset = now.timeZoneOffset.inHours.toDouble();

    // Calculate solar declination and equation of time
    final b = (2 * pi / 365) * (doy - 81);
    final eot = 9.87 * sin(2 * b) - 7.53 * cos(b) - 1.5 * sin(b); // equation of time (min)
    final decl = 23.45 * sin(b); // solar declination (degrees)

    // Solar noon
    final lngDiff = lng * 4; // minutes per degree
    final solarNoonMinutes = 720 - lngDiff - eot + timezoneOffset * 60;

    // Hour angle function
    double hourAngle(double altitude) {
      final cosH = (sin(altitude * pi / 180) - sin(lat * pi / 180) * sin(decl * pi / 180)) /
          (cos(lat * pi / 180) * cos(decl * pi / 180));
      if (cosH > 1) return double.nan; // Sun never reaches this altitude
      if (cosH < -1) return double.nan; // Sun never sets
      return acos(cosH) * 180 / pi;
    }

    // Calculate prayer times (angles from Muslim World League)
    final fajrAngle = 18.0;
    final ishaAngle = 17.0;

    final fajrHa = hourAngle(fajrAngle);
    final ishaHa = hourAngle(ishaAngle);

    // Sunrise/Sunset (altitude = -0.833 for atmospheric refraction)
    final sunriseHa = hourAngle(-0.833);
    final sunsetHa = hourAngle(-0.833);

    // Asr: Shafi'i method (shadow = object + shadow at noon)
    final noonAlt = 90 - (lat - decl).abs();
    final asrAlt = 90 - atan(1 + tan((90 - noonAlt) * pi / 180)) * 180 / pi;
    final asrHa = hourAngle(asrAlt);

    // Convert to clock times
    final fajr = _minutesToTime(solarNoonMinutes - fajrHa * 4);
    final sunrise = _minutesToTime(solarNoonMinutes - sunriseHa * 4);
    final dhuhr = _minutesToTime(solarNoonMinutes + 1); // +1 min safety margin
    final asr = _minutesToTime(solarNoonMinutes + asrHa * 4);
    final maghrib = _minutesToTime(solarNoonMinutes + sunsetHa * 4);
    final isha = _minutesToTime(solarNoonMinutes + ishaHa * 4);

    // Determine next prayer
    final nowMinutes = now.hour * 60 + now.minute;
    final prayerMap = {
      'الفجر': fajr,
      'الشروق': sunrise,
      'الظهر': dhuhr,
      'العصر': asr,
      'المغرب': maghrib,
      'العشاء': isha,
    };

    String? nextPrayer;
    Duration? timeToNext;
    for (final entry in prayerMap.entries) {
      final mins = _timeToMinutes(entry.value);
      if (mins > nowMinutes) {
        nextPrayer = entry.key;
        timeToNext = Duration(minutes: mins - nowMinutes);
        break;
      }
    }
    nextPrayer ??= 'الفجر (غداً)';

    // Qibla direction from given coordinates
    final qiblaDir = _calculateQibla(lat, lng);

    return PrayerTimesResult(
      fajr: fajr,
      sunrise: sunrise,
      dhuhr: dhuhr,
      asr: asr,
      maghrib: maghrib,
      isha: isha,
      nextPrayer: nextPrayer,
      timeToNextPrayer: timeToNext,
      qiblaDirection: qiblaDir,
      date: now,
      location: LocationInfo(latitude: lat, longitude: lng),
    );
  }

  /// Suggests an optimal schedule for the given [tasks].
  Future<ScheduleResult> suggestSchedule(List<ScheduleTask> tasks) async {
    // Sort tasks by priority and estimated duration
    final sorted = List<ScheduleTask>.from(tasks)
      ..sort((a, b) {
        final priorityCompare = b.priority.index.compareTo(a.priority.index);
        if (priorityCompare != 0) return priorityCompare;
        return a.estimatedMinutes.compareTo(b.estimatedMinutes);
      });

    final schedule = <ScheduledItem>[];
    var currentHour = 8; // Start at 8 AM

    for (final task in sorted) {
      // Skip prayer times (approximate)
      final conflicts = _checkPrayerConflicts(currentHour, task.estimatedMinutes);

      if (conflicts.isNotEmpty) {
        // Move to after prayer
        currentHour = conflicts.last + 1;
      }

      final startTime = _minutesToTime(currentHour * 60);
      final endHour = currentHour + (task.estimatedMinutes / 60).ceil();
      final endTime = _minutesToTime(endHour * 60);

      schedule.add(ScheduledItem(
        task: task,
        startTime: startTime,
        endTime: endTime,
        startMinutes: currentHour * 60,
        endMinutes: endHour * 60,
      ));

      currentHour = endHour + 1; // 1-hour break between tasks
    }

    return ScheduleResult(
      items: schedule,
      totalHours: schedule.fold<double>(0, (sum, item) =>
        sum + (item.endMinutes - item.startMinutes) / 60),
      tasksScheduled: schedule.length,
      tasksRemaining: tasks.length - schedule.length,
      suggestions: _generateScheduleSuggestions(schedule),
    );
  }

  /// Parses natural language time text (Arabic and English).
  ParsedTime parseNaturalTime(String text) {
    final lower = text.trim().toLowerCase();
    final now = DateTime.now();

    // Arabic time patterns
    final arPatterns = <_TimePattern>[
      _TimePattern(RegExp(r'الآن|حالاً'), (m) => now),
      _TimePattern(RegExp(r'بعد (\d+) دقيق[ةه]'), (m) => now.add(Duration(minutes: int.parse(m.group(1)!)))),
      _TimePattern(RegExp(r'بعد (\d+) ساع[ةه]'), (m) => now.add(Duration(hours: int.parse(m.group(1)!)))),
      _TimePattern(RegExp(r'بعد (\d+) يوم'), (m) => now.add(Duration(days: int.parse(m.group(1)!)))),
      _TimePattern(RegExp(r'الصباح'), (m) => DateTime(now.year, now.month, now.day, 8, 0)),
      _TimePattern(RegExp(r'الظهر'), (m) => DateTime(now.year, now.month, now.day, 12, 0)),
      _TimePattern(RegExp(r'العصر'), (m) => DateTime(now.year, now.month, now.day, 15, 0)),
      _TimePattern(RegExp(r'المغرب'), (m) => DateTime(now.year, now.month, now.day, 18, 0)),
      _TimePattern(RegExp(r'المساء'), (m) => DateTime(now.year, now.month, now.day, 20, 0)),
      _TimePattern(RegExp(r'بعد الفجر'), (m) => DateTime(now.year, now.month, now.day, 5, 30)),
      _TimePattern(RegExp(r'بعد الظهر'), (m) => DateTime(now.year, now.month, now.day, 13, 0)),
      _TimePattern(RegExp(r'غداً|بكرة'), (m) => now.add(const Duration(days: 1))),
      _TimePattern(RegExp(r'أمس|بارحة'), (m) => now.subtract(const Duration(days: 1))),
      _TimePattern(RegExp(r'بعد بكرة'), (m) => now.add(const Duration(days: 2))),
      _TimePattern(RegExp(r'الجمعة الجاية'), (m) => _nextWeekday(now, DateTime.friday)),
      _TimePattern(RegExp(r'السبت الجاي'), (m) => _nextWeekday(now, DateTime.saturday)),
    ];

    // English time patterns
    final enPatterns = <_TimePattern>[
      _TimePattern(RegExp(r'in (\d+) minutes?'), (m) => now.add(Duration(minutes: int.parse(m.group(1)!)))),
      _TimePattern(RegExp(r'in (\d+) hours?'), (m) => now.add(Duration(hours: int.parse(m.group(1)!)))),
      _TimePattern(RegExp(r'in (\d+) days?'), (m) => now.add(Duration(days: int.parse(m.group(1)!)))),
      _TimePattern(RegExp(r'tomorrow'), (m) => now.add(const Duration(days: 1))),
      _TimePattern(RegExp(r'yesterday'), (m) => now.subtract(const Duration(days: 1))),
      _TimePattern(RegExp(r'next week'), (m) => now.add(const Duration(days: 7))),
      _TimePattern(RegExp(r'tonight'), (m) => DateTime(now.year, now.month, now.day, 20, 0)),
      _TimePattern(RegExp(r'this morning'), (m) => DateTime(now.year, now.month, now.day, 8, 0)),
      _TimePattern(RegExp(r'this afternoon'), (m) => DateTime(now.year, now.month, now.day, 14, 0)),
      _TimePattern(RegExp(r'this evening'), (m) => DateTime(now.year, now.month, now.day, 18, 0)),
      _TimePattern(RegExp(r'next friday'), (m) => _nextWeekday(now, DateTime.friday)),
      _TimePattern(RegExp(r'next monday'), (m) => _nextWeekday(now, DateTime.monday)),
      _TimePattern(RegExp(r'(\d{1,2}):(\d{2})\s*(am|pm)?'), (m) {
        var hour = int.parse(m.group(1)!);
        final minute = int.parse(m.group(2)!);
        final period = m.group(3)?.toLowerCase();
        if (period == 'pm' && hour < 12) hour += 12;
        if (period == 'am' && hour == 12) hour = 0;
        return DateTime(now.year, now.month, now.day, hour, minute);
      }),
    ];

    // Try Arabic patterns first, then English
    for (final pattern in [...arPatterns, ...enPatterns]) {
      final match = pattern.regex.firstMatch(lower);
      if (match != null) {
        try {
          final parsed = pattern.builder(match);
          return ParsedTime(
            originalText: text,
            parsedDateTime: parsed,
            confidence: 0.9,
            isRelative: text.contains(RegExp(r'بعد|in|from')),
          );
        } catch (_) {
          continue;
        }
      }
    }

    // Could not parse
    return ParsedTime(
      originalText: text,
      parsedDateTime: null,
      confidence: 0.0,
      isRelative: false,
    );
  }

  // ── Private helpers ──

  int _dayOfYear(DateTime date) {
    return date.difference(DateTime(date.year, 1, 1)).inDays + 1;
  }

  String _minutesToTime(double minutes) {
    if (minutes.isNaN) return '--:--';
    final h = (minutes ~/ 60) % 24;
    final m = (minutes % 60).round();
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  int _timeToMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  double _calculateQibla(double lat, double lng) {
    // Kaaba coordinates
    const kaabaLat = 21.4225;
    const kaabaLng = 39.8262;

    final latR = lat * pi / 180;
    final lngR = lng * pi / 180;
    final kLatR = kaabaLat * pi / 180;
    final kLngR = kaabaLng * pi / 180;

    final qibla = atan2(
      sin(kLngR - lngR),
      cos(latR) * tan(kLatR) - sin(latR) * cos(kLngR - lngR),
    );

    return (qibla * 180 / pi + 360) % 360;
  }

  String _weekdayArabic(int weekday) {
    const days = {
      1: 'الاثنين', 2: 'الثلاثاء', 3: 'الأربعاء',
      4: 'الخميس', 5: 'الجمعة', 6: 'السبت', 7: 'الأحد',
    };
    return days[weekday] ?? '';
  }

  String _getGreeting(int hour) {
    if (hour >= 5 && hour < 12) return 'صباح الخير ☀️';
    if (hour >= 12 && hour < 17) return 'مساء النور 🌤️';
    if (hour >= 17 && hour < 21) return 'مساء الخير 🌅';
    return 'مساء النور 🌙';
  }

  HijriDate _gregorianToHijri(DateTime date) {
    // Simplified Hijri conversion using the Kuwaiti algorithm
    final gd = date.day;
    final gm = date.month;
    final gy = date.year;

    int jd;
    if (gm > 2) {
      jd = (365.25 * (gy + 4716)).toInt() + (30.6001 * (gm + 1)).toInt() + gd - 1524;
    } else {
      jd = (365.25 * (gy - 1 + 4716)).toInt() + (30.6001 * (gm + 13)).toInt() + gd - 1524;
    }

    final l = jd - 1948440 + 10632;
    final n = ((l - 1) / 10631).toInt();
    final lPrime = l - 10631 * n + 354;
    final j = ((10985 - lPrime) / 5316).toInt() * ((50 * lPrime) / 17719).toInt() +
        ((lPrime / 5670).toInt()) * ((43 * lPrime) / 15238).toInt();
    final lDouble = lPrime - ((30 - j) / 15).toInt() * ((17719 * j) / 50).toInt() -
        ((j / 16).toInt()) * ((15238 * j) / 15238).toInt() + 29;
    final m = ((24 * lDouble) / 709).toInt();
    final d = lDouble - ((709 * m) / 24).toInt();
    final y = 30 * n + j - 30;

    final monthNames = [
      '', 'محرم', 'صفر', 'ربيع الأول', 'ربيع الثاني',
      'جمادى الأولى', 'جمادى الآخرة', 'رجب', 'شعبان',
      'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة',
    ];

    return HijriDate(
      year: y,
      month: m,
      day: d,
      monthName: m >= 1 && m <= 12 ? monthNames[m] : '',
    );
  }

  List<int> _checkPrayerConflicts(int startHour, int durationMinutes) {
    // Approximate prayer hours that we should avoid scheduling over
    const prayerHours = [5, 12, 15, 18, 20]; // Fajr, Dhuhr, Asr, Maghrib, Isha
    final conflicts = <int>[];
    final endHour = startHour + (durationMinutes / 60).ceil();

    for (final ph in prayerHours) {
      if (ph >= startHour && ph < endHour) {
        conflicts.add(ph);
      }
    }
    return conflicts;
  }

  List<String> _generateScheduleSuggestions(List<ScheduledItem> schedule) {
    final suggestions = <String>[];

    if (schedule.isEmpty) {
      suggestions.add('لا توجد مهام لجدولتها');
      return suggestions;
    }

    // Suggest breaks between long sessions
    for (final item in schedule) {
      if (item.endMinutes - item.startMinutes > 120) {
        suggestions.add('اقتراح: قسم "${item.task.title}" إلى جلستين مع استراحة');
      }
    }

    // Suggest morning focus
    if (schedule.first.startMinutes >= 8 * 60 && schedule.first.startMinutes < 10 * 60) {
      suggestions.add('الصباح هو أفضل وقت للمهام المعرفية 🧠');
    }

    // Avoid late scheduling
    if (schedule.last.endMinutes > 22 * 60) {
      suggestions.add('⚠️ الجدول يمتد لوقت متأخر - حاول تبسيط المهام');
    }

    return suggestions;
  }

  DateTime _nextWeekday(DateTime from, int weekday) {
    var date = from;
    while (date.weekday != weekday) {
      date = date.add(const Duration(days: 1));
    }
    return date;
  }
}

// ── Data models ──

class CurrentTimeResult {
  final DateTime dateTime;
  final String timezone;
  final Duration timezoneOffset;
  final String weekdayAr;
  final HijriDate hijriDate;
  final String greeting;
  final bool isRamadan;

  const CurrentTimeResult({
    required this.dateTime,
    required this.timezone,
    required this.timezoneOffset,
    required this.weekdayAr,
    required this.hijriDate,
    required this.greeting,
    required this.isRamadan,
  });
}

class HijriDate {
  final int year;
  final int month;
  final int day;
  final String monthName;

  const HijriDate({
    required this.year,
    required this.month,
    required this.day,
    required this.monthName,
  });

  String get formatted => '$day $monthName $year هـ';
}

class PrayerTimesResult {
  final String fajr;
  final String sunrise;
  final String dhuhr;
  final String asr;
  final String maghrib;
  final String isha;
  final String nextPrayer;
  final Duration? timeToNextPrayer;
  final double qiblaDirection;
  final DateTime date;
  final LocationInfo location;

  const PrayerTimesResult({
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    required this.nextPrayer,
    this.timeToNextPrayer,
    required this.qiblaDirection,
    required this.date,
    required this.location,
  });

  Map<String, String> get allTimes => {
    'الفجر': fajr,
    'الشروق': sunrise,
    'الظهر': dhuhr,
    'العصر': asr,
    'المغرب': maghrib,
    'العشاء': isha,
  };
}

class LocationInfo {
  final double latitude;
  final double longitude;

  const LocationInfo({required this.latitude, required this.longitude});
}

enum TaskPriority { low, medium, high, critical }

class ScheduleTask {
  final String id;
  final String title;
  final String? description;
  final int estimatedMinutes;
  final TaskPriority priority;
  final String? preferredTimeSlot;

  const ScheduleTask({
    required this.id,
    required this.title,
    this.description,
    required this.estimatedMinutes,
    this.priority = TaskPriority.medium,
    this.preferredTimeSlot,
  });
}

class ScheduledItem {
  final ScheduleTask task;
  final String startTime;
  final String endTime;
  final int startMinutes;
  final int endMinutes;

  const ScheduledItem({
    required this.task,
    required this.startTime,
    required this.endTime,
    required this.startMinutes,
    required this.endMinutes,
  });
}

class ScheduleResult {
  final List<ScheduledItem> items;
  final double totalHours;
  final int tasksScheduled;
  final int tasksRemaining;
  final List<String> suggestions;

  const ScheduleResult({
    required this.items,
    required this.totalHours,
    required this.tasksScheduled,
    required this.tasksRemaining,
    required this.suggestions,
  });
}

class ParsedTime {
  final String originalText;
  final DateTime? parsedDateTime;
  final double confidence;
  final bool isRelative;

  const ParsedTime({
    required this.originalText,
    required this.parsedDateTime,
    required this.confidence,
    required this.isRelative,
  });

  bool get isValid => parsedDateTime != null && confidence > 0.5;
}

class _TimePattern {
  final RegExp regex;
  final DateTime Function(Match) builder;

  const _TimePattern(this.regex, this.builder);
}
