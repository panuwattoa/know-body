import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/strings.dart';
import '../../state/providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.g.dart';
import '../../widgets/calorie_ring.dart';

/// Onboarding step 3: show the computed calorie + macro target.
class CalorieResultScreen extends ConsumerWidget {
  const CalorieResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = KbStrings.of(context);
    final calc = ref.watch(lastCalcProvider);
    if (calc == null) {
      // no data (deep-linked) — skip ahead
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/name-pet'));
      return const SizedBox.shrink();
    }
    return Scaffold(
      backgroundColor: KbTokens.surfaceColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Text(t.calcTitle, style: AppTheme.display(), textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Text(t.calcSub, style: AppTheme.body(color: KbTokens.inkSoftColor), textAlign: TextAlign.center),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(color: KbTokens.limeColor, borderRadius: AppTheme.heroRadius),
                child: Column(
                  children: [
                    CalorieRing(kcalLeft: calc.kcal, pct: 0, label: t.kcalLeft, size: 168, stroke: 18),
                    const SizedBox(height: 6),
                    Text('${t.kcalLeft} · ${t.perDay}', style: AppTheme.label(color: KbTokens.inkSoftColor)),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _Macro(g: calc.proteinG, label: t.protein),
                        _Macro(g: calc.carbsG, label: t.carbs),
                        _Macro(g: calc.fatG, label: t.fat),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text('${t.maintenanceIs} ${calc.tdee} kcal', style: AppTheme.caption(color: KbTokens.inkSoftColor)),
              const Spacer(),
              GestureDetector(
                onTap: () => context.go('/name-pet'),
                child: Container(
                  height: 58,
                  width: double.infinity,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: KbTokens.inkColor, borderRadius: BorderRadius.circular(KbTokens.radiusPill)),
                  child: Text(t.cont, style: AppTheme.heading().copyWith(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Macro extends StatelessWidget {
  const _Macro({required this.g, required this.label});
  final int g;
  final String label;
  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text('${g}g', style: AppTheme.title()),
          Text(label, style: AppTheme.caption(color: KbTokens.inkSoftColor)),
        ],
      );
}
