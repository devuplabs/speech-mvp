# Sona web E2E (Playwright)

Automated tests for the hosted Flutter web app and dev API. Run **before merging** PRs that touch intake, API, or Flutter web.

## Setup (once)

```bash
cd e2e
npm install
npx playwright install chromium
```

## Pre-deploy verify (run before every PR)

From repo root (~10s if Flutter SDK is on PATH, otherwise skip step 1):

```powershell
.\scripts\pre-deploy-verify.ps1
```

This runs:

1. **Flutter unit + widget tests** — valid intake, 8-step persona-driven flow, clinician prep / triage / session plan / parent-summary widget tests (skipped if `flutter` not on PATH).
2. **API TypeScript typecheck**.
3. **API Vitest unit tests** — prep brief, session plan, parent-summary HTML + text generators.
4. **Playwright API specs** — bootstrap, intake, triage, session plan, parent summary preview/publish/PDF, and the full MVP happy-path E2E.
5. **Persona parity (TS ↔ JSON)** — guards `scripts/personas/*.json` and `e2e/fixtures/intake-personas.ts` against drift.

## Full test matrix

| Command | What it checks | Time |
|---------|----------------|------|
| `npm run test:api` | API-only specs (no browser) | ~5s |
| `npm run test:ui` | Get started smoke + hybrid full demo flow | ~4 min |
| `npm run test:full` | Everything above | ~4 min |

Hosted dev is the default target:

```bash
cd e2e
npm run test:api      # before every PR (fast, no browser)
npm run test:full     # before demo / after major UI change
```

Optional env overrides:

```bash
SONA_WEB_URL=https://sona-web-dev-3rhenudy6a-nw.a.run.app \
SONA_API_URL=https://sona-api-dev-3rhenudy6a-nw.a.run.app \
npm run test:full
```

## Tests

| File | What it checks |
|------|----------------|
| `tests/api-bootstrap.spec.ts` | Bootstrap 200/201, create case (with and without parentEmail), save draft |
| `tests/intake-api-full.spec.ts` | Full answers payload draft + submit; case visible in tenant list with the child name |
| `tests/triage-api.spec.ts` | 4 outcomes accepted; unknown rejected; triage[] surfaces in GET; repeat triage allowed (audit trail) |
| `tests/session-plan-api.spec.ts` | PUT /session-plan persists sections + reviewStatus; per-bullet validation; 404 + 409 error paths |
| `tests/parent-summary-api.spec.ts` | Preview returns html + projection; tone/section/AI-disclosure toggles flip output; publish persists options; PDF magic bytes valid |
| `tests/mvp-happy-path.spec.ts` | **Pure-API end-to-end happy path** — intake submit → dashboard → prep brief → triage → session plan edit (final) → preview summary → publish → portal HTML → PDF download. Runs in ~150ms. Deploy verification for the entire MVP loop. |
| `tests/personas-parity.spec.ts` | JSON ↔ TS persona parity (sister to `apps/sona/test/intake_personas_parity_test.dart`) |
| `tests/parent-intake-smoke.spec.ts` | Parent intake UI → Get started → step 1 (no `SonaApiException`) |
| `tests/parent-intake-full.spec.ts` | **Hybrid demo flow** — real parent UI starts a session, identical API path submits the full intake, clinician UI Refresh shows the child's case with status |

### Why hybrid full E2E

The full UI walks the parent through Get started in real Flutter web, captures the live `caseId`, then submits the answers via the exact same API endpoint the Flutter app calls. The clinician dashboard is verified through real UI navigation + Refresh.

This avoids fragility from Flutter web's accessibility tree (off-screen fields, virtualised lists) while still proving the demo pipeline end-to-end:

```
Parent UI  →  POST /v1/demo/bootstrap         (real)
Parent UI  →  POST /v1/cases                  (real)
API call   →  PUT  /v1/cases/{id}/intake/draft  (same as Flutter)
API call   →  POST /v1/cases/{id}/intake        (same as Flutter)
Clinician UI → GET /v1/tenants/{id}/cases     (real)
Clinician UI → Refresh button → case appears   (real)
```

Shared fixtures: `fixtures/valid-intake.ts` (mirrors `apps/sona/test/fixtures/valid_intake_fixture.dart`).

## Layered Flutter test strategy

Parent-intake correctness is guarded at four layers, cheapest first:

| Layer | Where | What it catches | Run with |
|---|---|---|---|
| **Unit** | `apps/sona/test/intake_form_validation_test.dart` | `IntakeFormData.validateStep` rules per step | `flutter test` |
| **Widget** | `apps/sona/test/widget/sona_text_field_test.dart`, `apps/sona/test/widget/parent_intake_step_screen_test.dart` | Substep transitions, pop-back, controller-listener race | `flutter test` |
| **Widget full-flow** | `apps/sona/test/widget/parent_intake_full_flow_test.dart` | All 8 steps + submit driven via `WidgetTester.enterText` against a `MockClient`-backed API. Deterministic safety net for the demo-blocker fix shipped in PR #21. | `flutter test` |
| **Widget personas full-flow** | `apps/sona/test/widget/parent_intake_personas_flow_test.dart` | Same 8-step flow looped over every synthetic persona — adding a new persona to `scripts/personas/` automatically extends coverage. | `flutter test` |
| **Clinician screen widget tests** | `apps/sona/test/widget/clinician_{prep,triage,session_plan,parent_summary}_screen_test.dart` | Live data render, action callbacks, rehydration, gating between stages. | `flutter test` |
| **API E2E (single-endpoint)** | `e2e/tests/api-bootstrap.spec.ts`, `e2e/tests/intake-api-full.spec.ts`, `e2e/tests/triage-api.spec.ts`, `e2e/tests/session-plan-api.spec.ts`, `e2e/tests/parent-summary-api.spec.ts` | Per-endpoint coverage of validation, persistence, error paths. | `npm run test:api` |
| **API E2E (full flow)** | `e2e/tests/mvp-happy-path.spec.ts` | Intake → dashboard → prep → triage → plan → summary → PDF, one persona, ~150 ms. The deploy-verification net for the whole MVP loop. | `npm run test:api` |
| **Hybrid UI E2E** | `e2e/tests/parent-intake-smoke.spec.ts`, `e2e/tests/parent-intake-full.spec.ts` | Real Flutter web for Get started + real clinician dashboard refresh | `npm run test:ui` |

`apps/sona/integration_test/` and `apps/sona/test_driver/integration_test.dart` are scaffolded so a chromedriver-backed integration test (the long-term replacement for the brittle Playwright UI flow on Flutter web) can drop in without infra changes. See `apps/sona/integration_test/README.md` for the run command.

## Reports

```bash
npm run report
```

## Notes

- First Flutter web load can take **30–60s**. Timeouts are generous.
- Tests click **Enable accessibility** so buttons/inputs appear in the DOM.
- Date pickers use Flutter web **day buttons** (not `gridcell`).
- Mobile viewport (430×932) matches the parent intake layout.
- Case rows on the clinician dashboard are buttons with the child name in their accessibility label — use `getByRole("button", { name })` to match, not `getByText`.
