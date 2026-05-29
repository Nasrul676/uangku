import 'dart:math';
import 'package:flutter/material.dart';

/// Wraps a child widget with a repeating bell-shake + scale-pulse animation.
///
/// The animation plays continuously while [animate] is true and stops
/// gracefully when set to false.
class AnimatedBellIcon extends StatefulWidget {
  final Widget child;
  final bool animate;

  const AnimatedBellIcon({
    super.key,
    required this.child,
    this.animate = false,
  });

  @override
  State<AnimatedBellIcon> createState() => _AnimatedBellIconState();
}

class _AnimatedBellIconState extends State<AnimatedBellIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shakeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    // Bell shake: 0.0→0.5 — do the shake, 0.5→1.0 — rest
    _shakeAnimation = TweenSequence<double>([
      // Shake left
      TweenSequenceItem(tween: Tween(begin: 0, end: -0.12), weight: 6),
      // Shake right
      TweenSequenceItem(tween: Tween(begin: -0.12, end: 0.12), weight: 6),
      // Shake left (smaller)
      TweenSequenceItem(tween: Tween(begin: 0.12, end: -0.08), weight: 6),
      // Shake right (smaller)
      TweenSequenceItem(tween: Tween(begin: -0.08, end: 0.08), weight: 6),
      // Settle back
      TweenSequenceItem(tween: Tween(begin: 0.08, end: 0), weight: 6),
      // Rest
      TweenSequenceItem(tween: ConstantTween(0), weight: 70),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    // Scale pulse: subtle bump at the start
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.18), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 1.18, end: 1.0), weight: 20),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 70),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    if (widget.animate) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedBellIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.animate && _controller.isAnimating) {
      // Let current cycle finish, then stop
      _controller.forward().then((_) {
        if (mounted && !widget.animate) {
          _controller.reset();
        }
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
    if (!widget.animate) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Transform.rotate(
            angle: _shakeAnimation.value * pi,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
