import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'database_helper.dart';

const int _dailySummaryAlarmId = 2001;
const int _financialPlanAlarmId = 2002;

@pragma('vm:entry-point')
Future<void> dailySummaryCallbackDispatcher() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    
    final dbHelper = DatabaseHelper.instance;
    final transactions = await dbHelper.getAllTransactions();
    
    double totalExpense = 0;
    for (var tx in transactions) {
      if (tx.type == 'EXPENSE' && tx.date.startsWith(todayStr)) {
        totalExpense += tx.amount;
      }
    }
    
    final rupiahFormatter = NumberFormat.currency(
      locale: 'id_ID', 
      symbol: 'Rp ', 
      decimalDigits: 0,
    );
    final formattedTotal = rupiahFormatter.format(totalExpense);
    
    final plugin = FlutterLocalNotificationsPlugin();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await plugin.initialize(const InitializationSettings(android: androidInit, iOS: iosInit));

    const androidDetails = AndroidNotificationDetails(
      'daily_summary_channel',
      'Ringkasan Harian',
      channelDescription: 'Notifikasi ringkasan pengeluaran harian',
      importance: Importance.max,
      priority: Priority.max,
    );
    const details = NotificationDetails(
      android: androidDetails, 
      iOS: DarwinNotificationDetails(),
    );
    
    await plugin.show(
      _dailySummaryAlarmId,
      'Pengeluaran Hari Ini',
      totalExpense > 0 
          ? 'Total pengeluaranmu hari ini adalah $formattedTotal' 
          : 'Belum ada pengeluaran hari ini. Hebat!',
      details,
    );
  } catch (e) {
    debugPrint('Daily Summary Error: $e');
  } finally {
    // Jadwalkan ulang untuk besok
    BackgroundNotificationService.scheduleDailySummary();
  }
}

@pragma('vm:entry-point')
Future<void> financialPlanCallbackDispatcher() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    
    final dbHelper = DatabaseHelper.instance;
    final plans = await dbHelper.getAllFinancialPlans();
    
    final plugin = FlutterLocalNotificationsPlugin();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await plugin.initialize(const InitializationSettings(android: androidInit, iOS: iosInit));

    const androidDetails = AndroidNotificationDetails(
      'financial_plan_channel',
      'Rencana Keuangan',
      channelDescription: 'Pengingat rencana keuangan jatuh tempo',
      importance: Importance.max,
      priority: Priority.max,
    );
    const details = NotificationDetails(
      android: androidDetails, 
      iOS: DarwinNotificationDetails(),
    );
    
    for (var plan in plans) {
      final targetDate = plan.targetDate;
      if (targetDate.startsWith(todayStr)) {
        final title = plan.title;
        final targetAmount = plan.targetAmount;
        
        final rupiahFormatter = NumberFormat.currency(
          locale: 'id_ID', 
          symbol: 'Rp ', 
          decimalDigits: 0,
        );
        
        await plugin.show(
          (plan.id ?? 0) + 800000,
          'Rencana Keuangan Jatuh Tempo',
          'Rencana "$title" (${rupiahFormatter.format(targetAmount)}) sudah masuk tanggal target hari ini!',
          details,
          payload: 'financial-plan:${plan.id}',
        );
      }
    }
  } catch(e) {
    debugPrint('Financial Plan Alarm Error: $e');
  } finally {
    // Jadwalkan ulang untuk besok
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt('plan_notification_hour') ?? 8;
    final minute = prefs.getInt('plan_notification_minute') ?? 0;
    BackgroundNotificationService.scheduleFinancialPlanAlarm(hour, minute);
  }
}

class BackgroundNotificationService {
  static Future<void> scheduleDailySummary() async {
    if (kIsWeb || !Platform.isAndroid) return;
    
    final now = DateTime.now();
    var targetTime = DateTime(now.year, now.month, now.day, 21, 0, 0);
    // Jika waktu target sudah lewat atau SAMA dengan sekarang (karena dipanggil oleh alarm yg baru saja menyala)
    if (now.isAfter(targetTime) || now.isAtSameMomentAs(targetTime)) {
      targetTime = targetTime.add(const Duration(days: 1));
    }
    
    await AndroidAlarmManager.oneShotAt(
      targetTime,
      _dailySummaryAlarmId,
      dailySummaryCallbackDispatcher,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
    );
  }

  static Future<void> scheduleFinancialPlanAlarm(int hour, int minute) async {
    if (kIsWeb || !Platform.isAndroid) return;
    
    final now = DateTime.now();
    var targetTime = DateTime(now.year, now.month, now.day, hour, minute, 0);
    // Jika waktu target sudah lewat atau SAMA dengan sekarang
    if (now.isAfter(targetTime) || now.isAtSameMomentAs(targetTime)) {
      targetTime = targetTime.add(const Duration(days: 1));
    }
    
    await AndroidAlarmManager.oneShotAt(
      targetTime,
      _financialPlanAlarmId,
      financialPlanCallbackDispatcher,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
    );
  }
}
