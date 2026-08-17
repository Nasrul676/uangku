import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uangkeluar/services/database_helper.dart';

/// Menguji bahwa menghapus sebuah buku benar-benar membersihkan SEMUA baris
/// yang menggantung padanya. Empat tabel memakai `book_period_id NOT NULL`,
/// dan `shopping_items` sempat terlewat sehingga datanya jadi yatim.
void main() {
  late Database db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await DatabaseHelper.createSchemaForTesting(db);
  });

  tearDown(() async => db.close());

  Future<int> seedBook(String label) async {
    final bookId = await db.insert(DatabaseHelper.bookPeriodsTable, {
      'label': label,
      'start_date': '2026-01-01',
      'is_closed': 1,
      'end_date': '2026-01-31',
      'plan_budget': 0.0,
    });

    await db.insert(DatabaseHelper.transactionsTable, {
      'book_period_id': bookId,
      'title': 'Kopi',
      'amount': 25000.0,
      'type': 'EXPENSE',
      'category': 'Makanan',
      'date': '2026-01-05',
    });
    await db.insert(DatabaseHelper.financialPlansTable, {
      'book_period_id': bookId,
      'title': 'Dana darurat',
      'target_amount': 1000000.0,
      'target_date': '2026-01-31',
    });
    await db.insert(DatabaseHelper.shoppingItemsTable, {
      'book_period_id': bookId,
      'title': 'Beras',
      'amount': 70000.0,
      'category': 'Belanja',
      'date': '2026-01-06',
      'quantity': 1.0,
      'unit': 'karung',
    });
    await db.insert(DatabaseHelper.pocketsTable, {
      'book_period_id': bookId,
      'name': 'Jajan',
      'icon': 'wallet',
      'allocation_type': 'NOMINAL',
      'allocation_value': 500000.0,
    });

    return bookId;
  }

  Future<int> countIn(String table, int bookId) async {
    final rows = await db.query(
      table,
      where: 'book_period_id = ?',
      whereArgs: [bookId],
    );
    return rows.length;
  }

  test('menghapus buku membersihkan keempat tabel terkait', () async {
    final bookId = await seedBook('Januari 2026');

    expect(await countIn(DatabaseHelper.transactionsTable, bookId), 1);
    expect(await countIn(DatabaseHelper.financialPlansTable, bookId), 1);
    expect(await countIn(DatabaseHelper.shoppingItemsTable, bookId), 1);
    expect(await countIn(DatabaseHelper.pocketsTable, bookId), 1);

    await DatabaseHelper.deleteBookPeriodIn(db, bookId);

    expect(await countIn(DatabaseHelper.transactionsTable, bookId), 0);
    expect(await countIn(DatabaseHelper.financialPlansTable, bookId), 0);
    expect(
      await countIn(DatabaseHelper.shoppingItemsTable, bookId),
      0,
      reason: 'shopping_items tidak boleh tertinggal sebagai baris yatim',
    );
    expect(await countIn(DatabaseHelper.pocketsTable, bookId), 0);

    final books = await db.query(
      DatabaseHelper.bookPeriodsTable,
      where: 'id = ?',
      whereArgs: [bookId],
    );
    expect(books, isEmpty);
  });

  test('buku lain tidak ikut terhapus', () async {
    final target = await seedBook('Januari 2026');
    final other = await seedBook('Februari 2026');

    await DatabaseHelper.deleteBookPeriodIn(db, target);

    expect(await countIn(DatabaseHelper.transactionsTable, other), 1);
    expect(await countIn(DatabaseHelper.financialPlansTable, other), 1);
    expect(await countIn(DatabaseHelper.shoppingItemsTable, other), 1);
    expect(await countIn(DatabaseHelper.pocketsTable, other), 1);
  });
}
