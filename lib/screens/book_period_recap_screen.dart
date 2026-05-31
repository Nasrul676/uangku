import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/transaction_provider.dart';
import '../models/book_period.dart';
import '../models/finance_transaction.dart';
import '../widgets/empty_state.dart';
import '../widgets/app_card.dart';
import 'book_cashflow_detail_screen.dart';

class BookPeriodRecapScreen extends StatelessWidget {
  const BookPeriodRecapScreen({super.key, this.isEmbedded = false});
  final bool isEmbedded;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isEmbedded ? Colors.transparent : null,
      appBar: isEmbedded
          ? null
          : AppBar(title: const Text('Rekap Cashflow per Buku')),
      body: Consumer<TransactionProvider>(
        builder: (context, provider, child) {
          final bookPeriods = provider.bookPeriods.toList();

          if (bookPeriods.isEmpty) {
            return const EmptyState(
              title: 'Belum ada data',
              subtitle: 'Belum ada buku pengeluaran.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: bookPeriods.length,
            itemBuilder: (context, index) {
              final book = bookPeriods[index];
              return _BookRecapCard(
                book: book,
                allTransactions: provider.allTransactions,
              );
            },
          );
        },
      ),
    );
  }
}

class _BookRecapCard extends StatelessWidget {
  const _BookRecapCard({required this.book, required this.allTransactions});

  final BookPeriod book;
  final List<FinanceTransaction> allTransactions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Filter transactions for this book
    final bookTransactions = allTransactions
        .where((tx) => tx.bookPeriodId == book.id)
        .toList(growable: false);

    double totalIncome = 0;
    double totalExpense = 0;

    for (final tx in bookTransactions) {
      if (tx.type == 'INCOME') {
        totalIncome += tx.amount;
      } else if (tx.type == 'EXPENSE') {
        totalExpense += tx.amount;
      }
    }

    final netBalance = totalIncome - totalExpense;

    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    // Format dates
    String dateRange = '';
    try {
      final startDf = DateFormat('yyyy-MM-dd').parse(book.startDate);
      final startStr = DateFormat('dd MMM yyyy', 'id').format(startDf);
      dateRange = startStr;

      if (book.endDate != null && book.endDate!.isNotEmpty) {
        final endDf = DateFormat('yyyy-MM-dd').parse(book.endDate!);
        final endStr = DateFormat('dd MMM yyyy', 'id').format(endDf);
        dateRange += ' - $endStr';
      } else {
        dateRange += ' - Sekarang';
      }
    } catch (_) {
      dateRange = book.startDate;
    }

    return AppCard(
      isInteractive: true,
      margin: const EdgeInsets.only(bottom: 16),
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BookCashflowDetailScreen(
              book: book,
              transactions: bookTransactions,
            ),
          ),
        );
      },
      padding: const EdgeInsets.all(16),
      child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      book.label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: book.isOpen
                          ? Colors.green.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      book.isOpen ? 'Aktif' : 'Selesai',
                      style: TextStyle(
                        color: book.isOpen
                            ? Colors.green[700]
                            : Colors.grey[700],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                dateRange,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                ),
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Pemasukan:'),
                  Text(
                    formatter.format(totalIncome),
                    style: const TextStyle(
                      color: Color(0xFF227C44),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Pengeluaran:'),
                  Text(
                    '- ${formatter.format(totalExpense)}',
                    style: const TextStyle(
                      color: Color(0xFFC24545),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Saldo Bersih:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    formatter.format(netBalance),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: netBalance < 0
                          ? const Color(0xFFC24545)
                          : (netBalance > 0
                                ? const Color(0xFF227C44)
                                : colorScheme.onSurface),
                    ),
                  ),
                ],
              ),
            ],
          ),
    );
  }
}
