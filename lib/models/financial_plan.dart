class FinancialPlan {
  const FinancialPlan({
    this.id,
    required this.bookPeriodId,
    required this.title,
    required this.targetAmount,
    required this.targetDate,
    this.category,
  });

  final int? id;
  final int bookPeriodId;
  final String title;
  final double targetAmount;
  final String targetDate;
  final String? category;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'book_period_id': bookPeriodId,
      'title': title,
      'target_amount': targetAmount,
      'target_date': targetDate,
      if (category != null) 'category': category,
    };
  }

  factory FinancialPlan.fromMap(Map<String, dynamic> map) {
    return FinancialPlan(
      id: (map['id'] as num?)?.toInt(),
      bookPeriodId: (map['book_period_id'] as num?)?.toInt() ?? 0,
      title: map['title'] as String? ?? '',
      targetAmount: (map['target_amount'] as num?)?.toDouble() ?? 0,
      targetDate: map['target_date'] as String? ?? '',
      category: map['category'] as String?,
    );
  }
}
