import 'package:flutter_test/flutter_test.dart';
import 'package:uangkeluar/models/book_period.dart';
import 'package:uangkeluar/models/finance_transaction.dart';
import 'package:uangkeluar/utils/cashflow_recap.dart';

FinanceTransaction tx({
  required int bookId,
  required String type,
  required double amount,
  String category = 'Lain-lain',
}) {
  return FinanceTransaction(
    bookPeriodId: bookId,
    title: 't',
    amount: amount,
    type: type,
    category: category,
    date: '2026-08-01',
  );
}

void main() {
  // Terurut terbaru ke terlama, sesuai keluaran getAllBookPeriods().
  final books = [
    const BookPeriod(id: 3, label: 'Agustus', startDate: '2026-08-01'),
    const BookPeriod(id: 2, label: 'Juli', startDate: '2026-07-01'),
    const BookPeriod(id: 1, label: 'Juni', startDate: '2026-06-01'),
  ];

  group('buildCashflowRecap', () {
    test('menjumlah pemasukan dan pengeluaran per buku', () {
      final recap = buildCashflowRecap(books, [
        tx(bookId: 3, type: 'INCOME', amount: 7500000),
        tx(bookId: 3, type: 'EXPENSE', amount: 5100000),
        tx(bookId: 2, type: 'INCOME', amount: 7000000),
        tx(bookId: 2, type: 'EXPENSE', amount: 5800000),
      ]);

      expect(recap.books.first.totalIncome, 7500000);
      expect(recap.books.first.totalExpense, 5100000);
      expect(recap.books.first.net, 2400000);
      expect(recap.books.first.transactionCount, 2);
    });

    test('total lintas buku dijumlah dari semua transaksi', () {
      final recap = buildCashflowRecap(books, [
        tx(bookId: 3, type: 'INCOME', amount: 7500000),
        tx(bookId: 2, type: 'INCOME', amount: 7000000),
        tx(bookId: 1, type: 'EXPENSE', amount: 7600000),
      ]);

      expect(recap.totalIncome, 14500000);
      expect(recap.totalExpense, 7600000);
      expect(recap.net, 6900000);
    });

    test('delta dihitung terhadap buku yang lebih lama', () {
      final recap = buildCashflowRecap(books, [
        tx(bookId: 3, type: 'EXPENSE', amount: 5100000), // Agustus
        tx(bookId: 2, type: 'EXPENSE', amount: 5800000), // Juli
        tx(bookId: 1, type: 'EXPENSE', amount: 7600000), // Juni
      ]);

      // Agustus vs Juli: (5.1 - 5.8) / 5.8 = -12%
      expect(recap.books[0].expenseDeltaRatio, closeTo(-0.1207, 0.001));
      // Juli vs Juni: (5.8 - 7.6) / 7.6 = -23.7%
      expect(recap.books[1].expenseDeltaRatio, closeTo(-0.2368, 0.001));
      // Juni tidak punya pembanding.
      expect(recap.books[2].expenseDeltaRatio, isNull);
    });

    test('delta null kalau buku sebelumnya tidak punya pengeluaran', () {
      final recap = buildCashflowRecap(books, [
        tx(bookId: 3, type: 'EXPENSE', amount: 5100000),
      ]);

      // Juli nol pengeluaran — persentase perubahan dari nol tidak bermakna.
      expect(recap.books[0].expenseDeltaRatio, isNull);
    });

    test('rasio terpakai dan tanda boros', () {
      final recap = buildCashflowRecap(books, [
        tx(bookId: 3, type: 'INCOME', amount: 7500000),
        tx(bookId: 3, type: 'EXPENSE', amount: 5100000),
        tx(bookId: 2, type: 'INCOME', amount: 7200000),
        tx(bookId: 2, type: 'EXPENSE', amount: 7600000),
      ]);

      expect(recap.books[0].spentRatio, closeTo(0.68, 0.001));
      expect(recap.books[0].isOverspending, isFalse);

      expect(recap.books[1].spentRatio, closeTo(1.0556, 0.001));
      expect(recap.books[1].isOverspending, isTrue);
    });

    test('rasio null kalau belum ada pemasukan, bukan pembagian nol', () {
      final recap = buildCashflowRecap(books, [
        tx(bookId: 3, type: 'EXPENSE', amount: 100000),
      ]);

      expect(recap.books[0].spentRatio, isNull);
      expect(recap.books[0].isOverspending, isFalse);
    });

    test('transaksi tanpa buku diabaikan, tidak menggagalkan rekap', () {
      final recap = buildCashflowRecap(books, [
        FinanceTransaction(
          title: 'yatim',
          amount: 999,
          type: 'EXPENSE',
          category: 'x',
          date: '2026-08-01',
        ),
        tx(bookId: 3, type: 'EXPENSE', amount: 100),
      ]);

      expect(recap.totalExpense, 100);
    });

    test('maxAbsoluteNet ikut memperhitungkan buku yang minus', () {
      final recap = buildCashflowRecap(books, [
        tx(bookId: 3, type: 'INCOME', amount: 1000),
        tx(bookId: 1, type: 'EXPENSE', amount: 5000),
      ]);

      expect(recap.maxAbsoluteNet, 5000);
    });

    test('tanpa buku menghasilkan rekap kosong', () {
      final recap = buildCashflowRecap(const [], const []);
      expect(recap.isEmpty, isTrue);
      expect(recap.net, 0);
      expect(recap.maxAbsoluteNet, 0);
    });
  });

  group('buildCategoryBreakdown', () {
    test('terurut menurun dengan porsi yang benar', () {
      final slices = buildCategoryBreakdown([
        tx(bookId: 1, type: 'EXPENSE', amount: 900000, category: 'Belanja'),
        tx(bookId: 1, type: 'EXPENSE', amount: 1850000, category: 'Makanan'),
        tx(bookId: 1, type: 'EXPENSE', amount: 1100000, category: 'Transport'),
      ]);

      expect(slices.map((s) => s.label), ['Makanan', 'Transport', 'Belanja']);
      expect(slices.first.share, closeTo(1850000 / 3850000, 0.0001));
    });

    test('pemasukan tidak ikut terhitung', () {
      final slices = buildCategoryBreakdown([
        tx(bookId: 1, type: 'INCOME', amount: 9000000, category: 'Gaji'),
        tx(bookId: 1, type: 'EXPENSE', amount: 100000, category: 'Makanan'),
      ]);

      expect(slices, hasLength(1));
      expect(slices.first.label, 'Makanan');
      expect(slices.first.share, 1);
    });

    test('kategori di luar lima teratas dilipat dan jumlahnya disebut', () {
      final slices = buildCategoryBreakdown([
        for (var i = 0; i < 9; i++)
          tx(
            bookId: 1,
            type: 'EXPENSE',
            amount: (9 - i) * 100000,
            category: 'Kategori $i',
          ),
      ]);

      expect(slices, hasLength(6));
      final other = slices.last;
      expect(other.isOther, isTrue);
      expect(other.label, 'Lainnya');
      // Sisa 4 kategori: 400k + 300k + 200k + 100k.
      expect(other.collapsedCount, 4);
      expect(other.amount, 1000000);
    });

    test('tanpa kategori tersisa, baris Lainnya tidak dibuat', () {
      final slices = buildCategoryBreakdown([
        tx(bookId: 1, type: 'EXPENSE', amount: 100, category: 'A'),
        tx(bookId: 1, type: 'EXPENSE', amount: 200, category: 'B'),
      ]);

      expect(slices.any((s) => s.isOther), isFalse);
    });

    test('porsi seluruh baris berjumlah satu', () {
      final slices = buildCategoryBreakdown([
        for (var i = 0; i < 8; i++)
          tx(
            bookId: 1,
            type: 'EXPENSE',
            amount: (i + 1) * 50000,
            category: 'K$i',
          ),
      ]);

      final total = slices.fold<double>(0, (sum, s) => sum + s.share);
      expect(total, closeTo(1.0, 0.0001));
    });

    test('tanpa pengeluaran mengembalikan daftar kosong', () {
      expect(buildCategoryBreakdown(const []), isEmpty);
    });
  });
}
