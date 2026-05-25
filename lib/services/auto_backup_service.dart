import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path/path.dart' as p;

import 'backup_service.dart';

const int _autoBackupAlarmId = 1001;

@pragma('vm:entry-point')
Future<void> callbackDispatcher() async {
  WidgetsFlutterBinding.ensureInitialized();
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
    final password = usePassword ? prefs.getString('auto_backup_password') : null;
    
    final zipFile = await BackupService.createBackup(password: password);
    
    final fileName = p.basename(zipFile.path);
    final destPath = p.join(destFolder, fileName);
    await zipFile.copy(destPath);
    
    if (await zipFile.exists()) {
      await zipFile.delete();
    }

    await AutoBackupService.showNotification(
      'Auto Backup Berhasil', 
      'Data berhasil dibackup ke: $fileName'
    );
    
  } catch (e) {
    debugPrint('Auto Backup Error: $e');
    await AutoBackupService.showNotification(
      'Auto Backup Gagal', 
      'Terjadi kesalahan saat membackup data.'
    );
  }
}

class AutoBackupService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
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
    const details = NotificationDetails(android: androidDetails);
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
