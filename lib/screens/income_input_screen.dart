import 'dart:async';

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_bouncing_card.dart';
import '../widgets/global_action_overlay.dart';
import '../widgets/swipe_button.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/book_period.dart';
import '../models/finance_transaction.dart';
import '../providers/transaction_provider.dart';
import '../utils/rupiah_input_formatter.dart';
import '../utils/calculator_parser.dart';
import '../widgets/custom_bottom_sheet.dart';

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

  Future<bool> _saveIncome() async {
    if (_isSaving) return false;
    if (!_formKey.currentState!.validate()) return false;

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
      return false;
    }

    final isEdit = widget.existingTransaction != null;

    setState(() => _isSaving = true);

    try {
      await GlobalActionOverlay.run(() async {
        if (isEdit) {
          await context.read<TransactionProvider>().updateTransaction(
            id: widget.existingTransaction!.id!,
            title: 'Pemasukan',
            amount: CalculatorParser.evaluate(_amountController.text),
            type: 'INCOME',
            category: _category,
            date: _selectedDate,
            time: _selectedTime == null
                ? null
                : _formatTimeForStorage(_selectedTime!),
          );
        } else {
          await context.read<TransactionProvider>().addTransaction(
            title: 'Pemasukan',
            amount: CalculatorParser.evaluate(_amountController.text),
            type: 'INCOME',
            category: _category,
            date: _selectedDate,
            time: _selectedTime == null
                ? null
                : _formatTimeForStorage(_selectedTime!),
          );
        }

        if (mounted) {
          Navigator.pop(context);
        }
      });
      return true;
    } on TimeoutException {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Proses simpan agak lama. Coba lagi ya.')),
      );
      return false;
    } catch (e) {
      if (!mounted) return false;
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
      return false;
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _openCategoryPicker(List<String> categories) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filteredCategories = categories
                .where((c) => c.toLowerCase().contains(searchQuery.toLowerCase()))
                .toList();

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  12,
                  6,
                  12,
                  MediaQuery.of(context).viewInsets.bottom + 12,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pilih Kategori',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Cari kategori...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (value) {
                        setSheetState(() {
                          searchQuery = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: filteredCategories.length + 1,
                        separatorBuilder: (_, _) => const SizedBox(height: 2),
                        itemBuilder: (context, index) {
                          if (index == filteredCategories.length) {
                            return AnimatedBouncingCard(
                              onTap: () {
                                Navigator.pop(sheetContext);
                                _openAddCategoryDialog();
                              },
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                              color: Theme.of(context).cardTheme.color,
                              borderRadius: BorderRadius.circular(12),
                              child: Row(
                                children: [
                                   Icon(Icons.add_rounded, color: Theme.of(context).colorScheme.primary),
                                   const SizedBox(width: 8),
                                   Expanded(
                                     child: Text(
                                       'Tambah Kategori Baru',
                                       style: TextStyle(
                                         fontWeight: FontWeight.w700,
                                         color: Theme.of(context).colorScheme.primary,
                                       ),
                                     ),
                                   ),
                                ],
                              ),
                            );
                          }
                          final category = filteredCategories[index];
                          return _CategorySheetItem(
                            title: category,
                            selected: _category == category,
                            onTap: () => Navigator.pop(sheetContext, category),
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

    if (!mounted) return;
    if (selected != null && selected != _category) {
      setState(() {
        _category = selected;
      });
    }
  }

  Future<void> _openAddCategoryDialog() async {
    if (_isAddingCategory) return;

    String inputValue = '';
    bool isSubmitting = false;

    final newCategory = await showCustomBottomSheet<String>(
      context: context,
      title: 'Tambah Kategori Baru',
      child: StatefulBuilder(
        builder: (context, setDialogState) {
          void submit([String? submittedValue]) {
            if (isSubmitting) return;
            final value = (submittedValue ?? inputValue).trim();
            if (value.isEmpty) return;

            setDialogState(() => isSubmitting = true);
            FocusManager.instance.primaryFocus?.unfocus();
            Navigator.pop(context, value);
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                autofocus: true,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  hintText: 'Contoh: Jualan Online',
                ),
                onChanged: (value) => inputValue = value,
                onSubmitted: submit,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: isSubmitting ? null : () => Navigator.pop(context),
                      child: const Text('Nanti Dulu'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: isSubmitting ? null : submit,
                      child: isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Tambah'),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                      style: theme.textTheme.displaySmall,
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
                            keyboardType: TextInputType.text,
                            inputFormatters: [RupiahInputFormatter()],
                            decoration: const InputDecoration(
                              hintText: 'Nominal',
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
                            style: theme.textTheme.titleMedium,
                          ),
                          _CategorySelectorField(
                            selectedText: _category,
                            onTap: () => _openCategoryPicker(categories),
                          ),
                          const SizedBox(height: 14),
                          SwipeButton(
                            label: widget.existingTransaction == null
                                ? 'Swipe untuk simpan'
                                : 'Swipe untuk update',
                            onSwipeComplete: _saveIncome,
                            isLoading: _isSaving,
                            isDark:
                                Theme.of(context).brightness == Brightness.dark,
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
          color: Theme.of(context).cardTheme.color ?? Colors.white,
          shape: BoxShape.circle,
          border: Theme.of(context).extension<AppThemeExtension>()?.cardBorder,
        ),
        child: Icon(icon, size: 18),
      ),
    );
  }
}

class _CategorySelectorField extends StatelessWidget {
  const _CategorySelectorField({
    required this.selectedText,
    required this.onTap,
  });

  final String selectedText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color:
            Theme.of(context).cardTheme.color ??
            Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Theme.of(context).extension<AppThemeExtension>()?.cardBorder,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.category_rounded, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  selectedText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.expand_more_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategorySheetItem extends StatelessWidget {
  const _CategorySheetItem({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedBouncingCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      color: selected
          ? Theme.of(context).colorScheme.tertiaryContainer
          : Theme.of(context).cardTheme.color,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected
                    ? Theme.of(context).colorScheme.onTertiaryContainer
                    : Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ),
          if (selected) ...[
            const SizedBox(width: 8),
            Icon(Icons.check_circle_rounded, color: Theme.of(context).colorScheme.onTertiaryContainer, size: 20),
          ],
        ],
      ),
    );
  }
}
