import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../utils/daily_budget.dart';
import '../../utils/rupiah_compact.dart';
import '../app_card.dart';

/// Batang jatah harian.
///
/// Satu-satunya elemen di beranda yang memberi alasan membuka aplikasi lebih
/// dari sekali sehari: batangnya terisi sepanjang hari, lalu kosong lagi besok
/// pagi.
///
/// Saat lewat batas batangnya berubah merah dan teksnya menyebut angka
/// lewatnya, bukan disembunyikan. Menutupi angka yang jelek justru membuat
/// orang berhenti mempercayai aplikasinya.
class DailyAllowanceCard extends StatelessWidget {
  const DailyAllowanceCard({super.key, required this.budget});

  final DailyBudget budget;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOver = budget.isOverToday;
    final isProjected = budget.horizon == BudgetHorizon.perkiraan;

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  // Dalam mode perkiraan tidak ada jatah yang benar-benar
                  // ditetapkan — yang ada cuma kebiasaan belanja sendiri, jadi
                  // labelnya tidak boleh berpura-pura jadi batas.
                  isProjected ? 'Rata-rata harianmu' : 'Jatah hari ini',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                isOver
                    ? 'lewat ${compactRupiah(-budget.remainingToday)}'
                    : '${compactRupiah(budget.remainingToday)} tersisa',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isOver ? AppTheme.expenseRed : AppTheme.incomeGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          _Track(ratio: budget.usedRatio, isOver: isOver),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Terpakai ${compactRupiah(budget.spentToday)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
              ),
              Text(
                'dari ${compactRupiah(budget.perDay)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Track extends StatelessWidget {
  const _Track({required this.ratio, required this.isOver});

  final double ratio;
  final bool isOver;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: isOver
          ? 'Jatah hari ini sudah terlampaui'
          : 'Jatah hari ini terpakai ${(ratio * 100).round()} persen',
      child: Container(
        height: 15,
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(99),
          // Garisnya ikut warna tinta tema. Hitam mati membuat batang ini
          // tidak terlihat sama sekali di mode gelap.
          border: Border.all(color: theme.colorScheme.onSurface, width: 2.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              // `usedRatio` sudah dijepit ke 0..1, jadi batangnya tidak pernah
              // meluber keluar bingkai walau pengeluaran jauh melewati jatah.
              widthFactor: ratio,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                color: isOver ? AppTheme.neoCoral : AppTheme.neoMint,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
