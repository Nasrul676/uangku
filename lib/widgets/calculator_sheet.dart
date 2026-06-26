import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/calculator_parser.dart';

class CalculatorSheet extends StatefulWidget {
  const CalculatorSheet({super.key});

  @override
  State<CalculatorSheet> createState() => _CalculatorSheetState();
}

class _CalculatorSheetState extends State<CalculatorSheet> {
  String _expression = '';
  static const String _prefKey = 'calculator_state';

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _expression = prefs.getString(_prefKey) ?? '';
    });
  }

  Future<void> _saveState(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, value);
  }

  void _onPressed(String text) {
    setState(() {
      if (text == 'C') {
        _expression = '';
      } else if (text == '⌫') {
        if (_expression.isNotEmpty) {
          _expression = _expression.substring(0, _expression.length - 1);
        }
      } else if (text == '=') {
        if (_expression.isNotEmpty) {
          try {
            _expression = CalculatorParser.formatAndCalculate(_expression);
          } catch (e) {
            // Keep expression if error
          }
        }
      } else {
        _expression += text;
      }
      _saveState(_expression);
    });
  }

  String _formatExpression(String expression) {
    if (expression.isEmpty) return '0';

    return expression.replaceAllMapped(RegExp(r'\d+(\.\d+)?'), (match) {
      String numStr = match.group(0)!;

      List<String> parts = numStr.split('.');
      String intPart = parts[0];

      // Add dots for thousands separator
      intPart = intPart.replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]}.',
      );

      if (parts.length > 1) {
        return '$intPart,${parts[1]}';
      }
      return intPart;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Container(
      padding: const EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        top: 8.0,
        bottom: 24.0,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Display area
          Container(
            width: double.infinity,
            alignment: Alignment.bottomRight,
            padding: const EdgeInsets.all(12),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                _formatExpression(_expression.isEmpty ? '0' : _expression),
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.0,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Numpad
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.25,
            children:
                [
                  'C',
                  '⌫',
                  '(',
                  ')',
                  '7',
                  '8',
                  '9',
                  '/',
                  '4',
                  '5',
                  '6',
                  '*',
                  '1',
                  '2',
                  '3',
                  '-',
                  '0',
                  '.',
                  '=',
                  '+',
                ].map((btn) {
                  final isOp = ['/', '*', '-', '+', '='].contains(btn);
                  final isSpecial = ['C', '⌫', '(', ')'].contains(btn);
                  final isEquals = btn == '=';

                  return InkWell(
                    onTap: () => _onPressed(btn),
                    borderRadius: BorderRadius.circular(16),
                    child: Ink(
                      decoration: BoxDecoration(
                        color: isEquals
                            ? Theme.of(context).colorScheme.primary
                            : isSpecial
                            ? Theme.of(context).colorScheme.secondaryContainer
                            : Theme.of(context).cardTheme.color ??
                                  Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: (isEquals || isSpecial)
                            ? null
                            : Border.all(
                                color: Theme.of(
                                  context,
                                ).dividerColor.withOpacity(0.3),
                              ),
                      ),
                      child: Center(
                        child: Text(
                          btn,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: isEquals
                                ? Theme.of(context).colorScheme.onPrimary
                                : isOp
                                ? Theme.of(context).colorScheme.primary
                                : isSpecial
                                ? Theme.of(
                                    context,
                                  ).colorScheme.onSecondaryContainer
                                : Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }
}
