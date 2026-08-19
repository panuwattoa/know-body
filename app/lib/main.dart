import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth/auth.dart';
import 'l10n/strings.dart';
import 'router.dart';
import 'services/prefs.dart';
import 'state/providers.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Prefs.init();
  await initAuth();
  // Edge-to-edge with a transparent system nav bar (removes the white bar below).
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
    statusBarColor: Colors.transparent,
  ));
  runApp(const ProviderScope(child: KnowBodyApp()));
}

class KnowBodyApp extends ConsumerWidget {
  const KnowBodyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    return MaterialApp.router(
      title: 'KnowBody',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      // Tap anywhere outside a text field to dismiss the keyboard.
      builder: (context, child) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: child,
      ),
      routerConfig: router,
      locale: locale,
      supportedLocales: KbStrings.supported,
      localizationsDelegates: const [
        KbStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
