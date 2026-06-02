import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/recurring_transaction.dart';
import '../providers/transaction_provider.dart';
import '../utils/calculator_parser.dart';
import '../widgets/global_action_overlay.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_loading_indicator.dart';
import '../models/financial_plan.dart';
import '../models/pocket.dart';
import '../widgets/animated_bouncing_card.dart';

class RecurringTransactionInputScreen extends StatefulWidget {
  const RecurringTransactionInputScreen({super.key, this.existingTransaction});

  final RecurringTransaction? existingTransaction;

  @override
  State<RecurringTransactionInputScreen> createState() =>
      _RecurringTransactionInputScreenState();
}

class _RecurringTransactionInputScreenState
    extends State<RecurringTransactionInputScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _categoryController = TextEditingController();
  
  String _type = 'EXPENSE';
  int? _selectedFinancialPlanId;
  int? _selectedPocketId;
  String _frequency = 'MONTHLY'; // MONTHLY or WEEKLY
  DateTime _nextDate = DateTime.now();
  bool _isSaving = false;

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
      _amountController.text = existing.amount.toInt().toString();
      _categoryController.text = existing.category;
      _type = existing.type;
      _frequency = existing.frequency;
      
      final parsedDate = DateTime.tryParse(existing.nextDate);
      if (parsedDate != null) {
        _nextDate = parsedDate;
      }
      _selectedPocketId = existing.pocketId;
      _selectedFinancialPlanId = existing.financialPlanId;
    } else {
      _categoryController.text = 'Langganan';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  double get _amountValue => CalculatorParser.evaluate(_amountController.text);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime(2050),
    );
    if (picked != null) {
      setState(() => _nextDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<TransactionProvider>();
    final isEdit = widget.existingTransaction != null;

    final tx = RecurringTransaction(
      id: widget.existingTransaction?.id,
      type: _type,
      amount: _amountValue,
      title: _titleController.text.trim(),
      category: _categoryController.text.trim(),
      frequency: _frequency,
      nextDate: _nextDate.toIso8601String(),
      isActive: widget.existingTransaction?.isActive ?? true,
      pocketId: _type == 'EXPENSE' ? _selectedPocketId : null,
      financialPlanId: _type == 'EXPENSE' ? _selectedFinancialPlanId : null,
    );

    await GlobalActionOverlay.run(() async {
      if (isEdit) {
        await provider.updateRecurringTransaction(tx);
      } else {
        await provider.addRecurringTransaction(tx);
      }

      if (mounted) {
        Navigator.pop(context);
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
    setState(() {
      _selectedFinancialPlanId = selected;
    });
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
                  subtitle: 'Transaksi ini tidak memotong/menambah kantong',
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<TransactionProvider>();
    final financialPlans = provider.financialPlans;
    final pockets = provider.pockets;
    String selectedPlanText = 'Tanpa Rencana Keuangan';
    String selectedPocketText = 'Tanpa Kantong';

    if (_selectedFinancialPlanId != null) {
      for (final plan in financialPlans) {
        if (plan.id == _selectedFinancialPlanId) {
          selectedPlanText = _planLabel(plan);
          break;
        }
      }
    }

    if (_selectedPocketId != null) {
      for (final pocket in pockets) {
        if (pocket.id == _selectedPocketId) {
          selectedPocketText = pocket.name;
          break;
        }
      }
    }
    
    final isEdit = widget.existingTransaction != null;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Rutin' : 'Rutin Baru'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          if (isEdit)
            IconButton(
              icon: const Icon(Icons.delete_rounded),
              onPressed: () => _confirmDelete(context),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Segmented Control for Income/Expense
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _type = 'EXPENSE'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _type == 'EXPENSE'
                                ? theme.colorScheme.error
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Pengeluaran',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _type == 'EXPENSE'
                                  ? theme.colorScheme.onError
                                  : theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _type = 'INCOME'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _type == 'INCOME'
                                ? Colors.green
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Pemasukan',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _type == 'INCOME'
                                  ? Colors.white
                                  : theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        children: [
                          if (_type == 'EXPENSE') ...[
                            const SizedBox(height: 16),
                            _FinancialPlanSelectorField(
                              plans: financialPlans,
                              selectedPlanId: _selectedFinancialPlanId,
                              onTap: () => _openFinancialPlanPicker(financialPlans),
                              selectedText: selectedPlanText,
                            ),
                            const SizedBox(height: 10),
                            _PocketSelectorField(
                              selectedPocketId: _selectedPocketId,
                              onTap: () => _openPocketPicker(pockets),
                              selectedText: selectedPocketText,
                            ),
                            const SizedBox(height: 16),
                          ],
                          TextFormField(
                            controller: _titleController,
                            decoration: const InputDecoration(
                              hintText: 'Judul (Contoh: Spotify / Gaji)',
                            ),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Wajib diisi'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _amountController,
                            keyboardType: TextInputType.visiblePassword,
                            decoration: InputDecoration(
                              hintText: 'Nominal (Bisa pakai k, m, +, -)',
                              suffix: _amountValue > 0
                                  ? Text(
                                      _currencyFormatter.format(_amountValue),
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: _type == 'EXPENSE' 
                                            ? theme.colorScheme.error 
                                            : Colors.green,
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
                          const Text(
                            'Kategori',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              children: [
                                ...(_type == 'EXPENSE' ? provider.expenseCategories : provider.incomeCategories).map(
                                  (item) => Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: _CategoryChip(
                                      label: item,
                                      selected: _categoryController.text == item,
                                      onTap: () => setState(() => _categoryController.text = item),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _frequency,
                            decoration: const InputDecoration(
                              hintText: 'Frekuensi',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'WEEKLY',
                                child: Text('Mingguan'),
                              ),
                              DropdownMenuItem(
                                value: 'MONTHLY',
                                child: Text('Bulanan'),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _frequency = val);
                            },
                          ),
                          const SizedBox(height: 16),
                          InkWell(
                            onTap: _pickDate,
                            borderRadius: BorderRadius.circular(12),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                hintText: 'Tanggal Jadwal Berikutnya',
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      DateFormat('dd MMM yyyy', 'id').format(_nextDate),
                                    ),
                                  ),
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
                    backgroundColor: _type == 'EXPENSE' 
                        ? theme.colorScheme.error 
                        : Colors.green,
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
                          'Simpan',
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

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Transaksi Rutin?'),
        content: const Text('Jadwal akan dihapus dan tidak akan diproses otomatis lagi.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              if (widget.existingTransaction?.id != null) {
                await context
                    .read<TransactionProvider>()
                    .deleteRecurringTransaction(widget.existingTransaction!.id!);
              }
              if (context.mounted) {
                Navigator.pop(context);
                Navigator.pop(context);
              }
            },
            child: const Text('Hapus'),
          ),
        ],
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
