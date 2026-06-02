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

class _EntranceAnimationState extends State<EntranceAnimation> {
  bool _start = false;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _start = true;
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) setState(() => _start = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: _start ? 1.0 : 0.0),
      duration: widget.duration,
      curve: widget.curve,
      builder: (context, value, child) {
        switch (widget.type) {
          case EntranceType.flipX:
            return _buildFlip(value, child!);
          case EntranceType.slideRight:
            return _buildSlideRight(value, child!);
          case EntranceType.slideUp:
            return _buildSlideUp(value, child!);
          case EntranceType.fadeScale:
            return _buildFadeScale(value, child!);
        }
      },
      child: widget.child,
    );
  }

  /// 3D flip around Y-axis
  Widget _buildFlip(double value, Widget child) {
    // Start at 90° and rotate to 0°
    final angle = (1 - value) * pi / 2;

    return Opacity(
      opacity: value.clamp(0.0, 1.0),
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001) // perspective
          ..rotateY(angle),
        child: child,
      ),
    );
  }

  /// Slide in from the right
  Widget _buildSlideRight(double value, Widget child) {
    return Opacity(
      opacity: value.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(80 * (1 - value), 0),
        child: child,
      ),
    );
  }

  /// Slide in from the bottom
  Widget _buildSlideUp(double value, Widget child) {
    return Opacity(
      opacity: value.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, 60 * (1 - value)),
        child: child,
      ),
    );
  }

  /// Fade in + scale up
  Widget _buildFadeScale(double value, Widget child) {
    return Opacity(
      opacity: value.clamp(0.0, 1.0),
      child: Transform.scale(
        scale: 0.9 + (0.1 * value),
        child: child,
      ),
    );
  }
}
