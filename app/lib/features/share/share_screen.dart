import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../api/models.dart';
import '../../l10n/strings.dart';
import '../../state/providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.g.dart';
import '../../widgets/mochi.dart';

/// Share a KnowBody-branded progress card to social. Renders the card widget to
/// a PNG and hands it to the OS share sheet.
class ShareScreen extends ConsumerWidget {
  const ShareScreen({super.key});
  static final _cardKey = GlobalKey();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = KbStrings.of(context);
    final home = ref.watch(homeProvider);
    return Scaffold(
      backgroundColor: KbTokens.darkColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        leading: IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.close)),
        title: Text(t.shareProgress, style: AppTheme.heading().copyWith(color: Colors.white)),
        centerTitle: true,
      ),
      body: home.when(
        loading: () => const Center(child: CircularProgressIndicator(color: KbTokens.limeColor)),
        error: (e, _) => Center(child: Text('$e', style: AppTheme.caption(color: Colors.white))),
        data: (h) => Column(
          children: [
            const Spacer(),
            // Cap the card so it doesn't blow up on large/foldable screens.
            // 360 logical px × pixelRatio 3 exports a clean 1080×1080 image.
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: RepaintBoundary(
                    key: _cardKey,
                    child: _ProgressCard(home: h),
                  ),
                ),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: KbTokens.limeColor, minimumSize: const Size.fromHeight(56)),
                  onPressed: () => _share(context),
                  icon: const Icon(Icons.ios_share, color: KbTokens.inkColor),
                  label: Text(t.share, style: AppTheme.heading()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _share(BuildContext context) async {
    try {
      final boundary = _cardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/knowbody_progress.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'KnowBody · knowbody.app');
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't share")));
      }
    }
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.home});
  final Home home;
  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: KbTokens.surfaceColor, borderRadius: BorderRadius.circular(24)),
        child: Stack(
          children: [
            Positioned(
              right: -50, top: -50,
              child: Container(width: 180, height: 180, decoration: const BoxDecoration(color: KbTokens.limeColor, shape: BoxShape.circle)),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // wordmark
                Row(children: [
                  Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(color: KbTokens.inkColor, borderRadius: BorderRadius.circular(10)),
                    child: const Center(child: Text('🌿', style: TextStyle(fontSize: 16))),
                  ),
                  const SizedBox(width: 8),
                  Text('KnowBody', style: AppTheme.title().copyWith(letterSpacing: -0.5)),
                ]),
                const SizedBox(height: 20),
                Text('${home.streak.count} วันต่อเนื่อง', style: AppTheme.display().copyWith(fontSize: 30)),
                const Spacer(),
                Row(
                  children: [
                    _stat('${home.streak.count}', 'streak', dark: false),
                    const SizedBox(width: 10),
                    _stat('${home.meals.length}', 'meals', dark: false),
                    const SizedBox(width: 10),
                    _stat('Lv${home.pet.level}', home.pet.name, dark: true),
                  ],
                ),
                const SizedBox(height: 14),
                Text('knowbody.app', style: AppTheme.caption(color: KbTokens.inkFaintColor)),
              ],
            ),
            Positioned(right: 6, top: 4, child: Mochi(size: 58, mood: home.pet.mood)),
          ],
        ),
      ),
    );
  }

  Widget _stat(String big, String small, {required bool dark}) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: dark ? KbTokens.inkColor : KbTokens.cardColor, borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(big, style: AppTheme.title().copyWith(color: dark ? KbTokens.limeColor : KbTokens.inkColor)),
              Text(small, style: AppTheme.caption(color: dark ? Colors.white70 : KbTokens.inkSoftColor)),
            ],
          ),
        ),
      );
}
