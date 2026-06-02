import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import '../models/book_period.dart';
import '../models/finance_transaction.dart';
import '../models/financial_plan.dart';
import '../models/pocket.dart';
import '../models/recurring_transaction.dart';
import '../models/saving_goal.dart';
import '../models/saving_history.dart';

class DatabaseHelper {
  DatabaseHelper._internal();

  static final DatabaseHelper instance = DatabaseHelper._internal();

  static const _dbName = 'uangkeluar.db';
  static const _dbVersion = 14;
  static const transactionsTable = 'transactions';
  static const bookPeriodsTable = 'book_periods';
  static const financialPlansTable = 'financial_plans';
  static const shoppingItemsTable = 'shopping_items';
  static const pocketsTable = 'pockets';
  static const notificationsTable = 'notifications';
  static const savingGoalsTable = 'saving_goals';
  static const savingHistoriesTable = 'saving_histories';
  static const recurringTransactionsTable = 'recurring_transactions';

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<void> checkpointDatabase() async {
    if (_database != null && _database!.isOpen) {
      // Gunakan rawQuery, BUKAN execute, untuk PRAGMA yang mengembalikan nilai
      await _database!.rawQuery('PRAGMA wal_checkpoint(FULL)');
    }
  }

  Future<void> closeDatabase() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
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
          // Check if column already exists (added in version 6 in some builds)
          var columns = await db.rawQuery('PRAGMA table_info($shoppingItemsTable)');
          bool columnExists = columns.any((column) => column['name'] == 'expense_transaction_id');
          
          if (!columnExists) {
            await db.execute('''
              ALTER TABLE $shoppingItemsTable
              ADD COLUMN expense_transaction_id INTEGER
            ''');
          }
          
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_shopping_items_expense_transaction_id ON $shoppingItemsTable(expense_transaction_id)',
          );
        }

        if (oldVersion < 8) {
          await db.execute('''
            ALTER TABLE $transactionsTable
            ADD COLUMN pocket_id INTEGER
          ''');

          await db.execute('''
            CREATE TABLE IF NOT EXISTS $pocketsTable (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              book_period_id INTEGER NOT NULL,
              name TEXT NOT NULL,
              icon TEXT NOT NULL,
              allocation_type TEXT NOT NULL,
              allocation_value REAL NOT NULL,
              current_balance REAL NOT NULL DEFAULT 0
            )
          ''');
          
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_pockets_book_period_id ON $pocketsTable(book_period_id)',
          );
        }

        if (oldVersion < 9) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS $notificationsTable (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              title TEXT NOT NULL,
              subtitle TEXT NOT NULL,
              type TEXT NOT NULL,
              is_read INTEGER NOT NULL DEFAULT 0,
              created_at TEXT NOT NULL
            )
          ''');
        }
        if (oldVersion < 10) {
          await db.execute('''
            ALTER TABLE $financialPlansTable
            ADD COLUMN category TEXT
          ''');
        }
        if (oldVersion < 11) {
          await db.execute('''
            ALTER TABLE $bookPeriodsTable
            ADD COLUMN plan_budget REAL NOT NULL DEFAULT 0
          ''');
        }
        if (oldVersion < 12) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS $savingGoalsTable (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              title TEXT NOT NULL,
              target_amount REAL NOT NULL,
              current_amount REAL NOT NULL DEFAULT 0,
              target_date TEXT,
              icon TEXT
            )
          ''');
          
          await db.execute('''
            CREATE TABLE IF NOT EXISTS $recurringTransactionsTable (
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
        }
        if (oldVersion < 13) {
          await db.execute('''
            ALTER TABLE $recurringTransactionsTable
            ADD COLUMN pocket_id INTEGER
          ''');
          await db.execute('''
            ALTER TABLE $recurringTransactionsTable
            ADD COLUMN financial_plan_id INTEGER
          ''');
        }
        if (oldVersion < 14) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS $savingHistoriesTable (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              saving_goal_id INTEGER NOT NULL,
              amount REAL NOT NULL,
              who TEXT NOT NULL,
              date TEXT NOT NULL
            )
          ''');
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_saving_histories_goal_id ON $savingHistoriesTable(saving_goal_id)',
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

    await db.execute('''
      CREATE TABLE $bookPeriodsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        label TEXT NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT,
        is_closed INTEGER NOT NULL DEFAULT 0,
        plan_budget REAL NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE $savingGoalsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        target_amount REAL NOT NULL,
        current_amount REAL NOT NULL DEFAULT 0,
        target_date TEXT,
        icon TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE $savingHistoriesTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        saving_goal_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        who TEXT NOT NULL,
        date TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $recurringTransactionsTable (
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

    await db.execute('''
      CREATE TABLE $financialPlansTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_period_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        target_amount REAL NOT NULL,
        target_date TEXT NOT NULL,
        category TEXT
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

    await db.execute('''
      CREATE TABLE $pocketsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_period_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        icon TEXT NOT NULL,
        allocation_type TEXT NOT NULL,
        allocation_value REAL NOT NULL,
        current_balance REAL NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE $notificationsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        subtitle TEXT NOT NULL,
        type TEXT NOT NULL,
        is_read INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
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
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_pockets_book_period_id ON $pocketsTable(book_period_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_saving_histories_goal_id ON $savingHistoriesTable(saving_goal_id)',
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
          if (plan.category != null) 'category': plan.category,
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

  Future<void> updateBookPeriodPlanBudget(int bookPeriodId, double planBudget) async {
    final db = await database;
    await db.update(
      bookPeriodsTable,
      {'plan_budget': planBudget},
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
        pocketsTable,
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

  Future<List<Pocket>> getAllPockets() async {
    final db = await database;
    final result = await db.query(pocketsTable, orderBy: 'id ASC');
    return result.map(Pocket.fromMap).toList();
  }

  Future<int> insertPocket(Pocket pocket) async {
    final db = await database;
    return db.insert(
      pocketsTable,
      pocket.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<void> updatePocket(Pocket pocket) async {
    final db = await database;
    await db.update(
      pocketsTable,
      pocket.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [pocket.id],
    );
  }

  Future<void> deletePocket(int id) async {
    final db = await database;
    await db.delete(pocketsTable, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getAllNotifications() async {
    final db = await database;
    return await db.query(notificationsTable, orderBy: 'created_at DESC');
  }

  Future<int> insertNotification(Map<String, dynamic> notification) async {
    final db = await database;
    return await db.insert(
      notificationsTable,
      notification,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> markNotificationAsRead(int id) async {
    final db = await database;
    await db.update(
      notificationsTable,
      {'is_read': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearNotifications() async {
    final db = await database;
    await db.delete(notificationsTable);
  }

  Future<void> deleteNotification(int id) async {
    final db = await database;
    await db.delete(notificationsTable, where: 'id = ?', whereArgs: [id]);
  }

  // --- SAVING GOALS CRUD ---
  Future<List<SavingGoal>> getAllSavingGoals() async {
    final db = await database;
    final result = await db.query(savingGoalsTable, orderBy: 'id ASC');
    return result.map(SavingGoal.fromMap).toList();
  }

  Future<int> insertSavingGoal(SavingGoal goal) async {
    final db = await database;
    return db.insert(
      savingGoalsTable,
      goal.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<void> updateSavingGoal(SavingGoal goal) async {
    final db = await database;
    await db.update(
      savingGoalsTable,
      goal.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [goal.id],
    );
  }

  Future<void> deleteSavingGoal(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(savingHistoriesTable, where: 'saving_goal_id = ?', whereArgs: [id]);
      await txn.delete(savingGoalsTable, where: 'id = ?', whereArgs: [id]);
    });
  }

  // --- SAVING HISTORIES CRUD ---
  Future<List<SavingHistory>> getSavingHistories(int savingGoalId) async {
    final db = await database;
    final result = await db.query(
      savingHistoriesTable,
      where: 'saving_goal_id = ?',
      whereArgs: [savingGoalId],
      orderBy: 'date DESC, id DESC',
    );
    return result.map(SavingHistory.fromMap).toList();
  }

  Future<int> insertSavingHistory(SavingHistory history) async {
    final db = await database;
    return db.insert(
      savingHistoriesTable,
      history.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  // --- RECURRING TRANSACTIONS CRUD ---
  Future<List<RecurringTransaction>> getAllRecurringTransactions() async {
    final db = await database;
    final result = await db.query(recurringTransactionsTable, orderBy: 'id ASC');
    return result.map(RecurringTransaction.fromMap).toList();
  }

  Future<int> insertRecurringTransaction(RecurringTransaction transaction) async {
    final db = await database;
    return db.insert(
      recurringTransactionsTable,
      transaction.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<void> updateRecurringTransaction(RecurringTransaction transaction) async {
    final db = await database;
    await db.update(
      recurringTransactionsTable,
      transaction.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<void> deleteRecurringTransaction(int id) async {
    final db = await database;
    await db.delete(recurringTransactionsTable, where: 'id = ?', whereArgs: [id]);
  }
}
