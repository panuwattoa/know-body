import 'package:supabase_flutter/supabase_flutter.dart';

/// Auth configuration. Provide these at build time to enable real login:
///   --dart-define=SUPABASE_URL=https://xxx.supabase.co
///   --dart-define=SUPABASE_ANON_KEY=eyJ...
/// When unset, the app runs in dev mode (dev-token bypass, no login screen).
abstract final class AuthConfig {
  static const url = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
  static bool get enabled => url.isNotEmpty && anonKey.isNotEmpty;

  /// Dev fallback user id (used only when [enabled] is false).
  static const devUserId =
      String.fromEnvironment('DEV_USER_ID', defaultValue: '11111111-1111-1111-1111-111111111111');

  /// OAuth deep-link redirect. Must match the Android intent-filter scheme and
  /// the redirect URL configured in the Supabase dashboard.
  static const oauthRedirect = 'app.knowbody://login-callback';
}

/// Initialize Supabase if configured. Call before runApp().
Future<void> initAuth() async {
  if (AuthConfig.enabled) {
    await Supabase.initialize(url: AuthConfig.url, anonKey: AuthConfig.anonKey);
  }
}

/// Thin wrapper over Supabase auth used by the app.
class Auth {
  static SupabaseClient get _c => Supabase.instance.client;

  static bool get isSignedIn => !AuthConfig.enabled || _c.auth.currentSession != null;

  /// Bearer value for the API: a real Supabase JWT, or the dev token.
  static Future<String> token() async {
    if (!AuthConfig.enabled) return 'dev:${AuthConfig.devUserId}';
    return _c.auth.currentSession?.accessToken ?? '';
  }

  static Stream<AuthState> get onChange => _c.auth.onAuthStateChange;

  static Future<void> signIn(String email, String password) =>
      _c.auth.signInWithPassword(email: email, password: password);

  static Future<void> signUp(String email, String password) =>
      _c.auth.signUp(email: email, password: password);

  /// OAuth via Google (opens the browser; returns after the deep-link callback).
  static Future<void> signInWithGoogle() => _c.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: AuthConfig.oauthRedirect,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );

  /// Continue as guest — a real anonymous account so data is still saved.
  static Future<void> continueAsGuest() => _c.auth.signInAnonymously();

  static Future<void> signOut() => _c.auth.signOut();
}
