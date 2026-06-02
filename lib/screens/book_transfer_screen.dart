import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/transaction_provider.dart';
import '../theme/app_theme.dart';
import '../utils/rupiah_input_formatter.dart';
import '../widgets/global_action_overlay.dart';

class BookTransferScreen extends StatefulWidget {
  const BookTransferScreen({super.key});

  @override
  State<BookTransferScreen> createState() => _BookTransferScreenState();
}

class _BookTransferScreenState extends State<BookTransferScreen> {
  final _formKey = GlobalKey<FormState>();
  
  int? _sourceBookId;
  int? _targetBookId;
  String? _targetCategory;
  DateTime _selectedDate = DateTime.now();
  
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  
  bool _isTransferAll = true; // Default transfer semua
  double _sourceBalance = 0;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<TransactionProvider>(context, listen: false);
      final activeId = provider.activeBookPeriod?.id;
      if (activeId != null) {
        setState(() {
          _sourceBookId = activeId;
          _sourceBalance = provider.getBookBalance(activeId);
          _updateAmountField();
        });
      }
    });
    
    // Matikan transfer semua kalau user ketik manual
    _amountController.addListener(() {
      if (_amountController.text.isNotEmpty) {
        final unformattedAmount = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
        final amount = double.tryParse(unformattedAmount) ?? 0;
        if (amount != _sourceBalance && _isTransferAll) {
          setState(() {
            _isTransferAll = false;
          });
        }
      }
    });
  }

  void _updateAmountField() {
    if (_isTransferAll && _sourceBalance > 0) {
      final formatter = NumberFormat.currency(
        locale: 'id_ID', 
        symbol: '', 
        decimalDigits: 0,
      );
      _amountController.text = formatter.format(_sourceBalance).trim();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: const Color(0xFF0066FF),
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_sourceBookId == _targetBookId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Buku sumber dan tujuan tidak boleh sama!'),
          backgroundColor: AppTheme.expenseRed,
        ),
      );
      return;
    }
    
    final unformattedAmount = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final amount = double.tryParse(unformattedAmount) ?? 0;
    
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nominal transfer tidak valid!'),
          backgroundColor: AppTheme.expenseRed,
        ),
      );
      return;
    }
    
    await GlobalActionOverlay.run(() async {
      await Provider.of<TransactionProvider>(context, listen: false)
          .transferBetweenBooks(
        sourceBookId: _sourceBookId!,
        targetBookId: _targetBookId!,
        amount: amount,
        date: _selectedDate,
        notes: _notesController.text.trim(),
        targetCategory: _targetCategory ?? 'Transfer Masuk',
      );
    });
    
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final provider = Provider.of<TransactionProvider>(context);
    final allBooks = provider.bookPeriods.toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Transfer Antar Buku',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Buku Sumber
              Text(
                'Buku Sumber (Pengeluaran)',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: _sourceBookId,
                items: allBooks.map((b) {
                  return DropdownMenuItem(
                    value: b.id,
                    child: Text(b.label),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _sourceBookId = val;
                    if (val != null) {
                      _sourceBalance = provider.getBookBalance(val);
                      _updateAmountField();
                    }
                  });
                },
                validator: (val) => val == null ? 'Pilih buku sumber' : null,
                decoration: _buildInputDecoration(theme),
              ),
              if (_sourceBookId != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 4),
                  child: Text(
                    'Sisa Saldo: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(_sourceBalance)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _sourceBalance < 0 ? AppTheme.expenseRed : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              const SizedBox(height: 20),

              // Buku Tujuan
              Text(
                'Buku Tujuan (Pemasukan)',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: _targetBookId,
                items: allBooks.map((b) {
                  return DropdownMenuItem(
                    value: b.id,
                    child: Text(b.label),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _targetBookId = val;
                    if (_targetBookId != null && _targetCategory == null) {
                      _targetCategory = 'Transfer Masuk';
                    }
                  });
                },
                validator: (val) => val == null ? 'Pilih buku tujuan' : null,
                decoration: _buildInputDecoration(theme),
              ),
              const SizedBox(height: 20),

              if (_targetBookId != null) ...[
                // Kategori Pemasukan
                Text(
                  'Kategori Pemasukan',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _targetCategory,
                  items: [
                    const DropdownMenuItem(
                      value: 'Transfer Masuk',
                      child: Text('Transfer Masuk (Default)'),
                    ),
                    ...provider.incomeCategories
                        .where((c) => c != 'Transfer Masuk')
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c),
                            )),
                  ],
                  onChanged: (val) {
                    setState(() => _targetCategory = val);
                  },
                  validator: (val) => val == null ? 'Pilih kategori' : null,
                  decoration: _buildInputDecoration(theme).copyWith(
                    hintText: 'Pilih kategori pemasukan',
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Nominal
              Text(
                'Nominal Transfer',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.text,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0066FF),
                ),
                decoration: _buildInputDecoration(theme).copyWith(
                  prefixText: 'Rp ',
                  prefixStyle: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0066FF),
                  ),
                ),
                inputFormatters: [RupiahInputFormatter()],
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Wajib diisi';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _isTransferAll,
                onChanged: (val) {
                  setState(() {
                    _isTransferAll = val ?? false;
                    if (_isTransferAll) {
                      _updateAmountField();
                    }
                  });
                },
                title: const Text('Transfer semua sisa saldo'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
                visualDensity: VisualDensity.compact,
                activeColor: const Color(0xFF0066FF),
              ),
              const SizedBox(height: 20),
              
              // Tanggal
              Text(
                'Tanggal Transfer',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _selectDate(context),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Theme.of(context).extension<AppThemeExtension>()?.cardBorder,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_month_rounded,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        DateFormat('dd MMMM yyyy', 'id').format(_selectedDate),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Catatan
              Text(
                'Catatan (Opsional)',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesController,
                textCapitalization: TextCapitalization.sentences,
                decoration: _buildInputDecoration(theme).copyWith(
                  hintText: 'Mis: Transfer sisa dana',
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Tombol Simpan
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0066FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Simpan Transfer',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return InputDecoration(
      filled: true,
      fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xFF0066FF),
          width: 2,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
    );
  }
}
