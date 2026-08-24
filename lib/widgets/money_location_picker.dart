import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../providers/transaction_provider.dart';
import '../screens/money_location_form_screen.dart';
import '../utils/icon_picker_utils.dart';
import 'animated_bouncing_card.dart';

/// Hasil pemilihan lokasi.
///
/// Dibungkus objek supaya "menutup sheet tanpa memilih" bisa dibedakan dari
/// "sengaja memilih tanpa lokasi" — dua-duanya bernilai null kalau yang
/// dikembalikan cuma `int?`, dan pilihan pengguna jadi ikut terhapus tiap
/// kali sheet-nya di-swipe turun.
class MoneyLocationChoice {
  const MoneyLocationChoice(this.locationId);

  /// Null berarti pengguna memilih "Tanpa lokasi".
  final int? locationId;
}

final NumberFormat _currency = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);

/// Membuka pemilih lokasi uang.
///
/// Mengembalikan null kalau sheet ditutup tanpa memilih.
Future<MoneyLocationChoice?> showMoneyLocationPicker({
  required BuildContext context,
  required int? selectedId,
  required String title,
  required String noneSubtitle,
}) {
  return showModalBottomSheet<MoneyLocationChoice>(
    context: context,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (sheetContext) => _MoneyLocationSheet(
      selectedId: selectedId,
      title: title,
      noneSubtitle: noneSubtitle,
    ),
  );
}

class _MoneyLocationSheet extends StatelessWidget {
  const _MoneyLocationSheet({
    required this.selectedId,
    required this.title,
    required this.noneSubtitle,
  });

  final int? selectedId;
  final String title;
  final String noneSubtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Sheet-nya ikut mendengarkan provider supaya lokasi yang baru dibuat
    // lewat pintasan di bawah langsung muncul, tanpa perlu tutup-buka lagi.
    return Consumer<TransactionProvider>(
      builder: (context, provider, _) {
        final summaries = provider.moneyLocationSummaries;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                _SheetItem(
                  title: 'Tanpa lokasi',
                  subtitle: noneSubtitle,
                  icon: LucideIcons.circleHelp,
                  selected: selectedId == null,
                  onTap: () => Navigator.pop(
                    context,
                    const MoneyLocationChoice(null),
                  ),
                ),
                const SizedBox(height: 4),
                Flexible(
                  child: summaries.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          child: Center(
                            child: Text(
                              'Belum ada lokasi uang.',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: summaries.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 4),
                          itemBuilder: (context, index) {
                            final summary = summaries[index];
                            final id = summary.id;
                            if (id == null) return const SizedBox.shrink();

                            return _SheetItem(
                              title: summary.name,
                              subtitle:
                                  'Sisa ${_currency.format(summary.balance)}',
                              icon: IconPickerUtils.getLucideIcon(summary.icon),
                              selected: selectedId == id,
                              onTap: () => Navigator.pop(
                                context,
                                MoneyLocationChoice(id),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MoneyLocationFormScreen(),
                    ),
                  ),
                  icon: const Icon(LucideIcons.plus, size: 18),
                  label: const Text('Tambah lokasi baru'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SheetItem extends StatelessWidget {
  const _SheetItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = selected
        ? theme.colorScheme.onPrimaryContainer
        : theme.textTheme.bodyMedium?.color;

    return Semantics(
      selected: selected,
      button: true,
      child: AnimatedBouncingCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        color: selected
            ? theme.colorScheme.primaryContainer
            : theme.cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: foreground),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: foreground,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: foreground?.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Centang, bukan cuma warna latar — supaya pilihan aktif tetap
            // terbaca tanpa mengandalkan kemampuan membedakan warna.
            if (selected)
              Icon(Icons.check_circle_rounded, color: foreground, size: 18),
          ],
        ),
      ),
    );
  }
}
