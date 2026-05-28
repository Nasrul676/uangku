import 'package:flutter/material.dart';

/// Widget shimmer/skeleton loading untuk menggantikan CircularProgressIndicator
/// pada list transaksi dan section lainnya.
class SkeletonLoader extends StatefulWidget {
  const SkeletonLoader({
    super.key,
    this.itemCount = 4,
    this.itemHeight = 72.0,
    this.showAvatar = true,
    this.showTrailing = true,
  });

  final int itemCount;
  final double itemHeight;
  final bool showAvatar;
  final bool showTrailing;

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
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
      builder: (context, _) {
        return Column(
          children: List.generate(
            widget.itemCount,
            (index) => _SkeletonItem(
              animValue: _animation.value,
              height: widget.itemHeight,
              showAvatar: widget.showAvatar,
              showTrailing: widget.showTrailing,
              // Stagger: item ke-N lebih gelap sedikit untuk efek wave
              delay: (index / widget.itemCount) * 0.4,
            ),
          ),
        );
      },
    );
  }
}

class _SkeletonItem extends StatelessWidget {
  const _SkeletonItem({
    required this.animValue,
    required this.height,
    required this.showAvatar,
    required this.showTrailing,
    required this.delay,
  });

  final double animValue;
  final double height;
  final bool showAvatar;
  final bool showTrailing;
  final double delay;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE8E8E8);
    final shimmerColor = isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF5F5F5);

    // Wave effect dengan delay per item
    final adjustedAnim = ((animValue + delay) % 1.0);
    final color = Color.lerp(baseColor, shimmerColor, adjustedAnim)!;

    return Container(
      height: height,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE),
        ),
      ),
      child: Row(
        children: [
          if (showAvatar) ...[
            _SkeletonBox(width: 40, height: 40, radius: 20, color: color),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _SkeletonBox(
                  width: double.infinity,
                  height: 12,
                  radius: 6,
                  color: color,
                ),
                const SizedBox(height: 8),
                _SkeletonBox(
                  width: 120,
                  height: 10,
                  radius: 5,
                  color: color,
                ),
              ],
            ),
          ),
          if (showTrailing) ...[
            const SizedBox(width: 12),
            _SkeletonBox(width: 60, height: 14, radius: 6, color: color),
          ],
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({
    required this.width,
    required this.height,
    required this.radius,
    required this.color,
  });

  final double width;
  final double height;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Variant skeleton untuk card summary (balance, pocket, dll)
class SkeletonCard extends StatefulWidget {
  const SkeletonCard({super.key, this.height = 100});
  final double height;

  @override
  State<SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<SkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE8E8E8);
    final shimmerColor = isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF5F5F5);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final color = Color.lerp(baseColor, shimmerColor, _animation.value)!;
        return Container(
          height: widget.height,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SkeletonBox(width: 80, height: 10, radius: 5, color: color),
              const SizedBox(height: 10),
              _SkeletonBox(width: 160, height: 20, radius: 8, color: color),
              const SizedBox(height: 8),
              _SkeletonBox(width: 100, height: 10, radius: 5, color: color),
            ],
          ),
        );
      },
    );
  }
}
