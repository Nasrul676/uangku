import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class IconPickerUtils {
  static const Map<String, String> _iconMap = {
    'wallet': '👛',
    'credit_card': '💳',
    'account_balance': '🏦',
    'banknote': '💵',
    'savings': '🐔', // Celengan ayam!
    'shopping_cart': '🛒',
    'restaurant': '🍽️',
    'flight': '✈️',
    'home': '🏠',
    'directions_car': '🚗',
    'school': '🎓',
    'health_and_safety': '🏥',
    'fitness_center': '🏋️',
    'pets': '🐶',
    'monitor': '💻',
    'phone_iphone': '📱',
    'movie': '🎬',
    'videogame_asset': '🎮',
    'checkroom': '👕',
    'face': '😎',
    'local_cafe': '☕',
    'fastfood': '🍔',
    'local_grocery_store': '🥦',
    'work': '💼',
    'redeem': '🎁',
    'favorite': '❤️',
    'star': '⭐',
    'bolt': '⚡',
    'emoji_events': '🏆',
    'umbrella': '☂️', // Dana Darurat
  };

  /// Padanan Lucide untuk kunci yang sama persis dengan [_iconMap].
  ///
  /// Emoji diambil dari font sistem, jadi bentuknya berbeda-beda antara
  /// Samsung, Pixel, dan iOS — kantong yang sama bisa terlihat lain di tiap
  /// HP. Ikon Lucide ikut dibundel bersama aplikasi, jadi tampilannya sama di
  /// mana pun dan sewarna dengan tema.
  ///
  /// Kuncinya sengaja tidak diubah supaya `pocket.icon` yang sudah tersimpan
  /// di basis data tetap terbaca tanpa migrasi.
  static const Map<String, IconData> _lucideMap = {
    'wallet': LucideIcons.wallet,
    'credit_card': LucideIcons.creditCard,
    'account_balance': LucideIcons.landmark,
    'banknote': LucideIcons.banknote,
    'savings': LucideIcons.piggyBank,
    'shopping_cart': LucideIcons.shoppingCart,
    'restaurant': LucideIcons.utensils,
    'flight': LucideIcons.plane,
    'home': LucideIcons.house,
    'directions_car': LucideIcons.carFront,
    'school': LucideIcons.graduationCap,
    'health_and_safety': LucideIcons.heartPulse,
    'fitness_center': LucideIcons.dumbbell,
    'pets': LucideIcons.pawPrint,
    'monitor': LucideIcons.monitor,
    'phone_iphone': LucideIcons.smartphone,
    'movie': LucideIcons.clapperboard,
    'videogame_asset': LucideIcons.gamepad2,
    'checkroom': LucideIcons.shirt,
    'face': LucideIcons.smile,
    'local_cafe': LucideIcons.coffee,
    'fastfood': LucideIcons.beef,
    'local_grocery_store': LucideIcons.carrot,
    'work': LucideIcons.briefcase,
    'redeem': LucideIcons.gift,
    'favorite': LucideIcons.heart,
    'star': LucideIcons.star,
    'bolt': LucideIcons.zap,
    'emoji_events': LucideIcons.trophy,
    'umbrella': LucideIcons.umbrella,
  };

  static String getIcon(String iconName) {
    return _iconMap[iconName] ?? '👛';
  }

  static IconData getLucideIcon(String iconName) {
    return _lucideMap[iconName] ?? LucideIcons.wallet;
  }

  static List<String> getAllIconNames() {
    return _iconMap.keys.toList();
  }
}
