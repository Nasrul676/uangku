import 'dart:math' as math;

import '../models/book_period.dart';
import '../models/finance_transaction.dart';

/// Angka mana yang sedang ditampilkan kalender.
///
/// Pemasukan dan pengeluaran tidak pernah digambar berbarengan di satu sel.
/// Satu kotak selebar sepertujuh layar cuma muat satu angka; dua angka di
/// dalamnya berebut ruang sampai keduanya tidak terbaca, dan mata pun tidak
/// bisa membandingkan dua warna yang bertumpuk di kotak yang sama.
enum CalendarMode { pengeluaran, pemasukan, net }

/// Satu tanggal beserta seluruh angkanya.
///
/// Keduanya dikumpulkan sekaligus walau hanya satu yang ditampilkan: berganti
/// filter jadi sekadar membaca ulang bidang yang sudah ada, bukan menghitung
/// ulang seluruh transaksi bulan itu.
class CalendarDay {
  const CalendarDay({
    required this.day,
    required this.expense,
    required this.income,
    required this.expenseCount,
    required this.incomeCount,
  });

  /// Tanggal dalam bulannya, 1..31.
  final int day;

  final double expense;
  final double income;
  final int expenseCount;
  final int incomeCount;

  double get net => income - expense;

  double amountFor(CalendarMode mode) {
    switch (mode) {
      case CalendarMode.pengeluaran:
        return expense;
      case CalendarMode.pemasukan:
        return income;
      case CalendarMode.net:
        return net;
    }
  }

  int countFor(CalendarMode mode) {
    switch (mode) {
      case CalendarMode.pengeluaran:
        return expenseCount;
      case CalendarMode.pemasukan:
        return incomeCount;
      case CalendarMode.net:
        return expenseCount + incomeCount;
    }
  }

  /// Apakah tanggal ini punya sesuatu untuk digambar pada [mode].
  ///
  /// Di mode net, hari yang masuk dan keluarnya kebetulan sama persis tetap
  /// dianggap ada isinya — nolnya adalah hasil hitungan, bukan ketiadaan
  /// catatan, dan keduanya tidak boleh digambar sama.
  bool hasDataFor(CalendarMode mode) => countFor(mode) > 0;
}

/// Satu bulan, sudah siap digambar jadi kisi kalender.
class CalendarMonth {
  const CalendarMonth({
    required this.month,
    required this.days,
    required this.totalExpense,
    required this.totalIncome,
  });

  /// Hari pertama bulan ini — penanda bulannya, bukan tanggal yang berarti.
  final DateTime month;

  /// Hanya berisi tanggal yang benar-benar ada catatannya. Tanggal kosong
  /// sengaja tidak diisi nol: "tidak ada catatan" dan "catatannya nol rupiah"
  /// adalah dua hal berbeda, dan kisinya menggambar keduanya berbeda pula.
  final Map<int, CalendarDay> days;

  final double totalExpense;
  final double totalIncome;

  double get net => totalIncome - totalExpense;

  double totalFor(CalendarMode mode) {
    switch (mode) {
      case CalendarMode.pengeluaran:
        return totalExpense;
      case CalendarMode.pemasukan:
        return totalIncome;
      case CalendarMode.net:
        return net;
    }
  }

  /// Jumlah hari di bulan ini. Tanggal 0 bulan berikutnya adalah tanggal
  /// terakhir bulan ini — sekaligus benar untuk Februari kabisat.
  int get dayCount => DateTime(month.year, month.month + 1, 0).day;

  /// Kolom tempat tanggal 1 jatuh, 1 = Senin … 7 = Minggu.
  int get leadingWeekday => DateTime(month.year, month.month, 1).weekday;

  CalendarDay? dayAt(int day) => days[day];

  bool isEmptyFor(CalendarMode mode) =>
      days.values.every((entry) => !entry.hasDataFor(mode));

  /// Hari dengan angka terbesar pada [mode]. Null kalau tidak ada isinya.
  ///
  /// Di mode net yang dicari adalah simpangan terjauh dari nol — hari paling
  /// merugi sama menariknya dengan hari paling untung.
  CalendarDay? busiestDayFor(CalendarMode mode) {
    CalendarDay? best;
    for (final entry in days.values) {
      if (!entry.hasDataFor(mode)) continue;
      final value = entry.amountFor(mode).abs();
      if (best == null || value > best.amountFor(mode).abs()) best = entry;
    }
    return best;
  }

  /// Seberapa pekat tanggal ini diwarnai pada [mode], 0..1.
  ///
  /// Akar kuadrat, bukan perbandingan lurus: dengan satu hari belanja besar,
  /// skala lurus membuat seluruh hari lain nyaris tak berwarna. Yang dicari
  /// adalah bentuk bulannya, bukan ketepatan rasio yang toh tidak terbaca
  /// dari warna.
  double intensityAt(int day, CalendarMode mode) {
    final entry = days[day];
    if (entry == null || !entry.hasDataFor(mode)) return 0;

    final peak = busiestDayFor(mode)?.amountFor(mode).abs() ?? 0;
    if (peak <= 0) return 0;

    final ratio = (entry.amountFor(mode).abs() / peak).clamp(0.0, 1.0);
    // Sedikit dasar, supaya hari dengan angka kecil tetap terlihat pernah
    // dicatat — bukan tampak sama saja dengan hari yang kosong.
    return 0.18 + 0.82 * math.sqrt(ratio);
  }
}

/// Rentang tanggal yang dicakup sebuah buku.
class CalendarRange {
  const CalendarRange({required this.start, required this.end});

  /// Keduanya inklusif dan sudah dinormalkan ke tengah malam.
  final DateTime start;
  final DateTime end;

  DateTime get firstMonth => DateTime(start.year, start.month);
  DateTime get lastMonth => DateTime(end.year, end.month);

  bool contains(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return !day.isBefore(start) && !day.isAfter(end);
  }

  bool hasMonthBefore(DateTime month) => month.isAfter(firstMonth);
  bool hasMonthAfter(DateTime month) => month.isBefore(lastMonth);
}

/// Rentang yang bisa dijelajahi kalender untuk [book].
///
/// Buku yang masih terbuka belum punya tanggal tutup, jadi ujungnya adalah
/// hari ini — bukan akhir bulan. Menawarkan tanggal yang belum terjadi
/// membuat kalender terlihat seperti kehilangan data, padahal harinya memang
/// belum datang.
///
/// Null kalau tanggal mulai bukunya tidak bisa dibaca; tidak ada yang bisa
/// digambar dari itu, dan menebaknya lebih buruk daripada tidak menggambar.
CalendarRange? calendarRangeFor(BookPeriod book, {required DateTime today}) {
  final parsedStart = DateTime.tryParse(book.startDate);
  if (parsedStart == null) return null;

  final start = DateTime(parsedStart.year, parsedStart.month, parsedStart.day);
  final now = DateTime(today.year, today.month, today.day);

  final rawEnd = book.endDate;
  final parsedEnd = (rawEnd == null || rawEnd.isEmpty)
      ? null
      : DateTime.tryParse(rawEnd);

  var end = parsedEnd == null
      ? now
      : DateTime(parsedEnd.year, parsedEnd.month, parsedEnd.day);

  // Buku yang sudah ditutup tetap dihormati ujungnya walau tanggalnya di masa
  // depan — itu keputusan pengguna, bukan data yang meleset. Yang dijaga cuma
  // ujung yang mendahului awalnya, yang tidak bisa digambar sama sekali.
  if (end.isBefore(start)) end = start;

  return CalendarRange(start: start, end: end);
}

/// Menjumlahkan pemasukan dan pengeluaran per tanggal untuk satu bulan.
///
/// [transactions] diharapkan sudah disaring ke buku yang bersangkutan —
/// fungsi ini hanya menyaring bulannya.
CalendarMonth buildCalendarMonth({
  required DateTime month,
  required List<FinanceTransaction> transactions,
}) {
  final prefix =
      '${month.year.toString().padLeft(4, '0')}-'
      '${month.month.toString().padLeft(2, '0')}-';

  final expenses = <int, double>{};
  final incomes = <int, double>{};
  final expenseCounts = <int, int>{};
  final incomeCounts = <int, int>{};

  var totalExpense = 0.0;
  var totalIncome = 0.0;

  for (final tx in transactions) {
    // Tanggal disimpan sebagai teks ISO. Membandingkan awalannya jauh lebih
    // murah daripada mem-parse puluhan ribu baris jadi DateTime.
    if (tx.date.length < 10) continue;
    if (!tx.date.startsWith(prefix)) continue;

    final day = int.tryParse(tx.date.substring(8, 10));
    if (day == null || day < 1) continue;

    if (tx.type == 'EXPENSE') {
      expenses[day] = (expenses[day] ?? 0) + tx.amount;
      expenseCounts[day] = (expenseCounts[day] ?? 0) + 1;
      totalExpense += tx.amount;
    } else if (tx.type == 'INCOME') {
      incomes[day] = (incomes[day] ?? 0) + tx.amount;
      incomeCounts[day] = (incomeCounts[day] ?? 0) + 1;
      totalIncome += tx.amount;
    }
  }

  final days = <int, CalendarDay>{};
  for (final day in {...expenses.keys, ...incomes.keys}) {
    days[day] = CalendarDay(
      day: day,
      expense: expenses[day] ?? 0,
      income: incomes[day] ?? 0,
      expenseCount: expenseCounts[day] ?? 0,
      incomeCount: incomeCounts[day] ?? 0,
    );
  }

  return CalendarMonth(
    month: DateTime(month.year, month.month),
    days: days,
    totalExpense: totalExpense,
    totalIncome: totalIncome,
  );
}

/// Transaksi pada satu tanggal untuk [mode], terbaru lebih dulu.
///
/// Urutannya memakai jam kalau ada. Transaksi tanpa jam ditaruh paling bawah:
/// menebaknya sebagai tengah malam akan menyelipkannya di antara catatan yang
/// jamnya benar-benar diketahui.
List<FinanceTransaction> transactionsOnDate(
  DateTime date,
  List<FinanceTransaction> transactions, {
  CalendarMode mode = CalendarMode.pengeluaran,
}) {
  final key =
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  bool matchesMode(FinanceTransaction tx) {
    switch (mode) {
      case CalendarMode.pengeluaran:
        return tx.type == 'EXPENSE';
      case CalendarMode.pemasukan:
        return tx.type == 'INCOME';
      case CalendarMode.net:
        return tx.type == 'EXPENSE' || tx.type == 'INCOME';
    }
  }

  final result = transactions
      .where(
        (tx) =>
            matchesMode(tx) &&
            tx.date.length >= 10 &&
            tx.date.substring(0, 10) == key,
      )
      .toList();

  result.sort((a, b) {
    final timeA = a.time;
    final timeB = b.time;
    if (timeA == null && timeB == null) return 0;
    if (timeA == null) return 1;
    if (timeB == null) return -1;
    return timeB.compareTo(timeA);
  });

  return result;
}
