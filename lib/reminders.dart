import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';

/// Daily reminders to take temperatures, as a normal notification or a
/// loud, repeating "alarm" style notification.
class Reminders {
  Reminders._();
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static const _channelNormal = 'chillproof_reminders';
  static const _channelAlarm = 'chillproof_alarm';
  static const _baseId = 100;

  /// Set by the app; called when a reminder is tapped.
  static VoidCallback? onOpenedFromReminder;
  static bool launchedFromReminder = false;

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  static Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Europe/London'));
    }

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_chillproof'),
      ),
      onDidReceiveNotificationResponse: (_) => onOpenedFromReminder?.call(),
    );

    try {
      final launch = await _plugin.getNotificationAppLaunchDetails();
      launchedFromReminder = launch?.didNotificationLaunchApp ?? false;
    } catch (_) {}

    final android = _android;
    if (android != null) {
      await android.createNotificationChannel(const AndroidNotificationChannel(
        _channelNormal,
        'Temperature check reminders',
        description: 'Reminds you when it is time to record fridge and freezer temperatures.',
        importance: Importance.high,
      ));
      await android.createNotificationChannel(const AndroidNotificationChannel(
        _channelAlarm,
        'Temperature check alarms',
        description: 'Loud alarm-style reminders that keep sounding until opened.',
        importance: Importance.max,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ));
    }
  }

  /// Asks for notification permission (Android 13+) and, where possible,
  /// permission to ring at exact times. Returns true if notifications allowed.
  static Future<bool> requestPermissions() async {
    final android = _android;
    if (android == null) return true;
    final granted = await android.requestNotificationsPermission() ?? true;
    try {
      final exact = await android.canScheduleExactNotifications() ?? true;
      if (!exact) await android.requestExactAlarmsPermission();
    } catch (_) {}
    return granted;
  }

  static Future<void> schedule(AppSettings s) async {
    await _plugin.cancelAllPendingNotifications();
    if (!s.remindersOn || s.times.isEmpty) return;

    var mode = AndroidScheduleMode.inexactAllowWhileIdle;
    try {
      if (await _android?.canScheduleExactNotifications() ?? false) {
        mode = AndroidScheduleMode.exactAllowWhileIdle;
      }
    } catch (_) {}

    final alarm = s.style == ReminderStyle.alarm;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        alarm ? _channelAlarm : _channelNormal,
        alarm ? 'Temperature check alarms' : 'Temperature check reminders',
        importance: alarm ? Importance.max : Importance.high,
        priority: alarm ? Priority.max : Priority.high,
        category: alarm ? AndroidNotificationCategory.alarm : AndroidNotificationCategory.reminder,
        audioAttributesUsage: alarm ? AudioAttributesUsage.alarm : AudioAttributesUsage.notification,
        // FLAG_INSISTENT (4): repeat the sound until the notification is opened.
        additionalFlags: alarm ? Int32List.fromList(<int>[4]) : null,
        color: const Color(0xFF0B3D6E),
        ticker: 'Time to check temperatures',
      ),
    );

    for (var i = 0; i < s.times.length; i++) {
      final t = s.times[i];
      try {
        await _plugin.zonedSchedule(
          id: _baseId + i,
          title: 'Time to check temperatures',
          body: 'Tap to record your fridge and freezer readings (${t.label} check).',
          scheduledDate: _nextInstance(t.hour, t.minute),
          notificationDetails: details,
          androidScheduleMode: mode,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: 'take_temps',
        );
      } catch (e) {
        debugPrint('Failed to schedule reminder ${t.label}: $e');
      }
    }
  }

  static Future<void> cancelAll() => _plugin.cancelAllPendingNotifications();

  static tz.TZDateTime _nextInstance(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!at.isAfter(now)) {
      at = tz.TZDateTime(tz.local, now.year, now.month, now.day + 1, hour, minute);
    }
    return at;
  }
}
