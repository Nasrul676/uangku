**AI Agent Execution Plan**

Flutter App — Backup & Restore Feature

Project: UangKu | Database: SQLite | Platform: Android & iOS

# **1\. Project Overview**

Tambahkan fitur Backup & Restore pada aplikasi Flutter UangKu yang menggunakan SQLite sebagai database lokal. Fitur ini memungkinkan user untuk mengekspor data ke file ZIP dan mengimpornya kembali tanpa memerlukan backend atau server.

## **1.1 Goals**

* Export seluruh data SQLite ke file .zip  
* Import file .zip dan restore database  
* Tidak memodifikasi struktur tabel atau logika bisnis yang ada  
* Kompatibel dengan Android dan iOS

## **1.2 Constraints**

* Tidak ada backend/server — semua operasi lokal  
* Database: SQLite via sqflite  
* Flutter stable channel (\>= 3.41.x)  
* Tidak mengubah kode fitur yang sudah berjalan

# **2\. Dependencies**

Tambahkan package berikut ke pubspec.yaml:

| Package | Version | Fungsi |
| :---- | :---- | :---- |
| sqflite | ^2.3.0 | SQLite database (sudah ada) |
| path\_provider | ^2.1.2 | Akses direktori sistem |
| archive | ^3.4.9 | Zip / unzip file |
| file\_picker | ^8.0.0 | Pilih file .zip saat restore |
| share\_plus | ^9.0.0 | Share/simpan file backup |
| permission\_handler | ^11.3.0 | Permission storage (Android) |

# **3\. File Structure**

Buat file-file berikut (jangan modifikasi file yang sudah ada):

lib/

  services/

    backup\_service.dart        \<-- T01: Core backup/restore logic

  widgets/

    backup\_restore\_tile.dart   \<-- T02: UI ListTile component

  pages/

    settings\_page.dart         \<-- T03: Tambahkan tile ke halaman ini

Modifikasi file yang sudah ada:

  database/

    database\_helper.dart       \<-- T00: Tambahkan fungsi closeDatabase()

# **4\. Task Breakdown**

## **T00 — Modifikasi DatabaseHelper**

File: lib/database/database\_helper.dart (atau nama file DB helper yang ada)

### **Instruksi untuk AI Agent:**

1. Buka file database helper yang ada  
2. Cari variabel static Database? (biasanya \_database)  
3. Tambahkan fungsi closeDatabase() di bawah getter database  
4. Jangan ubah fungsi lain yang sudah ada

### **Kode yang ditambahkan:**

static Future\<void\> closeDatabase() async {

  if (\_database \!= null && \_database\!.isOpen) {

    await \_database\!.close();

    \_database \= null;

  }

}

### **Validasi:**

* Fungsi closeDatabase() tersedia dan bisa dipanggil dari luar class  
* Tidak ada fungsi lain yang berubah

## **T01 — Buat BackupService**

File baru: lib/services/backup\_service.dart

### **Instruksi untuk AI Agent:**

5. Buat file baru lib/services/backup\_service.dart  
6. Ganti nilai \_dbName dengan nama file .db yang digunakan project ini  
7. Untuk menemukan nama .db: cari openDatabase() di database helper, lihat nama file yang dipass  
8. Implementasikan dua fungsi: createBackup() dan restoreBackup()

### **Cara menemukan nama database:**

// Cari di database\_helper.dart, biasanya seperti ini:

await openDatabase(p.join(dbPath, 'nama\_file.db'))

// Gunakan nama file tersebut untuk \_dbName

### **Isi file backup\_service.dart:**

import 'dart:io';

import 'package:archive/archive\_io.dart';

import 'package:path/path.dart' as p;

import 'package:path\_provider/path\_provider.dart';

import 'package:sqflite/sqflite.dart';

class BackupService {

  static const String \_dbName \= 'GANTI\_DENGAN\_NAMA\_DB.db';

  static Future\<String\> \_getDbPath() async {

    final dbDir \= await getDatabasesPath();

    return p.join(dbDir, \_dbName);

  }

  static Future\<File\> createBackup() async {

    final dbPath \= await \_getDbPath();

    final dbFile \= File(dbPath);

    if (\!await dbFile.exists()) throw Exception('Database tidak ditemukan');

    final tempDir \= await getTemporaryDirectory();

    final ts \= DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19);

    final zipPath \= p.join(tempDir.path, 'uangku\_backup\_$ts.zip');

    final encoder \= ZipFileEncoder();

    encoder.create(zipPath);

    encoder.addFile(dbFile, \_dbName);

    encoder.close();

    return File(zipPath);

  }

  static Future\<void\> restoreBackup(File zipFile) async {

    final bytes \= await zipFile.readAsBytes();

    final archive \= ZipDecoder().decodeBytes(bytes);

    final dbEntry \= archive.files.firstWhere(

      (f) \=\> f.name \== \_dbName,

      orElse: () \=\> throw Exception('File backup tidak valid'),

    );

    final dbPath \= await \_getDbPath();

    await File(dbPath).writeAsBytes(dbEntry.content as List\<int\>);

  }

}

### **Validasi:**

* createBackup() mengembalikan File .zip yang valid  
* restoreBackup() throw Exception jika file .db tidak ditemukan dalam zip  
* Tidak ada import yang hilang

## **T02 — Buat BackupRestoreTile Widget**

File baru: lib/widgets/backup\_restore\_tile.dart

### **Instruksi untuk AI Agent:**

9. Buat StatelessWidget bernama BackupRestoreTile  
10. Widget berisi dua ListTile: satu untuk Backup, satu untuk Restore  
11. Import DatabaseHelper dari path yang sesuai dengan project ini  
12. Gunakan showDialog untuk konfirmasi sebelum restore  
13. Gunakan ScaffoldMessenger untuk snackbar feedback

### **Dependensi yang perlu disesuaikan:**

// Sesuaikan import path dengan struktur project:

import '../database/database\_helper.dart'; // sesuaikan path

import '../services/backup\_service.dart';

### **Kode widget:**

import 'dart:io';

import 'package:flutter/material.dart';

import 'package:file\_picker/file\_picker.dart';

import 'package:share\_plus/share\_plus.dart';

import '../database/database\_helper.dart';

import '../services/backup\_service.dart';

class BackupRestoreTile extends StatelessWidget {

  const BackupRestoreTile({super.key});

  Future\<void\> \_handleBackup(BuildContext context) async {

    try {

      await DatabaseHelper.closeDatabase();

      final zipFile \= await BackupService.createBackup();

      await Share.shareXFiles(\[XFile(zipFile.path)\], subject: 'Backup UangKu');

    } catch (e) {

      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(content: Text('Backup gagal: $e')));

    }

  }

  Future\<void\> \_handleRestore(BuildContext context) async {

    final confirm \= await showDialog\<bool\>(

      context: context,

      builder: (\_) \=\> AlertDialog(

        title: const Text('Restore Backup?'),

        content: const Text('Data saat ini akan diganti. Lanjutkan?'),

        actions: \[

          TextButton(onPressed: () \=\> Navigator.pop(context, false), child: const Text('Batal')),

          TextButton(onPressed: () \=\> Navigator.pop(context, true), child: const Text('Restore')),

        \],

      ),

    );

    if (confirm \!= true) return;

    try {

      final result \= await FilePicker.platform.pickFiles(

        type: FileType.custom, allowedExtensions: \['zip'\]);

      if (result?.files.single.path \== null) return;

      await DatabaseHelper.closeDatabase();

      await BackupService.restoreBackup(File(result\!.files.single.path\!));

      ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(content: Text('Restore berhasil\! Silakan restart aplikasi.')));

    } catch (e) {

      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(content: Text('Restore gagal: $e')));

    }

  }

  @override

  Widget build(BuildContext context) {

    return Column(children: \[

      ListTile(

        leading: const Icon(Icons.upload),

        title: const Text('Backup Data'),

        subtitle: const Text('Simpan data ke file ZIP'),

        onTap: () \=\> \_handleBackup(context),

      ),

      ListTile(

        leading: const Icon(Icons.download),

        title: const Text('Restore Data'),

        subtitle: const Text('Pulihkan data dari file ZIP'),

        onTap: () \=\> \_handleRestore(context),

      ),

    \]);

  }

}

## **T03 — Integrasi ke Settings Page**

File: halaman settings yang sudah ada (tanyakan kepada user jika belum tahu nama filenya)

### **Instruksi untuk AI Agent:**

14. Temukan halaman Settings di project (cari file dengan kata 'setting' atau 'pengaturan')  
15. Tambahkan import BackupRestoreTile  
16. Tambahkan widget BackupRestoreTile() di dalam body halaman, di bawah item settings yang sudah ada  
17. Jangan hapus atau ubah widget yang sudah ada

### **Contoh penambahan:**

import '../widgets/backup\_restore\_tile.dart';

// Di dalam body / Column / ListView:

const Divider(),

const Padding(

  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),

  child: Text('Data', style: TextStyle(fontWeight: FontWeight.bold)),

),

const BackupRestoreTile(),

# **5\. Platform Configuration**

## **5.1 Android — android/app/src/main/AndroidManifest.xml**

Tambahkan permission berikut di dalam tag \<manifest\>:

\<uses-permission android:name="android.permission.READ\_EXTERNAL\_STORAGE" /\>

\<uses-permission android:name="android.permission.WRITE\_EXTERNAL\_STORAGE" /\>

\<uses-permission android:name="android.permission.READ\_MEDIA\_IMAGES" /\>

Tambahkan di dalam tag \<application\> untuk file\_picker:

\<provider

  android:name="com.mr.flutter.plugin.filepicker.FilePickerProvider"

  android:authorities="${applicationId}.filepicker"

  android:exported="false"

  android:grantUriPermissions="true"\>

  \<meta-data

    android:name="android.support.FILE\_PROVIDER\_PATHS"

    android:resource="@xml/file\_picker\_provider\_paths" /\>

\</provider\>

## **5.2 iOS — ios/Runner/Info.plist**

Tambahkan key berikut:

\<key\>NSPhotoLibraryUsageDescription\</key\>

\<string\>Diperlukan untuk menyimpan file backup\</string\>

\<key\>UIFileSharingEnabled\</key\>

\<true/\>

\<key\>LSSupportsOpeningDocumentsInPlace\</key\>

\<true/\>

# **6\. Execution Order**

| Step | Task | File | Catatan |
| :---- | :---- | :---- | :---- |
| 1 | Install packages | pubspec.yaml | flutter pub get setelahnya |
| 2 | T00 \- closeDatabase() | database\_helper.dart | Modifikasi file existing |
| 3 | T01 \- BackupService | services/backup\_service.dart | File baru, ganti \_dbName |
| 4 | T02 \- BackupRestoreTile | widgets/backup\_restore\_tile.dart | File baru |
| 5 | T03 \- Settings integration | settings\_page.dart | Tambahkan widget saja |
| 6 | Platform config | AndroidManifest \+ Info.plist | Permission & provider |
| 7 | Test | Emulator / device | Coba backup lalu restore |

# **7\. Validation Checklist**

* \[ \] flutter pub get berhasil tanpa error  
* \[ \] closeDatabase() dapat dipanggil dari BackupRestoreTile  
* \[ \] Backup menghasilkan file .zip yang bisa dibuka  
* \[ \] Isi .zip mengandung file .db dengan nama yang benar  
* \[ \] Restore mengganti file .db dengan isi zip  
* \[ \] Setelah restore, data tampil setelah app di-restart  
* \[ \] Error ditampilkan via SnackBar, bukan crash  
* \[ \] Tidak ada breaking change pada fitur yang sudah ada

# **8\. Notes for AI Agent**

**Hal-hal yang perlu disesuaikan dengan kondisi project:**

18. Nama file .db — cari di openDatabase() dalam database\_helper.dart  
19. Path import DatabaseHelper — sesuaikan dengan struktur folder project  
20. Nama halaman settings — cari file yang mengandung kata 'setting' atau 'pengaturan'  
21. Jika DatabaseHelper bukan static — ubah menjadi instance call atau sesuaikan

**Yang TIDAK boleh diubah:**

* Struktur tabel database  
* Logika bisnis yang sudah ada  
* Fungsi-fungsi lain di database\_helper.dart  
* Routing atau navigation yang sudah ada

**Jika ada ambiguitas, tanyakan kepada user sebelum melanjutkan.**