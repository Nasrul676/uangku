import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path/path.dart' as p;

import 'backup_service.dart';
import 'database_helper.dart';

const int _autoBackupAlarmId = 1001;

@pragma('vm:entry-point')
Future<void> callbackDispatcher() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool('auto_backup_enabled') ?? false;

    if (!isEnabled) {
      return;
    }

    final destFolder = prefs.getString('auto_backup_folder');
    if (destFolder == null || destFolder.isEmpty) {
      return;
    }

    final usePassword = prefs.getBool('auto_backup_use_password') ?? false;
    final password = usePassword
        ? prefs.getString('auto_backup_password')
        : null;

    // Pastikan koneksi database ditutup sebelum backup
    await DatabaseHelper.instance.checkpointDatabase();
    await DatabaseHelper.instance.closeDatabase();

    final zipFile = await BackupService.createBackup(password: password);

    // Copy to destination
    final fileName = p.basename(zipFile.path);
    final destPath = p.join(destFolder, fileName);
    await zipFile.copy(destPath);

    // Hapus file temp
    if (await zipFile.exists()) {
      await zipFile.delete();
    }

    final successNotification = {
      'title': 'Auto Backup Berhasil',
      'subtitle': 'Data berhasil dibackup ke: $fileName',
      'type': 'BACKUP_SUCCESS',
      'is_read': 0,
      'created_at': DateTime.now().toIso8601String(),
    };
    await DatabaseHelper.instance.insertNotification(successNotification);

    await AutoBackupService.showNotification(
      'Auto Backup Berhasil',
      'Data berhasil dibackup ke: $fileName',
    );

  } catch (e) {
    debugPrint('Auto Backup Error: $e');
    
    final errorNotification = {
      'title': 'Auto Backup Gagal',
      'subtitle': 'Terjadi kesalahan saat membackup data.',
      'type': 'BACKUP_FAILED',
      'is_read': 0,
      'created_at': DateTime.now().toIso8601String(),
    };
    await DatabaseHelper.instance.insertNotification(errorNotification);

    await AutoBackupService.showNotification(
      'Auto Backup Gagal',
      'Terjadi kesalahan saat membackup data.',
    );
  }
}

class AutoBackupService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
      macOS: iosInit,
    );
    await _notificationsPlugin.initialize(initSettings);

    await AndroidAlarmManager.initialize();
  }

  static Future<void> showNotification(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'auto_backup_channel',
      'Auto Backup Notifications',
      channelDescription: 'Notifications for automated backups',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );
    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }

  static Future<void> scheduleBackup(Duration frequency, {DateTime? startAt}) async {
    await AndroidAlarmManager.periodic(
      frequency,
      _autoBackupAlarmId,
      callbackDispatcher,
      startAt: startAt,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
    );
  }

  static Future<void> testBackupNow() async {
    await AndroidAlarmManager.oneShot(
      const Duration(seconds: 1),
      9999,
      callbackDispatcher,
      exact: true,
      wakeup: true,
    );
  }

  static Future<void> cancelBackup() async {
    await AndroidAlarmManager.cancel(_autoBackupAlarmId);
  }
}
