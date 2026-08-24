import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_theme.dart';

/// Ikon dan warna untuk satu kategori.
@immutable
class CategoryVisual {
  const CategoryVisual(this.icon, this.color);

  /// Ikon Lucide — bergaris seragam 2px, satu bahasa visual dengan border
  /// tebal yang sudah dipakai di seluruh gaya neo-brutalis aplikasi ini.
  final IconData icon;

  /// Latar kotaknya. Selalu dari token yang sudah ada di [AppTheme], bukan
  /// warna baru, supaya beranda tetap satu keluarga dengan layar lain.
  final Color color;

  @override
  bool operator ==(Object other) =>
      other is CategoryVisual && other.icon == icon && other.color == color;

  @override
  int get hashCode => Object.hash(icon, color);
}

class _Rule {
  const _Rule(this.keywords, this.icon, this.color);
  final List<String> keywords;
  final IconData icon;
  final Color color;
}

/// Kategori di aplikasi ini adalah teks bebas yang bisa diubah pengguna
/// (lihat `AppSettingsService.defaultExpenseCategories`), jadi tidak ada
/// daftar tetap yang bisa dipetakan satu per satu. Pencocokannya lewat kata
/// kunci: kategori dipecah jadi kata, lalu dicocokkan dengan awalan kata.
///
/// Sengaja mencocokkan kata utuh atau awalannya, bukan potongan di
/// tengah — `contains('bus')` akan salah mengenali "busana" sebagai
/// transportasi.
///
/// Urutan menentukan: aturan pertama yang cocok menang.
const List<_Rule> _rules = [
  // Pakaian didahulukan supaya "busana" tidak tertangkap aturan transportasi.
  _Rule(
    ['baju', 'busana', 'pakaian', 'sandang', 'fashion', 'sepatu'],
    LucideIcons.shirt,
    AppTheme.neoLavender,
  ),
  _Rule(
    [
      'makan',
      'makanan',
      'nasi',
      'jajan',
      'kuliner',
      'warung',
      'resto',
      'restoran',
      'kopi',
      'ngopi',
      'cafe',
      'kafe',
      'snack',
      'sarapan',
      'minum',
      'minuman',
      'dapur',
      'sembako',
    ],
    LucideIcons.utensils,
    AppTheme.neoYellow,
  ),
  _Rule(
    ['bensin', 'bbm', 'solar', 'pertalite', 'pertamax'],
    LucideIcons.fuel,
    AppTheme.neoCoral,
  ),
  _Rule(
    [
      'transport',
      'transportasi',
      'ojek',
      'ojol',
      'gojek',
      'grab',
      'angkot',
      'busway',
      'kereta',
      'krl',
      'parkir',
      'tol',
      'perjalanan',
      'ongkos',
    ],
    LucideIcons.bus,
    AppTheme.neoBlue,
  ),
  _Rule(
    ['motor', 'mobil', 'kendaraan', 'servis', 'bengkel'],
    LucideIcons.bike,
    AppTheme.neoBlue,
  ),
  _Rule(
    [
      'belanja',
      'shopping',
      'toko',
      'olshop',
      'marketplace',
      'pasar',
      'groceries',
    ],
    LucideIcons.shoppingCart,
    AppTheme.neoCoral,
  ),
  _Rule(
    ['listrik', 'token', 'pln', 'tagihan', 'utilitas', 'iuran', 'langganan'],
    LucideIcons.zap,
    AppTheme.neoYellow,
  ),
  _Rule(['air', 'pdam', 'galon'], LucideIcons.droplet, AppTheme.neoBlue),
  _Rule(['internet', 'wifi', 'indihome'], LucideIcons.wifi, AppTheme.neoBlue),
  _Rule(
    ['pulsa', 'hp', 'telepon', 'ponsel'],
    LucideIcons.smartphone,
    AppTheme.neoLavender,
  ),
  _Rule(
    [
      'rumah',
      'kos',
      'kontrakan',
      'sewa',
      'kpr',
      'cicilan',
      'perabot',
      'rumahtangga',
    ],
    LucideIcons.house,
    AppTheme.neoMint,
  ),
  _Rule(
    [
      'sehat',
      'kesehatan',
      'obat',
      'dokter',
      'apotek',
      'rumahsakit',
      'bpjs',
      'vitamin',
      'medis',
    ],
    LucideIcons.heartPulse,
    AppTheme.neoCoral,
  ),
  _Rule(
    ['sekolah', 'pendidikan', 'kuliah', 'kursus', 'buku', 'spp', 'belajar'],
    LucideIcons.graduationCap,
    AppTheme.neoLavender,
  ),
  _Rule(
    ['hiburan', 'nonton', 'bioskop', 'film', 'game', 'main', 'musik'],
    LucideIcons.gamepad2,
    AppTheme.neoLavender,
  ),
  _Rule(
    ['olahraga', 'gym', 'fitness', 'lari', 'sport'],
    LucideIcons.dumbbell,
    AppTheme.neoMint,
  ),
  _Rule(
    ['liburan', 'wisata', 'traveling', 'travel', 'jalanjalan', 'tiket'],
    LucideIcons.plane,
    AppTheme.neoBlue,
  ),
  _Rule(
    ['hadiah', 'kado', 'gift', 'sedekah', 'zakat', 'donasi', 'amal', 'infak'],
    LucideIcons.gift,
    AppTheme.neoCoral,
  ),
  _Rule(
    ['anak', 'bayi', 'popok', 'susu'],
    LucideIcons.baby,
    AppTheme.neoYellow,
  ),
  _Rule(
    ['keluarga', 'orangtua', 'ortu', 'istri', 'suami'],
    LucideIcons.users,
    AppTheme.neoMint,
  ),
  _Rule(
    ['hewan', 'kucing', 'anjing', 'peliharaan'],
    LucideIcons.pawPrint,
    AppTheme.neoYellow,
  ),
  _Rule(['darurat', 'emergency'], LucideIcons.lifeBuoy, AppTheme.neoCoral),
  _Rule(
    ['tabungan', 'nabung', 'menabung', 'simpanan', 'celengan'],
    LucideIcons.piggyBank,
    AppTheme.neoMint,
  ),
  _Rule(
    ['investasi', 'saham', 'reksadana', 'emas', 'crypto', 'deposito'],
    LucideIcons.trendingUp,
    AppTheme.neoMint,
  ),
  // Pemasukan.
  _Rule(
    ['gaji', 'gajian', 'upah', 'thr', 'penghasilan'],
    LucideIcons.briefcase,
    AppTheme.neoMint,
  ),
  _Rule(
    ['bonus', 'komisi', 'insentif', 'tunjangan'],
    LucideIcons.partyPopper,
    AppTheme.neoMint,
  ),
  _Rule(
    ['freelance', 'proyek', 'usaha', 'dagang', 'jualan', 'bisnis'],
    LucideIcons.handCoins,
    AppTheme.neoMint,
  ),
];

/// Memilih ikon dan warna untuk sebuah kategori.
///
/// [isIncome] hanya dipakai kalau tidak ada aturan yang cocok — pemasukan tak
/// dikenal jatuh ke ikon uang, pengeluaran ke label netral.
CategoryVisual visualForCategory(String category, {bool isIncome = false}) {
  final tokens = category
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((t) => t.isNotEmpty)
      .toList();

  for (final rule in _rules) {
    for (final token in tokens) {
      for (final keyword in rule.keywords) {
        if (token == keyword || token.startsWith(keyword)) {
          return CategoryVisual(rule.icon, rule.color);
        }
      }
    }
  }

  return isIncome
      ? const CategoryVisual(LucideIcons.banknote, AppTheme.neoMint)
      : const CategoryVisual(LucideIcons.tag, AppTheme.neoBlue);
}
