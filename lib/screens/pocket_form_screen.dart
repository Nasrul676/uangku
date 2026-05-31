import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';
import '../utils/icon_picker_utils.dart';
import '../utils/rupiah_input_formatter.dart';
import '../widgets/global_action_overlay.dart';
import '../models/pocket.dart';
import 'package:intl/intl.dart';

class PocketFormScreen extends StatefulWidget {
  final Pocket? pocket;

  const PocketFormScreen({super.key, this.pocket});

  @override
  State<PocketFormScreen> createState() => _PocketFormScreenState();
}

class _PocketFormScreenState extends State<PocketFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _valueController;
  
  String _selectedIcon = 'wallet';
  String _allocationType = 'PERCENTAGE';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.pocket?.name ?? '');
    
    _allocationType = widget.pocket?.allocationType ?? 'PERCENTAGE';
    _selectedIcon = widget.pocket?.icon ?? 'wallet';
    
    final val = widget.pocket?.allocationValue ?? 0;
    if (_allocationType == 'NOMINAL') {
      _valueController = TextEditingController(
        text: val > 0 ? NumberFormat.decimalPattern('id_ID').format(val) : '',
      );
    } else {
      _valueController = TextEditingController(
        text: val > 0 ? (val % 1 == 0 ? val.toInt().toString() : val.toString()) : '',
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  void _savePocket() async {
    if (_formKey.currentState!.validate()) {
      final provider = Provider.of<TransactionProvider>(context, listen: false);
      final bookId = provider.selectedBookPeriodId ?? provider.activeBookPeriod?.id;
      
      if (bookId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pilih buku terlebih dahulu')),
        );
        return;
      }

      final value = _allocationType == 'NOMINAL' 
          ? RupiahInputFormatter.parse(_valueController.text)
          : (double.tryParse(_valueController.text.replaceAll(',', '.')) ?? 0);
      
      await GlobalActionOverlay.run(() async {
        if (widget.pocket == null) {
          await provider.addPocket(
            bookPeriodId: bookId,
            name: _nameController.text,
            icon: _selectedIcon,
            allocationType: _allocationType,
            allocationValue: value,
          );
        } else {
          final updatedPocket = widget.pocket!.copyWith(
            name: _nameController.text,
            icon: _selectedIcon,
            allocationType: _allocationType,
            allocationValue: value,
          );
          await provider.updatePocket(updatedPocket);
        }
        
        if (mounted) {
          Navigator.pop(context);
        }
      });
    }
  }

  void _showIconPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final icons = IconPickerUtils.getAllIconNames();
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Pilih Ikon Kantong',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 2.5,
                  ),
                  itemCount: icons.length,
                  itemBuilder: (context, index) {
                    final iconName = icons[index];
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedIcon = iconName;
                        });
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: _selectedIcon == iconName 
                              ? const Color(0xFFE5F0FF) 
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: _selectedIcon == iconName
                              ? Border.all(color: const Color(0xFF0066FF), width: 2)
                              : Border.all(color: Colors.transparent, width: 2),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              IconPickerUtils.getIcon(iconName),
                              style: const TextStyle(fontSize: 24),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                iconName.split('_').map((e) => e.isEmpty ? '' : '${e[0].toUpperCase()}${e.substring(1)}').join(' '),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: _selectedIcon == iconName ? FontWeight.bold : FontWeight.normal,
                                  color: _selectedIcon == iconName ? const Color(0xFF0066FF) : Colors.grey.shade700,
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.pocket == null ? 'Buat Kantong Baru' : 'Edit Kantong',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: Theme.of(context).iconTheme,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon Picker
              Center(
                child: GestureDetector(
                  onTap: _showIconPicker,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5F0FF),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF0066FF), width: 2),
                    ),
                    child: Center(
                      child: Text(
                        IconPickerUtils.getIcon(_selectedIcon),
                        style: const TextStyle(fontSize: 40),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Ketuk untuk ubah ikon',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
              const SizedBox(height: 32),
              
              // Name Input
              const Text(
                'Nama Kantong',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'Cth: Dana Darurat, Biaya Makan',
                  filled: true,
                  fillColor: Theme.of(context).cardTheme.color ?? Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Nama kantong tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              
              // Allocation Type Switcher
              const Text(
                'Tipe Alokasi',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (_allocationType != 'PERCENTAGE') {
                          setState(() {
                            _allocationType = 'PERCENTAGE';
                            _valueController.clear();
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _allocationType == 'PERCENTAGE' ? const Color(0xFF0066FF) : (Theme.of(context).cardTheme.color ?? Colors.white),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _allocationType == 'PERCENTAGE' ? const Color(0xFF0066FF) : Theme.of(context).dividerColor,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'Persentase (%)',
                            style: TextStyle(
                              color: _allocationType == 'PERCENTAGE' ? Colors.white : (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (_allocationType != 'NOMINAL') {
                          setState(() {
                            _allocationType = 'NOMINAL';
                            _valueController.clear();
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _allocationType == 'NOMINAL' ? const Color(0xFF0066FF) : (Theme.of(context).cardTheme.color ?? Colors.white),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _allocationType == 'NOMINAL' ? const Color(0xFF0066FF) : Theme.of(context).dividerColor,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'Nominal Tetap (Rp)',
                            style: TextStyle(
                              color: _allocationType == 'NOMINAL' ? Colors.white : (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Value Input
              Text(
                _allocationType == 'PERCENTAGE' ? 'Persentase Alokasi (%)' : 'Nominal Target (Rp)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _valueController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: _allocationType == 'NOMINAL' ? [RupiahInputFormatter()] : [],
                decoration: InputDecoration(
                  hintText: _allocationType == 'PERCENTAGE' ? 'Cth: 20' : 'Cth: 500.000',
                  filled: true,
                  fillColor: Theme.of(context).cardTheme.color ?? Colors.white,
                  suffixText: _allocationType == 'PERCENTAGE' ? '%' : '',
                  prefixText: _allocationType == 'NOMINAL' ? 'Rp ' : '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Nilai tidak boleh kosong';
                  }
                  if (_allocationType == 'PERCENTAGE') {
                    final parsed = double.tryParse(value.replaceAll(',', '.'));
                    if (parsed == null || parsed <= 0) {
                      return 'Nilai tidak valid';
                    }
                    if (parsed > 100) {
                      return 'Persentase maksimal 100%';
                    }
                  } else {
                    final parsed = RupiahInputFormatter.parse(value);
                    if (parsed <= 0) {
                      return 'Nilai tidak valid';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _savePocket,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0066FF),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Simpan Kantong',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
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
