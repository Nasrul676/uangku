import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:uangkeluar/models/book_period.dart';
import 'package:uangkeluar/models/finance_transaction.dart';
import 'package:uangkeluar/screens/book_cashflow_detail_screen.dart';
import 'package:uangkeluar/screens/cashflow_statement_screen.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id', null);
  });

  const book = BookPeriod(
    id: 1,
    label: 'Agustus 2026',
    startDate: '2026-08-01',
  );

  FinanceTransaction tx({
    required String type,
    required double amount,
    String category = 'Makanan',
  }) {
    return FinanceTransaction(
      bookPeriodId: 1,
      title: 't',
      amount: amount,
      type: type,
      category: category,
      date: '2026-08-05',
    );
  }

  final sample = [
    tx(type: 'INCOME', amount: 7500000, category: 'Gaji'),
    tx(type: 'EXPENSE', amount: 1850000, category: 'Makanan'),
    tx(type: 'EXPENSE', amount: 1100000, category: 'Transport'),
    tx(type: 'EXPENSE', amount: 900000, category: 'Belanja'),
    tx(type: 'EXPENSE', amount: 620000, category: 'Tagihan'),
    tx(type: 'EXPENSE', amount: 380000, category: 'Hiburan'),
    tx(type: 'EXPENSE', amount: 150000, category: 'Lain A'),
    tx(type: 'EXPENSE', amount: 100000, category: 'Lain B'),
  ];

  Future<void> pumpDetail(
    WidgetTester tester, {
    List<FinanceTransaction>? transactions,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BookCashflowDetailScreen(
          book: book,
          transactions: transactions ?? sample,
        ),
      ),
    );
    await tester.pump();
  }

  group('layar detail arus kas', () {
    testWidgets('nominal masuk dan keluar terbaca di batangnya', (
      tester,
    ) async {
      await pumpDetail(tester);

      // Grafik lama tidak menampilkan angka sama sekali.
      expect(find.text('7.500.000'), findsOneWidget);
      expect(find.text('5.100.000'), findsOneWidget);
    });

    testWidgets('rasio terpakai memberi konteks ke saldo bersih', (
      tester,
    ) async {
      await pumpDetail(tester);

      expect(find.textContaining('Terpakai'), findsOneWidget);
      expect(find.textContaining('68%'), findsOneWidget);
    });

    testWidgets('kategori tampil terurut dengan Lainnya yang menyebut jumlah', (
      tester,
    ) async {
      await pumpDetail(tester);

      // ListView membangun anaknya secara malas, dan panel kategori kini
      // duduk di bawah kalender pengeluaran.
      await tester.scrollUntilVisible(
        find.text('Makanan'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Makanan'), findsOneWidget);
      expect(find.text('Transport'), findsOneWidget);
      expect(find.text('Lainnya (2 kategori)'), findsOneWidget);
    });

    testWidgets('laporan formal dipisah di balik satu baris navigasi', (
      tester,
    ) async {
      await pumpDetail(tester);

      // Tidak diulang inline di layar ini.
      expect(find.text('LAPORAN ARUS KAS'), findsNothing);

      await tester.scrollUntilVisible(
        find.text('Laporan arus kas lengkap'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Laporan arus kas lengkap'), findsOneWidget);
      await tester.tap(find.text('Laporan arus kas lengkap'));
      await tester.pumpAndSettle();

      expect(find.text('LAPORAN ARUS KAS'), findsOneWidget);
    });

    testWidgets('tombol ekspor PDF dan CSV tersedia', (tester) async {
      await pumpDetail(tester);

      // ListView membangun anaknya secara malas, jadi tombol di dasar layar
      // belum ada di pohon widget sebelum digulung.
      await tester.scrollUntilVisible(
        find.text('Ekspor PDF'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Ekspor PDF'), findsOneWidget);
      expect(find.text('CSV'), findsOneWidget);
    });

    testWidgets('buku tanpa pengeluaran tidak menampilkan panel kategori', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        transactions: [tx(type: 'INCOME', amount: 1000000, category: 'Gaji')],
      );

      expect(find.text('PENGELUARAN PER KATEGORI'), findsNothing);
      expect(find.text('ARUS KAS'), findsOneWidget);
    });

    testWidgets('buku tanpa pemasukan tidak membagi dengan nol', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        transactions: [tx(type: 'EXPENSE', amount: 500000)],
      );

      expect(find.text('Belum ada pemasukan di buku ini.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('layar laporan formal', () {
    testWidgets('mengelompokkan pemasukan dan pengeluaran per kategori', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CashflowStatementScreen(book: book, transactions: []),
        ),
      );
      await tester.pump();

      expect(find.text('ARUS KAS DARI PEMASUKAN'), findsOneWidget);
      expect(find.text('ARUS KAS UNTUK PENGELUARAN'), findsOneWidget);
      expect(find.text('Tidak ada pemasukan tercatat.'), findsOneWidget);
      expect(find.text('Tidak ada pengeluaran tercatat.'), findsOneWidget);
    });

    testWidgets('menampilkan kenaikan kas bersih', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CashflowStatementScreen(book: book, transactions: sample),
        ),
      );
      await tester.pump();

      expect(find.text('KENAIKAN (PENURUNAN) KAS BERSIH'), findsOneWidget);
      expect(find.text('Jumlah pemasukan'), findsOneWidget);
      expect(find.text('Jumlah pengeluaran'), findsOneWidget);
    });
  });
}
