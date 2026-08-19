import 'package:home_widget/home_widget.dart';

import '../api/models.dart';

/// Pushes the latest calorie-ring data to the native home-screen widget.
/// Called whenever Home data loads, so the widget reflects the last app open.
class WidgetService {
  static Future<void> update(Home h) async {
    try {
      await HomeWidget.saveWidgetData<int>('kcalLeft', h.kcalLeft);
      await HomeWidget.saveWidgetData<int>('pct', (h.ringPct * 100).round());
      await HomeWidget.saveWidgetData<int>('streak', h.streak.count);
      await HomeWidget.updateWidget(androidName: 'KnowBodyWidget', iOSName: 'KnowBodyWidget');
    } catch (_) {/* widget not available on this platform */}
  }
}
