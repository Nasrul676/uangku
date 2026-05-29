import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../utils/auth_page_route.dart';
import '../widgets/swipe_button.dart';
import 'dashboard_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _rememberMe = false;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<bool> _submit() async {
    if (_isLoading) return false;
    if (!_formKey.currentState!.validate()) return false;

    setState(() => _isLoading = true);

    try {
      final success = await _authService.login(
        email: _emailController.text,
        password: _passwordController.text,
        rememberMe: _rememberMe,
      );

      if (!mounted) return false;

      if (!success) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ups, email atau kata sandinya belum cocok.'),
          ),
        );
        return false;
      }

      final userName = await _authService.getCurrentUserName();
      if (!mounted) return false;
      Navigator.pushReplacement(
        context,
        dashboardEntryRoute(page: DashboardScreen(userName: userName)),
      );
      return true;
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
      return false;
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Palette colors
    final gradientColors = isDark
        ? [const Color(0xFF2A1B38), const Color(0xFF3B2A4A)]
        : [const Color(0xFF5A3092), const Color(0xFF8E5CC8)];

    final cardColor = isDark
        ? theme.colorScheme.surface
        : Colors.white;

    final fieldFill = isDark
        ? theme.colorScheme.surfaceContainerHighest
        : const Color(0xFFF5F5F5);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              gradientColors[0],
              gradientColors[1],
              cardColor,
            ],
            stops: const [0.0, 0.35, 0.35],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ─── Top Hero Section ───────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: Column(
                  children: [
                    // Wallet icon
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 28,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'UangKu',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: Colors.white.withOpacity(0.8),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Selamat Datang\nKembali 👋',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Masuk dulu ya, biar bisa lanjut\ncatat keuangan harianmu.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.75),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),

              // ─── Bottom Card Section ────────────────────────────────────
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 24,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    padding: EdgeInsets.fromLTRB(
                      24, 24, 24,
                      24 + MediaQuery.of(context).viewInsets.bottom,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ─── Tab Switcher ─────────────────────────────────
                        _AuthTabSwitcher(
                          activeTab: 0,
                          isDark: isDark,
                          onTabChanged: (index) {
                            if (index == 1) {
                              Navigator.pushReplacement(
                                context,
                                authPageRoute(
                                  page: const RegisterScreen(),
                                  direction: AxisDirection.left,
                                ),
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 28),

                        // ─── Form ─────────────────────────────────────────
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Email',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                decoration: _inputDecoration(
                                  hint: 'Masukkan email',
                                  icon: Icons.email_outlined,
                                  fillColor: fieldFill,
                                  isDark: isDark,
                                ),
                                validator: (value) {
                                  final text = (value ?? '').trim();
                                  if (text.isEmpty) return 'Email wajib diisi';
                                  if (!text.contains('@')) {
                                    return 'Format emailnya belum pas.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Password',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                decoration: _inputDecoration(
                                  hint: 'Masukkan password',
                                  icon: Icons.lock_outline_rounded,
                                  fillColor: fieldFill,
                                  isDark: isDark,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: isDark
                                          ? Colors.white54
                                          : const Color(0xFF9E9E9E),
                                    ),
                                    onPressed: () => setState(
                                      () => _obscurePassword = !_obscurePassword,
                                    ),
                                  ),
                                ),
                                onFieldSubmitted: (_) => _submit(),
                                validator: (value) {
                                  if ((value ?? '').isEmpty) {
                                    return 'Kata sandi masih kosong.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),

                              // Remember me
                              Row(
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: Checkbox(
                                      value: _rememberMe,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      onChanged: (value) {
                                        setState(() =>
                                            _rememberMe = value ?? false);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Ingat akun saya',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: isDark
                                          ? Colors.white70
                                          : const Color(0xFF666666),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),

                              // Swipe to login
                              SwipeButton(
                                label: 'Swipe untuk masuk',
                                onSwipeComplete: _submit,
                                isLoading: _isLoading,
                                isDark: isDark,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ─── Bottom Link ──────────────────────────────────
                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Belum punya akun? ',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isDark
                                      ? Colors.white54
                                      : const Color(0xFF999999),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.pushReplacement(
                                    context,
                                    PageRouteBuilder(
                                      pageBuilder: (_, __, ___) =>
                                          const RegisterScreen(),
                                      transitionDuration: Duration.zero,
                                    ),
                                  );
                                },
                                child: Text(
                                  'Daftar di sini',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: isDark
                                        ? theme.colorScheme.primary
                                        : const Color(0xFF5A3092),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    required Color fillColor,
    required bool isDark,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: isDark ? Colors.white38 : const Color(0xFFBDBDBD),
        fontSize: 14,
      ),
      prefixIcon: Icon(
        icon,
        size: 20,
        color: isDark ? Colors.white54 : const Color(0xFF9E9E9E),
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: fillColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark ? Colors.white12 : const Color(0xFFE0E0E0),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark ? Colors.white12 : const Color(0xFFE0E0E0),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF6C3FB5) : const Color(0xFF5A3092),
          width: 1.5,
        ),
      ),
    );
  }
}

// ─── Auth Tab Switcher ─────────────────────────────────────────────────────────

class _AuthTabSwitcher extends StatelessWidget {
  final int activeTab;
  final bool isDark;
  final ValueChanged<int> onTabChanged;

  const _AuthTabSwitcher({
    required this.activeTab,
    required this.isDark,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _buildTab(
            label: 'Masuk',
            isActive: activeTab == 0,
            onTap: () => onTabChanged(0),
            theme: theme,
          ),
          _buildTab(
            label: 'Daftar',
            isActive: activeTab == 1,
            onTap: () => onTabChanged(1),
            theme: theme,
          ),
        ],
      ),
    );
  }

  Widget _buildTab({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: isActive
                ? (isDark ? theme.colorScheme.surface : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive
                    ? (isDark ? Colors.white : const Color(0xFF1E1E1E))
                    : (isDark ? Colors.white54 : const Color(0xFF999999)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
