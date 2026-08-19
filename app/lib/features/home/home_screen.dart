import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/models.dart';
import '../../auth/auth.dart';
import '../../l10n/strings.dart';
import '../../services/prefs.dart';
import '../../state/providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.g.dart';
import '../../widgets/calorie_ring.dart';
import '../../widgets/mochi.dart';
import '../shell/tab_scaffold.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = KbStrings.of(context);
    final home = ref.watch(homeProvider);

    return Scaffold(
      backgroundColor: KbTokens.surfaceColor,
      body: SafeArea(
        bottom: false,
        child: home.when(
          loading: () => const Center(child: CircularProgressIndicator(color: KbTokens.inkColor)),
          error: (e, _) => _ErrorState(message: '$e', onRetry: () => ref.invalidate(homeProvider)),
          data: (h) => RefreshIndicator(
            onRefresh: () async => ref.invalidate(homeProvider),
            color: KbTokens.inkColor,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, kNavClearance),
              children: [
                _Header(streak: h.streak.count, t: t),
                const SizedBox(height: 16),
                _CalorieCard(home: h, t: t),
                const SizedBox(height: 14),
                _YesterdayCard(y: h.yesterday, t: t),
                if (h.suggestion.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _SuggestionCard(title: h.suggestion, t: t),
                ],
                const SizedBox(height: 20),
                Text(t.todaysMeals, style: AppTheme.heading()),
                const SizedBox(height: 10),
                ...h.meals.map((m) => _MealTile(meal: m)),
                _AddDinnerTile(label: t.addDinner, onTap: () => context.push('/add-meal')),
                const SizedBox(height: 16),
                _PetCard(pet: h.pet, streak: h.streak, t: t),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.streak, required this.t});
  final int streak;
  final KbStrings t;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.greeting('KnowBody'), style: AppTheme.title()),
              const SizedBox(height: 3),
              GestureDetector(
                onTap: () => context.push('/streaks'),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('🔥 ${t.streakDays(streak)}', style: AppTheme.label()),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, size: 16, color: KbTokens.inkSoftColor),
                ]),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => context.push('/share'),
          icon: const Icon(Icons.ios_share, color: KbTokens.inkColor),
        ),
        GestureDetector(
          onTap: () => _accountSheet(context, t),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFD9D9D2),
              shape: BoxShape.circle,
              border: Border.all(color: KbTokens.limeColor, width: 2),
            ),
            child: const Icon(Icons.person, size: 20, color: KbTokens.inkColor),
          ),
        ),
      ],
    );
  }

  void _accountSheet(BuildContext context, KbStrings t) {
    if (!AuthConfig.enabled) return; // no account in dev mode
    showModalBottomSheet(
      context: context,
      backgroundColor: KbTokens.surfaceColor,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.logout, color: KbTokens.dangerColor),
            title: Text(t.signOut, style: AppTheme.body()),
            onTap: () async {
              Navigator.pop(ctx);
              await Prefs.setOnboarded(false);
              await Auth.signOut();
            },
          ),
        ]),
      ),
    );
  }
}

class _YesterdayCard extends StatelessWidget {
  const _YesterdayCard({required this.y, required this.t});
  final DaySummary y;
  final KbStrings t;
  @override
  Widget build(BuildContext context) {
    final String msg;
    if (!y.hasData) {
      msg = t.noDataYest;
    } else if (y.onTarget) {
      msg = t.onTargetYest;
    } else if (y.kcalEaten > y.kcalGoal) {
      msg = t.overYest;
    } else {
      msg = t.underYest;
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(color: KbTokens.cardColor, borderRadius: AppTheme.cardRadius),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: KbTokens.limePaleColor, borderRadius: BorderRadius.circular(13)),
            child: const Icon(Icons.history, color: KbTokens.inkColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(t.yesterday, style: AppTheme.heading()),
                  if (y.workedOut) ...[const SizedBox(width: 8), Text(t.didWorkout, style: AppTheme.caption(color: KbTokens.accentTextColor))],
                ]),
                Text(y.hasData ? '${y.kcalEaten} / ${y.kcalGoal} kcal · $msg' : msg,
                    style: AppTheme.caption(color: KbTokens.inkSoftColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.title, required this.t});
  final String title;
  final KbStrings t;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/move'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(color: KbTokens.inkColor, borderRadius: AppTheme.cardRadius),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(color: const Color(0x22D8FB4F), borderRadius: BorderRadius.circular(13)),
              child: const Icon(Icons.bolt, color: KbTokens.limeColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.todaySuggestion, style: AppTheme.caption(color: KbTokens.onDarkSoftColor)),
                  Text(title, style: AppTheme.heading().copyWith(color: Colors.white)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: KbTokens.limeColor, borderRadius: BorderRadius.circular(12)),
              child: Text(t.startSuggested, style: AppTheme.label(color: KbTokens.inkColor).copyWith(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalorieCard extends StatelessWidget {
  const _CalorieCard({required this.home, required this.t});
  final Home home;
  final KbStrings t;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: const BoxDecoration(color: KbTokens.limeColor, borderRadius: AppTheme.heroRadius),
      child: Column(
        children: [
          Row(
            children: [
              CalorieRing(kcalLeft: home.kcalLeft, pct: home.ringPct, label: t.kcalLeft),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.eatenToday, style: AppTheme.label(color: KbTokens.inkSoftColor)),
                    const SizedBox(height: 2),
                    Text.rich(TextSpan(children: [
                      TextSpan(text: '${home.kcalEaten} ', style: AppTheme.title()),
                      TextSpan(
                          text: '${t.ofWord} ${home.kcalGoal} · ${t.burned(home.kcalBurned)}',
                          style: AppTheme.label()),
                    ])),
                    const SizedBox(height: 14),
                    _Macros(home: home, t: t),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _PrimaryButton(
                  icon: Icons.photo_camera_outlined,
                  label: t.snapMeal,
                  onTap: () => context.push('/add-meal'),
                ),
              ),
              const SizedBox(width: 10),
              _GhostButton(label: t.quickAdd, onTap: () => context.push('/add-meal')),
            ],
          ),
        ],
      ),
    );
  }
}

class _Macros extends StatelessWidget {
  const _Macros({required this.home, required this.t});
  final Home home;
  final KbStrings t;
  @override
  Widget build(BuildContext context) {
    Widget bar(String g, String name, Color c) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(g, style: AppTheme.label(color: KbTokens.inkColor).copyWith(fontWeight: FontWeight.w600)),
              Container(
                height: 5,
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)),
              ),
              Text(name, style: AppTheme.caption(color: KbTokens.inkSoftColor)),
            ],
          ),
        );
    return Row(
      children: [
        bar('${home.proteinG.round()}g', t.protein, KbTokens.inkColor),
        const SizedBox(width: 12),
        bar('${home.carbsG.round()}g', t.carbs, const Color(0x80121212)),
        const SizedBox(width: 12),
        bar('${home.fatG.round()}g', t.fat, const Color(0x47121212)),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(color: KbTokens.inkColor, borderRadius: BorderRadius.circular(KbTokens.radiusButton)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: KbTokens.limeColor, size: 20),
            const SizedBox(width: 8),
            Text(label, style: AppTheme.heading().copyWith(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({required this.label, this.onTap});
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: const Color(0x99FFFFFF), borderRadius: BorderRadius.circular(KbTokens.radiusButton)),
        child: Text(label, style: AppTheme.heading()),
      ),
    );
  }
}

class _MealTile extends StatelessWidget {
  const _MealTile({required this.meal});
  final Meal meal;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: KbTokens.cardColor, borderRadius: BorderRadius.circular(KbTokens.radiusCardLg)),
      child: Row(
        children: [
          Container(width: 54, height: 54, decoration: BoxDecoration(color: const Color(0xFFE8E4D8), borderRadius: BorderRadius.circular(16))),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(meal.title.isEmpty ? meal.slot : meal.title, style: AppTheme.heading()),
                const SizedBox(height: 2),
                Text('${_slotLabel(meal.slot)} · ${_time(meal.eatenAt)}', style: AppTheme.caption()),
              ],
            ),
          ),
          Text('${meal.kcal}', style: AppTheme.heading()),
        ],
      ),
    );
  }

  static String _slotLabel(String s) => s[0].toUpperCase() + s.substring(1);
  static String _time(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _AddDinnerTile extends StatelessWidget {
  const _AddDinnerTile({required this.label, this.onTap});
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(15),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(KbTokens.radiusCardLg),
          border: Border.all(color: const Color(0x2E121212), width: 1.5, style: BorderStyle.solid),
        ),
        child: Text(label, style: AppTheme.label(color: const Color(0x73121212)).copyWith(fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _PetCard extends StatelessWidget {
  const _PetCard({required this.pet, required this.streak, required this.t});
  final Pet pet;
  final Streak streak;
  final KbStrings t;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(color: KbTokens.darkColor, borderRadius: AppTheme.heroRadius),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(radius: 16, backgroundColor: KbTokens.limeColor, child: Text('${pet.level}', style: AppTheme.heading())),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${pet.name} · ${t.petLevel(pet.level)}', style: AppTheme.heading().copyWith(color: Colors.white)),
                    Text('${pet.xp} / ${pet.xpMax} XP', style: AppTheme.caption(color: KbTokens.onDarkSoftColor)),
                  ],
                ),
              ),
              _chip('🔥 ${streak.count}'),
              const SizedBox(width: 6),
              _chip('❄ ${streak.freezesLeft}'),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pet.xpPct,
              minHeight: 6,
              backgroundColor: const Color(0x1FFFFFFF),
              valueColor: const AlwaysStoppedAnimation(KbTokens.limeColor),
            ),
          ),
          const SizedBox(height: 8),
          AnimatedMochi(size: 132, mood: pet.mood),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _PrimaryButton(icon: Icons.favorite_border, label: t.feed, onTap: () => context.push('/add-meal'))),
              const SizedBox(width: 9),
              _GhostDark(label: t.play, onTap: () => context.go('/move')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String s) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(color: const Color(0x1AFFFFFF), borderRadius: BorderRadius.circular(12)),
        child: Text(s, style: AppTheme.label(color: Colors.white).copyWith(fontWeight: FontWeight.w600)),
      );
}

class _GhostDark extends StatelessWidget {
  const _GhostDark({required this.label, this.onTap});
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: const Color(0x1FFFFFFF), borderRadius: BorderRadius.circular(KbTokens.radiusButton)),
          child: Text(label, style: AppTheme.heading().copyWith(color: Colors.white)),
        ),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Couldn't reach KnowBody", style: AppTheme.heading()),
              const SizedBox(height: 8),
              Text(message, style: AppTheme.caption(), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onRetry,
                style: FilledButton.styleFrom(backgroundColor: KbTokens.inkColor),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
}
