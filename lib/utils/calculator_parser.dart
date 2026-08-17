import 'package:math_expressions/math_expressions.dart';

class CalculatorParser {
  static double _evaluateExpression(String sanitized) {
    final Expression exp = ShuntingYardParser().parse(sanitized);
    return RealEvaluator().evaluate(exp).toDouble();
  }

  /// Evaluates a mathematical expression string and returns the result as a double.
  /// If the expression is invalid, it returns 0.0 or the parsed number if it's just a number.
  static double evaluate(String input) {
    if (input.trim().isEmpty) return 0.0;

    String sanitized = input
        .toLowerCase()
        .replaceAll('rp', '')
        .replaceAll(' ', '')
        .replaceAll('.', '') // Remove thousand separators
        .replaceAll(',', '.'); // Comma to decimal point

    // Support 'k' for thousand and 'm' for million
    sanitized = sanitized.replaceAllMapped(
      RegExp(r'(\d+)k'),
      (match) => '${match[1]}000',
    );
    sanitized = sanitized.replaceAllMapped(
      RegExp(r'(\d+)m'),
      (match) => '${match[1]}000000',
    );

    // If it's empty after sanitization
    if (sanitized.isEmpty) return 0.0;

    try {
      return _evaluateExpression(sanitized);
    } catch (e) {
      // If parsing fails (e.g. trailing operator "50000+"), try to strip trailing non-digits and parse again
      try {
        final RegExp trailingOps = RegExp(r'[+\-*/]+$');
        if (trailingOps.hasMatch(sanitized)) {
          sanitized = sanitized.replaceAll(trailingOps, '');
          return _evaluateExpression(sanitized);
        }
      } catch (_) {}

      // Fallback: try parsing as double directly, otherwise 0
      return double.tryParse(sanitized) ?? 0.0;
    }
  }

  /// Formats a string by evaluating it and converting it back to a clean string without trailing .0
  static String formatAndCalculate(String input) {
    double result = evaluate(input);
    if (result == result.truncateToDouble()) {
      return result.toInt().toString();
    }
    return result.toString();
  }
}
