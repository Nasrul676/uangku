import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/book_period.dart';
import '../../theme/app_theme.dart';

/// Sapaan sesuai waktu setempat.
///
/// Dipisah dari widget supaya bisa diuji tanpa menunggu jam dinding berubah.
String greetingFor(DateTime time) {
  final hour = time.hour;
  if (hour < 11) return 'Selamat pagi';
  if (hour < 15) return 'Selamat siang';
  if (hour < 19) return 'Selamat sore';
  return 'Selamat malam';
}

/// Baris pembuka beranda: tanggal dan buku yang sedang aktif.
///
/// Sapaannya sendiri ada di bar atas layar, yang memang sudah menyebut nama
/// pengguna — mengulangnya di sini membuat dua sapaan bertumpuk.
///
/// Chip buku ada di sini karena sebelumnya beranda sama sekali tidak
/// menyebutkan angka di bawahnya milik periode yang mana.
class GreetingHeader extends StatelessWidget {
  const GreetingHeader({
    super.key,
    required this.now,
    this.activeBook,
    this.inkColor,
  });

  final DateTime now;
  final BookPeriod? activeBook;

  /// Warna tinta saat baris ini duduk di atas permukaan mint kartu saldo,
  /// yang selalu terang di mode gelap maupun terang. Tanpa ini teksnya ikut
  /// warna tema — putih di mode gelap, yang di atas mint praktis tak terbaca.
  ///
  /// Null berarti "ikut tema", untuk pemakaian di atas latar biasa.
  final Color? inkColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final book = activeBook;
    final ink = inkColor;

    // Jaraknya diatur pemanggil: sekarang baris ini duduk di dalam kartu
    // saldo, yang sudah punya paddingnya sendiri.
    return Row(
      children: [
        Expanded(
          child: Text(
            DateFormat('EEEE, d MMMM', 'id').format(now),
            style: theme.textTheme.bodySmall?.copyWith(
              color: ink?.withValues(alpha: 0.72) ?? theme.hintColor,
            ),
          ),
        ),
        if (book != null)
          Flexible(
            child: _BookChip(book: book, inkColor: ink),
          ),
      ],
    );
  }
}

class _BookChip extends StatelessWidget {
  const _BookChip({required this.book, this.inkColor});

  final BookPeriod book;
  final Color? inkColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOpen = book.isOpen;
    final ink = inkColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
      decoration: BoxDecoration(
        // Di atas mint, kartu gelap mode malam justru menabrak. Kertas terang
        // memberi bidang netral untuk tinta gelapnya.
        color: ink == null ? theme.cardTheme.color : AppTheme.neoPaper,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: ink ?? theme.colorScheme.onSurface, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOpen ? LucideIcons.bookOpen : LucideIcons.bookLock,
            size: 13,
            color: isOpen ? AppTheme.incomeGreen : theme.hintColor,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              book.label,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: ink,
              ),
            ),
          ),
          Text(
            isOpen ? ' · aktif' : ' · selesai',
            style: theme.textTheme.labelSmall?.copyWith(
              color: ink?.withValues(alpha: 0.7) ?? theme.hintColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
