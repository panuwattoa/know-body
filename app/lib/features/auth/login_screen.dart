import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/auth.dart';
import '../../l10n/strings.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.g.dart';
import '../../widgets/mochi.dart';

/// Email/password login + sign-up (Supabase). Only shown when auth is configured.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _signUp = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final email = _email.text.trim();
      final pw = _password.text;
      if (_signUp) {
        await Auth.signUp(email, pw);
      } else {
        await Auth.signIn(email, pw);
      }
      // Router redirect (auth state change) handles navigation.
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('AuthException(message: ', '').replaceAll(')', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = KbStrings.of(context);
    return Scaffold(
      backgroundColor: KbTokens.surfaceColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: Mochi(size: 120, mood: 'happy')),
                const SizedBox(height: 20),
                Text('KnowBody', style: AppTheme.display(), textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text(t.tagline, style: AppTheme.body(color: KbTokens.inkSoftColor), textAlign: TextAlign.center),
                const SizedBox(height: 28),
                _field(_email, t.email, keyboard: TextInputType.emailAddress),
                const SizedBox(height: 12),
                _field(_password, t.password, obscure: true),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: AppTheme.caption(color: KbTokens.dangerColor), textAlign: TextAlign.center),
                ],
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _busy ? null : _submit,
                  child: Container(
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: KbTokens.inkColor, borderRadius: BorderRadius.circular(KbTokens.radiusPill)),
                    child: _busy
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(_signUp ? t.signUp : t.signIn, style: AppTheme.heading().copyWith(color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 14),
                TextButton(
                  onPressed: () => setState(() => _signUp = !_signUp),
                  child: Text(_signUp ? t.haveAccount : t.noAccount, style: AppTheme.label()),
                ),
                const SizedBox(height: 6),
                Row(children: [
                  const Expanded(child: Divider(color: Color(0x22121212))),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(t.orDivider, style: AppTheme.caption(color: KbTokens.inkSoftColor))),
                  const Expanded(child: Divider(color: Color(0x22121212))),
                ]),
                const SizedBox(height: 12),
                _outlined(
                  icon: const _GoogleG(),
                  label: t.continueGoogle,
                  onTap: _busy ? null : () => _oauth(Auth.signInWithGoogle),
                ),
                const SizedBox(height: 10),
                _outlined(
                  icon: const Icon(Icons.apple, color: KbTokens.inkColor, size: 22),
                  label: t.continueApple,
                  onTap: _busy ? null : () => _oauth(Auth.signInWithApple),
                ),
                const SizedBox(height: 10),
                _outlined(
                  icon: const Icon(Icons.person_outline, color: KbTokens.inkColor),
                  label: t.continueGuest,
                  onTap: _busy ? null : () => _oauth(Auth.continueAsGuest),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _oauth(Future<void> Function() fn) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await fn();
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _outlined({required Widget icon, required String label, VoidCallback? onTap}) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: KbTokens.cardColor,
            borderRadius: BorderRadius.circular(KbTokens.radiusPill),
            border: Border.all(color: const Color(0x1A121212)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            icon,
            const SizedBox(width: 10),
            Text(label, style: AppTheme.heading()),
          ]),
        ),
      );

  Widget _field(TextEditingController c, String hint, {bool obscure = false, TextInputType? keyboard}) => TextField(
        controller: c,
        obscureText: obscure,
        keyboardType: keyboard,
        cursorColor: KbTokens.inkColor,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: KbTokens.cardColor,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        ),
      );
}

/// Minimal multicolor Google "G" mark.
class _GoogleG extends StatelessWidget {
  const _GoogleG();
  @override
  Widget build(BuildContext context) => const Text(
        'G',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF4285F4)),
      );
}
