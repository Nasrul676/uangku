import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/transaction_provider.dart';
import '../services/auth_service.dart';
import 'onboarding_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE6EBFA),
      appBar: AppBar(title: const Text('Setelan Aplikasi')),
      body: const SettingsContent(),
    );
  }
}

class SettingsContent extends StatefulWidget {
  const SettingsContent({super.key});

  @override
  State<SettingsContent> createState() => _SettingsContentState();
}

class _SettingsContentState extends State<SettingsContent> {
  late final TextEditingController _urlController;
  late final TextEditingController _payloadRootController;
  late final TextEditingController _incomeCategoriesController;
  late final TextEditingController _expenseCategoriesController;
  late final Map<String, TextEditingController> _mappingControllers;
  final _authService = AuthService();
  String _currentUserName = '';
  String _currentUserEmail = '';
  late TimeOfDay _notificationTime;
  bool _isSavingNotificationTime = false;
  bool _isSendingNotificationDemo = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<TransactionProvider>();
    _urlController = TextEditingController(text: provider.webAppUrl);
    _payloadRootController = TextEditingController(
      text: provider.payloadRootKey,
    );
    _incomeCategoriesController = TextEditingController(
      text: provider.incomeCategories.join(', '),
    );
    _expenseCategoriesController = TextEditingController(
      text: provider.expenseCategories.join(', '),
    );
    _notificationTime = TimeOfDay(
      hour: provider.planNotificationHour,
      minute: provider.planNotificationMinute,
    );

    _mappingControllers = {
      'id': TextEditingController(text: provider.jsonKeyMapping['id'] ?? 'id'),
      'book_period_id': TextEditingController(
        text: provider.jsonKeyMapping['book_period_id'] ?? 'book_period_id',
      ),
      'financial_plan_id': TextEditingController(
        text:
            provider.jsonKeyMapping['financial_plan_id'] ?? 'financial_plan_id',
      ),
      'title': TextEditingController(
        text: provider.jsonKeyMapping['title'] ?? 'title',
      ),
      'amount': TextEditingController(
        text: provider.jsonKeyMapping['amount'] ?? 'amount',
      ),
      'type': TextEditingController(
        text: provider.jsonKeyMapping['type'] ?? 'type',
      ),
      'category': TextEditingController(
        text: provider.jsonKeyMapping['category'] ?? 'category',
      ),
      'date': TextEditingController(
        text: provider.jsonKeyMapping['date'] ?? 'date',
      ),
      'time': TextEditingController(
        text: provider.jsonKeyMapping['time'] ?? 'time',
      ),
      'is_synced': TextEditingController(
        text: provider.jsonKeyMapping['is_synced'] ?? 'is_synced',
      ),
    };

    _loadAccountInfo();
  }

  Future<void> _loadAccountInfo() async {
    final name = await _authService.getCurrentUserName();
    final email = await _authService.getCurrentUserEmail();
    if (!mounted) return;
    setState(() {
      _currentUserName = name;
      _currentUserEmail = email;
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    _payloadRootController.dispose();
    _incomeCategoriesController.dispose();
    _expenseCategoriesController.dispose();
    for (final controller in _mappingControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  List<String> _splitManualCategories(String text, List<String> fallback) {
    final result = text
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    return result.isEmpty ? fallback : result;
  }

  Future<void> _save() async {
    final mapping = <String, String>{};
    for (final entry in _mappingControllers.entries) {
      mapping[entry.key] = entry.value.text.trim().isEmpty
          ? entry.key
          : entry.value.text.trim();
    }

    final provider = context.read<TransactionProvider>();

    await provider.saveSyncSettings(
      webAppUrl: _urlController.text.trim(),
      payloadRootKey: _payloadRootController.text.trim().isEmpty
          ? 'transaksi'
          : _payloadRootController.text.trim(),
      jsonKeyMapping: mapping,
      incomeCategories: _splitManualCategories(
        _incomeCategoriesController.text,
        provider.incomeCategories,
      ),
      expenseCategories: _splitManualCategories(
        _expenseCategoriesController.text,
        provider.expenseCategories,
      ),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Setelan berhasil disimpan.')));
  }

  Future<void> _pickNotificationTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _notificationTime,
    );
    if (picked == null || !mounted) return;
    setState(() => _notificationTime = picked);
  }

  Future<void> _saveNotificationTime() async {
    if (_isSavingNotificationTime) return;
    setState(() => _isSavingNotificationTime = true);

    try {
      await context.read<TransactionProvider>().savePlanNotificationTime(
        hour: _notificationTime.hour,
        minute: _notificationTime.minute,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Jam notifikasi rencana berhasil disimpan.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingNotificationTime = false);
      }
    }
  }

  Future<void> _sendNotificationDemo() async {
    if (_isSendingNotificationDemo) return;
    setState(() => _isSendingNotificationDemo = true);

    try {
      await context
          .read<TransactionProvider>()
          .showFinancialPlanNotificationDemo();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notifikasi demo berhasil dikirim.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _isSendingNotificationDemo = false);
      }
    }
  }

  String _notificationTimeLabel() {
    return MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(_notificationTime, alwaysUse24HourFormat: true);
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Keluar Akun'),
          content: const Text('Yakin mau keluar dulu dari akun ini?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Nanti Dulu'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Ya, Keluar'),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true) return;

    await _authService.logout();
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Akun yang Sedang Dipakai',
                  style: theme.textTheme.titleMedium?.copyWith(fontSize: 24),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.person_rounded),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _currentUserName.isEmpty
                            ? 'Nama akun belum tersedia'
                            : _currentUserName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.email_rounded),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _currentUserEmail.isEmpty
                            ? 'Email akun belum tersedia'
                            : _currentUserEmail,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notifikasi Rencana Keuangan',
                  style: theme.textTheme.titleMedium?.copyWith(fontSize: 24),
                ),
                const SizedBox(height: 6),
                Text(
                  'Atur jam notifikasi saat rencana keuangan mencapai tanggal target.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: _pickNotificationTime,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      hintText: 'Jam notifikasi',
                      prefixIcon: Icon(Icons.access_time_rounded),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: Text(_notificationTimeLabel())),
                        const Icon(Icons.expand_more_rounded),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 46,
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSavingNotificationTime
                        ? null
                        : _saveNotificationTime,
                    child: _isSavingNotificationTime
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Simpan Jam Notifikasi'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 46,
                  width: double.infinity,
                  child: FilledButton.tonal(
                    onPressed: _isSendingNotificationDemo
                        ? null
                        : _sendNotificationDemo,
                    child: _isSendingNotificationDemo
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Kirim Notifikasi Demo'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Atur Kategori',
                  style: theme.textTheme.titleMedium?.copyWith(fontSize: 24),
                ),
                const SizedBox(height: 6),
                Text(
                  'Pisahkan antar kategori pakai koma (,).',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _incomeCategoriesController,
                  decoration: const InputDecoration(
                    hintText:
                        'Kategori pemasukan (contoh: Gaji, Bonus, Jualan)',
                    prefixIcon: Icon(Icons.trending_up_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _expenseCategoriesController,
                  decoration: const InputDecoration(
                    hintText:
                        'Kategori pengeluaran (contoh: Belanja, Makan, Tagihan)',
                    prefixIcon: Icon(
                      Icons.trending_down_rounded,
                      color: Color(0xFFC24545),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Koneksi Google Apps Script',
                  style: theme.textTheme.titleMedium?.copyWith(fontSize: 24),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    hintText: 'URL Web App',
                    prefixIcon: Icon(Icons.link_rounded),
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _payloadRootController,
                  decoration: const InputDecoration(
                    hintText: 'Kunci root payload (contoh: transaksi)',
                    prefixIcon: Icon(Icons.data_object_rounded),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pemetaan Data JSON',
                  style: theme.textTheme.titleMedium?.copyWith(fontSize: 24),
                ),
                const SizedBox(height: 4),
                Text(
                  'Samakan dengan nama kolom di Google Sheets kamu.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                ..._mappingControllers.entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextField(
                      controller: entry.value,
                      decoration: InputDecoration(
                        hintText: entry.key,
                        prefixIcon: const Icon(Icons.tune_rounded),
                        labelText: entry.key,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 52,
          child: FilledButton(
            onPressed: _save,
            child: const Text('Simpan Setelan'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 52,
          child: FilledButton.tonal(
            onPressed: _logout,
            child: const Text('Keluar Akun'),
          ),
        ),
      ],
    );
  }
}
