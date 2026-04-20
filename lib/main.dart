import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import 'providers/transaction_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/auth_service.dart';
import 'services/home_balance_widget_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id', null);
  runApp(const UangKeluarApp());
}

class UangKeluarApp extends StatefulWidget {
  const UangKeluarApp({super.key});

  @override
  State<UangKeluarApp> createState() => _UangKeluarAppState();
}

class _UangKeluarAppState extends State<UangKeluarApp> {
  final _authService = AuthService();
  final _homeBalanceWidgetService = HomeBalanceWidgetService.instance;
  final _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<Uri?>? _widgetClickSubscription;

  Widget? _initialHome;

  @override
  void initState() {
    super.initState();
    _bootstrapInitialHome();
    _widgetClickSubscription = _homeBalanceWidgetService.widgetClickedStream
        .listen((uri) {
          _handleWidgetLaunchUri(uri);
        });
  }

  @override
  void dispose() {
    _widgetClickSubscription?.cancel();
    super.dispose();
  }

  Future<void> _bootstrapInitialHome() async {
    final initialUri = await _homeBalanceWidgetService.getInitialLaunchUri();
    final shouldOpenExpense = _homeBalanceWidgetService.isExpenseInputLaunchUri(
      initialUri,
    );
    final shouldOpenIncome = _homeBalanceWidgetService.isIncomeInputLaunchUri(
      initialUri,
    );
    final shouldToggleBalanceVisibility = _homeBalanceWidgetService
        .isToggleBalanceVisibilityLaunchUri(initialUri);

    if (shouldOpenExpense ||
        shouldOpenIncome ||
        shouldToggleBalanceVisibility) {
      final canSkipAuth = await _authService.shouldSkipAuth();
      if (canSkipAuth) {
        final userName = await _authService.getCurrentUserName();
        if (!mounted) return;
        setState(() {
          _initialHome = DashboardScreen(
            userName: userName,
            openExpenseOnStart: shouldOpenExpense,
            openIncomeOnStart: shouldOpenIncome,
            toggleBalanceVisibilityOnStart: shouldToggleBalanceVisibility,
          );
        });
        return;
      }
    }

    if (!mounted) return;
    setState(() => _initialHome = const OnboardingScreen());
  }

  Future<void> _handleWidgetLaunchUri(Uri? uri) async {
    final isExpense = _homeBalanceWidgetService.isExpenseInputLaunchUri(uri);
    final isIncome = _homeBalanceWidgetService.isIncomeInputLaunchUri(uri);
    final shouldToggleBalanceVisibility = _homeBalanceWidgetService
        .isToggleBalanceVisibilityLaunchUri(uri);
    if (!isExpense && !isIncome && !shouldToggleBalanceVisibility) return;

    final canSkipAuth = await _authService.shouldSkipAuth();
    if (!canSkipAuth) return;

    final userName = await _authService.getCurrentUserName();
    final navigator = _navigatorKey.currentState;
    if (navigator == null || !mounted) return;

    navigator.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => DashboardScreen(
          userName: userName,
          openExpenseOnStart: isExpense,
          openIncomeOnStart: isIncome,
          toggleBalanceVisibilityOnStart: shouldToggleBalanceVisibility,
        ),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    const borderColor = Color(0xFF121212);
    const cream = Color(0xFFF5F2E9);

    return ChangeNotifierProvider(
      create: (_) => TransactionProvider()..init(),
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'uangku',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'DMSans',
          scaffoldBackgroundColor: const Color(0xFFE6EBFA),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFEDD07D),
            surface: cream,
            brightness: Brightness.light,
          ),
          textTheme: const TextTheme().copyWith(
            headlineMedium: const TextStyle(
              fontFamily: 'DMSerifDisplay',
              fontSize: 32,
              color: borderColor,
              fontWeight: FontWeight.w400,
            ),
            titleLarge: const TextStyle(
              fontFamily: 'DMSerifDisplay',
              fontSize: 30,
              color: borderColor,
              fontWeight: FontWeight.w400,
            ),
            titleMedium: const TextStyle(
              fontFamily: 'DMSerifDisplay',
              fontSize: 24,
              color: borderColor,
            ),
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: cream,
            foregroundColor: borderColor,
            elevation: 0,
            scrolledUnderElevation: 0,
            titleTextStyle: const TextStyle(
              fontFamily: 'DMSerifDisplay',
              color: borderColor,
              fontSize: 34,
            ),
          ),
          cardTheme: CardThemeData(
            color: cream,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: borderColor, width: 1.8),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: borderColor, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: borderColor, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: borderColor, width: 1.8),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEDD07D),
              foregroundColor: borderColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: borderColor, width: 1.6),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
        ),
        home:
            _initialHome ??
            const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
    );
  }
}
