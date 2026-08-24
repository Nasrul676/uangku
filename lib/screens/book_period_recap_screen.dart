import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/transaction_provider.dart';
import '../models/finance_transaction.dart';
import '../utils/cashflow_recap.dart';
import '../widgets/empty_state.dart';
import '../widgets/app_card.dart';
import 'book_cashflow_detail_screen.dart';
import '../theme/app_theme.dart';

final _compactFormatter = NumberFormat.decimalPattern('id_ID');

String _signedCompact(double value) {
  final sign = value < 0 ? '−' : '+';
  return '$sign${_compactFormatter.format(value.abs())}';
}

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
          final recap = buildCashflowRecap(
            provider.bookPeriods,
            provider.allTransactions,
          );

          if (recap.isEmpty) {
            return const EmptyState(
              title: 'Belum ada data',
              subtitle: 'Belum ada buku pengeluaran.',
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            children: [
              _RecapSummaryCard(recap: recap),
              const SizedBox(height: 12),
              _BookRecapList(
                recap: recap,
                allTransactions: provider.allTransactions,
                moneyLocationNames: provider.moneyLocationNames,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Ringkasan lintas periode — menjawab "bagaimana keseluruhannya" sebelum
/// pembaca perlu menggulung ke buku mana pun.
class _RecapSummaryCard extends StatelessWidget {
  const _RecapSummaryCard({required this.recap});

  final CashflowRecap recap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final books = recap.books;

    final rangeLabel = _rangeLabel(books);
    final isPositive = recap.net >= 0;

    return AppCard(
      padding: const EdgeInsets.all(14),
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${books.length} buku${rangeLabel.isEmpty ? '' : ' · $rangeLabel'}'
                .toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.hintColor,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'Rp',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.hintColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  _compactFormatter.format(recap.net.abs()),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isPositive
                        ? AppTheme.fabIconColor
                        : AppTheme.expenseRed,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _MiniStat(
                label: 'Masuk',
                value: recap.totalIncome,
                color: AppTheme.incomeGreen,
              ),
              const SizedBox(width: 18),
              _MiniStat(
                label: 'Keluar',
                value: recap.totalExpense,
                color: AppTheme.expenseRed,
              ),
            ],
          ),
          if (books.length > 1) ...[
            const SizedBox(height: 14),
            _NetSeries(recap: recap),
          ],
        ],
      ),
    );
  }

  static String _rangeLabel(List<BookRecap> books) {
    if (books.isEmpty) return '';
    final newest = DateTime.tryParse(books.first.book.startDate);
    final oldest = DateTime.tryParse(books.last.book.startDate);
    if (newest == null || oldest == null) return '';

    final formatter = DateFormat('MMM yyyy', 'id');
    if (books.length == 1) return formatter.format(newest);
    return '${formatter.format(oldest)} – ${formatter.format(newest)}';
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
        ),
        Text(
          _compactFormatter.format(value),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// Deret saldo bersih per periode. Tinggi batang sebanding dengan nilainya,
/// merah untuk periode yang minus, garis tepi untuk buku yang masih aktif.
class _NetSeries extends StatelessWidget {
  const _NetSeries({required this.recap});

  final CashflowRecap recap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final max = recap.maxAbsoluteNet;
    if (max <= 0) return const SizedBox.shrink();

    // Terlama di kiri supaya waktu bergerak ke kanan seperti biasa.
    final ordered = recap.books.reversed.toList(growable: false);
    final formatter = DateFormat('MMM', 'id');

    return Semantics(
      label: 'Saldo bersih per periode',
      child: SizedBox(
        height: 54,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final item in ordered)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        height: (item.net.abs() / max * 34).clamp(2.0, 34.0),
                        decoration: BoxDecoration(
                          color: item.net < 0
                              ? AppTheme.expenseRed
                              : AppTheme.incomeGreen,
                          borderRadius: BorderRadius.circular(2),
                          border: item.book.isOpen
                              ? Border.all(
                                  color:
                                      theme.textTheme.bodyLarge?.color ??
                                      Colors.black,
                                  width: 1,
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _monthLabel(item.book.startDate, formatter),
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 9,
                          color: theme.hintColor,
                        ),
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

  static String _monthLabel(String startDate, DateFormat formatter) {
    final parsed = DateTime.tryParse(startDate);
    return parsed == null ? '–' : formatter.format(parsed);
  }
}

class _BookRecapList extends StatelessWidget {
  const _BookRecapList({
    required this.recap,
    required this.allTransactions,
    this.moneyLocationNames = const {},
  });

  final CashflowRecap recap;
  final List<FinanceTransaction> allTransactions;
  final Map<int, String> moneyLocationNames;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color:
            Theme.of(context).cardTheme.color ??
            Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Theme.of(context).extension<AppThemeExtension>()?.cardBorder,
      ),
      child: Column(
        children: [
          for (var i = 0; i < recap.books.length; i++)
            _BookRecapRow(
              item: recap.books[i],
              showDivider: i != recap.books.length - 1,
              onTap: () {
                final bookTransactions = allTransactions
                    .where((tx) => tx.bookPeriodId == recap.books[i].book.id)
                    .toList(growable: false);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BookCashflowDetailScreen(
                      book: recap.books[i].book,
                      transactions: bookTransactions,
                      moneyLocationNames: moneyLocationNames,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// Satu buku sebagai baris ringkas.
///
/// Bentuk baris dipilih supaya empat sampai lima buku terlihat sekaligus —
/// syarat agar perbandingan antar-periode bisa terjadi sama sekali.
class _BookRecapRow extends StatelessWidget {
  const _BookRecapRow({
    required this.item,
    required this.onTap,
    required this.showDivider,
  });

  final BookRecap item;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = item.spentRatio;
    final delta = item.expenseDeltaRatio;

    return Semantics(
      button: true,
      label:
          '${item.book.label}, saldo bersih ${_signedCompact(item.net)} rupiah'
          '${ratio == null ? '' : ', terpakai ${(ratio * 100).round()} persen dari pemasukan'}',
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Column(
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
                          color: item.book.isOpen
                              ? AppTheme.incomeGreen
                              : theme.hintColor,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          item.book.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        _signedCompact(item.net),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: item.net < 0
                              ? AppTheme.expenseRed
                              : AppTheme.incomeGreen,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  _SpendBar(ratio: ratio),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          ratio == null
                              ? 'Belum ada pemasukan'
                              : 'Terpakai ${(ratio * 100).round()}% dari pemasukan',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.hintColor,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      if (delta != null) _DeltaLabel(ratio: delta),
                    ],
                  ),
                ],
              ),
            ),
            if (showDivider)
              Divider(
                height: 1,
                thickness: 1,
                color: theme.dividerColor.withValues(alpha: 0.4),
              ),
          ],
        ),
      ),
    );
  }
}

/// Batang proporsional: berapa besar pengeluaran terhadap pemasukan.
/// Penuh dengan garis tepi merah kalau melebihi 100%.
class _SpendBar extends StatelessWidget {
  const _SpendBar({required this.ratio});

  final double? ratio;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = ratio;
    final isOver = value != null && value > 1;

    return Container(
      height: 7,
      decoration: BoxDecoration(
        color: value == null
            ? theme.dividerColor.withValues(alpha: 0.4)
            : AppTheme.incomeLight,
        borderRadius: BorderRadius.circular(999),
        border: isOver ? Border.all(color: AppTheme.expenseRed) : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: value == null
          ? null
          : FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.expenseRed,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
    );
  }
}

/// Perubahan pengeluaran dari periode sebelumnya. Turun hijau, naik merah —
/// angka mutlak memberi tahu posisi, delta memberi tahu arah.
class _DeltaLabel extends StatelessWidget {
  const _DeltaLabel({required this.ratio});

  final double ratio;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUp = ratio > 0;
    final percent = (ratio.abs() * 100).round();

    if (percent == 0) {
      return Text(
        'tetap',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.hintColor,
          fontSize: 11,
        ),
      );
    }

    return Semantics(
      label: isUp
          ? 'Pengeluaran naik $percent persen dari periode sebelumnya'
          : 'Pengeluaran turun $percent persen dari periode sebelumnya',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: 12,
            color: isUp ? AppTheme.expenseRed : AppTheme.incomeGreen,
          ),
          Text(
            '$percent%',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: isUp ? AppTheme.expenseRed : AppTheme.incomeGreen,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
