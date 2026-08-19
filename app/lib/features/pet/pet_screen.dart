import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/strings.dart';
import '../../state/providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.g.dart';
import '../../widgets/mochi.dart';
import '../shell/tab_scaffold.dart';

/// The pet tab — the pet lives here with XP/level and mood.
class PetScreen extends ConsumerWidget {
  const PetScreen({super.key});

  Future<void> _renameDialog(BuildContext context, WidgetRef ref, KbStrings t, String current) async {
    final controller = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KbTokens.surfaceColor,
        title: Text(t.rename, style: AppTheme.heading()),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 24,
          cursorColor: KbTokens.inkColor,
          decoration: InputDecoration(
            counterText: '',
            hintText: t.namePetHint,
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: KbTokens.inkColor)),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t.cancel, style: AppTheme.label())),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: KbTokens.inkColor),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(t.save, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty && name != current) {
      try {
        await ref.read(apiClientProvider).renamePet(name);
        ref.invalidate(homeProvider);
      } catch (_) {/* keep old name on failure */}
    }
  }
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = KbStrings.of(context);
    final home = ref.watch(homeProvider);
    return Scaffold(
      backgroundColor: KbTokens.darkColor,
      body: SafeArea(
        child: home.when(
          loading: () => const Center(child: CircularProgressIndicator(color: KbTokens.limeColor)),
          error: (e, _) => Center(child: Text('$e', style: AppTheme.caption(color: Colors.white))),
          data: (h) => Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, kNavClearance),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => _renameDialog(context, ref, t, h.pet.name),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${h.pet.name} · ${t.petLevel(h.pet.level)}',
                              style: AppTheme.title().copyWith(color: Colors.white)),
                          const SizedBox(width: 6),
                          const Icon(Icons.edit_outlined, size: 18, color: KbTokens.onDarkSoftColor),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                      decoration: BoxDecoration(color: const Color(0x1AFFFFFF), borderRadius: BorderRadius.circular(12)),
                      child: Text('🔥 ${h.streak.count}', style: AppTheme.label(color: Colors.white)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: h.pet.xpPct,
                    minHeight: 6,
                    backgroundColor: const Color(0x1FFFFFFF),
                    valueColor: const AlwaysStoppedAnimation(KbTokens.limeColor),
                  ),
                ),
                const Spacer(),
                AnimatedMochi(size: 220, mood: h.pet.mood),
                const SizedBox(height: 12),
                Text('${h.pet.xp} / ${h.pet.xpMax} XP · ${h.pet.mood}',
                    style: AppTheme.body(color: KbTokens.onDarkSoftColor)),
                const Spacer(),
                Text(t.petGrowsHint(h.pet.name),
                    style: AppTheme.caption(color: KbTokens.onDarkSoftColor), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
