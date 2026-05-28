import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/book_period.dart';
import '../models/finance_transaction.dart';

class BookCashflowDetailScreen extends StatelessWidget {
  const BookCashflowDetailScreen({
    super.key,
    required this.book,
    required this.transactions,
  });

  final BookPeriod book;
  final List<FinanceTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    // Grouping transactions
    final incomeTx = transactions.where((tx) => tx.type == 'INCOME').toList();
    final expenseTx = transactions.where((tx) => tx.type == 'EXPENSE').toList();

    double totalIncome = 0;
    final Map<String, double> incomeByCategory = {};
    for (final tx in incomeTx) {
      totalIncome += tx.amount;
      incomeByCategory[tx.category] =
          (incomeByCategory[tx.category] ?? 0) + tx.amount;
    }

    double totalExpense = 0;
    final Map<String, double> expenseByCategory = {};
    for (final tx in expenseTx) {
      totalExpense += tx.amount;
      expenseByCategory[tx.category] =
          (expenseByCategory[tx.category] ?? 0) + tx.amount;
    }

    final netCashflow = totalIncome - totalExpense;

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Laporan Cashflow')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Info
            _buildHeader(theme, formatter),
            const SizedBox(height: 24),

            // Laporan Cashflow Standard
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        'LAPORAN ARUS KAS',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ARUS KAS MASUK
                    Text(
                      'Arus Kas dari Pemasukan (Inflows)',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    if (incomeByCategory.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'Tidak ada pemasukan tercatat.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ...incomeByCategory.entries.map(
                      (e) => _buildDetailRow(e.key, e.value, formatter),
                    ),
                    const SizedBox(height: 8),
                    _buildTotalRow(
                      'Total Pemasukan',
                      totalIncome,
                      formatter,
                      isPositive: true,
                    ),

                    const SizedBox(height: 24),

                    // ARUS KAS KELUAR
                    Text(
                      'Arus Kas untuk Pengeluaran (Outflows)',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    if (expenseByCategory.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'Tidak ada pengeluaran tercatat.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ...expenseByCategory.entries.map(
                      (e) => _buildDetailRow(
                        e.key,
                        e.value,
                        formatter,
                        isNegative: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildTotalRow(
                      'Total Pengeluaran',
                      totalExpense,
                      formatter,
                      isNegative: true,
                    ),

                    const SizedBox(height: 32),

                    // ARUS KAS BERSIH
                    const Divider(thickness: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            'KENAIKAN/(PENURUNAN) KAS BERSIH',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatter.format(netCashflow),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: netCashflow < 0
                                ? colorScheme.error
                                : (netCashflow > 0
                                      ? colorScheme.primary
                                      : colorScheme.onSurface),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '  (Net Cash Flow)',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, NumberFormat formatter) {
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

    return Column(
      children: [
        Text(
          book.label,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'Periode: $dateRange',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.hintColor,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: book.isOpen
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            book.isOpen ? 'Status: Aktif' : 'Status: Selesai',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: book.isOpen
                  ? theme.colorScheme.primary
                  : theme.hintColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(
    String label,
    double amount,
    NumberFormat formatter, {
    bool isNegative = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text('  $label')),
          Text(
            (isNegative ? '(' : '') +
                formatter.format(amount) +
                (isNegative ? ')' : ''),
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(
    String label,
    double amount,
    NumberFormat formatter, {
    bool isNegative = false,
    bool isPositive = false,
  }) {
    return Column(
      children: [
        const Divider(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(
              (isNegative ? '(' : '') +
                  formatter.format(amount) +
                  (isNegative ? ')' : ''),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isNegative
                    ? const Color(0xFFC24545)
                    : (isPositive ? const Color(0xFF1E7C43) : null),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
