import 'package:flutter/material.dart';

class IconPickerUtils {
  static const Map<String, String> _iconMap = {
    'wallet': '👛',
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

  static String getIcon(String iconName) {
    return _iconMap[iconName] ?? '👛';
  }

  static List<String> getAllIconNames() {
    return _iconMap.keys.toList();
  }
}
