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
    return NumberFormat.decimalPattern('id_ID').format(value.toInt());
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
    final sanitized = newValue.text.replaceAll(RegExp(r'[^0-9kKmM+\-*/()., ]'), '');

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
    final digits = sanitized.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final number = int.parse(digits);
    final formatted = _numberFormatter.format(number);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
