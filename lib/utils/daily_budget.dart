import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../models/book_period.dart';
import '../models/finance_transaction.dart';
import 'rupiah_compact.dart';

/// Dari mana angka sisa hari berasal.
enum BudgetHorizon {
  /// Buku punya tanggal selesai — sisa harinya pasti, bukan tebakan.
  sampaiTanggal,

  /// Buku masih terbuka. Sisa hari diperkirakan dari rata-rata pemakaian,
  /// jadi teksnya harus jujur menyebut ini perkiraan.
  perkiraan,
}

/// Jatah harian dan sisa waktu sebuah buku.
///
/// Ini yang mengubah "Rp 2.400.000" jadi kalimat yang bisa dipakai mengambil
/// keputusan hari ini. Semuanya perhitungan murni supaya bisa diuji tanpa
/// database maupun widget.
@immutable
class DailyBudget {
  const DailyBudget({
    required this.balance,
    required this.daysRemaining,
    required this.perDay,
    required this.spentToday,
    required this.horizon,
    this.until,
  });

  /// Saldo tersisa saat perhitungan dibuat.
  final double balance;

  /// Termasuk hari ini, jadi minimal 1 selama masih ada waktu tersisa.
  final int daysRemaining;

  /// Jatah per hari kalau saldo dibagi rata ke sisa hari.
  final double perDay;

  /// Total pengeluaran bertanggal hari ini.
  final double spentToday;

  final BudgetHorizon horizon;

  /// Hanya terisi kalau [horizon] adalah [BudgetHorizon.sampaiTanggal].
  final DateTime? until;

  double get remainingToday => perDay - spentToday;

  bool get isOverToday => spentToday > perDay;

  /// Selalu 0..1 supaya aman dipakai langsung sebagai lebar batang.
  double get usedRatio {
    if (perDay <= 0) return spentToday > 0 ? 1 : 0;
    final ratio = spentToday / perDay;
    return ratio.clamp(0.0, 1.0);
  }
}

/// Menghitung jatah harian untuk sebuah buku.
///
/// Mengembalikan null kalau angkanya tidak bisa dipercaya — buku sudah lewat
/// tanggal selesainya, saldo habis, atau buku masih terbuka tapi belum ada
/// pengeluaran sama sekali sehingga tidak ada dasar untuk memperkirakan.
/// Memaksakan angka di keadaan seperti itu lebih buruk daripada tidak
/// menampilkan apa pun.
DailyBudget? buildDailyBudget({
  required BookPeriod book,
  required List<FinanceTransaction> transactions,
  required double balance,
  required DateTime today,
}) {
  if (balance <= 0) return null;

  final day = DateTime(today.year, today.month, today.day);
  final spentToday = _spentOn(transactions, day);

  final endRaw = book.endDate;
  if (endRaw != null && endRaw.isNotEmpty) {
    final parsed = DateTime.tryParse(endRaw);
    if (parsed == null) return null;

    final end = DateTime(parsed.year, parsed.month, parsed.day);
    if (end.isBefore(day)) return null;

    // +1 supaya hari ini ikut terhitung: buku yang selesai hari ini masih
    // menyisakan satu hari untuk dipakai, bukan nol.
    final days = end.difference(day).inDays + 1;
    return DailyBudget(
      balance: balance,
      daysRemaining: days,
      perDay: balance / days,
      spentToday: spentToday,
      horizon: BudgetHorizon.sampaiTanggal,
      until: end,
    );
  }

  final average = _averageDailySpend(transactions, book: book, today: day);
  if (average == null || average <= 0) return null;

  final days = (balance / average).floor();
  if (days < 1) return null;

  return DailyBudget(
    balance: balance,
    daysRemaining: days,
    perDay: average,
    spentToday: spentToday,
    horizon: BudgetHorizon.perkiraan,
  );
}

double _spentOn(List<FinanceTransaction> transactions, DateTime day) {
  final key = _dateKey(day);
  var total = 0.0;
  for (final tx in transactions) {
    if (tx.type != 'EXPENSE') continue;
    // `date` disimpan sebagai teks 'yyyy-MM-dd', jadi cukup dibandingkan
    // sebagai teks — tanpa parsing, dan tanpa risiko geser zona waktu.
    if (tx.date.length >= 10 && tx.date.substring(0, 10) == key) {
      total += tx.amount;
    }
  }
  return total;
}

/// Rata-rata pengeluaran harian selama tujuh hari terakhir.
///
/// Pembaginya jumlah hari yang benar-benar sudah berjalan sejak buku dibuka,
/// dibatasi tujuh. Kalau dibagi tujuh terus, buku yang baru dibuka dua hari
/// lalu akan terlihat jauh lebih hemat daripada kenyataannya.
double? _averageDailySpend(
  List<FinanceTransaction> transactions, {
  required BookPeriod book,
  required DateTime today,
}) {
  final start = DateTime.tryParse(book.startDate);
  if (start == null) return null;

  final bookStart = DateTime(start.year, start.month, start.day);
  if (bookStart.isAfter(today)) return null;

  final elapsed = today.difference(bookStart).inDays + 1;
  final window = elapsed < 7 ? elapsed : 7;
  final from = today.subtract(Duration(days: window - 1));
  final fromKey = _dateKey(from);
  final todayKey = _dateKey(today);

  var total = 0.0;
  for (final tx in transactions) {
    if (tx.type != 'EXPENSE') continue;
    if (tx.date.length < 10) continue;
    final key = tx.date.substring(0, 10);
    if (key.compareTo(fromKey) >= 0 && key.compareTo(todayKey) <= 0) {
      total += tx.amount;
    }
  }

  if (total <= 0) return null;
  return total / window;
}

/// Kalimat yang menerjemahkan saldo jadi keputusan hari ini.
///
/// Inilah yang sebenarnya dicari orang saat membuka aplikasi pencatat
/// keuangan — bukan nominal saldo mentah, tapi "hari ini aku boleh jajan
/// berapa".
///
/// Nada kalimatnya berbeda antara [BudgetHorizon.sampaiTanggal] yang pasti dan
/// [BudgetHorizon.perkiraan] yang cuma ramalan. Menyamakan keduanya berarti
/// menjual tebakan sebagai kepastian.
String describeBudget(DailyBudget budget) {
  final perDay = compactRupiah(budget.perDay);

  if (budget.horizon == BudgetHorizon.sampaiTanggal) {
    final until = DateFormat('d MMM', 'id').format(budget.until!);
    return 'Cukup sampai $until — sisa ${budget.daysRemaining} hari, '
        'jatah $perDay per hari.';
  }

  return 'Kalau jalan segini terus, kira-kira cukup '
      '${budget.daysRemaining} hari lagi — rata-rata $perDay per hari.';
}

String _dateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
