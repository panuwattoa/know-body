import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/models.dart';
import '../../l10n/strings.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.g.dart';

/// Build a custom workout (title + exercises), then run it through the runner.
class CustomWorkoutScreen extends ConsumerStatefulWidget {
  const CustomWorkoutScreen({super.key});
  @override
  ConsumerState<CustomWorkoutScreen> createState() => _CustomWorkoutScreenState();
}

class _CustomWorkoutScreenState extends ConsumerState<CustomWorkoutScreen> {
  final _title = TextEditingController();
  final List<Exercise> _moves = [];

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _addExercise(KbStrings t) async {
    final name = TextEditingController();
    final sets = TextEditingController(text: '3');
    final reps = TextEditingController(text: '10');
    const suggestions = ['วิ่ง', 'เดิน', 'วิดพื้น', 'สควอท', 'แพลงก์', 'ลันจ์', 'กระโดดตบ', 'ครันช์', 'ซิทอัพ', 'ดึงข้อ'];
    final ex = await showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      backgroundColor: KbTokens.surfaceColor,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.addExercise, style: AppTheme.title()),
            const SizedBox(height: 16),
            // exercise name
            Text(t.exNameLabel, style: AppTheme.label()),
            const SizedBox(height: 6),
            _field(name, t.exerciseName),
            const SizedBox(height: 10),
            // quick-pick chips
            Text(t.quickPick, style: AppTheme.caption(color: KbTokens.inkSoftColor)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in suggestions)
                  GestureDetector(
                    onTap: () => setSheet(() => name.text = s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: KbTokens.limePaleColor, borderRadius: BorderRadius.circular(12)),
                      child: Text(s, style: AppTheme.label(color: KbTokens.accentDeepColor)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.setLabel, style: AppTheme.label()),
                  const SizedBox(height: 6),
                  _field(sets, '3', number: true),
                ]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.repLabel, style: AppTheme.label()),
                  const SizedBox(height: 6),
                  _field(reps, '10', number: true),
                ]),
              ),
            ]),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: KbTokens.inkColor, minimumSize: const Size.fromHeight(52)),
                onPressed: () {
                  final n = name.text.trim();
                  if (n.isEmpty) return;
                  Navigator.pop(ctx, Exercise(name: n, nameEn: n, sets: int.tryParse(sets.text) ?? 3, reps: int.tryParse(reps.text) ?? 10, secs: 0));
                },
                child: Text(t.add, style: const TextStyle(color: Colors.white)),
              ),
            ),
          ]),
        ),
      ),
    );
    if (ex != null) setState(() => _moves.add(ex));
  }

  void _start(KbStrings t) {
    if (_moves.isEmpty) return;
    final minutes = (_moves.length * 3).clamp(3, 60);
    final plan = WorkoutPlan(
      title: _title.text.trim().isEmpty ? t.customWorkout : _title.text.trim(),
      titleEn: _title.text.trim(),
      focus: 'custom',
      minutes: minutes,
      kcal: minutes * 8,
      moves: _moves,
    );
    context.pushReplacement('/workout', extra: plan);
  }

  @override
  Widget build(BuildContext context) {
    final t = KbStrings.of(context);
    return Scaffold(
      backgroundColor: KbTokens.surfaceColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
              child: Row(children: [
                IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.close)),
                Expanded(child: Text(t.newWorkout, style: AppTheme.heading(), textAlign: TextAlign.center)),
                const SizedBox(width: 48),
              ]),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                children: [
                  _field(_title, t.workoutName),
                  const SizedBox(height: 18),
                  Text(t.addExercise, style: AppTheme.heading()),
                  const SizedBox(height: 10),
                  if (_moves.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: const BoxDecoration(color: KbTokens.cardColor, borderRadius: AppTheme.cardRadius),
                      child: Text(t.noExercisesYet, style: AppTheme.body(color: KbTokens.inkSoftColor), textAlign: TextAlign.center),
                    )
                  else
                    ..._moves.asMap().entries.map((e) => Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(color: KbTokens.cardColor, borderRadius: AppTheme.cardRadius),
                          child: Row(children: [
                            Expanded(child: Text(e.value.name, style: AppTheme.heading())),
                            Text(e.value.detail, style: AppTheme.caption(color: KbTokens.inkSoftColor)),
                            IconButton(onPressed: () => setState(() => _moves.removeAt(e.key)), icon: const Icon(Icons.close, size: 18)),
                          ]),
                        )),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    onPressed: () => _addExercise(t),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      side: const BorderSide(color: Color(0x22121212)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KbTokens.radiusButton)),
                    ),
                    icon: const Icon(Icons.add, color: KbTokens.inkColor),
                    label: Text(t.addExercise, style: AppTheme.heading()),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: GestureDetector(
                onTap: _moves.isEmpty ? null : () => _start(t),
                child: Opacity(
                  opacity: _moves.isEmpty ? 0.4 : 1,
                  child: Container(
                    height: 58,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: KbTokens.inkColor, borderRadius: BorderRadius.circular(KbTokens.radiusPill)),
                    child: Text(t.startWorkout, style: AppTheme.heading().copyWith(color: Colors.white)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String hint, {bool number = false}) => TextField(
        controller: c,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        inputFormatters: number ? [FilteringTextInputFormatter.digitsOnly] : null,
        cursorColor: KbTokens.inkColor,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: KbTokens.cardColor,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        ),
      );
}
