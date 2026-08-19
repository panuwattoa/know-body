import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../api/api_client.dart';
import '../../api/models.dart';
import '../../l10n/strings.dart';
import '../../state/providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.g.dart';

/// Add a meal by searching the Thai food DB, snapping a photo (AI), or manual entry.
/// Items accumulate into a draft, then save as one meal.
class AddMealScreen extends ConsumerStatefulWidget {
  const AddMealScreen({super.key, this.editMeal});

  /// When set, the screen edits this meal instead of creating a new one.
  final Meal? editMeal;

  @override
  ConsumerState<AddMealScreen> createState() => _AddMealScreenState();
}

class _AddMealScreenState extends ConsumerState<AddMealScreen> {
  final _picker = ImagePicker();
  final _search = TextEditingController();
  List<FoodSearchItem> _results = [];
  final List<MealItem> _draft = [];
  late String _slot;
  bool _searching = false;
  bool _analyzing = false;

  bool get _isEdit => widget.editMeal != null;

  @override
  void initState() {
    super.initState();
    if (widget.editMeal != null) {
      _slot = widget.editMeal!.slot;
      _draft.addAll(widget.editMeal!.items);
    } else {
      final h = DateTime.now().hour;
      _slot = h < 10 ? 'breakfast' : (h < 15 ? 'lunch' : (h < 21 ? 'dinner' : 'snack'));
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  int get _total => _draft.fold(0, (s, i) => s + i.kcal);

  Future<void> _runSearch(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final r = await ref.read(apiClientProvider).searchFoods(q.trim());
      if (mounted) setState(() => _results = r);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _addFromSearch(FoodSearchItem f, KbStrings t) async {
    final grams = await _gramsSheet(f, t);
    if (grams != null && grams > 0) {
      setState(() => _draft.add(f.toMealItem(grams)));
    }
  }

  Future<void> _snapPhoto(KbStrings t) async {
    final src = await _pickSource(t);
    if (src == null) return;
    setState(() => _analyzing = true);
    try {
      final file = await _picker.pickImage(source: src, maxWidth: 768, maxHeight: 768, imageQuality: 72);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final draft = await ref.read(apiClientProvider).analyzeMeal(bytes);
      setState(() => _draft.addAll(draft.items));
    } on FreeLimitReached catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Free limit reached (${e.used}/${e.limit}) — upgrade to Plus for unlimited.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  Future<void> _addManual(KbStrings t) async {
    final item = await _manualSheet(t);
    if (item != null) setState(() => _draft.add(item));
  }

  Future<void> _save(KbStrings t) async {
    if (_draft.isEmpty) return;
    final title = _draft.first.name;
    final draft = MealDraft(title: title, slot: _slot, items: _draft);
    try {
      if (_isEdit) {
        await ref.read(apiClientProvider).updateMeal(widget.editMeal!.id, draft);
      } else {
        await ref.read(apiClientProvider).saveMeal(draft);
      }
      ref.invalidate(homeProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isEdit ? t.saveMeal : t.mealSaved(10))));
        context.pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = KbStrings.of(context);
    final slots = [('breakfast', t.slotBreakfast), ('lunch', t.slotLunch), ('dinner', t.slotDinner), ('snack', t.slotSnack)];
    return Scaffold(
      backgroundColor: KbTokens.surfaceColor,
      body: Stack(
        children: [
          SafeArea(
        child: Column(
          children: [
            // header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.close, color: KbTokens.inkColor)),
                  Expanded(child: Text(_isEdit ? t.editMeal : t.addMeal, style: AppTheme.heading(), textAlign: TextAlign.center)),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            // slot chips
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final s in slots)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _slot = s.$1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: _slot == s.$1 ? KbTokens.inkColor : KbTokens.cardColor,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(s.$2, style: AppTheme.label(color: _slot == s.$1 ? Colors.white : KbTokens.inkColor)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // photo + manual actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Expanded(child: _ActionBtn(icon: Icons.photo_camera_outlined, label: t.byPhoto, busy: _analyzing, onTap: () => _snapPhoto(t))),
                const SizedBox(width: 10),
                Expanded(child: _ActionBtn(icon: Icons.edit_outlined, label: t.byManual, onTap: () => _addManual(t))),
              ]),
            ),
            const SizedBox(height: 12),
            // search
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _search,
                onChanged: _runSearch,
                cursorColor: KbTokens.inkColor,
                decoration: InputDecoration(
                  hintText: t.searchFoodHint,
                  prefixIcon: const Icon(Icons.search, color: KbTokens.inkFaintColor),
                  suffixIcon: _searching
                      ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: KbTokens.inkColor)))
                      : null,
                  filled: true,
                  fillColor: KbTokens.cardColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
            ),
            // results
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                itemCount: _results.length,
                itemBuilder: (_, i) {
                  final f = _results[i];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(f.nameTh, style: AppTheme.heading()),
                    subtitle: Text('${f.nameEn} · ${f.kcal100.round()} kcal/100g', style: AppTheme.caption()),
                    trailing: Container(
                      width: 34, height: 34,
                      decoration: const BoxDecoration(color: KbTokens.limeColor, shape: BoxShape.circle),
                      child: const Icon(Icons.add, color: KbTokens.inkColor, size: 20),
                    ),
                    onTap: () => _addFromSearch(f, t),
                  );
                },
              ),
            ),
            // draft summary + save
            if (_draft.isNotEmpty) _DraftBar(draft: _draft, total: _total, t: t, onRemove: (i) => setState(() => _draft.removeAt(i)), onSave: () => _save(t)),
          ],
        ),
          ),
          if (_analyzing) _AnalyzingOverlay(t: t),
        ],
      ),
    );
  }

  // ── sheets ──

  Future<ImageSource?> _pickSource(KbStrings t) => showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: KbTokens.surfaceColor,
        builder: (ctx) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(leading: const Icon(Icons.photo_camera_outlined), title: Text(t.byPhoto, style: AppTheme.body()), onTap: () => Navigator.pop(ctx, ImageSource.camera)),
            ListTile(leading: const Icon(Icons.image_outlined), title: const Text('Gallery'), onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
          ]),
        ),
      );

  Future<double?> _gramsSheet(FoodSearchItem f, KbStrings t) {
    double grams = 100;
    return showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: KbTokens.surfaceColor,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(f.nameTh, style: AppTheme.title()),
            Text('${(f.kcal100 * grams / 100).round()} kcal · ${grams.round()} ${t.grams}', style: AppTheme.body(color: KbTokens.inkSoftColor)),
            Slider(
              value: grams.clamp(10, 500),
              min: 10, max: 500, divisions: 49,
              activeColor: KbTokens.inkColor,
              onChanged: (v) => setSheet(() => grams = v),
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: KbTokens.inkColor, minimumSize: const Size.fromHeight(52)),
                onPressed: () => Navigator.pop(ctx, grams),
                child: Text(t.add, style: const TextStyle(color: Colors.white)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<MealItem?> _manualSheet(KbStrings t) {
    final name = TextEditingController();
    final kcal = TextEditingController();
    final grams = TextEditingController(text: '100');
    return showModalBottomSheet<MealItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: KbTokens.surfaceColor,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t.byManual, style: AppTheme.title()),
          const SizedBox(height: 12),
          TextField(controller: name, decoration: InputDecoration(hintText: t.manualName, filled: true, fillColor: KbTokens.cardColor, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: kcal, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: InputDecoration(hintText: 'kcal', filled: true, fillColor: KbTokens.cardColor, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none)))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: grams, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: InputDecoration(hintText: t.grams, filled: true, fillColor: KbTokens.cardColor, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none)))),
          ]),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: KbTokens.inkColor, minimumSize: const Size.fromHeight(52)),
              onPressed: () {
                final n = name.text.trim();
                final k = int.tryParse(kcal.text) ?? 0;
                if (n.isEmpty || k <= 0) return;
                Navigator.pop(ctx, MealItem(name: n, grams: double.tryParse(grams.text) ?? 100, kcal: k, proteinG: 0, carbsG: 0, fatG: 0, source: 'manual'));
              },
              child: Text(t.add, style: const TextStyle(color: Colors.white)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _AnalyzingOverlay extends StatelessWidget {
  const _AnalyzingOverlay({required this.t});
  final KbStrings t;
  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: const Color(0xE6121212),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 48, height: 48, child: CircularProgressIndicator(color: KbTokens.limeColor)),
            const SizedBox(height: 20),
            Text(t.analyzingPhoto, style: AppTheme.heading().copyWith(color: Colors.white), textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(t.analyzingSub, style: AppTheme.caption(color: KbTokens.onDarkSoftColor), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({required this.icon, required this.label, required this.onTap, this.busy = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool busy;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: busy ? null : onTap,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: KbTokens.cardColor, borderRadius: BorderRadius.circular(KbTokens.radiusButton)),
          child: busy
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: KbTokens.inkColor))
              : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(icon, size: 20, color: KbTokens.inkColor),
                  const SizedBox(width: 8),
                  Text(label, style: AppTheme.heading()),
                ]),
        ),
      );
}

class _DraftBar extends StatefulWidget {
  const _DraftBar({required this.draft, required this.total, required this.t, required this.onRemove, required this.onSave});
  final List<MealItem> draft;
  final int total;
  final KbStrings t;
  final void Function(int) onRemove;
  final VoidCallback onSave;
  @override
  State<_DraftBar> createState() => _DraftBarState();
}

class _DraftBarState extends State<_DraftBar> {
  bool _expanded = true; // expanded by default so all items are visible

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final draft = widget.draft;
    // Collapsed: a shorter list; expanded: up to ~55% of the screen.
    final maxH = _expanded ? MediaQuery.of(context).size.height * 0.5 : 132.0;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: const BoxDecoration(
        color: KbTokens.cardColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Color(0x1A000000), blurRadius: 20, offset: Offset(0, -4))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        // drag handle
        Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 8), decoration: BoxDecoration(color: const Color(0x22121212), borderRadius: BorderRadius.circular(2)))),
        // tappable header toggles expand
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          behavior: HitTestBehavior.opaque,
          child: Row(children: [
            Text('${t.itemsInMeal} · ${draft.length} · ${widget.total} kcal', style: AppTheme.heading()),
            const Spacer(),
            Icon(_expanded ? Icons.expand_more : Icons.expand_less, color: KbTokens.inkSoftColor),
          ]),
        ),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          constraints: BoxConstraints(maxHeight: maxH),
          child: Scrollbar(
            thumbVisibility: true,
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(right: 8),
              children: [
                for (var i = 0; i < draft.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(children: [
                      Expanded(child: Text('${draft[i].name} · ${draft[i].grams.round()}g', style: AppTheme.body())),
                      Text('${draft[i].kcal}', style: AppTheme.body(color: KbTokens.inkSoftColor)),
                      IconButton(visualDensity: VisualDensity.compact, onPressed: () => widget.onRemove(i), icon: const Icon(Icons.close, size: 18)),
                    ]),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: KbTokens.inkColor, minimumSize: const Size.fromHeight(54)),
            onPressed: widget.onSave,
            child: Text(t.saveMeal, style: const TextStyle(color: Colors.white)),
          ),
        ),
      ]),
    );
  }
}
