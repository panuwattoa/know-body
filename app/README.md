# KnowBody app (Flutter)

iOS + Android client. Thai-first, English switchable. Talks to the Go API in `../api`.

## Run

```bash
flutter pub get

# point at a running local API (see ../api), using the dev-auth bypass:
flutter run \
  --dart-define=API_BASE_URL=http://localhost:8080 \
  --dart-define=DEV_USER_ID=11111111-1111-1111-1111-111111111111
```

> The theme is generated from shared tokens. After editing
> `../packages/design-tokens/tokens.json`, run `node ../packages/design-tokens/build.mjs`
> to refresh `lib/theme/tokens.g.dart`.

## Structure

```
lib/
  main.dart                 app root, MaterialApp.router, localization
  router.dart               go_router: onboarding + 5-tab shell
  theme/                    tokens.g.dart (generated) + app_theme.dart
  l10n/strings.dart         th/en strings (Thai default)
  api/                      models.dart + api_client.dart (Dio)
  state/providers.dart      Riverpod: apiClient, locale, home
  widgets/                  calorie_ring.dart, mochi.dart (custom-painted)
  features/
    onboarding/             pick-one-goal
    home/                   calorie ring, macros, meals, Mochi card  ← centerpiece
    food/                   snap → AI draft → adjust → save (killer feature)
    pet/                    Mochi tab
    shell/                  bottom-nav pill scaffold + placeholders (Move, Trend)
```

## Auth (production)

Swap the dev token in `state/providers.dart` for the Supabase access token:
sign in with `supabase_flutter` (email / Apple / Google), then have `tokenProvider`
return `Supabase.instance.client.auth.currentSession!.accessToken`.

## Native widgets & Live Activity (Phase 1–2)

The `home_widget` package bridges Flutter → native. The calorie-ring home-screen widget
and the workout Live Activity (iOS) / Now bar (Android) are implemented natively:

- **iOS:** a WidgetKit extension (SwiftUI) reading a shared App Group; Live Activities via ActivityKit.
- **Android:** an App Widget (Glance/RemoteViews); ongoing workout via a foreground-service notification / Live Updates.

Flutter pushes the latest `kcalLeft`, `streak`, and `petLevel` into the shared store on each Home refresh;
the native widgets render from that. (Scaffolding these targets is tracked in `ROADMAP.md` Phase 1.)
