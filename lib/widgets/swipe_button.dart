import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'custom_loading_indicator.dart';

/// A swipe-to-action button with animated chevrons and shimmer text.
///
/// [onSwipeComplete] should return `true` if the action succeeded
/// (e.g. navigated away), or `false` to snap the handle back
/// (e.g. form validation failed).
class SwipeButton extends StatefulWidget {
  final String label;
  final Future<bool> Function() onSwipeComplete;
  final bool isLoading;
  final bool isDark;

  const SwipeButton({
    super.key,
    required this.label,
    required this.onSwipeComplete,
    this.isLoading = false,
    this.isDark = false,
  });

  @override
  State<SwipeButton> createState() => _SwipeButtonState();
}

class _SwipeButtonState extends State<SwipeButton>
    with TickerProviderStateMixin {
  double _dragOffset = 0;
  bool _completed = false;

  late AnimationController _chevronController;
  late AnimationController _shimmerController;
  late AnimationController _snapBackController;
  late Animation<double> _snapBackAnimation;

  static const double _trackHeight = 64;
  static const double _handleSize = 52;
  static const double _handlePadding = 6;

  @override
  void initState() {
    super.initState();

    _chevronController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _snapBackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _snapBackAnimation = CurvedAnimation(
      parent: _snapBackController,
      curve: Curves.elasticOut,
    );
  }

  @override
  void didUpdateWidget(covariant SwipeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Also reset if parent explicitly sets isLoading back to false
    if (oldWidget.isLoading && !widget.isLoading && _completed) {
      _snapToStart();
    }
  }

  @override
  void dispose() {
    _chevronController.dispose();
    _shimmerController.dispose();
    _snapBackController.dispose();
    super.dispose();
  }

  double get _maxDrag {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return 200;
    return box.size.width - _handleSize - _handlePadding * 2;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_completed || widget.isLoading) return;
    setState(() {
      _dragOffset = (_dragOffset + details.delta.dx).clamp(0.0, _maxDrag);
    });
  }

  void _onDragEnd(DragEndDetails details) async {
    if (_completed || widget.isLoading) return;

    if (_dragOffset >= _maxDrag * 0.85) {
      setState(() {
        _completed = true;
        _dragOffset = _maxDrag;
      });
      HapticFeedback.heavyImpact();

      final success = await widget.onSwipeComplete();
      if (!success && mounted) {
        _snapToStart();
      }
    } else {
      _animateSnapBack(_dragOffset);
      HapticFeedback.lightImpact();
    }
  }

  /// Snap the handle back to start position with elastic animation.
  void _snapToStart() {
    _animateSnapBack(_dragOffset);
    _completed = false;
  }

  void _animateSnapBack(double fromOffset) {
    _snapBackController.reset();
    _snapBackController.addListener(_createSnapBackListener(fromOffset));
    _snapBackController.forward();
  }

  VoidCallback _createSnapBackListener(double startOffset) {
    late VoidCallback listener;
    listener = () {
      setState(() {
        _dragOffset = startOffset * (1 - _snapBackAnimation.value);
      });
      if (_snapBackController.isCompleted) {
        _snapBackController.removeListener(listener);
      }
    };
    return listener;
  }

  @override
  Widget build(BuildContext context) {
    final progress = _maxDrag > 0 ? (_dragOffset / _maxDrag) : 0.0;

    final trackColors = widget.isDark
        ? [const Color(0xFF6C3FB5), const Color(0xFF9B59B6)]
        : [const Color(0xFFE8590C), const Color(0xFFF76707)];

    return SizedBox(
      width: double.infinity,
      height: _trackHeight,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_trackHeight / 2),
          gradient: LinearGradient(colors: trackColors),
          boxShadow: [
            BoxShadow(
              color: trackColors[0].withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Shimmer text
            Center(
              child: AnimatedBuilder(
                animation: _shimmerController,
                builder: (context, child) {
                  return ShaderMask(
                    shaderCallback: (bounds) {
                      return LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.4),
                          Colors.white.withOpacity(1.0),
                          Colors.white.withOpacity(0.4),
                        ],
                        stops: [
                          (_shimmerController.value - 0.3).clamp(0.0, 1.0),
                          _shimmerController.value,
                          (_shimmerController.value + 0.3).clamp(0.0, 1.0),
                        ],
                      ).createShader(bounds);
                    },
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: (1.0 - progress * 2).clamp(0.0, 1.0),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 40),
                        child: Text(
                          widget.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Draggable handle
            Positioned(
              left: _handlePadding + _dragOffset,
              top: _handlePadding,
              child: GestureDetector(
                onHorizontalDragUpdate: _onDragUpdate,
                onHorizontalDragEnd: _onDragEnd,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  width: _handleSize,
                  height: _handleSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(2, 2),
                      ),
                    ],
                  ),
                  child: widget.isLoading
                      ? CustomLoadingIndicator(
                          size: 24,
                          color: trackColors[0],
                        )
                      : AnimatedBuilder(
                          animation: _chevronController,
                          builder: (context, _) {
                            return CustomPaint(
                              painter: _ChevronPainter(
                                progress: _chevronController.value,
                                color: trackColors[0],
                              ),
                            );
                          },
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Animated Chevrons Painter ───────────────────────────────────────────────

class _ChevronPainter extends CustomPainter {
  final double progress;
  final Color color;

  _ChevronPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    const chevronWidth = 6.0;
    const chevronHeight = 10.0;
    const spacing = 7.0;
    final startX = size.width / 2 - spacing;

    for (int i = 0; i < 3; i++) {
      final phase = ((progress * 3) - i).clamp(0.0, 1.0);
      final opacity = sin(phase * pi);

      final paint = Paint()
        ..color = color.withOpacity(opacity.clamp(0.2, 1.0))
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      final x = startX + (i * spacing);
      final path = Path()
        ..moveTo(x, centerY - chevronHeight / 2)
        ..lineTo(x + chevronWidth, centerY)
        ..lineTo(x, centerY + chevronHeight / 2);

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ChevronPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
