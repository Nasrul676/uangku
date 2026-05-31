import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/saving_goal.dart';
import '../providers/transaction_provider.dart';
import '../utils/calculator_parser.dart';
import '../widgets/global_action_overlay.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_loading_indicator.dart';

class SavingGoalInputScreen extends StatefulWidget {
  const SavingGoalInputScreen({super.key, this.existingGoal});

  final SavingGoal? existingGoal;

  @override
  State<SavingGoalInputScreen> createState() => _SavingGoalInputScreenState();
}

class _SavingGoalInputScreenState extends State<SavingGoalInputScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _iconController = TextEditingController();
  DateTime? _targetDate;
  bool _isSaving = false;

  final _currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    final existing = widget.existingGoal;
    if (existing != null) {
      _titleController.text = existing.title;
      _amountController.text = existing.targetAmount.toInt().toString();
      _iconController.text = existing.icon ?? '';
      if (existing.targetDate != null) {
        _targetDate = DateTime.tryParse(existing.targetDate!);
      }
    } else {
      _iconController.text = '🎯';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _iconController.dispose();
    super.dispose();
  }

  double get _amountValue => CalculatorParser.evaluate(_amountController.text);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2050),
    );
    if (picked != null) {
      setState(() => _targetDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<TransactionProvider>();
    final isEdit = widget.existingGoal != null;

    final goal = SavingGoal(
      id: widget.existingGoal?.id,
      title: _titleController.text.trim(),
      targetAmount: _amountValue,
      currentAmount: widget.existingGoal?.currentAmount ?? 0.0,
      targetDate: _targetDate?.toIso8601String(),
      icon: _iconController.text.trim(),
    );

    await GlobalActionOverlay.run(() async {
      if (isEdit) {
        await provider.updateSavingGoal(goal);
      } else {
        await provider.addSavingGoal(goal);
      }

      if (mounted) {
        Navigator.pop(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = widget.existingGoal != null;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Tabungan' : 'Tabungan Baru'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        children: [
                          Row(
                            children: [
                              SizedBox(
                                width: 60,
                                child: TextFormField(
                                  controller: _iconController,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 24),
                                  decoration: const InputDecoration(
                                    hintText: '🎯',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _titleController,
                                  decoration: const InputDecoration(
                                    hintText: 'Nama Impian (Membeli Laptop)',
                                  ),
                                  validator: (v) => v == null || v.trim().isEmpty
                                      ? 'Wajib diisi'
                                      : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _amountController,
                            keyboardType: TextInputType.visiblePassword,
                            decoration: InputDecoration(
                              hintText: 'Target Dana (Bisa pakai k, m, +, -)',
                              suffix: _amountValue > 0
                                  ? Text(
                                      _currencyFormatter.format(_amountValue),
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    )
                                  : null,
                            ),
                            onChanged: (_) => setState(() {}),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Wajib diisi';
                              if (_amountValue <= 0) return 'Tidak valid';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          InkWell(
                            onTap: _pickDate,
                            borderRadius: BorderRadius.circular(12),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                hintText: 'Tanggal Target (Opsional)',
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _targetDate == null
                                          ? 'Pilih Target Tanggal (Opsional)'
                                          : DateFormat('dd MMM yyyy', 'id').format(_targetDate!),
                                    ),
                                  ),
                                  if (_targetDate != null)
                                    InkWell(
                                      onTap: () => setState(() => _targetDate = null),
                                      child: const Icon(Icons.close_rounded, size: 18),
                                    ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.calendar_month_rounded),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSaving ? null : _save,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSaving
                      ? const CustomLoadingIndicator(
                          size: 24,
                          color: Colors.white,
                        )
                      : const Text(
                          'Simpan Tabungan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
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
