# KnowBody

Calm, guided fitness & calorie tracking for people who *don't* like tracking — photo-first food
logging, one-tap workouts, and **Mochi** the cat who grows as you show up. Thai-first (สลับ EN ได้).

> Working design name was *Bloomfit*; the shipping/marketing name is **KnowBody**.

## Monorepo layout

| Path                     | Stack                                   | What |
|--------------------------|-----------------------------------------|------|
| `app/`                   | Flutter (iOS + Android + widgets)       | The mobile app |
| `api/`                   | Go (chi · pgx · sqlc)                    | REST API, AI food/body pipeline |
| `web/`                   | Next.js (Vercel)                        | Marketing site, Thai/EN |
| `packages/design-tokens` | JSON + `build.mjs`                       | One source of truth for color/type/radius → Dart + CSS |
| `docs/`                  | Markdown                                | Architecture, data model, decisions |
| `_handoff/`              | (local only, git-ignored)               | Original Claude Design HTML handoff |

## Architecture (chosen)

```
 Flutter app ─┬─▶ Go API (Cloud Run, scale-to-zero) ─┬─▶ Supabase Postgres
              │                                        ├─▶ Cloudflare R2 (meal/body photos)
              │                                        └─▶ Claude vision (food + body scan)
              ├─▶ Supabase Auth (JWT: email, Google, Apple)
              └─▶ RevenueCat ─▶ App Store / Play billing (KnowBody Plus)
```

- **Free tier friendly:** Supabase free, Cloud Run scale-to-zero, R2 free egress, Vercel free.
- **Privacy / PDPA:** body photos default to on-device; only ephemeral upload for AI analysis.

## Quick start

```bash
# 1. shared tokens (run after editing packages/design-tokens/tokens.json)
node packages/design-tokens/build.mjs

# 2. API (needs Docker for local Postgres)
cd api && cp .env.example .env && make db-up && make migrate && make run

# 3. web
cd web && npm install && npm run dev

# 4. app (needs Flutter SDK)
cd app && flutter pub get && flutter run
```

See `docs/ARCHITECTURE.md`, `PLAN.md`, and `ROADMAP.md`.
