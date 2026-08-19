import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/models.dart';
import '../../l10n/strings.dart';
import '../../state/providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.g.dart';

/// Full food page: today's meals (with totals + delete) and an add-meal entry.
class FoodScreen extends ConsumerWidget {
  const FoodScreen({super.key});

  String _slotLabel(KbStrings t, String slot) => switch (slot) {
        'breakfast' => t.slotBreakfast,
        'lunch' => t.slotLunch,
        'dinner' => t.slotDinner,
        _ => t.slotSnack,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = KbStrings.of(context);
    final home = ref.watch(homeProvider);
    return Scaffold(
      backgroundColor: KbTokens.surfaceColor,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 72),
        child: FloatingActionButton.extended(
          backgroundColor: KbTokens.inkColor,
          onPressed: () => context.push('/add-meal'),
          icon: const Icon(Icons.add, color: KbTokens.limeColor),
          label: Text(t.addMeal, style: AppTheme.heading().copyWith(color: Colors.white)),
        ),
      ),
      body: SafeArea(
        child: home.when(
          loading: () => const Center(child: CircularProgressIndicator(color: KbTokens.inkColor)),
          error: (e, _) => Center(child: Text('$e', style: AppTheme.caption())),
          data: (h) => RefreshIndicator(
            color: KbTokens.inkColor,
            onRefresh: () async => ref.invalidate(homeProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
              children: [
                Text(t.food, style: AppTheme.title()),
                const SizedBox(height: 6),
                Text('${h.kcalEaten} / ${h.kcalGoal} kcal · ${t.protein} ${h.proteinG.round()}g',
                    style: AppTheme.body(color: KbTokens.inkSoftColor)),
                const SizedBox(height: 18),
                if (h.meals.isEmpty)
                  _EmptyMeals(t: t)
                else
                  ...h.meals.map((m) => _MealCard(
                        meal: m,
                        slotLabel: _slotLabel(t, m.slot),
                        onDelete: () => _confirmDelete(context, ref, t, m),
                        onTap: () => context.push('/edit-meal', extra: m),
                      )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, KbStrings t, Meal m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KbTokens.surfaceColor,
        title: Text(t.deleteMealQ, style: AppTheme.heading()),
        content: Text(m.title.isEmpty ? _slotLabel(t, m.slot) : m.title, style: AppTheme.body()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.cancel, style: AppTheme.label())),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: KbTokens.dangerColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.delete, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await ref.read(apiClientProvider).deleteMeal(m.id);
        ref.invalidate(homeProvider);
      } catch (_) {}
    }
  }
}

class _EmptyMeals extends StatelessWidget {
  const _EmptyMeals({required this.t});
  final KbStrings t;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 40),
        padding: const EdgeInsets.all(28),
        decoration: const BoxDecoration(color: KbTokens.cardColor, borderRadius: AppTheme.cardRadius),
        child: Column(
          children: [
            const Icon(Icons.restaurant_rounded, size: 40, color: KbTokens.inkFaintColor),
            const SizedBox(height: 12),
            Text(t.noMealsYet, style: AppTheme.heading(), textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(t.noMealsSub, style: AppTheme.caption(color: KbTokens.inkSoftColor), textAlign: TextAlign.center),
          ],
        ),
      );
}

class _MealCard extends StatelessWidget {
  const _MealCard({required this.meal, required this.slotLabel, required this.onDelete, required this.onTap});
  final Meal meal;
  final String slotLabel;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(meal.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: const BoxDecoration(color: KbTokens.dangerColor, borderRadius: AppTheme.cardRadius),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false; // deletion handled via dialog + provider invalidate
      },
      child: GestureDetector(
        onTap: onTap,
        child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(color: KbTokens.cardColor, borderRadius: AppTheme.cardRadius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(meal.title.isEmpty ? slotLabel : meal.title, style: AppTheme.heading()),
                      Text('$slotLabel · ${meal.items.isNotEmpty ? '${meal.items.length} items' : ''}',
                          style: AppTheme.caption(color: KbTokens.inkSoftColor)),
                    ],
                  ),
                ),
                Text('${meal.kcal}', style: AppTheme.title()),
              ],
            ),
            if (meal.items.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...meal.items.map((it) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Expanded(child: Text('${it.name} · ${it.grams.round()}g', style: AppTheme.caption())),
                        Text('${it.kcal}', style: AppTheme.caption(color: KbTokens.inkSoftColor)),
                      ],
                    ),
                  )),
            ],
          ],
        ),
        ),
      ),
    );
  }
}
