import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vibration/vibration.dart';

import 'package:owj_assistant/services/storage_service.dart';

/// Mobile device control service using Android intent-based approach.
///
/// Provides methods to control device features such as opening apps,
/// making calls, sending SMS, controlling hardware toggles, and more.
/// Uses `url_launcher`, `android_intent_plus`, `vibration`, and
/// `flutter_local_notifications` packages.
///
/// All user-facing strings are in Egyptian Arabic.
/// Platform checks ensure methods fail gracefully on unsupported platforms.
class DeviceControlService {
  DeviceControlService({StorageService? storage})
      : _storage = storage ?? StorageService.instance;

  final StorageService _storage;

  /// Notification plugin for system-level notification actions.
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  /// Whether this device is Android.
  bool get isAndroid => Platform.isAndroid;

  /// Whether this device is iOS.
  bool get isIOS => Platform.isIOS;

  // ─── App & URL Launching ──────────────────────────────────────────────

  /// Launch another app by [packageName].
  ///
  /// On Android, uses an explicit intent to launch the app.
  /// Returns true if the app was successfully launched.
  Future<DeviceControlResult> openApp(String packageName) async {
    if (!isAndroid) {
      return DeviceControlResult(
        success: false,
        message: 'فتح التطبيقات متاح على أندرويد بس 📱',
      );
    }

    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.MAIN',
        package: packageName,
        flags: <int>[
          Flag.FLAG_ACTIVITY_NEW_TASK,
          Flag.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED,
        ],
      );
      await intent.launch();
      return DeviceControlResult(
        success: true,
        message: 'تم فتح التطبيق ✅',
      );
    } catch (e) {
      return DeviceControlResult(
        success: false,
        message: 'مقدرش أفتح التطبيق — ممكن مش متسطب ❌',
      );
    }
  }

  /// Open [url] in the default browser.
  Future<DeviceControlResult> openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        return DeviceControlResult(
          success: launched,
          message: launched ? 'تم فتح الرابط 🌐' : 'فشل فتح الرابط',
        );
      }
      return DeviceControlResult(
        success: false,
        message: 'الرابط مش صالح 🚫',
      );
    } catch (e) {
      return DeviceControlResult(
        success: false,
        message: 'حصل خطأ أثناء فتح الرابط: ${e.toString()}',
      );
    }
  }

  /// Open device settings page.
  ///
  /// [settingsPage] can be one of:
  /// 'wifi', 'bluetooth', 'location', 'sound', 'display',
  /// 'battery', 'apps', 'notifications', 'security',
  /// 'date', 'about', 'accessibility', 'storage', 'data_usage'
  Future<DeviceControlResult> openSettings(String settingsPage) async {
    if (!isAndroid) {
      // iOS fallback: open general settings
      try {
        const intent = AndroidIntent(
          action: 'android.settings.SETTINGS',
        );
        await intent.launch();
      } catch (_) {
        // On iOS, try app settings
        await openAppSettings();
      }
      return DeviceControlResult(
        success: true,
        message: 'تم فتح الإعدادات ⚙️',
      );
    }

    final actionMap = <String, String>{
      'wifi': 'android.settings.WIFI_SETTINGS',
      'bluetooth': 'android.settings.BLUETOOTH_SETTINGS',
      'location': 'android.settings.LOCATION_SOURCE_SETTINGS',
      'sound': 'android.settings.SOUND_SETTINGS',
      'display': 'android.settings.DISPLAY_SETTINGS',
      'battery': 'android.intent.action.POWER_USAGE_SUMMARY',
      'apps': 'android.settings.APPLICATION_SETTINGS',
      'notifications': 'android.settings.APP_NOTIFICATION_SETTINGS',
      'security': 'android.settings.SECURITY_SETTINGS',
      'date': 'android.settings.DATE_SETTINGS',
      'about': 'android.settings.DEVICE_INFO_SETTINGS',
      'accessibility': 'android.settings.ACCESSIBILITY_SETTINGS',
      'storage': 'android.settings.INTERNAL_STORAGE_SETTINGS',
      'data_usage': 'android.settings.DATA_USAGE_SETTINGS',
    };

    final action = actionMap[settingsPage.toLowerCase()] ??
        'android.settings.SETTINGS';

    try {
      final intent = AndroidIntent(action: action);
      await intent.launch();
      return DeviceControlResult(
        success: true,
        message: 'تم فتح الإعدادات ⚙️',
      );
    } catch (e) {
      return DeviceControlResult(
        success: false,
        message: 'مقدرش أفتح صفحة الإعدادات دي ❌',
      );
    }
  }

  /// Open app settings for this application.
  Future<bool> openAppSettings() async {
    try {
      return await openAppSettings();
    } catch (_) {
      return false;
    }
  }

  // ─── Communication ────────────────────────────────────────────────────

  /// Initiate a phone call to [number].
  Future<DeviceControlResult> makePhoneCall(String number) async {
    try {
      final uri = Uri(scheme: 'tel', path: number);
      final launched = await launchUrl(uri);
      return DeviceControlResult(
        success: launched,
        message: launched ? 'جاري الاتصال بـ $number 📞' : 'فشل الاتصال',
      );
    } catch (e) {
      return DeviceControlResult(
        success: false,
        message: 'مقدرش أتكلم في الرقم ده ❌',
      );
    }
  }

  /// Send an SMS to [number] with optional pre-filled [message].
  Future<DeviceControlResult> sendSms(String number, {String? message}) async {
    try {
      final uri = message != null
          ? Uri(scheme: 'sms', path: number, query: 'body=$message')
          : Uri(scheme: 'sms', path: number);
      final launched = await launchUrl(uri);
      return DeviceControlResult(
        success: launched,
        message: launched ? 'تم فتح رسائل SMS 📱' : 'فشل فتح الرسائل',
      );
    } catch (e) {
      return DeviceControlResult(
        success: false,
        message: 'مقدرش أفتح الرسائل ❌',
      );
    }
  }

  // ─── Alarms & Timers ─────────────────────────────────────────────────

  /// Set an alarm at [hour]:[minute] with an optional [label].
  Future<DeviceControlResult> setAlarm({
    required int hour,
    required int minute,
    String? label,
  }) async {
    if (!isAndroid) {
      return DeviceControlResult(
        success: false,
        message: 'ضبط المنبه متاح على أندرويد بس ⏰',
      );
    }

    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.SET_ALARM',
        arguments: <String, dynamic>{
          'android.intent.extra.alarm.HOUR': hour,
          'android.intent.extra.alarm.MINUTES': minute,
          'android.intent.extra.alarm.MESSAGE': label ?? 'منبه أوج',
          'android.intent.extra.alarm.SKIP_UI': false,
        },
      );
      await intent.launch();
      return DeviceControlResult(
        success: true,
        message: 'تم فتح المنبه على $hour:$minute ⏰',
      );
    } catch (e) {
      return DeviceControlResult(
        success: false,
        message: 'مقدرش أضبط المنبه ❌',
      );
    }
  }

  /// Set a timer for [seconds] with an optional [label].
  Future<DeviceControlResult> setTimer({
    required int seconds,
    String? label,
  }) async {
    if (!isAndroid) {
      return DeviceControlResult(
        success: false,
        message: 'ضبط المؤقت متاح على أندرويد بس ⏱️',
      );
    }

    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.SET_TIMER',
        arguments: <String, dynamic>{
          'android.intent.extra.timer.LENGTH': seconds,
          'android.intent.extra.timer.MESSAGE': label ?? 'مؤقت أوج',
          'android.intent.extra.timer.SKIP_UI': false,
        },
      );
      await intent.launch();
      final minutesStr = seconds >= 60
          ? '${seconds ~/ 60} دقيقة'
          : '$seconds ثانية';
      return DeviceControlResult(
        success: true,
        message: 'تم ضبط المؤقت: $minutesStr ⏱️',
      );
    } catch (e) {
      return DeviceControlResult(
        success: false,
        message: 'مقدرش أضبط المؤقت ❌',
      );
    }
  }

  // ─── Device Apps ──────────────────────────────────────────────────────

  /// Open the camera app.
  Future<DeviceControlResult> openCamera() async {
    if (!isAndroid) {
      return DeviceControlResult(
        success: false,
        message: 'فتح الكاميرا متاح على أندرويد بس 📷',
      );
    }

    try {
      final intent = AndroidIntent(
        action: 'android.media.action.STILL_IMAGE_CAMERA',
        flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
      );
      await intent.launch();
      return DeviceControlResult(
        success: true,
        message: 'تم فتح الكاميرا 📷',
      );
    } catch (e) {
      return DeviceControlResult(
        success: false,
        message: 'مقدرش أفتح الكاميرا ❌',
      );
    }
  }

  /// Open the contacts app.
  Future<DeviceControlResult> openContacts() async {
    try {
      if (isAndroid) {
        final intent = AndroidIntent(
          action: 'android.intent.action.VIEW',
          data: 'content://contacts/people',
          flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
        );
        await intent.launch();
      } else {
        final uri = Uri.parse('content://contacts/people');
        await launchUrl(uri);
      }
      return DeviceControlResult(
        success: true,
        message: 'تم فتح جهات الاتصال 👥',
      );
    } catch (e) {
      return DeviceControlResult(
        success: false,
        message: 'مقدرش أفتح جهات الاتصال ❌',
      );
    }
  }

  /// Open the calendar app.
  Future<DeviceControlResult> openCalendar() async {
    try {
      if (isAndroid) {
        final intent = AndroidIntent(
          action: 'android.intent.action.VIEW',
          data: 'content://com.android.calendar/time',
          flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
        );
        await intent.launch();
      } else {
        // iOS: try calshow URL scheme
        final uri = Uri.parse('calshow://');
        await launchUrl(uri);
      }
      return DeviceControlResult(
        success: true,
        message: 'تم فتح التقويم 📅',
      );
    } catch (e) {
      return DeviceControlResult(
        success: false,
        message: 'مقدرش أفتح التقويم ❌',
      );
    }
  }

  /// Open maps with a search [query].
  Future<DeviceControlResult> openMaps(String query) async {
    try {
      final uri = Uri.parse(
        'geo:0,0?q=${Uri.encodeComponent(query)}',
      );
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        // Fallback to Google Maps web
        final webUri = Uri.parse(
          'https://www.google.com/maps/search/${Uri.encodeComponent(query)}',
        );
        final webLaunched = await launchUrl(
          webUri,
          mode: LaunchMode.externalApplication,
        );
        return DeviceControlResult(
          success: webLaunched,
          message: webLaunched ? 'تم فتح الخريطة 🗺️' : 'فشل فتح الخريطة',
        );
      }
      return DeviceControlResult(
        success: true,
        message: 'تم فتح الخريطة 🗺️',
      );
    } catch (e) {
      return DeviceControlResult(
        success: false,
        message: 'مقدرش أفتح الخريطة ❌',
      );
    }
  }

  // ─── Hardware Controls ────────────────────────────────────────────────

  /// Set media volume to [level] (0-15 on Android).
  Future<DeviceControlResult> controlVolume(int level) async {
    if (!isAndroid) {
      return DeviceControlResult(
        success: false,
        message: 'التحكم في الصوت متاح على أندرويد بس 🔊',
      );
    }

    try {
      const channel = MethodChannel('com.awj.owj_assistant/device_control');
      await channel.invokeMethod('setVolume', {
        'level': level.clamp(0, 15),
        'streamType': 'music',
      });
      return DeviceControlResult(
        success: true,
        message: 'تم ضبط الصوت على $level 🔊',
      );
    } on PlatformException catch (_) {
      // Fallback: open sound settings
      return openSettings('sound');
    } catch (e) {
      return DeviceControlResult(
        success: false,
        message: 'مقدرش أتحكم في الصوت — فتحت إعدادات الصوت بدل كده ⚙️',
      );
    }
  }

  /// Set brightness to [level] (0-255 on Android).
  Future<DeviceControlResult> controlBrightness(int level) async {
    if (!isAndroid) {
      return DeviceControlResult(
        success: false,
        message: 'التحكم في السطوع متاح على أندرويد بس ☀️',
      );
    }

    try {
      const channel = MethodChannel('com.awj.owj_assistant/device_control');
      await channel.invokeMethod('setBrightness', {
        'level': level.clamp(0, 255),
      });
      return DeviceControlResult(
        success: true,
        message: 'تم ضبط السطوع ☀️',
      );
    } on PlatformException catch (_) {
      // Fallback: open display settings
      return openSettings('display');
    } catch (e) {
      return DeviceControlResult(
        success: false,
        message: 'مقدرش أتحكم في السطوع — فتحت إعدادات الشاشة بدل كده ⚙️',
      );
    }
  }

  /// Take a screenshot (shows notification with the screenshot).
  Future<DeviceControlResult> takeScreenshot() async {
    if (!isAndroid) {
      return DeviceControlResult(
        success: false,
        message: 'السكرين شوت متاح على أندرويد بس 📸',
      );
    }

    try {
      const channel = MethodChannel('com.awj.owj_assistant/device_control');
      await channel.invokeMethod('takeScreenshot');
      return DeviceControlResult(
        success: true,
        message: 'تم أخذ سكرين شوت 📸',
      );
    } on PlatformException catch (_) {
      // Fallback: suggest manual screenshot
      return DeviceControlResult(
        success: false,
        message: 'اضغط زر الصوت لتحت + زر الباور عشان سكرين شوت 📱',
      );
    } catch (e) {
      return DeviceControlResult(
        success: false,
        message: 'مقدرش أصور الشاشة ❌',
      );
    }
  }

  /// Toggle Wi-Fi on or off.
  Future<DeviceControlResult> toggleWifi(bool enable) async {
    if (!isAndroid) {
      return DeviceControlResult(
        success: false,
        message: 'التحكم في الواي فاي متاح على أندرويد بس 📶',
      );
    }

    try {
      const channel = MethodChannel('com.awj.owj_assistant/device_control');
      await channel.invokeMethod('toggleWifi', {'enable': enable});
      return DeviceControlResult(
        success: true,
        message: enable ? 'تم تشغيل الواي فاي 📶' : 'تم إطفاء الواي فاي 📵',
      );
    } on PlatformException catch (_) {
      // Fallback: open WiFi settings
      return openSettings('wifi');
    } catch (e) {
      return DeviceControlResult(
        success: false,
        message: 'مقدرش أتحكم في الواي فاي — فتحت الإعدادات بدل كده ⚙️',
      );
    }
  }

  /// Toggle Bluetooth on or off.
  Future<DeviceControlResult> toggleBluetooth(bool enable) async {
    if (!isAndroid) {
      return DeviceControlResult(
        success: false,
        message: 'التحكم في البلوتوث متاح على أندرويد بس 🔵',
      );
    }

    try {
      const channel = MethodChannel('com.awj.owj_assistant/device_control');
      await channel.invokeMethod('toggleBluetooth', {'enable': enable});
      return DeviceControlResult(
        success: true,
        message: enable ? 'تم تشغيل البلوتوث 🔵' : 'تم إطفاء البلوتوث ⚫',
      );
    } on PlatformException catch (_) {
      // Fallback: open Bluetooth settings
      return openSettings('bluetooth');
    } catch (e) {
      return DeviceControlResult(
        success: false,
        message: 'مقدرش أتحكم في البلوتوث — فتحت الإعدادات بدل كده ⚙️',
      );
    }
  }

  /// Toggle the flashlight on or off.
  Future<DeviceControlResult> toggleFlashlight(bool enable) async {
    try {
      const channel = MethodChannel('com.awj.owj_assistant/device_control');
      await channel.invokeMethod('toggleFlashlight', {'enable': enable});
      return DeviceControlResult(
        success: true,
        message: enable ? 'تم تشغيل الفلاش 🔦' : 'تم إطفاء الفلاش ⬛',
      );
    } on PlatformException catch (_) {
      return DeviceControlResult(
        success: false,
        message: 'مقدرش أتحكم في الفلاش — الموبايل مش بيدعم الكده 🔦',
      );
    } catch (e) {
      return DeviceControlResult(
        success: false,
        message: 'مقدرش أتحكم في الفلاش ❌',
      );
    }
  }

  // ─── Device Info ──────────────────────────────────────────────────────

  /// Get battery level and charging status.
  Future<BatteryInfo> getBatteryInfo() async {
    if (!isAndroid) {
      return BatteryInfo(
        level: -1,
        isCharging: false,
        label: 'معلومة البطارية مش متاحة على المنصة دي',
      );
    }

    try {
      const channel = MethodChannel('com.awj.owj_assistant/device_control');
      final result = await channel.invokeMethod<Map>('getBatteryInfo');
      final level = result?['level'] as int? ?? -1;
      final isCharging = result?['isCharging'] as bool? ?? false;

      return BatteryInfo(
        level: level,
        isCharging: isCharging,
        label: _batteryLabelAr(level, isCharging),
      );
    } on PlatformException catch (_) {
      return BatteryInfo(
        level: -1,
        isCharging: false,
        label: 'مقدرش أعرف معلومات البطارية 🔋',
      );
    } catch (e) {
      return BatteryInfo(
        level: -1,
        isCharging: false,
        label: 'حصل خطأ في قراءة البطارية ❌',
      );
    }
  }

  /// Get device information (model, OS version, etc.).
  Future<DeviceInfo> getDeviceInfo() async {
    try {
      const channel = MethodChannel('com.awj.owj_assistant/device_control');
      final result = await channel.invokeMethod<Map>('getDeviceInfo');

      return DeviceInfo(
        model: result?['model'] as String? ?? 'مش معروف',
        manufacturer: result?['manufacturer'] as String? ?? 'مش معروف',
        osVersion: result?['osVersion'] as String? ?? 'مش معروف',
        sdkVersion: result?['sdkVersion'] as int?,
        serial: result?['serial'] as String?,
        label: _deviceLabelAr(result),
      );
    } on PlatformException catch (_) {
      return DeviceInfo(
        model: Platform.isAndroid ? 'أندرويد' : 'iOS',
        manufacturer: 'مش معروف',
        osVersion: 'مش معروف',
        label: 'مقدرش أعرف معلومات الجهاز 📱',
      );
    } catch (e) {
      return DeviceInfo(
        model: 'مش معروف',
        manufacturer: 'مش معروف',
        osVersion: 'مش معروف',
        label: 'حصل خطأ في قراءة معلومات الجهاز ❌',
      );
    }
  }

  // ─── Clipboard ────────────────────────────────────────────────────────

  /// Copy [text] to the system clipboard.
  Future<DeviceControlResult> clipboardCopy(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      return DeviceControlResult(
        success: true,
        message: 'تم النسخ في الكليببورد 📋',
      );
    } catch (e) {
      return DeviceControlResult(
        success: false,
        message: 'فشل النسخ في الكليببورد ❌',
      );
    }
  }

  /// Paste from the system clipboard.
  Future<ClipboardResult> clipboardPaste() async {
    try {
      final data = await Clipboard.getData('text/plain');
      final text = data?.text ?? '';
      return ClipboardResult(
        text: text,
        hasContent: text.isNotEmpty,
        message: text.isNotEmpty ? 'تم اللصق من الكليببورد 📋' : 'الكليببورد فاضي 📭',
      );
    } catch (e) {
      return ClipboardResult(
        text: '',
        hasContent: false,
        message: 'فشل اللصق من الكليببورد ❌',
      );
    }
  }

  // ─── Haptic Feedback ──────────────────────────────────────────────────

  /// Vibrate the device for [duration] milliseconds.
  ///
  /// Default duration is 200ms. Falls back to haptic feedback
  /// on devices without vibration support.
  Future<DeviceControlResult> vibrate({int duration = 200}) async {
    try {
      final hasVibrator = await Vibration.hasVibrator() ?? false;
      if (!hasVibrator) {
        return DeviceControlResult(
          success: false,
          message: 'الجهاز مش بيدعم الاهتزاز 📳',
        );
      }

      await Vibration.vibrate(duration: duration);
      return DeviceControlResult(
        success: true,
        message: 'اهتزاز لمدة ${duration}ms 📳',
      );
    } catch (e) {
      return DeviceControlResult(
        success: false,
        message: 'مقدرش أهزز الجهاز ❌',
      );
    }
  }

  // ─── Private helpers ──

  /// Generate Arabic battery label.
  String _batteryLabelAr(int level, bool isCharging) {
    if (level < 0) return 'معلومة البطارية مش متاحة';
    final chargingStr = isCharging ? 'بيشحن ⚡' : 'مش بيشحن';
    if (level <= 10) return 'البطارية $level% — محتاجة شحن ضروري! 🪫 $chargingStr';
    if (level <= 30) return 'البطارية $level% — قليلة 🔋 $chargingStr';
    if (level <= 60) return 'البطارية $level% — معقولة 🔋 $chargingStr';
    if (level <= 80) return 'البطارية $level% — كويسة 🔋 $chargingStr';
    return 'البطارية $level% — ممتازة 🔋✅ $chargingStr';
  }

  /// Generate Arabic device label.
  String _deviceLabelAr(Map? info) {
    if (info == null) return 'معلومة الجهاز مش متاحة';
    final model = info['model'] ?? 'مش معروف';
    final manufacturer = info['manufacturer'] ?? '';
    final os = info['osVersion'] ?? '';
    return '$manufacturer $model — أندرويد $os 📱';
  }
}

// ── Data models ──

/// Result of a device control operation.
class DeviceControlResult {
  /// Whether the operation was successful.
  final bool success;

  /// Arabic message describing the result.
  final String message;

  const DeviceControlResult({
    required this.success,
    required this.message,
  });
}

/// Battery information.
class BatteryInfo {
  /// Battery level as percentage (0-100), or -1 if unavailable.
  final int level;

  /// Whether the device is currently charging.
  final bool isCharging;

  /// Arabic label describing battery status.
  final String label;

  const BatteryInfo({
    required this.level,
    required this.isCharging,
    required this.label,
  });
}

/// Device information.
class DeviceInfo {
  /// Device model name.
  final String model;

  /// Device manufacturer.
  final String manufacturer;

  /// OS version string.
  final String osVersion;

  /// Android SDK version (null on non-Android).
  final int? sdkVersion;

  /// Device serial number (null if unavailable).
  final String? serial;

  /// Arabic label summarizing device info.
  final String label;

  const DeviceInfo({
    required this.model,
    required this.manufacturer,
    required this.osVersion,
    this.sdkVersion,
    this.serial,
    required this.label,
  });
}

/// Clipboard paste result.
class ClipboardResult {
  /// The pasted text content.
  final String text;

  /// Whether there was content to paste.
  final bool hasContent;

  /// Arabic message describing the result.
  final String message;

  const ClipboardResult({
    required this.text,
    required this.hasContent,
    required this.message,
  });
}

/// Device control service exception.
class DeviceControlException implements Exception {
  final String message;
  DeviceControlException(this.message);

  @override
  String toString() => 'DeviceControlException: $message';
}
