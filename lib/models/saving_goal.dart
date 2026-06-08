class SavingGoal {
  const SavingGoal({
    this.id,
    required this.title,
    required this.targetAmount,
    required this.currentAmount,
    this.targetDate,
    this.icon,
    this.orderIndex = 0,
    this.type = 'money',
  });

  final int? id;
  final String title;
  final double targetAmount;
  final double currentAmount;
  final String? targetDate;
  final String? icon;
  final int orderIndex;
  final String type;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'target_amount': targetAmount,
      'current_amount': currentAmount,
      if (targetDate != null) 'target_date': targetDate,
      if (icon != null) 'icon': icon,
      'order_index': orderIndex,
      'type': type,
    };
  }

  factory SavingGoal.fromMap(Map<String, dynamic> map) {
    return SavingGoal(
      id: map['id'] as int?,
      title: map['title'] as String,
      targetAmount: (map['target_amount'] as num).toDouble(),
      currentAmount: (map['current_amount'] as num).toDouble(),
      targetDate: map['target_date'] as String?,
      icon: map['icon'] as String?,
      orderIndex: map['order_index'] as int? ?? 0,
      type: map['type'] as String? ?? 'money',
    );
  }

  SavingGoal copyWith({
    int? id,
    String? title,
    double? targetAmount,
    double? currentAmount,
    String? targetDate,
    String? icon,
    int? orderIndex,
    String? type,
  }) {
    return SavingGoal(
      id: id ?? this.id,
      title: title ?? this.title,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      targetDate: targetDate ?? this.targetDate,
      icon: icon ?? this.icon,
      orderIndex: orderIndex ?? this.orderIndex,
      type: type ?? this.type,
    );
  }
}
