# scripts/

One-off developer scripts and API test payloads used during local debugging
of the Sona Speech MVP. None of these run in CI; they exist as ready-made
inputs for ad-hoc verification against the dev API or for re-running design
tweaks against Figma.

## Pre-deploy verify

| Script | Purpose |
|---|---|
| `pre-deploy-verify.ps1` | Fast local check that runs the critical Flutter unit tests (when SDK is on PATH), API typecheck, and the Playwright API-only intake suite before opening a PR. Run from the repo root: `pwsh scripts/pre-deploy-verify.ps1`. |
| `sync-agent-skills.ps1` | Refresh the per-workspace Cursor agent skills under `.cursor/skills/`. |

## Synthetic intake personas

| Location | Role |
|---|---|
| `scripts/personas/*.json` | **Canonical** persona definitions (one file per persona). |
| `e2e/fixtures/intake-personas.ts` | TypeScript mirror — imported by Playwright specs. |
| `apps/sona/lib/test_utils/intake_personas.dart` | Dart mirror — imported by widget / integration tests and the dev-only "Fill with sample data" affordance on parent welcome. |

Parity across the three is asserted by:

- `e2e/tests/personas-parity.spec.ts` — JSON ↔ TS.
- `apps/sona/test/intake_personas_parity_test.dart` — JSON ↔ Dart.
- `apps/sona/test/intake_personas_validation_test.dart` — every persona passes the 8-step intake validator.

**Synthetic only.** Never replace these with real client data. PHI guardrails
(`docs/mvp-brief.md` + `.cursor/rules/mvp-security-reminder.mdc`) still apply.

### Seed the dev API

```bash
# Local API
SONA_API_URL=http://localhost:8081 npx tsx scripts/seed-dev.ts

# Hosted dev (synthetic only — never prod)
SONA_API_URL=https://sona-api-dev-3rhenudy6a-nw.a.run.app \
  SEED_STAGES=intake_submitted,prep_ready,triaged,plan_ready \
  SEED_PER_STAGE=1 \
  npx tsx scripts/seed-dev.ts

# Just a couple of personas
PERSONAS=aria_speech_sounds_4yo,theo_feeding_3yo \
  npx tsx scripts/seed-dev.ts
```

`scripts/seed-dev.ts` refuses to run against any URL containing `prod` /
`production`. Run it before manually exercising the clinician dashboard so
there's data to render.

### One-off: remove legacy E2E test cases from Postgres

After renaming test children to `Child`, clear old `E2E Child …` rows (and related ephemeral seed suffixes) from dev/stage:

```bash
cd apps/api
DATABASE_URL=postgresql://... npx tsx scripts/cleanup-e2e-test-cases.ts --dry-run
DATABASE_URL=postgresql://... npx tsx scripts/cleanup-e2e-test-cases.ts
```

Uses Cloud SQL Auth Proxy against hosted dev when needed. Refuses prod-looking URLs. Does not delete canonical demo personas (Aria M., etc.).

## Intake API test payloads

Use these with `curl` or any HTTP client against `apps/api` (locally or the
dev Cloud Run URL). They cover the demo bootstrap / case-creation / intake
draft + submit happy path and a few edge cases. They are intentionally
small, plain JSON files so anyone can `cat` them into a request body.

| File | Endpoint | Notes |
|---|---|---|
| `boot.json` | `POST /v1/demo/bootstrap` | Re-issues the dev tenant + jurisdiction context. |
| `test-case-min.json` | `POST /v1/cases` | Minimum-viable case payload. Replace `tenantId` before use. |
| `test-case-null-email.json` | `POST /v1/cases` | Reproduces the original `parentEmail: null` 400 we fixed in PR #16. |
| `test-create-case.json` | `POST /v1/cases` | Realistic case with a test parent and child. |
| `test-intake-e2e.json` | `PUT /v1/intake/{caseId}/draft` then `POST /v1/intake/{caseId}` | Complete 8-step intake answers for a "Jane Test" parent and "Alex Test" child. Mirrors `e2e/fixtures/valid-intake.ts`. |

Example:

```bash
# Local dev API
API=http://localhost:8081
BOOT=$(curl -sS -X POST "$API/v1/demo/bootstrap" -H 'content-type: application/json' --data @scripts/boot.json)
TENANT=$(echo "$BOOT" | jq -r .tenantId)

CASE=$(jq --arg t "$TENANT" '.tenantId=$t' scripts/test-create-case.json \
  | curl -sS -X POST "$API/v1/cases" -H 'content-type: application/json' -d @- )
CASE_ID=$(echo "$CASE" | jq -r .id)

curl -sS -X PUT "$API/v1/intake/$CASE_ID/draft" -H 'content-type: application/json' \
  -d @scripts/test-intake-e2e.json

curl -sS -X POST "$API/v1/intake/$CASE_ID" -H 'content-type: application/json' \
  -d @scripts/test-intake-e2e.json
```

## Figma maintenance (design only)

| Script | Purpose |
|---|---|
| `figma-rebuild-page2.js` | Builds the 2/8 difficulty-checklist screen in the MVP Figma file from scratch (all 21 options + 4 section headers). Run as `figma.run(...)` content via the `use_figma` MCP tool. |
| `figma-polish-page2.js` | Re-applies Sona design tokens (typography, colours, spacing) to the 2/8 frame so it matches page 1. |

These are pure design-time tooling; they do not touch any application
code or data. Keep them for future Figma cleanups when the design system
evolves.
