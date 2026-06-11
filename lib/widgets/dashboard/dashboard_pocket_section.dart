import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../providers/transaction_provider.dart';
import '../../utils/icon_picker_utils.dart';
import '../../screens/pocket_form_screen.dart';
import '../../screens/pocket_detail_screen.dart';
import '../app_card.dart';
import '../entrance_animation.dart';

class DashboardPocketSection extends StatelessWidget {
  final TransactionProvider provider;

  const DashboardPocketSection({super.key, required this.provider});

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
              ));
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
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: const Color(0xFFE5F0FF),
                      child: Text(
                        IconPickerUtils.getIcon(pocket.icon),
                        style: const TextStyle(fontSize: 32),
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
                    const SizedBox(height: 2),
                    Text(
                      pocket.allocationType == 'PERCENTAGE'
                          ? '${pocket.allocationValue.toInt()}% Pemasukan'
                          : 'Target: ${currencyFormatter.format(pocket.allocationValue)}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF666666),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ));
          },
        ),
      ],
    );
  }
}
