class ShoppingItem {
  final int? id;
  final int bookPeriodId;
  final String title;
  final double amount;
  final String category;
  final String date;
  final String? time;
  final double quantity;
  final String unit;
  final int isBought;
  final int? expenseTransactionId;

  ShoppingItem({
    this.id,
    required this.bookPeriodId,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    this.time,
    required this.quantity,
    required this.unit,
    this.isBought = 0,
    this.expenseTransactionId,
  });

  bool get bought => isBought == 1;

  double get total => amount * quantity;

  ShoppingItem copyWith({
    int? id,
    int? bookPeriodId,
    String? title,
    double? amount,
    String? category,
    String? date,
    String? time,
    double? quantity,
    String? unit,
    int? isBought,
    int? expenseTransactionId, bool clearExpenseTransactionId = false,
  }) {
    return ShoppingItem(
      id: id ?? this.id,
      bookPeriodId: bookPeriodId ?? this.bookPeriodId,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      date: date ?? this.date,
      time: time ?? this.time,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      isBought: isBought ?? this.isBought,
      expenseTransactionId: clearExpenseTransactionId ? null : (expenseTransactionId ?? this.expenseTransactionId),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'book_period_id': bookPeriodId,
      'title': title,
      'amount': amount,
      'category': category,
      'date': date,
      'time': time,
      'quantity': quantity,
      'unit': unit,
      'is_bought': isBought,
      'expense_transaction_id': expenseTransactionId,
    };
  }

  factory ShoppingItem.fromMap(Map<String, dynamic> map) {
    return ShoppingItem(
      id: map['id'] as int?,
      bookPeriodId: map['book_period_id'] as int,
      title: map['title'] as String,
      amount: (map['amount'] as num).toDouble(),
      category: map['category'] as String,
      date: map['date'] as String,
      time: map['time'] as String?,
      quantity: (map['quantity'] as num).toDouble(),
      unit: map['unit'] as String,
      isBought: map['is_bought'] as int? ?? 0,
      expenseTransactionId: (map['expense_transaction_id'] as num?)?.toInt(),
    );
  }
}
