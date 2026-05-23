import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';

import '../services/auto_backup_service.dart';

class AutoBackupSettingsSheet extends StatefulWidget {
  const AutoBackupSettingsSheet({super.key});

  @override
  State<AutoBackupSettingsSheet> createState() => _AutoBackupSettingsSheetState();
}

class _AutoBackupSettingsSheetState extends State<AutoBackupSettingsSheet> {
  bool _isEnabled = false;
  String _folderPath = '';
  
  bool _usePassword = false;
  final _pwdCtrl = TextEditingController();
  
  // Interval: 1 = Harian, 3 = 3 Hari, 7 = Mingguan, 30 = Bulanan
  int _intervalDays = 1;
  TimeOfDay? _dailyTime;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _pwdCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isEnabled = prefs.getBool('auto_backup_enabled') ?? false;
      _folderPath = prefs.getString('auto_backup_folder') ?? '';
      _usePassword = prefs.getBool('auto_backup_use_password') ?? false;
      _pwdCtrl.text = prefs.getString('auto_backup_password') ?? '';
      _intervalDays = prefs.getInt('auto_backup_interval') ?? 1;
      
      final savedHour = prefs.getInt('auto_backup_hour');
      final savedMinute = prefs.getInt('auto_backup_minute');
      if (savedHour != null && savedMinute != null) {
        _dailyTime = TimeOfDay(hour: savedHour, minute: savedMinute);
      }
      
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    if (_isEnabled && _folderPath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih folder penyimpanan terlebih dahulu!')),
      );
      return;
    }
    
    if (_isEnabled && _usePassword && _pwdCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password tidak boleh kosong!')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_backup_enabled', _isEnabled);
    await prefs.setString('auto_backup_folder', _folderPath);
    await prefs.setBool('auto_backup_use_password', _usePassword);
    await prefs.setString('auto_backup_password', _pwdCtrl.text);
    await prefs.setInt('auto_backup_interval', _intervalDays);
    
    if (_dailyTime != null) {
      await prefs.setInt('auto_backup_hour', _dailyTime!.hour);
      await prefs.setInt('auto_backup_minute', _dailyTime!.minute);
    } else {
      await prefs.remove('auto_backup_hour');
      await prefs.remove('auto_backup_minute');
    }

    if (_isEnabled) {
      Duration frequency = Duration(days: _intervalDays);
      Duration? initialDelay;

      if (_intervalDays == 1 && _dailyTime != null) {
        final now = DateTime.now();
        var scheduledDate = DateTime(
          now.year, now.month, now.day, _dailyTime!.hour, _dailyTime!.minute,
        );
        if (scheduledDate.isBefore(now)) {
          scheduledDate = scheduledDate.add(const Duration(days: 1));
        }
        initialDelay = scheduledDate.difference(now);
      }

      await AutoBackupService.scheduleBackup(frequency, initialDelay: initialDelay);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Auto Backup berhasil diaktifkan')),
        );
      }
    } else {
      await AutoBackupService.cancelBackup();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Auto Backup dimatikan')),
        );
      }
    }

    if (mounted) Navigator.pop(context);
  }

  Future<void> _pickFolder() async {
    final selectedDir = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Pilih folder untuk Auto Backup',
    );
    if (selectedDir != null) {
      setState(() => _folderPath = selectedDir);
    }
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _dailyTime ?? TimeOfDay.now(),
    );
    if (time != null) {
      setState(() => _dailyTime = time);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    if (_isLoading) {
      return const SizedBox(
        height: 200, 
        child: Center(child: CircularProgressIndicator())
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 24, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.autorenew_rounded, color: cs.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Auto Backup',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Switch(
                  value: _isEnabled,
                  onChanged: (val) => setState(() => _isEnabled = val),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Jalankan backup secara otomatis di latar belakang untuk mengamankan data Anda secara berkala.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const Divider(height: 32),

            if (_isEnabled) ...[
              // 1. Folder Tujuan
              Text('Folder Penyimpanan', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_folderPath.isEmpty ? 'Belum ada folder yang dipilih' : _folderPath, maxLines: 2),
                subtitle: const Text('Ketuk untuk mengubah folder'),
                leading: Icon(Icons.folder_rounded, color: cs.secondary),
                onTap: _pickFolder,
              ),
              const SizedBox(height: 16),

              // 2. Jadwal
              Text('Jadwal', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: _intervalDays,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('Setiap Hari')),
                  DropdownMenuItem(value: 3, child: Text('Setiap 3 Hari')),
                  DropdownMenuItem(value: 7, child: Text('Setiap 1 Minggu')),
                  DropdownMenuItem(value: 30, child: Text('Setiap 1 Bulan')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _intervalDays = val);
                },
              ),
              
              if (_intervalDays == 1) ...[
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_dailyTime == null ? 'Pilih Jam Backup' : 'Jam ${_dailyTime!.format(context)}'),
                  leading: Icon(Icons.access_time_rounded, color: cs.tertiary),
                  onTap: _pickTime,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: cs.outlineVariant),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
              
              const SizedBox(height: 16),

              // 3. Password
              Text('Keamanan', style: Theme.of(context).textTheme.titleMedium),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Gunakan Password (Enkripsi)'),
                value: _usePassword,
                onChanged: (val) => setState(() => _usePassword = val),
              ),
              if (_usePassword)
                TextField(
                  controller: _pwdCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                ),
              
              const SizedBox(height: 24),
            ],

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saveSettings,
                child: const Text('Simpan Pengaturan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
