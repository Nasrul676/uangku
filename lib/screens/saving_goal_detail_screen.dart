import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:confetti/confetti.dart';

import '../models/saving_goal.dart';
import '../models/saving_history.dart';
import '../models/saving_expense.dart';
import '../providers/transaction_provider.dart';
import '../utils/calculator_parser.dart';
import '../widgets/success_overlay.dart';
import 'saving_goal_input_screen.dart';

class _CombinedHistory {
  final bool isExpense;
  final double amount;
  final String title;
  final DateTime dateTime;
  
  _CombinedHistory({
    required this.isExpense,
    required this.amount,
    required this.title,
    required this.dateTime,
  });
}

class SavingGoalDetailScreen extends StatefulWidget {
  const SavingGoalDetailScreen({super.key, required this.goal});

  final SavingGoal goal;

  @override
  State<SavingGoalDetailScreen> createState() => _SavingGoalDetailScreenState();
}

class _SavingGoalDetailScreenState extends State<SavingGoalDetailScreen> {
  late ConfettiController _confettiController;
  List<_CombinedHistory> _histories = [];
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHistories();
    });
  }

  Future<void> _loadHistories() async {
    if (widget.goal.id == null) return;
    final provider = context.read<TransactionProvider>();
    final h = await provider.getSavingHistories(widget.goal.id!);
    final e = await provider.getSavingExpenses(widget.goal.id!);
    
    List<_CombinedHistory> combined = [];
    for (var item in h) {
      combined.add(_CombinedHistory(
        isExpense: false,
        amount: item.amount,
        title: item.who,
        dateTime: DateTime.parse(item.date),
      ));
    }
    for (var item in e) {
      DateTime dt;
      try {
        dt = DateTime.parse('${item.date} ${item.time}:00');
      } catch (_) {
        dt = DateTime.parse(item.date);
      }
      combined.add(_CombinedHistory(
        isExpense: true,
        amount: item.amount,
        title: item.purpose,
        dateTime: dt,
      ));
    }
    combined.sort((a, b) => b.dateTime.compareTo(a.dateTime));

    if (mounted) {
      setState(() {
        _histories = combined;
        _isLoadingHistory = false;
      });
    }
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
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: progress >= 1.0 
                        ? null 
                        : () => _showTopUpDialog(context, currentGoal, provider),
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    label: const Text('Isi Tabungan'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: currentGoal.currentAmount <= 0
                        ? null
                        : () => _showWithdrawDialog(context, currentGoal, provider),
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                    label: const Text('Ambil Tabungan'),
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
            const SizedBox(height: 32),
            if (_isLoadingHistory)
              const Center(child: CircularProgressIndicator())
            else if (_histories.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Riwayat Penambahan',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _histories.length,
                itemBuilder: (context, index) {
                  final h = _histories[index];
                  final dateStr = DateFormat('dd MMM yyyy HH:mm').format(h.dateTime);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Icon(
                        h.isExpense ? Icons.arrow_upward : Icons.arrow_downward, 
                        color: h.isExpense ? Colors.red : Colors.green,
                      ),
                    ),
                    title: Text(h.title),
                    subtitle: Text(dateStr),
                    trailing: Text(
                      '${h.isExpense ? '-' : '+'} ${currencyFormatter.format(h.amount)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: h.isExpense ? Colors.red : Colors.green,
                      ),
                    ),
                  );
                },
              ),
            ],
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
    final whoController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Tambah Tabungan'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType: TextInputType.visiblePassword,
                decoration: const InputDecoration(
                  hintText: 'Masukkan nominal (+ - k m)',
                  prefixText: 'Rp ',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: whoController,
                decoration: const InputDecoration(
                  hintText: 'Siapa yang menabung?',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () async {
                final amount = CalculatorParser.evaluate(amountController.text);
                final who = whoController.text.trim();
                if (amount > 0 && who.isNotEmpty) {
                  final newGoal = goal.copyWith(
                    currentAmount: goal.currentAmount + amount,
                  );
                  await provider.updateSavingGoal(newGoal);

                  final history = SavingHistory(
                    savingGoalId: goal.id!,
                    amount: amount,
                    who: who,
                    date: DateTime.now().toIso8601String(),
                  );
                  await provider.addSavingHistory(history);
                  _loadHistories();

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

  void _showWithdrawDialog(BuildContext context, SavingGoal goal, TransactionProvider provider) {
    final amountController = TextEditingController();
    final purposeController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Ambil Tabungan'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.visiblePassword,
                      decoration: const InputDecoration(
                        hintText: 'Masukkan nominal (+ - k m)',
                        prefixText: 'Rp ',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: purposeController,
                      decoration: const InputDecoration(
                        hintText: 'Tujuan pengambilan?',
                        prefixIcon: Icon(Icons.outbox_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today_rounded),
                      title: Text(DateFormat('dd MMM yyyy').format(selectedDate)),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (date != null) {
                          setState(() => selectedDate = date);
                        }
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.access_time_rounded),
                      title: Text(selectedTime.format(context)),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                        );
                        if (time != null) {
                          setState(() => selectedTime = time);
                        }
                      },
                    ),
                  ],
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
                    final purpose = purposeController.text.trim();
                    if (amount > 0 && purpose.isNotEmpty) {
                      if (amount > goal.currentAmount) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Nominal melebihi saldo tabungan!')),
                        );
                        return;
                      }
                      
                      final newGoal = goal.copyWith(
                        currentAmount: goal.currentAmount - amount,
                      );
                      await provider.updateSavingGoal(newGoal);

                      final expense = SavingExpense(
                        savingGoalId: goal.id!,
                        amount: amount,
                        purpose: purpose,
                        date: DateFormat('yyyy-MM-dd').format(selectedDate),
                        time: '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                      );
                      await provider.addSavingExpense(expense);
                      _loadHistories();

                      if (context.mounted) {
                        Navigator.pop(context);
                        SuccessOverlay.show(
                          context,
                          message: 'Tabungan diambil!',
                          color: Colors.red,
                        );
                      }
                    }
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          }
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
