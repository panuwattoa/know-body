# KnowBody — Master Plan

## 1. Product

A calorie + fitness tracker **for people who dislike tracking**. Every screen has one obvious
next action; numbers stay soft. Gamified by **Mochi**, a cat that levels up as the user shows up.
Thai-first, English switchable. Thai food is the primary nutrition domain.

**Core loop:** snap a meal photo → AI estimates kcal/macros (editable) → calorie ring updates →
Mochi earns XP → streak continues. Weekly: body-scan photos → AI trend (ranges, not verdicts).

### Pillars (from the design)
1. **Photo-first food** — no manual math; AI reads the plate, user tweaks ingredients.
2. **One-tap workouts** — from 5 minutes up; a part-finished workout still counts.
3. **The pet** — Mochi reacts to your week; feed/play; XP → levels; lives on its own tab.
4. **Soft social** — friends *nudge/cheer*, never compete; shareable cards with privacy toggles.
5. **Body scan** — 2 poses weekly, private-by-device, estimates as ranges.

## 2. Tech decisions (locked)

| Concern        | Choice | Why |
|----------------|--------|-----|
| App            | Flutter | one codebase iOS+Android; native channels for widgets |
| API            | Go (chi + pgx + sqlc) | fast, typed SQL, simple deploy |
| Compute        | Google Cloud Run | scale-to-zero → ~$0 idle, fast Go cold starts |
| DB + Auth      | Supabase (Postgres, GoTrue) | relational fit; Apple/Google login built in |
| Blob storage   | Cloudflare R2 | cheap, free egress; meal/body photos |
| AI             | Claude vision (Anthropic) | best-in-class multimodal for food/body estimates |
| Subscriptions  | RevenueCat over StoreKit/Play Billing | cross-platform entitlements, Thai payment via stores |
| Marketing web  | Next.js on Vercel | free tier, fast, Thai/EN i18n |
| Wearables      | HealthKit (iOS), Health Connect (Android → Samsung), Garmin Connect (partner) | native aggregation |

## 3. Monetization

**Consumer freemium** (add B2B Coach tier in Phase 2).

| Tier | Price (THB) | Includes |
|------|-------------|----------|
| Free | 0 | manual logging, basic calorie ring, pet + streak, **3 AI photo logs / month**, Thai food search |
| **KnowBody Plus** | ~129/mo · ~990/yr | **unlimited AI photo food logging**, AI workout programs + auto-adjust, weekly body scans, wearable sync, live activity + rich widgets, ad-free, pet cosmetics |
| Coach (Phase 2) | ~499/mo | manage N clients, assign programs, view client trends, branded share |

**AI cost control:** free users hard-capped; cache common Thai dishes; batch/queue non-urgent
analysis; downscale images before vision calls. Target Plus gross margin > 80% after AI + store cut.

**Conversion levers:** the 3-free-logs cap hits exactly where value is proven; body-scan trends and
wearable sync are Plus-gated; annual pushed at onboarding day 3 and after first streak freeze.

## 4. Data model (summary — see docs/DATA_MODEL.md)

`users` · `profiles(goal, locale, daily_kcal_goal, macro targets)` · `meals(photo, kcal, at)` ·
`meal_items(name, grams, kcal, macros, thai_food_id?)` · `thai_foods(name_th, name_en, per100g …)` ·
`workouts(template?, status, burned)` · `workout_sets` · `pet(level, xp, mood)` ·
`streaks(count, freezes_left, last_active)` · `body_scans(front, side, weight, bf_range …)` ·
`friendships` · `nudges` · `subscriptions(tier, source, expires)`.

## 5. Security & performance

- **Auth:** Supabase-issued JWT verified in Go middleware (JWKS cached); per-row ownership checks.
- **Privacy/PDPA:** body photos on-device by default; explicit consent per external upload; deletable;
  data-export endpoint; photos stored in R2 with short-lived signed URLs.
- **Transport:** TLS only; HSTS on web; signed URLs for media.
- **Rate limiting:** per-user token bucket on AI endpoints (also cost control).
- **Perf:** sqlc prepared statements + pgx pool; response P95 < 150ms non-AI; images downscaled
  client-side; Cloud Run min-instances=0 with concurrency tuned; CDN for web.
- **Secrets:** env only, never committed; Cloud Run secret manager in prod.

## 6. Open items to confirm later
- Garmin Connect partner approval (long lead — start application early).
- Thai Food Composition DB licensing (INMU Mahidol) vs. self-curated seed set.
- Apple Live Activities scope for v1 (workout timer) vs. later.
