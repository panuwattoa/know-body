import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/strings.dart';
import '../../state/providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.g.dart';

/// Onboarding: pick one goal. Maps to the API's goal enum and a starting kcal goal.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _selected = 0;

  static const _goals = ['eat_better', 'move_more', 'keep_pet_happy'];

  @override
  Widget build(BuildContext context) {
    final t = KbStrings.of(context);
    final options = [
      (t.goalEat, t.goalEatSub, Icons.eco_outlined),
      (t.goalMove, t.goalMoveSub, Icons.fitness_center),
      (t.goalPet, t.goalPetSub, Icons.pets_outlined),
    ];

    return Scaffold(
      backgroundColor: KbTokens.surfaceColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 34),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ...List.generate(3, (i) => Container(
                        width: 26,
                        height: 4,
                        margin: const EdgeInsets.only(right: 5),
                        decoration: BoxDecoration(
                          color: i == 0 ? KbTokens.inkColor : const Color(0x26121212),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      )),
                  const Spacer(),
                  Text('Skip', style: AppTheme.label()),
                ],
              ),
              const SizedBox(height: 34),
              Text(t.onbTitle, style: AppTheme.display()),
              const SizedBox(height: 12),
              Text(t.onbSubtitle, style: AppTheme.body(color: KbTokens.inkSoftColor)),
              const SizedBox(height: 26),
              for (var i = 0; i < options.length; i++) ...[
                _GoalTile(
                  title: options[i].$1,
                  sub: options[i].$2,
                  icon: options[i].$3,
                  selected: _selected == i,
                  onTap: () => setState(() => _selected = i),
                ),
                const SizedBox(height: 12),
              ],
              const Spacer(),
              GestureDetector(
                onTap: () => _continue(t),
                child: Container(
                  height: 58,
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

  void _continue(KbStrings t) {
    ref.read(onboardingGoalProvider.notifier).state = _goals[_selected];
    context.go('/setup'); // collect body metrics → compute calories
  }
}

class _GoalTile extends StatelessWidget {
  const _GoalTile({required this.title, required this.sub, required this.icon, required this.selected, required this.onTap});
  final String title, sub;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: selected ? KbTokens.limeColor : KbTokens.cardColor,
          borderRadius: BorderRadius.circular(KbTokens.radiusCard),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected ? KbTokens.inkColor : const Color(0xFFF1F1EC),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 22, color: selected ? KbTokens.limeColor : KbTokens.inkColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTheme.heading()),
                  const SizedBox(height: 2),
                  Text(sub, style: AppTheme.caption(color: KbTokens.inkSoftColor)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
