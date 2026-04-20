class FinancialPlanInput {
  const FinancialPlanInput({
    required this.title,
    required this.targetAmount,
    required this.targetDate,
  });

  final String title;
  final double targetAmount;
  final DateTime targetDate;
}
