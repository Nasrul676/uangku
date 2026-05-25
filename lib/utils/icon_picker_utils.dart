import 'package:flutter/material.dart';

class IconPickerUtils {
  static const Map<String, IconData> _iconMap = {
    'wallet': Icons.account_balance_wallet,
    'savings': Icons.savings,
    'shopping_cart': Icons.shopping_cart,
    'restaurant': Icons.restaurant,
    'flight': Icons.flight,
    'home': Icons.home,
    'directions_car': Icons.directions_car,
    'school': Icons.school,
    'health_and_safety': Icons.health_and_safety,
    'fitness_center': Icons.fitness_center,
    'pets': Icons.pets,
    'monitor': Icons.monitor,
    'phone_iphone': Icons.phone_iphone,
    'movie': Icons.movie,
    'videogame_asset': Icons.videogame_asset,
    'checkroom': Icons.checkroom,
    'face': Icons.face,
    'local_cafe': Icons.local_cafe,
    'fastfood': Icons.fastfood,
    'local_grocery_store': Icons.local_grocery_store,
    'work': Icons.work,
    'redeem': Icons.redeem,
    'favorite': Icons.favorite,
    'star': Icons.star,
    'bolt': Icons.bolt,
    'emoji_events': Icons.emoji_events,
    'umbrella': Icons.umbrella, // Dana Darurat
  };

  static IconData getIconData(String iconName) {
    return _iconMap[iconName] ?? Icons.account_balance_wallet;
  }

  static List<String> getAllIconNames() {
    return _iconMap.keys.toList();
  }
}
