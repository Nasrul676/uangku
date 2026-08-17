import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'calculator_parser.dart';

class RupiahInputFormatter extends TextInputFormatter {
  RupiahInputFormatter({String locale = 'id_ID'})
    : _numberFormatter = NumberFormat.decimalPattern(locale);

  final NumberFormat _numberFormatter;

  static double parse(String input) {
    return CalculatorParser.evaluate(input);
  }

  static String format(double value) {
    if (value <= 0) return '';
    if (value == value.truncateToDouble()) {
      return NumberFormat.decimalPattern('id_ID').format(value.toInt());
    } else {
      return NumberFormat.decimalPattern('id_ID').format(value);
    }
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    // Allow digits, dots, commas, k, m, +, -, *, /, (, ), spaces
    final sanitized = newValue.text.replaceAll(
      RegExp(r'[^0-9kKmM+\-*/()., ]'),
      '',
    );

    // Check if it contains math operators or k/m
    final hasMath = RegExp(r'[kKmM+\-*/()]').hasMatch(sanitized);

    if (hasMath) {
      // Just return the sanitized text without thousand separators forcing
      return TextEditingValue(
        text: sanitized,
        selection: TextSelection.collapsed(offset: sanitized.length),
      );
    }

    // Standard number formatting if no math symbols
    final parts = sanitized.split(',');
    final wholePart = parts[0].replaceAll(RegExp(r'[^0-9]'), '');

    if (wholePart.isEmpty && parts.length == 1) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final number = wholePart.isEmpty ? 0 : int.parse(wholePart);
    String formatted = _numberFormatter.format(number);

    if (parts.length > 1) {
      // It has a decimal part
      final decimalPart = parts[1].replaceAll(RegExp(r'[^0-9]'), '');
      formatted = '$formatted,$decimalPart';
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
