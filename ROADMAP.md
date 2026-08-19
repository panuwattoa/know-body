# KnowBody — Roadmap

✅ done · 🟡 partial · ⬜ pending

## Phase 0 — Foundation ✅
- ✅ Monorepo, git → GitHub (panuwattoa/know-body), `.gitignore`
- ✅ Shared design tokens (JSON → Dart + CSS)
- ✅ Plan / architecture / deploy docs
- ✅ Go API (chi · pgx), migrations, Supabase-JWT auth middleware
- ✅ Next.js marketing site (Thai/EN)
- ✅ CI (GitHub Actions: Go + Flutter + web + tokens check)
- ✅ App icon (lime leaf) for Android + iOS

## Phase 1 — MVP core loop ✅
- ✅ Onboarding: goal → body metrics → Mifflin-St Jeor calorie/macro target → name pet
- ✅ Home: animated calorie ring, macros, meals, yesterday recap, today suggestion
- ✅ Photo food logging → Gemini vision → editable ingredients → save (+ Thai food DB match)
- ✅ Full food CRUD: search / photo / manual add, edit, delete meals
- ✅ Streaks + freezes, Mochi XP/level engine, streak calendar
- ✅ Workouts: AI program + custom + runner (sets/timer) + completion → XP
- ✅ Weight + muscle tracking (add/edit/delete, charts)
- ✅ Auth via Supabase: email, **Google**, guest (anonymous, device-persistent)
- 🟡 Free-tier AI cap enforced (402) — ⬜ **RevenueCat paywall / purchase flow** still pending
- ⬜ **Home-screen widget** (calorie ring) — `home_widget` dep in, native widget not built
- ⬜ **Apple Sign-In** (email + Google + guest done; Apple pending)

## Phase 2 — Depth & retention
- 🟡 Body scan: API (analyze/save, ranges) ✅ — ⬜ **Flutter body-scan UI** pending
- 🟡 AI workout program generation ✅ — ⬜ **auto-adjust on no progress** pending
- ✅ Shareable KnowBody card (square) — ⬜ story variant + privacy toggles pending
- ✅ Android live "Now bar" notification (progress, timer, pause/finish) — ⬜ **iOS Live Activity** pending
- ⬜ **Soft social**: friends, nudges/cheers (DB tables exist; endpoints + UI pending)
- ⬜ **Wearables**: HealthKit + Health Connect sync
- ⬜ Responsive: iPad left-rail + Fold flex-mode layouts

## Phase 3 — Growth & B2B
- ⬜ Coach (trainer) tier: client management, assign programs, trends
- ⬜ Garmin Connect sync (partner approval — long lead)
- ⬜ Store prep: Android keystore signing, iOS signing, screenshots, ASO
- ⬜ Deploy execution: API → Cloud Run, DB → Supabase, web → Vercel (docs in `docs/DEPLOY.md`)
- ⬜ Analytics + A/B on paywall & onboarding

## Known constraints
- Gemini **free tier = 20 generations/day**; program is cached per user, and quota errors fall
  back to the built-in plan. Enable billing (or a higher-quota model) for production.
