import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Reusable Lottie loading indicator to replace CircularProgressIndicator.
///
/// If [color] is provided, a [ColorFilter] overlay is applied so the entire
/// animation is tinted to match the given colour (useful inside buttons with
/// a coloured background). When [color] is null the Lottie file's original
/// palette is rendered as-is, which looks best on most surfaces.
class CustomLoadingIndicator extends StatelessWidget {
  const CustomLoadingIndicator({
    super.key,
    this.size = 24.0,
    this.color,
  });

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Lottie.asset(
        'assets/lottie/loading.json',
        fit: BoxFit.contain,
        // Only tint when an explicit colour is requested.
        delegates: color != null
            ? LottieDelegates(
                values: [
                  ValueDelegate.color(
                    const ['**'],
                    value: color!,
                  ),
                ],
              )
            : null,
      ),
    );
  }
}
