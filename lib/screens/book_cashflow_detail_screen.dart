import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/book_period.dart';
import '../models/finance_transaction.dart';
import '../utils/cashflow_export.dart';
import '../utils/cashflow_recap.dart';
import '../widgets/app_card.dart';
import '../theme/app_theme.dart';
import 'cashflow_statement_screen.dart';

final _amountFormatter = NumberFormat.decimalPattern('id_ID');

class BookCashflowDetailScreen extends StatelessWidget {
  const BookCashflowDetailScreen({
    super.key,
    required this.book,
    required this.transactions,
    this.moneyLocationNames = const {},
  });

  final BookPeriod book;
  final List<FinanceTransaction> transactions;

  /// Nama lokasi per id, ikut ditulis sebagai kolom "Lokasi" di CSV.
  final Map<int, String> moneyLocationNames;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final recap = buildCashflowRecap([book], transactions).books.first;
    final categories = buildCategoryBreakdown(transactions);

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Arus Kas')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
        children: [
          _Header(book: book, transactionCount: recap.transactionCount),
          const SizedBox(height: 14),

          _FlowPanel(recap: recap),
          const SizedBox(height: 12),

          if (categories.isNotEmpty) ...[
            _CategoryPanel(slices: categories),
            const SizedBox(height: 12),
          ],

          _NavRow(
            icon: Icons.description_outlined,
            label: 'Laporan arus kas lengkap',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CashflowStatementScreen(
                  book: book,
                  transactions: transactions,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => shareCashflowPdf(
                    context: context,
                    book: book,
                    transactions: transactions,
                  ),
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: const Text('Ekspor PDF'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => shareCashflowCsv(
                    context: context,
                    book: book,
                    transactions: transactions,
                    moneyLocationNames: moneyLocationNames,
                  ),
                  icon: const Icon(Icons.table_chart_outlined, size: 18),
                  label: const Text('CSV'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'PDF untuk dibaca atau dicetak, CSV untuk diolah di Excel, '
            'Google Sheets, atau Numbers.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.book, required this.transactionCount});

  final BookPeriod book;
  final int transactionCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: book.isOpen ? AppTheme.incomeGreen : theme.hintColor,
              ),
            ),
            Expanded(
              child: Text(
                book.label,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '${_periodLabel(book)} · $transactionCount transaksi',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
        ),
      ],
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

/// Arus kas sebagai satu batang proporsional.
///
/// Menggantikan `BarChart` setinggi 200px yang sentuhannya dimatikan dan sumbu
/// kirinya disembunyikan — jadi tidak ada satu pun angka yang terbaca darinya.
/// Di sini kedua nominal tercetak di dalam batangnya.
class _FlowPanel extends StatelessWidget {
  const _FlowPanel({required this.recap});

  final BookRecap recap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = recap.spentRatio;
    final isOver = recap.isOverspending;

    return AppCard(
      padding: const EdgeInsets.all(14),
      borderRadius: BorderRadius.circular(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelLabel('Arus kas'),
          const SizedBox(height: 12),
          Semantics(
            label:
                'Pemasukan ${_amountFormatter.format(recap.totalIncome)} rupiah, '
                'pengeluaran ${_amountFormatter.format(recap.totalExpense)} rupiah',
            child: Container(
              height: 34,
              decoration: BoxDecoration(
                color: AppTheme.incomeLight,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: isOver
                      ? AppTheme.expenseRed
                      : (theme.textTheme.bodyLarge?.color ?? Colors.black),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  if (ratio != null)
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: ratio.clamp(0.0, 1.0),
                      child: Container(color: AppTheme.expenseLight),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _BarValue(
                          value: recap.totalExpense,
                          color: AppTheme.expenseRed,
                        ),
                        _BarValue(
                          value: recap.totalIncome,
                          color: AppTheme.incomeGreen,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Keluar',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                  fontSize: 11,
                ),
              ),
              Text(
                'Masuk',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          _RatioLine(recap: recap),
        ],
      ),
    );
  }
}

class _BarValue extends StatelessWidget {
  const _BarValue({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      _amountFormatter.format(value),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        fontWeight: FontWeight.w800,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

/// Konteks untuk saldo bersih — "Rp 2.400.000" saja tidak menjawab
/// "itu bagus atau tidak".
class _RatioLine extends StatelessWidget {
  const _RatioLine({required this.recap});

  final BookRecap recap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = recap.spentRatio;
    final net = recap.net;

    final baseStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.hintColor,
    );
    final strongStyle = theme.textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.w800,
      color: theme.textTheme.bodyMedium?.color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    if (ratio == null) {
      return Text('Belum ada pemasukan di buku ini.', style: baseStyle);
    }

    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          const TextSpan(text: 'Terpakai '),
          TextSpan(
            text: '${(ratio * 100).round()}%',
            style: strongStyle?.copyWith(
              color: recap.isOverspending ? AppTheme.expenseRed : null,
            ),
          ),
          const TextSpan(text: ' dari pemasukan · '),
          TextSpan(text: net < 0 ? 'kurang ' : 'sisa '),
          TextSpan(
            text: 'Rp ${_amountFormatter.format(net.abs())}',
            style: strongStyle?.copyWith(
              color: net < 0 ? AppTheme.expenseRed : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pengeluaran per kategori sebagai batang horizontal terurut.
///
/// Menggantikan pie chart + legenda + pengulangan di laporan formal. Panjang
/// batang bisa dibandingkan langsung — hal yang justru sulit pada pie ketika
/// dua irisan mirip besarnya.
class _CategoryPanel extends StatelessWidget {
  const _CategoryPanel({required this.slices});

  final List<CategorySlice> slices;

  @override
  Widget build(BuildContext context) {
    final largest = slices.first.amount;

    return AppCard(
      padding: const EdgeInsets.all(14),
      borderRadius: BorderRadius.circular(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelLabel('Pengeluaran per kategori'),
          const SizedBox(height: 10),
          for (final slice in slices)
            _CategoryBar(slice: slice, largest: largest),
        ],
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({required this.slice, required this.largest});

  final CategorySlice slice;
  final double largest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = (slice.share * 100).round();

    final label = slice.isOther
        ? '${slice.label} (${slice.collapsedCount} kategori)'
        : slice.label;

    return Semantics(
      label:
          '$label, $percent persen, ${_amountFormatter.format(slice.amount)} rupiah',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: slice.isOther ? theme.hintColor : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$percent%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                    fontSize: 11,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _amountFormatter.format(slice.amount),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: theme.dividerColor.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(999),
              ),
              clipBehavior: Clip.antiAlias,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: largest <= 0
                    ? 0.0
                    : (slice.amount / largest).clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    // Baris "Lainnya" dibuat netral supaya tidak terbaca
                    // sebagai satu kategori sungguhan.
                    color: slice.isOther
                        ? theme.hintColor
                        : AppTheme.expenseRed,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PanelLabel extends StatelessWidget {
  const _PanelLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      label.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.hintColor,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        fontSize: 10,
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      label: label,
      child: AppCard(
        isInteractive: true,
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 18, color: theme.hintColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: theme.hintColor),
          ],
        ),
      ),
    );
  }
}
