# CLAUDE.md

Guidance for AI assistants (Claude Code, Cursor) working in this repository.
See also `AGENTS.md` (Cursor Cloud / local dev env specifics) and `.cursor/rules/`
(always-on workflow + security rules). When this file and `AGENTS.md` overlap,
both are authoritative; `AGENTS.md` is the source of truth for the dev VM setup.

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

## Dev environment quick reference

See `AGENTS.md` for full detail. Essentials:
- Local Postgres: `postgresql://sona_app:sona_dev_pass@127.0.0.1:5432/sona`
- API needs env vars `export`ed (tsx does not read `.env`).
- Flutter 3.44.0 at `/opt/flutter/bin`; chromedriver at `/usr/local/bin/chromedriver`.
- A `SessionStart` hook (`.claude/settings.json` → `scripts/cloud_session_deps.sh`)
  installs npm/pub deps each session.
- Pre-PR sanity: `scripts/pre-deploy-verify.ps1` (Flutter tests + API typecheck + API E2E).
