# AGENTS.md

## Cursor Cloud specific instructions

### Architecture overview

This is a monorepo with two apps and an E2E test suite:

| Component | Path | Tech | Port |
|-----------|------|------|------|
| API | `apps/api` | Node 22 / TypeScript / Hono / Drizzle | 8081 (dev) |
| Flutter web | `apps/sona` | Flutter 3.44 / Dart 3.12 | 8080 (dev) |
| E2E tests | `e2e` | Playwright (Chromium) | — |

PostgreSQL 16 is required locally for the API data routes.

### Starting services

1. **PostgreSQL** — already running via systemd (`sudo pg_ctlcluster 16 main start` if stopped).
2. **API** (requires DATABASE_URL):
   ```bash
   cd apps/api
   export PORT=8081 NODE_ENV=development DATABASE_URL=postgresql://sona_app:sona_dev_pass@127.0.0.1:5432/sona CORS_ALLOW_LOCALHOST=true RUN_MIGRATIONS_ON_START=true
   npm run dev
   ```
3. **Flutter web** (optional; needed for UI testing):
   ```bash
   cd apps/sona
   flutter run -d web-server --web-port=8080 --dart-define=SONA_API_BASE_URL=http://localhost:8081
   ```

### Key gotchas

- The API's `tsx watch` does NOT auto-load `.env` files. You must `export` env vars in the shell or use a wrapper. The `.env` file at `apps/api/.env` is for reference only.
- Flutter web first load takes 30–60 seconds (WASM compilation). Playwright test timeouts are set to 300s for this reason.
- The full parent-intake E2E test (`parent-intake-full.spec.ts`) may time out on the date picker step in headless mode due to Flutter web accessibility tree rendering delays. The smoke test (`parent-intake-smoke.spec.ts`) and API tests are reliable.
- The LLM inference service (`INFERENCE_OPENAI_BASE_URL`) is not available locally — the API gracefully degrades and uses stub drafts.
- Migrations run automatically on API start when `RUN_MIGRATIONS_ON_START=true`.

### Lint & typecheck

- **API**: `cd apps/api && npx tsc --noEmit`
- **Flutter**: `cd apps/sona && flutter analyze` (2 info-level lint hints are expected, not errors)
- **E2E tests**: `cd e2e && SONA_API_URL=http://localhost:8081 SONA_WEB_URL=http://localhost:8080 npx playwright test`

### Local database credentials

- User: `sona_app` / Password: `sona_dev_pass`
- Database: `sona`
- Connection: `postgresql://sona_app:sona_dev_pass@127.0.0.1:5432/sona`

### Flutter SDK

Flutter 3.44.0 (Dart 3.12.0) is installed at `/opt/flutter/bin`. It is on PATH via `~/.bashrc`.
