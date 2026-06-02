class SavingHistory {
  const SavingHistory({
    this.id,
    required this.savingGoalId,
    required this.amount,
    required this.who,
    required this.date,
  });

  final int? id;
  final int savingGoalId;
  final double amount;
  final String who;
  final String date;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'saving_goal_id': savingGoalId,
      'amount': amount,
      'who': who,
      'date': date,
    };
  }

  factory SavingHistory.fromMap(Map<String, dynamic> map) {
    return SavingHistory(
      id: map['id'] as int?,
      savingGoalId: map['saving_goal_id'] as int,
      amount: (map['amount'] as num).toDouble(),
      who: map['who'] as String,
      date: map['date'] as String,
    );
  }
}
