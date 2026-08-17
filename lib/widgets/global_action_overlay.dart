import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

final GlobalKey<GlobalActionOverlayState> globalOverlayKey =
    GlobalKey<GlobalActionOverlayState>();

class GlobalActionOverlay extends StatefulWidget {
  const GlobalActionOverlay({super.key, required this.child});
  final Widget child;

  static Future<void> run(
    Future<void> Function() action, {
    String successMessage = 'Data berhasil disimpan!',
  }) async {
    final state = globalOverlayKey.currentState;
    if (state != null) {
      await state.runAction(action, successMessage: successMessage);
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

  Future<void> runAction(
    Future<void> Function() action, {
    String successMessage = 'Data berhasil disimpan!',
  }) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await action();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
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
      ],
    );
  }
}
