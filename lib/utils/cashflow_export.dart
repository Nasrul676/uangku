import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/book_period.dart';
import '../models/finance_transaction.dart';
import 'cashflow_recap.dart';
import 'error_message.dart';

/// Membungkus satu sel CSV sesuai RFC 4180.
///
/// Kutip ganda di dalam nilai digandakan, dan sel dikutip kalau mengandung
/// koma, kutip, atau baris baru. Tanpa ini, judul transaksi yang mengandung
/// koma akan menggeser seluruh kolom di baris itu.
String csvCell(Object? value) {
  final text = value?.toString() ?? '';
  if (!text.contains(RegExp(r'[",\n\r]'))) return text;
  return '"${text.replaceAll('"', '""')}"';
}

String csvRow(List<Object?> cells) => cells.map(csvCell).join(',');

/// Nominal untuk CSV: tanpa pemisah ribuan supaya tetap terbaca sebagai angka
/// oleh spreadsheet, dan tanpa `.0` yang menempel dari `double.toString()`.
String csvAmount(double value) {
  if (value == value.truncateToDouble()) return value.toInt().toString();
  return value.toString();
}

/// Menyusun CSV berisi seluruh transaksi satu buku, diawali blok ringkasan.
String buildCashflowCsv({
  required BookPeriod book,
  required List<FinanceTransaction> transactions,
  Map<int, String> moneyLocationNames = const {},
}) {
  final recap = buildCashflowRecap([book], transactions);
  final summary = recap.books.first;
  final buffer = StringBuffer();

  buffer.writeln(csvRow(['Laporan Arus Kas']));
  buffer.writeln(csvRow(['Buku', book.label]));
  buffer.writeln(csvRow(['Mulai', book.startDate]));
  buffer.writeln(csvRow(['Selesai', book.endDate ?? 'Sekarang']));
  buffer.writeln(csvRow(['Status', book.isOpen ? 'Aktif' : 'Selesai']));
  buffer.writeln(csvRow(['Total Pemasukan', csvAmount(summary.totalIncome)]));
  buffer.writeln(
    csvRow(['Total Pengeluaran', csvAmount(summary.totalExpense)]),
  );
  buffer.writeln(csvRow(['Saldo Bersih', csvAmount(summary.net)]));
  buffer.writeln();

  buffer.writeln(
    csvRow([
      'Tanggal',
      'Jam',
      'Tipe',
      'Kategori',
      'Judul',
      'Lokasi',
      'Nominal',
    ]),
  );

  final sorted = transactions.toList()
    ..sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      if (byDate != 0) return byDate;
      return (a.time ?? '').compareTo(b.time ?? '');
    });

  for (final tx in sorted) {
    buffer.writeln(
      csvRow([
        tx.date,
        tx.time ?? '',
        tx.type == 'INCOME' ? 'Pemasukan' : 'Pengeluaran',
        tx.category,
        tx.title,
        moneyLocationNames[tx.moneyLocationId] ?? '',
        csvAmount(tx.amount),
      ]),
    );
  }

  return buffer.toString();
}

/// Nama berkas yang aman untuk sistem berkas mana pun.
String cashflowFileName(BookPeriod book, {String extension = 'csv'}) {
  final slug = book.label
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  final safe = slug.isEmpty ? 'buku' : slug;
  return 'laporan-$safe.$extension';
}

/// Menulis CSV ke berkas sementara lalu membuka lembar berbagi sistem.
Future<void> shareCashflowCsv({
  required BuildContext context,
  required BookPeriod book,
  required List<FinanceTransaction> transactions,
  Map<int, String> moneyLocationNames = const {},
}) async {
  final messenger = ScaffoldMessenger.of(context);

  if (transactions.isEmpty) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Belum ada transaksi untuk diekspor.')),
    );
    return;
  }

  try {
    final csv = buildCashflowCsv(
      book: book,
      transactions: transactions,
      moneyLocationNames: moneyLocationNames,
    );
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/${cashflowFileName(book)}');
    await file.writeAsString(csv);

    final periodLabel = DateFormat(
      'MMMM yyyy',
      'id',
    ).format(DateTime.tryParse(book.startDate) ?? DateTime.now());

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      subject: 'Laporan arus kas ${book.label}',
      text: 'Laporan arus kas $periodLabel dari uangku.',
    );
  } catch (e) {
    if (!messenger.mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text('Gagal mengekspor: ${friendlyError(e)}')),
    );
  }
}

/// Angka untuk laporan cetak — dengan pemisah ribuan, tanpa simbol mata uang,
/// karena kolomnya sudah berjudul rupiah.
String _printedAmount(double value) =>
    NumberFormat.decimalPattern('id_ID').format(value.abs());

/// Menyusun PDF laporan arus kas.
///
/// Sengaja memakai paket `pdf` saja, bukan `printing` — yang terakhir membawa
/// channel native dan dialog cetak sistem, padahal yang dibutuhkan di sini
/// hanya berkas untuk dibagikan.
Future<Uint8List> buildCashflowPdf({
  required BookPeriod book,
  required List<FinanceTransaction> transactions,
}) async {
  final recap = buildCashflowRecap([book], transactions).books.first;
  final categories = buildCategoryBreakdown(transactions, topN: 100);

  final incomeByCategory = <String, double>{};
  for (final tx in transactions) {
    if (tx.type != 'INCOME') continue;
    incomeByCategory[tx.category] =
        (incomeByCategory[tx.category] ?? 0) + tx.amount;
  }
  final sortedIncome = incomeByCategory.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  final dateFormatter = DateFormat('dd MMM yyyy', 'id');
  final start = DateTime.tryParse(book.startDate);
  final end = book.endDate == null ? null : DateTime.tryParse(book.endDate!);
  final period =
      '${start == null ? book.startDate : dateFormatter.format(start)}'
      ' – '
      '${end == null ? 'Sekarang' : dateFormatter.format(end)}';

  final document = pw.Document();

  pw.Widget row(
    String label,
    double amount, {
    bool bold = false,
    bool indent = false,
    bool parens = false,
  }) {
    final style = pw.TextStyle(
      fontSize: 10,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    final text = parens || amount < 0
        ? '(${_printedAmount(amount)})'
        : _printedAmount(amount);
    return pw.Padding(
      padding: pw.EdgeInsets.only(left: indent ? 14 : 0, top: 3, bottom: 3),
      child: pw.Row(
        children: [
          pw.Expanded(child: pw.Text(label, style: style)),
          pw.Text(text, style: style),
        ],
      ),
    );
  }

  pw.Widget section(
    String title,
    List<MapEntry<String, double>> entries,
    double total,
    String totalLabel, {
    bool parens = false,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
        pw.Divider(height: 8, thickness: 0.8),
        if (entries.isEmpty)
          pw.Text(
            'Tidak ada data tercatat.',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          )
        else
          for (final entry in entries)
            row(entry.key, entry.value, indent: true, parens: parens),
        pw.Divider(height: 8, thickness: 0.8),
        row(totalLabel, total, bold: true, parens: parens),
      ],
    );
  }

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 40, 40, 40),
      build: (context) => [
        pw.Center(
          child: pw.Text(
            'LAPORAN ARUS KAS',
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Center(
          child: pw.Text(
            book.label,
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Center(
          child: pw.Text(
            period,
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ),
        pw.SizedBox(height: 22),

        section(
          'ARUS KAS DARI PEMASUKAN',
          sortedIncome,
          recap.totalIncome,
          'Jumlah pemasukan',
        ),
        pw.SizedBox(height: 18),
        section(
          'ARUS KAS UNTUK PENGELUARAN',
          categories.map((c) => MapEntry(c.label, c.amount)).toList(),
          recap.totalExpense,
          'Jumlah pengeluaran',
          parens: true,
        ),

        pw.SizedBox(height: 22),
        pw.Divider(thickness: 1.4),
        row('KENAIKAN (PENURUNAN) KAS BERSIH', recap.net, bold: true),
        pw.Divider(thickness: 0.8),

        pw.SizedBox(height: 26),
        pw.Text(
          'Dibuat oleh uangku · ${transactions.length} transaksi',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
      ],
    ),
  );

  return document.save();
}

/// Menulis PDF ke berkas sementara lalu membuka lembar berbagi sistem.
Future<void> shareCashflowPdf({
  required BuildContext context,
  required BookPeriod book,
  required List<FinanceTransaction> transactions,
}) async {
  final messenger = ScaffoldMessenger.of(context);

  if (transactions.isEmpty) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Belum ada transaksi untuk diekspor.')),
    );
    return;
  }

  try {
    final bytes = await buildCashflowPdf(
      book: book,
      transactions: transactions,
    );
    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/${cashflowFileName(book, extension: 'pdf')}',
    );
    await file.writeAsBytes(bytes);

    await Share.shareXFiles([
      XFile(file.path, mimeType: 'application/pdf'),
    ], subject: 'Laporan arus kas ${book.label}');
  } catch (e) {
    if (!messenger.mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text('Gagal mengekspor: ${friendlyError(e)}')),
    );
  }
}
