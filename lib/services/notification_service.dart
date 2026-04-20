import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/financial_plan.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const _channelId = 'financial_plan_channel';
  static const _channelName = 'Rencana Keuangan';
  static const _channelDescription = 'Pengingat rencana keuangan jatuh tempo';
  static const _planNotificationBaseId = 800000;
  static const _demoNotificationId = 899999;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    await _configureLocalTimezone();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: iosSettings,
    );

    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  Future<void> requestPermissions() async {
    await init();

    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);

    final macos = _plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >();
    await macos?.requestPermissions(alert: true, badge: true, sound: true);

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
  }

  Future<void> scheduleFinancialPlanNotifications({
    required List<FinancialPlan> plans,
    required int hour,
    required int minute,
  }) async {
    await init();
    await cancelFinancialPlanNotifications();

    for (final plan in plans) {
      final id = plan.id;
      if (id == null) continue;

      final parsedTargetDate = DateTime.tryParse(plan.targetDate);
      if (parsedTargetDate == null) continue;

      final scheduleTime = DateTime(
        parsedTargetDate.year,
        parsedTargetDate.month,
        parsedTargetDate.day,
        hour,
        minute,
      );

      if (scheduleTime.isBefore(DateTime.now())) continue;

      final body =
          'Rencana "${plan.title}" sudah masuk tanggal target. Cek progresnya sekarang.';

      await _plugin.zonedSchedule(
        _planNotificationBaseId + id,
        'Pengingat Rencana Keuangan',
        body,
        tz.TZDateTime.from(scheduleTime, tz.local),
        _notificationDetails(),
        payload: 'financial-plan:$id',
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<void> cancelFinancialPlanNotifications() async {
    await init();

    final pending = await _plugin.pendingNotificationRequests();
    for (final item in pending) {
      if (item.id >= _planNotificationBaseId && item.id < _demoNotificationId) {
        await _plugin.cancel(item.id);
      }
    }
  }

  Future<void> showDemoNotification() async {
    await init();

    await _plugin.show(
      _demoNotificationId,
      'Demo Notifikasi Aktif',
      'Ini contoh notifikasi rencana keuangan dari pengaturan aplikasi.',
      _notificationDetails(),
      payload: 'financial-plan:demo',
    );
  }

  NotificationDetails _notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    );
  }

  Future<void> _configureLocalTimezone() async {
    if (!(Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) return;

    try {
      final localTimezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTimezone.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
  }
}
