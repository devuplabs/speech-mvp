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
