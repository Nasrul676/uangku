import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/transaction_provider.dart';
import 'pocket_form_screen.dart';
import 'pocket_detail_screen.dart';
import '../utils/icon_picker_utils.dart'; // We'll create this to map string icons

class PocketListScreen extends StatelessWidget {
  const PocketListScreen({super.key});

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
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Kantong Kamu',
          style: TextStyle(
            color: Color(0xFF111111),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF111111)),
      ),
      body: Consumer<TransactionProvider>(
        builder: (context, provider, child) {
          final pockets = provider.pockets;
          
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemCount: pockets.length + 1,
            itemBuilder: (context, index) {
              if (index == pockets.length) {
                return _buildCreatePocketCard(context);
              }

              final pocket = pockets[index];
              final effectiveBalance = provider.getPocketEffectiveBalance(pocket.id!);
              final isNegative = effectiveBalance < 0;
              
              final NumberFormat currencyFormatter = NumberFormat.currency(
                locale: 'id_ID',
                symbol: 'Rp ',
                decimalDigits: 0,
              );

              final cardColor = _cardColors[index % _cardColors.length];

              return Card(
                elevation: 0,
                color: cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                margin: EdgeInsets.zero,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PocketDetailScreen(pocketId: pocket.id!),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: const Color(0xFFE5F0FF),
                          child: Icon(
                            IconPickerUtils.getIconData(pocket.icon),
                            color: const Color(0xFF0066FF),
                            size: 32,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          pocket.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111111),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currencyFormatter.format(effectiveBalance),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: isNegative ? const Color(0xFFE53935) : const Color(0xFF111111),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          pocket.allocationType == 'PERCENTAGE'
                              ? '${pocket.allocationValue.toInt()}% Pemasukan'
                              : 'Target: ${currencyFormatter.format(pocket.allocationValue)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF666666),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCreatePocketCard(BuildContext context) {
    return Card(
      elevation: 0,
      color: const Color(0xFFFDF0FC), // Light purple background like Jago
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.purple.shade50),
      ),
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const PocketFormScreen(),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const CircleAvatar(
                radius: 32,
                backgroundColor: Color(0xFF6B3076), // Dark purple circle
                child: Icon(
                  Icons.add,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Buat Kantong',
                style: TextStyle(
                  fontSize: 14,
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
}
