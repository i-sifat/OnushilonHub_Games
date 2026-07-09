// F-03: daily practice reminders.
//
// NotificationService is a singleton that wraps flutter_local_notifications.
// It initialises the Android channel on first use, requests the
// POST_NOTIFICATIONS permission on Android 13+, and exposes a clean API for
// scheduling / cancelling the single daily reminder.
//
// Notification preference (enabled + hour:minute) is persisted via
// SharedPreferences so the setting survives app restarts and reinstalls.

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

const _kPrefEnabled = 'notification_enabled';
const _kPrefHour = 'notification_hour';
const _kPrefMinute = 'notification_minute';
const _kChannelId = 'daily_practice';
const _kChannelName = 'Daily Practice';
const _kNotificationId = 1;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialised = false;

  // ── Initialisation ───────────────────────────────────────────────────────────

  /// Must be called once during app startup (before runApp).
  Future<void> initialize() async {
    if (_initialised) return;
    _initialised = true;

    // Initialise timezone database so zonedSchedule works correctly.
    await _initTimeZone();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );

    // Re-schedule the reminder on every cold start so it survives OS reboots.
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_kPrefEnabled) ?? false;
    if (enabled) {
      final hour = prefs.getInt(_kPrefHour) ?? 9;
      final minute = prefs.getInt(_kPrefMinute) ?? 0;
      await _scheduleImpl(hour, minute);
    }
  }

  Future<void> _initTimeZone() async {
    tz_data.initializeTimeZones();
    try {
      final String localTzName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTzName));
    } catch (e) {
      // Fall back to UTC if timezone detection fails.
      debugPrint('NotificationService: timezone detection failed ($e), using UTC');
    }
  }

  // ── Permission ─────────────────────────────────────────────────────────────

  /// Request POST_NOTIFICATIONS permission (Android 13+).
  /// Returns true if permission is granted or not required.
  Future<bool> requestPermission() async {
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl == null) return true;
    final granted = await androidImpl.requestNotificationsPermission();
    return granted ?? false;
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Schedule a daily reminder at [hour]:[minute].
  Future<void> scheduleDailyReminder(int hour, int minute) async {
    final hasPermission = await requestPermission();
    if (!hasPermission) {
      debugPrint('NotificationService: permission denied, skipping schedule');
      return;
    }
    await _plugin.cancel(_kNotificationId);
    await _scheduleImpl(hour, minute);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPrefEnabled, true);
    await prefs.setInt(_kPrefHour, hour);
    await prefs.setInt(_kPrefMinute, minute);
  }

  /// Cancel the daily reminder and clear the stored preference.
  Future<void> cancelDailyReminder() async {
    await _plugin.cancel(_kNotificationId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPrefEnabled, false);
  }

  /// Returns the saved reminder time, or null if no reminder is scheduled.
  Future<({int hour, int minute})?> getReminderTime() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_kPrefEnabled) ?? false;
    if (!enabled) return null;
    return (
      hour: prefs.getInt(_kPrefHour) ?? 9,
      minute: prefs.getInt(_kPrefMinute) ?? 0,
    );
  }

  // ── Internal ─────────────────────────────────────────────────────────────────

  Future<void> _scheduleImpl(int hour, int minute) async {
    const androidDetails = AndroidNotificationDetails(
      _kChannelId,
      _kChannelName,
      channelDescription: 'Daily vocabulary practice reminder',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const details = NotificationDetails(android: androidDetails);

    await _plugin.zonedSchedule(
      _kNotificationId,
      'Time to practice! \uD83D\uDCDA',
      'Your daily vocabulary session is waiting.',
      _nextInstanceOf(hour, minute),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now.add(const Duration(seconds: 5)))) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
