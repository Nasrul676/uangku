import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/saving_goal.dart';
import '../widgets/shake_widget.dart';
import '../providers/transaction_provider.dart';
import '../widgets/animated_bouncing_card.dart';
import 'saving_goal_input_screen.dart';
import 'saving_goal_detail_screen.dart';

class SavingGoalsScreen extends StatefulWidget {
  const SavingGoalsScreen({super.key});

  @override
  State<SavingGoalsScreen> createState() => _SavingGoalsScreenState();
}

class _SavingGoalsScreenState extends State<SavingGoalsScreen> {
  final _currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  
  final _goldFormatter = NumberFormat('#,##0.####', 'id_ID');

  bool _isReorderMode = false;
  Timer? _longPressTimer;

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<TransactionProvider>();
    final goals = provider.savingGoals;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          if (goals.isNotEmpty) ...[
            Builder(
              builder: (context) {
                double totalDanaTerkumpul = 0;
                double totalDanaTarget = 0;
                double totalEmasTerkumpul = 0;
                double totalEmasTarget = 0;

                for (var goal in goals) {
                  if (goal.type == 'gold') {
                    totalEmasTerkumpul += goal.currentAmount;
                    totalEmasTarget += goal.targetAmount;
                  } else {
                    totalDanaTerkumpul += goal.currentAmount;
                    totalDanaTarget += goal.targetAmount;
                  }
                }

                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          context,
                          title: 'Total Dana',
                          terkumpul: _currencyFormatter.format(totalDanaTerkumpul),
                          target: _currencyFormatter.format(totalDanaTarget),
                          icon: Icons.account_balance_wallet_rounded,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSummaryCard(
                          context,
                          title: 'Total Emas',
                          terkumpul: '${_goldFormatter.format(totalEmasTerkumpul)} g',
                          target: '${_goldFormatter.format(totalEmasTarget)} g',
                          icon: Icons.diamond_rounded,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                );
              }
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(5, 12, 5, 12),
            child: SizedBox(
              width: double.infinity,
              child: _isReorderMode
                  ? OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _isReorderMode = false;
                        });
                      },
                      icon: const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF2A9D50),
                      ),
                      label: const Text(
                        'Selesai Mengatur',
                        style: TextStyle(color: Color(0xFF2A9D50)),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Color(0xFF2A9D50)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    )
                  : OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SavingGoalInputScreen(),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.add_box_rounded,
                        color: Color(0xFF2A9D50),
                      ),
                      label: const Text(
                        'Tambah Tabungan',
                        style: TextStyle(color: Color(0xFF2A9D50)),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Color(0xFF2A9D50)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
            ),
          ),
          if (goals.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Lottie.asset(
                      'assets/lottie/empty.json',
                      width: 200,
                      height: 200,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Belum ada tabungan',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Mulai tabung untuk mewujudkan impianmu!',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.fromLTRB(5, 16, 5, 140),
                itemCount: goals.length,
                onReorder: (oldIndex, newIndex) {
                  provider.reorderSavingGoals(oldIndex, newIndex);
                },
                buildDefaultDragHandles: false,
                itemBuilder: (context, index) {
                  final goal = goals[index];
                  final progress = goal.targetAmount > 0
                      ? (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0)
                      : 0.0;

                  Widget cardContent = AnimatedBouncingCard(
                    onTap: _isReorderMode
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    SavingGoalDetailScreen(goal: goal),
                              ),
                            );
                          },
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              goal.icon ?? '🎯',
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                goal.title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                goal.type == 'gold'
                                    ? 'Terkumpul: ${_goldFormatter.format(goal.currentAmount)} gram'
                                    : 'Terkumpul: ${_currencyFormatter.format(goal.currentAmount)}',
                                style: theme.textTheme.bodySmall,
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor:
                                      theme.colorScheme.surfaceContainerHighest,
                                  color: progress >= 1.0
                                      ? Colors.green
                                      : theme.colorScheme.primary,
                                  minHeight: 8,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${(progress * 100).toStringAsFixed(1)}%',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    goal.type == 'gold'
                                        ? 'Target: ${_goldFormatter.format(goal.targetAmount)} gram'
                                        : 'Target: ${_currencyFormatter.format(goal.targetAmount)}',
                                    style: theme.textTheme.labelSmall,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );

                  Widget itemContent = Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: cardContent,
                  );

                  return Listener(
                    key: ValueKey(goal.id ?? index),
                    onPointerDown: (_) {
                      if (!_isReorderMode) {
                        _longPressTimer = Timer(const Duration(seconds: 2), () {
                          HapticFeedback.vibrate();
                          setState(() {
                            _isReorderMode = true;
                          });
                        });
                      }
                    },
                    onPointerUp: (_) => _longPressTimer?.cancel(),
                    onPointerCancel: (_) => _longPressTimer?.cancel(),
                    child: _isReorderMode
                        ? ReorderableDragStartListener(
                            index: index,
                            child: ShakeWidget(
                              isShaking: _isReorderMode,
                              child: itemContent,
                            ),
                          )
                        : ShakeWidget(
                            isShaking: _isReorderMode,
                            child: itemContent,
                          ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context, {
    required String title,
    required String terkumpul,
    required String target,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                title,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            terkumpul,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            'Target: $target',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
