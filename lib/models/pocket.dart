class Pocket {
  final int? id;
  final int bookPeriodId;
  final String name;
  final String icon;
  final String allocationType; // 'PERCENTAGE' or 'NOMINAL'
  final double allocationValue;
  final double currentBalance;

  Pocket({
    this.id,
    required this.bookPeriodId,
    required this.name,
    required this.icon,
    required this.allocationType,
    required this.allocationValue,
    this.currentBalance = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'book_period_id': bookPeriodId,
      'name': name,
      'icon': icon,
      'allocation_type': allocationType,
      'allocation_value': allocationValue,
      'current_balance': currentBalance,
    };
  }

  factory Pocket.fromMap(Map<String, dynamic> map) {
    return Pocket(
      id: map['id'] as int?,
      bookPeriodId: map['book_period_id'] as int,
      name: map['name'] as String,
      icon: map['icon'] as String,
      allocationType: map['allocation_type'] as String,
      allocationValue: (map['allocation_value'] as num?)?.toDouble() ?? 0.0,
      currentBalance: (map['current_balance'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Pocket copyWith({
    int? id,
    int? bookPeriodId,
    String? name,
    String? icon,
    String? allocationType,
    double? allocationValue,
    double? currentBalance,
  }) {
    return Pocket(
      id: id ?? this.id,
      bookPeriodId: bookPeriodId ?? this.bookPeriodId,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      allocationType: allocationType ?? this.allocationType,
      allocationValue: allocationValue ?? this.allocationValue,
      currentBalance: currentBalance ?? this.currentBalance,
    );
  }
}
