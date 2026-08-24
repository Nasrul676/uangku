import 'dart:async';

import 'package:image_cropper/image_cropper.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/book_period.dart';
import '../models/finance_transaction.dart';
import '../models/financial_plan.dart';
import '../models/pocket.dart';
import '../providers/transaction_provider.dart';
import '../providers/shopping_provider.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_transitions.dart';
import '../utils/rupiah_input_formatter.dart';
import '../widgets/animated_bell_icon.dart';
import '../widgets/entrance_animation.dart';
import '../widgets/success_overlay.dart';
import '../widgets/custom_bottom_sheet.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'expense_input_screen.dart';
import 'income_input_screen.dart';
import 'money_location_list_screen.dart';
import 'money_transfer_screen.dart';
import 'settings_screen.dart';
import 'shopping_list_screen.dart';
import 'book_period_recap_screen.dart';
import 'pocket_form_screen.dart';
import 'book_transfer_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:lottie/lottie.dart';
import '../services/ai_assistant_service.dart';
import 'receipt_result_screen.dart';
import '../widgets/app_card.dart';
import '../widgets/dashboard/dashboard_buttons.dart';
import '../widgets/dashboard/balance_card.dart';
import '../widgets/dashboard/daily_allowance_card.dart';
import '../widgets/dashboard/greeting_header.dart';
import '../widgets/dashboard/pira_mascot.dart';
import '../utils/daily_budget.dart';
import '../widgets/dashboard/dashboard_pocket_section.dart';
import '../widgets/dashboard/graph_card.dart';
import '../widgets/dashboard/financial_plan_card.dart';
import '../widgets/dashboard/recent_section.dart';
import '../widgets/dashboard/transactions_card.dart';
import '../widgets/dashboard/financial_plan_dialog.dart';
import '../widgets/dashboard/quick_menu.dart';
import '../widgets/ai_chat_bubble.dart';
import '../widgets/calculator_bubble.dart';
import '../utils/error_message.dart';
import '../widgets/item_actions_menu.dart';

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

  /// Dipakai untuk menyuruh PiRa bereaksi setelah transaksi tersimpan —
  /// tanda bahwa catatannya masuk, bukan cuma layar yang tertutup.
  final GlobalKey<PiraMascotState> _mascotKey = GlobalKey<PiraMascotState>();
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

  Future<void> _makePocketFromPlan(FinancialPlan plan) async {
    final provider = context.read<TransactionProvider>();
    final bookId =
        provider.selectedBookPeriodId ?? provider.activeBookPeriod?.id;

    if (bookId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih buku terlebih dahulu.')),
      );
      return;
    }

    final existing = provider.pockets.any(
      (pocket) =>
          pocket.name.trim().toLowerCase() == plan.title.trim().toLowerCase(),
    );
    if (existing) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kantong "${plan.title}" sudah ada di buku ini.'),
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PocketFormScreen(
          pocket: Pocket(
            bookPeriodId: bookId,
            name: plan.title,
            icon: 'savings',
            allocationType: 'NOMINAL',
            allocationValue: plan.targetAmount,
          ),
        ),
      ),
    );
  }

  Future<void> _cloneFinancialPlan(FinancialPlan plan) async {
    final provider = context.read<TransactionProvider>();
    final bookPeriods = provider.bookPeriods.toList(growable: false);

    if (bookPeriods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belum ada buku untuk tujuan kloning.')),
      );
      return;
    }

    showCustomBottomSheet(
      context: context,
      title: 'Pilih Buku Tujuan',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: bookPeriods.map((book) {
          return ListTile(
            leading: const Icon(Icons.book_rounded),
            title: Text(book.label),
            onTap: () async {
              Navigator.pop(context);
              setState(() => _isSavingFinancialPlan = true);

              DateTime originalTargetDate =
                  DateTime.tryParse(plan.targetDate) ?? DateTime.now();
              DateTime bookStartDate =
                  DateTime.tryParse(book.startDate) ?? DateTime.now();

              int targetYear = bookStartDate.year;
              int targetMonth = bookStartDate.month;
              int targetDay = originalTargetDate.day;

              int maxDaysInTargetMonth = DateTime(
                targetYear,
                targetMonth + 1,
                0,
              ).day;
              if (targetDay > maxDaysInTargetMonth) {
                targetDay = maxDaysInTargetMonth;
              }

              DateTime newTargetDate = DateTime(
                targetYear,
                targetMonth,
                targetDay,
              );
              if (newTargetDate.isBefore(bookStartDate)) {
                newTargetDate = bookStartDate;
              }

              try {
                await provider.addFinancialPlan(
                  title: plan.title,
                  targetAmount: plan.targetAmount,
                  targetDate: newTargetDate,
                  category: plan.category,
                  bookPeriodId: book.id,
                );
                if (mounted) {
                  SuccessOverlay.show(
                    context,
                    message: 'Rencana berhasil dikloning ke ${book.label}',
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
                }
              } finally {
                if (mounted) {
                  setState(() => _isSavingFinancialPlan = false);
                }
              }
            },
          );
        }).toList(),
      ),
    );
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) {
        setState(() => _isSavingFinancialPlan = false);
      }
    }
  }

  Future<FinancialPlanDraft?> _openFinancialPlanInputDialog({
    String title = 'Rencana baru',
    String actionLabel = 'Simpan rencana',
    required List<BookPeriod> targetBooks,
    int? defaultBookId,
    FinancialPlan? initialPlan,
  }) async {
    return showFinancialPlanSheet(
      context: context,
      title: title,
      actionLabel: actionLabel,
      targetBooks: targetBooks,
      defaultBookId: defaultBookId,
      parsePlanAmount: _parsePlanAmount,
      initialPlan: initialPlan,
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
      title: 'Edit rencana',
      actionLabel: 'Simpan perubahan',
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
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
                backgroundColor: AppTheme.expenseLight,
                foregroundColor: AppTheme.expenseRed,
              ),
              child: const Text('Ya, Hapus'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !mounted) return;

    try {
      await context.read<TransactionProvider>().removeFinancialPlan(id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
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

    if (result != null && mounted) {
      try {
        await context.read<TransactionProvider>().updateBookPlanBudget(
          bookPeriodId,
          result,
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
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

  /// PiRa menyapa balik saat dicolek. Kalimatnya ikut suasana, jadi
  /// mencoleknya tetap memberi kabar — bukan sekadar gerakan lucu.
  void _greetFromPira(PiraMood mood) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(greetingForMood(mood)),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
      _mascotKey.currentState?.react();
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
      _mascotKey.currentState?.react();
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
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
                          color: AppTheme.expenseRed,
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
                    backgroundColor: AppTheme.expenseLight,
                    foregroundColor: AppTheme.expenseRed,
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
                              tooltip: 'Tutup',
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

  String _getScreenContext() {
    switch (_currentIndex) {
      case 0:
        return "Beranda - Menampilkan ringkasan saldo, pengeluaran, pemasukan dan transaksi terakhir bulan ini.";
      case 1:
        return "Daftar Transaksi - Menampilkan seluruh riwayat pengeluaran dan pemasukan pengguna.";
      case 2:
        return "Daftar Belanja - Menampilkan daftar barang yang akan dibeli oleh pengguna.";
      default:
        return "Aplikasi Uangku - Halaman utama.";
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(5, 10, 5, 0),
              child: Consumer<TransactionProvider>(
                builder: (context, provider, _) {
                  final allTransactions = provider.transactions;
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
                  final userName = _userName;
                  // Sapaannya menyatu di sini, bukan diulang lagi di badan
                  // halaman. Waktunya ikut jam supaya terasa menyapa, bukan
                  // memasang label tetap.
                  final hello = greetingFor(DateTime.now());
                  final greeting = userName.isEmpty
                      ? '$hello 👋'
                      : '$hello, $userName 👋';

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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        greeting,
                                        style: theme.textTheme.titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                Consumer<ShoppingProvider>(
                                  builder: (context, shoppingProvider, child) {
                                    final count =
                                        shoppingProvider.unboughtCount;
                                    return Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        CircleIconButton(
                                          tooltip: 'Daftar belanja',
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
                                                  color: const Color(
                                                    0xFF111111,
                                                  ),
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
                                      child: CircleIconButton(
                                        tooltip: 'Notifikasi',
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
                              reverseDuration: const Duration(
                                milliseconds: 260,
                              ),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              transitionBuilder: (child, animation) {
                                final isForward =
                                    _currentIndex >= _previousIndex;
                                final isIncoming = child.key == currentTabKey;
                                final horizontalShift = isForward
                                    ? 0.16
                                    : -0.16;

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
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
          floatingActionButton: ExpandableQuickMenu(
            selectedIndex: _currentIndex,
            onMenuTap: _onMenuTap,
            onOpenQuickAdd: _openQuickAddSheet,
          ),
        ),
        if (_currentIndex != 3)
          AiChatBubble(currentContext: _getScreenContext()),
        if (_currentIndex != 3) const CalculatorBubble(),
      ],
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
                          iconColor: AppTheme.primaryBlue,
                          onTap: () {
                            Navigator.pop(sheetContext);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const BookTransferScreen(),
                              ),
                            );
                          },
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                // Pindah uang butuh dua tempat. Kalau syaratnya belum
                // terpenuhi, menawarkannya cuma mengantar pengguna ke jalan
                // buntu — sama seperti "Transfer Antar Buku" di atas.
                Consumer<TransactionProvider>(
                  builder: (context, provider, child) {
                    if (provider.moneyLocations.length < 2) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: QuickAddSheetItem(
                        icon: Icons.sync_alt_rounded,
                        title: 'Pindah Uang',
                        subtitle: 'Tarik tunai, setor, atau top-up e-wallet',
                        color: const Color(0xFFE0F2F1),
                        iconColor: AppTheme.fabIconColor,
                        onTap: () {
                          Navigator.pop(sheetContext);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MoneyTransferScreen(),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                QuickAddSheetItem(
                  icon: Icons.document_scanner_rounded,
                  title: 'Scan Struk (AI)',
                  subtitle: 'Otomatis catat dari foto struk',
                  color: const Color(0xFFF3E5F5),
                  iconColor: const Color(0xFF9C27B0),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _scanReceiptProcess();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<String?> _cropImage(String imagePath) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: imagePath,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Struk',
          toolbarColor: isDark
              ? const Color(0xFF1E1E2E)
              : theme.colorScheme.primary,
          toolbarWidgetColor: Colors.white,
          backgroundColor: isDark ? const Color(0xFF121212) : Colors.black,
          activeControlsWidgetColor: theme.colorScheme.primary,
          dimmedLayerColor: Colors.black54,
          cropFrameColor: theme.colorScheme.primary,
          cropGridColor: theme.colorScheme.primary.withAlpha(80),
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
          hideBottomControls: false,
        ),
        IOSUiSettings(
          title: 'Crop Struk',
          doneButtonTitle: 'Selesai',
          cancelButtonTitle: 'Batal',
          resetAspectRatioEnabled: true,
          aspectRatioLockEnabled: false,
          rotateButtonsHidden: false,
          rotateClockwiseButtonHidden: true,
        ),
      ],
    );

    return croppedFile?.path;
  }

  Future<void> _scanReceiptProcess() async {
    final source = await showModalBottomSheet<ImageSource>(
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
                  'Pilih Sumber Gambar',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.camera_alt_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  title: const Text(
                    'Kamera',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.photo_library_rounded,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                  title: const Text(
                    'Galeri Foto',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (source == null) return;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (pickedFile == null) return;

    if (!mounted) return;

    // Buka cropper agar user bisa memotong area struk
    final croppedPath = await _cropImage(pickedFile.path);
    if (croppedPath == null) return; // User membatalkan crop

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).cardTheme.color ??
                  Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset(
                  'assets/lottie/loading.json',
                  width: 120,
                  height: 120,
                ),
                const SizedBox(height: 16),
                Text(
                  'AI sedang memproses struk...',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final inputImage = InputImage.fromFilePath(croppedPath);
      final textRecognizer = TextRecognizer();
      final recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      if (!mounted) return;
      final provider = context.read<TransactionProvider>();
      final categories = provider.expenseCategories;

      final parsedItems = await AiAssistantService.parseReceiptText(
        ocrText: recognizedText.text,
        categories: categories,
        apiKey: provider.geminiApiKey,
        model: provider.geminiModel,
      );

      if (mounted) Navigator.pop(context); // Close loading dialog

      if (mounted && parsedItems.isNotEmpty) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReceiptResultScreen(
              items: parsedItems,
              receiptImageFilePath: croppedPath,
            ),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak ada barang yang terdeteksi dari struk ini.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal memproses struk: $e')));
      }
    }
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
        final now = DateTime.now();
        final activeBook = provider.activeBookPeriod;
        final budget = activeBook == null
            ? null
            : buildDailyBudget(
                book: activeBook,
                transactions: allTransactions,
                balance: netBalance,
                today: now,
              );
        // Rasio yang sama dipakai `BookRecap.spentRatio` di laporan, jadi
        // wajah celengan dan angka laporan tidak akan pernah bercerita beda.
        final mood = moodForRatio(
          totalIncome > 0 ? totalExpense / totalIncome : null,
        );

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          child: Column(
            children: [
              EntranceAnimation(
                type: EntranceType.fadeScale,
                delay: const Duration(milliseconds: 50),
                duration: const Duration(milliseconds: 500),
                child: GreetingHeader(now: now, activeBook: activeBook),
              ),
              const SizedBox(height: 6),
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
                  mood: mood,
                  budget: budget,
                  mascotKey: _mascotKey,
                  onTapMascot: () => _greetFromPira(mood),
                  locations: provider.moneyLocationSummaries,
                  unassignedBalance: provider.unassignedMoneyBalance,
                  onManageLocations: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MoneyLocationListScreen(),
                    ),
                  ),
                ),
              ),
              if (budget != null && !provider.isBalanceHidden) ...[
                const SizedBox(height: 4),
                EntranceAnimation(
                  type: EntranceType.slideUp,
                  delay: const Duration(milliseconds: 300),
                  duration: const Duration(milliseconds: 500),
                  child: DailyAllowanceCard(budget: budget),
                ),
              ],
              const SizedBox(height: 10),
              // Pockets — muncul satu per satu (animasi di dalam widget)
              DashboardPocketSection(provider: provider),
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
                  moneyLocationNames: provider.moneyLocationNames,
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
                        textColor: AppTheme.expenseRed,
                        selectedColor: AppTheme.expenseLight,
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
        final progressA = a.targetAmount > 0
            ? (realizationA / a.targetAmount).clamp(0.0, 1.0)
            : 0.0;
        final progressB = b.targetAmount > 0
            ? (realizationB / b.targetAmount).clamp(0.0, 1.0)
            : 0.0;
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
                  titleColor: AppTheme.expenseRed,
                  transactions: expenseTransactions,
                  isLoading: provider.isLoading,
                  emptyText: 'Belum ada data pengeluaran.',
                  moneyLocationNames: provider.moneyLocationNames,
                ),
                TransactionsCard(
                  theme: theme,
                  title: '',
                  transactions: incomeTransactions,
                  isLoading: provider.isLoading,
                  emptyText: 'Belum ada data pemasukan.',
                  moneyLocationNames: provider.moneyLocationNames,
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
                  onClonePlan: _cloneFinancialPlan,
                  onMakePocketFromPlan: _makePocketFromPlan,
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
                        endActionPane: ActionPane(
                          motion: const ScrollMotion(),
                          children: [
                            SlidableAction(
                              onPressed: (_) {
                                _deleteBookFlow(period);
                              },
                              backgroundColor: AppTheme.expenseRed,
                              foregroundColor: Colors.white,
                              icon: Icons.delete_rounded,
                              label: 'Hapus',
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
                              ItemActionsMenu(
                                semanticLabel:
                                    'Aksi untuk buku ${period.label}',
                                actions: [
                                  if (isActive)
                                    ItemAction(
                                      label: 'Tutup Buku',
                                      icon: Icons.bookmark_remove_rounded,
                                      onSelected: () =>
                                          _closeActiveBookFlow(period),
                                    )
                                  else
                                    ItemAction(
                                      label: 'Buka Lagi',
                                      icon: Icons.restore_rounded,
                                      onSelected: () => _reopenBookFlow(period),
                                    ),
                                  ItemAction(
                                    label: 'Hapus Buku',
                                    icon: Icons.delete_rounded,
                                    onSelected: () => _deleteBookFlow(period),
                                    isDestructive: true,
                                  ),
                                ],
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
