import 'package:flutter/services.dart';

/// Bridges to the native ongoing workout notification (Android "Now bar" /
/// iOS Live Activity later). Safe no-op on platforms that don't implement it.
///
/// Notification action buttons (Pause/Finish) call back via [onAction].
class LiveActivity {
  static const _ch = MethodChannel('knowbody/liveactivity');

  /// Called when a notification action button is tapped: 'toggle' | 'finish'.
  static void Function(String action)? onAction;
  static bool _handlerSet = false;

  static void _ensureHandler() {
    if (_handlerSet) return;
    _handlerSet = true;
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'onAction') {
        final a = (call.arguments as Map?)?['action'] as String?;
        if (a != null) onAction?.call(a);
      }
    });
  }

  static Future<void> start(
    String title,
    String sub, {
    int max = 0,
    int baseWhen = 0,
    bool paused = false,
    String pauseLabel = '',
    String finishLabel = '',
  }) async {
    _ensureHandler();
    try {
      await _ch.invokeMethod('start', {
        'title': title, 'sub': sub, 'max': max, 'baseWhen': baseWhen,
        'paused': paused, 'pauseLabel': pauseLabel, 'finishLabel': finishLabel,
      });
    } catch (_) {/* unsupported platform */}
  }

  static Future<void> update({
    required String title,
    required String sub,
    required int progress,
    required int max,
    int baseWhen = 0,
    bool paused = false,
    String pauseLabel = '',
    String finishLabel = '',
  }) async {
    try {
      await _ch.invokeMethod('update', {
        'title': title, 'sub': sub, 'progress': progress, 'max': max, 'baseWhen': baseWhen,
        'paused': paused, 'pauseLabel': pauseLabel, 'finishLabel': finishLabel,
      });
    } catch (_) {}
  }

  static Future<void> stop() async {
    try {
      await _ch.invokeMethod('stop');
    } catch (_) {}
  }
}
