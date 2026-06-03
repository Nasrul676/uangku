class SavingExpense {
  const SavingExpense({
    this.id,
    required this.savingGoalId,
    required this.amount,
    required this.purpose,
    required this.date,
    required this.time,
  });

  final int? id;
  final int savingGoalId;
  final double amount;
  final String purpose;
  final String date;
  final String time;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'saving_goal_id': savingGoalId,
      'amount': amount,
      'purpose': purpose,
      'date': date,
      'time': time,
    };
  }

  factory SavingExpense.fromMap(Map<String, dynamic> map) {
    return SavingExpense(
      id: map['id'] as int?,
      savingGoalId: map['saving_goal_id'] as int,
      amount: (map['amount'] as num).toDouble(),
      purpose: map['purpose'] as String,
      date: map['date'] as String,
      time: map['time'] as String,
    );
  }
}
