import 'package:flutter/material.dart';

/// Smooth horizontal slide transition for switching between auth screens.
///
/// [direction] controls the slide direction:
/// - `AxisDirection.left` = new page slides in from right (→ Register)
/// - `AxisDirection.right` = new page slides in from left (← Login)
Route<T> authPageRoute<T>({
  required Widget page,
  AxisDirection direction = AxisDirection.left,
}) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionDuration: const Duration(milliseconds: 400),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final isLeft = direction == AxisDirection.left;

      // New page slides in
      final slideIn = Tween<Offset>(
        begin: Offset(isLeft ? 1.0 : -1.0, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      ));

      // Fade in
      final fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: animation,
          curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
        ),
      );

      return SlideTransition(
        position: slideIn,
        child: FadeTransition(
          opacity: fadeIn,
          child: child,
        ),
      );
    },
  );
}

/// Fade + scale up transition from login/register → dashboard.
Route<T> dashboardEntryRoute<T>({required Widget page}) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionDuration: const Duration(milliseconds: 600),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final scale = Tween<double>(begin: 0.92, end: 1.0).animate(
        CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
      );
      final fade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: animation,
          curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
        ),
      );

      return FadeTransition(
        opacity: fade,
        child: ScaleTransition(
          scale: scale,
          child: child,
        ),
      );
    },
  );
}
