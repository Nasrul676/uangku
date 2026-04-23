import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AnimatedBouncingCard extends StatefulWidget {
  const AnimatedBouncingCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
    this.color,
    this.borderRadius,
    this.isPressedEffect = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final BorderRadiusGeometry? borderRadius;
  final bool isPressedEffect;

  @override
  State<AnimatedBouncingCard> createState() => _AnimatedBouncingCardState();
}

class _AnimatedBouncingCardState extends State<AnimatedBouncingCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeExtension = theme.extension<AppThemeExtension>();
    
    final inner = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      padding: widget.padding,
      margin: widget.margin,
      decoration: BoxDecoration(
        color: widget.color ?? theme.cardTheme.color,
        borderRadius: widget.borderRadius ?? (theme.cardTheme.shape is RoundedRectangleBorder 
          ? (theme.cardTheme.shape as RoundedRectangleBorder).borderRadius 
          : BorderRadius.circular(12)),
        border: themeExtension?.cardBorder,
        boxShadow: themeExtension?.cardShadow,
      ),
      child: widget.child,
    );

    if (widget.onTap == null || !widget.isPressedEffect) {
      if (widget.onTap != null) {
        return GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: inner,
        );
      }
      return inner;
    }

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.fastOutSlowIn,
        child: inner,
      ),
    );
  }
}
