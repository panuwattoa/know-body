# Architecture

## Runtime topology

```
┌─────────────┐        HTTPS/JWT        ┌──────────────────────┐
│ Flutter app │ ──────────────────────▶ │  Go API (Cloud Run)  │
│ iOS/Android │ ◀────────────────────── │  chi · pgx · sqlc    │
└──────┬──────┘                          └───┬─────────┬────────┘
       │ native widgets                      │         │
       │ (WidgetKit / Live Updates)          │         │
       │                                pgx pool     Claude
       ├─▶ Supabase Auth (GoTrue JWT)         │       vision API
       │                                      ▼         │
       └─▶ RevenueCat ─▶ Store billing   Supabase Postgres
                                              │
   Cloudflare R2 (photos) ◀── signed URLs ────┘
```

## Request auth
1. App authenticates with **Supabase Auth** (email / Apple / Google) → receives a JWT.
2. App sends `Authorization: Bearer <jwt>` to the Go API.
3. Go middleware verifies signature against Supabase **JWKS** (cached), extracts `sub` (user id),
   and loads/attaches the user. Every query is scoped by `user_id` (defense in depth even though
   the API is the only writer — no direct client→DB access).

## AI pipeline (food)
1. App downscales the meal photo (longest edge ≤ 1024) and uploads to `POST /v1/meals/analyze`.
2. API stores the original in R2, sends the image to **Claude vision** with a strict tool schema.
3. Claude returns candidate **ingredients** with grams + confidence.
4. API matches each ingredient against `thai_foods` (trigram + alias table); unmatched items keep the
   model's own kcal/macro estimate flagged `source='ai'`.
5. Response = editable draft meal. User adjusts grams/items → `POST /v1/meals` persists final.

## AI pipeline (body scan)
- Two poses (front/side) + optional weight → Claude returns **ranges** (body-fat %, measurements) with
  an explicit "estimate" disclaimer. Stored per scan; UI shows the *trend*, never a single verdict.

## Why Cloud Run
- Scale-to-zero → near-zero idle cost on the free tier while pre-revenue.
- Container = same image locally and in prod; Go cold start ~100–300ms.
- Concurrency > 1 per instance (Go handles it) keeps cost low under bursts.

## Environments
- **local:** Docker Postgres, fake auth optional, real Claude key.
- **prod:** Cloud Run + Supabase + R2; secrets via Secret Manager.

## Media & privacy
- Meal photos: R2, private bucket, short-lived signed GET URLs.
- Body photos: default kept **on device**; uploaded only for a scan the user explicitly runs, then
  optionally deleted server-side after analysis (PDPA-friendly). `DELETE /v1/account` purges all.
