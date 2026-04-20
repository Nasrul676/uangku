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

    return Scaffold(
      backgroundColor: const Color(0xFFCFAFE4),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 18,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: const Color(0xFF101010),
                    width: 1.2,
                  ),
                ),
                child: const Icon(
                  Icons.attach_money_rounded,
                  size: 12,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Text(
                'Atur Uang\nTanpa Ribet',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 44,
                  height: 1.02,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Catat uang masuk dan keluar dengan cara yang simpel, biar keuangan keluarga tetap nyaman dipantau.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF2D2D2D),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: _isCheckingRoute ? null : _startApp,
                  child: _isCheckingRoute
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Yuk Mulai'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
