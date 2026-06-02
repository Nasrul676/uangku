import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/parsed_receipt_item.dart';
import '../models/financial_plan.dart';
import '../models/pocket.dart';
import '../providers/transaction_provider.dart';
import '../providers/shopping_provider.dart';
import '../theme/app_theme.dart';
import '../utils/rupiah_input_formatter.dart';
import '../widgets/global_action_overlay.dart';
import '../widgets/swipe_button.dart';
import '../models/shopping_item.dart';

class ReceiptReviewScreen extends StatefulWidget {
  final List<ParsedReceiptItem> items;
  final String imagePath;

  const ReceiptReviewScreen({
    super.key,
    required this.items,
    required this.imagePath,
  });

  @override
  State<ReceiptReviewScreen> createState() => _ReceiptReviewScreenState();
}

class _ReceiptReviewScreenState extends State<ReceiptReviewScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late List<ParsedReceiptItem> _items;
  
  String _category = 'Belanja';
  int? _selectedFinancialPlanId;
  int? _selectedPocketId;
  bool _isSaving = false;

  final _currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    // Copy the items to allow editing
    _items = List.from(widget.items);
  }

  double get _totalAmount {
    return _items.fold(0, (sum, item) => sum + item.price);
  }

  Future<void> _openFinancialPlanPicker(List<FinancialPlan> plans) async {
    final selected = await showModalBottomSheet<int?>(
      context: context,
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
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
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
                      title: const Text('Tanpa Rencana Keuangan'),
                      subtitle: const Text('Pengeluaran ini tidak ditautkan ke rencana'),
                      selected: _selectedFinancialPlanId == null,
                      onTap: () => Navigator.pop(sheetContext, null),
                    ),
                    Flexible(
                      child: filteredPlans.isEmpty
                          ? const Center(child: Padding(padding: EdgeInsets.all(18), child: Text('Rencana tidak ditemukan.')))
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: filteredPlans.length,
                              itemBuilder: (context, index) {
                                final plan = filteredPlans[index];
                                return ListTile(
                                  title: Text(plan.title),
                                  subtitle: Text(_currencyFormatter.format(plan.targetAmount)),
                                  selected: _selectedFinancialPlanId == plan.id,
                                  onTap: () => Navigator.pop(sheetContext, plan.id),
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

    if (selected != null) {
      setState(() {
        _selectedFinancialPlanId = selected;
      });
    }
  }

  Future<void> _openPocketPicker(List<Pocket> pockets) async {
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
                  title: const Text('Tanpa Kantong'),
                  subtitle: const Text('Pengeluaran ini tidak memotong kantong'),
                  selected: _selectedPocketId == null,
                  onTap: () => Navigator.pop(sheetContext, null),
                ),
                Flexible(
                  child: pockets.isEmpty
                      ? const Center(child: Padding(padding: EdgeInsets.all(18), child: Text('Kantong belum ada.')))
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: pockets.length,
                          itemBuilder: (context, index) {
                            final pocket = pockets[index];
                            return ListTile(
                              title: Text(pocket.name),
                              selected: _selectedPocketId == pocket.id,
                              onTap: () => Navigator.pop(sheetContext, pocket.id),
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

    if (selected != null) {
      setState(() {
        _selectedPocketId = selected;
      });
    }
  }

  Future<bool> _saveReceipt() async {
    if (_isSaving) return false;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak ada item untuk disimpan.')));
      return false;
    }

    setState(() => _isSaving = true);

    try {
      await GlobalActionOverlay.run(() async {
        final provider = context.read<TransactionProvider>();
        final shoppingProvider = context.read<ShoppingProvider>();
        
        // Save the main transaction
        final transactionId = await provider.addTransaction(
          title: 'Belanja dari Scan Struk',
          amount: _totalAmount,
          type: 'EXPENSE',
          category: _category,
          date: DateTime.now(),
          time: null,
          financialPlanId: _selectedFinancialPlanId,
          pocketId: _selectedPocketId,
        );
        
        // Ensure book period is fetched
        final bookPeriodId = provider.selectedBookPeriodId ?? provider.activeBookPeriod?.id;

        // Save each item as a shopping item linked to this transaction
        if (bookPeriodId != null && transactionId > 0) {
          for (var item in _items) {
             final shoppingItem = ShoppingItem(
                bookPeriodId: bookPeriodId,
                title: item.name,
                amount: item.quantity > 0 ? item.price / item.quantity : item.price,
                category: _category,
                date: DateTime.now().toIso8601String(),
                quantity: item.quantity,
                unit: 'pcs',
                isBought: 1, // Marked as bought since it's from a receipt
                expenseTransactionId: transactionId,
              );
              await shoppingProvider.addItem(shoppingItem);
          }
        }

        if (mounted) {
          // Double pop to go back to dashboard (pop scanner, pop review)
          Navigator.pop(context);
        }
      });
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
      return false;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<TransactionProvider>();
    final categories = provider.expenseCategories;
    final financialPlans = provider.financialPlans;
    final pockets = provider.pockets;

    String selectedPlanText = 'Tanpa Rencana Keuangan';
    if (_selectedFinancialPlanId != null) {
      final plan = financialPlans.firstWhere((p) => p.id == _selectedFinancialPlanId, orElse: () => FinancialPlan(bookPeriodId: 0, title: '', targetAmount: 0, targetDate: ''));
      if (plan.title.isNotEmpty) selectedPlanText = plan.title;
    }

    String selectedPocketText = 'Tanpa Kantong';
    if (_selectedPocketId != null) {
      final pocket = pockets.firstWhere((p) => p.id == _selectedPocketId, orElse: () => Pocket(bookPeriodId: 0, name: '', icon: '', allocationType: '', allocationValue: 0));
      if (pocket.name.isNotEmpty) selectedPocketText = pocket.name;
    }

    if (!categories.contains(_category) && categories.isNotEmpty) {
      _category = categories.first;
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Review Hasil Scan'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Receipt Image Preview
          Container(
            height: 120,
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(
                image: FileImage(File(widget.imagePath)),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.5), BlendMode.darken),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              'Total: ${_currencyFormatter.format(_totalAmount)}',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),

          // Configuration
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _openPocketPicker(pockets),
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Kantong', border: OutlineInputBorder()),
                      child: Text(selectedPocketText, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () => _openFinancialPlanPicker(financialPlans),
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Rencana Keuangan', border: OutlineInputBorder()),
                      child: Text(selectedPlanText, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          
          // Items List Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Daftar Item', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _items.add(ParsedReceiptItem(name: '', price: 0));
                    });
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Tambah'),
                ),
              ],
            ),
          ),

          // Inline Editable Table
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _items.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final item = _items[index];
                
                final nameController = TextEditingController(text: item.name);
                final priceController = TextEditingController(
                  text: item.price > 0 ? NumberFormat.decimalPattern('id_ID').format(item.price) : ''
                );
                final qtyController = TextEditingController(
                  text: item.quantity == item.quantity.toInt()
                    ? item.quantity.toInt().toString()
                    : item.quantity.toString()
                );

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          hintText: 'Nama Item',
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onChanged: (val) {
                          item.name = val;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: qtyController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          hintText: 'Qty',
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onChanged: (val) {
                          setState(() {
                            item.quantity = double.tryParse(val.replaceAll(',', '.')) ?? 1.0;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: priceController,
                        keyboardType: TextInputType.text,
                        inputFormatters: [RupiahInputFormatter()],
                        textAlign: TextAlign.right,
                        decoration: const InputDecoration(
                          hintText: 'Rp 0',
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onChanged: (val) {
                          setState(() {
                            item.price = RupiahInputFormatter.parse(val);
                          });
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _items.removeAt(index);
                        });
                      },
                    ),
                  ],
                );
              },
            ),
          ),
          
          // Save Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SwipeButton(
              onSwipeComplete: _saveReceipt,
              label: 'Simpan ke Pengeluaran',
            ),
          ),
        ],
      ),
    );
  }
}
