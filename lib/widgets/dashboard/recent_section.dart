import 'package:flutter/material.dart';

import '../../models/finance_transaction.dart';
import '../app_card.dart';
import 'transactions_card.dart';

class RecentSection extends StatelessWidget {
  const RecentSection({
    super.key,
    required this.theme,
    required this.transactions,
    required this.isLoading,
    required this.headerBottom,
  });

  final ThemeData theme;
  final List<FinanceTransaction> transactions;
  final bool isLoading;
  final Widget headerBottom;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row(
            //   children: [
            //     Text(
            //       'Transaksi Terbaru',
            //       style: theme.textTheme.titleMedium?.copyWith(fontSize: 24),
            //     ),
            //   ],
            // ),
            // const SizedBox(height: 8),
            // headerBottom,
            // const SizedBox(height: 10),
            // if (isLoading)
            //   const Padding(
            //     padding: EdgeInsets.symmetric(vertical: 32),
            //     child: Center(child: CircularProgressIndicator()),
            //   )
            // else if (transactions.isEmpty)
            //   const Padding(
            //     padding: EdgeInsets.symmetric(vertical: 12),
            //     child: Text('Belum ada transaksi dulu nih.'),
            //   )
            // else
            //   ListView.separated(
            //     shrinkWrap: true,
            //     physics: const NeverScrollableScrollPhysics(),
            //     itemCount: transactions.length,
            //     separatorBuilder: (context, index) => const SizedBox(height: 8),
            //     itemBuilder: (context, index) =>
            //         TransactionTile(item: transactions[index], theme: theme),
            //   ),
          ],
      ),
    );
  }
}
