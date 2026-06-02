import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/recurring_transaction.dart';
import '../providers/transaction_provider.dart';
import '../widgets/animated_bouncing_card.dart';
import '../theme/app_theme.dart';
import 'recurring_transaction_input_screen.dart';

class RecurringTransactionsScreen extends StatefulWidget {
  const RecurringTransactionsScreen({super.key});

  @override
  State<RecurringTransactionsScreen> createState() =>
      _RecurringTransactionsScreenState();
}

class _RecurringTransactionsScreenState extends State<RecurringTransactionsScreen> {
  final _currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<TransactionProvider>();
    final transactions = provider.recurringTransactions;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(5, 12, 5, 12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RecurringTransactionInputScreen(),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.add_box_rounded,
                  color: Color(0xFF2A9D50),
                ),
                label: const Text(
                  'Tambah Rutin',
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
          if (transactions.isEmpty)
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
                      'Belum ada transaksi rutin',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Catat langganan Netflix, Spotify, atau tagihan bulanan.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(5, 16, 5, 140),
                itemCount: transactions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final tx = transactions[index];
                  final isIncome = tx.type == 'INCOME';
                  final isDark = theme.brightness == Brightness.dark;

                  final amountColor = isIncome ? AppTheme.incomeGreen : AppTheme.expenseRed;
                  final iconBg = isIncome
                      ? (isDark ? Colors.green.withOpacity(0.2) : Colors.green.shade100)
                      : (isDark ? Colors.red.withOpacity(0.2) : Colors.red.shade100);
                  
                  final nextDate = DateTime.tryParse(tx.nextDate);
                  final dateStr = nextDate != null
                      ? DateFormat('dd MMM yyyy', 'id').format(nextDate)
                      : '-';

                  String freqLabel = '';
                  switch (tx.frequency) {
                    case 'DAILY': freqLabel = 'Harian'; break;
                    case 'WEEKLY': freqLabel = 'Mingguan'; break;
                    case 'MONTHLY': freqLabel = 'Bulanan'; break;
                    case 'YEARLY': freqLabel = 'Tahunan'; break;
                    default: freqLabel = tx.frequency;
                  }

                  return AnimatedBouncingCard(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RecurringTransactionInputScreen(
                            existingTransaction: tx,
                          ),
                        ),
                      );
                    },
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tx.title,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2.0),
                                        child: Icon(
                                          Icons.category_outlined,
                                          size: 14,
                                          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          tx.category,
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                                          ),
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          freqLabel,
                                          style: theme.textTheme.labelSmall?.copyWith(
                                            color: theme.colorScheme.primary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          _currencyFormatter.format(tx.amount),
                                          style: theme.textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: amountColor,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: iconBg,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isIncome
                                    ? Icons.arrow_downward_rounded
                                    : Icons.arrow_upward_rounded,
                                color: amountColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: tx.isActive 
                                ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
                                : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today_rounded,
                                      size: 18,
                                      color: tx.isActive ? theme.colorScheme.primary : theme.disabledColor,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Jadwal Berikutnya',
                                            style: theme.textTheme.labelSmall?.copyWith(
                                              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            dateStr,
                                            style: theme.textTheme.labelMedium?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: tx.isActive ? theme.textTheme.bodyLarge?.color : theme.disabledColor,
                                              decoration: tx.isActive ? null : TextDecoration.lineThrough,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    tx.isActive ? 'Aktif' : 'Nonaktif',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: tx.isActive ? theme.colorScheme.primary : theme.disabledColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    height: 24,
                                    width: 40,
                                    child: Transform.scale(
                                      scale: 0.8,
                                      child: Switch(
                                        value: tx.isActive,
                                        onChanged: (val) {
                                          provider.updateRecurringTransaction(
                                            tx.copyWith(isActive: val),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
