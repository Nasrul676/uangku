import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/transaction_provider.dart';
import '../utils/icon_picker_utils.dart';
import '../utils/rupiah_input_formatter.dart';
import 'expense_input_screen.dart';
import 'pocket_form_screen.dart';

class PocketDetailScreen extends StatelessWidget {
  final int pocketId;

  const PocketDetailScreen({super.key, required this.pocketId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Detail Kantong'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: Theme.of(context).iconTheme,
        actions: [
          Consumer<TransactionProvider>(
            builder: (context, provider, child) {
              final pocket = provider.pockets.cast<dynamic?>().firstWhere(
                (p) => p?.id == pocketId,
                orElse: () => null,
              );
              if (pocket == null) return const SizedBox();

              return IconButton(
                icon: Icon(Icons.edit, color: Theme.of(context).colorScheme.primary),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PocketFormScreen(pocket: pocket),
                    ),
                  );
                },
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Hapus Kantong?'),
                  content: const Text(
                    'Apakah Anda yakin ingin menghapus kantong ini? Semua transaksi yang memakai kantong ini tidak akan ikut terhapus, hanya tidak memiliki label kantong lagi.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Batal'),
                    ),
                    TextButton(
                      onPressed: () {
                        Provider.of<TransactionProvider>(
                          context,
                          listen: false,
                        ).deletePocket(pocketId);
                        Navigator.pop(context);
                        Navigator.pop(context);
                      },
                      child: Text(
                        'Hapus',
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<TransactionProvider>(
        builder: (context, provider, child) {
          final pocket = provider.pockets.cast<dynamic?>().firstWhere(
            (p) => p?.id == pocketId,
            orElse: () => null,
          );

          if (pocket == null) {
            return const Center(child: Text('Kantong tidak ditemukan.'));
          }

          final effectiveBalance = provider.getPocketEffectiveBalance(pocketId);
          final isNegative = effectiveBalance < 0;
          final currencyFormatter = NumberFormat.currency(
            locale: 'id_ID',
            symbol: 'Rp ',
            decimalDigits: 0,
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 16),
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      IconPickerUtils.getIcon(pocket.icon),
                      style: const TextStyle(fontSize: 40),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  pocket.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Text(
                    pocket.allocationType == 'PERCENTAGE'
                        ? 'Target: ${pocket.allocationValue.toInt()}% Pemasukan'
                        : 'Target: ${currencyFormatter.format(pocket.allocationValue)}',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).shadowColor.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Saldo Kantong Tersisa',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          currencyFormatter.format(effectiveBalance),
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isNegative
                                ? Theme.of(context).colorScheme.error
                                : Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                      ),
                      if (isNegative) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'OVER BUDGET',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // ACTION BUTTONS
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _showAddMoneyOptionsDialog(context, provider, pocketId);
                    },
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Tambah Uang'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ExpenseInputScreen(
                            initialPocketId: pocketId,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.remove_circle_outline),
                    label: const Text('Tambah Pengeluaran'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.error,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Riwayat Pengeluaran Kantong',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(height: 12),
                Builder(
                  builder: (context) {
                    final expenses = provider.transactions
                        .where(
                          (tx) =>
                              tx.pocketId == pocketId && tx.type == 'EXPENSE',
                        )
                        .toList();
                    if (expenses.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'Belum ada pengeluaran dengan kantong ini.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: expenses.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final tx = expenses[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFEBEE),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.arrow_upward,
                              color: Theme.of(context).colorScheme.error,
                              size: 16,
                            ),
                          ),
                          title: Text(
                            tx.title,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            DateFormat(
                              'dd MMM yyyy',
                            ).format(DateTime.parse(tx.date)),
                          ),
                          trailing: Text(
                            '- ${currencyFormatter.format(tx.amount)}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showCustomAmountDialog(
    BuildContext context,
    TransactionProvider provider,
    int pocketId,
  ) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Tambah Uang Custom'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.text,
            inputFormatters: [RupiahInputFormatter()],
            decoration: const InputDecoration(
              hintText: 'Cth: 50.000',
              prefixText: 'Rp ',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final amount = RupiahInputFormatter.parse(controller.text);
                if (amount > 0) {
                  await provider.addCustomAmountToPocket(pocketId, amount);
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  void _showAddMoneyOptionsDialog(
    BuildContext context,
    TransactionProvider provider,
    int pocketId,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tambah Uang ke Kantong',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(
                      Icons.calculate_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  title: const Text('Hitung Otomatis dari Pemasukan Sekarang'),
                  onTap: () async {
                    Navigator.pop(context);
                    await provider.calculatePocketAllocation(pocketId);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Saldo berhasil dihitung dari pemasukan!',
                          ),
                        ),
                      );
                    }
                  },
                ),
                const Divider(),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(Icons.add, color: Theme.of(context).colorScheme.primary),
                  ),
                  title: const Text('Tambah Nominal Lain'),
                  onTap: () {
                    Navigator.pop(context);
                    _showCustomAmountDialog(context, provider, pocketId);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
