import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/transaction_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/backup_restore_tile.dart';
import '../services/auth_service.dart';
import '../widgets/custom_loading_indicator.dart';
import 'onboarding_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.isEmbedded = false});

  final bool isEmbedded;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isEmbedded
          ? Colors.transparent
          : Theme.of(context).scaffoldBackgroundColor,
      appBar: isEmbedded ? null : AppBar(title: const Text('Setelan Aplikasi')),
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
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
      children: [
        AppCard(isInteractive: true,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tampilan Tema',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Pilih gaya desain yang paling nyaman buatmu.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              const _ThemeSelectorRow(),
            ],
          ),
        ),
        const SizedBox(height: 10),
        AppCard(isInteractive: true,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mode Gelap',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Sesuaikan tampilan aplikasi dengan kenyamanan matamu.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              const _ThemeModeSelector(),
            ],
          ),
        ),
        const SizedBox(height: 10),
        AppCard(isInteractive: true,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gaya Huruf',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Pilih jenis huruf yang sesuai dengan seleramu.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              const _FontSelectorRow(),
            ],
          ),
        ),
        const SizedBox(height: 10),
        AppCard(isInteractive: true,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Akun yang Sedang Dipakai',
                style: theme.textTheme.titleMedium,
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
                      style: theme.textTheme.labelLarge,
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
        const SizedBox(height: 10),
        AppCard(isInteractive: true,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Notifikasi Rencana Keuangan',
                style: theme.textTheme.titleMedium,
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
                      ? const CustomLoadingIndicator(size: 20)
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
                      ? const CustomLoadingIndicator(size: 20)
                      : const Text('Kirim Notifikasi Demo'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        AppCard(isInteractive: true,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Atur Kategori',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Pisahkan antar kategori pakai koma (,).',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              Text(
                'Kategori Pemasukan',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _incomeCategoriesController,
                decoration: const InputDecoration(
                  hintText: 'Contoh: Gaji, Bonus, Jualan',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Kategori Pengeluaran',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFC24545),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _expenseCategoriesController,
                decoration: const InputDecoration(
                  hintText: 'Contoh: Belanja, Makan, Tagihan',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        AppCard(isInteractive: true,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Backup & Restore Data',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Ekspor data ke file ZIP atau pulihkan dari backup sebelumnya.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              const BackupRestoreTile(),
            ],
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
        const SizedBox(height: 100),
      ],
    );
  }
}

class _ThemeModeSelector extends StatelessWidget {
  const _ThemeModeSelector();

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final currentMode = themeProvider.themeMode;

    return Row(
      children: [
        _buildModeOption(
          context,
          'Sistem',
          Icons.brightness_auto_rounded,
          ThemeMode.system,
          currentMode == ThemeMode.system,
        ),
        const SizedBox(width: 8),
        _buildModeOption(
          context,
          'Terang',
          Icons.light_mode_rounded,
          ThemeMode.light,
          currentMode == ThemeMode.light,
        ),
        const SizedBox(width: 8),
        _buildModeOption(
          context,
          'Gelap',
          Icons.dark_mode_rounded,
          ThemeMode.dark,
          currentMode == ThemeMode.dark,
        ),
      ],
    );
  }

  Widget _buildModeOption(
    BuildContext context,
    String label,
    IconData icon,
    ThemeMode mode,
    bool isSelected,
  ) {
    final theme = Theme.of(context);
    final themeProvider = context.read<ThemeProvider>();

    return Expanded(
      child: InkWell(
        onTap: () => themeProvider.setThemeMode(mode),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary.withOpacity(0.1)
                : Colors.transparent,
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.dividerColor.withOpacity(0.2),
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? theme.colorScheme.primary : theme.hintColor,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.hintColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FontSelectorRow extends StatelessWidget {
  const _FontSelectorRow();

  String? _getFontFamilyForPreview(String fontId) {
    switch (fontId) {
      case 'feeling_cute':
        return GoogleFonts.fredoka().fontFamily;
      case 'feeling_childlike':
        return GoogleFonts.mali().fontFamily;
      case 'monospace':
        return GoogleFonts.spaceMono().fontFamily;
      case 'blobby':
        return GoogleFonts.sniglet().fontFamily;
      case 'pixel':
        return GoogleFonts.vt323().fontFamily;
      case 'informal':
        return GoogleFonts.caveat().fontFamily;
      case 'formal':
        return GoogleFonts.merriweather().fontFamily;
      default:
        return 'PlusJakartaSans';
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final currentFont = themeProvider.appFontFamily;

    final options = [
      {'id': 'default', 'label': 'Bawaan', 'name': 'Plus Jakarta Sans'},
      {'id': 'feeling_cute', 'label': 'Feeling Cute', 'name': 'Fredoka'},
      {'id': 'feeling_childlike', 'label': 'Childlike', 'name': 'Mali'},
      {'id': 'monospace', 'label': 'Monospace', 'name': 'Space Mono'},
      {'id': 'blobby', 'label': 'Blobby', 'name': 'Sniglet'},
      {'id': 'pixel', 'label': 'Pixel', 'name': 'VT323'},
      {'id': 'informal', 'label': 'Informal', 'name': 'Caveat'},
      {'id': 'formal', 'label': 'Formal', 'name': 'Merriweather'},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.0,
      ),
      itemCount: options.length,
      itemBuilder: (context, index) {
        final opt = options[index];
        return _buildFontOption(
          context,
          opt['label']!,
          opt['name']!,
          opt['id']!,
          currentFont == opt['id'],
        );
      },
    );
  }

  Widget _buildFontOption(
    BuildContext context,
    String label,
    String fontName,
    String fontId,
    bool isSelected,
  ) {
    final theme = Theme.of(context);
    final themeProvider = context.read<ThemeProvider>();

    return InkWell(
      onTap: () => themeProvider.setAppFontFamily(fontId),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withOpacity(0.1)
              : Colors.transparent,
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.dividerColor.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Aa',
              style: TextStyle(
                fontFamily: _getFontFamilyForPreview(fontId),
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: isSelected ? theme.colorScheme.primary : theme.hintColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? theme.colorScheme.primary : theme.hintColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    this.subtitle,
    required this.child,
    this.padding = const EdgeInsets.all(12),
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(isInteractive: true,
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!, style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ThemeSelectorRow extends StatelessWidget {
  const _ThemeSelectorRow();

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final currentTheme = themeProvider.currentStyle;

    return Row(
      children: [
        Expanded(
          child: _ThemePreviewOption(
            title: 'Modern Minimalis',
            isSelected: currentTheme == AppThemeStyle.classic,
            onTap: () => themeProvider.setTheme(AppThemeStyle.classic),
            previewWidget: _buildClassicPreview(context),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ThemePreviewOption(
            title: 'Neo-Brutalisme',
            isSelected: currentTheme == AppThemeStyle.neoBrutalism,
            onTap: () => themeProvider.setTheme(AppThemeStyle.neoBrutalism),
            previewWidget: _buildNeoBrutalismPreview(context),
          ),
        ),
      ],
    );
  }

  Widget _buildClassicPreview(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkScaffold : AppTheme.lightScaffold,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 12,
            width: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFEDD07D),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 30,
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : AppTheme.classicBorder,
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNeoBrutalismPreview(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkScaffold : AppTheme.neoScaffold,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 12,
            width: 40,
            decoration: BoxDecoration(
              color: isDark ? AppTheme.neoPaper : AppTheme.borderColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 30,
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCard : AppTheme.cream,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isDark ? AppTheme.neoPaper : AppTheme.borderColor,
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark ? AppTheme.neoPaper : AppTheme.borderColor,
                  offset: const Offset(2, 2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemePreviewOption extends StatelessWidget {
  const _ThemePreviewOption({
    required this.title,
    required this.isSelected,
    required this.onTap,
    required this.previewWidget,
  });

  final String title;
  final bool isSelected;
  final VoidCallback onTap;
  final Widget previewWidget;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppThemeExtension>();

    return AppCard(isInteractive: true,
      onTap: onTap,
      padding: const EdgeInsets.all(8),
      color: isSelected ? ext?.primaryActionColor : theme.cardTheme.color,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: previewWidget,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primary.withOpacity(0.1)
                  : Colors.transparent,
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.dividerColor,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isSelected ? 'Aktif' : 'Pilih',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.hintColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
