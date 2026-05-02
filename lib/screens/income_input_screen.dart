import 'dart:async';

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_bouncing_card.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/book_period.dart';
import '../models/finance_transaction.dart';
import '../providers/transaction_provider.dart';
import '../utils/rupiah_input_formatter.dart';

class IncomeInputScreen extends StatefulWidget {
  const IncomeInputScreen({super.key, this.existingTransaction});

  final FinanceTransaction? existingTransaction;

  @override
  State<IncomeInputScreen> createState() => _IncomeInputScreenState();
}

class _IncomeInputScreenState extends State<IncomeInputScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay? _selectedTime;
  String _category = 'Gaji';
  bool _isSaving = false;
  bool _isAddingCategory = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingTransaction;
    if (existing != null) {
      _amountController.text = NumberFormat.decimalPattern(
        'id_ID',
      ).format(existing.amount);
      final parsedDate = DateTime.tryParse(existing.date);
      if (parsedDate != null) {
        _selectedDate = DateTime(
          parsedDate.year,
          parsedDate.month,
          parsedDate.day,
        );
      }
      if (existing.time != null && existing.time!.isNotEmpty) {
        final parts = existing.time!.split(':');
        if (parts.length == 2) {
          _selectedTime = TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 0,
            minute: int.tryParse(parts[1]) ?? 0,
          );
        }
      }
      _category = existing.category;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  DateTime _normalizeDate(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  DateTime _minimumIncomeDate(TransactionProvider provider) {
    final selectedBookId = provider.selectedBookPeriodId;
    BookPeriod? selectedBook;
    if (selectedBookId == null) {
      selectedBook = provider.activeBookPeriod;
    } else {
      for (final item in provider.bookPeriods) {
        if (item.id == selectedBookId) {
          selectedBook = item;
          break;
        }
      }
    }
    final startDate = selectedBook == null
        ? null
        : DateTime.tryParse(selectedBook.startDate);
    if (startDate == null) return DateTime(2020);
    return _normalizeDate(startDate);
  }

  Future<void> _pickDate() async {
    final provider = context.read<TransactionProvider>();
    final minDate = _minimumIncomeDate(provider);
    final maxDate = DateTime(2030);
    final normalizedSelected = _normalizeDate(_selectedDate);
    final initialDate = normalizedSelected.isBefore(minDate)
        ? minDate
        : normalizedSelected.isAfter(maxDate)
        ? maxDate
        : normalizedSelected;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: minDate,
      lastDate: maxDate,
    );

    if (picked != null) {
      setState(() => _selectedDate = _normalizeDate(picked));
    }
  }

  Future<void> _pickTime() async {
    final initial = _selectedTime ?? TimeOfDay.now();
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  String _formatTimeForStorage(TimeOfDay value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _timeLabel() {
    final selected = _selectedTime;
    if (selected == null) return 'Pilih jam (opsional)';
    return MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(selected, alwaysUse24HourFormat: true);
  }

  Future<void> _saveIncome() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<TransactionProvider>();
    final minDate = _minimumIncomeDate(provider);
    final normalizedSelectedDate = _normalizeDate(_selectedDate);
    if (normalizedSelectedDate.isBefore(minDate)) {
      final minDateText = DateFormat('dd MMM yyyy', 'id').format(minDate);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Tanggal pemasukan belum bisa sebelum tanggal mulai buku ($minDateText).',
          ),
        ),
      );
      return;
    }

    final isEdit = widget.existingTransaction != null;

    setState(() => _isSaving = true);

    try {
      if (isEdit) {
        await context
            .read<TransactionProvider>()
            .updateTransaction(
              id: widget.existingTransaction!.id!,
              title: _category,
              amount: RupiahInputFormatter.parse(_amountController.text),
              type: 'INCOME',
              category: _category,
              date: _selectedDate,
              time: _selectedTime == null
                  ? null
                  : _formatTimeForStorage(_selectedTime!),
            )
            .timeout(const Duration(seconds: 10));
      } else {
        await context
            .read<TransactionProvider>()
            .addTransaction(
              title: _category,
              amount: RupiahInputFormatter.parse(_amountController.text),
              type: 'INCOME',
              category: _category,
              date: _selectedDate,
              time: _selectedTime == null
                  ? null
                  : _formatTimeForStorage(_selectedTime!),
            )
            .timeout(const Duration(seconds: 10));
      }

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isEdit
                ? 'Pemasukan berhasil diperbarui!'
                : 'Yeay, pemasukan berhasil disimpan!',
          ),
        ),
      );
    } on TimeoutException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Proses simpan agak lama. Coba lagi ya.')),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message.isEmpty
                ? 'Lagi ada kendala saat menyimpan pemasukan.'
                : message,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
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
                  hintText: 'Contoh: Jualan Online',
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
          .addIncomeCategory(newCategory)
          .timeout(const Duration(seconds: 8));
      if (!mounted) return;
      setState(() => _category = category);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<TransactionProvider>();
    final categories = provider.incomeCategories.isEmpty
        ? ['Gaji', 'Bonus', 'Lain-lain']
        : provider.incomeCategories;

    if (!categories.contains(_category)) {
      _category = categories.first;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFE6EBFA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.existingTransaction == null
                          ? 'Catat Pemasukan'
                          : 'Edit Pemasukan',
                      style: theme.textTheme.titleLarge?.copyWith(fontSize: 34),
                    ),
                  ),
                  _CircleButton(
                    icon: Icons.close_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        children: [
                          InkWell(
                            onTap: _pickDate,
                            borderRadius: BorderRadius.circular(12),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                hintText: 'Tanggal',
                                prefixIcon: Icon(Icons.calendar_today_rounded),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      DateFormat(
                                        'EEEE, dd MMM yyyy',
                                        'id',
                                      ).format(_selectedDate),
                                    ),
                                  ),
                                  const Icon(Icons.expand_more_rounded),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          InkWell(
                            onTap: _pickTime,
                            borderRadius: BorderRadius.circular(12),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                hintText: 'Jam',
                                prefixIcon: Icon(Icons.access_time_rounded),
                              ),
                              child: Row(
                                children: [
                                  Expanded(child: Text(_timeLabel())),
                                  if (_selectedTime != null)
                                    InkWell(
                                      onTap: () =>
                                          setState(() => _selectedTime = null),
                                      borderRadius: BorderRadius.circular(99),
                                      child: const Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Icon(
                                          Icons.close_rounded,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.expand_more_rounded),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _amountController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [RupiahInputFormatter()],
                            decoration: const InputDecoration(
                              hintText: 'Nominal',
                              prefixIcon: Icon(Icons.payments_rounded),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Nominal wajib diisi';
                              }
                              final amount = RupiahInputFormatter.parse(value);
                              if (amount <= 0) {
                                return 'Nominal tidak valid';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Pilih Kategori',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontSize: 22,
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
                                  selected: _category == item,
                                  onTap: () => setState(() => _category = item),
                                ),
                              ),
                              _AddCategoryChip(
                                onTap: _openAddCategoryDialog,
                                isLoading: _isAddingCategory,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            height: 52,
                            child: FilledButton(
                              onPressed: _isSaving ? null : _saveIncome,
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      widget.existingTransaction == null
                                          ? 'Simpan Catatan'
                                          : 'Simpan Perubahan',
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Theme.of(context).extension<AppThemeExtension>()?.cardBorder,
        ),
        child: Icon(icon, size: 18),
      ),
    );
  }
}

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
    return AnimatedBouncingCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: selected ? const Color(0xFFA4DBB2) : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
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
    return AnimatedBouncingCard(
      onTap: isLoading ? null : onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.add_rounded, size: 16),
    );
  }
}
