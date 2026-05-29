import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _authService = AuthService();
  bool _isCheckingRoute = false;

  Future<void> _startApp() async {
    if (_isCheckingRoute) return;
    setState(() => _isCheckingRoute = true);

    final shouldSkipAuth = await _authService.shouldSkipAuth();
    if (!mounted) return;

    if (shouldSkipAuth) {
      final userName = await _authService.getCurrentUserName();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => DashboardScreen(userName: userName)),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF2A1B38), const Color(0xFF3B2A4A), const Color(0xFF1E3A5F)]
                : [const Color(0xFFFFF2D8), const Color(0xFFEAD6EE), const Color(0xFFA0E9FF)],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black.withOpacity(0.3) : Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('💸', style: TextStyle(fontSize: 32)),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? theme.colorScheme.surface.withOpacity(0.5) : Colors.white.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '✨ UangKu App',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: isDark ? theme.colorScheme.primary : const Color(0xFF5A3092),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Atur Uang\nJadi Lebih\nMenyenangkan',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 48,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Catat pemasukan & pengeluaranmu dengan cara yang simpel dan antarmuka yang ceria.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.white70 : const Color(0xFF4A4A4A),
                    height: 1.6,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: _isCheckingRoute ? null : _startApp,
                    style: FilledButton.styleFrom(
                      backgroundColor: isDark ? theme.colorScheme.primary : const Color(0xFF1E1E1E),
                      foregroundColor: isDark ? theme.colorScheme.onPrimary : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 8,
                      shadowColor: const Color(0xFF1E1E1E).withOpacity(isDark ? 0.0 : 0.3),
                    ),
                    child: _isCheckingRoute
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Yuk Mulai Sekarang!',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
