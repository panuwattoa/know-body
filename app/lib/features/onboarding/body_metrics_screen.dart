import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/strings.dart';
import '../../state/providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.g.dart';

/// Onboarding step 2: collect body metrics; server computes the calorie target.
class BodyMetricsScreen extends ConsumerStatefulWidget {
  const BodyMetricsScreen({super.key});
  @override
  ConsumerState<BodyMetricsScreen> createState() => _BodyMetricsScreenState();
}

class _BodyMetricsScreenState extends ConsumerState<BodyMetricsScreen> {
  String _sex = 'm';
  final _age = TextEditingController(text: '30');
  final _height = TextEditingController(text: '170');
  final _weight = TextEditingController(text: '65');
  String _activity = 'light';
  String _goalDir = 'maintain';
  DateTime? _target;
  bool _busy = false;

  @override
  void dispose() {
    _age.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  Future<void> _submit(KbStrings t) async {
    setState(() => _busy = true);
    try {
      final calc = await ref.read(apiClientProvider).setupProfile(
            goal: ref.read(onboardingGoalProvider),
            locale: t.isThai ? 'th' : 'en',
            sex: _sex,
            age: int.tryParse(_age.text) ?? 30,
            heightCm: double.tryParse(_height.text) ?? 170,
            weightKg: double.tryParse(_weight.text) ?? 65,
            activity: _activity,
            goalDir: _goalDir,
            targetDate: _target == null
                ? ''
                : '${_target!.year}-${_target!.month.toString().padLeft(2, '0')}-${_target!.day.toString().padLeft(2, '0')}',
          );
      ref.read(lastCalcProvider.notifier).state = calc;
      ref.invalidate(homeProvider);
      if (mounted) context.go('/calorie-result');
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = KbStrings.of(context);
    return Scaffold(
      backgroundColor: KbTokens.surfaceColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 12),
                children: [
                  Text(t.bmTitle, style: AppTheme.display()),
                  const SizedBox(height: 12),
                  Text(t.bmSub, style: AppTheme.body(color: KbTokens.inkSoftColor)),
                  const SizedBox(height: 24),
                  _Segment(options: [('m', t.sexM), ('f', t.sexF)], value: _sex, onChanged: (v) => setState(() => _sex = v)),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: _NumField(label: t.age, controller: _age)),
                    const SizedBox(width: 12),
                    Expanded(child: _NumField(label: t.height, controller: _height)),
                    const SizedBox(width: 12),
                    Expanded(child: _NumField(label: t.weight, controller: _weight)),
                  ]),
                  const SizedBox(height: 20),
                  Text(t.activity, style: AppTheme.heading()),
                  const SizedBox(height: 10),
                  _Segment(
                    wrap: true,
                    options: [('sedentary', t.actSedentary), ('light', t.actLight), ('moderate', t.actModerate), ('active', t.actActive), ('very', t.actVery)],
                    value: _activity,
                    onChanged: (v) => setState(() => _activity = v),
                  ),
                  const SizedBox(height: 20),
                  Text(t.goalDirLabel, style: AppTheme.heading()),
                  const SizedBox(height: 10),
                  _Segment(
                    options: [('lose', t.dirLose), ('maintain', t.dirMaintain), ('gain', t.dirGain)],
                    value: _goalDir,
                    onChanged: (v) => setState(() => _goalDir = v),
                  ),
                  const SizedBox(height: 20),
                  Text(t.targetDateLabel, style: AppTheme.heading()),
                  const SizedBox(height: 4),
                  Text(t.targetDateSub, style: AppTheme.caption(color: KbTokens.inkSoftColor)),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _target ?? now.add(const Duration(days: 56)),
                        firstDate: now.add(const Duration(days: 7)),
                        lastDate: now.add(const Duration(days: 730)),
                      );
                      if (picked != null) setState(() => _target = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: const BoxDecoration(color: KbTokens.cardColor, borderRadius: AppTheme.cardRadius),
                      child: Row(children: [
                        const Icon(Icons.calendar_today_outlined, size: 20, color: KbTokens.inkColor),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _target == null
                                ? t.pickDate
                                : '${_target!.day}/${_target!.month}/${_target!.year}  ·  ${t.weeksToGo((_target!.difference(DateTime.now()).inDays / 7).ceil())}',
                            style: AppTheme.body(color: _target == null ? KbTokens.inkFaintColor : KbTokens.inkColor),
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: KbTokens.inkSoftColor),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: GestureDetector(
                onTap: _busy ? null : () => _submit(t),
                child: Container(
                  height: 58,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: KbTokens.inkColor, borderRadius: BorderRadius.circular(KbTokens.radiusPill)),
                  child: _busy
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(t.cont, style: AppTheme.heading().copyWith(color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NumField extends StatelessWidget {
  const _NumField({required this.label, required this.controller});
  final String label;
  final TextEditingController controller;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.caption(color: KbTokens.inkSoftColor)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          style: AppTheme.heading(),
          cursorColor: KbTokens.inkColor,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: KbTokens.cardColor,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.options, required this.value, required this.onChanged, this.wrap = false});
  final List<(String, String)> options;
  final String value;
  final ValueChanged<String> onChanged;
  final bool wrap;

  @override
  Widget build(BuildContext context) {
    final chips = options.map((o) {
      final sel = o.$1 == value;
      return GestureDetector(
        onTap: () => onChanged(o.$1),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: sel ? KbTokens.inkColor : KbTokens.cardColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(o.$2, style: AppTheme.label(color: sel ? Colors.white : KbTokens.inkColor).copyWith(fontWeight: FontWeight.w600)),
        ),
      );
    }).toList();
    return wrap
        ? Wrap(spacing: 8, runSpacing: 8, children: chips)
        : Row(children: [for (var i = 0; i < chips.length; i++) ...[if (i > 0) const SizedBox(width: 8), Expanded(child: chips[i])]]);
  }
}
