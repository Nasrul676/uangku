import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/parsed_receipt_item.dart';
import '../models/pocket.dart';
import '../models/financial_plan.dart';
import '../providers/transaction_provider.dart';
import '../utils/rupiah_input_formatter.dart';
import '../widgets/app_card.dart';
import '../widgets/swipe_button.dart';

class ReceiptResultScreen extends StatefulWidget {
  final List<ParsedReceiptItem> items;
  final String? receiptImageFilePath; // opsional, jika ingin ditampilkan 

  const ReceiptResultScreen({
    super.key,
    required this.items,
    this.receiptImageFilePath,
  });

  @override
  State<ReceiptResultScreen> createState() => _ReceiptResultScreenState();
}

class _ReceiptResultScreenState extends State<ReceiptResultScreen> {
  late List<ParsedReceiptItem> _items;
  bool _isSaving = false;

  final _currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.items);
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  void _editItem(int index) async {
    final item = _items[index];
    final provider = context.read<TransactionProvider>();
    final categories = provider.expenseCategories;
    final pockets = provider.pockets;
    final financialPlans = provider.financialPlans;

    final result = await showModalBottomSheet<ParsedReceiptItem>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return _EditReceiptItemSheet(
          item: item,
          categories: categories,
          pockets: pockets,
          financialPlans: financialPlans,
        );
      },
    );

    if (result != null) {
      setState(() {
        _items[index] = result;
      });
    }
  }

  Future<bool> _saveAllAsExpenses() async {
    if (_items.isEmpty) return false;
    
    setState(() => _isSaving = true);
    final provider = context.read<TransactionProvider>();
    final now = DateTime.now();

    try {
      for (final item in _items) {
        final title = item.quantity > 1 
            ? '${item.name} (${item.quantity.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')} ${item.unit})' 
            : item.name;
        
        await provider.addTransaction(
          title: title,
          amount: item.price,
          type: 'EXPENSE',
          category: item.category,
          date: now,
          pocketId: item.pocketId,
          financialPlanId: item.financialPlanId,
        );
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Berhasil menyimpan semua pengeluaran!')),
        );
        // Kembali ke dashboard (bisa pop 2x jika ada screen perantara)
        Navigator.pop(context, true); 
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan pengeluaran: $e')),
        );
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<TransactionProvider>();
    final pockets = provider.pockets;
    final financialPlans = provider.financialPlans;
    final total = _items.fold<double>(0, (sum, item) => sum + item.price);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Hasil Scan Struk'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: theme.colorScheme.primary.withOpacity(0.05),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ketuk barang untuk mengedit. Geser untuk menghapus.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _items.isEmpty
                  ? Center(
                      child: Text(
                        'Tidak ada barang',
                        style: theme.textTheme.bodyLarge,
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];

                        // Resolve pocket and plan names for display
                        String? pocketName;
                        if (item.pocketId != null) {
                          for (final p in pockets) {
                            if (p.id == item.pocketId) {
                              pocketName = p.name;
                              break;
                            }
                          }
                        }
                        String? planName;
                        if (item.financialPlanId != null) {
                          for (final p in financialPlans) {
                            if (p.id == item.financialPlanId) {
                              planName = p.title;
                              break;
                            }
                          }
                        }

                        return Dismissible(
                          key: ValueKey('${item.name}_$index'),
                          direction: DismissDirection.endToStart,
                          onDismissed: (direction) => _removeItem(index),
                          background: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.error,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(Icons.delete_outline, color: Colors.white),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: AppCard(
                              isInteractive: true,
                              onTap: () => _editItem(index),
                              padding: const EdgeInsets.all(16),
                              borderRadius: BorderRadius.circular(12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.secondaryContainer,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.shopping_bag_outlined,
                                      color: theme.colorScheme.onSecondaryContainer,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          style: theme.textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Kategori: ${item.category}',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        if (item.quantity != 1)
                                          Text(
                                            'Qty: ${item.quantity.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')} ${item.unit}',
                                            style: theme.textTheme.bodySmall,
                                          ),
                                        if (pocketName != null)
                                          Text(
                                            'Kantong: $pocketName',
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        if (planName != null)
                                          Text(
                                            'Rencana: $planName',
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    _currencyFormatter.format(item.price),
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFFC24545),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardTheme.color ?? theme.colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Harga:',
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        _currencyFormatter.format(total),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFC24545),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SwipeButton(
                    label: 'Simpan ke Pengeluaran',
                    onSwipeComplete: _saveAllAsExpenses,
                    isLoading: _isSaving,
                    isDark: Theme.of(context).brightness == Brightness.dark,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditReceiptItemSheet extends StatefulWidget {
  final ParsedReceiptItem item;
  final List<String> categories;
  final List<Pocket> pockets;
  final List<FinancialPlan> financialPlans;

  const _EditReceiptItemSheet({
    required this.item,
    required this.categories,
    required this.pockets,
    required this.financialPlans,
  });

  @override
  State<_EditReceiptItemSheet> createState() => _EditReceiptItemSheetState();
}

class _EditReceiptItemSheetState extends State<_EditReceiptItemSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _qtyCtrl;
  late TextEditingController _unitCtrl;
  late String _selectedCategory;
  int? _selectedPocketId;
  int? _selectedFinancialPlanId;

  final _currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.item.name);
    _priceCtrl = TextEditingController(
      text: NumberFormat.decimalPattern('id_ID').format(widget.item.price),
    );
    _qtyCtrl = TextEditingController(
      text: widget.item.quantity.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), ''),
    );
    _unitCtrl = TextEditingController(text: widget.item.unit);
    _selectedCategory = widget.item.category;
    if (!widget.categories.contains(_selectedCategory)) {
      if (widget.categories.isNotEmpty) {
        _selectedCategory = widget.categories.first;
      } else {
        _selectedCategory = 'Lain-lain';
      }
    }
    _selectedPocketId = widget.item.pocketId;
    _selectedFinancialPlanId = widget.item.financialPlanId;
  }

  void _save() {
    final amount = RupiahInputFormatter.parse(_priceCtrl.text);
    final qty = double.tryParse(_qtyCtrl.text) ?? 1.0;
    
    final updated = ParsedReceiptItem(
      name: _nameCtrl.text.trim(),
      price: amount,
      quantity: qty,
      unit: _unitCtrl.text.trim().isEmpty ? 'pcs' : _unitCtrl.text.trim(),
      category: _selectedCategory,
      pocketId: _selectedPocketId,
      financialPlanId: _selectedFinancialPlanId,
    );
    Navigator.pop(context, updated);
  }

  Future<void> _openPocketPicker() async {
    final pockets = widget.pockets;
    final selected = await showModalBottomSheet<int?>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pilih Kantong',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.block_rounded),
                  title: const Text('Tanpa Kantong'),
                  subtitle: const Text('Pengeluaran ini tidak memotong kantong'),
                  selected: _selectedPocketId == null,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onTap: () => Navigator.pop(sheetContext, -1), // -1 means "clear"
                ),
                const SizedBox(height: 4),
                Flexible(
                  child: pockets.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 18),
                            child: Text('Kantong belum ada.'),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: pockets.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 4),
                          itemBuilder: (context, index) {
                            final pocket = pockets[index];
                            final pocketId = pocket.id;
                            if (pocketId == null) return const SizedBox.shrink();
                            return ListTile(
                              leading: const Icon(Icons.account_balance_wallet_rounded),
                              title: Text(pocket.name),
                              subtitle: Text(
                                pocket.allocationType == 'PERCENTAGE'
                                    ? 'Alokasi: ${pocket.allocationValue.toInt()}%'
                                    : 'Alokasi: Rp ${NumberFormat.decimalPattern('id_ID').format(pocket.allocationValue)}',
                              ),
                              selected: _selectedPocketId == pocketId,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              onTap: () => Navigator.pop(sheetContext, pocketId),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || selected == null) return;
    setState(() {
      _selectedPocketId = selected == -1 ? null : selected;
    });
  }

  Future<void> _openFinancialPlanPicker() async {
    final plans = widget.financialPlans;
    final selected = await showModalBottomSheet<int?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setLocalState) {
            final filteredPlans = plans
                .where((plan) {
                  final normalizedQuery = query.trim().toLowerCase();
                  if (normalizedQuery.isEmpty) return true;
                  return plan.title.toLowerCase().contains(normalizedQuery);
                })
                .toList(growable: false);

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  12, 6, 12,
                  12 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pilih Rencana Keuangan',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      onChanged: (value) {
                        setLocalState(() => query = value);
                      },
                      decoration: const InputDecoration(
                        hintText: 'Cari rencana yang diinginkan...',
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      leading: const Icon(Icons.block_rounded),
                      title: const Text('Tanpa Rencana Keuangan'),
                      subtitle: const Text('Pengeluaran ini tidak ditautkan ke rencana'),
                      selected: _selectedFinancialPlanId == null,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onTap: () => Navigator.pop(sheetContext, -1), // -1 means "clear"
                    ),
                    const SizedBox(height: 4),
                    Flexible(
                      child: filteredPlans.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 18),
                                child: Text('Rencana tidak ditemukan.'),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: filteredPlans.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 4),
                              itemBuilder: (context, index) {
                                final plan = filteredPlans[index];
                                final planId = plan.id;
                                if (planId == null) return const SizedBox.shrink();
                                return ListTile(
                                  leading: const Icon(Icons.flag_rounded),
                                  title: Text(plan.title),
                                  subtitle: Text(_currencyFormatter.format(plan.targetAmount)),
                                  selected: _selectedFinancialPlanId == planId,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  onTap: () => Navigator.pop(sheetContext, planId),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted || selected == null) return;
    setState(() {
      _selectedFinancialPlanId = selected == -1 ? null : selected;
    });
  }

  String get _pocketDisplayText {
    if (_selectedPocketId == null) return 'Tanpa Kantong';
    for (final pocket in widget.pockets) {
      if (pocket.id == _selectedPocketId) return pocket.name;
    }
    return 'Tanpa Kantong';
  }

  String get _planDisplayText {
    if (_selectedFinancialPlanId == null) return 'Tanpa Rencana Keuangan';
    for (final plan in widget.financialPlans) {
      if (plan.id == _selectedFinancialPlanId) return plan.title;
    }
    return 'Tanpa Rencana Keuangan';
  }

  @override
  Widget build(BuildContext context) {
    final cats = widget.categories.isEmpty ? ['Lain-lain'] : widget.categories;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Edit Barang',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Nama Barang'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _priceCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [RupiahInputFormatter()],
            decoration: const InputDecoration(labelText: 'Harga Total'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _qtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Jumlah (Qty)'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: TextField(
                  controller: _unitCtrl,
                  decoration: const InputDecoration(labelText: 'Satuan'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: cats.contains(_selectedCategory) ? _selectedCategory : cats.first,
            decoration: const InputDecoration(labelText: 'Kategori'),
            items: cats.map((c) {
              return DropdownMenuItem(value: c, child: Text(c));
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedCategory = val);
            },
          ),
          const SizedBox(height: 12),

          // Kantong selector
          InkWell(
            onTap: _openPocketPicker,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Kantong',
                prefixIcon: Icon(Icons.account_balance_wallet_rounded),
                suffixIcon: Icon(Icons.expand_more_rounded),
              ),
              child: Text(
                _pocketDisplayText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Rencana Keuangan selector
          InkWell(
            onTap: _openFinancialPlanPicker,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Rencana Keuangan',
                prefixIcon: Icon(Icons.flag_rounded),
                suffixIcon: Icon(Icons.expand_more_rounded),
              ),
              child: Text(
                _planDisplayText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          const SizedBox(height: 24),
          FilledButton(
            onPressed: _save,
            child: const Text('Simpan Perubahan'),
          ),
        ],
      ),
    );
  }
}
