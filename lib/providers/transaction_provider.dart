import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';

import '../models/book_period.dart';
import '../models/finance_transaction.dart';
import '../models/financial_plan_input.dart';
import '../models/financial_plan.dart';
import '../services/app_settings_service.dart';
import '../services/database_helper.dart';
import '../services/home_balance_widget_service.dart';
import '../services/notification_service.dart';
import '../services/sync_api_service.dart';

class TransactionProvider extends ChangeNotifier {
  TransactionProvider({
    DatabaseHelper? databaseHelper,
    AppSettingsService? settingsService,
    SyncApiService? syncApiService,
    NotificationService? notificationService,
  }) : _databaseHelper = databaseHelper ?? DatabaseHelper.instance,
       _settingsService = settingsService ?? AppSettingsService(),
       _syncApiService = syncApiService ?? SyncApiService(),
       _notificationService =
           notificationService ?? NotificationService.instance;

  final DatabaseHelper _databaseHelper;
  final AppSettingsService _settingsService;
  final SyncApiService _syncApiService;
  final NotificationService _notificationService;
  final HomeBalanceWidgetService _homeBalanceWidgetService =
      HomeBalanceWidgetService.instance;

  List<String> _incomeCategories = AppSettingsService.defaultIncomeCategories;
  List<String> _expenseCategories = AppSettingsService.defaultExpenseCategories;

  List<FinanceTransaction> _allTransactions = [];
  List<BookPeriod> _bookPeriods = [];
  List<FinancialPlan> _allFinancialPlans = [];
  int? _selectedBookPeriodId;
  bool _isLoading = false;
  bool _isSyncing = false;
  String? _errorMessage;

  String _webAppUrl = '';
  String _payloadRootKey = 'transactions';
  Map<String, String> _jsonKeyMapping = AppSettingsService.defaultMapping;
  int _planNotificationHour = 8;
  int _planNotificationMinute = 0;
  bool _isBalanceHidden = false;
  bool _isRemovingBookPeriod = false;

  List<FinanceTransaction> get transactions {
    final selectedId = _selectedBookPeriodId;
    if (selectedId == null) return _allTransactions;
    return _allTransactions
        .where((tx) => tx.bookPeriodId == selectedId)
        .toList(growable: false);
  }

  List<BookPeriod> get bookPeriods => _bookPeriods;
  List<FinancialPlan> get financialPlans {
    final selectedId = _currentPlanScopeBookId;
    if (selectedId == null) return const [];
    return _allFinancialPlans
        .where((item) => item.bookPeriodId == selectedId)
        .toList(growable: false);
  }

  List<FinancialPlan> get activeBookFinancialPlans => financialPlans;

  int? get selectedBookPeriodId => _selectedBookPeriodId;
  BookPeriod? get activeBookPeriod {
    for (final period in _bookPeriods) {
      if (period.isOpen) return period;
    }
    return null;
  }

  bool get hasOpenBook => activeBookPeriod != null;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  String? get errorMessage => _errorMessage;
  String get webAppUrl => _webAppUrl;
  String get payloadRootKey => _payloadRootKey;
  Map<String, String> get jsonKeyMapping => _jsonKeyMapping;
  List<String> get incomeCategories => _incomeCategories;
  List<String> get expenseCategories => _expenseCategories;
  int get planNotificationHour => _planNotificationHour;
  int get planNotificationMinute => _planNotificationMinute;
  bool get isBalanceHidden => _isBalanceHidden;
  bool get isRemovingBookPeriod => _isRemovingBookPeriod;
  double get currentTotalIncome {
    final scoped = transactions;
    return scoped
        .where((tx) => tx.type == 'INCOME')
        .fold<double>(0, (sum, tx) => sum + tx.amount);
  }

  double get currentTotalExpense {
    final scoped = transactions;
    return scoped
        .where((tx) => tx.type == 'EXPENSE')
        .fold<double>(0, (sum, tx) => sum + tx.amount);
  }

  double get currentNetBalance {
    return currentTotalIncome - currentTotalExpense;
  }

  int get unsyncedCount =>
      _allTransactions.where((tx) => tx.isSynced == 0).length;

  Future<void> init() async {
    await _notificationService.init();
    await _notificationService.requestPermissions();
    await loadSettings();
    await loadBookPeriods();
    await loadFinancialPlans();
    await loadTransactions();
  }

  Future<void> loadTransactions() async {
    _isLoading = true;
    notifyListeners();

    try {
      _allTransactions = await _databaseHelper.getAllTransactions();
      unawaited(_syncHomeBalanceWidget());
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadBookPeriods() async {
    try {
      _bookPeriods = await _databaseHelper.getAllBookPeriods();
      _applySelectedBookPeriod();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      notifyListeners();
    }
  }

  Future<void> loadFinancialPlans() async {
    try {
      _allFinancialPlans = await _databaseHelper.getAllFinancialPlans();
      await _rescheduleFinancialPlanNotifications();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      notifyListeners();
    }
  }

  void selectBookPeriod(int? periodId) {
    if (periodId == null) {
      _applySelectedBookPeriod();
      notifyListeners();
      return;
    }

    final exists = _bookPeriods.any((item) => item.id == periodId);
    if (!exists) {
      _applySelectedBookPeriod();
      notifyListeners();
      return;
    }

    _selectedBookPeriodId = periodId;
    unawaited(_syncHomeBalanceWidget());
    notifyListeners();
  }

  Future<void> openBook({
    required DateTime startDate,
    String? label,
    List<FinancialPlanInput> initialPlans = const [],
  }) async {
    final openPeriod = await _databaseHelper.getOpenBookPeriod();
    if (openPeriod != null) {
      throw Exception(
        'Masih ada buku yang aktif ya. Tutup dulu bukunya, lalu lanjut lagi.',
      );
    }

    final normalizedStart = _normalizeDate(startDate);
    final periodLabel = (label ?? '').trim().isEmpty
        ? 'Buku ${DateFormat('dd MMM yyyy', 'id').format(normalizedStart)}'
        : label!.trim();

    for (final input in initialPlans) {
      if (input.title.trim().isEmpty || input.targetAmount <= 0) {
        throw Exception(
          'Rencana keuangan awalnya masih belum valid. Cek lagi, ya.',
        );
      }
    }

    final preparedPlans = initialPlans
        .map(
          (input) => FinancialPlan(
            bookPeriodId: -1,
            title: input.title.trim(),
            targetAmount: input.targetAmount,
            targetDate: DateFormat(
              'yyyy-MM-dd',
            ).format(_normalizeDate(input.targetDate)),
          ),
        )
        .toList(growable: false);

    final id = await _databaseHelper.createBookPeriodWithPlans(
      period: BookPeriod(
        label: periodLabel,
        startDate: DateFormat('yyyy-MM-dd').format(normalizedStart),
      ),
      initialPlans: preparedPlans,
    );

    await loadBookPeriods();
    await loadFinancialPlans();
    _selectedBookPeriodId = id;
    notifyListeners();
  }

  Future<void> closeActiveBook({required DateTime endDate}) async {
    final active = activeBookPeriod;
    if (active == null || active.id == null) {
      throw Exception('Belum ada buku aktif yang bisa ditutup.');
    }

    final start = DateTime.tryParse(active.startDate);
    final normalizedEnd = _normalizeDate(endDate);

    if (start != null && normalizedEnd.isBefore(_normalizeDate(start))) {
      throw Exception('Tanggal tutup belum bisa sebelum tanggal buka buku.');
    }

    await _databaseHelper.closeBookPeriod(
      bookPeriodId: active.id!,
      endDate: DateFormat('yyyy-MM-dd').format(normalizedEnd),
    );

    await loadBookPeriods();
  }

  Future<void> removeBookPeriod(int bookPeriodId) async {
    if (_isRemovingBookPeriod) {
      throw Exception('Lagi memproses hapus buku. Tunggu sebentar ya.');
    }

    final target = _bookPeriods.where((item) => item.id == bookPeriodId);
    if (target.isEmpty) {
      throw Exception('Buku yang dipilih belum ketemu.');
    }

    if (target.first.isOpen) {
      throw Exception(
        'Buku yang masih aktif harus ditutup dulu sebelum dihapus.',
      );
    }

    _isRemovingBookPeriod = true;
    notifyListeners();

    try {
      await _databaseHelper.deleteBookPeriod(bookPeriodId);

      _bookPeriods = _bookPeriods
          .where((item) => item.id != bookPeriodId)
          .toList(growable: false);
      _allFinancialPlans = _allFinancialPlans
          .where((item) => item.bookPeriodId != bookPeriodId)
          .toList(growable: false);
      _allTransactions = _allTransactions
          .where((item) => item.bookPeriodId != bookPeriodId)
          .toList(growable: false);

      _applySelectedBookPeriod();
      notifyListeners();

      unawaited(_syncHomeBalanceWidget());
      unawaited(_rescheduleFinancialPlanNotifications());
    } finally {
      _isRemovingBookPeriod = false;
      notifyListeners();
    }
  }

  Future<void> loadSettings() async {
    _webAppUrl = await _settingsService.getWebAppUrl();
    _payloadRootKey = await _settingsService.getPayloadRootKey();
    _jsonKeyMapping = await _settingsService.getJsonKeyMapping();
    _incomeCategories = await _settingsService.getIncomeCategories();
    _expenseCategories = await _settingsService.getExpenseCategories();
    _planNotificationHour = await _settingsService.getPlanNotificationHour();
    _planNotificationMinute = await _settingsService
        .getPlanNotificationMinute();
    _isBalanceHidden = await _settingsService.getHideBalance();
    notifyListeners();
  }

  Future<void> setBalanceHidden(bool value) async {
    _isBalanceHidden = value;
    await _settingsService.saveHideBalance(value);
    notifyListeners();
    unawaited(_syncHomeBalanceWidget());
  }

  Future<void> savePlanNotificationTime({
    required int hour,
    required int minute,
  }) async {
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      throw Exception('Jam notifikasi belum valid.');
    }

    await _settingsService.savePlanNotificationTime(hour: hour, minute: minute);
    _planNotificationHour = hour;
    _planNotificationMinute = minute;
    notifyListeners();
    await _rescheduleFinancialPlanNotifications();
  }

  Future<void> showFinancialPlanNotificationDemo() async {
    await _notificationService.showDemoNotification();
  }

  Future<void> saveSyncSettings({
    required String webAppUrl,
    required String payloadRootKey,
    required Map<String, String> jsonKeyMapping,
    required List<String> incomeCategories,
    required List<String> expenseCategories,
  }) async {
    await _settingsService.saveWebAppUrl(webAppUrl);
    await _settingsService.savePayloadRootKey(payloadRootKey);
    await _settingsService.saveJsonKeyMapping(jsonKeyMapping);
    await _settingsService.saveIncomeCategories(incomeCategories);
    await _settingsService.saveExpenseCategories(expenseCategories);

    _webAppUrl = webAppUrl;
    _payloadRootKey = payloadRootKey;
    _jsonKeyMapping = jsonKeyMapping;
    _incomeCategories = incomeCategories;
    _expenseCategories = expenseCategories;
    notifyListeners();
  }

  Future<String> addIncomeCategory(String name) async {
    final normalized = name.trim();
    if (normalized.isEmpty) {
      throw Exception('Nama kategori masih kosong. Isi dulu ya.');
    }

    final exists = _incomeCategories.any(
      (item) => item.trim().toLowerCase() == normalized.toLowerCase(),
    );
    if (exists) {
      throw Exception('Kategori ini sudah ada. Coba pakai nama lain ya.');
    }

    _incomeCategories = [..._incomeCategories, normalized];
    final categoriesSnapshot = List<String>.from(_incomeCategories);
    unawaited(_persistIncomeCategories(categoriesSnapshot));
    notifyListeners();
    return normalized;
  }

  Future<String> addExpenseCategory(String name) async {
    final normalized = name.trim();
    if (normalized.isEmpty) {
      throw Exception('Nama kategori masih kosong. Isi dulu ya.');
    }

    final exists = _expenseCategories.any(
      (item) => item.trim().toLowerCase() == normalized.toLowerCase(),
    );
    if (exists) {
      throw Exception('Kategori ini sudah ada. Coba pakai nama lain ya.');
    }

    _expenseCategories = [..._expenseCategories, normalized];
    final categoriesSnapshot = List<String>.from(_expenseCategories);
    unawaited(_persistExpenseCategories(categoriesSnapshot));
    notifyListeners();
    return normalized;
  }

  Future<void> addTransaction({
    required String title,
    required double amount,
    required String type,
    required String category,
    required DateTime date,
    String? time,
    int? financialPlanId,
  }) async {
    final active = activeBookPeriod;
    if (active == null || active.id == null) {
      throw Exception('Buka buku dulu yuk sebelum menambahkan transaksi.');
    }

    final normalizedDate = _normalizeDate(date);
    final activeStart = DateTime.tryParse(active.startDate);
    if (activeStart != null &&
        normalizedDate.isBefore(_normalizeDate(activeStart))) {
      throw Exception(
        'Tanggal transaksi belum bisa sebelum tanggal buka buku aktif.',
      );
    }

    if (financialPlanId != null) {
      final targetPlan = _allFinancialPlans.where(
        (p) => p.id == financialPlanId,
      );
      if (targetPlan.isEmpty) {
        throw Exception('Rencana keuangan yang dipilih belum ketemu.');
      }
      final plan = targetPlan.first;
      if (plan.bookPeriodId != active.id) {
        throw Exception(
          'Rencana keuangan harus dari buku yang sedang aktif, ya.',
        );
      }
    }

    final tx = FinanceTransaction(
      bookPeriodId: active.id,
      financialPlanId: financialPlanId,
      title: title,
      amount: amount,
      type: type,
      category: category,
      date: DateFormat('yyyy-MM-dd').format(normalizedDate),
      time: time,
      isSynced: 0,
    );

    await _databaseHelper.insertTransaction(tx);
    await loadTransactions();
  }

  Future<void> addFinancialPlan({
    required String title,
    required double targetAmount,
    required DateTime targetDate,
    int? bookPeriodId,
  }) async {
    final selectedId =
        bookPeriodId ?? _selectedBookPeriodId ?? activeBookPeriod?.id;
    if (selectedId == null) {
      throw Exception(
        'Pilih buku dulu yuk sebelum menambahkan rencana keuangan.',
      );
    }

    final selectedBook = _bookPeriods.where((item) => item.id == selectedId);
    if (selectedBook.isEmpty) {
      throw Exception('Buku yang dipilih belum ketemu.');
    }
    final selectedBookStart = DateTime.tryParse(selectedBook.first.startDate);

    final targetTitle = title.trim();
    if (targetTitle.isEmpty) {
      throw Exception('Judul rencananya belum diisi.');
    }
    if (targetAmount <= 0) {
      throw Exception('Target nominalnya belum valid.');
    }

    final normalizedTargetDate = _normalizeDate(targetDate);
    if (selectedBookStart != null &&
        normalizedTargetDate.isBefore(_normalizeDate(selectedBookStart))) {
      throw Exception(
        'Tanggal target rencana belum bisa sebelum tanggal buka buku.',
      );
    }

    final targetDateString = DateFormat(
      'yyyy-MM-dd',
    ).format(normalizedTargetDate);

    final insertedId = await _databaseHelper.insertFinancialPlan(
      FinancialPlan(
        bookPeriodId: selectedId,
        title: targetTitle,
        targetAmount: targetAmount,
        targetDate: targetDateString,
      ),
    );

    _allFinancialPlans = [
      ..._allFinancialPlans,
      FinancialPlan(
        id: insertedId,
        bookPeriodId: selectedId,
        title: targetTitle,
        targetAmount: targetAmount,
        targetDate: targetDateString,
      ),
    ];
    await _rescheduleFinancialPlanNotifications();
    notifyListeners();
  }

  Future<void> removeFinancialPlan(int id) async {
    final selectedId = _currentPlanScopeBookId;
    if (selectedId == null) {
      throw Exception('Pilih buku dulu ya sebelum menghapus rencana keuangan.');
    }

    final target = _allFinancialPlans.where((item) => item.id == id);
    if (target.isEmpty) {
      throw Exception('Rencana keuangannya belum ketemu.');
    }
    if (target.first.bookPeriodId != selectedId) {
      throw Exception(
        'Rencana keuangan hanya bisa dihapus dari buku yang sedang dipilih.',
      );
    }

    await _databaseHelper.deleteFinancialPlan(id);
    _allFinancialPlans = _allFinancialPlans
        .where((item) => item.id != id)
        .toList(growable: false);
    await _rescheduleFinancialPlanNotifications();
    notifyListeners();
  }

  double getFinancialPlanProgress(int planId) {
    final plan = _allFinancialPlans.where((item) => item.id == planId);
    if (plan.isEmpty) return 0;
    final targetAmount = plan.first.targetAmount;
    if (targetAmount <= 0) return 0;

    final realized = getFinancialPlanRealization(planId);
    return (realized / targetAmount).clamp(0, 1);
  }

  double getFinancialPlanRealization(int planId) {
    return _allTransactions
        .where((tx) => tx.type == 'EXPENSE' && tx.financialPlanId == planId)
        .fold<double>(0, (sum, tx) => sum + tx.amount);
  }

  Future<int> syncUnsyncedToGoogleSheets() async {
    _isSyncing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final unsynced = await _databaseHelper.getUnsyncedTransactions();
      if (unsynced.isEmpty) {
        return 0;
      }

      if (_webAppUrl.trim().isEmpty) {
        throw Exception(
          'URL Google Apps Script belum diatur. Yuk atur dulu di pengaturan.',
        );
      }

      await _syncApiService.syncTransactionsBatch(
        webAppUrl: _webAppUrl.trim(),
        transactions: unsynced,
        keyMapping: _jsonKeyMapping,
        payloadRootKey: _payloadRootKey.trim().isEmpty
            ? 'transactions'
            : _payloadRootKey.trim(),
      );

      final ids = unsynced
          .where((tx) => tx.id != null)
          .map((tx) => tx.id!)
          .toList();
      await _databaseHelper.markTransactionsAsSynced(ids);
      await loadTransactions();
      return ids.length;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _applySelectedBookPeriod() {
    final hasSelected =
        _selectedBookPeriodId != null &&
        _bookPeriods.any((item) => item.id == _selectedBookPeriodId);
    if (hasSelected) return;

    _selectedBookPeriodId =
        activeBookPeriod?.id ??
        (_bookPeriods.isNotEmpty ? _bookPeriods.first.id : null);
  }

  DateTime _normalizeDate(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  Future<void> _persistIncomeCategories(List<String> categories) async {
    try {
      await _settingsService.saveIncomeCategories(categories);
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  Future<void> _persistExpenseCategories(List<String> categories) async {
    try {
      await _settingsService.saveExpenseCategories(categories);
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  Future<void> _rescheduleFinancialPlanNotifications() async {
    try {
      await _notificationService.scheduleFinancialPlanNotifications(
        plans: _allFinancialPlans,
        hour: _planNotificationHour,
        minute: _planNotificationMinute,
      );
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  Future<void> _syncHomeBalanceWidget() async {
    try {
      await _homeBalanceWidgetService.syncBalance(
        totalIncome: currentTotalIncome,
        totalExpense: currentTotalExpense,
        balance: currentNetBalance,
        isHidden: _isBalanceHidden,
      );
    } catch (_) {}
  }

  int? get _currentPlanScopeBookId =>
      _selectedBookPeriodId ?? activeBookPeriod?.id;
}
