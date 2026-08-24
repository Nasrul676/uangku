import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uangkeluar/services/database_helper.dart';

/// Migrasi v18 → v19 menyentuh tabel `transactions` milik pengguna yang sudah
/// berisi data nyata. Test ini membangun skema versi lama apa adanya, lalu
/// membuktikan tiga hal: kolom baru muncul, transaksi lama tidak hilang atau
/// berubah, dan lokasi bawaan terisi.
void main() {
  late Database db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
  });

  tearDown(() async => db.close());

  /// Skema `transactions` persis seperti sebelum v19 — tanpa
  /// `money_location_id`.
  Future<void> createV18Transactions() async {
    await db.execute('''
      CREATE TABLE ${DatabaseHelper.transactionsTable} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_period_id INTEGER,
        financial_plan_id INTEGER,
        pocket_id INTEGER,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        category TEXT NOT NULL,
        date TEXT NOT NULL,
        time TEXT,
        is_synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  test('migrasi v18 ke v19 menambah kolom money_location_id', () async {
    await createV18Transactions();

    await DatabaseHelper.applyMigrationsForTesting(db, 18);

    final columns = await db.rawQuery(
      'PRAGMA table_info(${DatabaseHelper.transactionsTable})',
    );
    expect(
      columns.any((column) => column['name'] == 'money_location_id'),
      isTrue,
    );
  });

  test('transaksi lama tetap utuh dan lokasinya kosong', () async {
    await createV18Transactions();
    await db.insert(DatabaseHelper.transactionsTable, {
      'title': 'Kopi',
      'amount': 25000.0,
      'type': 'EXPENSE',
      'category': 'Makanan',
      'date': '2026-01-05',
    });

    await DatabaseHelper.applyMigrationsForTesting(db, 18);

    final rows = await db.query(DatabaseHelper.transactionsTable);
    expect(rows, hasLength(1));
    expect(rows.first['title'], 'Kopi');
    expect(rows.first['amount'], 25000.0);
    expect(rows.first['money_location_id'], isNull);
  });

  test('migrasi mengisi dua lokasi bawaan', () async {
    await createV18Transactions();

    await DatabaseHelper.applyMigrationsForTesting(db, 18);

    final locations = await db.query(
      DatabaseHelper.moneyLocationsTable,
      orderBy: 'sort_order ASC',
    );
    expect(locations.map((row) => row['name']), ['Dompet', 'Rekening / ATM']);
  });

  test('migrasi ulang tidak menggandakan lokasi bawaan', () async {
    await createV18Transactions();

    await DatabaseHelper.applyMigrationsForTesting(db, 18);
    await DatabaseHelper.applyMigrationsForTesting(db, 18);

    final locations = await db.query(DatabaseHelper.moneyLocationsTable);
    expect(locations, hasLength(2));
  });

  test('lokasi buatan pengguna tidak ditimpa seed', () async {
    await createV18Transactions();
    await DatabaseHelper.applyMigrationsForTesting(db, 18);
    await db.delete(DatabaseHelper.moneyLocationsTable);
    await db.insert(DatabaseHelper.moneyLocationsTable, {
      'name': 'Gopay',
      'icon': 'wallet',
      'initial_balance': 0.0,
      'sort_order': 0,
      'is_archived': 0,
      'created_at': '2026-01-01T00:00:00.000',
    });

    await DatabaseHelper.applyMigrationsForTesting(db, 18);

    final locations = await db.query(DatabaseHelper.moneyLocationsTable);
    expect(locations.map((row) => row['name']), ['Gopay']);
  });

  test('transaksi berulang ikut dapat kolom money_location_id', () async {
    await createV18Transactions();
    await db.execute('''
      CREATE TABLE ${DatabaseHelper.recurringTransactionsTable} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        title TEXT NOT NULL,
        category TEXT NOT NULL,
        frequency TEXT NOT NULL,
        next_date TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        pocket_id INTEGER,
        financial_plan_id INTEGER
      )
    ''');

    await DatabaseHelper.applyMigrationsForTesting(db, 18);

    final columns = await db.rawQuery(
      'PRAGMA table_info(${DatabaseHelper.recurringTransactionsTable})',
    );
    expect(
      columns.any((column) => column['name'] == 'money_location_id'),
      isTrue,
    );
  });

  test('instalasi baru langsung punya kolom dan lokasi bawaan', () async {
    await DatabaseHelper.createSchemaForTesting(db);

    final columns = await db.rawQuery(
      'PRAGMA table_info(${DatabaseHelper.transactionsTable})',
    );
    expect(
      columns.any((column) => column['name'] == 'money_location_id'),
      isTrue,
    );
    final locations = await db.query(DatabaseHelper.moneyLocationsTable);
    expect(locations, hasLength(2));
  });
}
