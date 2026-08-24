import 'package:flutter_test/flutter_test.dart';
import 'package:uangkeluar/models/book_period.dart';
import 'package:uangkeluar/models/finance_transaction.dart';
import 'package:uangkeluar/utils/daily_budget.dart';
import 'package:uangkeluar/widgets/dashboard/pira_mascot.dart';

void main() {
  final today = DateTime(2026, 8, 17);

  FinanceTransaction tx({
    required double amount,
    required String date,
    String type = 'EXPENSE',
  }) {
    return FinanceTransaction(
      bookPeriodId: 1,
      title: 't',
      amount: amount,
      type: type,
      category: 'Makanan',
      date: date,
    );
  }

  group('buku dengan tanggal selesai', () {
    const book = BookPeriod(
      id: 1,
      label: 'Agustus 2026',
      startDate: '2026-08-01',
      endDate: '2026-08-31',
    );

    test('membagi saldo ke sisa hari, termasuk hari ini', () {
      final budget = buildDailyBudget(
        book: book,
        transactions: const [],
        balance: 1500000,
        today: today,
      );

      // 17 sampai 31 Agustus = 15 hari, bukan 14.
      expect(budget!.daysRemaining, 15);
      expect(budget.perDay, 100000);
      expect(budget.horizon, BudgetHorizon.sampaiTanggal);
    });

    test('buku yang selesai hari ini masih menyisakan satu hari', () {
      const endsToday = BookPeriod(
        id: 1,
        label: 'x',
        startDate: '2026-08-01',
        endDate: '2026-08-17',
      );

      final budget = buildDailyBudget(
        book: endsToday,
        transactions: const [],
        balance: 50000,
        today: today,
      );

      expect(budget!.daysRemaining, 1);
      expect(budget.perDay, 50000);
    });

    test('hanya menjumlahkan pengeluaran bertanggal hari ini', () {
      final budget = buildDailyBudget(
        book: book,
        transactions: [
          tx(amount: 30000, date: '2026-08-17'),
          tx(amount: 20000, date: '2026-08-17'),
          tx(amount: 900000, date: '2026-08-16'),
          tx(amount: 500000, date: '2026-08-17', type: 'INCOME'),
        ],
        balance: 1500000,
        today: today,
      );

      expect(budget!.spentToday, 50000);
      expect(budget.remainingToday, 50000);
      expect(budget.isOverToday, isFalse);
    });

    test('tanggal bertanda waktu tetap terbaca', () {
      final budget = buildDailyBudget(
        book: book,
        transactions: [tx(amount: 25000, date: '2026-08-17T09:30:00.000')],
        balance: 1500000,
        today: today,
      );

      expect(budget!.spentToday, 25000);
    });

    test('lewat jatah ditandai, dan batangnya tidak melebihi penuh', () {
      final budget = buildDailyBudget(
        book: book,
        transactions: [tx(amount: 400000, date: '2026-08-17')],
        balance: 1500000,
        today: today,
      );

      expect(budget!.isOverToday, isTrue);
      expect(budget.remainingToday, lessThan(0));
      expect(budget.usedRatio, 1.0);
    });

    test('buku yang sudah lewat tanggal selesainya tidak diramal', () {
      const expired = BookPeriod(
        id: 1,
        label: 'x',
        startDate: '2026-07-01',
        endDate: '2026-07-31',
      );

      expect(
        buildDailyBudget(
          book: expired,
          transactions: const [],
          balance: 100000,
          today: today,
        ),
        isNull,
      );
    });

    test('tanggal selesai yang tidak bisa dibaca menghasilkan null', () {
      const broken = BookPeriod(
        id: 1,
        label: 'x',
        startDate: '2026-08-01',
        endDate: 'bukan tanggal',
      );

      expect(
        buildDailyBudget(
          book: broken,
          transactions: const [],
          balance: 100000,
          today: today,
        ),
        isNull,
      );
    });
  });

  group('buku yang masih terbuka', () {
    const open = BookPeriod(
      id: 1,
      label: 'Agustus 2026',
      startDate: '2026-08-01',
    );

    test('memperkirakan sisa hari dari rata-rata tujuh hari terakhir', () {
      final budget = buildDailyBudget(
        book: open,
        transactions: [
          for (var d = 11; d <= 17; d++)
            tx(amount: 100000, date: '2026-08-${d.toString().padLeft(2, '0')}'),
        ],
        balance: 700000,
        today: today,
      );

      expect(budget!.horizon, BudgetHorizon.perkiraan);
      expect(budget.perDay, 100000);
      expect(budget.daysRemaining, 7);
      expect(budget.until, isNull);
    });

    test('pengeluaran di luar tujuh hari terakhir tidak ikut dihitung', () {
      final budget = buildDailyBudget(
        book: open,
        transactions: [
          tx(amount: 5000000, date: '2026-08-01'), // di luar jendela
          tx(amount: 100000, date: '2026-08-17'),
        ],
        balance: 700000,
        today: today,
      );

      // Kalau yang 5 juta ikut, rata-ratanya meledak dan sisa hari jadi 0.
      expect(budget, isNotNull);
      expect(budget!.perDay, closeTo(100000 / 7, 0.01));
    });

    test('buku yang baru dibuka dibagi hari berjalan, bukan tujuh', () {
      const fresh = BookPeriod(id: 1, label: 'x', startDate: '2026-08-16');

      final budget = buildDailyBudget(
        book: fresh,
        transactions: [
          tx(amount: 100000, date: '2026-08-16'),
          tx(amount: 100000, date: '2026-08-17'),
        ],
        balance: 1000000,
        today: today,
      );

      // Dua hari berjalan, dua ratus ribu — seratus ribu per hari.
      // Dibagi tujuh, angkanya akan terlihat jauh lebih hemat dari kenyataan.
      expect(budget!.perDay, 100000);
      expect(budget.daysRemaining, 10);
    });

    test('belum ada pengeluaran sama sekali menghasilkan null', () {
      expect(
        buildDailyBudget(
          book: open,
          transactions: const [],
          balance: 1000000,
          today: today,
        ),
        isNull,
      );
    });

    test('saldo yang tak cukup untuk sehari pun menghasilkan null', () {
      expect(
        buildDailyBudget(
          book: open,
          transactions: [tx(amount: 100000, date: '2026-08-17')],
          balance: 5000,
          today: today,
        ),
        isNull,
      );
    });
  });

  test('saldo nol atau minus tidak menghasilkan jatah harian', () {
    const book = BookPeriod(
      id: 1,
      label: 'x',
      startDate: '2026-08-01',
      endDate: '2026-08-31',
    );

    for (final balance in [0.0, -50000.0]) {
      expect(
        buildDailyBudget(
          book: book,
          transactions: const [],
          balance: balance,
          today: today,
        ),
        isNull,
        reason: 'saldo $balance',
      );
    }
  });

  group('moodForRatio', () {
    test('memetakan rasio ke tiga suasana', () {
      expect(moodForRatio(0.4), PiraMood.santai);
      expect(moodForRatio(0.7), PiraMood.hatiHati);
      expect(moodForRatio(0.99), PiraMood.hatiHati);
      expect(moodForRatio(1.01), PiraMood.lewatBatas);
    });

    test('tepat 100% belum dianggap lewat batas', () {
      expect(moodForRatio(1.0), PiraMood.hatiHati);
    });

    test('belum ada data tidak membuat wajahnya cemas', () {
      // Pengguna baru yang belum mencatat apa pun tidak pantas disambut
      // celengan yang khawatir.
      expect(moodForRatio(null), PiraMood.santai);
    });
  });
}
