class BookPeriod {
  const BookPeriod({
    this.id,
    required this.label,
    required this.startDate,
    this.endDate,
    this.isClosed = 0,
    this.planBudget = 0.0,
  });

  final int? id;
  final String label;
  final String startDate;
  final String? endDate;
  final int isClosed;
  final double planBudget;

  bool get closed => isClosed == 1;
  bool get isOpen => !closed;

  BookPeriod copyWith({
    int? id,
    String? label,
    String? startDate,
    String? endDate,
    int? isClosed,
    double? planBudget,
  }) {
    return BookPeriod(
      id: id ?? this.id,
      label: label ?? this.label,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isClosed: isClosed ?? this.isClosed,
      planBudget: planBudget ?? this.planBudget,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'start_date': startDate,
      'end_date': endDate,
      'is_closed': isClosed,
      'plan_budget': planBudget,
    };
  }

  factory BookPeriod.fromMap(Map<String, dynamic> map) {
    return BookPeriod(
      id: map['id'] as int?,
      label: map['label'] as String? ?? '',
      startDate: map['start_date'] as String? ?? '',
      endDate: map['end_date'] as String?,
      isClosed: (map['is_closed'] as num?)?.toInt() ?? 0,
      planBudget: (map['plan_budget'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
