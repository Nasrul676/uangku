import 'package:flutter/material.dart';

/// Satu aksi pada sebuah kartu daftar (rencana, buku, transaksi, dsb).
class ItemAction {
  const ItemAction({
    required this.label,
    required this.icon,
    required this.onSelected,
    this.isDestructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onSelected;

  /// Aksi merusak dirender merah dan diletakkan paling bawah.
  final bool isDestructive;
}

/// Tombol titik-tiga yang membuka daftar aksi.
///
/// Alasan keberadaannya: aksi-aksi ini juga tersedia lewat geser (`Slidable`),
/// tapi gestur geser tidak punya petunjuk visual — pengguna tidak tahu aksinya
/// ada. Tombol ini menjadikan aksi yang sama bisa ditemukan tanpa menebak,
/// sekaligus membuatnya terjangkau oleh pembaca layar.
class ItemActionsMenu extends StatelessWidget {
  const ItemActionsMenu({
    super.key,
    required this.actions,
    this.semanticLabel = 'Aksi lainnya',
    this.iconSize = 20,
  });

  final List<ItemAction> actions;
  final String semanticLabel;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final ordered = [
      ...actions.where((a) => !a.isDestructive),
      ...actions.where((a) => a.isDestructive),
    ];

    return PopupMenuButton<ItemAction>(
      tooltip: semanticLabel,
      icon: Icon(Icons.more_vert_rounded, size: iconSize),
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (action) => action.onSelected(),
      itemBuilder: (context) => [
        for (final action in ordered)
          PopupMenuItem<ItemAction>(
            value: action,
            child: Row(
              children: [
                Icon(
                  action.icon,
                  size: 18,
                  color: action.isDestructive ? theme.colorScheme.error : null,
                ),
                const SizedBox(width: 12),
                Text(
                  action.label,
                  style: TextStyle(
                    color: action.isDestructive
                        ? theme.colorScheme.error
                        : null,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
