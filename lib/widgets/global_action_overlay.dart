import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:confetti/confetti.dart';

final GlobalKey<GlobalActionOverlayState> globalOverlayKey = GlobalKey<GlobalActionOverlayState>();

class GlobalActionOverlay extends StatefulWidget {
  const GlobalActionOverlay({super.key, required this.child});
  final Widget child;

  static Future<void> run(Future<void> Function() action) async {
    final state = globalOverlayKey.currentState;
    if (state != null) {
      await state.runAction(action);
    } else {
      // Fallback if overlay is not initialized
      await action();
    }
  }

  @override
  State<GlobalActionOverlay> createState() => GlobalActionOverlayState();
}

class GlobalActionOverlayState extends State<GlobalActionOverlay> {
  bool _isLoading = false;
  bool _isSuccess = false;

  late ConfettiController _leftConfettiController;
  late ConfettiController _rightConfettiController;

  @override
  void initState() {
    super.initState();
    _leftConfettiController = ConfettiController(duration: const Duration(seconds: 3));
    _rightConfettiController = ConfettiController(duration: const Duration(seconds: 3));
  }

  @override
  void dispose() {
    _leftConfettiController.dispose();
    _rightConfettiController.dispose();
    super.dispose();
  }

  Future<void> runAction(Future<void> Function() action) async {
    setState(() {
      _isLoading = true;
      _isSuccess = false;
    });

    try {
      // Minimum 1.5 seconds loading time
      await Future.wait([
        action(),
        Future.delayed(const Duration(milliseconds: 1500)),
      ]);

      setState(() {
        _isLoading = false;
        _isSuccess = true;
      });

      // Play confetti and success animation
      _leftConfettiController.play();
      _rightConfettiController.play();

      // Keep the success animation on screen for 2.5 seconds
      await Future.delayed(const Duration(milliseconds: 2500));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSuccess = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        widget.child,

        // Loading Overlay (Blocks UI)
        if (_isLoading)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: Center(
                child: Lottie.asset(
                  'assets/lottie/loading.json',
                  width: 150,
                  height: 150,
                ),
              ),
            ),
          ),

        // Success Overlay (Does NOT block UI clicks, using IgnorePointer)
        if (_isSuccess)
          Positioned.fill(
            child: IgnorePointer(
              child: Stack(
                children: [
                  // Center Success Lottie
                  Center(
                    child: Lottie.asset(
                      'assets/lottie/success.json',
                      width: 250,
                      height: 250,
                      repeat: false,
                    ),
                  ),
                  // Left Confetti
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ConfettiWidget(
                      confettiController: _leftConfettiController,
                      blastDirection: -pi / 4, // Up and right
                      emissionFrequency: 0.05,
                      numberOfParticles: 20,
                      maxBlastForce: 100,
                      minBlastForce: 80,
                      gravity: 0.1,
                    ),
                  ),
                  // Right Confetti
                  Align(
                    alignment: Alignment.centerRight,
                    child: ConfettiWidget(
                      confettiController: _rightConfettiController,
                      blastDirection: -3 * pi / 4, // Up and left
                      emissionFrequency: 0.05,
                      numberOfParticles: 20,
                      maxBlastForce: 100,
                      minBlastForce: 80,
                      gravity: 0.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
