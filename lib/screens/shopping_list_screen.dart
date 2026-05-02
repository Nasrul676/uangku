import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/shopping_item.dart';
import '../providers/shopping_provider.dart';
import '../providers/transaction_provider.dart';
import '../theme/app_theme.dart';
import '../utils/rupiah_input_formatter.dart';
import '../widgets/animated_bouncing_card.dart';

import 'add_shopping_item_screen.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({Key? key}) : super(key: key);

  @override
  _ShoppingListScreenState createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  Future<void> _showBuyDialog(ShoppingItem item) async {
    final formKey = GlobalKey<FormState>();
    final initialTotal = item.amount;
    final amountController = TextEditingController(
      text: RupiahInputFormatter.format(initialTotal),
    );
    final rupiahFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    final totalAmount = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Input Total Harga'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [RupiahInputFormatter()],
              decoration: const InputDecoration(
                hintText: 'Rp 0',
                prefixIcon: Icon(Icons.payments_rounded),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Masukkan total harga';
                }
                final amount = RupiahInputFormatter.parse(value);
                if (amount <= 0) {
                  return 'Total harga tidak valid';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() != true) return;
                final amount = RupiahInputFormatter.parse(
                  amountController.text,
                );
                Navigator.pop(dialogContext, amount);
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );

    if (!mounted || totalAmount == null) return;
    await context.read<ShoppingProvider>().markAsBought(item, totalAmount);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Belanja tercatat: ${rupiahFormatter.format(totalAmount)}',
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final activeBookId = context
          .read<TransactionProvider>()
          .selectedBookPeriodId;
      if (activeBookId != null) {
        context.read<ShoppingProvider>().loadItems(activeBookId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daftar Belanja')),
      body: Consumer<ShoppingProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.items.isEmpty) {
            return const Center(child: Text('Belum ada daftar belanja.'));
          }

          final unboughtItems = provider.items.where((i) => i.isBought == 0).toList();
          final estimatedTotal = unboughtItems.fold(0.0, (sum, item) => sum + item.amount);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _EstimationSummary(
                  total: estimatedTotal,
                  itemsCount: unboughtItems.length,
                ),
              ),
              Expanded(
                child: ListView.separated(
            itemCount: provider.items.length,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = provider.items[index];
              return _ShoppingItemTile(
                item: item,
                onEdit: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddShoppingItemScreen(item: item),
                    ),
                  );
                },
                onDelete: () => provider.deleteItem(item),
                onBuy: () => _showBuyDialog(item),
                onUndo: () =>
                    context.read<ShoppingProvider>().cancelBought(item),
              );
            },
          ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddShoppingItemScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _ShoppingItemTile extends StatelessWidget {
  const _ShoppingItemTile({
    required this.item,
    required this.onEdit,
    required this.onDelete,
    required this.onBuy,
    required this.onUndo,
  });

  final ShoppingItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onBuy;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final unboughtColor = isDark ? Colors.white : const Color(0xFF8A6E2F);
    final parsedDate = DateTime.tryParse(item.date);
    final dateText = parsedDate == null
        ? item.date
        : DateFormat('dd MMM yyyy', 'id').format(parsedDate);
    final storedTime = item.time?.trim();
    final hasTime = storedTime != null && storedTime.isNotEmpty;
    final datetimeLabel = hasTime ? '$dateText • $storedTime' : dateText;
    final rupiahFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final totalAmount = item.amount;
    final amountText = item.bought
        ? rupiahFormatter.format(totalAmount)
        : (totalAmount > 0
            ? '${rupiahFormatter.format(totalAmount)}'
            : 'Rp 0');

    return Slidable(
      key: ValueKey(item.id),
      startActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => onEdit(),
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
            onPressed: (_) => onDelete(),
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Colors.white,
            icon: Icons.delete_rounded,
            label: 'Hapus',
            borderRadius: BorderRadius.circular(12),
          ),
        ],
      ),
      child: AnimatedBouncingCard(
        isPressedEffect: true,
        onTap: () {},
        padding: const EdgeInsets.all(10),
        color: Theme.of(context).cardTheme.color ?? Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: item.bought
                    ? const Color(0xFFA9DDB5)
                    : Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
                border: theme.extension<AppThemeExtension>()?.cardBorder,
              ),
              child: Icon(
                item.bought
                    ? Icons.check_rounded
                    : Icons.shopping_cart_outlined,
                size: 16,
                color: item.bought ? null : unboughtColor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: item.bought ? null : unboughtColor,
                      decoration: item.bought
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.quantity.toInt()} ${item.unit} • ${item.category} • $datetimeLabel',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: item.bought ? null : unboughtColor,
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
                    fontWeight: FontWeight.w700,
                    color: item.bought ? null : unboughtColor,
                  ),
                ),
                const SizedBox(height: 4),
                IconButton(
                  onPressed: item.bought ? onUndo : onBuy,
                  icon: Icon(
                    item.bought
                        ? Icons.undo_rounded
                        : Icons.check_circle_rounded,
                    size: 20,
                  ),
                  color: item.bought
                      ? const Color(0xFF2A9D50)
                      : Theme.of(context).colorScheme.error,
                  tooltip: item.bought ? 'Batalkan' : 'Sudah dibeli',
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EstimationSummary extends StatelessWidget {
  final double total;
  final int itemsCount;

  const _EstimationSummary({required this.total, required this.itemsCount});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppThemeExtension>();
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.neoYellow,
        borderRadius: BorderRadius.circular(10),
        border: ext?.cardBorder,
        boxShadow: ext?.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? Colors.black26 : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: ext?.cardBorder,
            ),
            child: const Icon(Icons.calculate_rounded),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Estimasi Pengeluaran',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                Text(
                  total > 0 ? RupiahInputFormatter.format(total) : 'Rp 0',
                  style: const TextStyle(
                    fontFamily: 'DMSerifDisplay',
                    fontSize: 22,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'Belum Dibeli',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
              ),
              Text(
                '',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
