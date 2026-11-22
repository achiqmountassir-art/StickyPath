import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'challenge_progress.dart';
import 'custom_task.dart';

/// Schedules local reminders for [CustomTask]s. No-ops on unsupported platforms.
class TaskNotificationService {
  TaskNotificationService._();

  static final TaskNotificationService instance = TaskNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;
  bool _permissionDenied = false;

  bool get isReady => _ready;
  bool get permissionDenied => _permissionDenied;

  Future<void> init() async {
    if (kIsWeb) return;
    try {
      tz_data.initializeTimeZones();
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name.identifier));
    } catch (error) {
      debugPrint('Sticky Path timezone setup failed: $error');
      try {
        tz_data.initializeTimeZones();
        tz.setLocalLocation(tz.UTC);
      } catch (_) {}
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(android: android, iOS: ios);

    try {
      await _plugin.initialize(settings: settings);
      _ready = true;
    } catch (error) {
      debugPrint('Sticky Path notifications init failed: $error');
      _ready = false;
    }
  }

  /// Asks for permission the first time the user sets a reminder.
  Future<bool> requestPermission() async {
    if (!_ready || kIsWeb) return false;

    if (Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final granted = await android?.requestNotificationsPermission();
      if (granted == false) {
        _permissionDenied = true;
        return false;
      }
      await android?.requestExactAlarmsPermission();
    } else if (Platform.isIOS) {
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      final granted = await ios?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      if (granted == false) {
        _permissionDenied = true;
        return false;
      }
    }
    _permissionDenied = false;
    return true;
  }

  Future<void> syncTask({
    required CustomTask task,
    required DateTime taskDate,
    required String challengeId,
  }) async {
    await cancel(task.notificationId);
    if (!_ready ||
        task.completed ||
        task.reminderMinutes == null ||
        kIsWeb) {
      return;
    }

    final allowed = _permissionDenied ? false : await requestPermission();
    if (!allowed && _permissionDenied) return;

    final minutes = task.reminderMinutes!;
    final when = tz.TZDateTime(
      tz.local,
      taskDate.year,
      taskDate.month,
      taskDate.day,
      minutes ~/ 60,
      minutes % 60,
    );
    if (!when.isAfter(tz.TZDateTime.now(tz.local))) return;

    const androidDetails = AndroidNotificationDetails(
      'sticky_path_tasks',
      'Task reminders',
      channelDescription: 'Reminders for custom StickyPath tasks',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _plugin.zonedSchedule(
        id: task.notificationId,
        title: 'StickyPath',
        body: task.title,
        scheduledDate: when,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: '$challengeId|${task.id}',
      );
    } catch (error) {
      debugPrint('Sticky Path could not schedule reminder: $error');
      try {
        await _plugin.zonedSchedule(
          id: task.notificationId,
          title: 'StickyPath',
          body: task.title,
          scheduledDate: when,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: '$challengeId|${task.id}',
        );
      } catch (fallback) {
        debugPrint('Sticky Path reminder fallback failed: $fallback');
      }
    }
  }

  Future<void> cancel(int notificationId) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: notificationId);
    } catch (error) {
      debugPrint('Sticky Path could not cancel reminder: $error');
    }
  }

  Future<void> cancelAll(Iterable<CustomTask> tasks) async {
    for (final task in tasks) {
      await cancel(task.notificationId);
    }
  }

  /// Reschedules every incomplete task that still has a reminder.
  Future<void> rescheduleAll({
    required Iterable<CustomTask> tasks,
    required DateTime Function(int dayNumber) dateForDay,
    required String challengeId,
  }) async {
    for (final task in tasks) {
      await syncTask(
        task: task,
        taskDate: dateOnly(dateForDay(task.dayNumber)),
        challengeId: challengeId,
      );
    }
  }
}
