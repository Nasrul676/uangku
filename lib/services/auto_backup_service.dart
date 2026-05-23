import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path/path.dart' as p;

import 'backup_service.dart';
import 'database_helper.dart';

const String _autoBackupTask = 'com.uangku.autoBackupTask';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isEnabled = prefs.getBool('auto_backup_enabled') ?? false;
      
      if (!isEnabled) {
        return true;
      }

      final destFolder = prefs.getString('auto_backup_folder');
      if (destFolder == null || destFolder.isEmpty) {
        return true;
      }

      final usePassword = prefs.getBool('auto_backup_use_password') ?? false;
      final password = usePassword ? prefs.getString('auto_backup_password') : null;

      // Pastikan koneksi database ditutup sebelum backup
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

      await AutoBackupService.showNotification(
        'Auto Backup Berhasil', 
        'Data berhasil dibackup ke: $fileName'
      );
      
      return true;
    } catch (e) {
      debugPrint('Auto Backup Error: $e');
      await AutoBackupService.showNotification(
        'Auto Backup Gagal', 
        'Terjadi kesalahan saat membackup data.'
      );
      return false;
    }
  });
}

class AutoBackupService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    // Notifikasi
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _notificationsPlugin.initialize(initSettings);

    // Workmanager
    await Workmanager().initialize(
      callbackDispatcher,
    );
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

  static Future<void> scheduleBackup(Duration frequency, {Duration? initialDelay}) async {
    await Workmanager().registerPeriodicTask(
      _autoBackupTask,
      _autoBackupTask,
      frequency: frequency,
      initialDelay: initialDelay,
    );
  }

  static Future<void> cancelBackup() async {
    await Workmanager().cancelByUniqueName(_autoBackupTask);
  }
}
