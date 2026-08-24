import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../providers/transaction_provider.dart';
import '../theme/app_theme.dart';
import '../utils/error_message.dart';
import '../utils/icon_picker_utils.dart';
import '../utils/money_location_balance.dart';
import '../utils/rupiah_input_formatter.dart';
import '../widgets/global_action_overlay.dart';
import '../widgets/money_location_picker.dart';
import 'money_location_form_screen.dart';

/// Form pindah uang antar lokasi — tarik tunai, setor tunai, top-up e-wallet.
///
/// Yang dicatat di sini bukan pemasukan atau pengeluaran, cuma perpindahan
/// tempat. Karena itu tidak ada pilihan kategori, rencana, atau kantong:
/// menawarkannya justru akan menyiratkan uangnya keluar dari anggaran.
class MoneyTransferScreen extends StatefulWidget {
  const MoneyTransferScreen({super.key});

  @override
  State<MoneyTransferScreen> createState() => _MoneyTransferScreenState();
}

class _MoneyTransferScreenState extends State<MoneyTransferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  int? _fromLocationId;
  int? _toLocationId;
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  static final NumberFormat _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _amountController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  double get _amount => RupiahInputFormatter.parse(_amountController.text);

  Future<void> _pickLocation({required bool isSource}) async {
    final choice = await showMoneyLocationPicker(
      context: context,
      selectedId: isSource ? _fromLocationId : _toLocationId,
      title: isSource ? 'Uang diambil dari mana?' : 'Dipindahkan ke mana?',
      noneSubtitle: 'Kosongkan pilihan',
    );

    if (!mounted || choice == null) return;
    setState(() {
      if (isSource) {
        _fromLocationId = choice.locationId;
      } else {
        _toLocationId = choice.locationId;
      }
    });
  }

  /// Tarik tunai dan setor tunai adalah gerakan yang sama dengan arah
  /// terbalik, jadi menukar dua sisi lebih cepat daripada memilih ulang.
  void _swap() {
    setState(() {
      final previousFrom = _fromLocationId;
      _fromLocationId = _toLocationId;
      _toLocationId = previousFrom;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final from = _fromLocationId;
    final to = _toLocationId;
    if (from == null || to == null) return;

    setState(() => _isSaving = true);
    try {
      await GlobalActionOverlay.run(() async {
        await context.read<TransactionProvider>().addMoneyTransfer(
          fromLocationId: from,
          toLocationId: to,
          amount: _amount,
          date: _selectedDate,
          note: _noteController.text,
        );
        if (mounted) Navigator.pop(context, true);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<TransactionProvider>();
    final summaries = provider.moneyLocationSummaries;

    // Lokasi yang dihapus di layar lain tidak boleh menyisakan pilihan hantu.
    if (_fromLocationId != null &&
        !summaries.any((item) => item.id == _fromLocationId)) {
      _fromLocationId = null;
    }
    if (_toLocationId != null &&
        !summaries.any((item) => item.id == _toLocationId)) {
      _toLocationId = null;
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Pindah Uang',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: theme.iconTheme,
      ),
      body: summaries.length < 2
          ? _NeedTwoLocations(count: summaries.length)
          : _buildForm(theme, summaries),
    );
  }

  Widget _buildForm(ThemeData theme, List<MoneyLocationSummary> summaries) {
    final from = _findSummary(summaries, _fromLocationId);
    final to = _findSummary(summaries, _toLocationId);
    final isSameLocation =
        _fromLocationId != null && _fromLocationId == _toLocationId;
    final exceedsBalance =
        from != null && _amount > 0 && _amount > from.balance;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LocationField(
              label: 'Dari',
              summary: from,
              placeholder: 'Pilih lokasi asal',
              onTap: () => _pickLocation(isSource: true),
            ),
            const SizedBox(height: 8),
            Center(
              child: IconButton.filledTonal(
                onPressed: _swap,
                tooltip: 'Tukar lokasi asal dan tujuan',
                icon: const Icon(LucideIcons.arrowUpDown, size: 18),
              ),
            ),
            const SizedBox(height: 8),
            _LocationField(
              label: 'Ke',
              summary: to,
              placeholder: 'Pilih lokasi tujuan',
              onTap: () => _pickLocation(isSource: false),
            ),

            if (isSameLocation) ...[
              const SizedBox(height: 10),
              _InlineNote(
                icon: LucideIcons.circleAlert,
                text: 'Lokasi asal dan tujuan tidak boleh sama.',
                color: theme.colorScheme.error,
              ),
            ],

            const SizedBox(height: 22),
            Text(
              'Nominal',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [RupiahInputFormatter()],
              decoration: InputDecoration(
                hintText: 'Cth: 500.000',
                prefixText: 'Rp ',
                filled: true,
                fillColor: theme.cardTheme.color,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Nominal wajib diisi';
                }
                if (RupiahInputFormatter.parse(value) <= 0) {
                  return 'Nominal tidak valid';
                }
                if (_fromLocationId == null || _toLocationId == null) {
                  return 'Pilih lokasi asal dan tujuan dulu';
                }
                if (_fromLocationId == _toLocationId) {
                  return 'Lokasi asal dan tujuan tidak boleh sama';
                }
                return null;
              },
            ),

            // Peringatan, bukan larangan: uang tunai sering sudah berpindah
            // lebih dulu sebelum sempat dicatat, jadi memblokirnya hanya
            // memaksa pengguna berbohong pada catatannya sendiri.
            if (exceedsBalance) ...[
              const SizedBox(height: 10),
              _InlineNote(
                icon: LucideIcons.info,
                text:
                    'Nominalnya melebihi saldo ${from.name} '
                    '(${_currency.format(from.balance)}). Tetap bisa disimpan '
                    'kalau memang begitu keadaannya.',
                color: theme.textTheme.bodySmall?.color,
              ),
            ],

            const SizedBox(height: 22),
            Text(
              'Tanggal',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: InputDecoration(
                  filled: true,
                  fillColor: theme.cardTheme.color,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(LucideIcons.calendar, size: 18),
                ),
                child: Text(
                  DateFormat('dd MMM yyyy', 'id').format(_selectedDate),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),

            const SizedBox(height: 22),
            Text(
              'Catatan (opsional)',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _noteController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Cth: Tarik tunai di ATM dekat kantor',
                filled: true,
                fillColor: theme.cardTheme.color,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 14),
            _InlineNote(
              icon: LucideIcons.info,
              text:
                  'Perpindahan tidak dihitung sebagai pemasukan maupun '
                  'pengeluaran — uangnya cuma ganti tempat.',
              color: theme.textTheme.bodySmall?.color,
            ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _isSaving ? 'Menyimpan...' : 'Simpan Perpindahan',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static MoneyLocationSummary? _findSummary(
    List<MoneyLocationSummary> summaries,
    int? id,
  ) {
    if (id == null) return null;
    for (final summary in summaries) {
      if (summary.id == id) return summary;
    }
    return null;
  }
}

class _LocationField extends StatelessWidget {
  const _LocationField({
    required this.label,
    required this.summary,
    required this.placeholder,
    required this.onTap,
  });

  final String label;
  final MoneyLocationSummary? summary;
  final String placeholder;
  final VoidCallback onTap;

  static final NumberFormat _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = summary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          button: true,
          label: selected == null
              ? '$label, belum dipilih'
              : '$label, ${selected.name}',
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius: BorderRadius.circular(12),
                border: theme
                    .extension<AppThemeExtension>()
                    ?.cardBorder,
              ),
              child: Row(
                children: [
                  Icon(
                    selected == null
                        ? LucideIcons.circleHelp
                        : IconPickerUtils.getLucideIcon(selected.icon),
                    size: 20,
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selected?.name ?? placeholder,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: selected == null
                                ? theme.textTheme.bodyMedium?.color
                                      ?.withValues(alpha: 0.55)
                                : null,
                          ),
                        ),
                        if (selected != null)
                          Text(
                            'Sisa ${_currency.format(selected.balance)}',
                            style: theme.textTheme.labelSmall,
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.expand_more_rounded),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InlineNote extends StatelessWidget {
  const _InlineNote({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

/// Pindah uang butuh dua tempat. Daripada menampilkan form yang mustahil
/// diselesaikan, layarnya menyebut apa yang kurang dan menawarkan jalannya.
class _NeedTwoLocations extends StatelessWidget {
  const _NeedTwoLocations({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.arrowLeftRight,
              size: 48,
              color: theme.textTheme.bodySmall?.color,
            ),
            const SizedBox(height: 16),
            Text(
              'Butuh dua lokasi dulu',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              count == 0
                  ? 'Belum ada lokasi uang sama sekali. Buat dua dulu — '
                        'misalnya Dompet dan Rekening — baru uangnya bisa '
                        'dipindahkan.'
                  : 'Baru ada satu lokasi. Tambah satu lagi supaya uangnya '
                        'punya tempat untuk dituju.',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MoneyLocationFormScreen(),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(LucideIcons.plus, size: 18),
              label: const Text('Tambah Lokasi'),
            ),
          ],
        ),
      ),
    );
  }
}
