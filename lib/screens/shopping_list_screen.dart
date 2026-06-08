import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/shopping_item.dart';
import '../providers/shopping_provider.dart';
import '../providers/transaction_provider.dart';
import '../theme/app_theme.dart';
import '../utils/calculator_parser.dart';
import '../utils/rupiah_input_formatter.dart';
import '../widgets/app_card.dart';
import '../widgets/custom_loading_indicator.dart';
import '../widgets/custom_bottom_sheet.dart';

import 'add_shopping_item_screen.dart';
import 'saving_goals_screen.dart';
import 'recurring_transactions_screen.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({Key? key, this.isEmbedded = false})
    : super(key: key);
  final bool isEmbedded;

  @override
  _ShoppingListScreenState createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.isEmbedded) {
      return DefaultTabController(
        length: 3,
        child: Column(
          children: [
            TabBar(
              labelColor: theme.colorScheme.primary.computeLuminance() > 0.6 ? theme.colorScheme.onSurface : theme.colorScheme.primary,
              unselectedLabelColor: Colors.grey,
              indicatorColor: theme.colorScheme.primary.computeLuminance() > 0.6 ? theme.colorScheme.onSurface : theme.colorScheme.primary,
              tabs: const [
                Tab(text: 'Belanja'),
                Tab(text: 'Tabungan'),
                Tab(text: 'Rutin'),
              ],
            ),
            const SizedBox(height: 8),
            const Expanded(
              child: TabBarView(
                children: [
                  _ShoppingListContent(),
                  SavingGoalsScreen(),
                  RecurringTransactionsScreen(),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Daftar Rencana'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Belanja'),
              Tab(text: 'Tabungan'),
              Tab(text: 'Rutin'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ShoppingListContent(),
            SavingGoalsScreen(),
            RecurringTransactionsScreen(),
          ],
        ),
      ),
    );
  }
}

class _ShoppingListContent extends StatefulWidget {
  const _ShoppingListContent({Key? key}) : super(key: key);

  @override
  _ShoppingListContentState createState() => _ShoppingListContentState();
}

class _ShoppingListContentState extends State<_ShoppingListContent> {
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

    int? selectedPocketId;
    int? selectedPlanId;

    final transactionProvider = context.read<TransactionProvider>();
    final pockets = transactionProvider.pockets;
    final plans = transactionProvider.activeBookFinancialPlans;

    final result = await showCustomBottomSheet<Map<String, dynamic>>(
      context: context,
      title: 'Input Total Harga',
      child: StatefulBuilder(
        builder: (context, setState) {
          return Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: amountController,
                  keyboardType: TextInputType.text,
                  inputFormatters: [RupiahInputFormatter()],
                  decoration: const InputDecoration(
                    hintText: 'Rp 0',
                    labelText: 'Total Harga',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Masukkan total harga';
                    }
                    final amount = CalculatorParser.evaluate(value);
                    if (amount <= 0) {
                      return 'Total harga tidak valid';
                    }
                    return null;
                  },
                ),
                if (pockets.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int?>(
                    value: selectedPocketId,
                    decoration: const InputDecoration(
                      labelText: 'Sumber Dana (Opsional)',
                      prefixIcon: Icon(Icons.account_balance_wallet_rounded, size: 20),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Tanpa Sumber Dana'),
                      ),
                      ...pockets.map((p) => DropdownMenuItem<int?>(
                            value: p.id,
                            child: Text(p.name),
                          )),
                    ],
                    onChanged: (val) {
                      setState(() {
                        selectedPocketId = val;
                      });
                    },
                  ),
                ],
                if (plans.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int?>(
                    value: selectedPlanId,
                    decoration: const InputDecoration(
                      labelText: 'Rencana Keuangan (Opsional)',
                      prefixIcon: Icon(Icons.flag_rounded, size: 20),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Tanpa Rencana'),
                      ),
                      ...plans.map((p) => DropdownMenuItem<int?>(
                            value: p.id,
                            child: Text(p.title),
                          )),
                    ],
                    onChanged: (val) {
                      setState(() {
                        selectedPlanId = val;
                      });
                    },
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Batal'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          if (formKey.currentState?.validate() != true) return;
                          final amount = CalculatorParser.evaluate(
                            amountController.text,
                          );
                          Navigator.pop(context, {
                            'amount': amount,
                            'pocketId': selectedPocketId,
                            'planId': selectedPlanId,
                          });
                        },
                        child: const Text('Simpan'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    if (!mounted || result == null) return;
    final totalAmount = result['amount'] as double;
    final pocketId = result['pocketId'] as int?;
    final planId = result['planId'] as int?;

    await context.read<ShoppingProvider>().markAsBought(
          item,
          totalAmount,
          pocketId: pocketId,
          financialPlanId: planId,
        );
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
    return Consumer<ShoppingProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CustomLoadingIndicator(size: 40));
          }

          final unboughtItems = provider.items
              .where((i) => i.isBought == 0)
              .toList();
          final estimatedTotal = unboughtItems.fold(
            0.0,
            (sum, item) => sum + item.amount,
          );

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(5, 12, 5, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AddShoppingItemScreen(),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.add_box_rounded,
                      color: Color(0xFF2A9D50),
                    ),
                    label: const Text(
                      'Tambah Belanja',
                      style: TextStyle(color: Color(0xFF2A9D50)),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Color(0xFF2A9D50)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
              if (provider.items.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Lottie.asset(
                          'assets/lottie/empty.json',
                          width: 200,
                          height: 200,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Belum ada daftar belanja.',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: _EstimationSummary(
                    total: estimatedTotal,
                    itemsCount: unboughtItems.length,
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: provider.items.length,
                    padding: const EdgeInsets.fromLTRB(5, 12, 5, 140),
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = provider.items[index];
                      return _ShoppingItemTile(
                        item: item,
                        onEdit: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  AddShoppingItemScreen(item: item),
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
            ],
          );
        },
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
        : (totalAmount > 0 ? '${rupiahFormatter.format(totalAmount)}' : 'Rp 0');

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
      child: AppCard(isInteractive: true,
        onTap: () {},
        padding: const EdgeInsets.all(10),
        color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
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
              color: isDark ? Colors.black26 : Theme.of(context).colorScheme.surface,
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
                Text(
                  'Estimasi Pengeluaran',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  total > 0 ? RupiahInputFormatter.format(total) : 'Rp 0',
                  style: theme.textTheme.headlineSmall,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Belum Dibeli',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
