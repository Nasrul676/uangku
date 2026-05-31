import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Menampilkan overlay success animation singkat (scale + fade).
/// Dipanggil sebelum Navigator.pop() saat transaksi berhasil disimpan.
///
/// Contoh pemakaian:
/// ```dart
/// await SuccessOverlay.show(context, message: 'Pengeluaran disimpan!');
/// if (!mounted) return;
/// Navigator.pop(context);
/// ```
class SuccessOverlay {
  static Future<void> show(
    BuildContext context, {
    String message = 'Berhasil disimpan!',
    Color color = const Color(0xFF2A9D50),
    Duration duration = const Duration(milliseconds: 900),
    String lottieAsset = 'assets/lottie/success.json',
  }) async {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => _SuccessOverlayWidget(
        message: message,
        color: color,
        lottieAsset: lottieAsset,
        onDone: () => entry.remove(),
        duration: duration,
      ),
    );

    overlay.insert(entry);
    await Future.delayed(duration + const Duration(milliseconds: 300));
  }
}

class _SuccessOverlayWidget extends StatefulWidget {
  const _SuccessOverlayWidget({
    required this.message,
    required this.color,
    required this.lottieAsset,
    required this.onDone,
    required this.duration,
  });

  final String message;
  final Color color;
  final String lottieAsset;
  final VoidCallback onDone;
  final Duration duration;

  @override
  State<_SuccessOverlayWidget> createState() => _SuccessOverlayWidgetState();
}

class _SuccessOverlayWidgetState extends State<_SuccessOverlayWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scale = TweenSequence([
      TweenSequenceItem(
        tween: Tween(begin: 0.5, end: 1.1)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.1, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
    ]).animate(_ctrl);

    _opacity = TweenSequence([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: ConstantTween(1.0),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
    ]).animate(_ctrl);

    _ctrl.forward().then((_) => widget.onDone());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Catatan: JANGAN gunakan Positioned.fill di sini karena widget ini
    // di-build di dalam AnimatedBuilder, bukan sebagai direct child dari Stack.
    // SizedBox.expand mengisi seluruh ruang yang tersedia dari parent Overlay.
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return SizedBox.expand(
          child: IgnorePointer(
            child: Opacity(
              opacity: _opacity.value,
              child: ColoredBox(
                color: Colors.black.withOpacity(0.25),
                child: Center(
                  child: Transform.scale(
                    scale: _scale.value,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 28,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: widget.color.withOpacity(0.25),
                            blurRadius: 32,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: widget.color.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Lottie.asset(
                              widget.lottieAsset,
                              width: 72,
                              height: 72,
                              repeat: false,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            widget.message,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: Theme.of(context).textTheme.titleMedium?.fontFamily ?? 'PlusJakartaSans',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF111111),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
