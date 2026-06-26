import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:confetti/confetti.dart';

import '../widgets/custom_bottom_sheet.dart';

import '../models/saving_goal.dart';
import '../models/saving_history.dart';
import '../models/saving_expense.dart';
import '../providers/transaction_provider.dart';
import '../utils/calculator_parser.dart';
import '../widgets/success_overlay.dart';
import '../widgets/ai_chat_bubble.dart';
import '../widgets/calculator_bubble.dart';
import 'saving_goal_input_screen.dart';

class _CombinedHistory {
  final bool isExpense;
  final double amount;
  final String title;
  final DateTime dateTime;
  final dynamic originalItem;

  _CombinedHistory({
    required this.isExpense,
    required this.amount,
    required this.title,
    required this.dateTime,
    required this.originalItem,
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
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
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
      combined.add(
        _CombinedHistory(
          isExpense: false,
          amount: item.amount,
          title: item.who,
          dateTime: DateTime.parse(item.date),
          originalItem: item,
        ),
      );
    }
    for (var item in e) {
      DateTime dt;
      try {
        dt = DateTime.parse('${item.date} ${item.time}:00');
      } catch (_) {
        dt = DateTime.parse(item.date);
      }
      combined.add(
        _CombinedHistory(
          isExpense: true,
          amount: item.amount,
          title: item.purpose,
          dateTime: dt,
          originalItem: item,
        ),
      );
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
    final isDark = theme.brightness == Brightness.dark;
    final greenBg = isDark ? const Color(0xFF2E7D32) : const Color(0xFF388E3C);
    final redBg = isDark ? const Color(0xFFC62828) : const Color(0xFFD32F2F);

    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final goldFormatter = NumberFormat('#,##0.####', 'id_ID');

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
                  builder: (context) =>
                      SavingGoalInputScreen(existingGoal: currentGoal),
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
                  Builder(
                    builder: (context) {
                      final targetDateTime = DateTime.parse(
                        currentGoal.targetDate!,
                      );
                      final now = DateTime.now();
                      final today = DateTime(now.year, now.month, now.day);
                      final targetDay = DateTime(
                        targetDateTime.year,
                        targetDateTime.month,
                        targetDateTime.day,
                      );
                      final difference = targetDay.difference(today).inDays;

                      String countdownText = '';
                      Color? countdownColor = theme.colorScheme.primary;
                      if (difference > 0) {
                        countdownText = ' ($difference hari lagi)';
                      } else if (difference == 0) {
                        countdownText = ' (Batas waktu hari ini)';
                        countdownColor = Colors.orange;
                      } else {
                        countdownText = ' (Terlewat ${difference.abs()} hari)';
                        countdownColor = Colors.red;
                      }

                      final remaining =
                          (currentGoal.targetAmount -
                          currentGoal.currentAmount);
                      final remainingPositive = remaining > 0 ? remaining : 0.0;
                      final remainingStr = currentGoal.type == 'gold'
                          ? '${goldFormatter.format(remainingPositive)} gram'
                          : currencyFormatter.format(remainingPositive);

                      return Column(
                        children: [
                          Text.rich(
                            TextSpan(
                              text:
                                  'Target: ${DateFormat('dd MMM yyyy', 'id').format(targetDateTime)}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                              children: [
                                TextSpan(
                                  text: countdownText,
                                  style: TextStyle(
                                    color: countdownColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (remainingPositive > 0) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Kurang $remainingStr lagi',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.secondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      );
                    },
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
                                  currentGoal.type == 'gold'
                                      ? '${goldFormatter.format(currentGoal.currentAmount)} gram'
                                      : currencyFormatter.format(
                                          currentGoal.currentAmount,
                                        ),
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
                                  currentGoal.type == 'gold'
                                      ? '${goldFormatter.format(currentGoal.targetAmount)} gram'
                                      : currencyFormatter.format(
                                          currentGoal.targetAmount,
                                        ),
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
                            color: progress >= 1.0
                                ? Colors.green
                                : theme.colorScheme.primary,
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
                            : () => _showTopUpDialog(
                                context,
                                currentGoal,
                                provider,
                              ),
                        icon: const Icon(Icons.add_circle_outline_rounded),
                        label: const Text('Isi Tabungan'),
                        style: FilledButton.styleFrom(
                          backgroundColor: greenBg,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: greenBg.withOpacity(0.3),
                          disabledForegroundColor: Colors.white.withOpacity(
                            0.5,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: currentGoal.currentAmount <= 0
                            ? null
                            : () => _showWithdrawDialog(
                                context,
                                currentGoal,
                                provider,
                              ),
                        icon: const Icon(Icons.remove_circle_outline_rounded),
                        label: const Text('Ambil Tabungan'),
                        style: FilledButton.styleFrom(
                          backgroundColor: redBg,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: redBg.withOpacity(0.3),
                          disabledForegroundColor: Colors.white.withOpacity(
                            0.5,
                          ),
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
                      'Riwayat Transaksi',
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
                      final dateStr = DateFormat(
                        'dd MMM yyyy HH:mm',
                      ).format(h.dateTime);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        onTap: () {
                          _showEditDeleteHistoryOptions(
                            context,
                            h,
                            currentGoal,
                            provider,
                          );
                        },
                        leading: CircleAvatar(
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Icon(
                            h.isExpense
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            color: h.isExpense ? Colors.red : Colors.green,
                          ),
                        ),
                        title: Text(h.title),
                        subtitle: Text(dateStr),
                        trailing: Text(
                          '${h.isExpense ? '-' : '+'} ${currentGoal.type == 'gold' ? '${goldFormatter.format(h.amount)} gram' : currencyFormatter.format(h.amount)}',
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
          const AiChatBubble(currentContext: 'Saving Goal Detail Screen'),
          const CalculatorBubble(),
        ],
      ),
    );
  }

  void _showTopUpDialog(
    BuildContext context,
    SavingGoal goal,
    TransactionProvider provider, {
    SavingHistory? existingHistory,
  }) {
    final amountController = TextEditingController(
      text: existingHistory != null
          ? (goal.type == 'gold'
                ? existingHistory.amount.toString()
                : existingHistory.amount.toInt().toString())
          : '',
    );
    final whoController = TextEditingController(
      text: existingHistory?.who ?? '',
    );
    DateTime selectedDate = existingHistory != null
        ? DateTime.parse(existingHistory.date)
        : DateTime.now();
    TimeOfDay selectedTime = existingHistory != null
        ? TimeOfDay.fromDateTime(DateTime.parse(existingHistory.date))
        : TimeOfDay.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    existingHistory != null
                        ? 'Edit Isi Tabungan'
                        : 'Isi Tabungan',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: amountController,
                    keyboardType: goal.type == 'gold'
                        ? const TextInputType.numberWithOptions(decimal: true)
                        : TextInputType.visiblePassword,
                    decoration: InputDecoration(
                      labelText: 'Nominal',
                      hintText: goal.type == 'gold'
                          ? 'Masukkan gram (misal: 0.5)'
                          : 'Masukkan nominal (+ - k m)',
                      prefixText: goal.type == 'gold' ? null : 'Rp ',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: whoController,
                    decoration: const InputDecoration(
                      labelText: 'Siapa yang menabung?',
                      hintText: 'Siapa yang menabung?',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
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
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Tanggal',
                              prefixIcon: Icon(Icons.calendar_today_rounded),
                            ),
                            child: Text(
                              DateFormat('dd MMM yyyy').format(selectedDate),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: selectedTime,
                            );
                            if (time != null) {
                              setState(() => selectedTime = time);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Waktu',
                              prefixIcon: Icon(Icons.access_time_rounded),
                            ),
                            child: Text(selectedTime.format(context)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: () async {
                      final amount = goal.type == 'gold'
                          ? (double.tryParse(
                                  amountController.text.replaceAll(',', '.'),
                                ) ??
                                0.0)
                          : CalculatorParser.evaluate(amountController.text);
                      final who = whoController.text.trim();
                      if (amount > 0 && who.isNotEmpty) {
                        final double amountDifference = existingHistory != null
                            ? amount - existingHistory.amount
                            : amount;

                        final newGoal = goal.copyWith(
                          currentAmount: goal.currentAmount + amountDifference,
                        );
                        await provider.updateSavingGoal(newGoal);

                        final combinedDate = DateTime(
                          selectedDate.year,
                          selectedDate.month,
                          selectedDate.day,
                          selectedTime.hour,
                          selectedTime.minute,
                        );

                        if (existingHistory != null) {
                          final history = SavingHistory(
                            id: existingHistory.id,
                            savingGoalId: goal.id!,
                            amount: amount,
                            who: who,
                            date: combinedDate.toIso8601String(),
                          );
                          await provider.updateSavingHistory(history);
                        } else {
                          final history = SavingHistory(
                            savingGoalId: goal.id!,
                            amount: amount,
                            who: who,
                            date: combinedDate.toIso8601String(),
                          );
                          await provider.addSavingHistory(history);
                        }
                        _loadHistories();

                        if (context.mounted) {
                          Navigator.pop(context);

                          final newProgress = newGoal.targetAmount > 0
                              ? (newGoal.currentAmount / newGoal.targetAmount)
                                    .clamp(0.0, 1.0)
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
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Simpan'),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showWithdrawDialog(
    BuildContext context,
    SavingGoal goal,
    TransactionProvider provider, {
    SavingExpense? existingExpense,
  }) {
    final amountController = TextEditingController(
      text: existingExpense != null
          ? (goal.type == 'gold'
                ? existingExpense.amount.toString()
                : existingExpense.amount.toInt().toString())
          : '',
    );
    final purposeController = TextEditingController(
      text: existingExpense?.purpose ?? '',
    );
    DateTime selectedDate = existingExpense != null
        ? DateTime.parse(existingExpense.date)
        : DateTime.now();
    TimeOfDay selectedTime = existingExpense != null
        ? TimeOfDay(
            hour: int.parse(existingExpense.time.split(':')[0]),
            minute: int.parse(existingExpense.time.split(':')[1]),
          )
        : TimeOfDay.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    existingExpense != null
                        ? 'Edit Ambil Tabungan'
                        : 'Ambil Tabungan',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: amountController,
                    keyboardType: goal.type == 'gold'
                        ? const TextInputType.numberWithOptions(decimal: true)
                        : TextInputType.visiblePassword,
                    decoration: InputDecoration(
                      labelText: 'Nominal',
                      hintText: goal.type == 'gold'
                          ? 'Masukkan gram (misal: 0.5)'
                          : 'Masukkan nominal (+ - k m)',
                      prefixText: goal.type == 'gold' ? null : 'Rp ',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: purposeController,
                    decoration: const InputDecoration(
                      labelText: 'Tujuan Pengambilan',
                      hintText: 'Tujuan pengambilan?',
                      prefixIcon: Icon(Icons.outbox_rounded),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
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
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Tanggal',
                              prefixIcon: Icon(Icons.calendar_today_rounded),
                            ),
                            child: Text(
                              DateFormat('dd MMM yyyy').format(selectedDate),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: selectedTime,
                            );
                            if (time != null) {
                              setState(() => selectedTime = time);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Waktu',
                              prefixIcon: Icon(Icons.access_time_rounded),
                            ),
                            child: Text(selectedTime.format(context)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: () async {
                      final amount = goal.type == 'gold'
                          ? (double.tryParse(
                                  amountController.text.replaceAll(',', '.'),
                                ) ??
                                0.0)
                          : CalculatorParser.evaluate(amountController.text);
                      final purpose = purposeController.text.trim();
                      if (amount > 0 && purpose.isNotEmpty) {
                        final availableAmount =
                            goal.currentAmount +
                            (existingExpense != null
                                ? existingExpense.amount
                                : 0);
                        if (amount > availableAmount) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Nominal melebihi saldo tabungan!'),
                            ),
                          );
                          return;
                        }

                        final newGoal = goal.copyWith(
                          currentAmount: availableAmount - amount,
                        );
                        await provider.updateSavingGoal(newGoal);

                        if (existingExpense != null) {
                          final expense = SavingExpense(
                            id: existingExpense.id,
                            savingGoalId: goal.id!,
                            amount: amount,
                            purpose: purpose,
                            date: DateFormat('yyyy-MM-dd').format(selectedDate),
                            time:
                                '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                          );
                          await provider.updateSavingExpense(expense);
                        } else {
                          final expense = SavingExpense(
                            savingGoalId: goal.id!,
                            amount: amount,
                            purpose: purpose,
                            date: DateFormat('yyyy-MM-dd').format(selectedDate),
                            time:
                                '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                          );
                          await provider.addSavingExpense(expense);
                        }
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
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Ambil Tabungan'),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDelete(
    BuildContext context,
    SavingGoal goal,
    TransactionProvider provider,
  ) {
    showCustomBottomSheet(
      context: context,
      title: 'Hapus Tabungan?',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Tabungan yang dihapus tidak bisa dikembalikan.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
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
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditDeleteHistoryOptions(
    BuildContext context,
    _CombinedHistory h,
    SavingGoal goal,
    TransactionProvider provider,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Opsi Riwayat',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.edit_rounded, color: Colors.blue),
                title: const Text('Edit Riwayat'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  if (h.isExpense) {
                    _showWithdrawDialog(
                      context,
                      goal,
                      provider,
                      existingExpense: h.originalItem as SavingExpense,
                    );
                  } else {
                    _showTopUpDialog(
                      context,
                      goal,
                      provider,
                      existingHistory: h.originalItem as SavingHistory,
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_rounded, color: Colors.red),
                title: const Text(
                  'Hapus Riwayat',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  bool confirm =
                      await showDialog(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('Hapus Riwayat?'),
                          content: const Text(
                            'Riwayat ini akan dihapus dan saldo tabungan akan disesuaikan kembali.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, false),
                              child: const Text('Batal'),
                            ),
                            FilledButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, true),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              child: const Text('Hapus'),
                            ),
                          ],
                        ),
                      ) ??
                      false;

                  if (confirm && context.mounted) {
                    if (h.isExpense) {
                      final expense = h.originalItem as SavingExpense;
                      final newGoal = goal.copyWith(
                        currentAmount: goal.currentAmount + expense.amount,
                      );
                      await provider.updateSavingGoal(newGoal);
                      await provider.deleteSavingExpense(expense.id!);
                    } else {
                      final history = h.originalItem as SavingHistory;
                      final newGoal = goal.copyWith(
                        currentAmount: goal.currentAmount - history.amount,
                      );
                      await provider.updateSavingGoal(newGoal);
                      await provider.deleteSavingHistory(history.id!);
                    }
                    _loadHistories();

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Riwayat berhasil dihapus.'),
                        ),
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
