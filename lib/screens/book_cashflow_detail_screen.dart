import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../models/book_period.dart';
import '../models/finance_transaction.dart';
import '../widgets/app_card.dart';

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

    // --- Expense By Category Logic ---
    final sortedExpenses = expenseByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final topExpenses = sortedExpenses.take(5).toList();
    final otherExpensesSum = sortedExpenses.skip(5).fold<double>(0.0, (sum, entry) => sum + entry.value);
    
    if (otherExpensesSum > 0) {
      topExpenses.add(MapEntry('Lainnya', otherExpensesSum));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Laporan Cashflow')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Info
            _buildHeader(theme, formatter),
            const SizedBox(height: 24),

            // --- Income vs Expense Card ---
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Statistik Arus Kas', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 200,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: (totalIncome > totalExpense ? totalIncome : totalExpense) * 1.2,
                          barTouchData: BarTouchData(enabled: false),
                          titlesData: FlTitlesData(
                            show: true,
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  if (value == 0) return const Text('Masuk');
                                  if (value == 1) return const Text('Keluar');
                                  return const Text('');
                                },
                              ),
                            ),
                            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          gridData: const FlGridData(show: false),
                          borderData: FlBorderData(show: false),
                          barGroups: [
                            BarChartGroupData(
                              x: 0,
                              barRods: [
                                BarChartRodData(
                                  toY: totalIncome,
                                  color: Colors.green,
                                  width: 40,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ],
                            ),
                            BarChartGroupData(
                              x: 1,
                              barRods: [
                                BarChartRodData(
                                  toY: totalExpense,
                                  color: theme.colorScheme.error,
                                  width: 40,
                                  borderRadius: BorderRadius.circular(4),
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
            
            const SizedBox(height: 24),
            
            // --- Expense By Category PieChart ---
            if (topExpenses.isNotEmpty) ...[
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pengeluaran Berdasarkan Kategori', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 200,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 40,
                            sections: List.generate(topExpenses.length, (i) {
                              final entry = topExpenses[i];
                              final percentage = (entry.value / totalExpense) * 100;
                              final colors = [
                                Colors.blue,
                                Colors.orange,
                                Colors.purple,
                                Colors.teal,
                                Colors.pink,
                                Colors.grey
                              ];
                              
                              return PieChartSectionData(
                                color: colors[i % colors.length],
                                value: entry.value,
                                title: '${percentage.toStringAsFixed(0)}%',
                                radius: 50,
                                titleStyle: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              );
                            }),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Legend
                      ...List.generate(topExpenses.length, (i) {
                        final entry = topExpenses[i];
                        final colors = [
                          Colors.blue,
                          Colors.orange,
                          Colors.purple,
                          Colors.teal,
                          Colors.pink,
                          Colors.grey
                        ];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: colors[i % colors.length],
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(entry.key)),
                              Text(
                                formatter.format(entry.value),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
              ),
              const SizedBox(height: 24),
            ],

            // Laporan Cashflow Standard
            AppCard(
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
