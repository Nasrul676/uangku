import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uangkeluar/models/finance_transaction.dart';
import 'package:uangkeluar/models/money_location.dart';
import 'package:uangkeluar/models/money_transfer.dart';
import 'package:uangkeluar/services/database_helper.dart';
import 'package:uangkeluar/models/book_period.dart';
import 'package:uangkeluar/utils/cashflow_recap.dart';
import 'package:uangkeluar/utils/money_location_balance.dart';

MoneyLocation location(int id, {double initialBalance = 0}) => MoneyLocation(
  id: id,
  name: 'Lokasi $id',
  icon: 'wallet',
  initialBalance: initialBalance,
  createdAt: '2026-01-01T00:00:00.000',
);

MoneyTransfer transfer({
  int? from,
  int? to,
  double amount = 100000,
  String date = '2026-08-20',
}) => MoneyTransfer(
  fromLocationId: from,
  toLocationId: to,
  amount: amount,
  date: date,
  time: '10:00',
  createdAt: '2026-08-20T10:00:00.000',
);

FinanceTransaction tx({
  required String type,
  required double amount,
  int? locationId,
}) => FinanceTransaction(
  bookPeriodId: 1,
  moneyLocationId: locationId,
  title: 'Transaksi',
  amount: amount,
  type: type,
  category: 'Lain-lain',
  date: '2026-08-05',
);

void main() {
  group('saldo lokasi dengan perpindahan', () {
    test('transfer memindahkan uang: asal berkurang, tujuan bertambah', () {
      final totals = buildMoneyLocationNetTotals(
        const [],
        transfers: [transfer(from: 1, to: 2, amount: 100000)],
      );

      expect(totals[1], -100000);
      expect(totals[2], 100000);
    });

    test('total seluruh lokasi tidak berubah oleh transfer', () {
      final transactions = [
        tx(type: 'INCOME', amount: 1000000, locationId: 1),
      ];
      final locations = [location(1), location(2)];

      final before = buildMoneyLocationSummaries(
        locations: locations,
        transactions: transactions,
      ).fold<double>(0, (sum, item) => sum + item.balance);

      final after = buildMoneyLocationSummaries(
        locations: locations,
        transactions: transactions,
        transfers: [transfer(from: 1, to: 2, amount: 400000)],
      ).fold<double>(0, (sum, item) => sum + item.balance);

      expect(after, before);
    });

    test('tarik tunai: rekening turun, dompet naik, saldo awal ikut dihitung', () {
      final summaries = buildMoneyLocationSummaries(
        locations: [
          location(1, initialBalance: 2000000), // Rekening
          location(2, initialBalance: 50000), // Dompet
        ],
        transactions: const [],
        transfers: [transfer(from: 1, to: 2, amount: 500000)],
      );

      expect(summaries[0].balance, 1500000);
      expect(summaries[1].balance, 550000);
    });

    test('beberapa transfer menumpuk', () {
      final totals = buildMoneyLocationNetTotals(
        const [],
        transfers: [
          transfer(from: 1, to: 2, amount: 100000),
          transfer(from: 1, to: 2, amount: 250000),
          transfer(from: 2, to: 1, amount: 50000),
        ],
      );

      expect(totals[1], -300000);
      expect(totals[2], 300000);
    });

    test('sisi yang lokasinya sudah dihapus tidak mengubah sisi yang tersisa', () {
      final totals = buildMoneyLocationNetTotals(
        const [],
        transfers: [transfer(from: null, to: 2, amount: 100000)],
      );

      expect(totals[2], 100000);
      expect(totals.containsKey(null), isFalse);
      expect(totals.length, 1);
    });

    test('tanpa transfer, hasilnya sama seperti sebelum fitur ini ada', () {
      final transactions = [
        tx(type: 'INCOME', amount: 700000, locationId: 1),
        tx(type: 'EXPENSE', amount: 200000, locationId: 1),
      ];

      expect(
        buildMoneyLocationNetTotals(transactions),
        buildMoneyLocationNetTotals(transactions, transfers: const []),
      );
    });
  });

  group('transfer tidak menyentuh arus kas', () {
    test('laporan arus kas tidak melihat transfer sama sekali', () {
      final book = BookPeriod(
        id: 1,
        label: 'Agustus 2026',
        startDate: '2026-08-01',
        endDate: '2026-08-31',
        isClosed: 1,
      );
      final transactions = [
        tx(type: 'INCOME', amount: 1000000, locationId: 1),
        tx(type: 'EXPENSE', amount: 300000, locationId: 1),
      ];

      final recap = buildCashflowRecap([book], transactions).books.first;

      // Transfer hidup di tabelnya sendiri dan tidak pernah masuk daftar
      // transaksi, jadi tidak ada jalan bagi laporan untuk melihatnya.
      expect(recap.totalIncome, 1000000);
      expect(recap.totalExpense, 300000);
      expect(recap.net, 700000);
    });
  });

  group('penghapusan lokasi', () {
    late Database db;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await DatabaseHelper.createSchemaForTesting(db);
      await db.delete(DatabaseHelper.moneyLocationsTable);
    });

    tearDown(() async => db.close());

    Future<int> seedLocation(String name) => db.insert(
      DatabaseHelper.moneyLocationsTable,
      {
        'name': name,
        'icon': 'wallet',
        'initial_balance': 0.0,
        'sort_order': 0,
        'is_archived': 0,
        'created_at': '2026-01-01T00:00:00.000',
      },
    );

    Future<int> seedTransfer(int from, int to) => db.insert(
      DatabaseHelper.moneyTransfersTable,
      {
        'from_location_id': from,
        'to_location_id': to,
        'amount': 500000.0,
        'date': '2026-08-20',
        'time': '10:00',
        'created_at': '2026-08-20T10:00:00.000',
      },
    );

    test('hapus lokasi asal menyisakan barisnya, uang tujuan tetap utuh', () async {
      final atm = await seedLocation('ATM');
      final dompet = await seedLocation('Dompet');
      await seedTransfer(atm, dompet);

      await DatabaseHelper.deleteMoneyLocationFrom(db, atm);

      final rows = await db.query(DatabaseHelper.moneyTransfersTable);
      expect(rows, hasLength(1));
      expect(rows.first['from_location_id'], isNull);
      expect(rows.first['to_location_id'], dompet);

      // Dompet benar-benar menerima uang itu, jadi saldonya tidak boleh ikut
      // hilang cuma karena ATM dibuang.
      final totals = buildMoneyLocationNetTotals(
        const [],
        transfers: rows.map(MoneyTransfer.fromMap).toList(),
      );
      expect(totals[dompet], 500000);
    });

    test('hapus kedua lokasi membuang baris transfernya', () async {
      final atm = await seedLocation('ATM');
      final dompet = await seedLocation('Dompet');
      await seedTransfer(atm, dompet);

      await DatabaseHelper.deleteMoneyLocationFrom(db, atm);
      await DatabaseHelper.deleteMoneyLocationFrom(db, dompet);

      final rows = await db.query(DatabaseHelper.moneyTransfersTable);
      expect(rows, isEmpty);
    });

    test('transfer milik lokasi lain tidak ikut tersentuh', () async {
      final atm = await seedLocation('ATM');
      final dompet = await seedLocation('Dompet');
      final gopay = await seedLocation('Gopay');
      await seedTransfer(atm, dompet);
      await seedTransfer(dompet, gopay);

      await DatabaseHelper.deleteMoneyLocationFrom(db, atm);

      final rows = await db.query(
        DatabaseHelper.moneyTransfersTable,
        where: 'from_location_id = ?',
        whereArgs: [dompet],
      );
      expect(rows, hasLength(1));
      expect(rows.first['to_location_id'], gopay);
    });
  });

  group('migrasi', () {
    late Database db;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    });

    tearDown(() async => db.close());

    test('tabel money_transfers ada setelah upgrade dari v18', () async {
      await db.execute('''
        CREATE TABLE ${DatabaseHelper.transactionsTable} (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          amount REAL NOT NULL,
          type TEXT NOT NULL,
          category TEXT NOT NULL,
          date TEXT NOT NULL
        )
      ''');

      await DatabaseHelper.applyMigrationsForTesting(db, 18);

      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name = ?",
        [DatabaseHelper.moneyTransfersTable],
      );
      expect(tables, hasLength(1));
    });
  });
}
