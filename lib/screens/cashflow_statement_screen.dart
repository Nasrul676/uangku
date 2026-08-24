import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/book_period.dart';
import '../models/finance_transaction.dart';
import '../theme/app_theme.dart';
import '../utils/cashflow_export.dart';

/// Laporan arus kas formal, terpisah dari layar detail.
///
/// Dipisah karena isinya mengulang data yang sudah disajikan di layar detail
/// dengan bentuk yang lebih mudah dibaca. Di halamannya sendiri, gaya cetak
/// akuntansinya bisa dijalankan penuh — angka monospace rata kanan, garis
/// rule, tanpa kartu membulat — alih-alih setengah jalan di dalam kartu.
class CashflowStatementScreen extends StatelessWidget {
  const CashflowStatementScreen({
    super.key,
    required this.book,
    required this.transactions,
  });

  final BookPeriod book;
  final List<FinanceTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final incomeByCategory = <String, double>{};
    final expenseByCategory = <String, double>{};
    var totalIncome = 0.0;
    var totalExpense = 0.0;

    for (final tx in transactions) {
      if (tx.type == 'INCOME') {
        totalIncome += tx.amount;
        incomeByCategory[tx.category] =
            (incomeByCategory[tx.category] ?? 0) + tx.amount;
      } else if (tx.type == 'EXPENSE') {
        totalExpense += tx.amount;
        expenseByCategory[tx.category] =
            (expenseByCategory[tx.category] ?? 0) + tx.amount;
      }
    }

    final net = totalIncome - totalExpense;

    final sortedIncome = incomeByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final sortedExpense = expenseByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Arus Kas'),
        actions: [
          IconButton(
            tooltip: 'Bagikan sebagai PDF',
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: () => shareCashflowPdf(
              context: context,
              book: book,
              transactions: transactions,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          Text(
            'LAPORAN ARUS KAS',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            book.label,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            _periodLabel(book),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
          const SizedBox(height: 22),

          _StatementSection(
            title: 'ARUS KAS DARI PEMASUKAN',
            entries: sortedIncome,
            total: totalIncome,
            totalLabel: 'Jumlah pemasukan',
            emptyLabel: 'Tidak ada pemasukan tercatat.',
          ),
          const SizedBox(height: 26),
          _StatementSection(
            title: 'ARUS KAS UNTUK PENGELUARAN',
            entries: sortedExpense,
            total: totalExpense,
            totalLabel: 'Jumlah pengeluaran',
            emptyLabel: 'Tidak ada pengeluaran tercatat.',
            parenthesised: true,
          ),

          const SizedBox(height: 30),
          Container(height: 2, color: theme.dividerColor),
          const SizedBox(height: 10),
          _StatementRow(
            label: 'KENAIKAN (PENURUNAN) KAS BERSIH',
            amount: net,
            bold: true,
            emphasisColor: net < 0 ? AppTheme.expenseRed : AppTheme.incomeGreen,
          ),
          const SizedBox(height: 10),
          Container(height: 1, color: theme.dividerColor),
          const SizedBox(height: 3),
          Container(height: 1, color: theme.dividerColor),
        ],
      ),
    );
  }

  static String _periodLabel(BookPeriod book) {
    final formatter = DateFormat('dd MMM yyyy', 'id');
    final start = DateTime.tryParse(book.startDate);
    final startText = start == null ? book.startDate : formatter.format(start);

    final endRaw = book.endDate;
    if (endRaw == null || endRaw.isEmpty) return '$startText – Sekarang';
    final end = DateTime.tryParse(endRaw);
    return '$startText – ${end == null ? endRaw : formatter.format(end)}';
  }
}

class _StatementSection extends StatelessWidget {
  const _StatementSection({
    required this.title,
    required this.entries,
    required this.total,
    required this.totalLabel,
    required this.emptyLabel,
    this.parenthesised = false,
  });

  final String title;
  final List<MapEntry<String, double>> entries;
  final double total;
  final String totalLabel;
  final String emptyLabel;

  /// Konvensi akuntansi: angka pengurang ditulis dalam kurung.
  final bool parenthesised;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        Container(height: 1, color: theme.dividerColor),
        const SizedBox(height: 6),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              emptyLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          for (final entry in entries)
            _StatementRow(
              label: entry.key,
              amount: entry.value,
              indent: true,
              parenthesised: parenthesised,
            ),
        const SizedBox(height: 6),
        Container(height: 1, color: theme.dividerColor),
        const SizedBox(height: 4),
        _StatementRow(
          label: totalLabel,
          amount: total,
          bold: true,
          parenthesised: parenthesised,
        ),
      ],
    );
  }
}

class _StatementRow extends StatelessWidget {
  const _StatementRow({
    required this.label,
    required this.amount,
    this.indent = false,
    this.bold = false,
    this.parenthesised = false,
    this.emphasisColor,
  });

  final String label;
  final double amount;
  final bool indent;
  final bool bold;
  final bool parenthesised;
  final Color? emphasisColor;

  static final _formatter = NumberFormat.decimalPattern('id_ID');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final magnitude = _formatter.format(amount.abs());
    final showParens = parenthesised || amount < 0;
    final text = showParens ? '($magnitude)' : magnitude;

    final style = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: bold ? FontWeight.w800 : FontWeight.w400,
      color: emphasisColor,
      // Digit lurus antar-baris — inti dari sebuah laporan berkolom.
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Padding(
      padding: EdgeInsets.only(left: indent ? 14 : 0, top: 4, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: bold ? FontWeight.w800 : FontWeight.w400,
                color: emphasisColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(text, style: style),
        ],
      ),
    );
  }
}
