import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/models.dart';
import '../../l10n/strings.dart';
import '../../state/providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.g.dart';
import '../shell/tab_scaffold.dart';

/// Move tab: an AI-personalized workout program (from the user's data + target
/// date) plus custom workouts. Tapping a workout opens the runner.
class MoveScreen extends ConsumerWidget {
  const MoveScreen({super.key});

  Future<void> _regenerate(WidgetRef ref) async {
    try {
      await ref.read(apiClientProvider).workoutProgram(regenerate: true);
      ref.invalidate(workoutProgramProvider);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = KbStrings.of(context);
    final program = ref.watch(workoutProgramProvider);
    return Scaffold(
      backgroundColor: KbTokens.surfaceColor,
      body: SafeArea(
        child: RefreshIndicator(
          color: KbTokens.inkColor,
          onRefresh: () async => ref.invalidate(workoutProgramProvider),
          child: program.when(
            loading: () => Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const CircularProgressIndicator(color: KbTokens.inkColor),
                  const SizedBox(height: 16),
                  Text(t.generating, style: AppTheme.heading(), textAlign: TextAlign.center),
                  const SizedBox(height: 6),
                  Text(t.generatingSub, style: AppTheme.caption(color: KbTokens.inkSoftColor), textAlign: TextAlign.center),
                ]),
              ),
            ),
            error: (e, _) => ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text('$e', style: AppTheme.caption()))]),
            data: (prog) => ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, kNavClearance),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.yourProgram, style: AppTheme.title()),
                          Row(children: [
                            if (prog.isAI) ...[
                              const Icon(Icons.auto_awesome, size: 14, color: KbTokens.accentTextColor),
                              const SizedBox(width: 4),
                              Text(t.aiTrainer, style: AppTheme.caption(color: KbTokens.accentTextColor)),
                            ],
                            if (prog.weeksToTarget > 0) ...[
                              if (prog.isAI) const SizedBox(width: 8),
                              Text('· ${t.weeksToGo(prog.weeksToTarget)}', style: AppTheme.caption(color: KbTokens.inkSoftColor)),
                            ],
                          ]),
                        ],
                      ),
                    ),
                    if (prog.isAI)
                      IconButton(
                        tooltip: t.regenerate,
                        onPressed: () => _regenerate(ref),
                        icon: const Icon(Icons.refresh, color: KbTokens.inkColor),
                      ),
                  ],
                ),
                if (prog.summary.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: const BoxDecoration(color: KbTokens.limePaleColor, borderRadius: AppTheme.cardRadius),
                    child: Text(prog.summary, style: AppTheme.body(color: KbTokens.accentDeepColor)),
                  ),
                ],
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () => context.push('/custom-workout'),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(18),
                    decoration: const BoxDecoration(color: KbTokens.inkColor, borderRadius: AppTheme.cardRadius),
                    child: Row(children: [
                      const Icon(Icons.add_circle_outline, color: KbTokens.limeColor),
                      const SizedBox(width: 12),
                      Expanded(child: Text(t.customWorkout, style: AppTheme.heading().copyWith(color: Colors.white))),
                      const Icon(Icons.chevron_right, color: KbTokens.onDarkSoftColor),
                    ]),
                  ),
                ),
                ...prog.workouts.map((w) => _WorkoutCard(w: w, onStart: () => context.push('/workout', extra: w))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkoutCard extends StatelessWidget {
  const _WorkoutCard({required this.w, required this.onStart});
  final WorkoutPlan w;
  final VoidCallback onStart;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
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
                    Row(children: [
                      if (w.day.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: KbTokens.limePaleColor, borderRadius: BorderRadius.circular(8)),
                          child: Text(w.day, style: AppTheme.caption(color: KbTokens.accentDeepColor).copyWith(fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(child: Text(w.title, style: AppTheme.heading(), overflow: TextOverflow.ellipsis)),
                    ]),
                    const SizedBox(height: 2),
                    Text('${w.minutes} min · ~${w.kcal} kcal · ${w.moves.length} moves', style: AppTheme.caption()),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onStart,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(color: KbTokens.limeColor, borderRadius: BorderRadius.circular(14)),
                  child: Text(KbStrings.of(context).startNow, style: AppTheme.label(color: KbTokens.inkColor).copyWith(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...w.moves.map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  const Icon(Icons.circle, size: 6, color: KbTokens.inkFaintColor),
                  const SizedBox(width: 10),
                  Expanded(child: Text(m.name, style: AppTheme.body())),
                  Text(m.detail, style: AppTheme.caption(color: KbTokens.inkSoftColor)),
                ]),
              )),
        ],
      ),
    );
  }
}
