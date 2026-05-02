import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import '../models/book_period.dart';
import '../models/finance_transaction.dart';
import '../models/financial_plan.dart';

class DatabaseHelper {
  DatabaseHelper._internal();

  static final DatabaseHelper instance = DatabaseHelper._internal();

  static const _dbName = 'uangkeluar.db';
  static const _dbVersion = 7;
  static const transactionsTable = 'transactions';
  static const bookPeriodsTable = 'book_periods';
  static const financialPlansTable = 'financial_plans';
  static const shoppingItemsTable = 'shopping_items';

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path;
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
      path = _dbName;
    } else {
      final dbPath = await getDatabasesPath();
      path = join(dbPath, _dbName);
    }

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await _createSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            ALTER TABLE $transactionsTable
            ADD COLUMN book_period_id INTEGER
          ''');

          await db.execute('''
            CREATE TABLE IF NOT EXISTS $bookPeriodsTable (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              label TEXT NOT NULL,
              start_date TEXT NOT NULL,
              end_date TEXT,
              is_closed INTEGER NOT NULL DEFAULT 0
            )
          ''');
        }

        if (oldVersion < 3) {
          await db.execute('''
            ALTER TABLE $transactionsTable
            ADD COLUMN financial_plan_id INTEGER
          ''');

          await db.execute('''
            CREATE TABLE IF NOT EXISTS $financialPlansTable (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              book_period_id INTEGER NOT NULL,
              title TEXT NOT NULL,
              target_amount REAL NOT NULL,
              target_date TEXT NOT NULL
            )
          ''');
        }

        if (oldVersion < 4) {
          await db.execute('''
            ALTER TABLE $transactionsTable
            ADD COLUMN time TEXT
          ''');
        }

        if (oldVersion < 5) {
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_transactions_book_period_id ON $transactionsTable(book_period_id)',
          );
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_financial_plans_book_period_id ON $financialPlansTable(book_period_id)',
          );
        }

        if (oldVersion < 6) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS $shoppingItemsTable (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              book_period_id INTEGER NOT NULL,
              title TEXT NOT NULL,
              amount REAL NOT NULL,
              category TEXT NOT NULL,
              date TEXT NOT NULL,
              time TEXT,
              quantity REAL NOT NULL,
              unit TEXT NOT NULL,
              is_bought INTEGER NOT NULL DEFAULT 0,
              expense_transaction_id INTEGER
            )
          ''');
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_shopping_items_book_period_id ON $shoppingItemsTable(book_period_id)',
          );
        }

        if (oldVersion < 7) {
          await db.execute('''
            ALTER TABLE $shoppingItemsTable
            ADD COLUMN expense_transaction_id INTEGER
          ''');
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_shopping_items_expense_transaction_id ON $shoppingItemsTable(expense_transaction_id)',
          );
        }
      },
    );
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE $transactionsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_period_id INTEGER,
        financial_plan_id INTEGER,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        category TEXT NOT NULL,
        date TEXT NOT NULL,
        time TEXT,
        is_synced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE $bookPeriodsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        label TEXT NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT,
        is_closed INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE $financialPlansTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_period_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        target_amount REAL NOT NULL,
        target_date TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $shoppingItemsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_period_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        date TEXT NOT NULL,
        time TEXT,
        quantity REAL NOT NULL,
        unit TEXT NOT NULL,
        is_bought INTEGER NOT NULL DEFAULT 0,
        expense_transaction_id INTEGER
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transactions_book_period_id ON $transactionsTable(book_period_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_financial_plans_book_period_id ON $financialPlansTable(book_period_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_shopping_items_book_period_id ON $shoppingItemsTable(book_period_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_shopping_items_expense_transaction_id ON $shoppingItemsTable(expense_transaction_id)',
    );
  }

  Future<void> resetShoppingItemsByTransactionId(int transactionId) async {
    final db = await database;
    await db.update(
      shoppingItemsTable,
      {'is_bought': 0, 'amount': 0, 'expense_transaction_id': null},
      where: 'expense_transaction_id = ?',
      whereArgs: [transactionId],
    );
  }

  Future<int> insertTransaction(FinanceTransaction transaction) async {
    final db = await database;
    return db.insert(
      transactionsTable,
      transaction.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteTransaction(int id) async {
    final db = await database;
    await db.delete(transactionsTable, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateTransaction(FinanceTransaction transaction) async {
    if (transaction.id == null) return;
    final db = await database;
    await db.update(
      transactionsTable,
      transaction.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<List<FinanceTransaction>> getAllTransactions() async {
    final db = await database;
    final result = await db.query(
      transactionsTable,
      orderBy: 'date DESC, id DESC',
    );

    return result.map(FinanceTransaction.fromMap).toList();
  }

  Future<List<FinanceTransaction>> getUnsyncedTransactions() async {
    final db = await database;
    final result = await db.query(
      transactionsTable,
      where: 'is_synced = ?',
      whereArgs: [0],
      orderBy: 'date ASC, id ASC',
    );

    return result.map(FinanceTransaction.fromMap).toList();
  }

  Future<void> markTransactionsAsSynced(List<int> ids) async {
    if (ids.isEmpty) return;

    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');
    await db.rawUpdate(
      'UPDATE $transactionsTable SET is_synced = 1 WHERE id IN ($placeholders)',
      ids,
    );
  }

  Future<List<BookPeriod>> getAllBookPeriods() async {
    final db = await database;
    final result = await db.query(
      bookPeriodsTable,
      orderBy: 'start_date DESC, id DESC',
    );

    return result.map(BookPeriod.fromMap).toList();
  }

  Future<BookPeriod?> getOpenBookPeriod() async {
    final db = await database;
    final result = await db.query(
      bookPeriodsTable,
      where: 'is_closed = 0',
      orderBy: 'id DESC',
      limit: 1,
    );

    if (result.isEmpty) return null;
    return BookPeriod.fromMap(result.first);
  }

  Future<int> createBookPeriod(BookPeriod period) async {
    final db = await database;
    return db.insert(
      bookPeriodsTable,
      period.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<int> createBookPeriodWithPlans({
    required BookPeriod period,
    required List<FinancialPlan> initialPlans,
  }) async {
    final db = await database;

    return db.transaction<int>((txn) async {
      final periodId = await txn.insert(
        bookPeriodsTable,
        period.toMap()..remove('id'),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      for (final plan in initialPlans) {
        await txn.insert(financialPlansTable, {
          'book_period_id': periodId,
          'title': plan.title,
          'target_amount': plan.targetAmount,
          'target_date': plan.targetDate,
        }, conflictAlgorithm: ConflictAlgorithm.abort);
      }

      return periodId;
    });
  }

  Future<void> closeBookPeriod({
    required int bookPeriodId,
    required String endDate,
  }) async {
    final db = await database;
    await db.update(
      bookPeriodsTable,
      {'end_date': endDate, 'is_closed': 1},
      where: 'id = ?',
      whereArgs: [bookPeriodId],
    );
  }

  Future<void> reopenBookPeriod(int bookPeriodId) async {
    final db = await database;
    await db.update(
      bookPeriodsTable,
      {'end_date': null, 'is_closed': 0},
      where: 'id = ?',
      whereArgs: [bookPeriodId],
    );
  }

  Future<void> deleteBookPeriod(int bookPeriodId) async {
    final db = await database;

    await db.transaction((txn) async {
      await txn.delete(
        transactionsTable,
        where: 'book_period_id = ?',
        whereArgs: [bookPeriodId],
      );

      await txn.delete(
        financialPlansTable,
        where: 'book_period_id = ?',
        whereArgs: [bookPeriodId],
      );

      await txn.delete(
        bookPeriodsTable,
        where: 'id = ?',
        whereArgs: [bookPeriodId],
      );
    });
  }

  Future<List<FinancialPlan>> getAllFinancialPlans() async {
    final db = await database;
    final result = await db.query(
      financialPlansTable,
      orderBy: 'target_date ASC, id ASC',
    );
    return result.map(FinancialPlan.fromMap).toList();
  }

  Future<int> insertFinancialPlan(FinancialPlan plan) async {
    final db = await database;
    return db.insert(
      financialPlansTable,
      plan.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<void> updateFinancialPlan(FinancialPlan plan) async {
    final db = await database;
    await db.update(
      financialPlansTable,
      plan.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [plan.id],
    );
  }

  Future<void> deleteFinancialPlan(int id) async {
    final db = await database;
    await db.delete(financialPlansTable, where: 'id = ?', whereArgs: [id]);
  }
}
