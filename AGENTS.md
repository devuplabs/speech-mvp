# AGENTS.md

Guidance for any AI coding agent working in this repository. This is the single
source of truth for how the codebase is organized, how to run and test it, and
the conventions you must follow. See also `.cursor/rules/` for always-on
workflow + security rules.

## What this is

**Sona** — a speech-and-language-therapy (SLT) practice co-pilot. A multi-tenant
clinical platform that walks a case from parent intake → triage → clinician prep
→ session plan → parent summary → home-practice carryover, with AI-drafted
artifacts a clinician reviews before anything is published.

This handles **PHI** (children's health data) under **UK GDPR / DPA 2018** with
**HIPAA-aligned** GCP infrastructure. Treat PHI safety and compliance as
first-class constraints, not afterthoughts (see "Guardrails" below).

The ML/eval assets live in a **separate repo**, `speech-ml` (persona library +
eval regression harness). The API's LLM prompts must stay in parity with that
repo's eval harness — see `speech-ml/eval/runner/prompts.py`.

## Monorepo layout

| Component | Path | Tech | Dev port |
|-----------|------|------|----------|
| API | `apps/api` | Node 22 / TypeScript (ESM) / Hono / Drizzle / PostgreSQL 16 | 8081 |
| Flutter web/app | `apps/sona` | Flutter 3.44 / Dart 3.12 | 8080 |
| E2E tests | `e2e` | Playwright (Chromium) | — |
| Infrastructure | `infra` | Terraform / GCP / Cloud Build | — |
| Docs & ADRs | `docs` | Markdown | — |
| Dev scripts | `scripts` | TS / Bash / PowerShell | — |

## API — `apps/api`

Hono app, Drizzle ORM over PostgreSQL 16, Firebase Admin for identity, Zod for
all runtime validation. ES modules, Node ≥ 20 (CI runs Node 22).

Source map (`apps/api/src/`):
- `index.ts` — app boot, middleware chain, global error handler, migration orchestration
- `config.ts` — Zod env schema, `isProdEnv()`, `validateConfig()`, prod-safety gate
- `routes/` — `v1.ts` (main API), `practices.ts` (onboarding/admin), `tasks.ts` (async worker)
- `services/` — business logic (~26 modules: intake, triage, clinical-report, parent-summary, carryover, booking, dsar, fhir-export, audit, email…)
- `schemas/` — Zod payload schemas (intake, booking, practice, carryover…)
- `db/` — `schema.ts` (Drizzle tables), `client.ts` (pg pool singleton), `migrate.ts` (boot-time runner)
- `auth/` — Firebase token verification + RBAC (`requireIdentity` → `requireUser` → `requireRole`)
- `llm/` — vLLM/OpenAI-compatible client, few-shot selection, draft generation, PHI redaction
- `demo/` — dev-only seed/persona utilities (never registered in prod)
- `__tests__/` — Vitest specs (`*.test.ts`)

Migrations live in `apps/api/drizzle/` (numbered SQL). They run at boot when
`RUN_MIGRATIONS_ON_START=true`, coordinated by a Postgres advisory lock and an
idempotent `schema_migrations` table. To add one: edit `db/schema.ts`, run
`npm run db:generate`, register the new migration id in `db/migrate.ts`.

Commands (from `apps/api`):
```bash
npm run dev         # tsx watch — does NOT auto-load .env; export vars in shell
npm run typecheck   # tsc --noEmit
npm run lint        # eslint (typescript-eslint recommended)
npm test            # vitest run
npm run db:generate # drizzle-kit generate (after schema.ts edits)
```

### Prod-safety gate (treat as load-bearing)
`config.ts` refuses to boot in prod on misconfiguration, and demo/dev routes are
**not registered at all** in prod (404, never a guarded 403). When touching
config, auth, or demo routes, preserve these invariants:
- Demo endpoints exist only when `NODE_ENV` is `development`/`test` and not prod.
- Prod requires real inference (`INFERENCE_OPENAI_BASE_URL`) OR an explicit
  `ALLOW_STUB_DRAFTS=true` opt-in — never a silent stub fallback.
- Prod requires DB config, `SONA_WEB_BASE_URL`, `JURISDICTION`, and forbids
  `CORS_ALLOW_LOCALHOST`.

When no LLM endpoint is configured (typical locally), the API gracefully degrades
to deterministic **stub drafts** (`services/stub-draft-content.ts`, marked
`source: "mvp_stub"`).

## Flutter app — `apps/sona`

Mobile-first parent flow + desktop-oriented clinician workspace. Intentionally
simple state management: a single `SonaAppState` (`ChangeNotifier`) plus
enum-based manual routing in `app/sona_app_shell.dart`. **No** Provider/Riverpod/
Bloc/GoRouter. Plain `http` client (no Dio).

Source map (`apps/sona/lib/`):
- `app/` — `main.dart` (Firebase init), `sona_app_shell.dart` (routing/state machine)
- `config/` — `env.dart` (`SONA_API_BASE_URL` dart-define), `firebase_options.dart`
- `design_system/` — color/typography tokens, theme, and `widgets/` (`SonaDateField`, `SonaTextField`, `SonaYesNoField`, `SonaButton`, `SonaStepProgress`…)
- `features/parent/` — 8-step intake + welcome/review/summary/portal screens
- `features/clinician/` — workspace shell + today/clients/intake/triage/prep/summary/carryover/reports/settings
- `features/auth/` — practice onboarding + clinician login / set-password
- `models/` — `intake_form_data.dart`, `intake_template.dart` (full=1–8, short=1–3, followUp=1,6,7)
- `services/` — `api_client.dart` (`SonaApiClient`), `auth/` (Firebase + `AuthedHttpClient` token injection), local draft autosave
- `state/`, `utils/`, `test_utils/`

The parent intake is an **8-step questionnaire** (step 1 paginates 1a/1b on
mobile). `SonaDateField` is keyboard-editable (DD/MM/YYYY) — this matters for E2E
reliability; don't revert it to readonly (see DEV-36 below).

API base URL is a **compile-time** dart-define:
`flutter run -d web-server --web-port=8080 --dart-define=SONA_API_BASE_URL=http://localhost:8081`.

Tests: `flutter test` runs unit (`test/*.dart`) + widget tests
(`test/widget/*.dart`), including `parent_intake_full_flow_test.dart` which drives
all 8 steps against a `MockClient`. `flutter analyze` info-level hints are
expected (CI uses `--no-fatal-infos`).

## E2E — `e2e`

Playwright (Chromium, mobile viewport). Specs in `tests/`, Flutter-web interaction
helpers in `helpers/intake-flow.ts`, test data in `fixtures/`.
```bash
cd e2e && npm install && npx playwright install chromium
npm run test:api     # API-only, fast
npm run test:ui      # browser UI flows
npm run test:full    # everything
# Point at hosted dev: SONA_API_URL=… SONA_WEB_URL=… npm run test:full
```
**Date-picker strategy (DEV-36):** headless Flutter web rendered the Material
date-picker dialog unreliably, so the field was made keyboard-editable and specs
type dates directly (`fillDateField()`); button taps retry until a side effect
confirms (`clickFlutterButtonUntil()`); readiness uses semantics-tree polling, not
sleeps. See `e2e/README.md`.

## Testing layers (where to add a test)

1. **Flutter unit** — validation rules → `apps/sona/test/*_test.dart`
2. **Flutter widget** — screen behavior / step transitions → `apps/sona/test/widget/`
3. **Flutter widget full-flow** — all 8 steps + submit via `MockClient`
4. **API unit/integration (Vitest)** — `apps/api/src/__tests__/*.test.ts`
5. **API E2E (Playwright)** — `e2e/tests/api-*.spec.ts` against a real API
6. **Browser UI E2E (Playwright)** — real Flutter web + clinician dashboard

## CI — `.github/workflows/ci.yml`

Runs on every PR and on pushes to `main`. **All jobs must stay green to merge:**
- **api** — typecheck + Vitest (Node 22)
- **lint** — ESLint over `apps/api` and `e2e` (TypeScript static analysis)
- **flutter** — analyze (`--no-fatal-infos`) + `flutter test` (Flutter 3.44.0 pinned)
- **fhir-conformance** — official HL7 validator vs UK Core STU2 golden Bundle, zero-errors gate
- **npm-audit** — high/critical runtime-dep audit for `apps/api` and `e2e`
- **e2e-smoke** — Postgres 16 service + API (migrations on start) + Flutter web release build + Playwright specs (incl. `parent-intake-full.spec.ts`)

GitHub Actions gates tests; **Cloud Build (`infra/ci/`) handles deploys**.

## Infrastructure & deploy — `infra`

Terraform over GCP. A single composite module `terraform/modules/sona_environment`
orchestrates the per-env stack (network/PSA, KMS/CMEK, Cloud SQL Postgres 16,
Cloud Tasks, Artifact Registry, GCS exports, inference, Firebase Auth);
environment roots live under `terraform/environments/<region>/<env>/`.

**Deploys go through PR → merge → Cloud Build triggers — never `gcloud run
services update` or manual `terraform apply` by hand.** PRs run a Terraform plan;
merge to `main` runs apply (human-approved in GCP Console); `apps/api/**` and
`apps/sona/**` changes trigger app deploys. See `infra/MVP-INFRA.md` and ADRs.

## Docs & ADRs — `docs`

- `docs/decisions/` — ADRs, `NNN-kebab-case.md` (Status / Date / Depends on / Informs). Add one for any architecturally significant decision.
- `docs/compliance/` — DPIA, DSAR runbook, audit retention, subprocessors
- `docs/security/` — hardening checklist, token lifecycle
- `docs/ml/` — triage capture, session-plan & summary generation
- `docs/onboarding/`, `docs/design/`, `docs/strategy/`, `docs/integrations/`
- Root: `mvp-brief.md`, `architecture-gcp-hipaa.md`, `intake-form-spec.md`, `logging-policy.md`, `DEMO.md`

## Guardrails (do not violate)

- **Git workflow:** branch + PR only; never commit directly to `main`. Do not run
  `gcloud`/`terraform apply` to deploy — ship via PR → merge → Cloud Build.
- **PHI safety:** never put intake answers, summaries, or child data in email
  bodies, logs, third-party services, or LLM prompts without redaction. The
  logger allowlists fields; `llm/redact.ts` strips PHI before inference; the
  audit log is append-only. Keep clinical artifacts in the authenticated app / GCS.
- **Prod gate:** keep demo routes out of prod and the config validation strict
  (see API section).
- **Prompt parity:** changes to `apps/api/src/llm/generate-drafts.ts` /
  `intake-context.ts` can break the `speech-ml` eval harness golden snapshots —
  update both together.
- **Personas parity:** synthetic personas are mirrored in `scripts/personas/*.json`,
  `e2e/fixtures/intake-personas.ts`, and `apps/sona/lib/test_utils/intake_personas.dart`,
  with parity tests. Keep the three in sync.
- **Secrets:** never commit `.env`, keys, or `*.tfstate` (see `.gitignore`).

---

## Dev environment

The following assumes the cloud dev VM (also works locally with the same tools).

### Architecture overview

A monorepo with two apps and an E2E suite:

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
- The full parent-intake browser E2E (`parent-intake-full.spec.ts`) is reliable headless and runs in CI (DEV-36). The old date-picker flake is fixed: `SonaDateField` is now keyboard-editable, so the spec types the date straight into the field instead of tapping through the Material date-picker dialog (whose calendar grid rendered unreliably in the headless accessibility tree). Get-started/launcher taps are also retried until they take effect, since Flutter web occasionally swallows the first tap on a freshly-rendered button. See `e2e/README.md` → "Date-picker E2E strategy".
- The LLM inference service (`INFERENCE_OPENAI_BASE_URL`) is not available locally — the API gracefully degrades and uses stub drafts.
- Migrations run automatically on API start when `RUN_MIGRATIONS_ON_START=true`.

### Continuous integration

GitHub Actions (`.github/workflows/ci.yml`) runs on every PR and on pushes to `main`:

1. **api** — `npm run typecheck` + `npm test` (Vitest) in `apps/api` on Node 22.
2. **flutter** — `flutter analyze --no-fatal-infos` + `flutter test` in `apps/sona` (Flutter 3.44.0, pinned).
3. **e2e-smoke** — Postgres 16 service container, API booted via `tsx` with `RUN_MIGRATIONS_ON_START=true`, Flutter web release build served statically, then the Playwright smoke + API specs. This includes `parent-intake-full.spec.ts` (the full browser intake-through-submit flow) now that its date-picker flake is fixed (Linear DEV-36).

Keep these green: a PR that breaks any job should not merge. Cloud Build (`infra/ci/`) handles deploys; GitHub Actions handles test gating.

### Lint, typecheck & tests

- **API typecheck**: `cd apps/api && npx tsc --noEmit`
- **TS lint (ESLint)**: `cd apps/api && npm run lint` (and `cd e2e && npm run lint`)
- **Flutter analyze**: `cd apps/sona && flutter analyze` (info-level lint hints are expected, not errors)
- **Flutter unit/widget tests**: `cd apps/sona && flutter test` (includes full 8-step intake flow widget test)
- **E2E tests (Playwright)**: `cd e2e && SONA_API_URL=http://localhost:8081 SONA_WEB_URL=http://localhost:8080 npx playwright test`
- **Flutter integration tests** (requires chromedriver + running web server):
  ```bash
  chromedriver --port=4444 &
  cd apps/sona
  flutter drive --driver=test_driver/integration_test.dart \
    --target=integration_test/<test_file>.dart \
    -d web-server --browser-name=chrome --headless --web-port=8090
  ```
- **Pre-PR sanity**: `scripts/pre-deploy-verify.ps1` (Flutter tests + API typecheck + API E2E).

### Chromedriver

Chromedriver is installed at `/usr/local/bin/chromedriver`, version-matched to the VM's Chrome. The update script auto-updates it when Chrome changes.

### Local database credentials

- User: `sona_app` / Password: `sona_dev_pass`
- Database: `sona`
- Connection: `postgresql://sona_app:sona_dev_pass@127.0.0.1:5432/sona`

### Flutter SDK

Flutter 3.44.0 (Dart 3.12.0) is installed at `/opt/flutter/bin`. It is on PATH via `~/.bashrc`.

### Session setup

A `SessionStart` hook (`.claude/settings.json` → `scripts/cloud_session_deps.sh`)
installs npm/pub deps on each cloud session.
