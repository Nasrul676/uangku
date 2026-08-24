import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:uangkeluar/models/book_period.dart';
import 'package:uangkeluar/models/finance_transaction.dart';
import 'package:uangkeluar/utils/cashflow_export.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id', null);
  });

  const book = BookPeriod(
    id: 1,
    label: 'Agustus 2026',
    startDate: '2026-08-01',
    endDate: '2026-08-31',
    isClosed: 1,
  );

  FinanceTransaction tx({
    required String title,
    required double amount,
    String type = 'EXPENSE',
    String category = 'Makanan',
    String date = '2026-08-05',
    String? time,
    int? moneyLocationId,
  }) {
    return FinanceTransaction(
      bookPeriodId: 1,
      title: title,
      amount: amount,
      type: type,
      category: category,
      date: date,
      time: time,
      moneyLocationId: moneyLocationId,
    );
  }

  group('csvCell', () {
    test('nilai biasa tidak dikutip', () {
      expect(csvCell('Makanan'), 'Makanan');
      expect(csvCell(5000), '5000');
      expect(csvCell(null), '');
    });

    test('koma memicu pengutipan', () {
      // Tanpa ini, judul dengan koma akan menggeser seluruh kolom di barisnya.
      expect(csvCell('Nasi, ayam, es teh'), '"Nasi, ayam, es teh"');
    });

    test('kutip ganda digandakan', () {
      expect(csvCell('Beli "premium"'), '"Beli ""premium"""');
    });

    test('baris baru memicu pengutipan', () {
      expect(csvCell('baris1\nbaris2'), '"baris1\nbaris2"');
    });
  });

  group('buildCashflowCsv', () {
    test('memuat blok ringkasan dengan total yang benar', () {
      final csv = buildCashflowCsv(
        book: book,
        transactions: [
          tx(title: 'Gaji', amount: 7500000, type: 'INCOME', category: 'Gaji'),
          tx(title: 'Beras', amount: 5100000),
        ],
      );

      expect(csv, contains('Buku,Agustus 2026'));
      // Baris utuh, bukan `contains` — assertion longgar sempat menutupi
      // nominal yang tertulis "7500000.0".
      final lines = csv.split('\n');
      expect(lines, contains('Total Pemasukan,7500000'));
      expect(lines, contains('Total Pengeluaran,5100000'));
      expect(lines, contains('Saldo Bersih,2400000'));
      expect(csv.contains('.0'), isFalse);
      expect(csv, contains('Status,Selesai'));
    });

    test('baris transaksi memakai header yang benar', () {
      final csv = buildCashflowCsv(
        book: book,
        transactions: [tx(title: 'Beras', amount: 70000, time: '08:30')],
      );

      expect(csv, contains('Tanggal,Jam,Tipe,Kategori,Judul,Lokasi,Nominal'));
      expect(
        csv,
        contains('2026-08-05,08:30,Pengeluaran,Makanan,Beras,,70000'),
      );
    });

    test('kolom Lokasi terisi nama lokasi transaksi', () {
      final csv = buildCashflowCsv(
        book: book,
        transactions: [
          tx(
            title: 'Beras',
            amount: 70000,
            time: '08:30',
            moneyLocationId: 3,
          ),
        ],
        moneyLocationNames: const {3: 'Dompet'},
      );

      expect(
        csv,
        contains('2026-08-05,08:30,Pengeluaran,Makanan,Beras,Dompet,70000'),
      );
    });

    test('kolom Lokasi dikosongkan kalau lokasinya sudah dihapus', () {
      final csv = buildCashflowCsv(
        book: book,
        transactions: [
          tx(
            title: 'Beras',
            amount: 70000,
            time: '08:30',
            moneyLocationId: 99,
          ),
        ],
        moneyLocationNames: const {3: 'Dompet'},
      );

      expect(
        csv,
        contains('2026-08-05,08:30,Pengeluaran,Makanan,Beras,,70000'),
      );
    });

    test('transaksi terurut menurut tanggal lalu jam', () {
      final csv = buildCashflowCsv(
        book: book,
        transactions: [
          tx(title: 'Ketiga', amount: 3, date: '2026-08-10', time: '09:00'),
          tx(title: 'Pertama', amount: 1, date: '2026-08-05', time: '07:00'),
          tx(title: 'Kedua', amount: 2, date: '2026-08-05', time: '19:00'),
        ],
      );

      final body = csv.substring(csv.indexOf('Tanggal,Jam'));
      expect(
        body.indexOf('Pertama') < body.indexOf('Kedua'),
        isTrue,
        reason: 'jam lebih awal harus lebih dulu',
      );
      expect(body.indexOf('Kedua') < body.indexOf('Ketiga'), isTrue);
    });

    test('judul bertanda koma tidak merusak kolom', () {
      final csv = buildCashflowCsv(
        book: book,
        transactions: [tx(title: 'Nasi, ayam', amount: 25000)],
      );

      final line = csv
          .split('\n')
          .firstWhere((l) => l.contains('Nasi'), orElse: () => '');
      expect(line, contains('"Nasi, ayam"'));
      // Tanggal, jam, tipe, kategori, judul, lokasi, nominal — tujuh kolom,
      // dan koma di dalam judul tidak boleh menambah kolom kedelapan.
      expect(line.split(',').length, 8); // judul terkutip memuat satu koma
      expect(line.endsWith('25000'), isTrue);
    });

    test('jam kosong menghasilkan sel kosong, bukan kata null', () {
      final csv = buildCashflowCsv(
        book: book,
        transactions: [tx(title: 'Tanpa jam', amount: 1000)],
      );

      expect(csv.contains('null'), isFalse);
      expect(csv, contains('2026-08-05,,Pengeluaran'));
    });

    test('buku yang masih aktif ditandai Sekarang', () {
      const openBook = BookPeriod(
        id: 2,
        label: 'September 2026',
        startDate: '2026-09-01',
      );
      final csv = buildCashflowCsv(
        book: openBook,
        transactions: [tx(title: 'x', amount: 1)],
      );

      expect(csv, contains('Selesai,Sekarang'));
      expect(csv, contains('Status,Aktif'));
    });
  });

  group('cashflowFileName', () {
    test('label diubah jadi slug yang aman', () {
      expect(cashflowFileName(book), 'laporan-agustus-2026.csv');
    });

    test('karakter aneh dibersihkan', () {
      const odd = BookPeriod(
        id: 3,
        label: 'Buku #1 / Q3 (revisi)',
        startDate: '2026-01-01',
      );
      expect(cashflowFileName(odd), 'laporan-buku-1-q3-revisi.csv');
    });

    test('label kosong tetap menghasilkan nama berkas', () {
      const blank = BookPeriod(id: 4, label: '!!!', startDate: '2026-01-01');
      expect(cashflowFileName(blank), 'laporan-buku.csv');
    });
  });

  group('buildCashflowPdf', () {
    test('menghasilkan berkas PDF yang valid dan tidak kosong', () async {
      final bytes = await buildCashflowPdf(
        book: book,
        transactions: [
          tx(title: 'Gaji', amount: 7500000, type: 'INCOME', category: 'Gaji'),
          tx(title: 'Beras', amount: 5100000),
        ],
      );

      expect(bytes, isNotEmpty);
      // Setiap PDF diawali penanda "%PDF-".
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test(
      'buku tanpa transaksi tetap menghasilkan PDF, bukan exception',
      () async {
        final bytes = await buildCashflowPdf(
          book: book,
          transactions: const [],
        );
        expect(bytes, isNotEmpty);
      },
    );
  });
}
