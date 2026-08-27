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
import '../widgets/money_location_picker.dart';
import '../providers/transaction_provider.dart';
import '../utils/calculator_parser.dart';
import '../utils/rupiah_input_formatter.dart';
import '../widgets/custom_bottom_sheet.dart';
import '../widgets/ai_chat_bubble.dart';
import '../widgets/calculator_bubble.dart';
import '../utils/error_message.dart';

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
  TimeOfDay? _selectedTime = TimeOfDay.now();
  String _category = 'Pengeluaran';
  int? _selectedFinancialPlanId;
  int? _selectedPocketId;
  int? _selectedMoneyLocationId;
  bool _isSaving = false;
  bool _isAddingCategory = false;

  /// Jumlah & satuan bersifat opsional, jadi disembunyikan sampai diminta.
  /// Saat mengedit transaksi yang sudah punya detail, langsung dibuka.
  bool _showQuantityDetail = false;

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
      } else {
        _selectedTime = null;
      }
      _category = existing.category;
      _selectedFinancialPlanId = existing.financialPlanId;
      _selectedPocketId = existing.pocketId;
      _selectedMoneyLocationId = existing.moneyLocationId;
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

  /// Melepaskan fokus sebelum lembar pilihan dibuka.
  ///
  /// Tanpa ini, papan ketik yang tadi terbuka akan muncul lagi begitu lembar
  /// ditutup — Flutter mengembalikan fokus ke tempat terakhirnya. Memilih
  /// kategori seharusnya tidak berujung pada papan ketik yang menyembul
  /// sendiri di kolom yang sama sekali tidak disentuh pengguna.
  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _pickDate() async {
    _dismissKeyboard();
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
    _dismissKeyboard();
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
    _dismissKeyboard();
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

    String? autofillAmount;
    String? autofillTitle;
    String? autofillCategory;
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
          break;
        }
      }
    }

    setState(() {
      _selectedFinancialPlanId = selected;

      // Nominal rencana cuma dipakai sebagai isian awal, bukan koreksi.
      // Angka yang sudah diketik adalah yang benar-benar dikeluarkan hari ini
      // — target rencana belum tentu sama, dan menimpanya diam-diam membuat
      // pengeluaran tercatat lebih besar dari yang sebenarnya terjadi.
      final amountText = autofillAmount;
      if (amountText != null && _amountController.text.trim().isEmpty) {
        _amountController.value = TextEditingValue(
          text: amountText,
          selection: TextSelection.collapsed(offset: amountText.length),
        );
      }

      final titleText = autofillTitle?.trim();
      if (titleText != null &&
          titleText.isNotEmpty &&
          _titleController.text.trim().isEmpty) {
        _titleController.value = TextEditingValue(
          text: titleText,
          selection: TextSelection.collapsed(offset: titleText.length),
        );
      }

      final categoryText = autofillCategory?.trim();
      if (categoryText != null && categoryText.isNotEmpty) {
        _category = categoryText;
      }

      // Tanggal & jam sengaja tidak ikut diubah. Target rencana adalah
      // tenggat di masa depan, sedangkan yang dicatat di sini adalah kapan
      // uangnya benar-benar keluar — yaitu sekarang.
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
    _dismissKeyboard();
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

  Future<void> _openMoneyLocationPicker() async {
    _dismissKeyboard();
    final choice = await showMoneyLocationPicker(
      context: context,
      selectedId: _selectedMoneyLocationId,
      title: 'Uang ini dari mana?',
      noneSubtitle: 'Tidak dicatat asal uangnya',
    );

    if (!mounted || choice == null) return;
    if (choice.locationId != _selectedMoneyLocationId) {
      setState(() => _selectedMoneyLocationId = choice.locationId);
    }
  }

  Future<void> _openCategoryPicker(List<String> categories) async {
    _dismissKeyboard();
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
                .where(
                  (c) => c.toLowerCase().contains(searchQuery.toLowerCase()),
                )
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
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Cari kategori...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 0,
                        ),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 12,
                              ),
                              color: Theme.of(context).cardTheme.color,
                              borderRadius: BorderRadius.circular(12),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.add_rounded,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Tambah Kategori Baru',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
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
                  hintText: 'Contoh: Belanja Dapur',
                ),
                onChanged: (value) => inputValue = value,
                onSubmitted: submit,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: isSubmitting
                          ? null
                          : () => Navigator.pop(context),
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
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
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
      final message = friendlyError(e);
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
    final qty = qtyText.isEmpty
        ? null
        : double.tryParse(qtyText.replaceAll(',', '.'));

    if (qtyText.isNotEmpty && (qty == null || qty <= 0)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Jumlahnya belum valid.')));
      return false;
    }

    final detailParts = <String>[];
    if (qtyText.isNotEmpty) {
      detailParts.add(qtyText);
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
            moneyLocationId: _selectedMoneyLocationId,
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
            moneyLocationId: _selectedMoneyLocationId,
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
      final message = friendlyError(e);
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
    // Placeholder dibedakan dari nilai: teksnya netral dan dirender redup
    // lewat `isPlaceholder`, supaya tidak terbaca sebagai nama rencana/kantong.
    String selectedPlanText = 'Belum dipilih';
    String selectedPocketText = 'Belum dipilih';

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

    // Lokasi yang sudah dihapus tidak boleh menyisakan pilihan hantu di form.
    final moneyLocations = provider.moneyLocations;
    if (_selectedMoneyLocationId != null &&
        !moneyLocations.any((item) => item.id == _selectedMoneyLocationId)) {
      _selectedMoneyLocationId = null;
    }

    String selectedMoneyLocationText = 'Belum dipilih';
    if (_selectedMoneyLocationId != null) {
      for (final item in moneyLocations) {
        if (item.id == _selectedMoneyLocationId) {
          selectedMoneyLocationText = item.name;
          break;
        }
      }
    }

    if (!categories.contains(_category)) {
      _category = categories.first;
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          SafeArea(
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
                  const SizedBox(height: 4),
                  Expanded(
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        padding: const EdgeInsets.only(bottom: 24),
                        children: [
                          // ── Nominal: elemen utama layar ini ────────────────
                          _AmountHeroField(
                            controller: _amountController,
                            onChanged: () => setState(() {}),
                          ),
                          const SizedBox(height: 18),

                          // ── Judul ──────────────────────────────────────────
                          TextFormField(
                            controller: _titleController,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Judul',
                              hintText: 'Catatan pengeluaran',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Judul wajib diisi';
                              }
                              return null;
                            },
                          ),

                          // ── Jumlah & satuan: opsional, dilipat ─────────────
                          if (!_showQuantityDetail)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () =>
                                    setState(() => _showQuantityDetail = true),
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: const Text('Jumlah & satuan'),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            )
                          else ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _qtyController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    textInputAction: TextInputAction.next,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                        RegExp(r'[0-9.,]'),
                                      ),
                                    ],
                                    decoration: const InputDecoration(
                                      labelText: 'Jumlah',
                                      hintText: 'mis. 2',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    controller: _unitController,
                                    textInputAction: TextInputAction.done,
                                    decoration: const InputDecoration(
                                      labelText: 'Satuan',
                                      hintText: 'mis. kg',
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Sembunyikan jumlah & satuan',
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    _qtyController.clear();
                                    _unitController.clear();
                                    setState(() => _showQuantityDetail = false);
                                  },
                                ),
                              ],
                            ),
                          ],

                          // ── Rincian: pilihan, bukan ketikan ────────────────
                          const SizedBox(height: 18),
                          const _SectionLabel('Rincian'),
                          const SizedBox(height: 10),
                          _DetailGroup(
                            children: [
                              _DetailRow(
                                label: 'Kategori',
                                value: _category,
                                icon: Icons.category_rounded,
                                onTap: () => _openCategoryPicker(categories),
                              ),
                              _DetailRow(
                                label: 'Rencana',
                                value: selectedPlanText,
                                icon: Icons.flag_rounded,
                                isPlaceholder: _selectedFinancialPlanId == null,
                                onTap: () =>
                                    _openFinancialPlanPicker(financialPlans),
                              ),
                              _DetailRow(
                                label: 'Kantong',
                                value: selectedPocketText,
                                icon: Icons.account_balance_wallet_rounded,
                                isPlaceholder: _selectedPocketId == null,
                                onTap: () => _openPocketPicker(pockets),
                              ),
                              _DetailRow(
                                label: 'Sumber Uang',
                                value: selectedMoneyLocationText,
                                icon: Icons.savings_rounded,
                                isPlaceholder:
                                    _selectedMoneyLocationId == null,
                                showDivider: false,
                                onTap: _openMoneyLocationPicker,
                              ),
                            ],
                          ),

                          // ── Kapan: tanggal & jam sejajar ───────────────────
                          const SizedBox(height: 18),
                          const _SectionLabel('Kapan'),
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: _pickDate,
                                  borderRadius: BorderRadius.circular(12),
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: 'Tanggal',
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
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: InkWell(
                                  onTap: _pickTime,
                                  borderRadius: BorderRadius.circular(12),
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      labelText: 'Jam',
                                      suffixIcon: _selectedTime == null
                                          ? null
                                          : IconButton(
                                              tooltip: 'Kosongkan jam',
                                              icon: const Icon(
                                                Icons.close_rounded,
                                                size: 16,
                                              ),
                                              onPressed: () => setState(
                                                () => _selectedTime = null,
                                              ),
                                            ),
                                    ),
                                    child: Text(
                                      _timeLabel(),
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // ── Simpan ─────────────────────────────────────────
                          const SizedBox(height: 24),
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
                ],
              ),
            ),
          ),
          const AiChatBubble(currentContext: 'Expense Input Screen'),
          const CalculatorBubble(),
        ],
      ),
    );
  }
}

/// Satu baris pilihan di dalam [_DetailGroup].
///
/// Sengaja TIDAK berbentuk kotak seperti field ketikan: baris ini membuka
/// bottom sheet, bukan memunculkan keyboard. Bentuk yang berbeda untuk
/// perilaku yang berbeda.
class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.isPlaceholder = false,
    this.showDivider = true,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  /// Nilai belum dipilih — dirender redup supaya tidak terbaca sebagai pilihan.
  final bool isPlaceholder;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      label: '$label: $value',
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Row(
                children: [
                  Icon(icon, size: 17, color: theme.hintColor),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 74,
                    child: Text(
                      label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.hintColor,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: isPlaceholder
                            ? FontWeight.w400
                            : FontWeight.w600,
                        color: isPlaceholder ? theme.hintColor : null,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: theme.hintColor,
                  ),
                ],
              ),
            ),
            if (showDivider)
              Divider(
                height: 1,
                thickness: 1,
                indent: 12,
                endIndent: 12,
                color: theme.dividerColor.withValues(alpha: 0.4),
              ),
          ],
        ),
      ),
    );
  }
}

/// Pembungkus untuk sekelompok [_DetailRow] — satu border, bukan satu per baris.
class _DetailGroup extends StatelessWidget {
  const _DetailGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color:
            Theme.of(context).cardTheme.color ??
            Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Theme.of(context).extension<AppThemeExtension>()?.cardBorder,
      ),
      child: Column(children: children),
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
                        ? Theme.of(context).colorScheme.onErrorContainer
                        : Theme.of(
                            context,
                          ).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: selected
                          ? Theme.of(context).colorScheme.onErrorContainer
                          : Theme.of(context).textTheme.bodyMedium?.color
                                ?.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (selected)
            Icon(
              Icons.check_circle_rounded,
              color: Theme.of(context).colorScheme.onErrorContainer,
              size: 18,
            ),
        ],
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
          ? Theme.of(context).colorScheme.errorContainer
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
                    ? Theme.of(context).colorScheme.onErrorContainer
                    : Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ),
          if (selected) ...[
            const SizedBox(width: 8),
            Icon(
              Icons.check_circle_rounded,
              color: Theme.of(context).colorScheme.onErrorContainer,
              size: 20,
            ),
          ],
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

/// Label seksi: huruf besar kecil-renggang dengan garis rambut.
///
/// Menggantikan emoji + label berwarna. Emoji tidak mewarisi warna yang
/// dioper, jadi labelnya berwarna sementara emojinya tidak. Warna error juga
/// dilepas — merah harus berarti "ada yang salah", bukan nama seksi.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.hintColor,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            fontSize: 10,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Divider(
            height: 1,
            thickness: 1,
            color: theme.dividerColor.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }
}

/// Field nominal sebagai elemen utama layar.
///
/// Dibuat tanpa kotak: prefiks `Rp` kecil dan redup, angka berukuran display
/// dengan `tabular-nums`, dan garis bawah tebal sebagai pengganti border.
/// Tetap menerima ekspresi kalkulator ("50k+20k"), karena itu keyboard-nya
/// `text` dan bukan numerik.
class _AmountHeroField extends StatelessWidget {
  const _AmountHeroField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expenseColor = theme.colorScheme.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              'Rp',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.hintColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: controller,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.next,
                inputFormatters: [RupiahInputFormatter()],
                style: theme.textTheme.displaySmall?.copyWith(
                  color: expenseColor,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle: theme.textTheme.displaySmall?.copyWith(
                    color: theme.hintColor.withValues(alpha: 0.4),
                    fontWeight: FontWeight.w800,
                  ),
                  // Kotak dilepas — garis bawah yang menandai field ini.
                  filled: false,
                  isDense: true,
                  contentPadding: const EdgeInsets.only(bottom: 6),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                ),
                onChanged: (_) => onChanged(),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Nominal wajib diisi';
                  }
                  if (RupiahInputFormatter.parse(value) <= 0) {
                    return 'Nominal tidak valid';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        Container(height: 2, color: expenseColor.withValues(alpha: 0.85)),
        const SizedBox(height: 7),
        Text(
          'Ketik angka, atau hitung langsung: 50k+20k',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
        ),
      ],
    );
  }
}
