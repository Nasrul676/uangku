import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:uangkeluar/theme/app_theme.dart';
import 'package:uangkeluar/utils/category_icon.dart';

void main() {
  group('visualForCategory', () {
    test('mengenali kategori umum', () {
      expect(visualForCategory('Makanan').icon, LucideIcons.utensils);
      expect(visualForCategory('Transportasi').icon, LucideIcons.bus);
      expect(visualForCategory('Kesehatan').icon, LucideIcons.heartPulse);
      expect(visualForCategory('Belanja').icon, LucideIcons.shoppingCart);
    });

    test('tidak peduli huruf besar-kecil dan tanda baca', () {
      final a = visualForCategory('makanan');
      final b = visualForCategory('MAKANAN');
      final c = visualForCategory('Makanan & Minuman');
      expect(a, b);
      expect(a, c);
    });

    test('mencocokkan awalan kata, bukan potongan di tengah', () {
      // "busana" mengandung "bus" — pencocokan potongan akan salah
      // mengenalinya sebagai transportasi.
      expect(visualForCategory('Busana').icon, LucideIcons.shirt);
      expect(visualForCategory('Busway').icon, LucideIcons.bus);
    });

    test('kategori bawaan aplikasi tetap dapat ikon yang masuk akal', () {
      // Ini yang benar-benar dilihat pengguna baru.
      expect(
        visualForCategory('Tabungan/Investasi').icon,
        LucideIcons.piggyBank,
      );
      expect(
        visualForCategory('Gaji', isIncome: true).icon,
        LucideIcons.briefcase,
      );
      expect(
        visualForCategory('Bonus', isIncome: true).icon,
        LucideIcons.partyPopper,
      );
    });

    test('kategori tak dikenal jatuh ke ikon netral sesuai jenisnya', () {
      expect(visualForCategory('Needs').icon, LucideIcons.tag);
      expect(
        visualForCategory('Lain-lain', isIncome: true).icon,
        LucideIcons.banknote,
      );
    });

    test('teks kosong tidak melempar exception', () {
      expect(visualForCategory('').icon, LucideIcons.tag);
      expect(visualForCategory('   ').icon, LucideIcons.tag);
      expect(visualForCategory('!!!').icon, LucideIcons.tag);
    });

    test('warnanya selalu dari token tema yang sudah ada', () {
      // Bukan const: Color menimpa `==`, jadi tidak boleh jadi elemen set const.
      final allowed = {
        AppTheme.neoMint,
        AppTheme.neoCoral,
        AppTheme.neoYellow,
        AppTheme.neoBlue,
        AppTheme.neoLavender,
      };

      const samples = [
        'Makanan',
        'Transportasi',
        'Gaji',
        'Listrik',
        'Hiburan',
        'Kesehatan',
        'Entah apa ini',
      ];

      for (final sample in samples) {
        expect(
          allowed.contains(visualForCategory(sample).color),
          isTrue,
          reason: '$sample memakai warna di luar token tema',
        );
      }
    });
  });
}
