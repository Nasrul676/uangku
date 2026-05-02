import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/shopping_provider.dart';
import '../providers/transaction_provider.dart';
import '../models/shopping_item.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../utils/rupiah_input_formatter.dart';

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Theme.of(context).colorScheme.errorContainer : Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(10),
          border:
              Theme.of(context).extension<AppThemeExtension>()?.cardBorder ??
              Border.all(color: Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: selected ? Theme.of(context).colorScheme.error : Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
          ),
        ),
      ),
    );
  }
}

class _AddCategoryChip extends StatelessWidget {
  const _AddCategoryChip({required this.onTap, required this.isLoading});

  final VoidCallback onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(10),
          border:
              Theme.of(context).extension<AppThemeExtension>()?.cardBorder ??
              Border.all(color: Colors.grey.shade300),
        ),
        child: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add_rounded, size: 16),
      ),
    );
  }
}

class AddShoppingItemScreen extends StatefulWidget {
  final ShoppingItem? item;

  const AddShoppingItemScreen({super.key, this.item});

  @override
  State<AddShoppingItemScreen> createState() => _AddShoppingItemScreenState();
}

class _AddShoppingItemScreenState extends State<AddShoppingItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _amountController = TextEditingController();

  String _selectedCategory = 'Lainnya';
  String _selectedUnit = 'pcs';
  DateTime _selectedDate = DateTime.now();
  TimeOfDay? _selectedTime;
  bool _isAddingCategory = false;

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _titleController.text = widget.item!.title;
      _quantityController.text = widget.item!.quantity.toInt().toString();
      _selectedCategory = widget.item!.category;
      _selectedUnit = widget.item!.unit;
      _selectedDate = DateTime.parse(widget.item!.date);
      if (widget.item!.time != null) {
        final timeParts = widget.item!.time!.split(':');
        _selectedTime = TimeOfDay(
          hour: int.parse(timeParts[0]),
          minute: int.parse(timeParts[1]),
        );
      }
      if (widget.item!.amount > 0) {
        _amountController.text = NumberFormat.decimalPattern('id_ID')
            .format(widget.item!.amount);
      }
    } else {
      final categories = context.read<TransactionProvider>().expenseCategories;
      if (categories.isNotEmpty) {
        _selectedCategory = categories.first;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _quantityController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _openAddCategoryDialog() async {
    if (_isAddingCategory) return;

    final newCategory = await showDialog<String>(
      context: context,
      builder: (context) {
        String inputValue = '';
        bool isSubmitting = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            void submit([String? submittedValue]) {
              if (isSubmitting) return;
              final value = (submittedValue ?? inputValue).trim();
              if (value.isEmpty) return;

              setDialogState(() => isSubmitting = true);
              FocusManager.instance.primaryFocus?.unfocus();
              Navigator.pop(context, value);
            }

            return AlertDialog(
              title: const Text('Tambah Kategori Baru'),
              content: TextField(
                autofocus: true,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  hintText: 'Contoh: Belanja Dapur',
                  prefixIcon: Icon(Icons.add_rounded),
                ),
                onChanged: (value) => inputValue = value,
                onSubmitted: submit,
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text('Nanti Dulu'),
                ),
                FilledButton(
                  onPressed: isSubmitting ? null : submit,
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Tambah'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted || newCategory == null || newCategory.trim().isEmpty) return;

    setState(() => _isAddingCategory = true);

    try {
      final provider = context.read<TransactionProvider>();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      final category = await provider
          .addExpenseCategory(newCategory)
          .timeout(const Duration(seconds: 8));
      if (!mounted) return;
      setState(() => _selectedCategory = category);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kategori "$category" berhasil ditambahkan.')),
        );
      });
    } on TimeoutException {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Proses tambah kategori agak lama. Coba lagi ya.'),
          ),
        );
      });
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message.isEmpty
                  ? 'Oops, kategori belum berhasil ditambahkan.'
                  : message,
            ),
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isAddingCategory = false);
      }
    }
  }

  Future<void> _saveItem() async {
    if (_formKey.currentState!.validate()) {
      final activeBookId = context
          .read<TransactionProvider>()
          .selectedBookPeriodId;
      if (activeBookId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak ada buku kas aktif')),
        );
        return;
      }

      final quantity = double.parse(_quantityController.text);
      final amount = RupiahInputFormatter.parse(_amountController.text);
      final timeStr = _selectedTime != null
          ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}'
          : null;

      final newItem = ShoppingItem(
        id: widget.item?.id,
        bookPeriodId: activeBookId,
        title: _titleController.text,
        amount: amount,
        category: _selectedCategory,
        date: DateFormat('yyyy-MM-dd').format(_selectedDate),
        time: timeStr,
        quantity: quantity,
        unit: _selectedUnit,
        isBought: widget.item?.isBought ?? 0,
      );

      final provider = context.read<ShoppingProvider>();
      if (widget.item == null) {
        await provider.addItem(newItem);
      } else {
        await provider.updateItem(newItem);
      }

      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<TransactionProvider>().expenseCategories;
    if (!categories.contains(_selectedCategory) && categories.isNotEmpty) {
      _selectedCategory = categories.first;
    }

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.item == null ? 'Tambah Daftar Belanja' : 'Edit Daftar Belanja',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const SizedBox(height: 10),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Nama Barang',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Masukkan nama barang'
                    : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _quantityController,
                      decoration: const InputDecoration(
                        labelText: 'Jumlah',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Isi jumlah' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      initialValue: _selectedUnit,
                      decoration: const InputDecoration(
                        labelText: 'Satuan',
                        hintText: 'Contoh: pcs',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (newValue) {
                        setState(() {
                          _selectedUnit = newValue;
                        });
                      },
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Isi satuan' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Total Harga (Opsional)',
                  hintText: 'Rp 0',
                  border: OutlineInputBorder(),
                  helperText:
                      'Kamu bisa mengisinya kembali ketika sudah membeli',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [RupiahInputFormatter()],
              ),
              const SizedBox(height: 16),
              Text(
                'Pilih Kategori',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...categories.map(
                    (item) => _CategoryChip(
                      label: item,
                      selected: _selectedCategory == item,
                      onTap: () => setState(() => _selectedCategory = item),
                    ),
                  ),
                  _AddCategoryChip(
                    onTap: _openAddCategoryDialog,
                    isLoading: _isAddingCategory,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text(
                  'Tanggal: ${DateFormat('dd/MM/yyyy').format(_selectedDate)}',
                ),
                trailing: const Icon(Icons.calendar_today),
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Theme.of(context).colorScheme.outline),
                  borderRadius: BorderRadius.circular(4),
                ),
                onTap: () => _selectDate(context),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text(
                  'Jam (Opsional): ${_selectedTime != null ? _selectedTime!.format(context) : 'Belum diatur'}',
                ),
                trailing: const Icon(Icons.access_time),
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Theme.of(context).colorScheme.outline),
                  borderRadius: BorderRadius.circular(4),
                ),
                onTap: () => _selectTime(context),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.surface,
                    foregroundColor: theme.colorScheme.onSurface,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: theme.colorScheme.outline),
                    ),
                    elevation: 0,
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                  onPressed: _saveItem,
                  child: const Text('Simpan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
