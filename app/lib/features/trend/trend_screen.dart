import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/models.dart';
import '../../l10n/strings.dart';
import '../../state/providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.g.dart';

/// Trend tab: weight + muscle tracking. Weigh-ins are editable and removable;
/// the graphs recalculate from the current data.
class TrendScreen extends ConsumerWidget {
  const TrendScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = KbStrings.of(context);
    final weights = ref.watch(weightsProvider);
    return Scaffold(
      backgroundColor: KbTokens.surfaceColor,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 72),
        child: FloatingActionButton.extended(
          backgroundColor: KbTokens.inkColor,
          onPressed: () => _logSheet(context, ref, t),
          icon: const Icon(Icons.add, color: KbTokens.limeColor),
          label: Text(t.logWeight, style: AppTheme.heading().copyWith(color: Colors.white)),
        ),
      ),
      body: SafeArea(
        child: weights.when(
          loading: () => const Center(child: CircularProgressIndicator(color: KbTokens.inkColor)),
          error: (e, _) => Center(child: Text('$e', style: AppTheme.caption())),
          data: (list) {
            final hasMuscle = list.any((w) => w.muscleKg != null);
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
              children: [
                Text(t.trendTitle, style: AppTheme.title()),
                const SizedBox(height: 6),
                Text(t.trendSub, style: AppTheme.body(color: KbTokens.inkSoftColor)),
                const SizedBox(height: 18),
                if (list.isEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 30),
                    padding: const EdgeInsets.all(28),
                    decoration: const BoxDecoration(color: KbTokens.cardColor, borderRadius: AppTheme.cardRadius),
                    child: Text(t.noWeightYet, style: AppTheme.body(color: KbTokens.inkSoftColor), textAlign: TextAlign.center),
                  )
                else ...[
                  _MetricChart(
                    label: '${t.weight} (kg)',
                    values: list.map((e) => e.weightKg).toList(),
                    accent: KbTokens.inkColor,
                  ),
                  if (hasMuscle) ...[
                    const SizedBox(height: 14),
                    _MetricChart(
                      label: '${t.muscle} (kg)',
                      values: list.map((e) => e.muscleKg).toList(),
                      accent: KbTokens.accentTextColor,
                    ),
                  ],
                  const SizedBox(height: 16),
                  ...list.reversed.map((w) => _WeighRow(
                        w: w,
                        onEdit: () => _logSheet(context, ref, t, existing: w),
                        onDelete: () => _confirmDelete(context, ref, t, w),
                      )),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, KbStrings t, WeighIn w) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KbTokens.surfaceColor,
        title: Text(t.deleteWeighInQ, style: AppTheme.heading()),
        content: Text('${w.weightKg.toStringAsFixed(1)} kg · ${w.at.day}/${w.at.month}/${w.at.year}', style: AppTheme.body()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.cancel, style: AppTheme.label())),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: KbTokens.dangerColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.delete, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await ref.read(apiClientProvider).deleteWeight(w.id);
        ref.invalidate(weightsProvider);
        ref.invalidate(homeProvider);
      } catch (_) {}
    }
  }

  Future<void> _logSheet(BuildContext context, WidgetRef ref, KbStrings t, {WeighIn? existing}) async {
    final weight = TextEditingController(text: existing != null ? existing.weightKg.toStringAsFixed(1) : '');
    final muscle = TextEditingController(text: existing?.muscleKg != null ? existing!.muscleKg!.toStringAsFixed(1) : '');
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: KbTokens.surfaceColor,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(existing == null ? t.logWeight : t.editWeighIn, style: AppTheme.title()),
          const SizedBox(height: 14),
          _numField(weight, t.weight, suffix: 'kg', autofocus: true),
          const SizedBox(height: 12),
          _numField(muscle, t.muscleKgOpt, suffix: 'kg'),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: KbTokens.inkColor, minimumSize: const Size.fromHeight(52)),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(t.save, style: const TextStyle(color: Colors.white)),
            ),
          ),
        ]),
      ),
    );
    if (saved != true) return;
    final kg = double.tryParse(weight.text);
    final mus = double.tryParse(muscle.text);
    if (kg == null || kg <= 0) return;
    try {
      final api = ref.read(apiClientProvider);
      if (existing == null) {
        await api.addWeight(kg, muscleKg: mus);
      } else {
        await api.updateWeight(existing.id, kg, muscleKg: mus);
      }
      ref.invalidate(weightsProvider);
      ref.invalidate(homeProvider);
    } catch (_) {}
  }

  Widget _numField(TextEditingController c, String label, {String? suffix, bool autofocus = false}) => TextField(
        controller: c,
        autofocus: autofocus,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        cursorColor: KbTokens.inkColor,
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffix,
          filled: true,
          fillColor: KbTokens.cardColor,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        ),
      );
}

class _MetricChart extends StatelessWidget {
  const _MetricChart({required this.label, required this.values, required this.accent});
  final String label;
  final List<double?> values;
  final Color accent;
  @override
  Widget build(BuildContext context) {
    final present = values.whereType<double>().toList();
    if (present.isEmpty) return const SizedBox.shrink();
    final latest = present.last;
    final first = present.first;
    final delta = latest - first;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(color: KbTokens.cardColor, borderRadius: AppTheme.heroRadius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(label, style: AppTheme.label(color: KbTokens.inkSoftColor)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: KbTokens.limePaleColor, borderRadius: BorderRadius.circular(12)),
              child: Text('${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)} kg',
                  style: AppTheme.caption(color: KbTokens.accentDeepColor).copyWith(fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 2),
          Text(latest.toStringAsFixed(1), style: AppTheme.display().copyWith(fontSize: 30)),
          const SizedBox(height: 8),
          SizedBox(height: 100, child: CustomPaint(size: Size.infinite, painter: _LinePainter(present, accent))),
        ],
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.values, this.accent);
  final List<double> values;
  final Color accent;
  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) {
      canvas.drawCircle(Offset(size.width / 2, size.height / 2), 5, Paint()..color = accent);
      return;
    }
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final range = (maxV - minV).abs() < 0.1 ? 1.0 : (maxV - minV);
    Offset pt(int i) {
      final x = size.width * i / (values.length - 1);
      final y = size.height - ((values[i] - minV) / range) * size.height * 0.85 - size.height * 0.075;
      return Offset(x, y);
    }

    final path = Path()..moveTo(pt(0).dx, pt(0).dy);
    final area = Path()..moveTo(pt(0).dx, size.height)..lineTo(pt(0).dx, pt(0).dy);
    for (var i = 1; i < values.length; i++) {
      path.lineTo(pt(i).dx, pt(i).dy);
      area.lineTo(pt(i).dx, pt(i).dy);
    }
    area..lineTo(pt(values.length - 1).dx, size.height)..close();
    canvas.drawPath(area, Paint()..color = KbTokens.limeColor.withValues(alpha: 0.30));
    canvas.drawPath(path, Paint()..color = accent..style = PaintingStyle.stroke..strokeWidth = 2.6..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
    final last = pt(values.length - 1);
    canvas.drawCircle(last, 5.5, Paint()..color = accent);
    canvas.drawCircle(last, 5.5, Paint()..color = KbTokens.limeColor..style = PaintingStyle.stroke..strokeWidth = 3);
  }

  @override
  bool shouldRepaint(_LinePainter old) => old.values != values || old.accent != accent;
}

class _WeighRow extends StatelessWidget {
  const _WeighRow({required this.w, required this.onEdit, required this.onDelete});
  final WeighIn w;
  final VoidCallback onEdit, onDelete;
  @override
  Widget build(BuildContext context) {
    final t = KbStrings.of(context);
    return Dismissible(
      key: ValueKey(w.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: const BoxDecoration(color: KbTokens.dangerColor, borderRadius: AppTheme.cardRadius),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      child: GestureDetector(
        onTap: onEdit,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: const BoxDecoration(color: KbTokens.cardColor, borderRadius: AppTheme.cardRadius),
          child: Row(children: [
            Expanded(child: Text('${w.at.day}/${w.at.month}/${w.at.year}', style: AppTheme.body())),
            if (w.muscleKg != null) ...[
              Text('${t.muscle} ${w.muscleKg!.toStringAsFixed(1)}', style: AppTheme.caption(color: KbTokens.accentTextColor)),
              const SizedBox(width: 12),
            ],
            Text('${w.weightKg.toStringAsFixed(1)} kg', style: AppTheme.heading()),
            const SizedBox(width: 6),
            const Icon(Icons.edit_outlined, size: 16, color: KbTokens.inkFaintColor),
          ]),
        ),
      ),
    );
  }
}
