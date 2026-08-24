import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../models/finance_transaction.dart';
import '../../providers/transaction_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/category_icon.dart';
import '../../utils/relative_time.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/skeleton_loader.dart';
import '../app_card.dart';
import '../item_actions_menu.dart';
import '../../screens/income_input_screen.dart';
import '../../screens/expense_input_screen.dart';
import '../../utils/error_message.dart';

class TransactionsCard extends StatefulWidget {
  const TransactionsCard({
    super.key,
    required this.theme,
    required this.title,
    required this.transactions,
    required this.isLoading,
    required this.emptyText,
    this.moneyLocationNames = const {},
    this.titleColor,
  });

  final ThemeData theme;
  final String title;
  final List<FinanceTransaction> transactions;
  final bool isLoading;
  final String emptyText;

  /// Nama lokasi per id, dipakai untuk menambah keterangan "dari dompet mana"
  /// di tiap baris. Kosong berarti keterangannya tidak dirender.
  final Map<int, String> moneyLocationNames;
  final Color? titleColor;

  @override
  State<TransactionsCard> createState() => _TransactionsCardState();
}

class _TransactionsCardState extends State<TransactionsCard> {
  late final ScrollController _scrollController;
  final Set<int> _hiddenTransactions = {};
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    // Penghapusan yang masih menunggu jendela "Batalkan" harus tetap
    // dieksekusi walau kartu ini dilepas (pindah tab / tutup layar),
    // supaya transaksi tidak muncul lagi setelah user merasa menghapusnya.
    _flushPendingDeletions();
    _scrollController.dispose();
    super.dispose();
  }

  /// id transaksi yang sudah disembunyikan tapi belum dikomit ke database.
  final Map<int, _PendingDeletion> _pendingDeletions = {};

  /// Sembunyikan transaksi lebih dulu, beri jendela 2 detik untuk membatalkan,
  /// lalu komit penghapusan ke database.
  void _requestDelete(FinanceTransaction item) {
    final id = item.id;
    if (id == null || _pendingDeletions.containsKey(id)) return;

    final provider = context.read<TransactionProvider>();
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _hiddenTransactions.add(id));

    Future<void> commit() async {
      try {
        await provider.removeTransaction(id);
      } catch (e) {
        if (!mounted) return;
        setState(() => _hiddenTransactions.remove(id));
        messenger.showSnackBar(
          SnackBar(
            content: Text('Gagal menghapus: ${friendlyError(e)}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    void undo() {
      final pending = _pendingDeletions.remove(id);
      pending?.timer.cancel();
      if (!mounted) return;
      setState(() => _hiddenTransactions.remove(id));
    }

    final timer = Timer(const Duration(seconds: 2), () {
      if (_pendingDeletions.remove(id) == null) return;
      unawaited(commit());
    });

    _pendingDeletions[id] = _PendingDeletion(timer: timer, commit: commit);

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '"${item.title}" dihapus.',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(label: 'Batalkan', onPressed: undo),
      ),
    );
  }

  void _flushPendingDeletions() {
    if (_pendingDeletions.isEmpty) return;
    final pending = List<_PendingDeletion>.from(_pendingDeletions.values);
    _pendingDeletions.clear();
    for (final entry in pending) {
      entry.timer.cancel();
      // Sengaja tidak di-await: dispose bersifat sinkron. Kegagalan tidak
      // bisa lagi ditampilkan ke user karena widget-nya sudah hilang.
      unawaited(entry.commit());
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredTransactions = _searchQuery.isEmpty
        ? widget.transactions
        : widget.transactions
              .where(
                (t) =>
                    t.title.toLowerCase().contains(_searchQuery) ||
                    t.category.toLowerCase().contains(_searchQuery),
              )
              .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.title.isNotEmpty) ...[
            Row(
              children: [
                Text(
                  widget.title,
                  style: widget.theme.textTheme.headlineSmall?.copyWith(
                    color: widget.titleColor,
                  ),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 10),
          ],
          if (widget.transactions.isNotEmpty || _searchQuery.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: TextField(
                controller: TextEditingController.fromValue(
                  TextEditingValue(
                    text: _searchQuery,
                    selection: TextSelection.collapsed(
                      offset: _searchQuery.length,
                    ),
                  ),
                ),
                decoration: InputDecoration(
                  hintText: 'Cari transaksi...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          tooltip: 'Bersihkan pencarian',
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
              ),
            ),
          ],
          if (widget.isLoading)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: SkeletonLoader(itemCount: 5),
              ),
            )
          else if (filteredTransactions.isEmpty)
            Expanded(
              child: EmptyState(
                title: _searchQuery.isNotEmpty
                    ? 'Pencarian tidak ditemukan'
                    : 'Belum ada data',
                subtitle: _searchQuery.isNotEmpty
                    ? 'Coba gunakan kata kunci lain.'
                    : widget.emptyText,
              ),
            )
          else
            Expanded(
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                child: ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(bottom: 100),
                  primary: false,
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  itemCount: filteredTransactions.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = filteredTransactions[index];
                    if (_hiddenTransactions.contains(item.id)) {
                      return const SizedBox.shrink();
                    }
                    return TransactionTile(
                      item: item,
                      theme: widget.theme,
                      moneyLocationName:
                          widget.moneyLocationNames[item.moneyLocationId],
                      onRequestDelete: () => _requestDelete(item),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.item,
    required this.theme,
    this.moneyLocationName,
    this.onRequestDelete,
  });

  final FinanceTransaction item;
  final ThemeData theme;

  /// Null kalau transaksinya belum ditandai lokasinya — barisnya lalu dirender
  /// tanpa keterangan tambahan, bukan dengan tulisan "tanpa lokasi" yang cuma
  /// jadi kebisingan di daftar panjang.
  final String? moneyLocationName;

  /// Kalau null, tile dirender tanpa aksi geser (mode baca saja).
  final VoidCallback? onRequestDelete;

  @override
  Widget build(BuildContext context) {
    final isIncome = item.type == 'INCOME';
    final datetimeLabel = relativeTimeLabel(
      item.date,
      item.time,
      DateTime.now(),
    );
    final visual = visualForCategory(item.category, isIncome: isIncome);
    final rupiahFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final amountText =
        '${isIncome ? '+' : '-'}${rupiahFormatter.format(item.amount)}';

    Widget child = AppCard(
      isInteractive: true,
      onTap: () {
        // If you want tap to do something, add it here.
        // For now just for the bounce effect.
      },
      padding: const EdgeInsets.all(10),
      color: Theme.of(context).cardTheme.color ?? Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          // Ikon kategori berwarna membuat daftar bisa dipindai tanpa membaca
          // satu kata pun — mata mencari kotak kuning kalau ingin tahu
          // pengeluaran makan.
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: visual.color,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: AppTheme.borderColor, width: 2),
            ),
            child: Icon(visual.icon, size: 18, color: AppTheme.borderColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Warna dipakai hanya di nominal. Kalau judul dan keterangan
                // ikut merah, seluruh daftar jadi merah — dan warna yang
                // dipakai di mana-mana berhenti menandakan apa pun.
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  moneyLocationName == null
                      ? '${item.category} • $datetimeLabel'
                      : '${item.category} • $datetimeLabel • $moneyLocationName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amountText,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: isIncome ? AppTheme.incomeGreen : AppTheme.expenseRed,
                ),
              ),
              const SizedBox(height: 2),
              Icon(
                item.isSynced == 1
                    ? Icons.cloud_done_rounded
                    : Icons.cloud_off_rounded,
                size: 16,
                color: item.isSynced == 1
                    ? AppTheme.incomeGreen
                    : AppTheme.expenseRed,
                semanticLabel: item.isSynced == 1
                    ? 'Sudah tersinkron'
                    : 'Belum tersinkron',
              ),
            ],
          ),
          if (onRequestDelete != null)
            ItemActionsMenu(
              semanticLabel: 'Aksi untuk transaksi ${item.title}',
              actions: [
                ItemAction(
                  label: 'Edit',
                  icon: Icons.edit_rounded,
                  onSelected: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => isIncome
                          ? IncomeInputScreen(existingTransaction: item)
                          : ExpenseInputScreen(existingTransaction: item),
                    ),
                  ),
                ),
                ItemAction(
                  label: 'Hapus',
                  icon: Icons.delete_rounded,
                  onSelected: onRequestDelete!,
                  isDestructive: true,
                ),
              ],
            ),
        ],
      ),
    );

    final requestDelete = onRequestDelete;
    if (requestDelete == null) {
      return child;
    }

    return Slidable(
      key: ValueKey(item.id),
      startActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (context) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => isIncome
                      ? IncomeInputScreen(existingTransaction: item)
                      : ExpenseInputScreen(existingTransaction: item),
                ),
              );
            },
            backgroundColor: const Color(0xFF6CC185),
            foregroundColor: Colors.white,
            icon: Icons.edit_rounded,
            label: 'Edit',
            borderRadius: BorderRadius.circular(12),
          ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => requestDelete(),
            backgroundColor: AppTheme.expenseRed,
            foregroundColor: Colors.white,
            icon: Icons.delete_rounded,
            label: 'Hapus',
            borderRadius: BorderRadius.circular(12),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Penghapusan transaksi yang menunggu jendela "Batalkan" selesai.
class _PendingDeletion {
  const _PendingDeletion({required this.timer, required this.commit});

  final Timer timer;
  final Future<void> Function() commit;
}
