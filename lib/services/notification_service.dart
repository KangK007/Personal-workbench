import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'windows_activity_service.dart';

int stableNotificationId(String value) {
  var hash = 0x811c9dc5;
  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash == 0 ? 1 : hash;
}

class NotificationService {
  NotificationService({WindowsActivityService? windowsActivityService})
    : _windowsActivityService =
          windowsActivityService ?? WindowsActivityService();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final WindowsActivityService _windowsActivityService;
  final Map<int, Timer> _windowsTimers = {};

  bool _initialized = false;
  Future<void>? _initializing;
  bool get initialized => _initialized;
  bool get supportsSystemNotifications =>
      Platform.isAndroid || (Platform.isWindows && _initialized);

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    final pending = _initializing;
    if (pending != null) return pending;
    final operation = _initialize();
    _initializing = operation;
    try {
      await operation;
    } finally {
      _initializing = null;
    }
  }

  Future<void> _initialize() async {
    tz_data.initializeTimeZones();
    if (Platform.isAndroid) {
      try {
        final zone = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(zone.identifier));
      } catch (error) {
        debugPrint('Unable to resolve local timezone: $error');
        // The bundled timezone database stays usable if platform lookup fails.
      }
    }

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    try {
      if (Platform.isWindows) {
        _initialized = await _windowsActivityService.bridgeAvailable();
      } else {
        _initialized = await _plugin.initialize(settings) ?? false;
      }
    } catch (error) {
      debugPrint('Unable to initialize notifications: $error');
      _initialized = false;
    }
  }

  Future<bool> requestPermission() async {
    if (!supportsSystemNotifications) return false;
    if (!_initialized) await initialize();
    if (Platform.isWindows) return _initialized;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestNotificationsPermission() ?? false;
  }

  Future<void> scheduleTaskReminder({
    required int id,
    required String title,
    required DateTime when,
    String? body,
  }) async {
    if (!supportsSystemNotifications) return;
    if (!_initialized) await initialize();
    if (!_initialized || !when.isAfter(DateTime.now())) return;
    if (Platform.isWindows) {
      _scheduleWindows(
        id: id,
        title: title,
        body: body ?? '任务时间到了',
        when: when,
      );
      return;
    }

    await _plugin.zonedSchedule(
      id,
      title,
      body ?? '任务时间到了',
      tz.TZDateTime.from(when, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'task_reminders',
          '任务提醒',
          channelDescription: '任务、时间块和每日回顾提醒',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'task:$id',
    );
  }

  Future<void> scheduleDailyReminder({
    required int id,
    required String title,
    required String body,
    required DateTime firstAt,
  }) async {
    if (!supportsSystemNotifications) return;
    if (!_initialized) await initialize();
    if (!_initialized || !firstAt.isAfter(DateTime.now())) return;
    if (Platform.isWindows) {
      _scheduleWindowsDaily(id: id, title: title, body: body, firstAt: firstAt);
      return;
    }
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(firstAt, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'review_overdue',
          '逾期回顾',
          channelDescription: '未完成回顾的每日追踪提醒',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'review-overdue:$id',
    );
  }

  Future<void> showNow({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!supportsSystemNotifications) return;
    if (!_initialized) await initialize();
    if (!_initialized) return;
    if (Platform.isWindows) {
      await _windowsActivityService.showNotification(title: title, body: body);
      return;
    }
    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'workbench_updates',
          '工作台提醒',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
    );
  }

  Future<void> scheduleFocusEnd({
    required int id,
    required String taskTitle,
    required DateTime when,
    required int restMinutes,
  }) async {
    if (!supportsSystemNotifications) return;
    if (!_initialized) await initialize();
    if (!_initialized || !when.isAfter(DateTime.now())) return;
    if (Platform.isWindows) {
      _scheduleWindows(
        id: id,
        title: '专注时间结束',
        body: '$taskTitle · 建议休息 $restMinutes 分钟',
        when: when,
      );
      return;
    }
    await _plugin.zonedSchedule(
      id,
      '专注时间结束',
      '$taskTitle · 建议休息 $restMinutes 分钟',
      tz.TZDateTime.from(when, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'focus_sessions',
          '专注计时',
          channelDescription: '专注计时结束与休息提醒',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'focus:$id',
    );
  }

  Future<void> cancel(int id) {
    if (!supportsSystemNotifications) return Future.value();
    _windowsTimers.remove(id)?.cancel();
    if (Platform.isWindows) return Future.value();
    return _plugin.cancel(id);
  }

  void _scheduleWindows({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) {
    _windowsTimers.remove(id)?.cancel();
    final delay = when.difference(DateTime.now());
    if (delay <= Duration.zero) return;
    _windowsTimers[id] = Timer(delay, () {
      _windowsTimers.remove(id);
      _windowsActivityService.showNotification(title: title, body: body);
    });
  }

  void _scheduleWindowsDaily({
    required int id,
    required String title,
    required String body,
    required DateTime firstAt,
  }) {
    _windowsTimers.remove(id)?.cancel();
    void schedule(DateTime when) {
      final delay = when.difference(DateTime.now());
      if (delay <= Duration.zero) return;
      _windowsTimers[id] = Timer(delay, () {
        _windowsActivityService.showNotification(title: title, body: body);
        schedule(when.add(const Duration(days: 1)));
      });
    }

    schedule(firstAt);
  }

  void dispose() {
    for (final timer in _windowsTimers.values) {
      timer.cancel();
    }
    _windowsTimers.clear();
  }
}
