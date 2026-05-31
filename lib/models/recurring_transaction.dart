class RecurringTransaction {
  const RecurringTransaction({
    this.id,
    required this.type,
    required this.amount,
    required this.title,
    required this.category,
    required this.frequency,
    required this.nextDate,
    this.isActive = true,
    this.pocketId,
    this.financialPlanId,
  });

  final int? id;
  final String type; // 'INCOME' or 'EXPENSE'
  final double amount;
  final String title;
  final String category;
  final String frequency; // 'DAILY', 'WEEKLY', 'MONTHLY', 'YEARLY'
  final String nextDate;
  final bool isActive;
  final int? pocketId;
  final int? financialPlanId;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'amount': amount,
      'title': title,
      'category': category,
      'frequency': frequency,
      'next_date': nextDate,
      'is_active': isActive ? 1 : 0,
      'pocket_id': pocketId,
      'financial_plan_id': financialPlanId,
    };
  }

  factory RecurringTransaction.fromMap(Map<String, dynamic> map) {
    return RecurringTransaction(
      id: map['id'] as int?,
      type: map['type'] as String,
      amount: (map['amount'] as num).toDouble(),
      title: map['title'] as String,
      category: map['category'] as String,
      frequency: map['frequency'] as String,
      nextDate: map['next_date'] as String,
      isActive: (map['is_active'] as int) == 1,
      pocketId: map['pocket_id'] as int?,
      financialPlanId: map['financial_plan_id'] as int?,
    );
  }

  RecurringTransaction copyWith({
    int? id,
    String? type,
    double? amount,
    String? title,
    String? category,
    String? frequency,
    String? nextDate,
    bool? isActive,
    int? pocketId,
    int? financialPlanId,
  }) {
    return RecurringTransaction(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      title: title ?? this.title,
      category: category ?? this.category,
      frequency: frequency ?? this.frequency,
      nextDate: nextDate ?? this.nextDate,
      isActive: isActive ?? this.isActive,
      pocketId: pocketId ?? this.pocketId,
      financialPlanId: financialPlanId ?? this.financialPlanId,
    );
  }
}
