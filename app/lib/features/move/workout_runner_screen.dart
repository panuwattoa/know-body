import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/models.dart';
import '../../l10n/strings.dart';
import '../../services/live_activity.dart';
import '../../state/providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.g.dart';
import '../../widgets/mochi.dart';

/// Real workout runner: elapsed timer, tap each set as done, advance moves,
/// and drive a native ongoing "Now bar" notification. Finishing logs it (XP).
class WorkoutRunnerScreen extends ConsumerStatefulWidget {
  const WorkoutRunnerScreen({super.key, required this.workout});
  final WorkoutPlan workout;
  @override
  ConsumerState<WorkoutRunnerScreen> createState() => _WorkoutRunnerScreenState();
}

class _WorkoutRunnerScreenState extends ConsumerState<WorkoutRunnerScreen> {
  late final List<int> _done; // sets done per exercise
  int _idx = 0;
  int _elapsed = 0;
  Timer? _timer;
  String? _workoutId;
  Map<String, dynamic>? _reward;
  bool _finishing = false;
  bool _paused = false;

  WorkoutPlan get w => widget.workout;
  int get _totalSets => w.moves.fold(0, (s, m) => s + m.sets);
  int get _doneSets => _done.fold(0, (s, v) => s + v);

  @override
  void initState() {
    super.initState();
    _done = List.filled(w.moves.length, 0);
    _startTimer();
    // Defer to after first frame — reading Localizations in initState throws.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final t = KbStrings.of(context);
      // Handle Pause/Finish taps from the notification.
      LiveActivity.onAction = (action) {
        if (!mounted) return;
        final tt = KbStrings.of(context);
        if (action == 'toggle') {
          _togglePause(tt);
        } else if (action == 'finish') {
          _finish(tt, partial: _doneSets < _totalSets);
        }
      };
      final firstDetail = '${w.moves.first.name} · 0/$_totalSets ${t.sets}';
      try {
        _workoutId = await ref.read(apiClientProvider).createWorkout(w.title);
      } catch (_) {}
      await LiveActivity.start(w.title, firstDetail,
          max: _totalSets, baseWhen: _baseWhen(), pauseLabel: t.pause, finishLabel: t.finishWorkout);
    });
  }

  @override
  void dispose() {
    LiveActivity.onAction = null;
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed++);
    });
  }

  int _baseWhen() => DateTime.now().millisecondsSinceEpoch - _elapsed * 1000;

  String get _clock {
    final m = (_elapsed ~/ 60).toString().padLeft(2, '0');
    final s = (_elapsed % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // Push current state to the notification.
  void _pushNoti(KbStrings t) {
    final detail = _paused
        ? '${t.paused} · $_clock'
        : '${w.moves[_idx].name} · $_doneSets/$_totalSets ${t.sets}';
    LiveActivity.update(
      title: w.title,
      sub: detail,
      progress: _doneSets,
      max: _totalSets,
      baseWhen: _baseWhen(),
      paused: _paused,
      pauseLabel: _paused ? t.resume : t.pause,
      finishLabel: t.finishWorkout,
    );
  }

  void _togglePause(KbStrings t) {
    setState(() => _paused = !_paused);
    if (_paused) {
      _timer?.cancel();
    } else {
      _startTimer();
    }
    _pushNoti(t);
  }

  void _tapSet(KbStrings t) {
    if (_paused || _done[_idx] >= w.moves[_idx].sets) return;
    setState(() => _done[_idx]++);
    _pushNoti(t);
  }

  void _next() {
    if (_idx < w.moves.length - 1) {
      setState(() => _idx++);
      _pushNoti(KbStrings.of(context));
    }
  }

  Future<void> _finish(KbStrings t, {required bool partial}) async {
    _timer?.cancel();
    setState(() => _finishing = true);
    await LiveActivity.stop();
    try {
      if (_workoutId != null) {
        final res = await ref
            .read(apiClientProvider)
            .completeWorkout(_workoutId!, kcalBurned: w.kcal, durationS: _elapsed, partial: partial);
        ref.invalidate(homeProvider);
        setState(() => _reward = res);
      } else {
        setState(() => _reward = {'xpGained': partial ? 4 : 8, 'pet': {}, 'streak': {}});
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      if (mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = KbStrings.of(context);
    if (_reward != null) return _RewardScreen(reward: _reward!, t: t);

    final move = w.moves[_idx];
    final allDone = _doneSets >= _totalSets;
    final lastMove = _idx == w.moves.length - 1;

    return Scaffold(
      backgroundColor: KbTokens.darkColor,
      body: SafeArea(
        child: Column(
          children: [
            // header
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => _finish(t, partial: !allDone),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                  Expanded(child: Text(w.title, style: AppTheme.heading().copyWith(color: Colors.white))),
                  IconButton(
                    onPressed: () => _togglePause(t),
                    icon: Icon(_paused ? Icons.play_arrow_rounded : Icons.pause_rounded, color: KbTokens.limeColor),
                  ),
                ],
              ),
            ),
            const Spacer(),
            // elapsed
            Text(t.elapsed.toUpperCase(), style: AppTheme.caption(color: KbTokens.onDarkSoftColor).copyWith(letterSpacing: 1.4)),
            Text(_clock, style: const TextStyle(fontSize: 84, height: 1, fontWeight: FontWeight.w300, letterSpacing: -2, color: KbTokens.limeColor)),
            const SizedBox(height: 6),
            Text('${t.moveOf(_idx + 1, w.moves.length)} · $_doneSets/$_totalSets ${t.sets}',
                style: AppTheme.body(color: KbTokens.onDarkSoftColor)),
            const SizedBox(height: 28),
            // current move card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: const Color(0x14FFFFFF), borderRadius: BorderRadius.circular(24)),
              child: Column(
                children: [
                  Text(move.name, style: AppTheme.title().copyWith(color: Colors.white)),
                  Text(move.detail, style: AppTheme.body(color: KbTokens.onDarkSoftColor)),
                  const SizedBox(height: 16),
                  // set dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(move.sets, (i) {
                      final on = i < _done[_idx];
                      return Container(
                        width: 22, height: 22,
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        decoration: BoxDecoration(
                          color: on ? KbTokens.limeColor : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(color: on ? KbTokens.limeColor : const Color(0x55FFFFFF), width: 2),
                        ),
                        child: on ? const Icon(Icons.check, size: 14, color: KbTokens.inkColor) : null,
                      );
                    }),
                  ),
                ],
              ),
            ),
            const Spacer(),
            // actions
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: () => _tapSet(t),
                      child: Container(
                        height: 58,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: KbTokens.limeColor, borderRadius: BorderRadius.circular(KbTokens.radiusPill)),
                        child: Text(t.setDone, style: AppTheme.heading()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: _finishing ? null : (allDone || lastMove ? () => _finish(t, partial: !allDone) : _next),
                      child: Container(
                        height: 58,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: const Color(0x1FFFFFFF), borderRadius: BorderRadius.circular(KbTokens.radiusPill)),
                        child: Text(allDone || lastMove ? t.finishWorkout : t.nextMove,
                            style: AppTheme.label(color: Colors.white).copyWith(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(t.stopAnytime, style: AppTheme.caption(color: KbTokens.onDarkSoftColor)),
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardScreen extends StatelessWidget {
  const _RewardScreen({required this.reward, required this.t});
  final Map<String, dynamic> reward;
  final KbStrings t;
  @override
  Widget build(BuildContext context) {
    final xp = reward['xpGained'] ?? 0;
    final pet = reward['pet'] as Map<String, dynamic>? ?? {};
    final streak = reward['streak'] as Map<String, dynamic>? ?? {};
    return Scaffold(
      backgroundColor: KbTokens.darkColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Mochi(size: 180, mood: 'cheering'),
              const SizedBox(height: 20),
              Text(t.workoutDone(xp), style: AppTheme.title().copyWith(color: Colors.white), textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Text('🔥 ${t.streakDays(streak['count'] ?? 0)}  ·  ${pet['name'] ?? ''} ${pet['level'] != null ? t.petLevel(pet['level']) : ''}',
                  style: AppTheme.body(color: KbTokens.onDarkSoftColor)),
              const SizedBox(height: 28),
              GestureDetector(
                onTap: () => context.pop(),
                child: Container(
                  height: 54,
                  width: double.infinity,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: KbTokens.limeColor, borderRadius: BorderRadius.circular(KbTokens.radiusPill)),
                  child: Text(t.cont, style: AppTheme.heading()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
