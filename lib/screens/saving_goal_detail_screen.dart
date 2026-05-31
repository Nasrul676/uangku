import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:confetti/confetti.dart';

import '../models/saving_goal.dart';
import '../providers/transaction_provider.dart';
import '../utils/calculator_parser.dart';
import '../widgets/success_overlay.dart';
import 'saving_goal_input_screen.dart';

class SavingGoalDetailScreen extends StatefulWidget {
  const SavingGoalDetailScreen({super.key, required this.goal});

  final SavingGoal goal;

  @override
  State<SavingGoalDetailScreen> createState() => _SavingGoalDetailScreenState();
}

class _SavingGoalDetailScreenState extends State<SavingGoalDetailScreen> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Re-fetch the goal from provider to keep it updated
    final provider = context.watch<TransactionProvider>();
    final currentGoal = provider.savingGoals.firstWhere(
      (g) => g.id == widget.goal.id,
      orElse: () => widget.goal,
    );

    final theme = Theme.of(context);
    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    
    final progress = currentGoal.targetAmount > 0
        ? (currentGoal.currentAmount / currentGoal.targetAmount).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Detail Tabungan'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SavingGoalInputScreen(existingGoal: currentGoal),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_rounded),
            onPressed: () => _confirmDelete(context, currentGoal, provider),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Text(
                currentGoal.icon ?? '🎯',
                style: const TextStyle(fontSize: 48),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              currentGoal.title,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            if (currentGoal.targetDate != null) ...[
              const SizedBox(height: 8),
              Text(
                'Target: ${DateFormat('dd MMM yyyy', 'id').format(DateTime.parse(currentGoal.targetDate!))}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
            const SizedBox(height: 32),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Terkumpul',
                              style: theme.textTheme.labelMedium,
                            ),
                            Text(
                              currencyFormatter.format(currentGoal.currentAmount),
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Target',
                              style: theme.textTheme.labelMedium,
                            ),
                            Text(
                              currencyFormatter.format(currentGoal.targetAmount),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 16,
                        backgroundColor: theme.colorScheme.surfaceVariant,
                        color: progress >= 1.0 ? Colors.green : theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${(progress * 100).toStringAsFixed(1)}% Tercapai',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: progress >= 1.0 ? Colors.green : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: progress >= 1.0 
                    ? null 
                    : () => _showTopUpDialog(context, currentGoal, provider),
                icon: const Icon(Icons.add_circle_outline_rounded),
                label: const Text('Tambah Tabungan'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      Align(
        alignment: Alignment.topCenter,
        child: ConfettiWidget(
          confettiController: _confettiController,
          blastDirection: 3.14 / 2, // Straight down
          emissionFrequency: 0.05,
          numberOfParticles: 20,
          gravity: 0.1,
        ),
      ),
    ],
  ),
);
  }

  void _showTopUpDialog(BuildContext context, SavingGoal goal, TransactionProvider provider) {
    final amountController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Tambah Tabungan'),
          content: TextField(
            controller: amountController,
            keyboardType: TextInputType.visiblePassword,
            decoration: const InputDecoration(
              hintText: 'Masukkan nominal (+ - k m)',
              prefixText: 'Rp ',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () async {
                final amount = CalculatorParser.evaluate(amountController.text);
                if (amount > 0) {
                  final newGoal = goal.copyWith(
                    currentAmount: goal.currentAmount + amount,
                  );
                  await provider.updateSavingGoal(newGoal);
                  if (context.mounted) {
                    Navigator.pop(context);
                    
                    final newProgress = newGoal.targetAmount > 0 
                        ? (newGoal.currentAmount / newGoal.targetAmount).clamp(0.0, 1.0)
                        : 0.0;
                    
                    if (newProgress >= 0.90) {
                      _confettiController.play();
                      SuccessOverlay.show(
                        context,
                        message: 'Yeay! Tabungan Impianmu tercapai! 🎉',
                        color: Colors.green,
                        lottieAsset: 'assets/lottie/tercapai.json',
                      );
                    } else {
                      SuccessOverlay.show(
                        context,
                        message: 'Tabungan bertambah!',
                        color: Theme.of(context).colorScheme.primary,
                      );
                    }
                  }
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, SavingGoal goal, TransactionProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Tabungan?'),
        content: const Text('Tabungan yang dihapus tidak bisa dikembalikan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              if (goal.id != null) {
                await provider.deleteSavingGoal(goal.id!);
              }
              if (context.mounted) {
                Navigator.pop(context);
                Navigator.pop(context);
              }
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}
