import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/book_period.dart';
import '../models/finance_transaction.dart';
import '../models/financial_plan.dart';
import '../providers/transaction_provider.dart';
import '../providers/shopping_provider.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_transitions.dart';
import '../utils/rupiah_input_formatter.dart';
import '../widgets/animated_bell_icon.dart';
import '../widgets/animated_bouncing_card.dart';
import '../widgets/entrance_animation.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/success_overlay.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'expense_input_screen.dart';
import 'income_input_screen.dart';
import 'settings_screen.dart';
import 'shopping_list_screen.dart';
import 'book_period_recap_screen.dart';
import 'pocket_list_screen.dart';
import 'pocket_detail_screen.dart';
import 'pocket_form_screen.dart';
import '../utils/icon_picker_utils.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    this.userName = '',
    this.openExpenseOnStart = false,
    this.openIncomeOnStart = false,
    this.toggleBalanceVisibilityOnStart = false,
  });

  final String userName;
  final bool openExpenseOnStart;
  final bool openIncomeOnStart;
  final bool toggleBalanceVisibilityOnStart;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _authService = AuthService();
  int _currentIndex = 0;
  int _previousIndex = 0;
  String _recentFilter = 'ALL';
  String _chartFilter = 'EXPENSE';
  int _chartRangeDays = 7;
  late String _userName;
  bool _isOpeningInput = false;
  bool _isSavingFinancialPlan = false;
  _ChartDetail? _selectedChartDetail;

  @override
  void initState() {
    super.initState();
    _userName = widget.userName.trim();
    _loadLoggedInUserName();
    if (widget.toggleBalanceVisibilityOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final provider = context.read<TransactionProvider>();
        await provider.setBalanceHidden(!provider.isBalanceHidden);
      });
    }
    if (widget.openExpenseOnStart || widget.openIncomeOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (widget.openIncomeOnStart) {
          _openIncomeInput();
          return;
        }
        _openExpenseInput();
      });
    }
  }

  Future<void> _loadLoggedInUserName() async {
    final currentName = await _authService.getCurrentUserName();
    if (!mounted || currentName.isEmpty) return;
    setState(() => _userName = currentName);
  }

  double? _parsePlanAmount(String input) {
    final amount = RupiahInputFormatter.parse(input);
    if (amount <= 0) return null;
    return amount;
  }

  Future<void> _openAddFinancialPlanDialog() async {
    if (_isSavingFinancialPlan) return;

    final provider = context.read<TransactionProvider>();
    final openBooks = provider.bookPeriods
        .where((b) => b.isOpen)
        .toList(growable: false);

    if (openBooks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Pilih atau buka buku dulu ya sebelum menambah rencana.',
          ),
        ),
      );
      return;
    }

    final defaultBookId =
        provider.selectedBookPeriodId ?? provider.activeBookPeriod?.id;

    final draft = await _openFinancialPlanInputDialog(
      openBooks: openBooks,
      defaultBookId: defaultBookId,
    );
    if (draft == null) return;

    setState(() => _isSavingFinancialPlan = true);

    try {
      await provider
          .addFinancialPlan(
            title: draft.title,
            targetAmount: draft.targetAmount,
            targetDate: draft.targetDate,
            bookPeriodId: draft.targetBookId,
          )
          .timeout(const Duration(seconds: 12));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rencana keuangan berhasil ditambahkan ✨'),
        ),
      );
    } on TimeoutException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Proses simpan agak lama. Coba lagi ya.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingFinancialPlan = false);
      }
    }
  }

  Future<_FinancialPlanDraft?> _openFinancialPlanInputDialog({
    String title = 'Rencana Keuangan Baru',
    String actionLabel = 'Simpan',
    required List<BookPeriod> openBooks,
    int? defaultBookId,
    FinancialPlan? initialPlan,
  }) async {
    return showZoomDialog<_FinancialPlanDraft?>(
      context: context,
      builder: (dialogContext) {
        return _FinancialPlanInputDialog(
          title: title,
          actionLabel: actionLabel,
          openBooks: openBooks,
          defaultBookId: defaultBookId,
          parsePlanAmount: _parsePlanAmount,
          initialPlan: initialPlan,
        );
      },
    );
  }

  Future<void> _openEditFinancialPlanDialog(FinancialPlan plan) async {
    if (_isSavingFinancialPlan) return;

    final provider = context.read<TransactionProvider>();
    final openBooks = provider.bookPeriods
        .where((b) => b.isOpen)
        .toList(growable: false);

    if (openBooks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada buku yang terbuka.')),
      );
      return;
    }

    final draft = await _openFinancialPlanInputDialog(
      title: 'Edit Rencana Keuangan',
      actionLabel: 'Update',
      openBooks: openBooks,
      defaultBookId: plan.bookPeriodId,
      initialPlan: plan,
    );
    if (draft == null) return;

    setState(() => _isSavingFinancialPlan = true);

    try {
      await provider
          .updateFinancialPlan(
            id: plan.id!,
            title: draft.title,
            targetAmount: draft.targetAmount,
            targetDate: draft.targetDate,
            bookPeriodId: draft.targetBookId,
          )
          .timeout(const Duration(seconds: 12));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rencana keuangan berhasil diubah ✨')),
      );
    } on TimeoutException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Proses simpan agak lama. Coba lagi ya.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isSavingFinancialPlan = false);
    }
  }

  Future<void> _removeFinancialPlan(int id) async {
    try {
      await context.read<TransactionProvider>().removeFinancialPlan(id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  void _onMenuTap(int index) {
    if (index == _currentIndex) return;
    setState(() {
      _previousIndex = _currentIndex;
      _currentIndex = index;
    });
  }

  Future<void> _openIncomeInput() async {
    if (!await _ensureBookIsOpen()) return;
    if (!mounted) return;
    if (_isOpeningInput) return;
    setState(() => _isOpeningInput = true);
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const IncomeInputScreen()),
      );
    } finally {
      if (mounted) {
        setState(() => _isOpeningInput = false);
      }
    }
  }

  Future<void> _openExpenseInput() async {
    if (!await _ensureBookIsOpen()) return;
    if (!mounted) return;
    if (_isOpeningInput) return;
    setState(() => _isOpeningInput = true);
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ExpenseInputScreen()),
      );
    } finally {
      if (mounted) {
        setState(() => _isOpeningInput = false);
      }
    }
  }

  Future<bool> _ensureBookIsOpen() async {
    final provider = context.read<TransactionProvider>();
    if (provider.hasOpenBook) return true;

    final shouldOpen = await showZoomDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Belum ada buku yang aktif'),
          content: const Text(
            'Yuk buka buku dulu sebelum menambahkan transaksi.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Nanti Dulu'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Buka Sekarang'),
            ),
          ],
        );
      },
    );

    if (shouldOpen != true) return false;
    return _openBookFlow();
  }

  Future<bool> _openBookFlow() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'Tanggal Buka Buku',
    );

    if (picked == null) return false;
    if (!mounted) return false;

    try {
      final provider = context.read<TransactionProvider>();
      await provider.openBook(startDate: picked);
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Buku baru berhasil dibuka. Semangat nabungnya!'),
        ),
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
      return false;
    }
  }

  Future<void> _closeActiveBookFlow(BookPeriod activeBook) async {
    final initialDate = DateTime.now();
    final startDate = DateTime.tryParse(activeBook.startDate) ?? initialDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(startDate) ? startDate : initialDate,
      firstDate: DateTime(startDate.year, startDate.month, startDate.day),
      lastDate: DateTime(2035),
      helpText: 'Tanggal Tutup Buku',
    );

    if (picked == null) return;
    if (!mounted) return;

    try {
      final provider = context.read<TransactionProvider>();
      await provider.closeActiveBook(endDate: picked);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Buku aktif berhasil ditutup.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _deleteBookFlow(BookPeriod book) async {
    final provider = context.read<TransactionProvider>();
    if (provider.isRemovingBookPeriod) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Proses hapus buku sedang berjalan. Mohon tunggu.'),
        ),
      );
      return;
    }

    final bookId = book.id;
    if (bookId == null) return;

    if (book.isOpen) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tutup dulu buku yang masih aktif sebelum dihapus.'),
        ),
      );
      return;
    }

    final password = await _openDeleteBookPasswordDialog(book.label);
    if (!mounted || password == null) return;

    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;

    final isPasswordValid = await _authService.verifyPassword(password);
    if (!mounted) return;
    if (!isPasswordValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password tidak cocok. Buku batal dihapus.'),
        ),
      );
      return;
    }

    try {
      await provider.removeBookPeriod(bookId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Buku "${book.label}" berhasil dihapus.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _reopenBookFlow(BookPeriod book) async {
    final provider = context.read<TransactionProvider>();
    if (provider.isRemovingBookPeriod) return;

    final bookId = book.id;
    if (bookId == null) return;

    try {
      await provider.reopenBook(bookId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Buku berhasil dibuka ulang.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<String?> _openDeleteBookPasswordDialog(String bookLabel) async {
    final controller = TextEditingController();
    final confirmationController = TextEditingController();
    bool isSubmitting = false;
    String? validationMessage;

    final result = await showZoomDialog<String?>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void submit() {
              final value = controller.text;
              final confirmationText = confirmationController.text.trim();
              if (isSubmitting) return;
              FocusManager.instance.primaryFocus?.unfocus();

              if (value.trim().isEmpty) {
                setDialogState(
                  () => validationMessage = 'Password wajib diisi dulu.',
                );
                return;
              }
              if (confirmationText.toUpperCase() != 'HAPUS') {
                setDialogState(
                  () => validationMessage =
                      'Ketik HAPUS untuk konfirmasi tindakan.',
                );
                return;
              }

              setDialogState(() => isSubmitting = true);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext, rootNavigator: true).pop(value);
              });
            }

            return AlertDialog(
              scrollable: true,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              title: const Text('Konfirmasi Hapus Buku'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Masukkan password akun untuk menghapus buku "$bookLabel". Semua transaksi dan rencana di buku ini akan ikut terhapus.',
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: controller,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => submit(),
                      decoration: const InputDecoration(
                        hintText: 'Password akun',
                        prefixIcon: Icon(Icons.lock_rounded),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: confirmationController,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => submit(),
                      decoration: const InputDecoration(
                        hintText: 'Ketik HAPUS untuk konfirmasi',
                        prefixIcon: Icon(Icons.warning_amber_rounded),
                      ),
                    ),
                    if (validationMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        validationMessage!,
                        style: const TextStyle(
                          color: Color(0xFFC24545),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.pop(dialogContext, null),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: isSubmitting ? null : submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF0C8C8),
                    foregroundColor: const Color(0xFFC24545),
                  ),
                  child: const Text('Hapus Buku'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
    confirmationController.dispose();
    return result;
  }

  void _showNotificationsBottomSheet(
    BuildContext context,
    TransactionProvider initialProvider,
    ThemeData theme,
  ) {
    // Mark persistent ones as read
    for (final alert in initialProvider.appNotifications) {
      if (alert.id != null && !alert.isRead) {
        initialProvider.markNotificationAsRead(alert.id!);
      }
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Consumer<TransactionProvider>(
          builder: (context, provider, _) {
            final alerts = provider.appNotifications;

            if (alerts.isEmpty) {
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.notifications_off_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Tidak ada notifikasi baru.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                    ],
                  ),
                ),
              );
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.notifications_active_rounded,
                          size: 24,
                          color: theme.brightness == Brightness.dark
                              ? Colors.white
                              : const Color(0xFF111111),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Notifikasi',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: alerts.length,
                        separatorBuilder: (context, index) => const Divider(),
                        itemBuilder: (context, index) {
                          final alert = alerts[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: alert.backgroundColor,
                              child: Icon(alert.icon, color: alert.iconColor),
                            ),
                            title: Text(
                              alert.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              alert.subtitle,
                              style: TextStyle(
                                color: alert.iconColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.close_rounded, size: 20),
                              color: Colors.grey,
                              onPressed: () {
                                provider.removeNotification(alert);
                              },
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
      },
    );
  }

  Future<void> _showBookManagerBottomSheet(
    BuildContext context,
    TransactionProvider provider,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final periods = provider.bookPeriods;
            final currentId = provider.selectedBookPeriodId;
            final activeBook = provider.activeBookPeriod;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text(
                        'Buku Pengeluaran',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (activeBook != null && activeBook.id != currentId) ...[
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            provider.selectBookPeriod(activeBook.id);
                            setState(() {
                              _selectedChartDetail = null;
                            });
                            Navigator.pop(context);
                          },
                          icon: const Icon(
                            Icons.check_circle_outline,
                            color: AppTheme.primaryBlue,
                          ),
                          label: const Text(
                            'Pilih Buku Aktif',
                            style: TextStyle(color: AppTheme.primaryBlue),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(color: AppTheme.primaryBlue),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Flexible(
                      child: periods.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text(
                                  'Belum ada buku. Buka buku pertama untuk mulai mencatat.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: periods.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final period = periods[index];
                                final isSelected = period.id == currentId;
                                final isActive = period.isOpen;

                                String subtitle =
                                    'Dari ${DateFormat('dd MMM yyyy').format(DateTime.parse(period.startDate))}';
                                if (!isActive && period.endDate != null) {
                                  subtitle +=
                                      ' smp ${DateFormat('dd MMM yyyy').format(DateTime.parse(period.endDate!))}';
                                } else {
                                  subtitle += ' (Sedang Berjalan)';
                                }

                                return InkWell(
                                  onTap: () {
                                    provider.selectBookPeriod(period.id);
                                    setState(() {
                                      _selectedChartDetail = null;
                                    });
                                    Navigator.pop(context);
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? (isDark ? const Color(0xFF1A3B66) : const Color(0xFFE5F0FF))
                                          : (isDark ? const Color(0xFF2D2D2D) : Colors.white),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFF0066FF)
                                            : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? const Color(0xFF0066FF)
                                                : (isDark ? const Color(0xFF3D3D3D) : const Color(0xFFF0F0F0)),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            isActive
                                                ? Icons.menu_book_rounded
                                                : Icons.lock_outline_rounded,
                                            color: isSelected
                                                ? Colors.white
                                                : (isDark ? Colors.grey.shade300 : Colors.grey.shade600),
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                period.label,
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: isSelected
                                                      ? (isDark ? const Color(0xFF66A3FF) : const Color(0xFF0066FF))
                                                      : (isDark ? Colors.white : const Color(0xFF111111)),
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                subtitle,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: isSelected
                                                      ? (isDark ? const Color(0xFF66A3FF).withOpacity(0.8) : const Color(0xFF0066FF).withOpacity(0.8))
                                                      : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isSelected)
                                          const Icon(
                                            Icons.check_circle,
                                            color: Color(0xFF0066FF),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _openBookFlow();
                            },
                            icon: const Icon(Icons.add_box_rounded),
                            label: const Text('Buka Buku'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.incomeGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: activeBook == null
                                ? null
                                : () {
                                    Navigator.pop(context);
                                    _closeActiveBookFlow(activeBook);
                                  },
                            icon: const Icon(Icons.bookmark_remove_rounded),
                            label: const Text('Tutup Buku'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.expenseRed,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (currentId != null) ...[
                      Builder(
                        builder: (context) {
                          final currentPeriod = periods.firstWhere(
                            (p) => p.id == currentId,
                            orElse: () => periods.first,
                          );
                          if (!currentPeriod.isOpen) {
                            return Column(
                              children: [
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _reopenBookFlow(currentPeriod);
                                    },
                                    icon: const Icon(
                                      Icons.lock_open_rounded,
                                      color: Color(0xFF6B3076),
                                    ),
                                    label: const Text(
                                      'Buka Ulang Buku',
                                      style: TextStyle(
                                        color: Color(0xFF6B3076),
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      side: const BorderSide(
                                        color: Color(0xFF6B3076),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _deleteBookFlow(currentPeriod);
                                    },
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: Color(0xFFC24545),
                                    ),
                                    label: const Text(
                                      'Hapus Buku Terpilih',
                                      style: TextStyle(
                                        color: Color(0xFFC24545),
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      side: const BorderSide(
                                        color: Color(0xFFC24545),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Consumer<TransactionProvider>(
            builder: (context, provider, _) {
              final allTransactions = provider.transactions;
              final bookPeriods = provider.bookPeriods;
              final financialPlans = provider.financialPlans;
              final selectedBookId = provider.selectedBookPeriodId;
              final activeBook = provider.activeBookPeriod;
              final chartBookId = selectedBookId ?? activeBook?.id;
              final chartTransactions = chartBookId == null
                  ? const <FinanceTransaction>[]
                  : allTransactions
                        .where((item) => item.bookPeriodId == chartBookId)
                        .toList(growable: false);
              final incomeTransactions = allTransactions
                  .where((item) => item.type == 'INCOME')
                  .toList();
              final expenseTransactions = allTransactions
                  .where((item) => item.type == 'EXPENSE')
                  .toList();

              final filteredRecent = _recentFilter == 'INCOME'
                  ? incomeTransactions
                  : _recentFilter == 'EXPENSE'
                  ? expenseTransactions
                  : allTransactions;

              final totalIncome = incomeTransactions.fold<double>(
                0,
                (sum, tx) => sum + tx.amount,
              );
              final totalExpense = expenseTransactions.fold<double>(
                0,
                (sum, tx) => sum + tx.amount,
              );
              final netBalance = totalIncome - totalExpense;
              final currentTabKey = ValueKey(_currentIndex);
              final currentTitle = _currentIndex == 1
                  ? 'Transaksi'
                  : _currentIndex == 2
                  ? 'Belanja'
                  : _currentIndex == 3
                  ? 'Pengaturan'
                  : 'Beranda';
              final userName = _userName;
              final greeting = userName.isEmpty ? 'Hai,' : 'Hai, $userName';

              return Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_currentIndex == 0) ...[
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    greeting,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    currentTitle,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            Consumer<ShoppingProvider>(
                              builder: (context, shoppingProvider, child) {
                                final count = shoppingProvider.unboughtCount;
                                return Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    if (count > 0)
                                      Positioned(
                                        right: -2,
                                        top: -2,
                                        child: Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFF9F1C),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: const Color(0xFF111111),
                                              width: 1.5,
                                            ),
                                            boxShadow: [
                                              const BoxShadow(
                                                color: Color(0xFF111111),
                                                offset: Offset(1, 1),
                                              ),
                                            ],
                                          ),
                                          constraints: const BoxConstraints(
                                            minWidth: 16,
                                            minHeight: 16,
                                          ),
                                          child: Center(
                                            child: Text(
                                              count > 99
                                                  ? '99+'
                                                  : count.toString(),
                                              style: const TextStyle(
                                                color: Color(0xFF111111),
                                                fontSize: 8,
                                                fontWeight: FontWeight.w900,
                                                height: 1.0,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                AnimatedBellIcon(
                                  animate:
                                      provider.unreadNotificationCount > 0,
                                  child: _CircleIconButton(
                                    icon: Icons.notifications_none_rounded,
                                    onTap: () {
                                      _showNotificationsBottomSheet(
                                        context,
                                        provider,
                                        theme,
                                      );
                                    },
                                  ),
                                ),
                                if (provider.unreadNotificationCount > 0)
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE53935),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          reverseDuration: const Duration(milliseconds: 260),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) {
                            final isForward = _currentIndex >= _previousIndex;
                            final isIncoming = child.key == currentTabKey;
                            final horizontalShift = isForward ? 0.16 : -0.16;

                            final offsetTween = isIncoming
                                ? Tween<Offset>(
                                    begin: Offset(horizontalShift, 0),
                                    end: Offset.zero,
                                  )
                                : Tween<Offset>(
                                    begin: Offset.zero,
                                    end: Offset(-horizontalShift, 0),
                                  );

                            final positionAnimation = offsetTween.animate(
                              CurvedAnimation(
                                parent: isIncoming
                                    ? animation
                                    : ReverseAnimation(animation),
                                curve: Curves.easeOutCubic,
                              ),
                            );

                            final opacityAnimation = CurvedAnimation(
                              parent: animation,
                              curve: isIncoming
                                  ? Curves.easeOut
                                  : Curves.easeIn,
                            );

                            return FadeTransition(
                              opacity: opacityAnimation,
                              child: SlideTransition(
                                position: positionAnimation,
                                child: child,
                              ),
                            );
                          },
                          child: KeyedSubtree(
                            key: currentTabKey,
                            child: _buildCurrentTab(
                              theme: theme,
                              provider: provider,
                              allTransactions: allTransactions,
                              chartTransactions: chartTransactions,
                              financialPlans: financialPlans,
                              incomeTransactions: incomeTransactions,
                              expenseTransactions: expenseTransactions,
                              filteredRecent: filteredRecent,
                              totalIncome: totalIncome,
                              totalExpense: totalExpense,
                              netBalance: netBalance,
                              onAddIncome: _openIncomeInput,
                              onAddExpense: _openExpenseInput,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _ExpandableQuickMenu(
        selectedIndex: _currentIndex,
        onMenuTap: _onMenuTap,
        onOpenQuickAdd: _openQuickAddSheet,
      ),
    );
  }

  Future<void> _openQuickAddSheet() async {
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tambah Catatan',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                _QuickAddSheetItem(
                  icon: Icons.south_west_rounded,
                  title: 'Tambah Pemasukan',
                  subtitle: 'Catat uang yang masuk',
                  color: AppTheme.incomeLight,
                  iconColor: AppTheme.incomeGreen,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openIncomeInput();
                  },
                ),
                const SizedBox(height: 8),
                _QuickAddSheetItem(
                  icon: Icons.north_east_rounded,
                  title: 'Tambah Pengeluaran',
                  subtitle: 'Catat uang yang keluar',
                  color: AppTheme.expenseLight,
                  iconColor: AppTheme.expenseRed,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openExpenseInput();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCurrentTab({
    required ThemeData theme,
    required TransactionProvider provider,
    required List<FinanceTransaction> allTransactions,
    required List<FinanceTransaction> chartTransactions,
    required List<FinancialPlan> financialPlans,
    required List<FinanceTransaction> incomeTransactions,
    required List<FinanceTransaction> expenseTransactions,
    required List<FinanceTransaction> filteredRecent,
    required double totalIncome,
    required double totalExpense,
    required double netBalance,
    required VoidCallback onAddIncome,
    required VoidCallback onAddExpense,
  }) {
    switch (_currentIndex) {
      case 1:
        return _buildTransactionsTabScreen(
          theme: theme,
          provider: provider,
          allTransactions: allTransactions,
          financialPlans: financialPlans,
          incomeTransactions: incomeTransactions,
          expenseTransactions: expenseTransactions,
        );
      case 2:
        return const ShoppingListScreen(isEmbedded: true);
      case 3:
        return const SettingsScreen(isEmbedded: true);
      default:
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          child: Column(
            children: [
              // Balance card — flip entrance
              EntranceAnimation(
                type: EntranceType.flipX,
                delay: const Duration(milliseconds: 100),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutBack,
                child: _BalanceCard(
                  theme: theme,
                  totalIncome: totalIncome,
                  totalExpense: totalExpense,
                  netBalance: netBalance,
                  isBalanceHidden: provider.isBalanceHidden,
                  onToggleBalanceVisibility: () {
                    provider.setBalanceHidden(!provider.isBalanceHidden);
                  },
                  onAddIncome: onAddIncome,
                  onAddExpense: onAddExpense,
                ),
              ),
              const SizedBox(height: 10),
              // Pockets — slide from right
              EntranceAnimation(
                type: EntranceType.slideRight,
                delay: const Duration(milliseconds: 300),
                duration: const Duration(milliseconds: 700),
                child: _DashboardPocketSection(provider: provider),
              ),
              const SizedBox(height: 10),
              // Chart — slide from bottom
              EntranceAnimation(
                type: EntranceType.slideUp,
                delay: const Duration(milliseconds: 500),
                duration: const Duration(milliseconds: 700),
                child: _GraphCard(
                  theme: theme,
                  transactions: chartTransactions,
                  selectedType: _chartFilter,
                  selectedRangeDays: _chartRangeDays,
                  selectedDetail: _selectedChartDetail,
                  onSelectType: (type) => setState(() {
                    _chartFilter = type;
                    _selectedChartDetail = null;
                  }),
                  onSelectRangeDays: (days) => setState(() {
                    _chartRangeDays = days;
                    _selectedChartDetail = null;
                  }),
                  onBarTap: (detail) => setState(() {
                    final isSame =
                        _selectedChartDetail?.dayLabel == detail.dayLabel &&
                        _selectedChartDetail?.amount == detail.amount;
                    _selectedChartDetail = isSame ? null : detail;
                  }),
                ),
              ),
              const SizedBox(height: 10),
              // Recent transactions — fade scale
              EntranceAnimation(
                type: EntranceType.fadeScale,
                delay: const Duration(milliseconds: 700),
                duration: const Duration(milliseconds: 600),
                child: _RecentSection(
                  theme: theme,
                  transactions: filteredRecent,
                  isLoading: provider.isLoading,
                  headerBottom: Row(
                    children: [
                      _FilterButton(
                        label: 'Pemasukan',
                        selected: _recentFilter == 'INCOME',
                        onTap: () => setState(() {
                          _recentFilter = _recentFilter == 'INCOME'
                              ? 'ALL'
                              : 'INCOME';
                        }),
                      ),
                      const SizedBox(width: 8),
                      _FilterButton(
                        label: 'Pengeluaran',
                        selected: _recentFilter == 'EXPENSE',
                        textColor: const Color(0xFFC24545),
                        selectedColor: const Color(0xFFF0C8C8),
                        onTap: () => setState(() {
                          _recentFilter = _recentFilter == 'EXPENSE'
                              ? 'ALL'
                              : 'EXPENSE';
                        }),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(
                height: 120,
              ), // Transparent space for navbar clearance
            ],
          ),
        );
    }
  }

  Widget _buildTransactionsTabScreen({
    required ThemeData theme,
    required TransactionProvider provider,
    required List<FinanceTransaction> allTransactions,
    required List<FinancialPlan> financialPlans,
    required List<FinanceTransaction> incomeTransactions,
    required List<FinanceTransaction> expenseTransactions,
  }) {
    final realizationByPlan = <int, double>{};
    for (final tx in allTransactions) {
      final planId = tx.financialPlanId;
      if (tx.type != 'EXPENSE' || planId == null) continue;
      realizationByPlan[planId] = (realizationByPlan[planId] ?? 0) + tx.amount;
    }

    return DefaultTabController(
      length: 5,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: theme.colorScheme.primary,
            tabs: const [
              Tab(text: 'Buku'),
              Tab(text: 'Pengeluaran'),
              Tab(text: 'Pemasukan'),
              Tab(text: 'Rencana Keuangan'),
              Tab(text: 'Laporan'),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TabBarView(
              children: [
                _buildBookManagerTab(provider),
                _TransactionsCard(
                  theme: theme,
                  title: '',
                  titleColor: const Color(0xFFC24545),
                  transactions: expenseTransactions,
                  isLoading: provider.isLoading,
                  emptyText: 'Belum ada data pengeluaran.',
                ),
                _TransactionsCard(
                  theme: theme,
                  title: '',
                  transactions: incomeTransactions,
                  isLoading: provider.isLoading,
                  emptyText: 'Belum ada data pemasukan.',
                ),
                _FinancialPlanCard(
                  theme: theme,
                  plans: financialPlans,
                  isLoading: provider.isLoading,
                  realizationByPlan: realizationByPlan,
                  isSaving: _isSavingFinancialPlan,
                  onAddPlan: _openAddFinancialPlanDialog,
                  onEditPlan: _openEditFinancialPlanDialog,
                  onDeletePlan: _removeFinancialPlan,
                ),
                const BookPeriodRecapScreen(isEmbedded: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookManagerTab(TransactionProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final periods = provider.bookPeriods;
    final currentId = provider.selectedBookPeriodId;
    final activeBook = provider.activeBookPeriod;

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openBookFlow,
              icon: const Icon(Icons.add_box_rounded, color: AppTheme.incomeGreen),
              label: const Text('Buka Buku Baru', style: TextStyle(color: AppTheme.incomeGreen)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: const BorderSide(color: AppTheme.incomeGreen),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: periods.isEmpty
                ? Center(
                    child: _AppEmptyState(
                      emoji: '📖',
                      title: 'Belum ada buku',
                      subtitle: 'Buka buku pertama untuk mulai mencatat keuanganmu.',
                      ctaLabel: 'Buka Buku Pertama',
                      onCtaTap: _openBookFlow,
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: periods.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final period = periods[index];
                      final isSelected = period.id == currentId;
                      final isActive = period.isOpen;

                      String subtitle =
                          'Dari ${DateFormat('dd MMM yyyy').format(DateTime.parse(period.startDate))}';
                      if (!isActive && period.endDate != null) {
                        subtitle +=
                            ' smp ${DateFormat('dd MMM yyyy').format(DateTime.parse(period.endDate!))}';
                      } else {
                        subtitle += ' (Sedang Berjalan)';
                      }

                      return Slidable(
                        key: ValueKey(period.id),
                        startActionPane: ActionPane(
                          motion: const ScrollMotion(),
                          children: [
                            if (isActive)
                              SlidableAction(
                                onPressed: (_) {
                                  _closeActiveBookFlow(period);
                                },
                                backgroundColor: AppTheme.expenseRed,
                                foregroundColor: Colors.white,
                                icon: Icons.bookmark_remove_rounded,
                                label: 'Tutup',
                                borderRadius: BorderRadius.circular(12),
                              )
                            else
                              SlidableAction(
                                onPressed: (_) {
                                  _reopenBookFlow(period);
                                },
                                backgroundColor: AppTheme.incomeGreen,
                                foregroundColor: Colors.white,
                                icon: Icons.restore_rounded,
                                label: 'Buka Lagi',
                                borderRadius: BorderRadius.circular(12),
                              ),
                          ],
                        ),
                        child: InkWell(
                          onTap: () {
                            provider.selectBookPeriod(period.id);
                            setState(() {
                              _selectedChartDetail = null;
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primaryContainer
                                  : (isDark ? const Color(0xFF2D2D2D) : Colors.white),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : (isDark ? const Color(0xFF3D3D3D) : const Color(0xFFF0F0F0)),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isActive
                                        ? Icons.menu_book_rounded
                                        : Icons.lock_outline_rounded,
                                    color: isSelected
                                        ? Colors.white
                                        : (isDark ? Colors.grey.shade300 : Colors.grey.shade600),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        period.label,
                                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: isSelected
                                              ? Theme.of(context).colorScheme.primary
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        subtitle,
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected) ...[
                                  Icon(
                                    Icons.check_circle,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Icon(
                                  Icons.swipe_right_rounded,
                                  color: Colors.grey.shade400,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable Empty State Widget
// ─────────────────────────────────────────────────────────────────────────────
class _AppEmptyState extends StatelessWidget {
  const _AppEmptyState({
    required this.emoji,
    required this.title,
    required this.subtitle,
    this.ctaLabel,
    this.onCtaTap,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final String? ctaLabel;
  final VoidCallback? onCtaTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 52),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (ctaLabel != null && onCtaTap != null) ...[
              const SizedBox(height: 20),
              FilledButton.tonal(
                onPressed: onCtaTap,
                child: Text(ctaLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlanDueAlert {
  const _PlanDueAlert({
    required this.plan,
    required this.isOverdue,
    required this.overdueDays,
  });

  final FinancialPlan plan;
  final bool isOverdue;
  final int overdueDays;
}

class _ExpandableQuickMenu extends StatelessWidget {
  const _ExpandableQuickMenu({
    required this.selectedIndex,
    required this.onMenuTap,
    required this.onOpenQuickAdd,
  });

  final int selectedIndex;
  final ValueChanged<int> onMenuTap;
  final VoidCallback onOpenQuickAdd;

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width - 32;

    return SizedBox(
      width: maxWidth,
      height: 100,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            width: maxWidth,
            height: 60,
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color ?? Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Theme.of(
                context,
              ).extension<AppThemeExtension>()?.cardBorder,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                _QuickNavItem(
                  icon: Icons.home_rounded,
                  semanticLabel: 'Beranda',
                  selected: selectedIndex == 0,
                  onTap: () => onMenuTap(0),
                ),
                _QuickNavItem(
                  icon: Icons.swap_horiz_rounded,
                  semanticLabel: 'Transaksi',
                  selected: selectedIndex == 1,
                  onTap: () => onMenuTap(1),
                ),
                const SizedBox(width: 74),
                _QuickNavItem(
                  icon: Icons.shopping_cart_outlined,
                  semanticLabel: 'Daftar Belanja',
                  selected: selectedIndex == 2,
                  onTap: () => onMenuTap(2),
                ),
                _QuickNavItem(
                  icon: Icons.settings_outlined,
                  semanticLabel: 'Pengaturan',
                  selected: selectedIndex == 3,
                  onTap: () => onMenuTap(3),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: _FloatingQuickAddButton(onTap: onOpenQuickAdd),
          ),
        ],
      ),
    );
  }
}

class _FloatingQuickAddButton extends StatelessWidget {
  const _FloatingQuickAddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: AppTheme.fabBgColor,
          shape: BoxShape.circle,
          border: Theme.of(context).extension<AppThemeExtension>()?.cardBorder,
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.add_rounded,
          size: 28,
          color: AppTheme.fabIconColor,
        ),
      ),
    );
  }
}

class _QuickAddSheetItem extends StatelessWidget {
  const _QuickAddSheetItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final themeTextColor = Theme.of(context).textTheme.bodyMedium?.color;
    final themeSubtitleColor = Theme.of(context).textTheme.bodySmall?.color;

    return AnimatedBouncingCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      color: Theme.of(context).cardTheme.color ?? Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(9),
              border: Theme.of(
                context,
              ).extension<AppThemeExtension>()?.cardBorder,
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: themeTextColor,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: themeSubtitleColor),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: themeTextColor),
        ],
      ),
    );
  }
}

class _QuickNavItem extends StatefulWidget {
  const _QuickNavItem({
    required this.icon,
    required this.semanticLabel,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String semanticLabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_QuickNavItem> createState() => _QuickNavItemState();
}

class _QuickNavItemState extends State<_QuickNavItem> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSelected = widget.selected;
    final activeColor = theme.colorScheme.primary;
    final iconColor = isSelected
        ? activeColor
        : theme.iconTheme.color ?? AppTheme.borderColor;

    return Expanded(
      child: Semantics(
        label: widget.semanticLabel,
        button: true,
        selected: isSelected,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOutCubic,
          scale: _isPressed ? 0.93 : 1,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: widget.onTap,
            onHighlightChanged: (value) {
              if (_isPressed == value) return;
              setState(() => _isPressed = value);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  width: isSelected ? 48 : 40,
                  height: 30,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primaryContainer
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Icon(
                    widget.icon,
                    size: 20,
                    color: iconColor,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BookPeriodCard extends StatelessWidget {
  const _BookPeriodCard({
    required this.periods,
    required this.selectedPeriodId,
    required this.activePeriodId,
    required this.onSelectPeriod,
    required this.onOpenBook,
    required this.onCloseActiveBook,
    required this.onReopenBook,
    required this.onDeleteBook,
    required this.onHideCard,
  });

  final List<BookPeriod> periods;
  final int? selectedPeriodId;
  final int? activePeriodId;
  final ValueChanged<int?> onSelectPeriod;
  final Future<bool> Function() onOpenBook;
  final Future<void> Function()? onCloseActiveBook;
  final Future<void> Function(BookPeriod period) onReopenBook;
  final Future<void> Function(BookPeriod period) onDeleteBook;
  final VoidCallback onHideCard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    BookPeriod? selectedPeriod;
    for (final period in periods) {
      if (period.id == selectedPeriodId) {
        selectedPeriod = period;
        break;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Buku Pengeluaran',
                    style: theme.textTheme.titleMedium?.copyWith(fontSize: 20),
                  ),
                ),
                _CircleIconButton(
                  icon: Icons.visibility_off_rounded,
                  onTap: onHideCard,
                ),
              ],
            ),
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: periods.isEmpty
                  ? null
                  : () => _openPeriodPicker(context, selectedPeriodId),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color ?? Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Theme.of(
                    context,
                  ).extension<AppThemeExtension>()?.cardBorder,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color:
                            Theme.of(context).cardTheme.color ?? Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                              (Theme.of(context)
                                  .extension<AppThemeExtension>()
                                  ?.cardBorder
                                  ?.top
                                  .color ??
                              const Color(0xFF2D2D2D)),
                          width: 1,
                        ),
                      ),
                      child: const Icon(Icons.menu_book_rounded, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedLabel(selectedPeriod),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            _selectedSubLabel(selectedPeriod),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      periods.isEmpty
                          ? Icons.lock_outline_rounded
                          : Icons.expand_more_rounded,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: selectedPeriod == null
                        ? Theme.of(context).colorScheme.surface
                        : selectedPeriod.closed
                        ? Theme.of(context).colorScheme.secondaryContainer
                        : const Color(0xFFA4DBB2),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color:
                          (Theme.of(context)
                              .extension<AppThemeExtension>()
                              ?.cardBorder
                              ?.top
                              .color ??
                          const Color(0xFF2D2D2D)),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    selectedPeriod == null
                        ? 'Semua Buku'
                        : selectedPeriod.closed
                        ? 'Buku Ditutup'
                        : 'Buku Aktif',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    periods.isEmpty
                        ? 'Belum ada buku. Buka buku pertama untuk mulai mencatat transaksi.'
                        : 'Tap kartu untuk ganti periode buku.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: 'Buka Buku',
                    icon: Icons.menu_book_rounded,
                    background:
                        Theme.of(context).cardTheme.color ?? Colors.white,
                    iconBackground: const Color(0xFFF5BB8A),
                    onTap: () {
                      onOpenBook();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton(
                    label: 'Tutup Buku',
                    icon: Icons.bookmark_remove_rounded,
                    background: activePeriodId == null
                        ? Theme.of(context).colorScheme.surface
                        : const Color(0xFFD4BEF2),
                    iconBackground: const Color(0xFFF5BB8A),
                    labelColor: activePeriodId == null
                        ? null
                        : const Color(0xFF111111),
                    iconColor: activePeriodId == null
                        ? null
                        : const Color(0xFF111111),
                    onTap: onCloseActiveBook ?? () {},
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (selectedPeriod != null && selectedPeriod.closed) ...[
              SizedBox(
                width: double.infinity,
                child: _ActionButton(
                  label: 'Buka Ulang Buku',
                  icon: Icons.lock_open_rounded,
                  background: const Color(0xFFD4BEF2),
                  iconBackground: const Color(0xFFF5BB8A),
                  labelColor: const Color(0xFF111111),
                  iconColor: const Color(0xFF111111),
                  onTap: () {
                    onReopenBook(selectedPeriod!);
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (selectedPeriod != null && selectedPeriod.closed) ...[
              SizedBox(
                width: double.infinity,
                child: _ActionButton(
                  label: 'Hapus Buku',
                  icon: Icons.delete_outline_rounded,
                  background: const Color(0xFFC24545),
                  iconBackground: const Color(0xFFF0C8C8),
                  labelColor: Colors.white,
                  iconColor: Colors.white,
                  onTap: () {
                    onDeleteBook(selectedPeriod!);
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _buildPeriodLabel(BookPeriod period) {
    final start = DateTime.tryParse(period.startDate);
    final end = period.endDate == null
        ? null
        : DateTime.tryParse(period.endDate!);

    final formatter = DateFormat('dd MMM yyyy', 'id');
    final startText = start == null
        ? period.startDate
        : formatter.format(start);
    final endText = end == null ? 'Sekarang' : formatter.format(end);
    final statusText = period.closed ? 'Tutup' : 'Aktif';

    return '${period.label} ($startText - $endText) • $statusText';
  }

  String _selectedLabel(BookPeriod? period) {
    if (period == null) return 'Semua Buku';
    return period.label;
  }

  String _selectedSubLabel(BookPeriod? period) {
    if (period == null) return 'Belum ada periode buku dipilih.';

    final start = DateTime.tryParse(period.startDate);
    final end = period.endDate == null
        ? null
        : DateTime.tryParse(period.endDate!);

    final formatter = DateFormat('dd MMM yyyy', 'id');
    final startText = start == null
        ? period.startDate
        : formatter.format(start);
    final endText = end == null ? 'Sekarang' : formatter.format(end);
    return '$startText - $endText';
  }

  Future<void> _openPeriodPicker(BuildContext context, int? currentId) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Pilih Periode Buku',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: periods.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final period = periods[index];
                      final periodId = period.id;
                      return _PeriodPickerItem(
                        label: period.label,
                        subtitle: _buildPeriodLabel(period),
                        selected: period.id == currentId,
                        onTap: () {
                          onSelectPeriod(period.id);
                          Navigator.pop(context);
                        },
                        onDelete: periodId == null
                            ? null
                            : period.isOpen
                            ? null
                            : () {
                                Navigator.pop(context);
                                onDeleteBook(period);
                              },
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
  }
}

class _BookPeriodCollapsedBar extends StatelessWidget {
  const _BookPeriodCollapsedBar({
    required this.activeBook,
    required this.onShowCard,
  });

  final BookPeriod? activeBook;
  final VoidCallback onShowCard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color ?? Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Theme.of(
                  context,
                ).extension<AppThemeExtension>()?.cardBorder,
              ),
              child: const Icon(Icons.menu_book_rounded, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Buku Pengeluaran Disembunyikan',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    activeBook == null
                        ? 'Tidak ada buku aktif.'
                        : 'Buku aktif: ${activeBook!.label}',
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            _CircleIconButton(
              icon: Icons.visibility_rounded,
              onTap: onShowCard,
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodPickerItem extends StatelessWidget {
  const _PeriodPickerItem({
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.onDelete,
  });

  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.secondaryContainer
              : (Theme.of(context).cardTheme.color ?? Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Theme.of(context).extension<AppThemeExtension>()?.cardBorder,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? Theme.of(context).colorScheme.onSecondaryContainer
                          : Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF1F5A62),
                size: 18,
              ),
            if (onDelete != null) ...[
              const SizedBox(width: 6),
              InkWell(
                borderRadius: BorderRadius.circular(99),
                onTap: onDelete,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0C8C8),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color:
                          (Theme.of(context)
                              .extension<AppThemeExtension>()
                              ?.cardBorder
                              ?.top
                              .color ??
                          const Color(0xFF2D2D2D)),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    size: 16,
                    color: Color(0xFFC24545),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FinancialPlanCard extends StatelessWidget {
  const _FinancialPlanCard({
    required this.theme,
    required this.plans,
    required this.isLoading,
    required this.realizationByPlan,
    required this.isSaving,
    required this.onAddPlan,
    required this.onEditPlan,
    required this.onDeletePlan,
  });

  final ThemeData theme;
  final List<FinancialPlan> plans;
  final bool isLoading;
  final Map<int, double> realizationByPlan;
  final bool isSaving;
  final Future<void> Function() onAddPlan;
  final Future<void> Function(FinancialPlan plan) onEditPlan;
  final Future<void> Function(int id) onDeletePlan;

  @override
  Widget build(BuildContext context) {
    final addButton = SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: isSaving ? null : onAddPlan,
        icon: Icon(
          isSaving ? Icons.hourglass_top_rounded : Icons.add_box_rounded,
          color: AppTheme.incomeGreen,
        ),
        label: Text(
          isSaving ? 'Tunggu Sebentar...' : 'Buat Rencana Baru',
          style: const TextStyle(color: AppTheme.incomeGreen),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          side: const BorderSide(color: AppTheme.incomeGreen),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isLoading)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: SkeletonLoader(itemCount: 3, itemHeight: 80),
              ),
            )
          else if (plans.isEmpty)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Belum ada rencana keuangan.'),
                  const SizedBox(height: 16),
                  addButton,
                ],
              ),
            )
          else
            Expanded(
              child: Column(
                children: [
                  _FinancialPlanSummaryCard(
                    theme: theme,
                    plans: plans,
                    realizationByPlan: realizationByPlan,
                  ),
                  const SizedBox(height: 12),
                  addButton,
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.only(bottom: 100),
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      itemCount: plans.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final plan = plans[index];
                        final planId = plan.id;
                        if (planId == null) {
                          return const SizedBox.shrink();
                        }
                        final realized = realizationByPlan[planId] ?? 0;
                        final progress = plan.targetAmount <= 0
                            ? 0.0
                            : (realized / plan.targetAmount)
                                  .clamp(0.0, 1.0)
                                  .toDouble();
                        return _FinancialPlanTile(
                          plan: plan,
                          progress: progress,
                          realizationAmount: realized,
                          onEdit: () => onEditPlan(plan),
                          onDelete: () => onDeletePlan(planId),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _FinancialPlanSummaryCard extends StatelessWidget {
  const _FinancialPlanSummaryCard({
    required this.theme,
    required this.plans,
    required this.realizationByPlan,
  });

  final ThemeData theme;
  final List<FinancialPlan> plans;
  final Map<int, double> realizationByPlan;

  @override
  Widget build(BuildContext context) {
    double totalTarget = 0;
    double totalRealization = 0;

    for (final plan in plans) {
      final planId = plan.id;
      if (planId == null) continue;
      totalTarget += plan.targetAmount;
      totalRealization += realizationByPlan[planId] ?? 0;
    }

    final percentageText = totalTarget > 0
        ? '${((totalRealization / totalTarget) * 100).toStringAsFixed(0)}%'
        : '0%';

    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.secondaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Theme.of(context).extension<AppThemeExtension>()?.cardBorder,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.calculate_rounded, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Rencana Keuangan',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Target: ${formatter.format(totalTarget)}',
                          style: theme.textTheme.bodySmall,
                        ),
                        Text(
                          'Realisasi: ${formatter.format(totalRealization)}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          percentageText,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FinancialPlanTile extends StatelessWidget {
  const _FinancialPlanTile({
    required this.plan,
    required this.progress,
    required this.realizationAmount,
    required this.onEdit,
    required this.onDelete,
  });

  final FinancialPlan plan;
  final double progress;
  final double realizationAmount;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(plan.targetDate);
    final dateText = date == null
        ? plan.targetDate
        : DateFormat('dd MMM yyyy', 'id').format(date);
    final amountText = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(plan.targetAmount);
    final cappedRealization = realizationAmount.clamp(0, plan.targetAmount);
    final progressText = '${(progress * 100).toStringAsFixed(0)}%';
    final realizationText = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(cappedRealization);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Theme.of(context).extension<AppThemeExtension>()?.cardBorder,
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(8),
              border: Theme.of(
                context,
              ).extension<AppThemeExtension>()?.cardBorder,
            ),
            child: const Icon(Icons.flag_rounded, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text('$amountText • Target $dateText'),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: progress),
                          duration: const Duration(milliseconds: 1000),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, _) => LinearProgressIndicator(
                            minHeight: 6,
                            value: value,
                            backgroundColor: Theme.of(context).colorScheme.surface,
                            color: const Color(0xFF1F5A62),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      progressText,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Realisasi: $realizationText',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit rencana',
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Hapus rencana',
          ),
        ],
      ),
    );
  }
}

class _RecentSection extends StatelessWidget {
  const _RecentSection({
    required this.theme,
    required this.transactions,
    required this.isLoading,
    required this.headerBottom,
  });

  final ThemeData theme;
  final List<FinanceTransaction> transactions;
  final bool isLoading;
  final Widget headerBottom;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row(
            //   children: [
            //     Text(
            //       'Transaksi Terbaru',
            //       style: theme.textTheme.titleMedium?.copyWith(fontSize: 24),
            //     ),
            //   ],
            // ),
            // const SizedBox(height: 8),
            // headerBottom,
            // const SizedBox(height: 10),
            // if (isLoading)
            //   const Padding(
            //     padding: EdgeInsets.symmetric(vertical: 32),
            //     child: Center(child: CircularProgressIndicator()),
            //   )
            // else if (transactions.isEmpty)
            //   const Padding(
            //     padding: EdgeInsets.symmetric(vertical: 12),
            //     child: Text('Belum ada transaksi dulu nih.'),
            //   )
            // else
            //   ListView.separated(
            //     shrinkWrap: true,
            //     physics: const NeverScrollableScrollPhysics(),
            //     itemCount: transactions.length,
            //     separatorBuilder: (context, index) => const SizedBox(height: 8),
            //     itemBuilder: (context, index) =>
            //         _TransactionTile(item: transactions[index], theme: theme),
            //   ),
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.theme,
    required this.totalIncome,
    required this.totalExpense,
    required this.netBalance,
    required this.isBalanceHidden,
    required this.onToggleBalanceVisibility,
    required this.onAddIncome,
    required this.onAddExpense,
  });

  final ThemeData theme;
  final double totalIncome;
  final double totalExpense;
  final double netBalance;
  final bool isBalanceHidden;
  final VoidCallback onToggleBalanceVisibility;
  final VoidCallback onAddIncome;
  final VoidCallback onAddExpense;

  @override
  Widget build(BuildContext context) {
    return AnimatedBouncingCard(
      isPressedEffect: true,
      padding: const EdgeInsets.all(14),
      color: Theme.of(context).colorScheme.primaryContainer,
      onTap: () {
        // Toggle visibility maybe?
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Dompet Kamu',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                splashRadius: 18,
                onPressed: onToggleBalanceVisibility,
                icon: Icon(
                  isBalanceHidden
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  size: 18,
                ),
              ),
              const Icon(Icons.cloud_done_rounded, size: 16),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Saldo Kamu Sekarang',
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          _AnimatedVisibilityCurrencyText(
            value: netBalance,
            isHidden: isBalanceHidden,
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 34,
              fontWeight: FontWeight.w700,
            ),
            childBuilder: (style) =>
                _AnimatedNetBalanceText(value: netBalance, style: style),
          ),
          const SizedBox(height: 8),
          _SummaryRow(
            label: 'Total Pemasukan',
            value: totalIncome,
            isHidden: isBalanceHidden,
          ),
          _SummaryRow(
            label: 'Total Pengeluaran',
            value: totalExpense,
            labelColor: const Color(0xFFC24545),
            valueColor: const Color(0xFFC24545),
            isHidden: isBalanceHidden,
          ),
          _SummaryRow(
            label: 'Selisih',
            value: netBalance,
            withSign: true,
            isHidden: isBalanceHidden,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: 'Pemasukan',
                  icon: Icons.south_west_rounded,
                  background: Theme.of(context).cardTheme.color ?? Colors.white,
                  iconBackground: const Color(0xFFA4DBB2),
                  onTap: onAddIncome,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  label: 'Pengeluaran',
                  icon: Icons.north_east_rounded,
                  background: const Color(0xFFF0C8C8),
                  iconBackground: const Color(0xFFC24545),
                  labelColor: const Color(0xFFC24545),
                  iconColor: Colors.white,
                  onTap: onAddExpense,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.withSign = false,
    this.labelColor,
    this.valueColor,
    this.isHidden = false,
  });

  final String label;
  final double value;
  final bool withSign;
  final Color? labelColor;
  final Color? valueColor;
  final bool isHidden;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: labelColor),
          ),
          const Spacer(),
          _AnimatedVisibilityCurrencyText(
            value: value,
            withSign: withSign,
            isHidden: isHidden,
            style: TextStyle(fontWeight: FontWeight.w700, color: valueColor),
          ),
        ],
      ),
    );
  }
}

class _AnimatedNetBalanceText extends StatefulWidget {
  const _AnimatedNetBalanceText({required this.value, required this.style});

  final double value;
  final TextStyle? style;

  @override
  State<_AnimatedNetBalanceText> createState() =>
      _AnimatedNetBalanceTextState();
}

class _AnimatedNetBalanceTextState extends State<_AnimatedNetBalanceText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant _AnimatedNetBalanceText oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasNegative = oldWidget.value < 0;
    final isNegative = widget.value < 0;
    if (wasNegative != isNegative) {
      _syncPulse();
    }
  }

  void _syncPulse() {
    if (widget.value < 0) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
      return;
    }

    if (_pulseController.isAnimating) {
      _pulseController.stop();
    }
    _pulseController.animateTo(
      0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final baseColor =
            widget.style?.color ??
            Theme.of(context).textTheme.titleLarge?.color ??
            const Color(0xFF111111);
        const warningColor = Color(0xFFC24545);

        final t = widget.value < 0 ? _pulseController.value : 0.0;
        final animatedStyle = widget.style?.copyWith(
          color: Color.lerp(baseColor, warningColor, t),
        );

        return Transform.scale(
          alignment: Alignment.centerLeft,
          scale: 1 + (0.03 * t),
          child: _AnimatedCurrencyText(
            value: widget.value,
            style: animatedStyle,
          ),
        );
      },
    );
  }
}

class _AnimatedCurrencyText extends StatefulWidget {
  const _AnimatedCurrencyText({
    required this.value,
    required this.style,
    this.withSign = false,
  });

  final double value;
  final TextStyle? style;
  final bool withSign;

  @override
  State<_AnimatedCurrencyText> createState() => _AnimatedCurrencyTextState();
}

class _AnimatedCurrencyTextState extends State<_AnimatedCurrencyText> {
  late double _fromValue;
  late double _toValue;

  @override
  void initState() {
    super.initState();
    _fromValue = widget.value;
    _toValue = widget.value;
  }

  @override
  void didUpdateWidget(covariant _AnimatedCurrencyText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value == widget.value) return;
    _fromValue = _toValue;
    _toValue = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: _fromValue, end: _toValue),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) {
        return Text(
          _formatRupiah(animatedValue, withSign: widget.withSign),
          style: widget.style,
        );
      },
    );
  }

  String _formatRupiah(double value, {bool withSign = false}) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    final formatted = formatter.format(value.abs());

    if (withSign) {
      return '${value >= 0 ? '+' : '-'}$formatted';
    }

    if (value < 0) {
      return '-$formatted';
    }

    return formatted;
  }
}

class _AnimatedVisibilityCurrencyText extends StatelessWidget {
  const _AnimatedVisibilityCurrencyText({
    required this.value,
    required this.style,
    this.withSign = false,
    this.isHidden = false,
    this.childBuilder,
  });

  final double value;
  final TextStyle? style;
  final bool withSign;
  final bool isHidden;
  final Widget Function(TextStyle? style)? childBuilder;

  @override
  Widget build(BuildContext context) {
    final visibleChild =
        childBuilder?.call(style) ??
        _AnimatedCurrencyText(value: value, style: style, withSign: withSign);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.08),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: isHidden
          ? Text(
              'Rp ••••••',
              key: const ValueKey('currency-hidden'),
              style: style,
            )
          : KeyedSubtree(
              key: const ValueKey('currency-visible'),
              child: visibleChild,
            ),
    );
  }
}

class _GraphCard extends StatelessWidget {
  const _GraphCard({
    required this.theme,
    required this.transactions,
    required this.selectedType,
    required this.selectedRangeDays,
    required this.selectedDetail,
    required this.onSelectType,
    required this.onSelectRangeDays,
    required this.onBarTap,
  });

  final ThemeData theme;
  final List<FinanceTransaction> transactions;
  final String selectedType;
  final int selectedRangeDays;
  final _ChartDetail? selectedDetail;
  final ValueChanged<String> onSelectType;
  final ValueChanged<int> onSelectRangeDays;
  final ValueChanged<_ChartDetail> onBarTap;

  @override
  Widget build(BuildContext context) {
    final bars = _buildBars();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              child: Row(
                children: [
                  _CircleIconButton(
                    icon: Icons.show_chart_rounded,
                    onTap: () {},
                  ),
                  const SizedBox(width: 8),
                  _FilterButton(
                    label: '1',
                    selected: selectedRangeDays == 1,
                    onTap: () => onSelectRangeDays(1),
                  ),
                  const SizedBox(width: 6),
                  _FilterButton(
                    label: '3',
                    selected: selectedRangeDays == 3,
                    onTap: () => onSelectRangeDays(3),
                  ),
                  const SizedBox(width: 6),
                  _FilterButton(
                    label: '7',
                    selected: selectedRangeDays == 7,
                    onTap: () => onSelectRangeDays(7),
                  ),
                  const SizedBox(width: 6),
                  _FilterButton(
                    label: '30',
                    selected: selectedRangeDays == 30,
                    onTap: () => onSelectRangeDays(30),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 1,
                    height: 28,
                    color:
                        (Theme.of(context)
                            .extension<AppThemeExtension>()
                            ?.cardBorder
                            ?.top
                            .color ??
                        const Color(0xFF2D2D2D)),
                  ),
                  const SizedBox(width: 10),
                  _IconFilterButton(
                    icon: Icons.north_east_rounded,
                    selected: selectedType == 'EXPENSE',
                    selectedColor: const Color(0xFFF0C8C8),
                    iconColor: const Color(0xFFC24545),
                    onTap: () => onSelectType('EXPENSE'),
                  ),
                  const SizedBox(width: 6),
                  _IconFilterButton(
                    icon: Icons.south_west_rounded,
                    selected: selectedType == 'INCOME',
                    onTap: () => onSelectType('INCOME'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 110,
              child: bars.isEmpty
                  ? Center(
                      child: Text(
                        'Belum ada transaksi di rentang waktu ini.',
                        style: theme.textTheme.bodySmall,
                      ),
                    )
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      itemCount: bars.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 6),
                      itemBuilder: (context, index) {
                        final width = selectedRangeDays >= 30 ? 34.0 : 42.0;
                        final bar = bars[index];
                        final isSelected =
                            selectedDetail?.dayLabel == bar.dayLabel &&
                            selectedDetail?.amount == bar.amount;
                        return SizedBox(
                          width: width,
                          child: _Bar(
                            data: bar,
                            selected: isSelected,
                            onTap: () => onBarTap(
                              _ChartDetail(
                                dayLabel: bar.dayLabel,
                                amount: bar.amount,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              reverseDuration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.08),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: selectedDetail == null
                  ? const SizedBox(key: ValueKey('empty-detail'))
                  : Container(
                      key: ValueKey(
                        '${selectedDetail!.dayLabel}-${selectedDetail!.amount}',
                      ),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color:
                              (Theme.of(context)
                                  .extension<AppThemeExtension>()
                                  ?.cardBorder
                                  ?.top
                                  .color ??
                              const Color(0xFF2D2D2D)),
                          width: 1.1,
                        ),
                      ),
                      child: Text(
                        '${selectedDetail!.dayLabel} • ${_formatRupiah(selectedDetail!.amount)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2D2D2D),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<_BarData> _buildBars() {
    const expenseColors = [
      Color(0xFFF7CACA),
      Color(0xFFF3B1B1),
      Color(0xFFEC9090),
      Color(0xFFE37979),
      Color(0xFFD96565),
      Color(0xFFC24545),
      Color(0xFFA13A3A),
    ];
    const incomeColors = [
      Color(0xFFBEE7C8),
      Color(0xFFA4DBB2),
      Color(0xFF93D5A1),
      Color(0xFF85C793),
      Color(0xFF74B886),
      Color(0xFF63A879),
      Color(0xFF55986D),
    ];
    final colors = selectedType == 'EXPENSE' ? expenseColors : incomeColors;

    final filteredDates = transactions
        .where((tx) => tx.type == selectedType)
        .map((tx) => DateTime.tryParse(tx.date))
        .whereType<DateTime>()
        .map((date) => DateTime(date.year, date.month, date.day))
        .toList(growable: false);

    if (filteredDates.isEmpty) return [];

    final now = DateTime.now();
    final latestTxDate = filteredDates.reduce((a, b) => a.isAfter(b) ? a : b);
    final anchorDate = latestTxDate.isAfter(now)
        ? latestTxDate
        : DateTime(now.year, now.month, now.day);

    final days = List.generate(
      selectedRangeDays,
      (index) => DateTime(
        anchorDate.year,
        anchorDate.month,
        anchorDate.day - ((selectedRangeDays - 1) - index),
      ),
    );

    final amountByDay = <String, double>{
      for (final day in days) DateFormat('yyyy-MM-dd').format(day): 0,
    };

    for (final tx in transactions) {
      if (tx.type != selectedType) continue;
      final parsed = DateTime.tryParse(tx.date);
      if (parsed == null) continue;
      final key = DateFormat(
        'yyyy-MM-dd',
      ).format(DateTime(parsed.year, parsed.month, parsed.day));
      if (!amountByDay.containsKey(key)) continue;
      amountByDay[key] = (amountByDay[key] ?? 0) + tx.amount;
    }

    final activeEntries = days
        .map(
          (day) => MapEntry(
            day,
            amountByDay[DateFormat('yyyy-MM-dd').format(day)] ?? 0,
          ),
        )
        .where((entry) => entry.value > 0)
        .toList();

    if (activeEntries.isEmpty) return [];

    final maxValue = activeEntries.fold<double>(
      0,
      (max, entry) => entry.value > max ? entry.value : max,
    );

    return List.generate(activeEntries.length, (index) {
      final entry = activeEntries[index];
      final factor = (entry.value / maxValue).clamp(0.02, 1.0);
      return _BarData(
        factor,
        colors[index % colors.length],
        DateFormat('d MMM', 'id').format(entry.key),
        entry.value,
      );
    });
  }

  String _formatRupiah(double value) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(value);
  }
}

class _ChartDetail {
  const _ChartDetail({required this.dayLabel, required this.amount});

  final String dayLabel;
  final double amount;
}

class _FinancialPlanDraft {
  const _FinancialPlanDraft({
    required this.title,
    required this.targetAmount,
    required this.targetDate,
    required this.targetBookId,
  });

  final String title;
  final double targetAmount;
  final DateTime targetDate;
  final int targetBookId;
}

class _FinancialPlanInputDialog extends StatefulWidget {
  const _FinancialPlanInputDialog({
    required this.title,
    required this.openBooks,
    required this.defaultBookId,
    required this.parsePlanAmount,
    this.actionLabel = 'Simpan',
    this.initialPlan,
  });

  final String title;
  final String actionLabel;
  final List<BookPeriod> openBooks;
  final int? defaultBookId;
  final double? Function(String input) parsePlanAmount;
  final FinancialPlan? initialPlan;

  @override
  State<_FinancialPlanInputDialog> createState() =>
      _FinancialPlanInputDialogState();
}

class _FinancialPlanInputDialogState extends State<_FinancialPlanInputDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late DateTime _selectedDate;
  int? _selectedBookId;
  DateTime? _minTargetDate;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.initialPlan?.title ?? '',
    );

    final initialAmount = widget.initialPlan?.targetAmount;
    _amountController = TextEditingController(
      text: initialAmount != null
          ? NumberFormat.currency(
              locale: 'id_ID',
              symbol: '',
              decimalDigits: 0,
            ).format(initialAmount).trim()
          : '',
    );

    final defaultBookIdCandidate =
        widget.initialPlan?.bookPeriodId ?? widget.defaultBookId;
    if (defaultBookIdCandidate != null &&
        widget.openBooks.any((b) => b.id == defaultBookIdCandidate)) {
      _selectedBookId = defaultBookIdCandidate;
    } else {
      _selectedBookId = widget.openBooks.first.id;
    }

    _updateMinTargetDate();

    if (widget.initialPlan != null) {
      _selectedDate =
          DateTime.tryParse(widget.initialPlan!.targetDate) ?? DateTime.now();
      // Make sure we validate it vs min target date again just in case the book was changed
      if (_minTargetDate != null && _selectedDate.isBefore(_minTargetDate!)) {
        _selectedDate = _minTargetDate!;
      }
    } else {
      _selectedDate = DateTime.now();
      _adjustSelectedDateToMin();
    }
  }

  void _updateMinTargetDate() {
    final book = widget.openBooks.firstWhere(
      (b) => b.id == _selectedBookId,
      orElse: () => widget.openBooks.first,
    );
    _minTargetDate = DateTime.tryParse(book.startDate);
  }

  void _adjustSelectedDateToMin() {
    final minDate = _minTargetDate;
    if (minDate != null && _selectedDate.isBefore(minDate)) {
      _selectedDate = DateTime(minDate.year, minDate.month, minDate.day);
    }
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
      firstDate: _minTargetDate ?? DateTime(2020),
      lastDate: DateTime(2040),
      helpText: 'Target Tanggal',
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedDate = picked);
  }

  void _submit() {
    if (_titleController.text.trim().isEmpty) {
      setState(() => _validationMessage = 'Judul rencana wajib diisi.');
      return;
    }

    final amount = widget.parsePlanAmount(_amountController.text);
    if (amount == null || amount <= 0) {
      setState(() => _validationMessage = 'Target nominal tidak valid.');
      return;
    }

    if (_selectedBookId == null) {
      setState(() => _validationMessage = 'Pilih target buku dulu.');
      return;
    }

    final minDate = _minTargetDate;
    if (minDate != null && _selectedDate.isBefore(minDate)) {
      setState(
        () => _validationMessage =
            'Tanggal target tidak boleh sebelum tanggal buka buku.',
      );
      return;
    }

    Navigator.pop(
      context,
      _FinancialPlanDraft(
        title: _titleController.text.trim(),
        targetAmount: amount,
        targetDate: _selectedDate,
        targetBookId: _selectedBookId!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.openBooks.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: DropdownButtonFormField<int>(
                  initialValue: _selectedBookId,
                  style: Theme.of(context).textTheme.bodyLarge,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.book_rounded),
                    hintText: 'Pilih Buku Target',
                  ),
                  items: widget.openBooks.map((book) {
                    return DropdownMenuItem(
                      value: book.id,
                      child: Text(book.label),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _selectedBookId = value;
                      _updateMinTargetDate();
                      _adjustSelectedDateToMin();
                      _validationMessage = null;
                    });
                  },
                ),
              ),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                hintText: 'Judul rencana',
                prefixIcon: Icon(Icons.flag_rounded),
              ),
              onChanged: (_) {
                if (_validationMessage == null) return;
                setState(() => _validationMessage = null);
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [RupiahInputFormatter()],
              decoration: const InputDecoration(
                hintText: 'Target nominal',
                prefixIcon: Icon(Icons.payments_rounded),
              ),
              onChanged: (_) {
                if (_validationMessage == null) return;
                setState(() => _validationMessage = null);
              },
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(10),
              child: InputDecorator(
                decoration: const InputDecoration(
                  hintText: 'Target tanggal',
                  prefixIcon: Icon(Icons.calendar_month_rounded),
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
            if (_validationMessage != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _validationMessage!,
                  style: const TextStyle(
                    color: Color(0xFFC24545),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Batal'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.actionLabel)),
      ],
    );
  }
}

class _TransactionsCard extends StatefulWidget {
  const _TransactionsCard({
    required this.theme,
    required this.title,
    required this.transactions,
    required this.isLoading,
    required this.emptyText,
    this.titleColor,
  });

  final ThemeData theme;
  final String title;
  final List<FinanceTransaction> transactions;
  final bool isLoading;
  final String emptyText;
  final Color? titleColor;

  @override
  State<_TransactionsCard> createState() => _TransactionsCardState();
}

class _TransactionsCardState extends State<_TransactionsCard> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.title.isNotEmpty) ...[
            Row(
              children: [
                Text(
                  widget.title,
                  style: widget.theme.textTheme.headlineSmall?.copyWith(
                    color: widget.titleColor,
                  ),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 10),
          ],
          if (widget.isLoading)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: SkeletonLoader(itemCount: 5),
              ),
            )
          else if (widget.transactions.isEmpty)
            Expanded(
              child: _AppEmptyState(
                emoji: widget.emptyText.contains('pemasukan') ? '💚' : '📭',
                title: 'Belum ada data',
                subtitle: widget.emptyText,
              ),
            )
          else
            Expanded(
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                child: ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(bottom: 100),
                  primary: false,
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  itemCount: widget.transactions.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) => _TransactionTile(
                    item: widget.transactions[index],
                    theme: widget.theme,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.item, required this.theme});

  final FinanceTransaction item;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final isIncome = item.type == 'INCOME';
    final parsedDate = DateTime.tryParse(item.date);
    final dateText = parsedDate == null
        ? item.date
        : DateFormat('dd MMM yyyy', 'id').format(parsedDate);
    final storedTime = item.time?.trim();
    final hasTime = storedTime != null && storedTime.isNotEmpty;
    final datetimeLabel = hasTime ? '$dateText • $storedTime' : dateText;
    final rupiahFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final amountText =
        '${isIncome ? '+' : '-'}${rupiahFormatter.format(item.amount)}';

    return Slidable(
      key: ValueKey(item.id),
      startActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (context) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => isIncome
                      ? IncomeInputScreen(existingTransaction: item)
                      : ExpenseInputScreen(existingTransaction: item),
                ),
              );
            },
            backgroundColor: const Color(0xFF6CC185),
            foregroundColor: Colors.white,
            icon: Icons.edit_rounded,
            label: 'Edit',
            borderRadius: BorderRadius.circular(12),
          ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (slidableCtx) async {
              if (!context.mounted) return;
              final provider = context.read<TransactionProvider>();
              final messenger = ScaffoldMessenger.of(context);

              // Optimistic removal dengan Undo
              messenger.clearSnackBars();
              final snackBarController = messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    '"${item.title}" dihapus.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  duration: const Duration(seconds: 5),
                  behavior: SnackBarBehavior.floating,
                  action: SnackBarAction(
                    label: 'Batalkan',
                    onPressed: () {
                      // Undo: tidak jadi hapus, snackbar dismiss sendiri
                    },
                  ),
                ),
              );

              final reason = await snackBarController.closed;
              if (!context.mounted) return;

              // Hanya hapus jika user TIDAK menekan Batalkan
              if (reason != SnackBarClosedReason.action) {
                try {
                  await provider.removeTransaction(item.id!);
                } catch (e) {
                  if (context.mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          'Gagal menghapus: ${e.toString().replaceFirst('Exception: ', '')}',
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              }
            },
            backgroundColor: AppTheme.expenseRed,
            foregroundColor: Colors.white,
            icon: Icons.delete_rounded,
            label: 'Hapus',
            borderRadius: BorderRadius.circular(12),
          ),
        ],
      ),
      child: AnimatedBouncingCard(
        isPressedEffect: true,
        onTap: () {
          // If you want tap to do something, add it here.
          // For now just for the bounce effect.
        },
        padding: const EdgeInsets.all(10),
        color: Theme.of(context).cardTheme.color ?? Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isIncome
                    ? AppTheme.incomeLight
                    : AppTheme.expenseLight,
                borderRadius: BorderRadius.circular(8),
                border: Theme.of(
                  context,
                ).extension<AppThemeExtension>()?.cardBorder,
              ),
              child: Icon(
                isIncome ? Icons.south_west_rounded : Icons.north_east_rounded,
                size: 16,
                color: isIncome ? AppTheme.incomeGreen : AppTheme.expenseRed,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isIncome ? null : const Color(0xFFC24545),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.category} • $datetimeLabel',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isIncome ? null : const Color(0xFFA13A3A),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amountText,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isIncome ? null : const Color(0xFFC24545),
                  ),
                ),
                const SizedBox(height: 2),
                Icon(
                  item.isSynced == 1
                      ? Icons.cloud_done_rounded
                      : Icons.cloud_off_rounded,
                  size: 16,
                  color: item.isSynced == 1
                      ? const Color(0xFF2A9D50)
                      : const Color(0xFFC24545),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardPocketSection extends StatelessWidget {
  final TransactionProvider provider;

  const _DashboardPocketSection({required this.provider});

  static const List<Color> _cardColors = [
    Color(0xFFFFF9E6), // Soft Yellow
    Color(0xFFF0F4C3), // Soft Lime
    Color(0xFFE8F5E9), // Soft Green
    Color(0xFFE0F7FA), // Soft Cyan
    Color(0xFFE3F2FD), // Soft Blue
    Color(0xFFF3E5F5), // Soft Purple
    Color(0xFFFFEBEE), // Soft Red
    Color(0xFFFFF3E0), // Soft Orange
  ];

  @override
  Widget build(BuildContext context) {
    final pockets = provider.pockets;

    final NumberFormat currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Kantong Kamu',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 145,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: pockets.length + 1,
            itemBuilder: (context, index) {
              if (index == pockets.length) {
                return Container(
                  width: 140,
                  margin: const EdgeInsets.only(right: 12),
                  child: Card(
                    elevation: 0,
                    color: const Color(0xFFFDF0FC), // Light purple
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.purple.shade50),
                    ),
                    margin: EdgeInsets.zero,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PocketFormScreen(),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(
                                color: Color(0xFF6B3076), // Dark purple circle
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Buat Kantong',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF111111),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }

              final pocket = pockets[index];
              final effectiveBalance = provider.getPocketEffectiveBalance(
                pocket.id!,
              );
              final isNegative = effectiveBalance < 0;
              final cardColor = _cardColors[index % _cardColors.length];

              return Container(
                width: 140,
                margin: const EdgeInsets.only(right: 12),
                child: Card(
                  elevation: 0,
                  color: cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  margin: EdgeInsets.zero,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              PocketDetailScreen(pocketId: pocket.id!),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: const Color(0xFFE5F0FF),
                            child: Icon(
                              IconPickerUtils.getIconData(pocket.icon),
                              color: const Color(0xFF0066FF),
                              size: 20,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            pocket.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF111111),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            currencyFormatter.format(effectiveBalance),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: isNegative
                                  ? const Color(0xFFE53935)
                                  : const Color(0xFF111111),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            pocket.allocationType == 'PERCENTAGE'
                                ? '${pocket.allocationValue.toInt()}% Pemasukan'
                                : 'Target: ${currencyFormatter.format(pocket.allocationValue)}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF666666),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.selectedColor,
    this.textColor,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? selectedColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? (selectedColor ?? const Color(0xFFA4DBB2))
              : Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(10),
          border: Theme.of(context).extension<AppThemeExtension>()?.cardBorder,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: selected
                ? (textColor ?? const Color(0xFF1F5A62))
                : Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
      ),
    );
  }
}

class _IconFilterButton extends StatelessWidget {
  const _IconFilterButton({
    required this.icon,
    required this.selected,
    required this.onTap,
    this.selectedColor,
    this.iconColor,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final Color? selectedColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 34,
        height: 30,
        decoration: BoxDecoration(
          color: selected
              ? (selectedColor ?? const Color(0xFFA4DBB2))
              : Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(10),
          border: Theme.of(context).extension<AppThemeExtension>()?.cardBorder,
        ),
        child: Icon(
          icon,
          size: 16,
          color: selected
              ? (iconColor ?? const Color(0xFF1F5A62))
              : Theme.of(context).iconTheme.color,
        ),
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.iconBackground,
    required this.onTap,
    this.labelColor,
    this.iconColor,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color iconBackground;
  final VoidCallback onTap;
  final Color? labelColor;
  final Color? iconColor;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOutCubic,
      scale: _isPressed ? 0.98 : 1,
      child: InkWell(
        onTap: widget.onTap,
        onHighlightChanged: (value) {
          if (_isPressed == value) return;
          setState(() => _isPressed = value);
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 34,
          decoration: BoxDecoration(
            color: widget.background,
            borderRadius: BorderRadius.circular(10),
            border: Theme.of(
              context,
            ).extension<AppThemeExtension>()?.cardBorder,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: widget.labelColor,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: widget.iconBackground,
                  borderRadius: BorderRadius.circular(4),
                  border: Theme.of(
                    context,
                  ).extension<AppThemeExtension>()?.cardBorder,
                ),
                child: Icon(widget.icon, size: 12, color: widget.iconColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          shape: BoxShape.circle,
          border: Theme.of(context).extension<AppThemeExtension>()?.cardBorder,
        ),
        child: Icon(icon, size: 16, color: Theme.of(context).iconTheme.color),
      ),
    );
  }
}

class _BarData {
  const _BarData(this.heightFactor, this.color, this.dayLabel, this.amount);

  final double heightFactor;
  final Color color;
  final String dayLabel;
  final double amount;
}

class _Bar extends StatefulWidget {
  const _Bar({required this.data, required this.selected, required this.onTap});

  final _BarData data;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_Bar> createState() => _BarState();
}

class _BarState extends State<_Bar> {
  late double _fromFactor;
  late double _toFactor;

  @override
  void initState() {
    super.initState();
    _fromFactor = widget.data.heightFactor;
    _toFactor = widget.data.heightFactor;
  }

  @override
  void didUpdateWidget(covariant _Bar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.heightFactor == widget.data.heightFactor) return;
    _fromFactor = _toFactor;
    _toFactor = widget.data.heightFactor;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: widget.onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: _fromFactor, end: _toFactor),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                builder: (context, animatedFactor, child) {
                  return FractionallySizedBox(
                    heightFactor: animatedFactor,
                    child: Container(
                      decoration: BoxDecoration(
                        color: widget.data.color,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: widget.selected
                              ? const Color(0xFF1F5A62)
                              : const Color(0xFF111111),
                          width: widget.selected ? 1.8 : 1.2,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            widget.data.dayLabel,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: widget.selected
                  ? const Color(0xFF1F5A62)
                  : (Theme.of(context).brightness == Brightness.dark
                        ? Colors.white70
                        : const Color(0xFF3B3B55)),
            ),
          ),
        ],
      ),
    );
  }
}
