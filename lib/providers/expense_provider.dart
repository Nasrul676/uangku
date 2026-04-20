import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/expense.dart';
import '../services/sheet_api_service.dart';
import 'package:intl/intl.dart';

class ExpenseProvider extends ChangeNotifier {
  // ── Form state ──────────────────────────────────────────────────────
  DateTime _selectedDate = DateTime.now();
  String _category = 'Pengeluaran';
  String _amount = '';
  String _qty = '1';
  String _notes = '';

  // ── API state ───────────────────────────────────────────────────────
  bool _isLoading = false;
  String? _errorMessage;
  bool _isSuccess = false;

  // ── Settings ────────────────────────────────────────────────────────
  String _webAppUrl = '';

  // ── Getters ─────────────────────────────────────────────────────────
  DateTime get selectedDate => _selectedDate;
  String get category => _category;
  String get amount => _amount;
  String get qty => _qty;
  String get notes => _notes;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isSuccess => _isSuccess;
  String get webAppUrl => _webAppUrl;

  // ── Category options (40-40-20 scheme) ──────────────────────────────
  final List<String> categories = [
    'Pengeluaran',
    'Tabungan/Investasi',
    'Needs',
  ];

  // ── Initialize: load saved URL ──────────────────────────────────────
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _webAppUrl = prefs.getString('web_app_url') ?? '';
    notifyListeners();
  }

  // ── Setters ─────────────────────────────────────────────────────────
  void setDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  void setCategory(String cat) {
    _category = cat;
    notifyListeners();
  }

  void setAmount(String val) {
    _amount = val;
  }

  void setQty(String val) {
    _qty = val;
  }

  void setNotes(String val) {
    _notes = val;
  }

  // ── Save URL to SharedPreferences ───────────────────────────────────
  Future<void> saveUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('web_app_url', url);
    _webAppUrl = url;
    notifyListeners();
  }

  // ── Submit expense to Google Sheets ─────────────────────────────────
  Future<void> submitExpense() async {
    _errorMessage = null;
    _isSuccess = false;

    // Validate URL
    if (_webAppUrl.isEmpty) {
      _errorMessage = 'URL belum diatur. Buka Settings terlebih dahulu.';
      notifyListeners();
      return;
    }

    // Validate amount
    final nominal = double.tryParse(_amount);
    if (nominal == null || nominal <= 0) {
      _errorMessage = 'Nominal harus berupa angka yang valid.';
      notifyListeners();
      return;
    }

    // Validate qty
    final qtyVal = int.tryParse(_qty);
    if (qtyVal == null || qtyVal <= 0) {
      _errorMessage = 'Qty harus berupa angka yang valid.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final expense = Expense(
        tanggal: DateFormat('yyyy-MM-dd').format(_selectedDate),
        kategori: _category,
        nominal: nominal,
        qty: qtyVal,
        keterangan: _notes,
      );

      await SheetApiService.postExpense(_webAppUrl, expense);
      _isSuccess = true;
      _resetForm();
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _resetForm() {
    _selectedDate = DateTime.now();
    _category = 'Pengeluaran';
    _amount = '';
    _qty = '1';
    _notes = '';
  }

  /// Clears any transient success/error state so SnackBars don't re-fire.
  void clearStatus() {
    _isSuccess = false;
    _errorMessage = null;
  }
}
