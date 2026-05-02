import 'dart:async';

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_bouncing_card.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/book_period.dart';
import '../models/finance_transaction.dart';
import '../models/financial_plan.dart';
import '../providers/transaction_provider.dart';
import '../utils/rupiah_input_formatter.dart';
import 'settings_screen.dart';
import 'shopping_list_screen.dart';

class ExpenseInputScreen extends StatefulWidget {
  const ExpenseInputScreen({super.key, this.existingTransaction});

  final FinanceTransaction? existingTransaction;

  @override
  State<ExpenseInputScreen> createState() => _ExpenseInputScreenState();
}

class _ExpenseInputScreenState extends State<ExpenseInputScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _qtyController = TextEditingController();
  final _unitController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay? _selectedTime;
  String _category = 'Pengeluaran';
  int? _selectedFinancialPlanId;
  bool _isSaving = false;
  bool _isAddingCategory = false;

  final _currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    final existing = widget.existingTransaction;
    if (existing != null) {
      _titleController.text = existing.title;
      _amountController.text = NumberFormat.decimalPattern(
        'id_ID',
      ).format(existing.amount);
      final parsedDate = DateTime.tryParse(existing.date);
      if (parsedDate != null) {
        _selectedDate = _normalizeDate(parsedDate);
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
      _selectedFinancialPlanId = existing.financialPlanId;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _qtyController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  double get _amountValue => RupiahInputFormatter.parse(_amountController.text);

  DateTime _normalizeDate(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  DateTime _minimumExpenseDate(TransactionProvider provider) {
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
    final minDate = _minimumExpenseDate(provider);
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
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      onChanged: (value) {
                        setLocalState(() => query = value);
                      },
                      decoration: const InputDecoration(
                        hintText: 'Cari rencana yang diinginkan...',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _FinancialPlanSheetItem(
                      title: 'Tanpa Rencana Keuangan',
                      subtitle: 'Pengeluaran ini tidak ditautkan ke rencana',
                      selected: _selectedFinancialPlanId == null,
                      onTap: () => Navigator.pop(sheetContext, null),
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
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 4),
                              itemBuilder: (context, index) {
                                final plan = filteredPlans[index];
                                final planId = plan.id;
                                if (planId == null) {
                                  return const SizedBox.shrink();
                                }
                                return _FinancialPlanSheetItem(
                                  title: plan.title,
                                  subtitle: _planLabel(plan),
                                  selected: _selectedFinancialPlanId == planId,
                                  onTap: () =>
                                      Navigator.pop(sheetContext, planId),
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

    final provider = context.read<TransactionProvider>();
    final minDate = _minimumExpenseDate(provider);
    final maxDate = DateTime(2030);

    String? autofillAmount;
    String? autofillTitle;
    DateTime? autofillDate;
    if (selected != null) {
      for (final plan in plans) {
        if (plan.id == selected) {
          final normalizedAmount = plan.targetAmount <= 0
              ? 0
              : plan.targetAmount.round();
          autofillAmount = NumberFormat.decimalPattern(
            'id_ID',
          ).format(normalizedAmount);
          autofillTitle = plan.title;

          final parsedTargetDate = DateTime.tryParse(plan.targetDate);
          if (parsedTargetDate != null) {
            final normalizedTargetDate = _normalizeDate(parsedTargetDate);
            if (normalizedTargetDate.isBefore(minDate)) {
              autofillDate = minDate;
            } else if (normalizedTargetDate.isAfter(maxDate)) {
              autofillDate = maxDate;
            } else {
              autofillDate = normalizedTargetDate;
            }
          }
          break;
        }
      }
    }

    setState(() {
      _selectedFinancialPlanId = selected;
      final amountText = autofillAmount;
      if (amountText != null) {
        _amountController.value = TextEditingValue(
          text: amountText,
          selection: TextSelection.collapsed(offset: amountText.length),
        );
      }

      final titleText = autofillTitle?.trim();
      if (titleText != null && titleText.isNotEmpty) {
        _titleController.value = TextEditingValue(
          text: titleText,
          selection: TextSelection.collapsed(offset: titleText.length),
        );
      }

      final pickedDate = autofillDate;
      if (pickedDate != null) {
        _selectedDate = pickedDate;
      }
    });
  }

  String _planLabel(FinancialPlan plan) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return '${plan.title} • ${formatter.format(plan.targetAmount)}';
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

  Future<void> _saveExpense() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<TransactionProvider>();
    final minDate = _minimumExpenseDate(provider);
    final normalizedSelectedDate = _normalizeDate(_selectedDate);
    if (normalizedSelectedDate.isBefore(minDate)) {
      final minDateText = DateFormat('dd MMM yyyy', 'id').format(minDate);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Tanggal pengeluaran belum bisa sebelum tanggal mulai buku ($minDateText).',
          ),
        ),
      );
      return;
    }

    final qtyText = _qtyController.text.trim();
    final unitText = _unitController.text.trim();
    final qty = qtyText.isEmpty ? null : int.tryParse(qtyText);

    if (qtyText.isNotEmpty && (qty == null || qty <= 0)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Jumlahnya belum valid.')));
      return;
    }

    final detailParts = <String>[];
    if (qty != null) {
      detailParts.add('$qty');
    }
    if (unitText.isNotEmpty) {
      detailParts.add(unitText);
    }

    final titleWithDetail = detailParts.isEmpty
        ? _titleController.text.trim()
        : '${_titleController.text.trim()} (${detailParts.join(' ')})';

    final selectedPlanId = _selectedFinancialPlanId;

    final isEdit = widget.existingTransaction != null;

    setState(() => _isSaving = true);

    try {
      if (isEdit) {
        await context
            .read<TransactionProvider>()
            .updateTransaction(
              id: widget.existingTransaction!.id!,
              title: titleWithDetail,
              amount: RupiahInputFormatter.parse(_amountController.text),
              type: 'EXPENSE',
              category: _category,
              date: normalizedSelectedDate,
              time: _selectedTime == null
                  ? null
                  : _formatTimeForStorage(_selectedTime!),
              financialPlanId: selectedPlanId,
            )
            .timeout(const Duration(seconds: 10));
      } else {
        await context
            .read<TransactionProvider>()
            .addTransaction(
              title: titleWithDetail,
              amount: RupiahInputFormatter.parse(_amountController.text),
              type: 'EXPENSE',
              category: _category,
              date: normalizedSelectedDate,
              time: _selectedTime == null
                  ? null
                  : _formatTimeForStorage(_selectedTime!),
              financialPlanId: selectedPlanId,
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
                ? 'Pengeluaran berhasil diperbarui!'
                : 'Sip, pengeluaran berhasil disimpan!',
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
                ? 'Lagi ada kendala saat menyimpan pengeluaran.'
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<TransactionProvider>();
    final categories = provider.expenseCategories.isEmpty
        ? ['Pengeluaran', 'Tabungan/Investasi', 'Needs']
        : provider.expenseCategories;
    final financialPlans = provider.financialPlans;
    String selectedPlanText = 'Tanpa Rencana Keuangan';

    if (_selectedFinancialPlanId != null &&
        !financialPlans.any((item) => item.id == _selectedFinancialPlanId)) {
      _selectedFinancialPlanId = null;
    }

    if (_selectedFinancialPlanId != null) {
      for (final plan in financialPlans) {
        if (plan.id == _selectedFinancialPlanId) {
          selectedPlanText = _planLabel(plan);
          break;
        }
      }
    }

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
                          ? 'Catat Pengeluaran'
                          : 'Edit Pengeluaran',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontSize: 34,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                  _CircleButton(
                    icon: Icons.shopping_cart_outlined,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ShoppingListScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  _CircleButton(
                    icon: Icons.settings_rounded,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
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
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0x33F7CACA), Color(0x22F0C8C8)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: (Theme.of(context).extension<AppThemeExtension>()?.cardBorder?.top.color ?? const Color(0xFF2D2D2D)),
                                width: 1.1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.existingTransaction == null
                                      ? 'Catat Cepat'
                                      : 'Edit Data',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontSize: 24,
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Catat pengeluaran harian dengan cepat, datanya aman tersimpan di HP dulu.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onErrorContainer,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _currencyFormatter.format(_amountValue),
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontSize: 34,
                                    fontWeight: FontWeight.w700,
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
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
                          Text(
                            'Pilih Kategori',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontSize: 22,
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
                          const SizedBox(height: 10),
                          _FinancialPlanSelectorField(
                            plans: financialPlans,
                            selectedPlanId: _selectedFinancialPlanId,
                            onTap: () =>
                                _openFinancialPlanPicker(financialPlans),
                            selectedText: selectedPlanText,
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _titleController,
                            decoration: const InputDecoration(
                              hintText: 'Catatan pengeluaran',
                              prefixIcon: Icon(Icons.title_rounded),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Judul wajib diisi';
                              }
                              return null;
                            },
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
                            onChanged: (_) => setState(() {}),
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
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _qtyController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: const InputDecoration(
                                    hintText: 'Jumlah (opsional)',
                                    prefixIcon: Icon(Icons.numbers_rounded),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: _unitController,
                                  decoration: const InputDecoration(
                                    hintText: 'Satuan (opsional)',
                                    prefixIcon: Icon(Icons.straighten_rounded),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            height: 52,
                            child: FilledButton(
                              onPressed: _isSaving ? null : _saveExpense,
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

class _FinancialPlanSelectorField extends StatelessWidget {
  const _FinancialPlanSelectorField({
    required this.plans,
    required this.selectedPlanId,
    required this.selectedText,
    required this.onTap,
  });

  final List<FinancialPlan> plans;
  final int? selectedPlanId;
  final String selectedText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? Colors.white,
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
              const Icon(Icons.flag_rounded, size: 18),
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

class _FinancialPlanSheetItem extends StatelessWidget {
  const _FinancialPlanSheetItem({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedBouncingCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      color: selected ? Theme.of(context).colorScheme.errorContainer : Theme.of(context).cardTheme.color,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selected ? Theme.of(context).colorScheme.error : Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: selected ? Theme.of(context).colorScheme.onErrorContainer : Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          if (selected)
            const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFFC24545),
              size: 18,
            ),
        ],
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
          border: Theme.of(context).extension<AppThemeExtension>()?.cardBorder,
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
          color: Theme.of(context).cardTheme.color ?? Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Theme.of(context).extension<AppThemeExtension>()?.cardBorder,
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
