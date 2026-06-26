import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../screens/ai_chat_panel.dart';

class AiChatBubble extends StatefulWidget {
  final String currentContext;

  const AiChatBubble({
    super.key,
    required this.currentContext,
  });

  @override
  State<AiChatBubble> createState() => _AiChatBubbleState();
}

class _AiChatBubbleState extends State<AiChatBubble> {
  Offset _position = const Offset(300, 600); // Initial position

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Default position at bottom right
    final size = MediaQuery.of(context).size;
    _position = Offset(size.width - 80, size.height - 150);
  }

  void _openChatPanel() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AiChatPanel(currentContext: widget.currentContext),
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
        onTap: _openChatPanel,
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Lottie.asset(
            'assets/lottie/AI.json',
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
