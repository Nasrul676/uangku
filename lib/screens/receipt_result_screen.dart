import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/parsed_receipt_item.dart';
import '../providers/transaction_provider.dart';
import '../utils/rupiah_input_formatter.dart';
import '../utils/calculator_parser.dart';
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
            ? '${item.name} (${item.quantity}x)' 
            : item.name;
        
        await provider.addTransaction(
          title: title,
          amount: item.price,
          type: 'EXPENSE',
          category: item.category,
          date: now,
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
                                            'Qty: ${item.quantity.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}',
                                            style: theme.textTheme.bodySmall,
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

  const _EditReceiptItemSheet({
    required this.item,
    required this.categories,
  });

  @override
  State<_EditReceiptItemSheet> createState() => _EditReceiptItemSheetState();
}

class _EditReceiptItemSheetState extends State<_EditReceiptItemSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _qtyCtrl;
  late String _selectedCategory;

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
    _selectedCategory = widget.item.category;
    if (!widget.categories.contains(_selectedCategory)) {
      if (widget.categories.isNotEmpty) {
        _selectedCategory = widget.categories.first;
      } else {
        _selectedCategory = 'Lain-lain';
      }
    }
  }

  void _save() {
    final amount = RupiahInputFormatter.parse(_priceCtrl.text);
    final qty = double.tryParse(_qtyCtrl.text) ?? 1.0;
    
    final updated = ParsedReceiptItem(
      name: _nameCtrl.text.trim(),
      price: amount,
      quantity: qty,
      category: _selectedCategory,
    );
    Navigator.pop(context, updated);
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
          TextField(
            controller: _qtyCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Jumlah (Qty)'),
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
