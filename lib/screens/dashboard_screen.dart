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
import 'book_transfer_screen.dart';
import '../utils/icon_picker_utils.dart';
import '../widgets/app_card.dart';
import '../widgets/dashboard/dashboard_buttons.dart';
import '../widgets/dashboard/balance_card.dart';
import '../widgets/dashboard/dashboard_pocket_section.dart';
import '../widgets/dashboard/graph_card.dart';
import '../widgets/dashboard/book_period_card.dart';
import '../widgets/dashboard/financial_plan_card.dart';
import '../widgets/dashboard/recent_section.dart';
import '../widgets/dashboard/transactions_card.dart';
import '../widgets/dashboard/financial_plan_dialog.dart';
import '../widgets/dashboard/quick_menu.dart';

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
  ChartDetail? _selectedChartDetail;

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
    final targetBooks = provider.bookPeriods.toList(growable: false);

    if (targetBooks.isEmpty) {
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
      targetBooks: targetBooks,
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
            category: draft.category,
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

  Future<FinancialPlanDraft?> _openFinancialPlanInputDialog({
    String title = 'Rencana Keuangan Baru',
    String actionLabel = 'Simpan',
    required List<BookPeriod> targetBooks,
    int? defaultBookId,
    FinancialPlan? initialPlan,
  }) async {
    return showZoomDialog<FinancialPlanDraft?>(
      context: context,
      builder: (dialogContext) {
        return FinancialPlanInputDialog(
          title: title,
          actionLabel: actionLabel,
          targetBooks: targetBooks,
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
    final targetBooks = provider.bookPeriods.toList(growable: false);

    if (targetBooks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belum ada buku yang tersedia.')),
      );
      return;
    }

    final draft = await _openFinancialPlanInputDialog(
      title: 'Edit Rencana Keuangan',
      actionLabel: 'Update',
      targetBooks: targetBooks,
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
            category: draft.category,
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
    final shouldDelete = await showZoomDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Konfirmasi Hapus'),
          content: const Text(
            'Apakah kamu yakin ingin menghapus rencana keuangan ini?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Tidak'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF0C8C8),
                foregroundColor: const Color(0xFFC24545),
              ),
              child: const Text('Ya, Hapus'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    try {
      await context.read<TransactionProvider>().removeFinancialPlan(id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _openEditPlanBudgetDialog(
    int bookPeriodId,
    double currentBudget,
  ) async {
    final controller = TextEditingController(
      text: currentBudget > 0
          ? NumberFormat.decimalPattern('id_ID').format(currentBudget)
          : '',
    );
    final result = await showZoomDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Budget Rencana'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [RupiahInputFormatter()],
            decoration: const InputDecoration(
              hintText: 'Misal: 7000000',
              prefixText: 'Rp ',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                final val = RupiahInputFormatter.parse(controller.text);
                Navigator.pop(context, val);
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      try {
        await context.read<TransactionProvider>().updateBookPlanBudget(
          bookPeriodId,
          result,
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
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
        const SnackBar(content: Text('Buku baru berhasil dibuka. Semangat!')),
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
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: confirmationController,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => submit(),
                      decoration: const InputDecoration(
                        hintText: 'Ketik HAPUS untuk konfirmasi',
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
                                          ? (isDark
                                                ? const Color(0xFF1A3B66)
                                                : const Color(0xFFE5F0FF))
                                          : (isDark
                                                ? const Color(0xFF2D2D2D)
                                                : Colors.white),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFF0066FF)
                                            : (isDark
                                                  ? Colors.grey.shade800
                                                  : Colors.grey.shade300),
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
                                                : (isDark
                                                      ? const Color(0xFF3D3D3D)
                                                      : const Color(
                                                          0xFFF0F0F0,
                                                        )),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            isActive
                                                ? Icons.menu_book_rounded
                                                : Icons.lock_outline_rounded,
                                            color: isSelected
                                                ? Colors.white
                                                : (isDark
                                                      ? Colors.grey.shade300
                                                      : Colors.grey.shade600),
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
                                                      ? (isDark
                                                            ? const Color(
                                                                0xFF66A3FF,
                                                              )
                                                            : const Color(
                                                                0xFF0066FF,
                                                              ))
                                                      : (isDark
                                                            ? Colors.white
                                                            : const Color(
                                                                0xFF111111,
                                                              )),
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                subtitle,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: isSelected
                                                      ? (isDark
                                                            ? const Color(
                                                                0xFF66A3FF,
                                                              ).withOpacity(0.8)
                                                            : const Color(
                                                                0xFF0066FF,
                                                              ).withOpacity(
                                                                0.8,
                                                              ))
                                                      : (isDark
                                                            ? Colors
                                                                  .grey
                                                                  .shade400
                                                            : Colors
                                                                  .grey
                                                                  .shade600),
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
          padding: const EdgeInsets.fromLTRB(5, 10, 5, 0),
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
                                    CircleIconButton(
                                      icon: Icons.shopping_cart_outlined,
                                      onTap: () {
                                        setState(() {
                                          _previousIndex = _currentIndex;
                                          _currentIndex = 2;
                                        });
                                      },
                                    ),
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
                                  animate: provider.unreadNotificationCount > 0,
                                  child: CircleIconButton(
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
      floatingActionButton: ExpandableQuickMenu(
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
                QuickAddSheetItem(
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
                QuickAddSheetItem(
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
                Consumer<TransactionProvider>(
                  builder: (context, provider, child) {
                    final totalBooksCount = provider.bookPeriods.length;
                    if (totalBooksCount >= 2) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: QuickAddSheetItem(
                          icon: Icons.swap_horiz_rounded,
                          title: 'Transfer Antar Buku',
                          subtitle: 'Pindahkan saldo ke buku lain',
                          color: const Color(0xFFE3F2FD),
                          iconColor: const Color(0xFF0066FF),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const BookTransferScreen(),
                              ),
                            );
                          },
                        ),
                      );
                    }
                    return const SizedBox.shrink();
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
          totalIncome: totalIncome,
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
                child: BalanceCard(
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
                child: DashboardPocketSection(provider: provider),
              ),
              const SizedBox(height: 10),
              // Chart — slide from bottom
              EntranceAnimation(
                type: EntranceType.slideUp,
                delay: const Duration(milliseconds: 500),
                duration: const Duration(milliseconds: 700),
                child: GraphCard(
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
                child: RecentSection(
                  theme: theme,
                  transactions: filteredRecent,
                  isLoading: provider.isLoading,
                  headerBottom: Row(
                    children: [
                      FilterButton(
                        label: 'Pemasukan',
                        selected: _recentFilter == 'INCOME',
                        onTap: () => setState(() {
                          _recentFilter = _recentFilter == 'INCOME'
                              ? 'ALL'
                              : 'INCOME';
                        }),
                      ),
                      const SizedBox(width: 8),
                      FilterButton(
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
    required double totalIncome,
  }) {
    final realizationByPlan = <int, double>{};
    for (final tx in allTransactions) {
      final planId = tx.financialPlanId;
      if (tx.type != 'EXPENSE' || planId == null) continue;
      realizationByPlan[planId] = (realizationByPlan[planId] ?? 0) + tx.amount;
    }

    final sortedFinancialPlans = List<FinancialPlan>.from(financialPlans)
      ..sort((a, b) {
        final realizationA = realizationByPlan[a.id] ?? 0;
        final realizationB = realizationByPlan[b.id] ?? 0;
        final progressA = a.targetAmount > 0 ? (realizationA / a.targetAmount).clamp(0.0, 1.0) : 0.0;
        final progressB = b.targetAmount > 0 ? (realizationB / b.targetAmount).clamp(0.0, 1.0) : 0.0;
        return progressA.compareTo(progressB);
      });

    return DefaultTabController(
      length: 5,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            labelColor: theme.colorScheme.primary.computeLuminance() > 0.6
                ? theme.colorScheme.onSurface
                : theme.colorScheme.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: theme.colorScheme.primary.computeLuminance() > 0.6
                ? theme.colorScheme.onSurface
                : theme.colorScheme.primary,
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
                TransactionsCard(
                  theme: theme,
                  title: '',
                  titleColor: const Color(0xFFC24545),
                  transactions: expenseTransactions,
                  isLoading: provider.isLoading,
                  emptyText: 'Belum ada data pengeluaran.',
                ),
                TransactionsCard(
                  theme: theme,
                  title: '',
                  transactions: incomeTransactions,
                  isLoading: provider.isLoading,
                  emptyText: 'Belum ada data pemasukan.',
                ),
                FinancialPlanCard(
                  theme: theme,
                  plans: sortedFinancialPlans,
                  isLoading: provider.isLoading,
                  realizationByPlan: realizationByPlan,
                  isSaving: _isSavingFinancialPlan,
                  planBudget: totalIncome > 0 
                      ? totalIncome 
                      : provider.bookPeriods
                          .firstWhere(
                            (b) =>
                                b.id ==
                                (provider.selectedBookPeriodId ??
                                    provider.activeBookPeriod?.id),
                            orElse: () => const BookPeriod(
                              label: '',
                              startDate: '',
                              planBudget: 0.0,
                            ),
                          )
                          .planBudget,
                  canEditBudget: totalIncome <= 0,
                  onAddPlan: _openAddFinancialPlanDialog,
                  onEditPlan: _openEditFinancialPlanDialog,
                  onDeletePlan: _removeFinancialPlan,
                  onEditBudget: () {
                    final bookId =
                        provider.selectedBookPeriodId ??
                        provider.activeBookPeriod?.id;
                    if (bookId != null) {
                      final current = provider.bookPeriods
                          .firstWhere(
                            (b) => b.id == bookId,
                            orElse: () => const BookPeriod(
                              label: '',
                              startDate: '',
                              planBudget: 0.0,
                            ),
                          )
                          .planBudget;
                      _openEditPlanBudgetDialog(bookId, current);
                    }
                  },
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
              icon: const Icon(
                Icons.add_box_rounded,
                color: AppTheme.incomeGreen,
              ),
              label: const Text(
                'Buka Buku Baru',
                style: TextStyle(color: AppTheme.incomeGreen),
              ),
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
                      subtitle:
                          'Buka buku pertama untuk mulai mencatat keuanganmu.',
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
                        child: AppCard(
                          isInteractive: true,
                          onTap: () {
                            provider.selectBookPeriod(period.id);
                            setState(() {
                              _selectedChartDetail = null;
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          color: isSelected
                              ? Theme.of(context).colorScheme.primaryContainer
                              : null,
                          border: isSelected
                              ? Border.all(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 2,
                                )
                              : null,
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : (isDark
                                            ? const Color(0xFF3D3D3D)
                                            : const Color(0xFFF0F0F0)),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isActive
                                      ? Icons.menu_book_rounded
                                      : Icons.lock_outline_rounded,
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : (isDark
                                            ? Colors.grey.shade300
                                            : Colors.grey.shade600),
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
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: isSelected
                                                ? (isDark
                                                      ? Colors.white
                                                      : Colors.black)
                                                : null,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      subtitle,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected) ...[
                                Icon(
                                  Icons.check_circle,
                                  color:
                                      Theme.of(context).colorScheme.primary
                                              .computeLuminance() >
                                          0.6
                                      ? Theme.of(context).colorScheme.onSurface
                                      : Theme.of(context).colorScheme.primary,
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
            Text(emoji, style: const TextStyle(fontSize: 52)),
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
              FilledButton.tonal(onPressed: onCtaTap, child: Text(ctaLabel!)),
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
