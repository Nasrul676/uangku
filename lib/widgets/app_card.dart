import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'animated_bouncing_card.dart';

/// A reusable Card component for the application.
/// It wraps AnimatedBouncingCard if [onTap] is provided and [isInteractive] is true,
/// otherwise it renders a standard styled container with the app's theme.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
    this.color,
    this.borderRadius,
    this.isInteractive = false,
    this.border,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final BorderRadiusGeometry? borderRadius;
  final bool isInteractive;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    if (isInteractive || onTap != null) {
      return AnimatedBouncingCard(
        onTap: onTap,
        padding: padding,
        margin: margin,
        color: color,
        borderRadius: borderRadius,
        child: child,
      );
    }

    final theme = Theme.of(context);
    final themeExtension = theme.extension<AppThemeExtension>();

    return Container(
      padding: padding,
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: color ?? theme.cardTheme.color,
        borderRadius: borderRadius ??
            (theme.cardTheme.shape is RoundedRectangleBorder
                ? (theme.cardTheme.shape as RoundedRectangleBorder).borderRadius
                : BorderRadius.circular(12)),
        border: border ?? themeExtension?.cardBorder,
        boxShadow: themeExtension?.cardShadow,
      ),
      child: child,
    );
  }
}
