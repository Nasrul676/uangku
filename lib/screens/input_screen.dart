import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/transaction_provider.dart';
import 'settings_screen.dart';

class InputScreen extends StatefulWidget {
  const InputScreen({super.key, this.initialType = 'EXPENSE'});

  final String initialType;

  @override
  State<InputScreen> createState() => _InputScreenState();
}

class _InputScreenState extends State<InputScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();

  String _type = 'EXPENSE';
  String _category = 'Pengeluaran';
  DateTime _selectedDate = DateTime.now();
  TimeOfDay? _selectedTime;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType == 'INCOME' ? 'INCOME' : 'EXPENSE';
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
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<TransactionProvider>();
    await provider.addTransaction(
      title: _titleController.text.trim(),
      amount: double.parse(_amountController.text.trim()),
      type: _type,
      category: _category,
      date: _selectedDate,
      time: _selectedTime == null
          ? null
          : _formatTimeForStorage(_selectedTime!),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Transaksi disimpan ke SQLite.')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFE6EBFA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Input Transaksi',
                      style: theme.textTheme.titleLarge?.copyWith(fontSize: 34),
                    ),
                  ),
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
                          Text(
                            'Tipe',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontSize: 24,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _TypeToggle(
                                  label: 'Pemasukan',
                                  selected: _type == 'INCOME',
                                  selectedColor: const Color(0xFFA4DBB2),
                                  onTap: () => setState(() => _type = 'INCOME'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _TypeToggle(
                                  label: 'Pengeluaran',
                                  selected: _type == 'EXPENSE',
                                  selectedColor: const Color(0xFFF0C8C8),
                                  selectedTextColor: const Color(0xFFC24545),
                                  onTap: () =>
                                      setState(() => _type = 'EXPENSE'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: _pickDate,
                            borderRadius: BorderRadius.circular(12),
                            child: InputDecorator(
                              decoration: _fieldDecoration(
                                'Tanggal',
                                Icons.calendar_today_rounded,
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
                              decoration: _fieldDecoration(
                                'Jam',
                                Icons.access_time_rounded,
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
                            controller: _titleController,
                            decoration: _fieldDecoration(
                              'Judul transaksi',
                              Icons.title_rounded,
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
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: _fieldDecoration(
                              'Nominal',
                              Icons.payments_rounded,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Nominal wajib diisi';
                              }
                              final amount = double.tryParse(value);
                              if (amount == null || amount <= 0) {
                                return 'Nominal tidak valid';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          Consumer<TransactionProvider>(
                            builder: (context, provider, _) {
                              final categories = _type == 'INCOME'
                                  ? provider.incomeCategories
                                  : provider.expenseCategories;

                              if (categories.isNotEmpty &&
                                  !categories.contains(_category)) {
                                _category = categories.first;
                              }

                              return DropdownButtonFormField<String>(
                                initialValue: _category,
                                decoration: _fieldDecoration(
                                  'Kategori',
                                  Icons.category_rounded,
                                ),
                                items: categories
                                    .map(
                                      (value) => DropdownMenuItem(
                                        value: value,
                                        child: Text(value),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _category = value);
                                  }
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            height: 52,
                            child: FilledButton(
                              onPressed: _save,
                              child: const Text('Simpan ke SQLite'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(
                height: 100,
              ), // Transparent space for navbar clearance
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon),
      fillColor: Colors.white,
    );
  }
}

class _TypeToggle extends StatelessWidget {
  const _TypeToggle({
    required this.label,
    required this.selected,
    required this.onTap,
    this.selectedColor,
    this.selectedTextColor,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? selectedColor;
  final Color? selectedTextColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? (selectedColor ?? const Color(0xFFA4DBB2))
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Theme.of(context).extension<AppThemeExtension>()?.cardBorder,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected ? selectedTextColor : null,
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
          color: Colors.white,
          shape: BoxShape.circle,
          border: Theme.of(context).extension<AppThemeExtension>()?.cardBorder,
        ),
        child: Icon(icon, size: 18),
      ),
    );
  }
}
