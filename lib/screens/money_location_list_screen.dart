import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/money_location.dart';
import '../models/money_transfer.dart';
import '../providers/transaction_provider.dart';
import '../theme/app_theme.dart';
import '../utils/icon_picker_utils.dart';
import '../utils/money_location_balance.dart';
import '../widgets/app_card.dart';
import 'money_location_form_screen.dart';
import 'money_transfer_screen.dart';

/// Daftar tempat uang disimpan beserta saldo terkininya.
///
/// Dibuat sebagai daftar vertikal, bukan grid seperti kantong: yang dicari
/// pengguna di sini adalah kolom angka yang bisa disapu ke bawah — "di dompet
/// tinggal berapa" — dan grid dua kolom memaksa mata zig-zag untuk itu.
class MoneyLocationListScreen extends StatelessWidget {
  const MoneyLocationListScreen({super.key});

  static final NumberFormat _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Lokasi Uangmu',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: theme.iconTheme,
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Berlabel, bukan ikon telanjang: "dua panah berlawanan" bisa
          // berarti tukar, sinkron, atau ulangi — tooltip tidak menolong di
          // layar sentuh karena tidak ada kursor untuk menggantung di atasnya.
          FloatingActionButton.extended(
            heroTag: 'pindah-uang',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MoneyTransferScreen()),
            ),
            backgroundColor: theme.colorScheme.secondaryContainer,
            foregroundColor: theme.colorScheme.onSecondaryContainer,
            elevation: 1,
            icon: const Icon(LucideIcons.arrowLeftRight, size: 18),
            label: const Text('Pindah Uang'),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'tambah-lokasi',
            onPressed: () => _openForm(context),
            backgroundColor: AppTheme.primaryBlue,
            foregroundColor: Colors.white,
            icon: const Icon(LucideIcons.plus),
            label: const Text('Tambah Lokasi'),
          ),
        ],
      ),
      body: Consumer<TransactionProvider>(
        builder: (context, provider, _) {
          final summaries = provider.moneyLocationSummaries;
          final unassigned = provider.unassignedMoneyBalance;

          if (summaries.isEmpty) {
            return _EmptyState(onCreate: () => _openForm(context));
          }

          final total = summaries.fold<double>(
            0,
            (sum, item) => sum + item.balance,
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 96),
            children: [
              _TotalCard(total: total, count: summaries.length),
              const SizedBox(height: 4),
              for (final summary in summaries)
                _LocationTile(
                  summary: summary,
                  onEdit: () => _openForm(context, location: summary.location),
                  onDelete: () => _confirmDelete(context, summary.location),
                ),
              if (unassigned != 0) ...[
                const SizedBox(height: 4),
                _UnassignedNote(amount: unassigned),
              ],
              _TransferHistory(
                transfers: provider.moneyTransfers,
                nameById: provider.moneyLocationNames,
                onDelete: (transfer) => _confirmDeleteTransfer(
                  context,
                  transfer,
                  provider.moneyLocationNames,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static Future<void> _openForm(
    BuildContext context, {
    MoneyLocation? location,
  }) {
    return Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MoneyLocationFormScreen(location: location),
      ),
    );
  }

  /// Konfirmasinya menyebut jumlah transaksi terdampak, bukan sekadar "yakin?"
  /// — angka itulah yang membuat pengguna sadar hapusnya menyentuh riwayat,
  /// bukan cuma satu baris di daftar ini.
  static Future<void> _confirmDelete(
    BuildContext context,
    MoneyLocation location,
  ) async {
    final id = location.id;
    if (id == null) return;

    final provider = context.read<TransactionProvider>();
    final affected = await provider.countTransactionsInMoneyLocation(id);
    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Hapus ${location.name}?'),
        content: Text(
          affected == 0
              ? 'Belum ada transaksi yang memakai lokasi ini.'
              : '$affected transaksi memakai lokasi ini. Transaksinya tetap '
                    'tersimpan, hanya keterangan lokasinya yang hilang.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await provider.deleteMoneyLocation(id);
  }

  /// Menghapus perpindahan mengembalikan saldo kedua lokasi seperti semula —
  /// disebutkan di dialognya supaya jelas ini bukan menghapus pengeluaran.
  static Future<void> _confirmDeleteTransfer(
    BuildContext context,
    MoneyTransfer transfer,
    Map<int, String> nameById,
  ) async {
    final id = transfer.id;
    if (id == null) return;

    final provider = context.read<TransactionProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus perpindahan ini?'),
        content: Text(
          'Saldo ${_labelFor(transfer.fromLocationId, nameById)} dan '
          '${_labelFor(transfer.toLocationId, nameById)} akan kembali seperti '
          'sebelum perpindahan dicatat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await provider.deleteMoneyTransfer(id);
  }

  static String _labelFor(int? locationId, Map<int, String> nameById) {
    if (locationId == null) return '(lokasi dihapus)';
    return nameById[locationId] ?? '(lokasi dihapus)';
  }
}

/// Daftar perpindahan terakhir.
///
/// Perpindahan tidak muncul di "Transaksi Terbaru" — memang bukan transaksi —
/// jadi tanpa daftar ini pengguna tidak punya cara menjawab "kok saldo
/// dompetku naik?", apalagi membatalkan salah ketik.
class _TransferHistory extends StatelessWidget {
  const _TransferHistory({
    required this.transfers,
    required this.nameById,
    required this.onDelete,
  });

  final List<MoneyTransfer> transfers;
  final Map<int, String> nameById;
  final ValueChanged<MoneyTransfer> onDelete;

  /// Cukup beberapa yang terakhir — ini catatan pendukung, bukan buku besar.
  static const _maxShown = 10;

  @override
  Widget build(BuildContext context) {
    if (transfers.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final shown = transfers.take(_maxShown).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'PERPINDAHAN TERAKHIR',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: theme.textTheme.bodySmall?.color,
            ),
          ),
        ),
        const SizedBox(height: 4),
        for (final transfer in shown)
          _TransferTile(
            transfer: transfer,
            nameById: nameById,
            onDelete: () => onDelete(transfer),
          ),
        if (transfers.length > _maxShown)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
            child: Text(
              '+${transfers.length - _maxShown} perpindahan lebih lama',
              style: theme.textTheme.labelSmall,
            ),
          ),
      ],
    );
  }
}

class _TransferTile extends StatelessWidget {
  const _TransferTile({
    required this.transfer,
    required this.nameById,
    required this.onDelete,
  });

  final MoneyTransfer transfer;
  final Map<int, String> nameById;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final from = MoneyLocationListScreen._labelFor(
      transfer.fromLocationId,
      nameById,
    );
    final to = MoneyLocationListScreen._labelFor(
      transfer.toLocationId,
      nameById,
    );

    final parsedDate = DateTime.tryParse(transfer.date);
    final dateLabel = parsedDate == null
        ? transfer.date
        : DateFormat('d MMM', 'id').format(parsedDate);

    return Slidable(
      key: ValueKey('transfer-${transfer.id}'),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: AppTheme.expenseRed,
            foregroundColor: Colors.white,
            icon: Icons.delete_rounded,
            label: 'Hapus',
            borderRadius: BorderRadius.circular(12),
          ),
        ],
      ),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Icon(
              LucideIcons.arrowLeftRight,
              size: 18,
              color: theme.textTheme.bodySmall?.color,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$from → $to',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    transfer.note == null
                        ? dateLabel
                        : '$dateLabel · ${transfer.note}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Tanpa tanda + atau −: uangnya tidak bertambah dan tidak
            // berkurang, cuma pindah tempat.
            Text(
              MoneyLocationListScreen._currency.format(transfer.amount),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.total, required this.count});

  final double total;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      color: AppTheme.neoMint,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TOTAL DI SEMUA LOKASI',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: AppTheme.borderColor.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            MoneyLocationListScreen._currency.format(total),
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              color: AppTheme.borderColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Tersebar di $count lokasi',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.borderColor.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationTile extends StatelessWidget {
  const _LocationTile({
    required this.summary,
    required this.onEdit,
    required this.onDelete,
  });

  final MoneyLocationSummary summary;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNegative = summary.balance < 0;
    final amountText = MoneyLocationListScreen._currency.format(summary.balance);

    return Slidable(
      key: ValueKey(summary.id),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => onEdit(),
            backgroundColor: AppTheme.primaryBlue,
            foregroundColor: Colors.white,
            icon: Icons.edit_rounded,
            label: 'Ubah',
            borderRadius: BorderRadius.circular(12),
          ),
          SlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: AppTheme.expenseRed,
            foregroundColor: Colors.white,
            icon: Icons.delete_rounded,
            label: 'Hapus',
            borderRadius: BorderRadius.circular(12),
          ),
        ],
      ),
      child: AppCard(
        isInteractive: true,
        onTap: onEdit,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                IconPickerUtils.getLucideIcon(summary.icon),
                size: 22,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    summary.name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (summary.location.initialBalance > 0)
                    Text(
                      'Saldo awal ${MoneyLocationListScreen._currency.format(summary.location.initialBalance)}',
                      style: theme.textTheme.labelSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Angka minus tidak cuma diwarnai merah — tandanya ikut ditulis,
            // supaya tetap terbaca oleh mata yang sulit membedakan warna.
            Text(
              amountText,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: isNegative
                    ? theme.colorScheme.error
                    : theme.textTheme.bodyLarge?.color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnassignedNote extends StatelessWidget {
  const _UnassignedNote({required this.amount});

  final double amount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(
            LucideIcons.circleHelp,
            size: 20,
            color: theme.textTheme.bodySmall?.color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Belum ditentukan',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Transaksi yang belum ditandai lokasinya',
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            MoneyLocationListScreen._currency.format(amount),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.textTheme.bodySmall?.color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.wallet,
              size: 48,
              color: theme.textTheme.bodySmall?.color,
            ),
            const SizedBox(height: 16),
            Text(
              'Belum ada lokasi uang',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tandai di mana uangmu disimpan — dompet, rekening, atau '
              'e-wallet — supaya sisa saldonya bisa dilihat terpisah.',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onCreate,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(LucideIcons.plus, size: 18),
              label: const Text('Tambah Lokasi'),
            ),
          ],
        ),
      ),
    );
  }
}
