import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';

class BackupService {
  static const String _dbName = 'uangkeluar.db';
  static const String _sqlName = 'uangkeluar.sql';

  static Future<String> _getDbPath() async {
    final dbDir = await getDatabasesPath();
    return p.join(dbDir, _dbName);
  }

  /// Membuat file backup ZIP dari database SQLite.
  /// ZIP berisi:
  ///   - [_dbName]  → binary SQLite (digunakan untuk restore)
  ///   - [_sqlName] → SQL dump teks (bisa dibuka di DB Browser, dsb.)
  ///
  /// Menggunakan in-memory ZIP (Archive + ZipEncoder) agar reliable di Android.
  /// Mengembalikan [File] objek yang mengarah ke file ZIP di direktori temp.
  static Future<File> createBackup({String? password}) async {
    final db = await DatabaseHelper.instance.database;
    final dbPath = db.path;

    // Flush WAL (Write-Ahead Log) ke file database utama agar data utuh saat di-copy
    await db.execute('PRAGMA wal_checkpoint(FULL)');

    final dbFile = File(dbPath);

    if (!await dbFile.exists()) {
      throw Exception('Database tidak ditemukan di: $dbPath');
    }

    // 1. Baca binary database
    final dbBytes = await dbFile.readAsBytes();

    // 2. Generate SQL dump menggunakan instance database yang sudah terbuka
    final sqlContent = await _generateSqlDump(db);
    final sqlBytes = utf8.encode(sqlContent);

    // 3. Buat archive dalam memori
    final archive = Archive();
    archive.addFile(ArchiveFile(_dbName, dbBytes.length, dbBytes));
    archive.addFile(ArchiveFile(_sqlName, sqlBytes.length, sqlBytes));

    // 4. Encode ke ZIP bytes (dengan password jika ada)
    final zipBytes = ZipEncoder(password: password).encode(archive);
    if (zipBytes.isEmpty) {
      throw Exception('Gagal membuat file ZIP backup — encoder mengembalikan data kosong.');
    }

    // 5. Tulis ke temp directory
    final tempDir = await getTemporaryDirectory();
    final ts = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .substring(0, 19);
    final zipPath = p.join(tempDir.path, 'uangku_backup_$ts.zip');

    await File(zipPath).writeAsBytes(zipBytes);

    return File(zipPath);
  }

  /// Mengecek apakah file ZIP backup memerlukan password.
  static Future<bool> isZipEncrypted(File zipFile) async {
    try {
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      // Coba akses konten file pertama untuk men-trigger dekripsi
      if (archive.files.isNotEmpty) {
        final _ = archive.files.first.content;
      }
      return false; // Berhasil membaca tanpa error -> tidak pakai password
    } catch (e) {
      final err = e.toString().toLowerCase();
      // ZipDecoder melempar "Null check operator used on a null value" 
      // atau "password error" jika file terenkripsi tapi password null.
      if (err.contains('null check operator') || err.contains('password')) {
        return true;
      }
      return false; // Error lain (file rusak), anggap tidak terenkripsi biar ditangani oleh proses restore utama
    }
  }

  /// Mengecek apakah password cocok untuk file ZIP yang terenkripsi.
  static Future<bool> verifyZipPassword(File zipFile, String password) async {
    try {
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes, password: password);
      // Akses konten untuk men-trigger dekripsi
      if (archive.files.isNotEmpty) {
        final _ = archive.files.first.content;
      }
      return true; // Berhasil membaca tanpa error -> password benar
    } catch (e) {
      return false; // Gagal membaca -> password salah atau file rusak
    }
  }

  /// Merestore database dari file ZIP backup.
  /// Throws [Exception] jika file ZIP tidak mengandung file database yang valid.
  static Future<void> restoreBackup(File zipFile, {String? password}) async {
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes, password: password);

    // Cari file .db secara fleksibel:
    // - Nama bisa disimpan sebagai 'uangkeluar.db' atau 'path/to/uangkeluar.db'
    // - Abaikan entry direktori (nama diakhiri '/')
    ArchiveFile? dbEntry;
    for (final file in archive.files) {
      // Entry direktori diakhiri '/' — lewati
      if (file.name.endsWith('/')) continue;

      // Ambil basename saja, normalisasi separator Windows & Unix
      final entryBasename = p
          .basename(file.name.replaceAll('\\', '/'))
          .toLowerCase();

      if (entryBasename == _dbName.toLowerCase()) {
        dbEntry = file;
        break;
      }
    }

    if (dbEntry == null) {
      // Tampilkan daftar file yang ADA agar mudah di-debug
      final fileList = archive.files
          .where((f) => !f.name.endsWith('/'))
          .map((f) => '"${f.name}"')
          .join(', ');
      throw Exception(
        'File backup tidak valid.\n'
        'File yang ditemukan dalam ZIP: [$fileList]\n'
        'Pastikan file ZIP adalah backup dari aplikasi UangKu.',
      );
    }

    final dbPath = await _getDbPath();
    await File(dbPath).writeAsBytes(dbEntry.content as List<int>);
  }

  /// Membuat SQL dump dari database SQLite menggunakan koneksi yang sudah ada.
  static Future<String> _generateSqlDump(Database db) async {
    final buffer = StringBuffer();
      buffer.writeln('-- ================================================');
      buffer.writeln('-- UangKu Database SQL Dump');
      buffer.writeln('-- Generated : ${DateTime.now().toIso8601String()}');
      buffer.writeln('-- ================================================');
      buffer.writeln();
      buffer.writeln('PRAGMA foreign_keys = OFF;');
      buffer.writeln('BEGIN TRANSACTION;');
      buffer.writeln();

      final tables = await db.rawQuery(
        "SELECT name, sql FROM sqlite_master "
        "WHERE type='table' AND name NOT LIKE 'sqlite_%' "
        "ORDER BY name",
      );

      for (final table in tables) {
        final name = table['name'] as String;
        final createSql = table['sql'] as String?;
        if (createSql == null) continue;

        buffer.writeln('-- ---------------------------------------------');
        buffer.writeln('-- Table: $name');
        buffer.writeln('-- ---------------------------------------------');
        buffer.writeln('DROP TABLE IF EXISTS "$name";');
        buffer.writeln('$createSql;');
        buffer.writeln();

        final rows = await db.query(name);
        if (rows.isNotEmpty) {
          buffer.writeln('-- Data ($name): ${rows.length} baris');
          for (final row in rows) {
            final cols = row.keys.map((k) => '"$k"').join(', ');
            final vals = row.values.map((v) {
              if (v == null) return 'NULL';
              if (v is int || v is double) return v.toString();
              // Escape single-quotes dalam string
              return "'${v.toString().replaceAll("'", "''")}'";
            }).join(', ');
            buffer.writeln('INSERT INTO "$name" ($cols) VALUES ($vals);');
          }
          buffer.writeln();
        }
      }

      buffer.writeln('COMMIT;');
      buffer.writeln('PRAGMA foreign_keys = ON;');

      return buffer.toString();
  }
}
