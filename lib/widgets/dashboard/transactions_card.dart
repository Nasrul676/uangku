import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../models/finance_transaction.dart';
import '../../providers/transaction_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/skeleton_loader.dart';
import '../app_card.dart';
import '../../screens/income_input_screen.dart';
import '../../screens/expense_input_screen.dart';

class TransactionsCard extends StatefulWidget {
  const TransactionsCard({
    super.key,
    required this.theme,
    required this.title,
    required this.transactions,
    required this.isLoading,
    required this.emptyText,
    this.titleColor,
  });

  final ThemeData theme;
  final String title;
  final List<FinanceTransaction> transactions;
  final bool isLoading;
  final String emptyText;
  final Color? titleColor;

  @override
  State<TransactionsCard> createState() => _TransactionsCardState();
}

class _TransactionsCardState extends State<TransactionsCard> {
  late final ScrollController _scrollController;
  final Set<int> _hiddenTransactions = {};

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.title.isNotEmpty) ...[
            Row(
              children: [
                Text(
                  widget.title,
                  style: widget.theme.textTheme.headlineSmall?.copyWith(
                    color: widget.titleColor,
                  ),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 10),
          ],
          if (widget.isLoading)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: SkeletonLoader(itemCount: 5),
              ),
            )
          else if (widget.transactions.isEmpty)
            Expanded(
              child: EmptyState(
                title: 'Belum ada data',
                subtitle: widget.emptyText,
              ),
            )
          else
            Expanded(
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                child: ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(bottom: 100),
                  primary: false,
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  itemCount: widget.transactions.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = widget.transactions[index];
                    if (_hiddenTransactions.contains(item.id)) {
                      return const SizedBox.shrink();
                    }
                    return TransactionTile(
                      item: item,
                      theme: widget.theme,
                      onDeleteOptimistic: (txId) {
                        setState(() {
                          _hiddenTransactions.add(txId);
                        });
                      },
                      onUndoDelete: (txId) {
                        setState(() {
                          _hiddenTransactions.remove(txId);
                        });
                      },
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.item,
    required this.theme,
    this.onDeleteOptimistic,
    this.onUndoDelete,
  });

  final FinanceTransaction item;
  final ThemeData theme;
  final Function(int)? onDeleteOptimistic;
  final Function(int)? onUndoDelete;

  @override
  Widget build(BuildContext context) {
    final isIncome = item.type == 'INCOME';
    final parsedDate = DateTime.tryParse(item.date);
    final dateText = parsedDate == null
        ? item.date
        : DateFormat('dd MMM yyyy', 'id').format(parsedDate);
    final storedTime = item.time?.trim();
    final hasTime = storedTime != null && storedTime.isNotEmpty;
    final datetimeLabel = hasTime ? '$dateText • $storedTime' : dateText;
    final rupiahFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final amountText =
        '${isIncome ? '+' : '-'}${rupiahFormatter.format(item.amount)}';

    Widget child = AppCard(
      isInteractive: true,
      onTap: () {
        // If you want tap to do something, add it here.
        // For now just for the bounce effect.
      },
      padding: const EdgeInsets.all(10),
      color: Theme.of(context).cardTheme.color ?? Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isIncome ? AppTheme.incomeLight : AppTheme.expenseLight,
              borderRadius: BorderRadius.circular(8),
              border: Theme.of(
                context,
              ).extension<AppThemeExtension>()?.cardBorder,
            ),
            child: Icon(
              isIncome ? Icons.south_west_rounded : Icons.north_east_rounded,
              size: 16,
              color: isIncome ? AppTheme.incomeGreen : AppTheme.expenseRed,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isIncome ? null : const Color(0xFFC24545),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.category} • $datetimeLabel',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isIncome ? null : const Color(0xFFA13A3A),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amountText,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: isIncome ? null : const Color(0xFFC24545),
                ),
              ),
              const SizedBox(height: 2),
              Icon(
                item.isSynced == 1
                    ? Icons.cloud_done_rounded
                    : Icons.cloud_off_rounded,
                size: 16,
                color: item.isSynced == 1
                    ? const Color(0xFF2A9D50)
                    : const Color(0xFFC24545),
              ),
            ],
          ),
        ],
      ),
    );

    if (onDeleteOptimistic == null || onUndoDelete == null) {
      return child;
    }

    return Slidable(
      key: ValueKey(item.id),
      startActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (context) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => isIncome
                      ? IncomeInputScreen(existingTransaction: item)
                      : ExpenseInputScreen(existingTransaction: item),
                ),
              );
            },
            backgroundColor: const Color(0xFF6CC185),
            foregroundColor: Colors.white,
            icon: Icons.edit_rounded,
            label: 'Edit',
            borderRadius: BorderRadius.circular(12),
          ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (slidableCtx) {
              if (!context.mounted) return;
              final provider = context.read<TransactionProvider>();
              final messenger = ScaffoldMessenger.of(context);

              // Optimistic UI hiding
              onDeleteOptimistic!(item.id!);

              messenger.clearSnackBars();
              final snackBarController = messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    '"${item.title}" dihapus.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  action: SnackBarAction(
                    label: 'Batalkan',
                    onPressed: () {
                      // Action handles its own dismissal and undo
                    },
                  ),
                ),
              );

              // Paksa tutup snackbar setelah 2 detik agar tidak nyangkut
              final closeTimer = Timer(const Duration(seconds: 2), () {
                snackBarController.close();
              });

              snackBarController.closed.then((reason) async {
                closeTimer.cancel();
                if (reason == SnackBarClosedReason.action) {
                  // Jika di-klik Batalkan
                  onUndoDelete!(item.id!);
                } else {
                  // Jika waktu habis atau ditutup alasan lain (benar-benar dihapus)
                  try {
                    await provider.removeTransaction(item.id!);
                  } catch (e) {
                    onUndoDelete!(item.id!); // restore if failed
                    if (messenger.mounted) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            'Gagal menghapus: ${e.toString().replaceFirst('Exception: ', '')}',
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                }
              });
            },
            backgroundColor: AppTheme.expenseRed,
            foregroundColor: Colors.white,
            icon: Icons.delete_rounded,
            label: 'Hapus',
            borderRadius: BorderRadius.circular(12),
          ),
        ],
      ),
      child: child,
    );
  }
}
