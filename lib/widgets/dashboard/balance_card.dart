import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_card.dart';
import 'dashboard_buttons.dart';

class BalanceCard extends StatelessWidget {
  const BalanceCard({
    super.key,
    required this.theme,
    required this.totalIncome,
    required this.totalExpense,
    required this.netBalance,
    required this.isBalanceHidden,
    required this.onToggleBalanceVisibility,
    required this.onAddIncome,
    required this.onAddExpense,
  });

  final ThemeData theme;
  final double totalIncome;
  final double totalExpense;
  final double netBalance;
  final bool isBalanceHidden;
  final VoidCallback onToggleBalanceVisibility;
  final VoidCallback onAddIncome;
  final VoidCallback onAddExpense;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      isInteractive: true,
      padding: const EdgeInsets.all(14),
      color: Theme.of(context).colorScheme.primaryContainer,
      onTap: () {
        // Toggle visibility maybe?
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Dompet Kamu',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                splashRadius: 18,
                onPressed: onToggleBalanceVisibility,
                icon: Icon(
                  isBalanceHidden
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  size: 18,
                ),
              ),
              const Icon(Icons.cloud_done_rounded, size: 16),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Saldo Kamu Sekarang',
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          AnimatedVisibilityCurrencyText(
            value: netBalance,
            isHidden: isBalanceHidden,
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 34,
              fontWeight: FontWeight.w700,
            ),
            childBuilder: (style) =>
                AnimatedNetBalanceText(value: netBalance, style: style),
          ),
          const SizedBox(height: 8),
          SummaryRow(
            label: 'Total Pemasukan',
            value: totalIncome,
            isHidden: isBalanceHidden,
          ),
          SummaryRow(
            label: 'Total Pengeluaran',
            value: totalExpense,
            labelColor: const Color(0xFFC24545),
            valueColor: const Color(0xFFC24545),
            isHidden: isBalanceHidden,
          ),
          SummaryRow(
            label: 'Selisih',
            value: netBalance,
            withSign: true,
            isHidden: isBalanceHidden,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ActionButton(
                  label: 'Pemasukan',
                  icon: Icons.south_west_rounded,
                  background: Theme.of(context).cardTheme.color ?? Colors.white,
                  iconBackground: const Color(0xFFA4DBB2),
                  onTap: onAddIncome,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ActionButton(
                  label: 'Pengeluaran',
                  icon: Icons.north_east_rounded,
                  background: const Color(0xFFF0C8C8),
                  iconBackground: const Color(0xFFC24545),
                  labelColor: const Color(0xFFC24545),
                  iconColor: Colors.white,
                  onTap: onAddExpense,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SummaryRow extends StatelessWidget {
  const SummaryRow({
    super.key,
    required this.label,
    required this.value,
    this.withSign = false,
    this.labelColor,
    this.valueColor,
    this.isHidden = false,
  });

  final String label;
  final double value;
  final bool withSign;
  final Color? labelColor;
  final Color? valueColor;
  final bool isHidden;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: labelColor),
          ),
          const Spacer(),
          AnimatedVisibilityCurrencyText(
            value: value,
            withSign: withSign,
            isHidden: isHidden,
            style: TextStyle(fontWeight: FontWeight.w700, color: valueColor),
          ),
        ],
      ),
    );
  }
}

class AnimatedNetBalanceText extends StatefulWidget {
  const AnimatedNetBalanceText({super.key, required this.value, required this.style});

  final double value;
  final TextStyle? style;

  @override
  State<AnimatedNetBalanceText> createState() =>
      _AnimatedNetBalanceTextState();
}

class _AnimatedNetBalanceTextState extends State<AnimatedNetBalanceText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant AnimatedNetBalanceText oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasNegative = oldWidget.value < 0;
    final isNegative = widget.value < 0;
    if (wasNegative != isNegative) {
      _syncPulse();
    }
  }

  void _syncPulse() {
    if (widget.value < 0) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
      return;
    }

    if (_pulseController.isAnimating) {
      _pulseController.stop();
    }
    _pulseController.animateTo(
      0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final baseColor =
            widget.style?.color ??
            Theme.of(context).textTheme.titleLarge?.color ??
            const Color(0xFF111111);
        const warningColor = Color(0xFFC24545);

        final t = widget.value < 0 ? _pulseController.value : 0.0;
        final animatedStyle = widget.style?.copyWith(
          color: Color.lerp(baseColor, warningColor, t),
        );

        return Transform.scale(
          alignment: Alignment.centerLeft,
          scale: 1 + (0.03 * t),
          child: AnimatedCurrencyText(
            value: widget.value,
            style: animatedStyle,
          ),
        );
      },
    );
  }
}

class AnimatedCurrencyText extends StatefulWidget {
  const AnimatedCurrencyText({
    super.key,
    required this.value,
    required this.style,
    this.withSign = false,
  });

  final double value;
  final TextStyle? style;
  final bool withSign;

  @override
  State<AnimatedCurrencyText> createState() => _AnimatedCurrencyTextState();
}

class _AnimatedCurrencyTextState extends State<AnimatedCurrencyText> {
  late double _fromValue;
  late double _toValue;

  @override
  void initState() {
    super.initState();
    _fromValue = widget.value;
    _toValue = widget.value;
  }

  @override
  void didUpdateWidget(covariant AnimatedCurrencyText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value == widget.value) return;
    _fromValue = _toValue;
    _toValue = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: _fromValue, end: _toValue),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) {
        return Text(
          _formatRupiah(animatedValue, withSign: widget.withSign),
          style: widget.style,
        );
      },
    );
  }

  String _formatRupiah(double value, {bool withSign = false}) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    final formatted = formatter.format(value.abs());

    if (withSign) {
      return '${value >= 0 ? '+' : '-'}$formatted';
    }

    if (value < 0) {
      return '-$formatted';
    }

    return formatted;
  }
}

class AnimatedVisibilityCurrencyText extends StatelessWidget {
  const AnimatedVisibilityCurrencyText({
    super.key,
    required this.value,
    required this.style,
    this.withSign = false,
    this.isHidden = false,
    this.childBuilder,
  });

  final double value;
  final TextStyle? style;
  final bool withSign;
  final bool isHidden;
  final Widget Function(TextStyle? style)? childBuilder;

  @override
  Widget build(BuildContext context) {
    final visibleChild =
        childBuilder?.call(style) ??
        AnimatedCurrencyText(value: value, style: style, withSign: withSign);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.08),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: isHidden
          ? Text(
              'Rp ••••••',
              key: const ValueKey('currency-hidden'),
              style: style,
            )
          : KeyedSubtree(
              key: const ValueKey('currency-visible'),
              child: visibleChild,
            ),
    );
  }
}
