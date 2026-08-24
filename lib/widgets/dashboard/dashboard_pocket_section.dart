import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../providers/transaction_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/icon_picker_utils.dart';
import '../../utils/rupiah_compact.dart';
import '../../screens/pocket_form_screen.dart';
import '../../screens/pocket_detail_screen.dart';
import '../app_card.dart';
import '../entrance_animation.dart';

class DashboardPocketSection extends StatelessWidget {
  final TransactionProvider provider;

  const DashboardPocketSection({super.key, required this.provider});

  /// Warna batang isi, sejajar indeksnya dengan [_cardColors] supaya kartu dan
  /// batangnya tetap terbaca sebagai satu kesatuan. Pastel kartunya sendiri
  /// terlalu pucat untuk dipakai sebagai batang.
  static const List<Color> _accentColors = [
    AppTheme.neoYellow,
    AppTheme.neoMint,
    AppTheme.incomeLight,
    AppTheme.neoBlue,
    AppTheme.neoBlue,
    AppTheme.neoLavender,
    AppTheme.neoCoral,
    AppTheme.fabBgColor,
  ];

  static const List<Color> _cardColors = [
    Color(0xFFFFF9E6), // Soft Yellow
    Color(0xFFF0F4C3), // Soft Lime
    Color(0xFFE8F5E9), // Soft Green
    Color(0xFFE0F7FA), // Soft Cyan
    Color(0xFFE3F2FD), // Soft Blue
    Color(0xFFF3E5F5), // Soft Purple
    Color(0xFFFFEBEE), // Soft Red
    Color(0xFFFFF3E0), // Soft Orange
  ];

  @override
  Widget build(BuildContext context) {
    final pockets = provider.pockets;

    final NumberFormat currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EntranceAnimation(
          type: EntranceType.fadeScale,
          delay: const Duration(milliseconds: 300),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Kantong Kamu',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemCount: pockets.length + 1,
          itemBuilder: (context, index) {
            final animationDelay = 350 + (index * 100);

            if (index == pockets.length) {
              return EntranceAnimation(
                type: EntranceType.fadeScale,
                delay: Duration(milliseconds: animationDelay),
                child: AppCard(
                  color: const Color(0xFFFDF0FC), // Light purple
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.purple.shade50),
                  margin: EdgeInsets.zero,
                  isInteractive: true,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PocketFormScreen(),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: const BoxDecoration(
                            color: Color(0xFF6B3076), // Dark purple circle
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Buat Kantong',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111111),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            final pocket = pockets[index];
            final effectiveBalance = provider.getPocketEffectiveBalance(
              pocket.id!,
            );
            final isNegative = effectiveBalance < 0;
            final cardColor = _cardColors[index % _cardColors.length];

            return EntranceAnimation(
              type: EntranceType.fadeScale,
              delay: Duration(milliseconds: animationDelay),
              child: AppCard(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                margin: EdgeInsets.zero,
                isInteractive: true,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          PocketDetailScreen(pocketId: pocket.id!),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: _accentColors[index % _accentColors.length],
                          borderRadius: BorderRadius.circular(13),
                          // Kartu kantong selalu berlatar pastel terang, juga
                          // di mode gelap, jadi garisnya memang harus gelap.
                          border: Border.all(
                            color: AppTheme.borderColor,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          IconPickerUtils.getLucideIcon(pocket.icon),
                          size: 22,
                          color: AppTheme.borderColor,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        pocket.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111111),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        currencyFormatter.format(effectiveBalance),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: isNegative
                              ? const Color(0xFFE53935)
                              : const Color(0xFF111111),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      _PocketFill(
                        balance: effectiveBalance,
                        target: pocket.allocationType == 'PERCENTAGE'
                            ? null
                            : pocket.allocationValue,
                        percentOfIncome: pocket.allocationType == 'PERCENTAGE'
                            ? pocket.allocationValue
                            : null,
                        accent: _accentColors[index % _accentColors.length],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Batang isi kantong.
///
/// Sekali lihat langsung ketahuan mana yang hampir penuh — sebelumnya
/// informasi itu cuma teks "Target: Rp 5.000.000" yang harus dibandingkan
/// sendiri dengan saldonya.
class _PocketFill extends StatelessWidget {
  const _PocketFill({
    required this.balance,
    required this.target,
    required this.percentOfIncome,
    required this.accent,
  });

  final double balance;

  /// Null untuk kantong beralokasi persentase — kantong seperti itu tidak
  /// punya garis akhir, jadi tidak ada yang bisa dijadikan batang.
  final double? target;
  final double? percentOfIncome;
  final Color accent;

  /// Kartu kantong berlatar pastel terang di kedua mode tema, jadi warna
  /// teksnya tidak boleh ikut tema. `theme.hintColor` di mode gelap berwarna
  /// abu terang dan hilang sama sekali di atas pastel.
  static const _mutedOnPastel = Color(0xFF6B6B6B);

  @override
  Widget build(BuildContext context) {
    final goal = target;

    if (goal == null || goal <= 0) {
      return Text(
        percentOfIncome == null
            ? 'Tanpa target'
            : '${percentOfIncome!.toInt()}% dari pemasukan',
        style: const TextStyle(fontSize: 10, color: _mutedOnPastel),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final ratio = (balance / goal).clamp(0.0, 1.0);
    final percent = (ratio * 100).round();
    final nearlyFull = ratio >= 0.9;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: 'Terisi $percent persen dari target',
          child: Container(
            height: 9,
            decoration: BoxDecoration(
              color: AppTheme.neoPaper,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: AppTheme.borderColor, width: 1.6),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: ratio,
                  child: Container(color: accent),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          // Dorongan kecil untuk kantong yang tinggal sedikit lagi — inilah
          // bedanya alat pencatat dengan alat yang bikin semangat menabung.
          nearlyFull
              ? '$percent% — dikit lagi!'
              : '$percent% dari ${compactRupiah(goal)}',
          style: TextStyle(
            fontSize: 10,
            fontWeight: nearlyFull ? FontWeight.w800 : FontWeight.w400,
            color: nearlyFull ? AppTheme.incomeGreen : _mutedOnPastel,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
