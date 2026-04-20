class FinanceTransaction {
  const FinanceTransaction({
    this.id,
    this.bookPeriodId,
    this.financialPlanId,
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    required this.date,
    this.time,
    this.isSynced = 0,
  });

  final int? id;
  final int? bookPeriodId;
  final int? financialPlanId;
  final String title;
  final double amount;
  final String type;
  final String category;
  final String date;
  final String? time;
  final int isSynced;

  bool get synced => isSynced == 1;

  FinanceTransaction copyWith({
    int? id,
    int? bookPeriodId,
    int? financialPlanId,
    String? title,
    double? amount,
    String? type,
    String? category,
    String? date,
    String? time,
    int? isSynced,
  }) {
    return FinanceTransaction(
      id: id ?? this.id,
      bookPeriodId: bookPeriodId ?? this.bookPeriodId,
      financialPlanId: financialPlanId ?? this.financialPlanId,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      category: category ?? this.category,
      date: date ?? this.date,
      time: time ?? this.time,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'book_period_id': bookPeriodId,
      'financial_plan_id': financialPlanId,
      'title': title,
      'amount': amount,
      'type': type,
      'category': category,
      'date': date,
      'time': time,
      'is_synced': isSynced,
    };
  }

  factory FinanceTransaction.fromMap(Map<String, dynamic> map) {
    return FinanceTransaction(
      id: map['id'] as int?,
      bookPeriodId: (map['book_period_id'] as num?)?.toInt(),
      financialPlanId: (map['financial_plan_id'] as num?)?.toInt(),
      title: map['title'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      type: map['type'] as String? ?? 'EXPENSE',
      category: map['category'] as String? ?? 'Pengeluaran',
      date: map['date'] as String? ?? '',
      time: map['time'] as String?,
      isSynced: (map['is_synced'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJsonByMapping(Map<String, String> keyMapping) {
    return {
      keyMapping['id'] ?? 'id': id,
      keyMapping['book_period_id'] ?? 'book_period_id': bookPeriodId,
      keyMapping['financial_plan_id'] ?? 'financial_plan_id': financialPlanId,
      keyMapping['title'] ?? 'title': title,
      keyMapping['amount'] ?? 'amount': amount,
      keyMapping['type'] ?? 'type': type,
      keyMapping['category'] ?? 'category': category,
      keyMapping['date'] ?? 'date': date,
      keyMapping['time'] ?? 'time': time,
      keyMapping['is_synced'] ?? 'is_synced': isSynced,
    };
  }
}
