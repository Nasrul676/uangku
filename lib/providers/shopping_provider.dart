import 'package:flutter/foundation.dart';
import '../models/shopping_item.dart';
import '../services/database_helper.dart';
import 'transaction_provider.dart';

class ShoppingProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final TransactionProvider _transactionProvider;

  List<ShoppingItem> _items = [];
  bool _isLoading = false;

  ShoppingProvider(this._transactionProvider);

  List<ShoppingItem> get items => _items;
  bool get isLoading => _isLoading;
  int get unboughtCount => _items.where((item) => item.isBought == 0).length;

  int? _lastLoadedBookId;

  Future<void> loadItems(int bookPeriodId, {bool force = false}) async {
    if (!force && _lastLoadedBookId == bookPeriodId && !_isLoading && _items.isNotEmpty) {
      return;
    }
    _lastLoadedBookId = bookPeriodId;
    _isLoading = true;
    notifyListeners();

    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.shoppingItemsTable,
      where: 'book_period_id = ?',
      whereArgs: [bookPeriodId],
      orderBy: 'date DESC, time DESC',
    );

    _items = maps.map((map) => ShoppingItem.fromMap(map)).toList();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addItem(ShoppingItem item) async {
    try {
      final db = await _dbHelper.database;
      await db.insert(DatabaseHelper.shoppingItemsTable, item.toMap());
      await loadItems(item.bookPeriodId, force: true);
    } catch (e) {
      debugPrint('Error adding shopping item: $e');
      rethrow;
    }
  }

  Future<void> updateItem(ShoppingItem item) async {
    if (item.id == null) {
      debugPrint('Warning: Attempted to update item with null ID');
      return;
    }
    final db = await _dbHelper.database;
    final rows = await db.update(
      DatabaseHelper.shoppingItemsTable,
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
    if (rows == 0) {
      throw Exception('Gagal memperbarui item: ID  tidak ditemukan.');
    }
    await loadItems(item.bookPeriodId, force: true);
  }

  Future<void> deleteItem(ShoppingItem item) async {
    if (item.id == null) {
      debugPrint('Warning: Attempted to delete item with null ID');
      return;
    }
    final db = await _dbHelper.database;
    await db.delete(
      DatabaseHelper.shoppingItemsTable,
      where: 'id = ?',
      whereArgs: [item.id],
    );
    await loadItems(item.bookPeriodId, force: true);
  }

  Future<void> markAsBought(ShoppingItem item, double totalAmount) async {
    try {
      final normalizedTotal = totalAmount < 0 ? 0.0 : totalAmount;
      final unitAmount = item.quantity == 0
          ? normalizedTotal
          : normalizedTotal / item.quantity;
      
      // Use current date for transaction to avoid 'before book start' errors
      // and accurately reflect when the purchase was made.
      final now = DateTime.now();
      final transactionId = await _transactionProvider.addTransactionForShopping(
        title: item.title,
        amount: normalizedTotal,
        type: 'EXPENSE',
        category: item.category,
        date: now,
        time: ':',
        bookId: item.bookPeriodId,
      );
      
      final updatedItem = item.copyWith(
        isBought: 1,
        amount: unitAmount,
        expenseTransactionId: transactionId,
      );
      await updateItem(updatedItem);
    } catch (e) {
      debugPrint('Error marking item as bought: ');
      rethrow;
    }
  }

  Future<void> cancelBought(ShoppingItem item) async {
    final transactionId = item.expenseTransactionId;
    if (transactionId != null) {
      await _transactionProvider.removeTransaction(transactionId);
    }

    final updatedItem = item.copyWith(
      isBought: 0,
      amount: 0,
      clearExpenseTransactionId: true,
    );
    await updateItem(updatedItem);
  }
}
