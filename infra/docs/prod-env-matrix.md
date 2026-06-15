# Production environment matrix & boot-time safety gate (DEV-45)

Authoritative list of the API's environment variables, what they must be in
production, and the **refuse-to-boot** rules that make dev conveniences provably
absent in prod. This is part of the **Go-Live Compliance Gate** ("no shortcuts
for real use") and supports ADR-007 (managed Vertex inference).

The runtime enforces the prod rules below in `validateConfig()` (pure, in
`apps/api/src/config.ts`, called by `loadEnv()` at boot). If any prod rule is
violated the process **refuses to start** with a `ConfigValidationError` listing
every problem — it does not silently downgrade.

## What "production" means here

`NODE_ENV` is set to `production` by the Node runtime/bundler for *any* deployed
build, including a deployed dev/staging Cloud Run service. To tell a real prod
stack apart from a non-prod deployed stack we use **`SONA_ENV`**:

- `isProdEnv(env)` is **true** when `SONA_ENV` is `prod`/`production`, or — if
  `SONA_ENV` is unset — when `NODE_ENV=production`.
- `SONA_ENV` of `dev`/`development`/`staging`/`stage` marks a **non-prod** stack
  even though `NODE_ENV` is `production` in the bundle.

Set `SONA_ENV=prod` explicitly on the production service. Deployed non-prod
stacks that need the demo endpoints must run with `NODE_ENV=development` (the
demo-route gate keys off `NODE_ENV` being `development`/`test`).

## Refuse-to-boot rules (production only)

| Rule | Why |
|---|---|
| `CORS_ALLOW_LOCALHOST` must be `false` | A localhost browser-origin allowance in prod is always a mistake. |
| Inference: `INFERENCE_OPENAI_BASE_URL` set **OR** `ALLOW_STUB_DRAFTS=true` | Per ADR-007 the pilot uses managed Vertex (OpenAI-compatible endpoint). Without a real endpoint and without the deliberate stub opt-in, prod would silently serve **stub AI drafts** — refused. |
| A database is configured: `DATABASE_URL` **OR** (`DB_HOST` + `DB_PASSWORD`) | Prod cannot run without its datastore. |
| `SONA_WEB_BASE_URL` set | Used to build intake/portal magic-links; a wrong/empty base URL breaks family comms. |
| `JURISDICTION` set (`uk`/`us`) | Data-residency / jurisdiction stack selector (ADR-001). |

`ALLOW_STUB_DRAFTS=true` is the **documented, deliberate** escape hatch for an
eyes-open non-clinical prod (e.g. an infra smoke stack with no real patients).
Do **not** set it on a real clinical production service.

## Demo / dev-maintenance endpoints

The `POST /v1/demo/bootstrap`, `/v1/demo/seed-canonical`, and
`/v1/demo/cleanup-e2e-test-cases` routes are **not registered at all** unless
`demoRoutesEnabled(env)` is true (`NODE_ENV` is `development`/`test` and not a
prod `SONA_ENV`). In production they return **404 (route absent)**, never 403.
This is a stronger guarantee than the previous in-handler `isDevMaintenanceAllowed`
check (which is retained as defence-in-depth for the hosted `-dev` Cloud Run).

## `RUN_MIGRATIONS_ON_START` policy

Dev and CI rely on boot-time migrations, so the flag stays and defaults to
`true`. **In production, migrations SHOULD run as an explicit, gated deploy step**
(a dedicated migrate job/command), not on boot — boot-time migration races
rolling/parallel instances against schema changes. Recommended prod value:
`RUN_MIGRATIONS_ON_START=false`. If it is set/true in prod the API logs a clear
warning (`run_migrations_on_start_enabled_in_prod`) so it is a conscious choice,
not an accident. The flag is intentionally not removed.

## Full env var matrix

| Variable | Required in prod? | Dev default | Prod value / source | Notes |
|---|---|---|---|---|
| `PORT` | no | `8080` | platform-provided (Cloud Run) | — |
| `NODE_ENV` | yes | `development` | `production` | Set by runtime/bundler for any deployed build. |
| `SONA_ENV` | recommended | unset | `prod` | Distinguishes real prod from deployed dev/staging. Unset ⇒ falls back to `NODE_ENV`. |
| `JURISDICTION` | **yes** | `uk` | `uk` / `us` | Data-residency stack (ADR-001). |
| `SONA_MODE` | yes | `api` | `api` / `worker` | Selects route set. |
| `GCP_PROJECT_ID` | per deploy | unset | Terraform | — |
| `GCP_REGION` | per deploy | `europe-west2` | `europe-west2` | Region-pin (ADR-001/ADR-007 §4). |
| `CLOUD_SQL_CONNECTION_NAME` | per deploy | unset | Terraform | Cloud SQL socket. |
| `DATABASE_URL` | **yes** (or DB_* pair) | local pg URL | **Secret Manager** | Full DSN; takes precedence over DB_* parts. |
| `DB_HOST` | **yes** if no `DATABASE_URL` | unset | Terraform / socket | — |
| `DB_NAME` | yes | `sona` | `sona` | — |
| `DB_USER` | yes | `sona_app` | runtime SA user | — |
| `DB_PASSWORD` | **yes** if no `DATABASE_URL` | unset | **Secret Manager** | Never logged. |
| `INFERENCE_OPENAI_BASE_URL` | **yes** unless `ALLOW_STUB_DRAFTS` | unset (stub) | Vertex OpenAI-compatible endpoint (PSC) | ADR-007. Empty string treated as unset. |
| `ALLOW_STUB_DRAFTS` | opt-in | `false` | `false` (real clinical prod) | Deliberate escape hatch; only for non-clinical prod. |
| `LLM_MODEL` | per deploy | unset | e.g. `gemini-1.5-flash` | — |
| `LLM_API_KEY` | per deploy | unset | **Secret Manager** | Bearer for the inference endpoint. Never logged. |
| `SONA_WEB_BASE_URL` | **yes** | falls back to localhost | `https://app...` | Builds intake/portal links. |
| `LLM_CLOUD_TASKS_QUEUE` | per deploy | `sona-llm-dev` | prod queue name | — |
| `RUNTIME_SERVICE_ACCOUNT` | per deploy | unset | Terraform | — |
| `WORKER_SERVICE_URL` | per deploy | unset | Cloud Run URL | Worker dispatch target. |
| `MAILGUN_API_KEY` | for email | unset | **Secret Manager** | Notification-only email (ADR-005). Never logged. |
| `MAILGUN_DOMAIN` | for email | unset | Terraform | — |
| `MAILGUN_FROM_EMAIL` | for email | unset | config | — |
| `MAILGUN_BASE_URL` | for email | US default | EU base for UK | `https://api.eu.mailgun.net`. |
| `RUN_MIGRATIONS_ON_START` | policy | `true` | **`false`** (run as deploy step) | Warns if `true` in prod. |
| `CORS_ORIGINS` | **yes** (web clients) | unset | `https://app.example.com,...` | Exact allowlist; no wildcards. |
| `CORS_ALLOW_LOCALHOST` | **must be false** | `false` | `false` | Refuses to boot if `true` in prod. |
| `RATE_LIMIT_TOKEN_MAX` | no | `30` | tune per load | Per-IP magic-link limit. |
| `RATE_LIMIT_TOKEN_WINDOW_MS` | no | `60000` | tune | — |
| `RATE_LIMIT_ENABLED` | recommended `true` | `true` | `true` | `false` only for load tests. |

## See also

- ADR-007 — managed Vertex Gemini inference (`docs/decisions/007-vertex-gemini-managed-inference.md`)
- ADR-001 — data residency / jurisdiction stacks
- `apps/api/src/config.ts` — `validateConfig`, `isProdEnv`, `demoRoutesEnabled`
