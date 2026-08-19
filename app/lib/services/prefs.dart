import 'package:shared_preferences/shared_preferences.dart';

/// Small persisted flags. Initialized in main() before runApp().
class Prefs {
  static late SharedPreferences _p;
  static Future<void> init() async => _p = await SharedPreferences.getInstance();

  /// Whether the user finished onboarding (so we can skip it on re-entry).
  static bool get onboarded => _p.getBool('onboarded') ?? false;
  static Future<void> setOnboarded(bool v) => _p.setBool('onboarded', v);
}
