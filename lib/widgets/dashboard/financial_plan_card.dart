import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:flutter_slidable/flutter_slidable.dart';

import '../../models/financial_plan.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/skeleton_loader.dart';

class FinancialPlanCard extends StatelessWidget {
  const FinancialPlanCard({
    super.key,
    required this.theme,
    required this.plans,
    required this.isLoading,
    required this.realizationByPlan,
    required this.isSaving,
    required this.planBudget,
    required this.onAddPlan,
    required this.onEditPlan,
    required this.onDeletePlan,
    required this.onEditBudget,
    required this.canEditBudget,
  });

  final ThemeData theme;
  final List<FinancialPlan> plans;
  final bool isLoading;
  final Map<int, double> realizationByPlan;
  final bool isSaving;
  final double planBudget;
  final Future<void> Function() onAddPlan;
  final Future<void> Function(FinancialPlan plan) onEditPlan;
  final Future<void> Function(int id) onDeletePlan;
  final VoidCallback onEditBudget;
  final bool canEditBudget;

  @override
  Widget build(BuildContext context) {
    final addButton = SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: isSaving ? null : onAddPlan,
        icon: Icon(
          isSaving ? Icons.hourglass_top_rounded : Icons.add_box_rounded,
          color: AppTheme.incomeGreen,
        ),
        label: Text(
          isSaving ? 'Tunggu Sebentar...' : 'Buat Rencana Baru',
          style: const TextStyle(color: AppTheme.incomeGreen),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          side: const BorderSide(color: AppTheme.incomeGreen),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isLoading)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: SkeletonLoader(itemCount: 3, itemHeight: 80),
              ),
            )
          else if (plans.isEmpty)
            Expanded(
              child: EmptyState(
                title: 'Belum ada data',
                subtitle: 'Belum ada rencana keuangan.',
                ctaLabel: isSaving ? 'Tunggu Sebentar...' : 'Buat Rencana Baru',
                onCtaTap: isSaving ? null : onAddPlan,
              ),
            )
          else
            Expanded(
              child: Column(
                children: [
                  FinancialPlanSummaryCard(
                    theme: theme,
                    plans: plans,
                    realizationByPlan: realizationByPlan,
                    planBudget: planBudget,
                    onEditBudget: onEditBudget,
                    canEditBudget: canEditBudget,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 100),
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      children: [
                        addButton,
                        const SizedBox(height: 12),
                        ...(() {
                          final sortedPlans = List<FinancialPlan>.from(plans)..sort((a, b) {
                            final realizedA = realizationByPlan[a.id] ?? 0;
                            final progressA = a.targetAmount <= 0
                                ? 0.0
                                : (realizedA / a.targetAmount).clamp(0.0, 1.0).toDouble();
                            final realizedB = realizationByPlan[b.id] ?? 0;
                            final progressB = b.targetAmount <= 0
                                ? 0.0
                                : (realizedB / b.targetAmount).clamp(0.0, 1.0).toDouble();
                            return progressA.compareTo(progressB);
                          });
                          return sortedPlans;
                        })().map((plan) {
                          final planId = plan.id;
                          if (planId == null) {
                            return const SizedBox.shrink();
                          }
                          final realized = realizationByPlan[planId] ?? 0;
                          final progress = plan.targetAmount <= 0
                              ? 0.0
                              : (realized / plan.targetAmount)
                                    .clamp(0.0, 1.0)
                                    .toDouble();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: FinancialPlanTile(
                              plan: plan,
                              progress: progress,
                              realizationAmount: realized,
                              onEdit: () => onEditPlan(plan),
                              onDelete: () => onDeletePlan(planId),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class FinancialPlanSummaryCard extends StatelessWidget {
  const FinancialPlanSummaryCard({
    super.key,
    required this.theme,
    required this.plans,
    required this.realizationByPlan,
    required this.planBudget,
    required this.onEditBudget,
    required this.canEditBudget,
  });

  final ThemeData theme;
  final List<FinancialPlan> plans;
  final Map<int, double> realizationByPlan;
  final double planBudget;
  final VoidCallback onEditBudget;
  final bool canEditBudget;

  @override
  Widget build(BuildContext context) {
    double totalTarget = 0;
    double totalRealization = 0;

    for (final plan in plans) {
      final planId = plan.id;
      if (planId == null) continue;
      totalTarget += plan.targetAmount;
      totalRealization += realizationByPlan[planId] ?? 0;
    }

    final percentageText = totalTarget > 0
        ? '${((totalRealization / totalTarget) * 100).toStringAsFixed(0)}%'
        : '0%';

    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Slidable(
      key: const ValueKey('summary-card'),
      endActionPane: canEditBudget ? ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => onEditBudget(),
            backgroundColor: const Color(0xFF6CC185),
            foregroundColor: Colors.white,
            icon: Icons.edit_rounded,
            label: 'Edit',
            borderRadius: BorderRadius.circular(12),
          ),
        ],
      ) : null,
      child: AppCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.calculate_rounded,
                size: 20,
                color: Theme.of(context).colorScheme.onSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Ringkasan',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Budget: ${formatter.format(planBudget)}',
                            style: theme.textTheme.bodySmall,
                          ),
                          Text(
                            'Target: ${formatter.format(totalTarget)}',
                            style: theme.textTheme.bodySmall,
                          ),
                          Row(
                            children: [
                              Text(
                                'Selisih: ',
                                style: theme.textTheme.bodySmall,
                              ),
                              Expanded(
                                child: Text(
                                  formatter.format(planBudget - totalTarget),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: (planBudget - totalTarget) < 0
                                        ? const Color(0xFFC24545)
                                        : null,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Realisasi: ${formatter.format(totalRealization)}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          percentageText,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color:
                                Theme.of(
                                      context,
                                    ).colorScheme.primary.computeLuminance() >
                                    0.6
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(context).colorScheme.primary,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ));
  }
}

class FinancialPlanTile extends StatelessWidget {
  const FinancialPlanTile({
    super.key,
    required this.plan,
    required this.progress,
    required this.realizationAmount,
    required this.onEdit,
    required this.onDelete,
  });

  final FinancialPlan plan;
  final double progress;
  final double realizationAmount;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(plan.targetDate);
    final dateText = date == null
        ? plan.targetDate
        : DateFormat('dd MMM yyyy', 'id').format(date);
    final amountText = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(plan.targetAmount);
    final cappedRealization = realizationAmount.clamp(0, plan.targetAmount);
    final progressText = '${(progress * 100).toStringAsFixed(0)}%';
    final realizationText = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(cappedRealization);

    return Slidable(
      key: ValueKey(plan.id ?? plan.hashCode),
      startActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => onEdit(),
            backgroundColor: const Color(0xFF6CC185),
            foregroundColor: Colors.white,
            icon: Icons.edit_rounded,
            label: 'Edit',
            borderRadius: BorderRadius.circular(12),
          ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: const Color(0xFFE57373),
            foregroundColor: Colors.white,
            icon: Icons.delete_rounded,
            label: 'Hapus',
            borderRadius: BorderRadius.circular(12),
          ),
        ],
      ),
      child: AppCard(
        padding: const EdgeInsets.all(10),
        color: Theme.of(context).cardTheme.color ?? Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Theme.of(context).extension<AppThemeExtension>()?.cardBorder,
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
                border: Theme.of(
                  context,
                ).extension<AppThemeExtension>()?.cardBorder,
              ),
              child: const Icon(Icons.flag_rounded, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    plan.category != null
                        ? '${plan.category} • Target $dateText • $amountText'
                        : 'Target $dateText • $amountText',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0, end: progress),
                            duration: const Duration(milliseconds: 1000),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, _) =>
                                LinearProgressIndicator(
                                  minHeight: 6,
                                  value: value,
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.surface,
                                  color: const Color(0xFF1F5A62),
                                ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        progressText,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Realisasi: $realizationText',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
