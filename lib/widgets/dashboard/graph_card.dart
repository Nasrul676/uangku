import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/finance_transaction.dart';
import '../../theme/app_theme.dart';
import '../app_card.dart';
import 'dashboard_buttons.dart';

class ChartDetail {
  const ChartDetail({required this.dayLabel, required this.amount});

  final String dayLabel;
  final double amount;
}

class BarData {
  const BarData(this.heightFactor, this.color, this.dayLabel, this.amount);

  final double heightFactor;
  final Color color;
  final String dayLabel;
  final double amount;
}

class Bar extends StatefulWidget {
  const Bar({super.key, required this.data, required this.selected, required this.onTap});

  final BarData data;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<Bar> createState() => _BarState();
}

class _BarState extends State<Bar> {
  late double _fromFactor;
  late double _toFactor;

  @override
  void initState() {
    super.initState();
    _fromFactor = widget.data.heightFactor;
    _toFactor = widget.data.heightFactor;
  }

  @override
  void didUpdateWidget(covariant Bar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.heightFactor == widget.data.heightFactor) return;
    _fromFactor = _toFactor;
    _toFactor = widget.data.heightFactor;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: widget.onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: _fromFactor, end: _toFactor),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                builder: (context, animatedFactor, child) {
                  return FractionallySizedBox(
                    heightFactor: animatedFactor,
                    child: Container(
                      decoration: BoxDecoration(
                        color: widget.data.color,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: widget.selected
                              ? const Color(0xFF1F5A62)
                              : const Color(0xFF111111),
                          width: widget.selected ? 1.8 : 1.2,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            widget.data.dayLabel,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: widget.selected
                  ? const Color(0xFF1F5A62)
                  : (Theme.of(context).brightness == Brightness.dark
                        ? Colors.white70
                        : const Color(0xFF3B3B55)),
            ),
          ),
        ],
      ),
    );
  }
}

class GraphCard extends StatelessWidget {
  const GraphCard({
    super.key,
    required this.theme,
    required this.transactions,
    required this.selectedType,
    required this.selectedRangeDays,
    required this.selectedDetail,
    required this.onSelectType,
    required this.onSelectRangeDays,
    required this.onBarTap,
  });

  final ThemeData theme;
  final List<FinanceTransaction> transactions;
  final String selectedType;
  final int selectedRangeDays;
  final ChartDetail? selectedDetail;
  final ValueChanged<String> onSelectType;
  final ValueChanged<int> onSelectRangeDays;
  final ValueChanged<ChartDetail> onBarTap;

  @override
  Widget build(BuildContext context) {
    final bars = _buildBars();

    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            child: Row(
              children: [
                CircleIconButton(
                  icon: Icons.show_chart_rounded,
                  onTap: () {},
                ),
                const SizedBox(width: 8),
                FilterButton(
                  label: '1',
                  selected: selectedRangeDays == 1,
                  onTap: () => onSelectRangeDays(1),
                ),
                const SizedBox(width: 6),
                FilterButton(
                  label: '3',
                  selected: selectedRangeDays == 3,
                  onTap: () => onSelectRangeDays(3),
                ),
                const SizedBox(width: 6),
                FilterButton(
                  label: '7',
                  selected: selectedRangeDays == 7,
                  onTap: () => onSelectRangeDays(7),
                ),
                const SizedBox(width: 6),
                FilterButton(
                  label: '30',
                  selected: selectedRangeDays == 30,
                  onTap: () => onSelectRangeDays(30),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 1,
                  height: 28,
                  color:
                      (Theme.of(context)
                          .extension<AppThemeExtension>()
                          ?.cardBorder
                          ?.top
                          .color ??
                      const Color(0xFF2D2D2D)),
                ),
                const SizedBox(width: 10),
                IconFilterButton(
                  icon: Icons.north_east_rounded,
                  selected: selectedType == 'EXPENSE',
                  selectedColor: const Color(0xFFF0C8C8),
                  iconColor: const Color(0xFFC24545),
                  onTap: () => onSelectType('EXPENSE'),
                ),
                const SizedBox(width: 6),
                IconFilterButton(
                  icon: Icons.south_west_rounded,
                  selected: selectedType == 'INCOME',
                  onTap: () => onSelectType('INCOME'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 110,
            child: bars.isEmpty
                ? Center(
                    child: Text(
                      'Belum ada transaksi di rentang waktu ini.',
                      style: theme.textTheme.bodySmall,
                    ),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    itemCount: bars.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      final width = selectedRangeDays >= 30 ? 34.0 : 42.0;
                      final bar = bars[index];
                      final isSelected =
                          selectedDetail?.dayLabel == bar.dayLabel &&
                          selectedDetail?.amount == bar.amount;
                      return SizedBox(
                        width: width,
                        child: Bar(
                          data: bar,
                          selected: isSelected,
                          onTap: () => onBarTap(
                            ChartDetail(
                              dayLabel: bar.dayLabel,
                              amount: bar.amount,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
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
            child: selectedDetail == null
                ? const SizedBox(key: ValueKey('empty-detail'))
                : Container(
                    key: ValueKey(
                      '${selectedDetail!.dayLabel}-${selectedDetail!.amount}',
                    ),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color:
                            (Theme.of(context)
                                .extension<AppThemeExtension>()
                                ?.cardBorder
                                ?.top
                                .color ??
                            const Color(0xFF2D2D2D)),
                        width: 1.1,
                      ),
                    ),
                    child: Text(
                      '${selectedDetail!.dayLabel} • ${_formatRupiah(selectedDetail!.amount)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2D2D2D),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  List<BarData> _buildBars() {
    const expenseColors = [
      Color(0xFFF7CACA),
      Color(0xFFF3B1B1),
      Color(0xFFEC9090),
      Color(0xFFE37979),
      Color(0xFFD96565),
      Color(0xFFC24545),
      Color(0xFFA13A3A),
    ];
    const incomeColors = [
      Color(0xFFBEE7C8),
      Color(0xFFA4DBB2),
      Color(0xFF93D5A1),
      Color(0xFF85C793),
      Color(0xFF74B886),
      Color(0xFF63A879),
      Color(0xFF55986D),
    ];
    final colors = selectedType == 'EXPENSE' ? expenseColors : incomeColors;

    final filteredDates = transactions
        .where((tx) => tx.type == selectedType)
        .map((tx) => DateTime.tryParse(tx.date))
        .whereType<DateTime>()
        .map((date) => DateTime(date.year, date.month, date.day))
        .toList(growable: false);

    if (filteredDates.isEmpty) return [];

    final now = DateTime.now();
    final latestTxDate = filteredDates.reduce((a, b) => a.isAfter(b) ? a : b);
    final anchorDate = latestTxDate.isAfter(now)
        ? latestTxDate
        : DateTime(now.year, now.month, now.day);

    final days = List.generate(
      selectedRangeDays,
      (index) => DateTime(
        anchorDate.year,
        anchorDate.month,
        anchorDate.day - ((selectedRangeDays - 1) - index),
      ),
    );

    final amountByDay = <String, double>{
      for (final day in days) DateFormat('yyyy-MM-dd').format(day): 0,
    };

    for (final tx in transactions) {
      if (tx.type != selectedType) continue;
      final parsed = DateTime.tryParse(tx.date);
      if (parsed == null) continue;
      final key = DateFormat(
        'yyyy-MM-dd',
      ).format(DateTime(parsed.year, parsed.month, parsed.day));
      if (!amountByDay.containsKey(key)) continue;
      amountByDay[key] = (amountByDay[key] ?? 0) + tx.amount;
    }

    final activeEntries = days
        .map(
          (day) => MapEntry(
            day,
            amountByDay[DateFormat('yyyy-MM-dd').format(day)] ?? 0,
          ),
        )
        .where((entry) => entry.value > 0)
        .toList();

    if (activeEntries.isEmpty) return [];

    final maxValue = activeEntries.fold<double>(
      0,
      (max, entry) => entry.value > max ? entry.value : max,
    );

    return List.generate(activeEntries.length, (index) {
      final entry = activeEntries[index];
      final factor = (entry.value / maxValue).clamp(0.02, 1.0);
      return BarData(
        factor,
        colors[index % colors.length],
        DateFormat('d MMM', 'id').format(entry.key),
        entry.value,
      );
    });
  }

  String _formatRupiah(double value) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(value);
  }
}
