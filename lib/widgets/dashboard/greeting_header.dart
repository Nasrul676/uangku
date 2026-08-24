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
  const GreetingHeader({super.key, required this.now, this.activeBook});

  final DateTime now;
  final BookPeriod? activeBook;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final book = activeBook;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              DateFormat('EEEE, d MMMM', 'id').format(now),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
          ),
          if (book != null) Flexible(child: _BookChip(book: book)),
        ],
      ),
    );
  }
}

class _BookChip extends StatelessWidget {
  const _BookChip({required this.book});

  final BookPeriod book;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOpen = book.isOpen;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: theme.colorScheme.onSurface, width: 2),
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
              ),
            ),
          ),
          Text(
            isOpen ? ' · aktif' : ' · selesai',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.hintColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
