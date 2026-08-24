import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:uangkeluar/utils/relative_time.dart';
import 'package:uangkeluar/utils/rupiah_compact.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id', null);
  });

  group('relativeTimeLabel', () {
    final now = DateTime(2026, 8, 17, 14, 30);

    test('hari ini dihitung dalam jam dan menit', () {
      expect(relativeTimeLabel('2026-08-17', '12:30', now), '2 jam lalu');
      expect(relativeTimeLabel('2026-08-17', '14:05', now), '25 menit lalu');
      expect(relativeTimeLabel('2026-08-17', '14:30', now), 'baru saja');
    });

    test('jam yang lebih maju dari sekarang tidak jadi angka minus', () {
      // Bisa terjadi kalau pengguna mengisi jam secara manual.
      expect(relativeTimeLabel('2026-08-17', '20:00', now), 'baru saja');
    });

    test('hari ini tanpa jam tetap masuk akal', () {
      expect(relativeTimeLabel('2026-08-17', null, now), 'hari ini');
      expect(relativeTimeLabel('2026-08-17', '', now), 'hari ini');
    });

    test('kemarin menyebut jamnya kalau ada', () {
      expect(relativeTimeLabel('2026-08-16', '19:05', now), 'kemarin, 19:05');
      expect(relativeTimeLabel('2026-08-16', null, now), 'kemarin');
    });

    test('dalam seminggu terakhir dihitung per hari', () {
      expect(relativeTimeLabel('2026-08-14', '10:00', now), '3 hari lalu');
      expect(relativeTimeLabel('2026-08-12', null, now), '5 hari lalu');
    });

    test('lebih dari seminggu kembali ke tanggal biasa', () {
      // "23 hari lalu" memaksa orang berhitung sendiri.
      expect(relativeTimeLabel('2026-07-25', null, now), '25 Jul 2026');
    });

    test('tanggal di masa depan tidak jadi hari minus', () {
      expect(relativeTimeLabel('2026-08-20', null, now), '20 Agu 2026');
    });

    test('tanggal rusak dikembalikan apa adanya, bukan melempar exception', () {
      expect(relativeTimeLabel('bukan tanggal', null, now), 'bukan tanggal');
    });

    test('jam rusak diabaikan, tanggalnya tetap terbaca', () {
      expect(relativeTimeLabel('2026-08-17', '99:99', now), 'hari ini');
      expect(relativeTimeLabel('2026-08-17', 'pagi', now), 'hari ini');
      expect(relativeTimeLabel('2026-08-16', '25:00', now), 'kemarin');
    });
  });

  group('compactRupiah', () {
    test('memendekkan ribuan, jutaan, dan miliaran', () {
      expect(compactRupiah(171000), 'Rp 171rb');
      expect(compactRupiah(2400000), 'Rp 2,4jt');
      expect(compactRupiah(1500000000), 'Rp 1,5m');
    });

    test('koma nol dibuang', () {
      // "Rp 2,0jt" terbaca seperti hasil pembulatan yang ceroboh.
      expect(compactRupiah(2000000), 'Rp 2jt');
      expect(compactRupiah(5000), 'Rp 5rb');
    });

    test('di bawah seribu ditulis utuh', () {
      expect(compactRupiah(750), 'Rp 750');
      expect(compactRupiah(0), 'Rp 0');
    });

    test('nilai minus mempertahankan tandanya di depan', () {
      expect(compactRupiah(-24000), '-Rp 24rb');
    });

    test('awalan bisa dimatikan', () {
      expect(compactRupiah(171000, withPrefix: false), '171rb');
    });
  });
}
