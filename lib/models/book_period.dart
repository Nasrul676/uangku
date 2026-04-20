class BookPeriod {
  const BookPeriod({
    this.id,
    required this.label,
    required this.startDate,
    this.endDate,
    this.isClosed = 0,
  });

  final int? id;
  final String label;
  final String startDate;
  final String? endDate;
  final int isClosed;

  bool get closed => isClosed == 1;
  bool get isOpen => !closed;

  BookPeriod copyWith({
    int? id,
    String? label,
    String? startDate,
    String? endDate,
    int? isClosed,
  }) {
    return BookPeriod(
      id: id ?? this.id,
      label: label ?? this.label,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isClosed: isClosed ?? this.isClosed,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'start_date': startDate,
      'end_date': endDate,
      'is_closed': isClosed,
    };
  }

  factory BookPeriod.fromMap(Map<String, dynamic> map) {
    return BookPeriod(
      id: map['id'] as int?,
      label: map['label'] as String? ?? '',
      startDate: map['start_date'] as String? ?? '',
      endDate: map['end_date'] as String?,
      isClosed: (map['is_closed'] as num?)?.toInt() ?? 0,
    );
  }
}
