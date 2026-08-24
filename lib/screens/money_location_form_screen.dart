import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/money_location.dart';
import '../providers/transaction_provider.dart';
import '../theme/app_theme.dart';
import '../utils/icon_picker_utils.dart';
import '../utils/rupiah_input_formatter.dart';
import '../widgets/global_action_overlay.dart';

/// Form tambah/ubah lokasi penyimpanan uang.
///
/// Ikon dan tata letaknya sengaja mengikuti [PocketFormScreen] supaya dua
/// layar yang sama-sama "bikin wadah uang" tidak terasa datang dari aplikasi
/// berbeda.
class MoneyLocationFormScreen extends StatefulWidget {
  const MoneyLocationFormScreen({super.key, this.location});

  /// Null berarti membuat lokasi baru.
  final MoneyLocation? location;

  @override
  State<MoneyLocationFormScreen> createState() =>
      _MoneyLocationFormScreenState();
}

class _MoneyLocationFormScreenState extends State<MoneyLocationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _initialBalanceController;

  late String _selectedIcon;

  bool get _isEditing => widget.location?.id != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.location?.name ?? '');
    _selectedIcon = widget.location?.icon ?? 'wallet';

    final initialBalance = widget.location?.initialBalance ?? 0;
    _initialBalanceController = TextEditingController(
      text: initialBalance > 0
          ? NumberFormat.decimalPattern('id_ID').format(initialBalance)
          : '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _initialBalanceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<TransactionProvider>();
    final name = _nameController.text.trim();
    final initialBalance = RupiahInputFormatter.parse(
      _initialBalanceController.text,
    );

    await GlobalActionOverlay.run(() async {
      final existing = widget.location;
      if (existing == null || existing.id == null) {
        await provider.addMoneyLocation(
          name: name,
          icon: _selectedIcon,
          initialBalance: initialBalance,
        );
      } else {
        await provider.updateMoneyLocation(
          existing.copyWith(
            name: name,
            icon: _selectedIcon,
            initialBalance: initialBalance,
          ),
        );
      }

      if (mounted) Navigator.pop(context, true);
    });
  }

  Future<void> _openIconPicker() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final icons = IconPickerUtils.getAllIconNames();
        final theme = Theme.of(sheetContext);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Pilih Ikon Lokasi',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: GridView.builder(
                    shrinkWrap: true,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 2.5,
                        ),
                    itemCount: icons.length,
                    itemBuilder: (context, index) {
                      final iconName = icons[index];
                      final isSelected = _selectedIcon == iconName;

                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => Navigator.pop(sheetContext, iconName),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? theme.colorScheme.primaryContainer
                                : theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.primaryBlue
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                IconPickerUtils.getLucideIcon(iconName),
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _humanizeIconName(iconName),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isSelected
                                        ? AppTheme.primaryBlue
                                        : theme.textTheme.bodyMedium?.color,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
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

    if (selected != null && mounted) {
      setState(() => _selectedIcon = selected);
    }
  }

  static String _humanizeIconName(String iconName) => iconName
      .split('_')
      .map((part) => part.isEmpty ? '' : '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Ubah Lokasi Uang' : 'Tambah Lokasi Uang',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: theme.iconTheme,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Semantics(
                  button: true,
                  label: 'Ubah ikon lokasi, sekarang ${_humanizeIconName(_selectedIcon)}',
                  child: InkWell(
                    onTap: _openIconPicker,
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.primaryBlue,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          IconPickerUtils.getLucideIcon(_selectedIcon),
                          size: 38,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Ketuk untuk ubah ikon',
                  style: theme.textTheme.labelSmall,
                ),
              ),
              const SizedBox(height: 32),

              Text(
                'Nama Lokasi',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'Cth: Dompet, Rekening BCA, Gopay',
                  filled: true,
                  fillColor: theme.cardTheme.color,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Nama lokasi tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              Text(
                'Saldo Awal',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Uang yang sudah ada di sini sebelum kamu mulai mencatat. '
                'Kosongkan kalau mulai dari nol.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withValues(
                    alpha: 0.7,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _initialBalanceController,
                keyboardType: TextInputType.number,
                inputFormatters: [RupiahInputFormatter()],
                decoration: InputDecoration(
                  hintText: 'Cth: 200.000',
                  prefixText: 'Rp ',
                  filled: true,
                  fillColor: theme.cardTheme.color,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return null;
                  if (RupiahInputFormatter.parse(value) < 0) {
                    return 'Saldo awal tidak boleh negatif';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Simpan Lokasi',
                    style: TextStyle(
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
      ),
    );
  }
}
