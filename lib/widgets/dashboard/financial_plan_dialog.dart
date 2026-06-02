import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/book_period.dart';
import '../../models/financial_plan.dart';
import '../../providers/transaction_provider.dart';
import '../../utils/rupiah_input_formatter.dart';

class FinancialPlanDraft {
  const FinancialPlanDraft({
    required this.title,
    required this.targetAmount,
    required this.targetDate,
    required this.targetBookId,
    this.category,
  });

  final String title;
  final double targetAmount;
  final DateTime targetDate;
  final int targetBookId;
  final String? category;
}

class FinancialPlanInputDialog extends StatefulWidget {
  const FinancialPlanInputDialog({
    super.key,
    required this.title,
    required this.targetBooks,
    required this.defaultBookId,
    required this.parsePlanAmount,
    this.actionLabel = 'Simpan',
    this.initialPlan,
  });

  final String title;
  final String actionLabel;
  final List<BookPeriod> targetBooks;
  final int? defaultBookId;
  final double? Function(String input) parsePlanAmount;
  final FinancialPlan? initialPlan;

  @override
  State<FinancialPlanInputDialog> createState() =>
      _FinancialPlanInputDialogState();
}

class _FinancialPlanInputDialogState extends State<FinancialPlanInputDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late DateTime _selectedDate;
  int? _selectedBookId;
  DateTime? _minTargetDate;
  String? _validationMessage;
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.initialPlan?.title ?? '',
    );

    final provider = context.read<TransactionProvider>();
    final initialCat = widget.initialPlan?.category;
    if (initialCat != null && provider.expenseCategories.contains(initialCat)) {
      _selectedCategory = initialCat;
    }

    final initialAmount = widget.initialPlan?.targetAmount;
    _amountController = TextEditingController(
      text: initialAmount != null
          ? NumberFormat.currency(
              locale: 'id_ID',
              symbol: '',
              decimalDigits: 0,
            ).format(initialAmount).trim()
          : '',
    );

    final defaultBookIdCandidate =
        widget.initialPlan?.bookPeriodId ?? widget.defaultBookId;
    if (defaultBookIdCandidate != null &&
        widget.targetBooks.any((b) => b.id == defaultBookIdCandidate)) {
      _selectedBookId = defaultBookIdCandidate;
    } else {
      _selectedBookId = widget.targetBooks.first.id;
    }

    _updateMinTargetDate();

    if (widget.initialPlan != null) {
      _selectedDate =
          DateTime.tryParse(widget.initialPlan!.targetDate) ?? DateTime.now();
      // Make sure we validate it vs min target date again just in case the book was changed
      if (_minTargetDate != null && _selectedDate.isBefore(_minTargetDate!)) {
        _selectedDate = _minTargetDate!;
      }
    } else {
      _selectedDate = DateTime.now();
      _adjustSelectedDateToMin();
    }
  }

  void _updateMinTargetDate() {
    final book = widget.targetBooks.firstWhere(
      (b) => b.id == _selectedBookId,
      orElse: () => widget.targetBooks.first,
    );
    _minTargetDate = DateTime.tryParse(book.startDate);
  }

  void _adjustSelectedDateToMin() {
    final minDate = _minTargetDate;
    if (minDate != null && _selectedDate.isBefore(minDate)) {
      _selectedDate = DateTime(minDate.year, minDate.month, minDate.day);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: _minTargetDate ?? DateTime(2020),
      lastDate: DateTime(2040),
      helpText: 'Target Tanggal',
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedDate = picked);
  }

  void _submit() {
    if (_titleController.text.trim().isEmpty) {
      setState(() => _validationMessage = 'Judul rencana wajib diisi.');
      return;
    }

    final amount = widget.parsePlanAmount(_amountController.text);
    if (amount == null || amount <= 0) {
      setState(() => _validationMessage = 'Target nominal tidak valid.');
      return;
    }

    if (_selectedBookId == null) {
      setState(() => _validationMessage = 'Pilih target buku dulu.');
      return;
    }

    final minDate = _minTargetDate;
    if (minDate != null && _selectedDate.isBefore(minDate)) {
      setState(
        () => _validationMessage =
            'Tanggal target tidak boleh sebelum tanggal buka buku.',
      );
      return;
    }

    Navigator.pop(
      context,
      FinancialPlanDraft(
        title: _titleController.text.trim(),
        targetAmount: amount,
        targetDate: _selectedDate,
        targetBookId: _selectedBookId!,
        category: _selectedCategory,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.targetBooks.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: DropdownButtonFormField<int>(
                  initialValue: _selectedBookId,
                  style: Theme.of(context).textTheme.bodyLarge,
                  decoration: const InputDecoration(
                    hintText: 'Pilih Buku Target',
                  ),
                  items: widget.targetBooks.map((book) {
                    return DropdownMenuItem(
                      value: book.id,
                      child: Text(book.label),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _selectedBookId = value;
                      _updateMinTargetDate();
                      _adjustSelectedDateToMin();
                      _validationMessage = null;
                    });
                  },
                ),
              ),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(hintText: 'Judul rencana'),
              onChanged: (_) {
                if (_validationMessage == null) return;
                setState(() => _validationMessage = null);
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.text,
              inputFormatters: [RupiahInputFormatter()],
              decoration: const InputDecoration(hintText: 'Target nominal'),
              onChanged: (_) {
                if (_validationMessage == null) return;
                setState(() => _validationMessage = null);
              },
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(10),
              child: InputDecorator(
                decoration: const InputDecoration(hintText: 'Target tanggal'),
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
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                hintText: 'Kategori Pengeluaran (Opsional)',
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('Tanpa Kategori'),
                ),
                ...context.read<TransactionProvider>().expenseCategories.map(
                  (cat) => DropdownMenuItem(value: cat, child: Text(cat)),
                ),
              ],
              onChanged: (val) {
                setState(() => _selectedCategory = val);
              },
            ),
            if (_validationMessage != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _validationMessage!,
                  style: const TextStyle(
                    color: Color(0xFFC24545),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Batal'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.actionLabel)),
      ],
    );
  }
}
