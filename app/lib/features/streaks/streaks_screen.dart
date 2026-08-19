import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/strings.dart';
import '../../state/providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.g.dart';

/// Streak calendar: big streak count + a month grid highlighting active days.
class StreaksScreen extends ConsumerStatefulWidget {
  const StreaksScreen({super.key});
  @override
  ConsumerState<StreaksScreen> createState() => _StreaksScreenState();
}

class _StreaksScreenState extends ConsumerState<StreaksScreen> {
  late int _year, _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
  }

  int get _ym => _year * 100 + _month;

  void _shift(int delta) {
    setState(() {
      var m = _month + delta, y = _year;
      if (m < 1) {
        m = 12;
        y--;
      } else if (m > 12) {
        m = 1;
        y++;
      }
      _month = m;
      _year = y;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = KbStrings.of(context);
    final act = ref.watch(activityProvider(_ym));
    return Scaffold(
      backgroundColor: KbTokens.surfaceColor,
      appBar: AppBar(
        backgroundColor: KbTokens.surfaceColor,
        leading: IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.arrow_back_ios_new, size: 18)),
        title: Text(t.streaksTitle, style: AppTheme.heading()),
        centerTitle: true,
      ),
      body: act.when(
        loading: () => const Center(child: CircularProgressIndicator(color: KbTokens.inkColor)),
        error: (e, _) => Center(child: Text('$e', style: AppTheme.caption())),
        data: (a) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            // hero streak count
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${a.streak}', style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w700, height: 1, color: KbTokens.inkColor)),
                    Text(t.streakDaysBig, style: AppTheme.heading()),
                  ],
                ),
                const Spacer(),
                Container(
                  width: 84, height: 84,
                  decoration: const BoxDecoration(color: KbTokens.limeColor, shape: BoxShape.circle),
                  child: const Center(child: Text('🔥', style: TextStyle(fontSize: 40))),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(t.streakBlurb, style: AppTheme.body(color: KbTokens.inkSoftColor)),
            const SizedBox(height: 20),
            // month nav
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(color: KbTokens.cardColor, borderRadius: AppTheme.heroRadius),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left)),
                      Text('${t.thMonth(_month)} $_year', style: AppTheme.heading()),
                      IconButton(onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _CalendarGrid(year: _year, month: _month, active: a.activeDays, weekdays: t.weekdayShort),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({required this.year, required this.month, required this.active, required this.weekdays});
  final int year, month;
  final Set<String> active;
  final List<String> weekdays;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final leading = first.weekday % 7; // Sun=0
    final today = DateTime.now();
    final cells = <Widget>[];

    for (final w in weekdays) {
      cells.add(Center(child: Text(w, style: AppTheme.caption(color: KbTokens.inkSoftColor))));
    }
    for (var i = 0; i < leading; i++) {
      cells.add(const SizedBox());
    }
    for (var d = 1; d <= daysInMonth; d++) {
      final key = '$year-${month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
      final isActive = active.contains(key);
      final isToday = today.year == year && today.month == month && today.day == d;
      cells.add(Center(
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive ? KbTokens.limeColor : Colors.transparent,
            shape: BoxShape.circle,
            border: isToday && !isActive ? Border.all(color: KbTokens.inkColor, width: 1.5) : null,
          ),
          child: Text('$d',
              style: AppTheme.label(color: isActive ? KbTokens.inkColor : KbTokens.inkSoftColor)
                  .copyWith(fontWeight: isActive || isToday ? FontWeight.w700 : FontWeight.w400)),
        ),
      ));
    }
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 6,
      children: cells,
    );
  }
}
