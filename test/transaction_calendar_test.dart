import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:uangkeluar/models/book_period.dart';
import 'package:uangkeluar/models/finance_transaction.dart';
import 'package:uangkeluar/utils/transaction_calendar.dart';
import 'package:uangkeluar/widgets/transaction_calendar_panel.dart';

FinanceTransaction tx({
  required String date,
  required double amount,
  String type = 'EXPENSE',
  String title = 'Transaksi',
  String? time,
}) {
  return FinanceTransaction(
    bookPeriodId: 1,
    title: title,
    amount: amount,
    type: type,
    category: 'Pengeluaran',
    date: date,
    time: time,
  );
}

BookPeriod book({String start = '2026-08-01', String? end}) {
  return BookPeriod(
    id: 1,
    label: 'Agustus 2026',
    startDate: start,
    endDate: end,
    isClosed: end == null ? 0 : 1,
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id', null);
  });

  group('menjumlahkan pengeluaran per tanggal', () {
    test('beberapa transaksi di tanggal yang sama jadi satu angka', () {
      final month = buildCalendarMonth(
        month: DateTime(2026, 8),
        transactions: [
          tx(date: '2026-08-12', amount: 50000),
          tx(date: '2026-08-12', amount: 75000),
          tx(date: '2026-08-20', amount: 30000),
        ],
      );

      expect(month.dayAt(12)?.expense, 125000);
      expect(month.dayAt(12)?.expenseCount, 2);
      expect(month.dayAt(20)?.expense, 30000);
      expect(month.totalExpense, 155000);
    });

    test('pemasukan tidak ikut terhitung', () {
      final month = buildCalendarMonth(
        month: DateTime(2026, 8),
        transactions: [
          tx(date: '2026-08-12', amount: 50000),
          tx(date: '2026-08-12', amount: 9000000, type: 'INCOME'),
        ],
      );

      // Kalendernya menyebut dirinya kalender pengeluaran. Gaji yang ikut
      // terhitung akan membuat satu tanggal terlihat merah pekat tanpa sebab.
      expect(month.dayAt(12)?.expense, 50000);
      expect(month.totalExpense, 50000);
    });

    test('transaksi dari bulan lain tidak bocor masuk', () {
      final month = buildCalendarMonth(
        month: DateTime(2026, 8),
        transactions: [
          tx(date: '2026-07-12', amount: 50000),
          tx(date: '2026-09-12', amount: 50000),
          tx(date: '2026-08-12', amount: 20000),
        ],
      );

      expect(month.totalExpense, 20000);
      expect(month.days, hasLength(1));
    });

    test('tanggal tanpa catatan tetap kosong, bukan nol', () {
      final month = buildCalendarMonth(
        month: DateTime(2026, 8),
        transactions: [tx(date: '2026-08-12', amount: 20000)],
      );

      // "Belum ada catatan" dan "catatannya nol rupiah" digambar berbeda di
      // kisi, jadi keduanya tidak boleh diratakan di sini.
      expect(month.dayAt(13), isNull);
    });

    test('tanggal cacat dilewati tanpa melempar', () {
      final month = buildCalendarMonth(
        month: DateTime(2026, 8),
        transactions: [
          tx(date: '', amount: 10000),
          tx(date: '2026-08', amount: 10000),
          tx(date: '2026-08-05', amount: 10000),
        ],
      );

      expect(month.totalExpense, 10000);
    });

    test('hari terboros ditemukan dengan benar', () {
      final month = buildCalendarMonth(
        month: DateTime(2026, 8),
        transactions: [
          tx(date: '2026-08-03', amount: 40000),
          tx(date: '2026-08-19', amount: 310000),
          tx(date: '2026-08-27', amount: 120000),
        ],
      );

      expect(month.busiestDayFor(CalendarMode.pengeluaran)?.day, 19);
      expect(month.busiestDayFor(CalendarMode.pengeluaran)?.expense, 310000);
    });

    test('bulan kosong tidak punya hari terboros', () {
      final month = buildCalendarMonth(
        month: DateTime(2026, 8),
        transactions: const [],
      );

      expect(month.isEmptyFor(CalendarMode.pengeluaran), isTrue);
      expect(month.busiestDayFor(CalendarMode.pengeluaran), isNull);
      expect(month.totalExpense, 0);
    });

    test('Februari kabisat dihitung 29 hari', () {
      final month = buildCalendarMonth(
        month: DateTime(2028, 2),
        transactions: const [],
      );

      expect(month.dayCount, 29);
    });
  });

  group('pekat warnanya', () {
    final month = buildCalendarMonth(
      month: DateTime(2026, 8),
      transactions: [
        tx(date: '2026-08-01', amount: 1000),
        tx(date: '2026-08-02', amount: 500000),
      ],
    );

    test('hari tanpa catatan tidak diwarnai sama sekali', () {
      expect(month.intensityAt(3, CalendarMode.pengeluaran), 0);
    });

    test('hari terboros paling pekat', () {
      expect(month.intensityAt(2, CalendarMode.pengeluaran), 1.0);
    });

    test('belanja kecil tetap terlihat, tidak hilang jadi putih', () {
      // Dengan skala lurus, 1.000 dari 500.000 hanya 0,2% — praktis tak
      // terlihat, padahal hari itu jelas berbeda dari hari yang kosong.
      final small = month.intensityAt(1, CalendarMode.pengeluaran);
      expect(small, greaterThan(0.15));
      expect(small, lessThan(month.intensityAt(2, CalendarMode.pengeluaran)));
    });
  });

  group('transaksi satu tanggal', () {
    test('hanya pengeluaran di tanggal itu yang ikut', () {
      final items = transactionsOnDate(DateTime(2026, 8, 12), [
        tx(date: '2026-08-12', amount: 10000, title: 'Kopi'),
        tx(date: '2026-08-13', amount: 20000, title: 'Bensin'),
        tx(date: '2026-08-12', amount: 9000000, type: 'INCOME', title: 'Gaji'),
      ]);

      expect(items.map((tx) => tx.title), ['Kopi']);
    });

    test('terbaru lebih dulu', () {
      final items = transactionsOnDate(DateTime(2026, 8, 12), [
        tx(date: '2026-08-12', amount: 1, title: 'Pagi', time: '07:30'),
        tx(date: '2026-08-12', amount: 1, title: 'Malam', time: '20:15'),
        tx(date: '2026-08-12', amount: 1, title: 'Siang', time: '12:00'),
      ]);

      expect(items.map((tx) => tx.title), ['Malam', 'Siang', 'Pagi']);
    });

    test('yang tanpa jam ditaruh paling bawah', () {
      final items = transactionsOnDate(DateTime(2026, 8, 12), [
        tx(date: '2026-08-12', amount: 1, title: 'Entah kapan'),
        tx(date: '2026-08-12', amount: 1, title: 'Pagi', time: '07:30'),
      ]);

      // Menebaknya tengah malam akan menyelipkannya di antara catatan yang
      // jamnya benar-benar diketahui.
      expect(items.map((tx) => tx.title), ['Pagi', 'Entah kapan']);
    });
  });

  group('pemasukan dan net', () {
    CalendarMonth sample() => buildCalendarMonth(
      month: DateTime(2026, 8),
      transactions: [
        tx(date: '2026-08-05', amount: 200000),
        tx(date: '2026-08-05', amount: 500000, type: 'INCOME'),
        tx(date: '2026-08-19', amount: 800000),
      ],
    );

    test('keduanya dikumpulkan sekaligus di satu tanggal', () {
      final day = sample().dayAt(5)!;

      expect(day.expense, 200000);
      expect(day.income, 500000);
      expect(day.net, 300000);
    });

    test('net bisa negatif', () {
      final day = sample().dayAt(19)!;

      expect(day.net, -800000);
      expect(sample().totalFor(CalendarMode.net), -500000);
    });

    test('tanggal tanpa pemasukan kosong di mode pemasukan', () {
      final month = sample();

      // Tanggal 19 cuma berisi pengeluaran. Di mode pemasukan kotaknya harus
      // terbaca sebagai "tidak ada catatan", bukan sebagai "nol rupiah".
      expect(month.dayAt(19)!.hasDataFor(CalendarMode.pemasukan), isFalse);
      expect(month.dayAt(19)!.hasDataFor(CalendarMode.pengeluaran), isTrue);
    });

    test('hari puncak berbeda tiap mode', () {
      final month = sample();

      expect(month.busiestDayFor(CalendarMode.pengeluaran)?.day, 19);
      expect(month.busiestDayFor(CalendarMode.pemasukan)?.day, 5);
      // Di mode net yang dicari simpangan terjauh dari nol, jadi hari paling
      // merugi menang atas hari yang untungnya lebih kecil.
      expect(month.busiestDayFor(CalendarMode.net)?.day, 19);
    });

    test('bulan yang cuma berisi pengeluaran kosong di mode pemasukan', () {
      final month = buildCalendarMonth(
        month: DateTime(2026, 8),
        transactions: [tx(date: '2026-08-05', amount: 200000)],
      );

      expect(month.isEmptyFor(CalendarMode.pemasukan), isTrue);
      expect(month.isEmptyFor(CalendarMode.pengeluaran), isFalse);
    });

    test('daftar tanggal ikut modenya', () {
      final items = [
        tx(date: '2026-08-05', amount: 200000, title: 'Belanja'),
        tx(date: '2026-08-05', amount: 500000, type: 'INCOME', title: 'Gaji'),
      ];

      expect(
        transactionsOnDate(
          DateTime(2026, 8, 5),
          items,
          mode: CalendarMode.pemasukan,
        ).map((tx) => tx.title),
        ['Gaji'],
      );
      expect(
        transactionsOnDate(
          DateTime(2026, 8, 5),
          items,
          mode: CalendarMode.net,
        ).map((tx) => tx.title),
        hasLength(2),
      );
    });
  });

  group('rentang buku', () {
    test('buku terbuka berhenti di hari ini, bukan akhir bulan', () {
      final range = calendarRangeFor(book(), today: DateTime(2026, 8, 17));

      // Menawarkan tanggal yang belum terjadi membuat kalender terlihat
      // kehilangan data, padahal harinya memang belum datang.
      expect(range?.end, DateTime(2026, 8, 17));
      expect(range?.contains(DateTime(2026, 8, 18)), isFalse);
    });

    test('buku tertutup memakai tanggal tutupnya', () {
      final range = calendarRangeFor(
        book(end: '2026-08-31'),
        today: DateTime(2026, 12, 1),
      );

      expect(range?.end, DateTime(2026, 8, 31));
      expect(range?.contains(DateTime(2026, 9, 1)), isFalse);
    });

    test('tanggal sebelum buku mulai di luar rentang', () {
      final range = calendarRangeFor(
        book(start: '2026-08-10'),
        today: DateTime(2026, 8, 17),
      );

      expect(range?.contains(DateTime(2026, 8, 9)), isFalse);
      expect(range?.contains(DateTime(2026, 8, 10)), isTrue);
    });

    test('buku lintas bulan bisa dijelajahi bolak-balik', () {
      final range = calendarRangeFor(
        book(start: '2026-06-15', end: '2026-08-31'),
        today: DateTime(2026, 9, 1),
      );

      expect(range?.firstMonth, DateTime(2026, 6));
      expect(range?.lastMonth, DateTime(2026, 8));
      expect(range?.hasMonthBefore(DateTime(2026, 7)), isTrue);
      expect(range?.hasMonthAfter(DateTime(2026, 8)), isFalse);
      expect(range?.hasMonthBefore(DateTime(2026, 6)), isFalse);
    });

    test('tanggal mulai yang tidak terbaca tidak menghasilkan rentang', () {
      // Menebak tanggalnya lebih buruk daripada tidak menggambar apa pun.
      final range = calendarRangeFor(
        book(start: 'entah kapan'),
        today: DateTime(2026, 8, 17),
      );

      expect(range, isNull);
    });
  });

  group('panel kalender', () {
    Future<void> pumpPanel(
      WidgetTester tester, {
      required List<FinanceTransaction> transactions,
      BookPeriod? withBook,
      DateTime? today,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TransactionCalendarPanel(
                book: withBook ?? book(),
                transactions: transactions,
                today: today ?? DateTime(2026, 8, 17),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('nominal ringkas tertulis di tanggalnya', (tester) async {
      await pumpPanel(
        tester,
        transactions: [tx(date: '2026-08-12', amount: 125000)],
      );

      expect(find.text('12'), findsOneWidget);
      expect(find.text('125rb'), findsOneWidget);
    });

    testWidgets('mengetuk tanggal memunculkan nominal penuhnya', (
      tester,
    ) async {
      await pumpPanel(
        tester,
        transactions: [
          tx(date: '2026-08-12', amount: 100000),
          tx(date: '2026-08-12', amount: 25000),
        ],
      );

      await tester.tap(find.text('12'));
      await tester.pump();

      // "125rb" cukup untuk melihat bentuk bulannya, tidak cukup untuk
      // mencocokkan dengan catatan.
      expect(find.text('Rabu, 12 Agustus'), findsOneWidget);
      expect(find.text('2 transaksi · Rp 125.000'), findsOneWidget);
    });

    testWidgets('membuka daftar transaksi tanggal terpilih', (tester) async {
      await pumpPanel(
        tester,
        transactions: [
          tx(date: '2026-08-12', amount: 100000, title: 'Belanja bulanan'),
          tx(date: '2026-08-12', amount: 25000, title: 'Kopi sore'),
          tx(date: '2026-08-13', amount: 40000, title: 'Bensin'),
        ],
      );

      await tester.tap(find.text('12'));
      await tester.pump();
      await tester.tap(find.text('Lihat 2 transaksi'));
      await tester.pumpAndSettle();

      expect(find.text('Rabu, 12 Agustus 2026'), findsOneWidget);
      expect(find.text('Belanja bulanan'), findsOneWidget);
      expect(find.text('Kopi sore'), findsOneWidget);
      // Tanggal lain tidak ikut terbawa masuk.
      expect(find.text('Bensin'), findsNothing);
    });

    testWidgets('lembar rinciannya menyebut total tanggal itu', (tester) async {
      await pumpPanel(
        tester,
        transactions: [
          tx(date: '2026-08-12', amount: 100000),
          tx(date: '2026-08-12', amount: 25000),
        ],
      );

      await tester.tap(find.text('12'));
      await tester.pump();
      await tester.tap(find.text('Lihat 2 transaksi'));
      await tester.pumpAndSettle();

      expect(find.text('Total Rp 125.000'), findsOneWidget);
    });

    testWidgets('filter pemasukan mengganti angka di kisinya', (tester) async {
      await pumpPanel(
        tester,
        transactions: [
          tx(date: '2026-08-05', amount: 200000),
          tx(date: '2026-08-05', amount: 500000, type: 'INCOME'),
        ],
      );

      expect(find.text('200rb'), findsOneWidget);
      expect(find.text('500rb'), findsNothing);

      await tester.tap(find.text('Pemasukan'));
      await tester.pump();

      // Keduanya tidak pernah digambar berbarengan di satu sel: satu kotak
      // selebar sepertujuh layar cuma muat satu angka.
      expect(find.text('500rb'), findsOneWidget);
      expect(find.text('200rb'), findsNothing);
    });

    testWidgets('mode net menuliskan selisihnya beserta tandanya', (
      tester,
    ) async {
      await pumpPanel(
        tester,
        transactions: [
          tx(date: '2026-08-05', amount: 200000),
          tx(date: '2026-08-05', amount: 500000, type: 'INCOME'),
          tx(date: '2026-08-06', amount: 800000),
        ],
      );

      await tester.tap(find.text('Net'));
      await tester.pump();

      // Tanpa tanda, "300rb" di kolom net tidak bisa dibedakan dari "-300rb"
      // selain lewat warna — dan warna saja tidak cukup menyampaikan arti.
      expect(find.text('+300rb'), findsOneWidget);
      expect(find.text('-800rb'), findsOneWidget);
    });

    testWidgets('ganti filter melepas tanggal yang sedang dipilih', (
      tester,
    ) async {
      await pumpPanel(
        tester,
        transactions: [tx(date: '2026-08-12', amount: 100000)],
      );

      await tester.tap(find.text('12'));
      await tester.pump();
      expect(find.text('Rabu, 12 Agustus'), findsOneWidget);

      await tester.tap(find.text('Pemasukan'));
      await tester.pump();

      // Rincian yang tertinggal akan menyebut angka yang tidak ada lagi di
      // kisinya.
      expect(find.text('Rabu, 12 Agustus'), findsNothing);
    });

    testWidgets('bulan kosong pemasukan punya kalimatnya sendiri', (
      tester,
    ) async {
      await pumpPanel(
        tester,
        transactions: [tx(date: '2026-08-12', amount: 100000)],
      );

      await tester.tap(find.text('Pemasukan'));
      await tester.pump();

      expect(
        find.text('Belum ada pemasukan tercatat di bulan ini.'),
        findsOneWidget,
      );
    });

    testWidgets('tanggal kosong tidak menawarkan daftar apa pun', (
      tester,
    ) async {
      await pumpPanel(
        tester,
        transactions: [tx(date: '2026-08-12', amount: 100000)],
      );

      await tester.tap(find.text('5'));
      await tester.pump();

      // Tombol yang membuka daftar kosong cuma memancing ketukan sia-sia.
      expect(find.textContaining('Lihat'), findsNothing);
    });

    testWidgets('tanggal tanpa pengeluaran mengatakannya, bukan diam', (
      tester,
    ) async {
      await pumpPanel(
        tester,
        transactions: [tx(date: '2026-08-12', amount: 100000)],
      );

      await tester.tap(find.text('5'));
      await tester.pump();

      expect(find.text('Tidak ada pengeluaran tercatat.'), findsOneWidget);
    });

    testWidgets('mengetuk tanggal yang sama lagi membatalkan pilihan', (
      tester,
    ) async {
      await pumpPanel(
        tester,
        transactions: [tx(date: '2026-08-12', amount: 100000)],
      );

      await tester.tap(find.text('12'));
      await tester.pump();
      await tester.tap(find.text('12'));
      await tester.pump();

      expect(find.text('Rabu, 12 Agustus'), findsNothing);
      expect(find.textContaining('Total keluar bulan ini'), findsOneWidget);
    });

    testWidgets('tanggal di luar periode buku tidak bisa dipilih', (
      tester,
    ) async {
      await pumpPanel(
        tester,
        withBook: book(start: '2026-08-10'),
        transactions: const [],
      );

      await tester.tap(find.text('3'), warnIfMissed: false);
      await tester.pump();

      expect(find.textContaining('3 Agustus'), findsNothing);
    });

    testWidgets('bulan kosong punya kalimatnya sendiri', (tester) async {
      await pumpPanel(tester, transactions: const []);

      expect(
        find.text('Belum ada pengeluaran tercatat di bulan ini.'),
        findsOneWidget,
      );
    });

    testWidgets('menyebut hari paling boros', (tester) async {
      await pumpPanel(
        tester,
        transactions: [
          tx(date: '2026-08-03', amount: 40000),
          tx(date: '2026-08-15', amount: 310000),
        ],
      );

      expect(find.textContaining('Paling boros 15 Agustus'), findsOneWidget);
      expect(
        find.textContaining('Total keluar bulan ini Rp 350.000'),
        findsOneWidget,
      );
    });

    testWidgets('buka bulan terakhir dulu, bukan bulan pertama', (
      tester,
    ) async {
      await pumpPanel(
        tester,
        withBook: book(start: '2026-06-01', end: '2026-08-31'),
        transactions: const [],
        today: DateTime(2026, 9, 1),
      );

      // Yang dicari orang saat membuka laporan hampir selalu belanja terbaru.
      expect(find.text('Agustus 2026'), findsOneWidget);
    });

    testWidgets('bisa mundur ke bulan sebelumnya', (tester) async {
      await pumpPanel(
        tester,
        withBook: book(start: '2026-06-01', end: '2026-08-31'),
        transactions: [tx(date: '2026-07-04', amount: 90000)],
        today: DateTime(2026, 9, 1),
      );

      await tester.tap(find.byTooltip('Bulan sebelumnya'));
      await tester.pump();

      expect(find.text('Juli 2026'), findsOneWidget);
      expect(find.text('90rb'), findsOneWidget);
    });

    testWidgets('tombol maju mati di bulan terakhir', (tester) async {
      await pumpPanel(
        tester,
        withBook: book(start: '2026-06-01', end: '2026-08-31'),
        transactions: const [],
        today: DateTime(2026, 9, 1),
      );

      final forward = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.chevron_right_rounded),
      );
      expect(forward.onPressed, isNull);
    });

    testWidgets('buku dengan tanggal cacat tidak merusak layar', (
      tester,
    ) async {
      await pumpPanel(
        tester,
        withBook: book(start: 'entah kapan'),
        transactions: const [],
      );

      expect(find.text('KALENDER PENGELUARAN'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tiap tanggal terbaca pembaca layar', (tester) async {
      await pumpPanel(
        tester,
        transactions: [tx(date: '2026-08-12', amount: 125000)],
      );

      // Warna sel tidak berarti apa-apa untuk pembaca layar; labelnya yang
      // harus menyebut angkanya.
      expect(
        find.bySemanticsLabel(
          'Rabu, 12 Agustus, pengeluaran Rp 125.000, 1 transaksi',
        ),
        findsOneWidget,
      );
    });

    testWidgets('muat di layar sempit dengan huruf terbesar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(
                  width: 320,
                  child: TransactionCalendarPanel(
                    book: book(),
                    transactions: [
                      for (var day = 1; day <= 17; day++)
                        tx(
                          date: '2026-08-${day.toString().padLeft(2, '0')}',
                          amount: 1250000,
                        ),
                    ],
                    today: DateTime(2026, 8, 17),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Tujuh kolom di layar 320px berarti sel selebar ~44px. Ini keadaan
      // paling sempit yang benar-benar bisa dialami pengguna.
      expect(tester.takeException(), isNull);
    });
  });
}
