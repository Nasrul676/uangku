import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/book_period.dart';
import '../../theme/app_theme.dart';
import '../app_card.dart';
import 'dashboard_buttons.dart';

class BookPeriodCard extends StatelessWidget {
  const BookPeriodCard({
    super.key,
    required this.periods,
    required this.selectedPeriodId,
    required this.activePeriodId,
    required this.onSelectPeriod,
    required this.onOpenBook,
    required this.onCloseActiveBook,
    required this.onReopenBook,
    required this.onDeleteBook,
    required this.onHideCard,
  });

  final List<BookPeriod> periods;
  final int? selectedPeriodId;
  final int? activePeriodId;
  final ValueChanged<int?> onSelectPeriod;
  final Future<bool> Function() onOpenBook;
  final Future<void> Function()? onCloseActiveBook;
  final Future<void> Function(BookPeriod period) onReopenBook;
  final Future<void> Function(BookPeriod period) onDeleteBook;
  final VoidCallback onHideCard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    BookPeriod? selectedPeriod;
    for (final period in periods) {
      if (period.id == selectedPeriodId) {
        selectedPeriod = period;
        break;
      }
    }

    return AppCard(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Buku Pengeluaran',
                    style: theme.textTheme.titleMedium?.copyWith(fontSize: 20),
                  ),
                ),
                CircleIconButton(
                  icon: Icons.visibility_off_rounded,
                  onTap: onHideCard,
                ),
              ],
            ),
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: periods.isEmpty
                  ? null
                  : () => _openPeriodPicker(context, selectedPeriodId),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color ?? Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Theme.of(
                    context,
                  ).extension<AppThemeExtension>()?.cardBorder,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color:
                            Theme.of(context).cardTheme.color ?? Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                              (Theme.of(context)
                                  .extension<AppThemeExtension>()
                                  ?.cardBorder
                                  ?.top
                                  .color ??
                              const Color(0xFF2D2D2D)),
                          width: 1,
                        ),
                      ),
                      child: const Icon(Icons.menu_book_rounded, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedLabel(selectedPeriod),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            _selectedSubLabel(selectedPeriod),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      periods.isEmpty
                          ? Icons.lock_outline_rounded
                          : Icons.expand_more_rounded,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: selectedPeriod == null
                        ? Theme.of(context).colorScheme.surface
                        : selectedPeriod.closed
                        ? Theme.of(context).colorScheme.secondaryContainer
                        : const Color(0xFFA4DBB2),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color:
                          (Theme.of(context)
                              .extension<AppThemeExtension>()
                              ?.cardBorder
                              ?.top
                              .color ??
                          const Color(0xFF2D2D2D)),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    selectedPeriod == null
                        ? 'Semua Buku'
                        : selectedPeriod.closed
                        ? 'Buku Ditutup'
                        : 'Buku Aktif',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    periods.isEmpty
                        ? 'Belum ada buku. Buka buku pertama untuk mulai mencatat transaksi.'
                        : 'Tap kartu untuk ganti periode buku.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ActionButton(
                    label: 'Buka Buku',
                    icon: Icons.menu_book_rounded,
                    background:
                        Theme.of(context).cardTheme.color ?? Colors.white,
                    iconBackground: const Color(0xFFF5BB8A),
                    onTap: () {
                      onOpenBook();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ActionButton(
                    label: 'Tutup Buku',
                    icon: Icons.bookmark_remove_rounded,
                    background: activePeriodId == null
                        ? Theme.of(context).colorScheme.surface
                        : const Color(0xFFD4BEF2),
                    iconBackground: const Color(0xFFF5BB8A),
                    labelColor: activePeriodId == null
                        ? null
                        : const Color(0xFF111111),
                    iconColor: activePeriodId == null
                        ? null
                        : const Color(0xFF111111),
                    onTap: onCloseActiveBook ?? () {},
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (selectedPeriod != null && selectedPeriod.closed) ...[
              SizedBox(
                width: double.infinity,
                child: ActionButton(
                  label: 'Buka Ulang Buku',
                  icon: Icons.lock_open_rounded,
                  background: const Color(0xFFD4BEF2),
                  iconBackground: const Color(0xFFF5BB8A),
                  labelColor: const Color(0xFF111111),
                  iconColor: const Color(0xFF111111),
                  onTap: () {
                    onReopenBook(selectedPeriod!);
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (selectedPeriod != null && selectedPeriod.closed) ...[
              SizedBox(
                width: double.infinity,
                child: ActionButton(
                  label: 'Hapus Buku',
                  icon: Icons.delete_outline_rounded,
                  background: const Color(0xFFC24545),
                  iconBackground: const Color(0xFFF0C8C8),
                  labelColor: Colors.white,
                  iconColor: Colors.white,
                  onTap: () {
                    onDeleteBook(selectedPeriod!);
                  },
                ),
              ),
            ],
          ],
        ),
    );
  }

  String _buildPeriodLabel(BookPeriod period) {
    final start = DateTime.tryParse(period.startDate);
    final end = period.endDate == null
        ? null
        : DateTime.tryParse(period.endDate!);

    final formatter = DateFormat('dd MMM yyyy', 'id');
    final startText = start == null
        ? period.startDate
        : formatter.format(start);
    final endText = end == null ? 'Sekarang' : formatter.format(end);
    final statusText = period.closed ? 'Tutup' : 'Aktif';

    return '${period.label} ($startText - $endText) • $statusText';
  }

  String _selectedLabel(BookPeriod? period) {
    if (period == null) return 'Semua Buku';
    return period.label;
  }

  String _selectedSubLabel(BookPeriod? period) {
    if (period == null) return 'Belum ada periode buku dipilih.';

    final start = DateTime.tryParse(period.startDate);
    final end = period.endDate == null
        ? null
        : DateTime.tryParse(period.endDate!);

    final formatter = DateFormat('dd MMM yyyy', 'id');
    final startText = start == null
        ? period.startDate
        : formatter.format(start);
    final endText = end == null ? 'Sekarang' : formatter.format(end);
    return '$startText - $endText';
  }

  Future<void> _openPeriodPicker(BuildContext context, int? currentId) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Pilih Periode Buku',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: periods.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final period = periods[index];
                      final periodId = period.id;
                      return PeriodPickerItem(
                        label: period.label,
                        subtitle: _buildPeriodLabel(period),
                        selected: period.id == currentId,
                        onTap: () {
                          onSelectPeriod(period.id);
                          Navigator.pop(context);
                        },
                        onDelete: periodId == null
                            ? null
                            : period.isOpen
                            ? null
                            : () {
                                Navigator.pop(context);
                                onDeleteBook(period);
                              },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class BookPeriodCollapsedBar extends StatelessWidget {
  const BookPeriodCollapsedBar({
    super.key,
    required this.activeBook,
    required this.onShowCard,
  });

  final BookPeriod? activeBook;
  final VoidCallback onShowCard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color ?? Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Theme.of(
                  context,
                ).extension<AppThemeExtension>()?.cardBorder,
              ),
              child: const Icon(Icons.menu_book_rounded, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Buku Pengeluaran Disembunyikan',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    activeBook == null
                        ? 'Tidak ada buku aktif.'
                        : 'Buku aktif: ${activeBook!.label}',
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            CircleIconButton(
              icon: Icons.visibility_rounded,
              onTap: onShowCard,
            ),
          ],
        ),
    );
  }
}

class PeriodPickerItem extends StatelessWidget {
  const PeriodPickerItem({
    super.key,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.onDelete,
  });

  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.secondaryContainer
              : (Theme.of(context).cardTheme.color ?? Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Theme.of(context).extension<AppThemeExtension>()?.cardBorder,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? Theme.of(context).colorScheme.onSecondaryContainer
                          : Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF1F5A62),
                size: 18,
              ),
            if (onDelete != null) ...[
              const SizedBox(width: 6),
              InkWell(
                borderRadius: BorderRadius.circular(99),
                onTap: onDelete,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0C8C8),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color:
                          (Theme.of(context)
                              .extension<AppThemeExtension>()
                              ?.cardBorder
                              ?.top
                              .color ??
                          const Color(0xFF2D2D2D)),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    size: 16,
                    color: Color(0xFFC24545),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
