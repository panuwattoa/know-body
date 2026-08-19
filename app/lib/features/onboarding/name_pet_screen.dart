import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/strings.dart';
import '../../state/providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.g.dart';
import '../../widgets/mochi.dart';

/// Step 2 of onboarding: let the user name their pet. Saved via PUT /v1/pet.
class NamePetScreen extends ConsumerStatefulWidget {
  const NamePetScreen({super.key});
  @override
  ConsumerState<NamePetScreen> createState() => _NamePetScreenState();
}

class _NamePetScreenState extends ConsumerState<NamePetScreen> {
  final _controller = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save(KbStrings t) async {
    final name = _controller.text.trim();
    setState(() => _busy = true);
    try {
      if (name.isNotEmpty) {
        await ref.read(apiClientProvider).renamePet(name);
        ref.invalidate(homeProvider);
      }
    } catch (_) {
      // non-fatal — pet keeps its default name
    }
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final t = KbStrings.of(context);
    return Scaffold(
      backgroundColor: KbTokens.darkColor,
      // resizeToAvoidBottomInset (default true) + a scroll view that keeps min
      // height so the Spacers work when there's room and it scrolls when the
      // keyboard is up — no overflow on the Fold's large inner screen.
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 46),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text(t.namePetTitle, style: AppTheme.display().copyWith(color: Colors.white)),
                    const SizedBox(height: 12),
                    Text(t.namePetSub, style: AppTheme.body(color: KbTokens.onDarkSoftColor)),
                    const Spacer(),
                    const Center(child: Mochi(size: 180, mood: 'happy')),
                    const Spacer(),
                    TextField(
                controller: _controller,
                autofocus: true,
                textAlign: TextAlign.center,
                maxLength: 24,
                style: AppTheme.title().copyWith(color: Colors.white),
                cursorColor: KbTokens.limeColor,
                decoration: InputDecoration(
                  counterText: '',
                  hintText: t.namePetHint,
                  hintStyle: AppTheme.title().copyWith(color: const Color(0x66FFFFFF)),
                  filled: true,
                  fillColor: const Color(0x14FFFFFF),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(KbTokens.radiusPill),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
                ),
                      onSubmitted: (_) => _save(t),
                    ),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: _busy ? null : () => _save(t),
                      child: Container(
                        height: 58,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: KbTokens.limeColor, borderRadius: BorderRadius.circular(KbTokens.radiusPill)),
                        child: _busy
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: KbTokens.inkColor))
                            : Text(t.cont, style: AppTheme.heading()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
