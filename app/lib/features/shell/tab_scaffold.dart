import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/strings.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.g.dart';

/// Space the floating bottom nav occupies. Screens add this as bottom padding
/// (and FABs lift by it) so content isn't hidden behind the nav pill.
const double kNavClearance = 96;

/// Bottom-nav shell matching the design's dark pill nav (Home · Food · Move · Trend · Mochi).
class TabScaffold extends StatelessWidget {
  const TabScaffold({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final t = KbStrings.of(context);
    final items = [
      (Icons.home_rounded, t.home),
      (Icons.restaurant_rounded, t.food),
      (Icons.fitness_center, t.move),
      (Icons.show_chart_rounded, t.trend),
      (Icons.pets_rounded, t.buddy),
    ];
    return Scaffold(
      backgroundColor: KbTokens.surfaceColor,
      // Let the page fill the full height behind the floating nav pill — removes
      // the scaffold-background band that showed below the bar.
      extendBody: true,
      // NOTE: don't wrap navigationShell in an AnimatedSwitcher — it carries an
      // internal GlobalKey and can't exist twice during a transition (crashes with
      // "Duplicate GlobalKey"). The nav-pill animation provides the motion instead.
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(color: KbTokens.inkColor, borderRadius: BorderRadius.circular(24)),
          // Items size to content so the selected lime pill can grow smoothly
          // (AnimatedSize) while the others stay compact icons.
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var i = 0; i < items.length; i++)
                _NavItem(
                  icon: items[i].$1,
                  label: items[i].$2,
                  selected: navigationShell.currentIndex == i,
                  onTap: () => navigationShell.goBranch(i, initialLocation: i == navigationShell.currentIndex),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap});
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  static const _dur = Duration(milliseconds: 280);
  static const _curve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: _dur,
        curve: _curve,
        height: 46,
        margin: const EdgeInsets.symmetric(vertical: 7),
        padding: EdgeInsets.symmetric(horizontal: selected ? 16 : 12),
        decoration: BoxDecoration(
          color: selected ? KbTokens.limeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(17),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 21, color: selected ? KbTokens.inkColor : const Color(0x8CFFFFFF)),
            // AnimatedSize tweens the pill's width as the full-size label grows
            // in / out — the "adjust size green button" animation.
            ClipRect(
              child: AnimatedSize(
                duration: _dur,
                curve: _curve,
                child: selected
                    ? Padding(
                        padding: const EdgeInsets.only(left: 7),
                        child: Text(
                          label,
                          maxLines: 1,
                          softWrap: false,
                          style: AppTheme.label(color: KbTokens.inkColor).copyWith(fontWeight: FontWeight.w600),
                        ),
                      )
                    : const SizedBox(height: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple placeholder for tabs not yet built out (Move, Trend).
class PlaceholderTab extends StatelessWidget {
  const PlaceholderTab({super.key, required this.title, required this.note});
  final String title, note;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KbTokens.surfaceColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: AppTheme.title()),
                const SizedBox(height: 8),
                Text(note, style: AppTheme.body(color: KbTokens.inkSoftColor), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
