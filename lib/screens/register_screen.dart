import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../utils/auth_page_route.dart';
import '../widgets/swipe_button.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<bool> _submit() async {
    if (_isLoading) return false;
    if (!_formKey.currentState!.validate()) return false;

    setState(() => _isLoading = true);

    try {
      await _authService.register(
        name: _nameController.text,
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (!mounted) return false;
      Navigator.pushReplacement(
        context,
        dashboardEntryRoute(
          page: DashboardScreen(userName: _nameController.text.trim()),
        ),
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

    // Palette colors — keep existing warm/purple palette
    final gradientColors = isDark
        ? [const Color(0xFF2A1B38), const Color(0xFF3B2A4A)]
        : [const Color(0xFF5A3092), const Color(0xFF8E5CC8)];

    final cardColor = isDark ? theme.colorScheme.surface : Colors.white;

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
            stops: const [0.0, 0.30, 0.30],
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
                      'Bikin Akun Baru ✨',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Daftar pakai nama, email, dan kata sandi.\nCepat kok, gak ribet! 😊',
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
                          activeTab: 1,
                          isDark: isDark,
                          onTabChanged: (index) {
                            if (index == 0) {
                              Navigator.pushReplacement(
                                context,
                                authPageRoute(
                                  page: const LoginScreen(),
                                  direction: AxisDirection.right,
                                ),
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 24),

                        // ─── Form ─────────────────────────────────────────
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Name
                              Text(
                                'Nama Panggilan',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1E1E1E),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _nameController,
                                textInputAction: TextInputAction.next,
                                decoration: _inputDecoration(
                                  hint: 'Misal: Budi',
                                  icon: Icons.person_outline_rounded,
                                  fillColor: fieldFill,
                                  isDark: isDark,
                                ),
                                validator: (value) {
                                  if ((value ?? '').trim().isEmpty) {
                                    return 'Nama belum diisi.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 18),

                              // Email
                              Text(
                                'Email',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1E1E1E),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                decoration: _inputDecoration(
                                  hint: 'budi@contoh.com',
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
                              const SizedBox(height: 18),

                              // Password
                              Text(
                                'Password',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1E1E1E),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.next,
                                decoration: _inputDecoration(
                                  hint: 'Minimal 6 karakter',
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
                                      () => _obscurePassword =
                                          !_obscurePassword,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if ((value ?? '').isEmpty) {
                                    return 'Kata sandi masih kosong.';
                                  }
                                  if ((value ?? '').length < 6) {
                                    return 'Kata sandi minimal 6 karakter ya.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 18),

                              // Confirm Password
                              Text(
                                'Konfirmasi Password',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1E1E1E),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _confirmPasswordController,
                                obscureText: _obscureConfirm,
                                textInputAction: TextInputAction.done,
                                decoration: _inputDecoration(
                                  hint: 'Ulangi kata sandi',
                                  icon: Icons.lock_outline_rounded,
                                  fillColor: fieldFill,
                                  isDark: isDark,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirm
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: isDark
                                          ? Colors.white54
                                          : const Color(0xFF9E9E9E),
                                    ),
                                    onPressed: () => setState(
                                      () =>
                                          _obscureConfirm = !_obscureConfirm,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if ((value ?? '').isEmpty) {
                                    return 'Konfirmasi kata sandi masih kosong.';
                                  }
                                  if (value != _passwordController.text) {
                                    return 'Kata sandi tidak sama.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 28),

                              // Swipe to register
                              SwipeButton(
                                label: 'Swipe untuk daftar',
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
                                'Sudah punya akun? ',
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
                                          const LoginScreen(),
                                      transitionDuration: Duration.zero,
                                    ),
                                  );
                                },
                                child: Text(
                                  'Masuk di sini',
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
                        const SizedBox(height: 16),
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
