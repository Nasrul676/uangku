import 'dart:async';

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_bouncing_card.dart';
import '../widgets/global_action_overlay.dart';
import '../widgets/swipe_button.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/book_period.dart';
import '../models/finance_transaction.dart';
import '../models/financial_plan.dart';
import '../models/pocket.dart';
import '../providers/transaction_provider.dart';
import '../utils/calculator_parser.dart';
import '../utils/rupiah_input_formatter.dart';
import 'settings_screen.dart';
import 'shopping_list_screen.dart';

class ExpenseInputScreen extends StatefulWidget {
  const ExpenseInputScreen({
    super.key,
    this.existingTransaction,
    this.initialPocketId,
  });

  final FinanceTransaction? existingTransaction;
  final int? initialPocketId;

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
  int? _selectedPocketId;
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
      _selectedPocketId = existing.pocketId;
    } else {
      _selectedPocketId = widget.initialPocketId;
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
                  12,
                  6,
                  12,
                  12 + MediaQuery.of(context).viewInsets.bottom,
                ),
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
    String? autofillCategory;
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
          autofillCategory = plan.category;

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

      final categoryText = autofillCategory?.trim();
      if (categoryText != null && categoryText.isNotEmpty) {
        _category = categoryText;
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
                _FinancialPlanSheetItem(
                  title: 'Tanpa Kantong',
                  subtitle: 'Pengeluaran ini tidak memotong kantong',
                  selected: _selectedPocketId == null,
                  onTap: () => Navigator.pop(sheetContext, null),
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
                          separatorBuilder: (_, _) => const SizedBox(height: 4),
                          itemBuilder: (context, index) {
                            final pocket = pockets[index];
                            final pocketId = pocket.id;
                            if (pocketId == null) {
                              return const SizedBox.shrink();
                            }
                            return _FinancialPlanSheetItem(
                              title: pocket.name,
                              subtitle: pocket.allocationType == 'PERCENTAGE'
                                  ? 'Alokasi: ${pocket.allocationValue.toInt()}%'
                                  : 'Alokasi: Rp ${NumberFormat.decimalPattern('id_ID').format(pocket.allocationValue)}',
                              selected: _selectedPocketId == pocketId,
                              onTap: () =>
                                  Navigator.pop(sheetContext, pocketId),
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

    if (!mounted) return;
    if (selected != _selectedPocketId) {
      setState(() {
        _selectedPocketId = selected;
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

  Future<bool> _saveExpense() async {
    if (_isSaving) return false;
    if (!_formKey.currentState!.validate()) return false;

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
      return false;
    }

    final qtyText = _qtyController.text.trim();
    final unitText = _unitController.text.trim();
    final qty = qtyText.isEmpty ? null : int.tryParse(qtyText);

    if (qtyText.isNotEmpty && (qty == null || qty <= 0)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Jumlahnya belum valid.')));
      return false;
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
      await GlobalActionOverlay.run(() async {
        if (isEdit) {
          await context.read<TransactionProvider>().updateTransaction(
            id: widget.existingTransaction!.id!,
            title: titleWithDetail,
            amount: CalculatorParser.evaluate(_amountController.text),
            type: 'EXPENSE',
            category: _category,
            date: normalizedSelectedDate,
            time: _selectedTime == null
                ? null
                : _formatTimeForStorage(_selectedTime!),
            financialPlanId: selectedPlanId,
            pocketId: _selectedPocketId,
          );
        } else {
          await context.read<TransactionProvider>().addTransaction(
            title: titleWithDetail,
            amount: CalculatorParser.evaluate(_amountController.text),
            type: 'EXPENSE',
            category: _category,
            date: normalizedSelectedDate,
            time: _selectedTime == null
                ? null
                : _formatTimeForStorage(_selectedTime!),
            financialPlanId: selectedPlanId,
            pocketId: _selectedPocketId,
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $message')));
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
    final categories = provider.expenseCategories.isEmpty
        ? ['Pengeluaran', 'Tabungan/Investasi', 'Needs']
        : provider.expenseCategories;
    final financialPlans = provider.financialPlans;
    final pockets = provider.pockets;
    String selectedPlanText = 'Tanpa Rencana Keuangan';
    String selectedPocketText = 'Tanpa Kantong';

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

    if (_selectedPocketId != null &&
        !pockets.any((item) => item.id == _selectedPocketId)) {
      _selectedPocketId = null;
    }

    if (_selectedPocketId != null) {
      for (final pocket in pockets) {
        if (pocket.id == _selectedPocketId) {
          selectedPocketText = pocket.name;
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
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
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
                          // ── Section 1: Kategori & Label ─────────────────
                          _SectionHeader(
                            emoji: '🏷️',
                            label: 'Kategori & Label',
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 10),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              children: [
                                ...categories.map(
                                  (item) => Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: _CategoryChip(
                                      label: item,
                                      selected: _category == item,
                                      onTap: () =>
                                          setState(() => _category = item),
                                    ),
                                  ),
                                ),
                                _AddCategoryChip(
                                  onTap: _openAddCategoryDialog,
                                  isLoading: _isAddingCategory,
                                ),
                              ],
                            ),
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
                          _PocketSelectorField(
                            selectedPocketId: _selectedPocketId,
                            onTap: () => _openPocketPicker(pockets),
                            selectedText: selectedPocketText,
                          ),

                          // ── Section 2: Nominal & Judul ──────────────────
                          const SizedBox(height: 16),
                          const _SectionDivider(),
                          const SizedBox(height: 12),
                          _SectionHeader(
                            emoji: '📝',
                            label: 'Detail Pengeluaran',
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _amountController,
                            keyboardType: TextInputType.text,
                            inputFormatters: [RupiahInputFormatter()],
                            decoration: InputDecoration(
                              hintText: 'Nominal pengeluaran',
                              suffix: _amountValue > 0
                                  ? Text(
                                      _currencyFormatter.format(_amountValue),
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: theme.colorScheme.error,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    )
                                  : null,
                            ),
                            onChanged: (_) => setState(() {}),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Nominal wajib diisi';
                              }
                              final amount = RupiahInputFormatter.parse(value);
                              if (amount <= 0) return 'Nominal tidak valid';
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _titleController,
                            decoration: const InputDecoration(
                              hintText: 'Catatan / judul pengeluaran',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Judul wajib diisi';
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
                                    hintText: 'Jml (ops.)',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: _unitController,
                                  decoration: const InputDecoration(
                                    hintText: 'Satuan (ops.)',
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // ── Section 3: Waktu ────────────────────────────
                          const SizedBox(height: 16),
                          const _SectionDivider(),
                          const SizedBox(height: 12),
                          _SectionHeader(
                            emoji: '📅',
                            label: 'Kapan?',
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              InkWell(
                                onTap: _pickDate,
                                borderRadius: BorderRadius.circular(12),
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    hintText: 'Tanggal',
                                  ),
                                  child: Text(
                                    DateFormat(
                                      'dd MMM yyyy',
                                      'id',
                                    ).format(_selectedDate),
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              InkWell(
                                onTap: _pickTime,
                                borderRadius: BorderRadius.circular(12),
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    hintText: 'Jam',
                                    suffix: _selectedTime != null
                                        ? GestureDetector(
                                            onTap: () => setState(
                                              () => _selectedTime = null,
                                            ),
                                            child: const Icon(
                                              Icons.close_rounded,
                                              size: 16,
                                            ),
                                          )
                                        : null,
                                  ),
                                  child: Text(
                                    _timeLabel(),
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // ── Save Button ──────────────────────────────────
                          const SizedBox(height: 20),
                          SwipeButton(
                            label: widget.existingTransaction == null
                                ? 'Swipe untuk simpan'
                                : 'Swipe untuk update',
                            onSwipeComplete: _saveExpense,
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

class _PocketSelectorField extends StatelessWidget {
  const _PocketSelectorField({
    required this.selectedPocketId,
    required this.selectedText,
    required this.onTap,
  });

  final int? selectedPocketId;
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
              const Icon(Icons.account_balance_wallet_rounded, size: 18),
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
      color: selected
          ? Theme.of(context).colorScheme.errorContainer
          : Theme.of(context).cardTheme.color,
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
                    color: selected
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(
                            context,
                          ).textTheme.bodyMedium?.color?.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: selected
                        ? Theme.of(context).colorScheme.onErrorContainer
                        : Theme.of(
                            context,
                          ).textTheme.bodyMedium?.color?.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          if (selected)
            Icon(
              Icons.check_circle_rounded,
              color: Theme.of(context).colorScheme.error,
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
          color:
              Theme.of(context).cardTheme.color ??
              Theme.of(context).colorScheme.surface,
          shape: BoxShape.circle,
          border: Theme.of(context).extension<AppThemeExtension>()?.cardBorder,
        ),
        child: Icon(icon, size: 18),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.emoji,
    required this.label,
    required this.color,
  });

  final String emoji;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
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
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.errorContainer
              : theme.cardTheme.color,
          borderRadius: BorderRadius.circular(12),
          border: selected
              ? Border.all(color: theme.colorScheme.error, width: 1.5)
              : theme.extension<AppThemeExtension>()?.cardBorder,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(
                Icons.check_rounded,
                size: 14,
                color: theme.brightness == Brightness.dark
                    ? Colors.white
                    : theme.colorScheme.error,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: theme.brightness == Brightness.dark
                    ? Colors.white
                    : (selected
                        ? theme.colorScheme.error
                        : theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
              ),
            ),
          ],
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
    final theme = Theme.of(context);
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.5),
            width: 1.5,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            isLoading
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primary,
                    ),
                  )
                : Icon(
                    Icons.add_rounded,
                    size: 14,
                    color: theme.colorScheme.primary,
                  ),
            const SizedBox(width: 4),
            Text(
              'Tambah',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
