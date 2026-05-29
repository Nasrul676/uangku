import 'dart:math';
import 'package:flutter/material.dart';

/// An entrance animation that plays once when the widget is first built.
///
/// Use [EntranceAnimation.type] to choose the animation:
/// - [EntranceType.flipX] — 3D flip around Y-axis (for balance card)
/// - [EntranceType.slideRight] — slides in from the right
/// - [EntranceType.slideUp] — slides in from the bottom
/// - [EntranceType.fadeScale] — fade in + scale up
enum EntranceType { flipX, slideRight, slideUp, fadeScale }

class EntranceAnimation extends StatefulWidget {
  final Widget child;
  final EntranceType type;
  final Duration delay;
  final Duration duration;
  final Curve curve;

  const EntranceAnimation({
    super.key,
    required this.child,
    this.type = EntranceType.fadeScale,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 700),
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<EntranceAnimation> createState() => _EntranceAnimationState();
}

class _EntranceAnimationState extends State<EntranceAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    );

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final value = _animation.value;

        switch (widget.type) {
          case EntranceType.flipX:
            return _buildFlip(value);
          case EntranceType.slideRight:
            return _buildSlideRight(value);
          case EntranceType.slideUp:
            return _buildSlideUp(value);
          case EntranceType.fadeScale:
            return _buildFadeScale(value);
        }
      },
    );
  }

  /// 3D flip around Y-axis
  Widget _buildFlip(double value) {
    // Start at 90° and rotate to 0°
    final angle = (1 - value) * pi / 2;

    return Opacity(
      opacity: value.clamp(0.0, 1.0),
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001) // perspective
          ..rotateY(angle),
        child: widget.child,
      ),
    );
  }

  /// Slide in from the right
  Widget _buildSlideRight(double value) {
    return Opacity(
      opacity: value.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(80 * (1 - value), 0),
        child: widget.child,
      ),
    );
  }

  /// Slide in from the bottom
  Widget _buildSlideUp(double value) {
    return Opacity(
      opacity: value.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, 60 * (1 - value)),
        child: widget.child,
      ),
    );
  }

  /// Fade in + scale up
  Widget _buildFadeScale(double value) {
    return Opacity(
      opacity: value.clamp(0.0, 1.0),
      child: Transform.scale(
        scale: 0.9 + (0.1 * value),
        child: widget.child,
      ),
    );
  }
}
