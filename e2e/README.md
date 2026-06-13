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

1. **Flutter unit tests** — valid intake passes all 8 steps; JSON omits null keys; bootstrap HTTP 200/201 accepted (skipped if `flutter` not on PATH)
2. **API TypeScript typecheck**
3. **Playwright API specs** — bootstrap, create case, draft, full submit, case appears in tenant list

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
| `tests/parent-intake-smoke.spec.ts` | Parent intake UI → Get started → step 1 (no `SonaApiException`) |
| `tests/parent-intake-full.spec.ts` | **Full browser flow** — real parent UI starts a session and fills step 1 *including the date-of-birth field typed in the browser*, the full intake is submitted via the same API the app calls, and the clinician UI Refresh shows the child's case with status |

### Why the full E2E is part-UI, part-API

The full spec walks the parent through Get started in real Flutter web, fills the
step-1 "About you & your child" fields **in the browser** (most importantly the
date-of-birth field — see below), captures the live `caseId`, then submits the
remaining deep history steps (4–8, dozens of below-the-fold fields) via the exact
same API endpoint the Flutter app calls. The clinician dashboard is then verified
through real UI navigation + Refresh.

This keeps the spec hermetic and fast: it proves the load-bearing UI surface
(start a session + enter & commit the trickiest field) without re-litigating
Flutter web's virtualised-list quirks for every one of the ~70 fields (those are
covered deterministically by the Dart widget full-flow test,
`apps/sona/test/widget/parent_intake_full_flow_test.dart`).

```
Parent UI  →  POST /v1/demo/bootstrap           (real, retried until it fires)
Parent UI  →  POST /v1/cases                     (real)
Parent UI  →  type Email / Child's name / DOB    (real — keyboard entry)
API call   →  PUT  /v1/cases/{id}/intake/draft   (same as Flutter)
API call   →  POST /v1/cases/{id}/intake         (same as Flutter)
Clinician UI → GET /v1/tenants/{id}/cases        (real)
Clinician UI → Refresh button → case appears     (real)
```

Each run bootstraps its own demo tenant and uses a unique child name, so repeated
runs never collide (hermetic). The shared cleanup endpoint
`POST /v1/demo/cleanup-e2e-test-cases` can prune accumulated `Child <id>` rows.

### Date-picker E2E strategy (DEV-36)

The full spec used to time out on the date-of-birth step in headless Chromium and
was excluded from CI. **Root cause:** `SonaDateField` was `readOnly`, so the only
way to set a value was to tap the calendar icon and drive the Material
date-picker dialog. That dialog's calendar grid renders unreliably in headless
Flutter web's accessibility tree, so the tap/grid interaction would hang until
the test timed out. (The Get-started / launcher taps had a related issue: Flutter
web occasionally swallows the *first* tap on a freshly-rendered button while its
gesture handler is still attaching.)

**Fix (most durable option):**

- `SonaDateField` is now **keyboard-editable**. The date is typed straight into
  the field via the same shared-input path as every other text field (see
  `helpers/intake-flow.ts` → `fillDateField` / `fillLabeledField`), so we never
  open the picker dialog in tests. The calendar icon still opens the Material
  picker for users who prefer it — visible behaviour is unchanged, the field just
  *also* accepts typing now (a small UX win). The widget reports changes via both
  `onChanged` and a controller listener, with the same stale-value guard as
  `SonaTextField`, so fast `pressSequentially` keystrokes commit reliably.
- Button taps go through `clickFlutterButtonUntil`, which retries the tap until it
  produces its side effect (e.g. the bootstrap API call fires), instead of
  assuming a single `.click()` lands.
- Readiness uses semantics-node polling (`waitForSemanticsTree`) rather than fixed
  sleeps.

Result: 10/10 consecutive headless passes locally; the spec now runs in CI.

Shared fixtures: `fixtures/valid-intake.ts` (mirrors `apps/sona/test/fixtures/valid_intake_fixture.dart`).

## Layered Flutter test strategy

Parent-intake correctness is guarded at four layers, cheapest first:

| Layer | Where | What it catches | Run with |
|---|---|---|---|
| **Unit** | `apps/sona/test/intake_form_validation_test.dart` | `IntakeFormData.validateStep` rules per step | `flutter test` |
| **Widget** | `apps/sona/test/widget/sona_text_field_test.dart`, `apps/sona/test/widget/parent_intake_step_screen_test.dart` | Substep transitions, pop-back, controller-listener race | `flutter test` |
| **Widget full-flow** | `apps/sona/test/widget/parent_intake_full_flow_test.dart` | All 8 steps + submit driven via `WidgetTester.enterText` against a `MockClient`-backed API. Deterministic safety net for the demo-blocker fix shipped in PR #21. | `flutter test` |
| **API E2E** | `e2e/tests/api-bootstrap.spec.ts`, `e2e/tests/intake-api-full.spec.ts` | Real Cloud Run API; full draft + submit + tenant list | `npm run test:api` |
| **Browser UI E2E** | `e2e/tests/parent-intake-smoke.spec.ts`, `e2e/tests/parent-intake-full.spec.ts` | Real Flutter web for Get started, step-1 entry (incl. typed date), submit, and clinician dashboard refresh | `npm run test:ui` |

`apps/sona/integration_test/` and `apps/sona/test_driver/integration_test.dart` are scaffolded so a chromedriver-backed integration test (the long-term replacement for the brittle Playwright UI flow on Flutter web) can drop in without infra changes. See `apps/sona/integration_test/README.md` for the run command.

## Reports

```bash
npm run report
```

## Notes

- First Flutter web load can take **30–60s**. Timeouts are generous.
- Tests click **Enable accessibility** so buttons/inputs appear in the DOM.
- Date fields are **typed into directly** (`SonaDateField` is keyboard-editable);
  the Material date-picker dialog is avoided in tests — see "Date-picker E2E
  strategy" above. The legacy `pickDateInOpenDialog`/`pickDateByLabel` helpers
  remain only for any test that explicitly exercises the calendar-icon path.
- Mobile viewport (430×932) matches the parent intake layout.
- Case rows on the clinician dashboard are buttons with the child name in their accessibility label — use `getByRole("button", { name })` to match, not `getByText`.
