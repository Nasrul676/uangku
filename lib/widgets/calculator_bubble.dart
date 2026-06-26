import 'package:flutter/material.dart';
import 'calculator_sheet.dart';

class CalculatorBubble extends StatefulWidget {
  const CalculatorBubble({super.key});

  @override
  State<CalculatorBubble> createState() => _CalculatorBubbleState();
}

class _CalculatorBubbleState extends State<CalculatorBubble> {
  Offset _position = const Offset(16, 600); // Initial position

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Default position at bottom left
    final size = MediaQuery.of(context).size;
    _position = Offset(16, size.height - 150);
  }

  void _openCalculator() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: const CalculatorSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _position += details.delta;
          });
        },
        onPanEnd: (details) {
          // Snap to edges logic if needed
          final size = MediaQuery.of(context).size;
          double newX = _position.dx;
          double newY = _position.dy;

          if (newX < 0) newX = 16;
          if (newX > size.width - 64) newX = size.width - 80;
          if (newY < 50) newY = 50;
          if (newY > size.height - 100) newY = size.height - 150;

          setState(() {
            _position = Offset(newX, newY);
          });
        },
        onTap: _openCalculator,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).colorScheme.tertiary,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            Icons.calculate_rounded,
            color: Theme.of(context).colorScheme.onTertiary,
            size: 28,
          ),
        ),
      ),
    );
  }
}
