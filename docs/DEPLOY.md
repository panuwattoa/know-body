# Deploying KnowBody

Three deployables: **API** (Go → Cloud Run), **web** (Next.js → Vercel), **app** (Flutter → stores).
Auth is **Supabase**; the app runs in a dev-bypass mode until you provide Supabase config.

## 0. Supabase (auth + Postgres)

1. Create a project at [supabase.com](https://supabase.com). Note:
   - **Project URL** (`https://xxxx.supabase.co`)
   - **anon/publishable key** (Settings → API)
   - **JWT secret** (Settings → API → JWT secret) — the API verifies tokens with this
   - **Postgres connection string** (Settings → Database → Connection string, "URI")
2. Run the migrations against the Supabase Postgres:
   ```bash
   for f in api/migrations/*.sql; do psql "$SUPABASE_DB_URL" -f "$f"; done
   ```
3. Enable auth providers: **Email**, **Anonymous** (for guest), and **Google**
   (Auth → Providers → Google; add your Google OAuth client ID/secret).
   Add redirect URL: `app.knowbody://login-callback`.

## 1. API → Google Cloud Run

```bash
cd api
gcloud run deploy knowbody-api \
  --source . \
  --region asia-southeast1 \
  --allow-unauthenticated \
  --set-env-vars ENV=prod,AUTH_DEV_BYPASS=0 \
  --set-env-vars DATABASE_URL="$SUPABASE_DB_URL" \
  --set-env-vars SUPABASE_JWT_SECRET="$SUPABASE_JWT_SECRET" \
  --set-env-vars AI_PROVIDER=gemini,GEMINI_API_KEY="$GEMINI_API_KEY",GEMINI_MODEL=gemini-3.6-flash
```
- `AUTH_DEV_BYPASS=0` in prod — only real Supabase JWTs are accepted.
- Prefer **Secret Manager** for `SUPABASE_JWT_SECRET`, `GEMINI_API_KEY`, `DATABASE_URL` (`--set-secrets`).
- Cloud Run scales to zero → ~$0 idle. Note the service URL for the app/web.

## 2. Web → Vercel

- Import the repo in Vercel, set **Root Directory = `web`** (framework auto-detected via `vercel.json`).
- No env vars required for the marketing site. Deploys on every push to `main`.

## 3. App → iOS / Android

Build with production defines pointing at the deployed API + Supabase:

```bash
cd app
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://<cloud-run-url> \
  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-key>
# iOS: flutter build ipa --release --dart-define=...
```
- When `SUPABASE_URL`/`SUPABASE_ANON_KEY` are set, the login screen (email · Google · guest) is shown
  and the API receives real JWTs. Without them, the app uses the dev-token bypass (local dev only).
- Android signing: create a keystore and configure `android/key.properties` before a store build.
- iOS: set the signing team in Xcode; run `pod install` in `app/ios`.

## CI

`.github/workflows/ci.yml` runs on every push/PR: Go vet+test+build, Flutter analyze+test+build,
web build, and a check that generated design tokens are committed.

## Environments summary

| Piece | Prod host | Key env |
|-------|-----------|---------|
| API   | Cloud Run | `DATABASE_URL`, `SUPABASE_JWT_SECRET`, `GEMINI_API_KEY`, `AUTH_DEV_BYPASS=0` |
| Web   | Vercel    | — |
| App   | App Store / Play | `API_BASE_URL`, `SUPABASE_URL`, `SUPABASE_ANON_KEY` |
