import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
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

    // Checkpoint WAL sebelum backup agar data konsisten, tapi JANGAN tutup database
    // karena BackupService butuh koneksi aktif untuk membuat SQL dump.
    await DatabaseHelper.instance.checkpointDatabase();

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

    try {
      final errorNotification = {
        'title': 'Auto Backup Gagal',
        'subtitle': 'Error: ${e.toString().length > 100 ? e.toString().substring(0, 100) : e.toString()}',
        'type': 'BACKUP_FAILED',
        'is_read': 0,
        'created_at': DateTime.now().toIso8601String(),
      };
      await DatabaseHelper.instance.insertNotification(errorNotification);
    } catch (_) {
      // Abaikan error saat menyimpan notifikasi gagal
    }

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

    if (!kIsWeb && Platform.isAndroid) {
      await AndroidAlarmManager.initialize();
    }
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

  static Future<void> scheduleBackup(
    Duration frequency, {
    DateTime? startAt,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return;
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

  /// Menjalankan backup langsung (untuk tombol test di UI).
  /// Mengembalikan nama file ZIP jika berhasil, atau melempar exception jika gagal.
  static Future<String> runBackupNow() async {
    final prefs = await SharedPreferences.getInstance();
    final destFolder = prefs.getString('auto_backup_folder') ?? '';
    if (destFolder.isEmpty) {
      throw Exception('Folder penyimpanan belum dipilih. Pilih folder terlebih dahulu.');
    }

    final usePassword = prefs.getBool('auto_backup_use_password') ?? false;
    final password = usePassword ? prefs.getString('auto_backup_password') : null;

    // Checkpoint WAL agar data konsisten sebelum backup
    await DatabaseHelper.instance.checkpointDatabase();

    final zipFile = await BackupService.createBackup(password: password);

    final fileName = p.basename(zipFile.path);
    final destPath = p.join(destFolder, fileName);
    await zipFile.copy(destPath);

    if (await zipFile.exists()) {
      await zipFile.delete();
    }

    // Catat notifikasi sukses
    final successNotification = {
      'title': 'Auto Backup Berhasil',
      'subtitle': 'Data berhasil dibackup ke: $fileName',
      'type': 'BACKUP_SUCCESS',
      'is_read': 0,
      'created_at': DateTime.now().toIso8601String(),
    };
    await DatabaseHelper.instance.insertNotification(successNotification);

    return fileName;
  }

  /// Hanya untuk keperluan alarm manager background.
  static Future<void> testBackupNow() async {
    if (kIsWeb || !Platform.isAndroid) return;
    await AndroidAlarmManager.oneShot(
      const Duration(seconds: 1),
      9999,
      callbackDispatcher,
      exact: true,
      wakeup: true,
    );
  }

  static Future<void> cancelBackup() async {
    if (kIsWeb || !Platform.isAndroid) return;
    await AndroidAlarmManager.cancel(_autoBackupAlarmId);
  }
}
