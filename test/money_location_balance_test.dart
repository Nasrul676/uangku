import 'package:flutter_test/flutter_test.dart';
import 'package:uangkeluar/models/finance_transaction.dart';
import 'package:uangkeluar/models/money_location.dart';
import 'package:uangkeluar/utils/money_location_balance.dart';

MoneyLocation location(int id, {double initialBalance = 0}) => MoneyLocation(
  id: id,
  name: 'Lokasi $id',
  icon: 'wallet',
  initialBalance: initialBalance,
  createdAt: '2026-01-01T00:00:00.000',
);

FinanceTransaction tx({
  required String type,
  required double amount,
  int? locationId,
  int? bookId,
}) => FinanceTransaction(
  bookPeriodId: bookId,
  moneyLocationId: locationId,
  title: 'Transaksi',
  amount: amount,
  type: type,
  category: 'Lain-lain',
  date: '2026-01-05',
);

void main() {
  group('buildMoneyLocationNetTotals', () {
    test('pemasukan menambah, pengeluaran mengurangi', () {
      final totals = buildMoneyLocationNetTotals([
        tx(type: 'INCOME', amount: 1000000, locationId: 1),
        tx(type: 'EXPENSE', amount: 250000, locationId: 1),
      ]);

      expect(totals[1], 750000);
    });

    test('tiap lokasi terpisah, tidak saling bocor', () {
      final totals = buildMoneyLocationNetTotals([
        tx(type: 'INCOME', amount: 500000, locationId: 1),
        tx(type: 'EXPENSE', amount: 200000, locationId: 2),
      ]);

      expect(totals[1], 500000);
      expect(totals[2], -200000);
    });

    test('transaksi tanpa lokasi tidak masuk ke lokasi mana pun', () {
      final totals = buildMoneyLocationNetTotals([
        tx(type: 'INCOME', amount: 900000),
        tx(type: 'INCOME', amount: 100000, locationId: 1),
      ]);

      expect(totals[1], 100000);
      expect(totals.values.fold<double>(0, (a, b) => a + b), 100000);
    });

    test('lokasi tanpa transaksi tidak muncul di peta', () {
      expect(buildMoneyLocationNetTotals(const []), isEmpty);
    });

    test('transaksi dari periode buku berbeda tetap dijumlahkan', () {
      final totals = buildMoneyLocationNetTotals([
        tx(type: 'INCOME', amount: 300000, locationId: 1, bookId: 1),
        tx(type: 'INCOME', amount: 200000, locationId: 1, bookId: 2),
      ]);

      expect(totals[1], 500000);
    });
  });

  group('unassignedNetTotal', () {
    test('hanya menghitung transaksi tanpa lokasi', () {
      final total = unassignedNetTotal([
        tx(type: 'INCOME', amount: 1000000),
        tx(type: 'EXPENSE', amount: 400000),
        tx(type: 'EXPENSE', amount: 999999, locationId: 3),
      ]);

      expect(total, 600000);
    });

    test('nol saat semua transaksi sudah punya lokasi', () {
      final total = unassignedNetTotal([
        tx(type: 'INCOME', amount: 1000000, locationId: 1),
      ]);

      expect(total, 0);
    });
  });

  group('resolveMoneyLocationBalance', () {
    test('lokasi tanpa transaksi bersaldo sama dengan saldo awal', () {
      final balance = resolveMoneyLocationBalance(
        location: location(1, initialBalance: 200000),
        netTotals: const {},
      );

      expect(balance, 200000);
    });

    test('saldo awal ditambah arus bersih', () {
      final balance = resolveMoneyLocationBalance(
        location: location(1, initialBalance: 200000),
        netTotals: const {1: -50000},
      );

      expect(balance, 150000);
    });

    test('saldo bisa negatif kalau pengeluaran melebihi isinya', () {
      final balance = resolveMoneyLocationBalance(
        location: location(1),
        netTotals: const {1: -75000},
      );

      expect(balance, -75000);
    });
  });

  group('buildMoneyLocationSummaries', () {
    test('menjaga urutan daftar lokasi dan mengisi saldo tiap lokasi', () {
      final summaries = buildMoneyLocationSummaries(
        locations: [
          location(2, initialBalance: 100000),
          location(1, initialBalance: 50000),
        ],
        transactions: [
          tx(type: 'EXPENSE', amount: 25000, locationId: 1),
          tx(type: 'INCOME', amount: 400000, locationId: 2),
        ],
      );

      expect(summaries.map((item) => item.id), [2, 1]);
      expect(summaries[0].balance, 500000);
      expect(summaries[1].balance, 25000);
    });

    test('daftar lokasi kosong menghasilkan ringkasan kosong', () {
      expect(
        buildMoneyLocationSummaries(
          locations: const [],
          transactions: [tx(type: 'INCOME', amount: 1000, locationId: 1)],
        ),
        isEmpty,
      );
    });
  });
}
