import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as p;

import '../services/database_helper.dart';
import '../services/backup_service.dart';
import '../services/auto_backup_service.dart';
import 'auto_backup_settings_sheet.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';
import '../models/app_notification.dart';

// ─── Progress Model ──────────────────────────────────────────────────────────

class _ProgressData {
  final double progress; // 0.0 – 1.0
  final String status;
  const _ProgressData(this.progress, this.status);
}

// ─── Password Dialog ─────────────────────────────────────────────────────────

class _PasswordDialog extends StatefulWidget {
  final bool isRestore;
  final bool forcePassword; // Jika true, paksa user isi password (hide switch)
  const _PasswordDialog({required this.isRestore, this.forcePassword = false});

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  late bool _usePassword = widget.forcePassword;
  final _pwdCtrl = TextEditingController();
  bool _obscure = true;
  String? _errorText;

  @override
  void dispose() {
    _pwdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isRestore ? 'Masukkan Password' : 'Opsi Backup'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!widget.forcePassword)
            SwitchListTile(
              title: const Text('Gunakan password'),
              value: _usePassword,
              onChanged: (val) => setState(() {
                _usePassword = val;
                _errorText = null;
              }),
              contentPadding: EdgeInsets.zero,
            ),
          if (_usePassword)
            TextField(
              controller: _pwdCtrl,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Password',
                errorText: _errorText,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () {
            if (_usePassword && _pwdCtrl.text.isEmpty) {
              setState(() => _errorText = 'Password tidak boleh kosong');
              return;
            }
            Navigator.pop(context, _usePassword ? _pwdCtrl.text : '');
          },
          child: const Text('Lanjut'),
        ),
      ],
    );
  }
}

// ─── Progress Dialog ─────────────────────────────────────────────────────────

class _BackupProgressDialog extends StatefulWidget {
  final String title;
  final bool isRestore;
  final ValueNotifier<_ProgressData> notifier;

  const _BackupProgressDialog({
    required this.title,
    required this.isRestore,
    required this.notifier,
  });

  @override
  State<_BackupProgressDialog> createState() => _BackupProgressDialogState();
}

class _BackupProgressDialogState extends State<_BackupProgressDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulse = Tween<double>(
      begin: 0.88,
      end: 1.12,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return PopScope(
      canPop: false, // cegah back button menutup dialog
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
          child: ValueListenableBuilder<_ProgressData>(
            valueListenable: widget.notifier,
            builder: (context, data, _) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Pulsing Icon ──
                  ScaleTransition(
                    scale: _pulse,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: cs.primary.withValues(alpha: 0.25),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        widget.isRestore
                            ? Icons.settings_backup_restore_rounded
                            : Icons.backup_rounded,
                        size: 40,
                        color: cs.primary,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Title ──
                  Text(
                    widget.title,
                    style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 24),

                  // ── Animated Progress Bar ──
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: data.progress),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOut,
                    builder: (ctx, animValue, _) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Stack(
                            children: [
                              // Background track
                              Container(
                                height: 12,
                                decoration: BoxDecoration(
                                  color: cs.primaryContainer.withValues(
                                    alpha: 0.5,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              // Fill
                              FractionallySizedBox(
                                widthFactor: animValue.clamp(0.0, 1.0),
                                child: Container(
                                  height: 12,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        cs.primary.withValues(alpha: 0.7),
                                        cs.primary,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                '${(animValue * 100).toInt()}%',
                                style: tt.labelMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: cs.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 4),

                  // ── Animated Status Text ──
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.3),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: Text(
                      data.status,
                      key: ValueKey(data.status),
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 4),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─── Main Widget ─────────────────────────────────────────────────────────────

/// Widget yang menampilkan dua tile untuk fitur Backup dan Restore data.
/// Digunakan di dalam halaman Settings.
class BackupRestoreTile extends StatefulWidget {
  const BackupRestoreTile({super.key});

  @override
  State<BackupRestoreTile> createState() => _BackupRestoreTileState();
}

class _BackupRestoreTileState extends State<BackupRestoreTile> {
  bool _isBackingUp = false;
  bool _isRestoring = false;

  // ─── Backup ─────────────────────────────────────────────────────────────────

  Future<void> _handleBackup() async {
    // Tanyakan password dulu
    final passwordResult = await showDialog<String>(
      context: context,
      builder: (_) => const _PasswordDialog(isRestore: false),
    );
    if (passwordResult == null) return; // User membatalkan
    final password = passwordResult.isEmpty ? null : passwordResult;

    setState(() => _isBackingUp = true);

    final progressNotifier = ValueNotifier<_ProgressData>(
      const _ProgressData(0.0, 'Mempersiapkan...'),
    );

    File? zipFile;
    Object? caughtError;

    // Tampilkan dialog loading
    if (!mounted) {
      setState(() => _isBackingUp = false);
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _BackupProgressDialog(
        title: 'Membuat Backup',
        isRestore: false,
        notifier: progressNotifier,
      ),
    );

    // Jalankan operasi + animasi + minimum 3 detik secara paralel
    await Future.wait([
      // [A] Animasi progress (choreographed stages)
      _animateStages(progressNotifier, const [
        (0.00, 0.05, 'Mempersiapkan...'),
        (0.40, 0.30, 'Menutup database...'),
        (0.80, 0.55, 'Membaca data...'),
        (1.20, 0.72, 'Membuat SQL dump...'),
        (1.80, 0.88, 'Mengkompresi file...'),
        (2.40, 0.96, 'Menyimpan backup...'),
        (2.80, 1.00, 'Backup selesai! ✓'),
      ]),

      Future(() async {
        try {
          await DatabaseHelper.instance.checkpointDatabase();
          await DatabaseHelper.instance.closeDatabase();
          zipFile = await BackupService.createBackup(password: password);
        } catch (e) {
          caughtError = e;
        }
      }),

      // [C] Minimum tampil 3 detik
      Future.delayed(const Duration(seconds: 3)),
    ]);

    if (!mounted) {
      progressNotifier.dispose();
      setState(() => _isBackingUp = false);
      return;
    }

    Navigator.of(context, rootNavigator: true).pop(); // tutup dialog
    progressNotifier.dispose();
    setState(() => _isBackingUp = false);

    if (caughtError != null) {
      if (mounted) {
        await Provider.of<TransactionProvider>(
          context,
          listen: false,
        ).insertNotification(
          AppNotification(
            title: 'Backup Manual Gagal',
            subtitle: 'Terjadi kesalahan saat membuat backup.',
            type: 'BACKUP_FAILED',
            createdAt: DateTime.now(),
          ),
        );
      }
      _showSnackBar('Backup gagal: $caughtError');
      return;
    }

    if (zipFile != null) {
      if (mounted) {
        await Provider.of<TransactionProvider>(
          context,
          listen: false,
        ).insertNotification(
          AppNotification(
            title: 'Backup Manual Berhasil',
            subtitle: 'File backup telah berhasil dibuat.',
            type: 'BACKUP_SUCCESS',
            createdAt: DateTime.now(),
          ),
        );
      }
      await AutoBackupService.showNotification(
        'Backup Berhasil',
        'File backup telah berhasil dibuat secara manual.',
      );
      await _showBackupOptionsSheet(zipFile!);
    }
  }

  Future<void> _showBackupOptionsSheet(File zipFile) async {
    final fileName = p.basename(zipFile.path);

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: Theme.of(sheetCtx).colorScheme.primary,
                      size: 30,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Backup Siap!',
                            style: Theme.of(sheetCtx).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            fileName,
                            style: Theme.of(
                              sheetCtx,
                            ).textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                Text(
                  'Pilih cara menyimpan:',
                  style: Theme.of(
                    sheetCtx,
                  ).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),

                // Opsi: Simpan ke Folder
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        sheetCtx,
                      ).colorScheme.primaryContainer.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.folder_open_rounded,
                      color: Theme.of(sheetCtx).colorScheme.primary,
                    ),
                  ),
                  title: const Text('Simpan ke Folder'),
                  subtitle: const Text(
                    'Pilih lokasi penyimpanan di perangkat Anda',
                  ),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _saveToFolder(zipFile);
                  },
                ),

                // Opsi: Bagikan File
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        sheetCtx,
                      ).colorScheme.secondaryContainer.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.share_rounded,
                      color: Theme.of(sheetCtx).colorScheme.secondary,
                    ),
                  ),
                  title: const Text('Bagikan File'),
                  subtitle: const Text(
                    'Kirim via WhatsApp, Google Drive, dll.',
                  ),
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    await Share.shareXFiles([
                      XFile(zipFile.path),
                    ], subject: 'Backup UangKu');
                  },
                ),

                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveToFolder(File zipFile) async {
    try {
      final selectedDir = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Pilih folder untuk menyimpan backup',
      );

      if (selectedDir == null) return;

      final fileName = p.basename(zipFile.path);
      final destPath = p.join(selectedDir, fileName);
      await zipFile.copy(destPath);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Backup berhasil disimpan!',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                destPath,
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Gagal menyimpan ke folder: $e');
    }
  }

  // ─── Restore ────────────────────────────────────────────────────────────────

  Future<void> _handleRestore() async {
    // Konfirmasi dulu
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Restore Backup?'),
        content: const Text(
          'Data saat ini akan diganti dengan data dari file backup. '
          'Aksi ini tidak bisa dibatalkan. Lanjutkan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    // Pilih file backup
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      dialogTitle: 'Pilih file backup (.zip)',
    );

    if (result?.files.single.path == null) return;
    if (!mounted) return;

    final selectedFile = File(result!.files.single.path!);
    String? password;

    // Cek otomatis apakah file ZIP dilindungi password
    final isEncrypted = await BackupService.isZipEncrypted(selectedFile);
    if (!mounted) return;

    if (isEncrypted) {
      bool isPasswordValid = false;
      while (!isPasswordValid) {
        if (!mounted) return;

        // Tanyakan password jika terenkripsi
        final passwordResult = await showDialog<String>(
          context: context,
          builder: (_) =>
              const _PasswordDialog(isRestore: true, forcePassword: true),
        );

        if (passwordResult == null) return; // User membatalkan
        password = passwordResult.isEmpty ? null : passwordResult;

        if (password == null) continue; // Minta ulang jika kosong

        // Cek apakah password benar
        isPasswordValid = await BackupService.verifyZipPassword(
          selectedFile,
          password,
        );

        if (!mounted) return;

        if (!isPasswordValid) {
          // Password salah -> muncul popup
          await showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Password Salah'),
              content: const Text(
                'Password yang Anda masukkan tidak cocok dengan file backup ini. Silakan coba lagi.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    }

    if (!mounted) return;

    setState(() => _isRestoring = true);

    final progressNotifier = ValueNotifier<_ProgressData>(
      const _ProgressData(0.0, 'Mempersiapkan...'),
    );

    Object? caughtError;

    // Tampilkan dialog loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _BackupProgressDialog(
        title: 'Memulihkan Data',
        isRestore: true,
        notifier: progressNotifier,
      ),
    );

    await Future.wait([
      // [A] Animasi progress
      _animateStages(progressNotifier, const [
        (0.00, 0.05, 'Mempersiapkan...'),
        (0.40, 0.25, 'Memvalidasi file backup...'),
        (0.90, 0.50, 'Membaca isi backup...'),
        (1.40, 0.68, 'Menutup database...'),
        (1.90, 0.85, 'Memulihkan database...'),
        (2.40, 0.96, 'Finalisasi...'),
        (2.80, 1.00, 'Restore selesai! ✓'),
      ]),

      Future(() async {
        try {
          await DatabaseHelper.instance.closeDatabase();
          await BackupService.restoreBackup(selectedFile, password: password);
        } catch (e) {
          caughtError = e;
        }
      }),

      // [C] Minimum tampil 3 detik
      Future.delayed(const Duration(seconds: 3)),
    ]);

    if (!mounted) {
      progressNotifier.dispose();
      setState(() => _isRestoring = false);
      return;
    }

    Navigator.of(context, rootNavigator: true).pop(); // tutup dialog
    progressNotifier.dispose();
    setState(() => _isRestoring = false);

    if (caughtError != null) {
      if (mounted) {
        await Provider.of<TransactionProvider>(
          context,
          listen: false,
        ).insertNotification(
          AppNotification(
            title: 'Restore Gagal',
            subtitle: 'Terjadi kesalahan saat memulihkan data.',
            type: 'RESTORE_FAILED',
            createdAt: DateTime.now(),
          ),
        );
      }
      _showSnackBar('Restore gagal: $caughtError');
      return;
    }

    if (mounted) {
      await Provider.of<TransactionProvider>(
        context,
        listen: false,
      ).insertNotification(
        AppNotification(
          title: 'Restore Berhasil',
          subtitle: 'Data berhasil dipulihkan dari file backup.',
          type: 'RESTORE_SUCCESS',
          createdAt: DateTime.now(),
        ),
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Restore berhasil! Silakan restart aplikasi untuk memuat data terbaru.',
        ),
        duration: Duration(seconds: 5),
      ),
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  /// Animasi progress secara berurutan berdasarkan [stages].
  /// Setiap stage: (delayDetik, progress, statusText)
  static Future<void> _animateStages(
    ValueNotifier<_ProgressData> notifier,
    List<(double, double, String)> stages,
  ) async {
    for (final (delaySec, progress, status) in stages) {
      await Future.delayed(Duration(milliseconds: (delaySec * 1000).round()));
      notifier.value = _ProgressData(progress, status);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: _isBackingUp
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.upload_rounded),
          title: const Text('Backup Data'),
          subtitle: const Text('Simpan data ke file ZIP'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: _isBackingUp ? null : _handleBackup,
        ),
        ListTile(
          leading: _isRestoring
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download_rounded),
          title: const Text('Restore Data'),
          subtitle: const Text('Pulihkan data dari file ZIP'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: _isRestoring ? null : _handleRestore,
        ),
        ListTile(
          leading: const Icon(Icons.autorenew_rounded),
          title: const Text('Auto Backup'),
          subtitle: const Text('Jadwalkan pencadangan otomatis'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (ctx) => const AutoBackupSettingsSheet(),
            );
          },
        ),
      ],
    );
  }
}
