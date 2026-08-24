import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/book_period.dart';
import '../../models/financial_plan.dart';
import '../../providers/transaction_provider.dart';
import '../../utils/rupiah_input_formatter.dart';
import '../../theme/app_theme.dart';
import '../custom_bottom_sheet.dart';

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

/// Membuka form rencana keuangan sebagai bottom sheet.
///
/// Menggantikan `AlertDialog`: form ini punya lima input, dan dialog membuatnya
/// sempit, menggulung di dalam dirinya sendiri, serta tertutup keyboard di
/// layar HP. Bottom sheet juga sejalan dengan arah aplikasi ini yang sudah
/// mengganti AlertDialog di banyak tempat lain.
Future<FinancialPlanDraft?> showFinancialPlanSheet({
  required BuildContext context,
  required String title,
  required List<BookPeriod> targetBooks,
  required double? Function(String input) parsePlanAmount,
  int? defaultBookId,
  String actionLabel = 'Simpan rencana',
  FinancialPlan? initialPlan,
}) {
  return showCustomBottomSheet<FinancialPlanDraft?>(
    context: context,
    title: title,
    child: FinancialPlanForm(
      targetBooks: targetBooks,
      defaultBookId: defaultBookId,
      parsePlanAmount: parsePlanAmount,
      actionLabel: actionLabel,
      initialPlan: initialPlan,
    ),
  );
}

class FinancialPlanForm extends StatefulWidget {
  const FinancialPlanForm({
    super.key,
    required this.targetBooks,
    required this.defaultBookId,
    required this.parsePlanAmount,
    this.actionLabel = 'Simpan rencana',
    this.initialPlan,
  });

  final List<BookPeriod> targetBooks;
  final int? defaultBookId;
  final double? Function(String input) parsePlanAmount;
  final String actionLabel;
  final FinancialPlan? initialPlan;

  @override
  State<FinancialPlanForm> createState() => _FinancialPlanFormState();
}

class _FinancialPlanFormState extends State<FinancialPlanForm> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late DateTime _selectedDate;
  int? _selectedBookId;
  DateTime? _minTargetDate;
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
          ? RupiahInputFormatter.format(initialAmount)
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
      if (_minTargetDate != null && _selectedDate.isBefore(_minTargetDate!)) {
        _selectedDate = _minTargetDate!;
      }
    } else {
      _selectedDate = DateTime.now();
      _adjustSelectedDateToMin();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
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

  double get _amountValue =>
      widget.parsePlanAmount(_amountController.text) ?? 0;

  /// Berapa bulan dari sekarang ke tanggal target, minimal 1.
  int get _monthsAway {
    final now = DateTime.now();
    final months =
        (_selectedDate.year - now.year) * 12 +
        (_selectedDate.month - now.month);
    return months < 1 ? 1 : months;
  }

  String _bookLabel(int? bookId) {
    for (final book in widget.targetBooks) {
      if (book.id == bookId) return book.label;
    }
    return widget.targetBooks.first.label;
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

  Future<void> _pickBook() async {
    final picked = await showCustomBottomSheet<int>(
      context: context,
      title: 'Pilih Buku',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: widget.targetBooks.map((book) {
          return ListTile(
            leading: const Icon(Icons.menu_book_rounded),
            title: Text(book.label),
            trailing: book.id == _selectedBookId
                ? const Icon(Icons.check_circle_rounded)
                : null,
            onTap: () => Navigator.pop(context, book.id),
          );
        }).toList(),
      ),
    );

    if (picked == null || !mounted) return;
    setState(() {
      _selectedBookId = picked;
      _updateMinTargetDate();
      _adjustSelectedDateToMin();
    });
  }

  Future<void> _pickCategory() async {
    final categories = context.read<TransactionProvider>().expenseCategories;

    final picked = await showCustomBottomSheet<String>(
      context: context,
      title: 'Kategori Pengeluaran',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.block_rounded),
            title: const Text('Tanpa kategori'),
            onTap: () => Navigator.pop(context, ''),
          ),
          ...categories.map(
            (cat) => ListTile(
              leading: const Icon(Icons.category_rounded),
              title: Text(cat),
              trailing: cat == _selectedCategory
                  ? const Icon(Icons.check_circle_rounded)
                  : null,
              onTap: () => Navigator.pop(context, cat),
            ),
          ),
        ],
      ),
    );

    if (picked == null || !mounted) return;
    setState(() => _selectedCategory = picked.isEmpty ? null : picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.pop(
      context,
      FinancialPlanDraft(
        title: _titleController.text.trim(),
        targetAmount: _amountValue,
        targetDate: _selectedDate,
        targetBookId: _selectedBookId!,
        category: _selectedCategory,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<TransactionProvider>();
    final bookId = _selectedBookId;

    return Form(
      key: _formKey,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _TargetAmountField(
                controller: _amountController,
                autofocus: widget.initialPlan == null,
                parsePlanAmount: widget.parsePlanAmount,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 8),
              _PerMonthHint(amount: _amountValue, months: _monthsAway),

              if (bookId != null) ...[
                const SizedBox(height: 12),
                _BudgetImpact(
                  budget: provider.planBudgetBasisForBook(bookId),
                  otherPlansTotal: provider.totalPlannedForBook(
                    bookId,
                    excludingPlanId: widget.initialPlan?.id,
                  ),
                  otherPlansCount: provider.plannedCountForBook(
                    bookId,
                    excludingPlanId: widget.initialPlan?.id,
                  ),
                  thisPlan: _amountValue,
                ),
              ],

              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Judul rencana',
                  hintText: 'mis. Dana darurat',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Judul rencana wajib diisi';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 18),
              const _SectionLabel('Rincian'),
              const SizedBox(height: 10),
              _DetailGroup(
                children: [
                  _DetailRow(
                    label: 'Target',
                    value: DateFormat(
                      'dd MMM yyyy',
                      'id',
                    ).format(_selectedDate),
                    secondary: _relativeLabel(_selectedDate),
                    icon: Icons.event_rounded,
                    onTap: _pickDate,
                  ),
                  // Baris buku disembunyikan kalau memang cuma ada satu buku.
                  if (widget.targetBooks.length > 1)
                    _DetailRow(
                      label: 'Buku',
                      value: _bookLabel(bookId),
                      icon: Icons.menu_book_rounded,
                      onTap: _pickBook,
                    ),
                  _DetailRow(
                    label: 'Kategori',
                    value: _selectedCategory ?? 'Belum dipilih',
                    icon: Icons.category_rounded,
                    isPlaceholder: _selectedCategory == null,
                    showDivider: false,
                    onTap: _pickCategory,
                  ),
                ],
              ),

              const SizedBox(height: 20),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, null),
                    child: const Text('Batal'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: _submit,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        widget.actionLabel,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "6 bulan lagi" / "3 minggu lagi" — jarak waktu yang justru ingin diketahui,
/// menggantikan nama hari yang tidak berarti apa-apa untuk sebuah target.
String _relativeLabel(DateTime target) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(target.year, target.month, target.day);
  final days = date.difference(today).inDays;

  if (days < 0) return 'Sudah lewat';
  if (days == 0) return 'Hari ini';
  if (days == 1) return 'Besok';
  if (days < 30) return '$days hari lagi';

  final months = (days / 30).round();
  if (months < 12) return '$months bulan lagi';

  final years = (months / 12).floor();
  final restMonths = months % 12;
  if (restMonths == 0) return '$years tahun lagi';
  return '$years tahun $restMonths bulan lagi';
}

/// Target nominal sebagai elemen utama form.
///
/// Sejajar dengan nominal di form pengeluaran, tapi berwarna teal — ini target
/// yang dituju, bukan uang yang keluar.
class _TargetAmountField extends StatelessWidget {
  const _TargetAmountField({
    required this.controller,
    required this.autofocus,
    required this.parsePlanAmount,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool autofocus;
  final double? Function(String input) parsePlanAmount;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const targetColor = AppTheme.fabIconColor;

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
                autofocus: autofocus,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.next,
                inputFormatters: [RupiahInputFormatter()],
                style: theme.textTheme.displaySmall?.copyWith(
                  color: targetColor,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle: theme.textTheme.displaySmall?.copyWith(
                    color: theme.hintColor.withValues(alpha: 0.4),
                    fontWeight: FontWeight.w800,
                  ),
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
                  final amount = parsePlanAmount(value ?? '');
                  if (amount == null || amount <= 0) {
                    return 'Target nominal tidak valid';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        Container(height: 2, color: targetColor.withValues(alpha: 0.85)),
      ],
    );
  }
}

/// Target dibagi jarak waktu — "Rp 6 juta dalam 6 bulan" sulit dinilai,
/// "Rp 1 juta per bulan" langsung terasa realistis atau tidak.
class _PerMonthHint extends StatelessWidget {
  const _PerMonthHint({required this.amount, required this.months});

  final double amount;
  final int months;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (amount <= 0) {
      return Text(
        'Ketik angka, atau hitung langsung: 500k+1jt',
        style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
      );
    }

    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Text.rich(
      TextSpan(
        style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
        children: [
          const TextSpan(text: 'Sekitar '),
          TextSpan(
            text: formatter.format(amount / months),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: theme.textTheme.bodyMedium?.color,
            ),
          ),
          const TextSpan(text: ' per bulan selama '),
          TextSpan(
            text: '$months bulan',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: theme.textTheme.bodyMedium?.color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dampak rencana ini terhadap budget buku, terlihat saat mengetik.
///
/// Angka-angkanya sudah dihitung di kartu ringkasan dasbor, tapi baru terlihat
/// setelah rencana tersimpan — terlambat untuk mengubah keputusan. Sifatnya
/// memberi tahu, tidak memblokir penyimpanan.
class _BudgetImpact extends StatelessWidget {
  const _BudgetImpact({
    required this.budget,
    required this.otherPlansTotal,
    required this.otherPlansCount,
    required this.thisPlan,
  });

  final double budget;
  final double otherPlansTotal;
  final int otherPlansCount;
  final double thisPlan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Tanpa budget yang diketahui, tidak ada yang bisa dibandingkan.
    if (budget <= 0) return const SizedBox.shrink();

    final remaining = budget - otherPlansTotal - thisPlan;
    final isOver = remaining < 0;

    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: '',
      decimalDigits: 0,
    );

    final accent = isOver ? AppTheme.expenseRed : AppTheme.incomeGreen;
    final tint = isOver ? AppTheme.expenseLight : AppTheme.incomeLight;
    final onTint = isOver ? const Color(0xFF7A3636) : const Color(0xFF215E38);

    Widget line(String label, String value, {bool emphasize = false}) {
      final style = theme.textTheme.bodySmall?.copyWith(
        color: emphasize ? accent : onTint,
        fontWeight: emphasize ? FontWeight.w800 : FontWeight.w500,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
      return Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Row(
          children: [
            Expanded(child: Text(label, style: style)),
            Text(value, style: style),
          ],
        ),
      );
    }

    return Semantics(
      label: isOver
          ? 'Target melebihi budget buku sebesar ${formatter.format(remaining.abs())} rupiah'
          : 'Sisa budget buku ${formatter.format(remaining)} rupiah',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            line('Budget buku', formatter.format(budget)),
            if (otherPlansCount > 0)
              line(
                'Rencana lain ($otherPlansCount)',
                formatter.format(otherPlansTotal),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Divider(
                height: 1,
                thickness: 1,
                color: accent.withValues(alpha: 0.35),
              ),
            ),
            line(
              isOver ? 'Kelebihan' : 'Sisa',
              isOver
                  ? '−${formatter.format(remaining.abs())}'
                  : formatter.format(remaining),
              emphasize: true,
            ),
          ],
        ),
      ),
    );
  }
}

/// Label seksi: huruf besar kecil-renggang dengan garis rambut.
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

/// Satu baris pilihan — membuka sheet, bukan memunculkan keyboard.
class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.secondary,
    this.isPlaceholder = false,
    this.showDivider = true,
  });

  final String label;
  final String value;
  final String? secondary;
  final IconData icon;
  final VoidCallback onTap;
  final bool isPlaceholder;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sub = secondary;

    return Semantics(
      button: true,
      label: sub == null ? '$label: $value' : '$label: $value, $sub',
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
                    width: 66,
                    child: Text(
                      label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.hintColor,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
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
                        if (sub != null)
                          Text(
                            sub,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.hintColor,
                            ),
                          ),
                      ],
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
