# Sona — Intake → Clinician Flow Bug Bash: Agent Brief

> **For:** an Opus 4.7 agent running in this Cursor workspace with the local stack runnable per `AGENTS.md`, the **Chrome DevTools MCP** (`browser-testing-with-devtools` skill), Playwright (`e2e/`), and Flutter widget tests.
> **Goal:** Systematically hunt, log, and fix **basic, demo-blocking bugs** in the parent intake → submit → clinician dashboard → case-detail flow. No new features. No architecture work. The bar is "a clinician demoing this to a peer doesn't get embarrassed by an obvious bug."

---

## 1. Mission

A live demo on **2026-05-29** surfaced three concrete bugs. They are symptoms of a wider class of basic UX/data-integrity bugs in the intake → clinician loop. Your job is to:

1. **Reproduce** the three known bugs end-to-end and pin their root cause.
2. **Hunt** for similar issues by methodically walking the same flow with the personas (Aria, Jaden, Mia, Theo), with intentionally-bad input, and with two cases in a row to catch state leakage.
3. **Log every bug** in a single, structured file in the repo before fixing anything.
4. **Fix bugs one at a time**, smallest first, each with a regression test and an isolated commit.
5. **Ship via a single PR** unless the bug list grows past ~10 — then split (see §7).

This is a **stabilisation pass**, not a redesign. Resist the urge to refactor, restyle, or add features. If you find a deeper architectural problem, **log it as `severity: design-debt`** and keep moving.

---

## 2. The three known bugs (must be in the log on Day 1)

### BUG-1 — Text-box contents disappear when scrolling or toggling checkboxes

**Symptom (user-reported, demo 2026-05-29):**
> "The text-box text disappears when scrolling up and down the parent intake form, or when you check any checkboxes below."

**Where to look:**

- `apps/sona/lib/design_system/widgets/sona_text_field.dart` — stateful widget with a `TextEditingController`. The comment block at lines 35–39 already flags Flutter web IME quirks. The `didUpdateWidget` (lines 60–68) overwrites the controller with `widget.value` when they diverge — which means if a parent rebuild passes a **stale** `widget.value`, typed text is destroyed.
- `apps/sona/lib/features/parent/intake/parent_intake_step_screen.dart` — `_scrollBody` uses a plain `ListView` (line 337). Default `ListView(children: [...])` keeps children mounted, so this isn't virtualisation. The likely culprit is that some text field's `onChanged` does **not** propagate to `state.intake.X` synchronously, and a checkbox `setState` triggers a parent rebuild that ships the stale value back down.
- `apps/sona/lib/features/parent/intake/difficulty_checklist.dart` — a checkbox change here is the most likely trigger reported in the demo.

**Hypotheses to test (in order):**

1. Some text fields in the step screen call `onChanged` with a value that is not immediately persisted to `state.intake` (e.g., debounced, only on blur, or only on submit).
2. A field is missing a stable `Key` so `ListView` reorders mistakenly re-instantiate the widget on rebuild.
3. Browser autofill or paste fires a synthetic event that the controller listener filters out via `_suppressListener`.

**Repro recipe:**

1. Open the parent intake on a fresh case.
2. Type into the "main concern" long-text field on the relevant step.
3. **Without leaving the field**, scroll the form up and back, then check a box in the difficulty checklist below.
4. Verify the typed text is still visible.
5. Repeat with each text field on each step.

---

### BUG-2 — Validation error "Please check your answers" is uselessly generic

**Symptom:**
> "Sometimes when filling the form it errors out and says 'Error: Please check your answers'. This is not helpful — the user has no idea which field is wrong."

**Where to look:**

- `apps/sona/lib/utils/api_errors.dart` — `friendlyApiError()` already half-parses the API's `validation_failed` envelope (`{ issues: { fieldErrors: {...} } }`) and produces `Please check your answers (<firstFieldKey>).`. Problems:
  1. It surfaces only the **first** field, not all failing fields.
  2. The field **key** ("gpPhone") is shown to the user, not a human label ("GP phone number").
  3. The fallback `'Some answers are invalid…'` fires when the body is `validation_failed` but `fieldErrors` is empty or shaped differently — likely the demo case.
  4. The user is left on whatever screen they were on; the form doesn't scroll to or highlight the offending field.
- API validation source: `apps/api/src/routes/v1.ts` (intake submit / step handlers) and any Zod schemas under `apps/api/src/services/` — confirm the shape of the validation error response.
- `apps/sona/lib/features/parent/intake/parent_intake_step_screen.dart` already has `_errorTextFor` + `_maybeScrollToPendingValidation` for in-form, per-field errors. Question: are server-side validation failures routed through that pipeline, or does the user only see the top-level snackbar/banner?

**Acceptance for the fix:**

- All failing field labels (not keys) shown, e.g. "Please fix: mother's email (not a valid email), GP phone (required)."
- Form auto-scrolls to the first offending field and shows the field-level error inline (reuse `pendingValidationFieldKey` / `pendingValidationMessage`).
- If the error envelope is unparseable, fall back to a message that says **what the server actually returned** (status code + short body excerpt) so the user can at least screenshot something useful.

---

### BUG-3 — Clinician dashboard → case detail shows wrong case (often Aria)

**Symptom:**
> "When the form is filled it shows up in the dashboard. But when you click on it, it shows random data — most of the time it's Aria. There was a recent fix for this. I need to make sure that from intake to the end of the flow, the same data is used. If the AI stub is used, modify the stub accordingly for the user."

**Where to look:**

- A partial fix landed in commit on `main` (see `apps/sona/test/widget/clinician_screens_uses_case_detail_test.dart`). The prep screen now reads from a `caseDetail` map shaped `{case, intake, drafts}` instead of hard-coding "Aria M." Verify the same fix has been applied to **every** clinician screen:
  - `apps/sona/lib/features/clinician/clinician_prep_screen.dart` ✅ (verify)
  - `apps/sona/lib/features/clinician/clinician_triage_screen.dart` (verify — referenced in the new test)
  - `apps/sona/lib/features/clinician/clinician_parent_summary_screen.dart` (verify — referenced in the new test)
  - `apps/sona/lib/features/clinician/clinician_intake_review_screen.dart` (audit — may still be reading from a different source)
  - Any session-plan / report screens reachable from the case
- `apps/sona/lib/app/sona_app_shell.dart` — confirm `_refreshCase()` is called on **every** Today/Clients row tap, and that navigating from case A to case B fully replaces `caseDetail` (no stale read while the new fetch is in flight).
- **AI stub** — `apps/api/src/services/prep-brief.ts` lines 27–35: the stub `probeAreas` are generic placeholders ("Confirm primary concern…", "Check red flags…") that don't reference the case's intake. Same likely true for `session-plan.ts`, `parent-summary.ts`. When the LLM is unavailable, the demo will show identical AI text for every child, which **looks like** the Aria bug from the outside. Fix: make each stub interpolate at minimum the child's name + primary concern + age band, drawn from `loadIntakeAnswers()`. Each stub is ~30 lines — keep it deterministic, no randomness.

**Acceptance for the fix:**

- A widget test loads case A (e.g., a freshly-submitted custom case from the parent flow) and asserts the child name, parent email, main concern, and at least one difficulty render on prep, triage, and parent-summary screens.
- The test loads case B (Jaden) and asserts Aria's name and Aria's main concern appear **nowhere** in the rendered tree.
- An API test asserts the `prep_brief` stub for case A references case A's `childDisplayName` and `mainConcern`, not Aria's.
- End-to-end via Playwright: submit a custom-named intake → see that name on the dashboard → click → see that name everywhere on the prep screen → never see "Aria" on the page.

---

## 3. Scope

### In scope (must be tested)

The full **intake → clinician** loop, on Chrome (Flutter web), at the screen and API level:

1. Parent intake — `/intake/...` deep link → 8 steps → review → submit. All four personas plus one hand-typed custom case.
2. Clinician dashboard — `Today`, `Clients`, `Intake forms`, `Reports`. Click each list row.
3. Case detail screens — Prep, Triage, Session plan, Parent summary (preview + send), Intake review.
4. Round-tripping — back-arrow / browser back / direct deep link to a case URL.
5. The two-case sanity test — open case A, then case B, then case A again. State must never bleed.

### Out of scope (do **not** touch)

- Authentication, magic-link flows, NHS Login, GP integration.
- Pricing, billing, multi-tenancy.
- New screens or new fields.
- LLM prompt engineering beyond the stub deterministic interpolation in BUG-3.
- Infra/Terraform/Cloud Build.
- The strategy review brief (`docs/strategy/*`).
- Any refactor "while you're in there." If it's not on the bug log, do not change it.

---

## 4. Test methodology

Use **all three** layers. Each bug should be reproduced at the highest layer first (browser), then have a regression test added at the lowest layer that catches it (widget or API).

### 4.1 Browser-driven exploratory test (Chrome DevTools MCP)

Follow `.cursor/skills/browser-testing-with-devtools/SKILL.md`.

1. Start the local stack per `AGENTS.md` (Postgres + API on 8081 + Flutter web on 8080). Run `pwsh scripts/pre-deploy-verify.ps1` first.
2. Walk each persona through intake → submit → click on dashboard → walk through prep/triage/plan/parent-summary.
3. Watch the **Console** tab for warnings/errors throughout. Capture network 4xx/5xx responses.
4. For BUG-1, screen-record (or take before/after screenshots) of the field contents while toggling a checkbox and scrolling.
5. For BUG-2, intentionally submit with: missing required field, invalid email, malformed phone, oversize free text, special characters in the name. Capture the actual API response body and the actual UI message shown.
6. For BUG-3, after each click on a case, capture (a) the URL, (b) the network request to `GET /v1/cases/:id`, (c) the visible child name on the prep screen header. Compare across cases.

### 4.2 Playwright E2E (`e2e/`)

The existing tests live in `e2e/tests/`. Use them as templates:

- `e2e/tests/parent-intake-smoke.spec.ts` — reliable smoke; mirror its structure.
- `e2e/tests/parent-intake-full.spec.ts` — known flaky on the date picker step; do **not** rely on it as your regression test.
- API-only smoke: `e2e/tests/intake-api-full.spec.ts` for shaping bug-3 fixtures.

Add new tests under `e2e/tests/bug-bash-*.spec.ts` only when a widget test cannot reach the bug.

### 4.3 Flutter widget tests (`apps/sona/test/`)

This is the **preferred** regression layer for BUG-1 and BUG-3 (deterministic, fast).

- BUG-1: write a widget test that pumps `ParentIntakeStepScreen`, types into a long-text field, toggles a checkbox, scrolls the `ListView` 600px, and asserts the typed text is still in the field controller and the rendered tree.
- BUG-3: extend `apps/sona/test/widget/clinician_screens_uses_case_detail_test.dart` with a case-A-then-case-B test, asserting "Aria" appears nowhere when Jaden is loaded, and vice versa.

### 4.4 API tests (`apps/api/src/__tests__/`)

- BUG-2: add a test that feeds the intake submit handler intentionally bad payloads (missing required, bad email, etc.) and asserts the response shape contains a parseable `issues.fieldErrors` map keyed by field, with **human-readable** messages (not Zod codes).
- BUG-3 stub: add a test on `prep-brief.ts` that asserts the stub's `probeAreas[0]` contains the case's `childDisplayName` and `mainConcern`.

---

## 5. The bug log

Create **one file**: `docs/qa/intake-flow-bug-bash-log.md`. Append-only during the run. Format:

```markdown
# Intake → Clinician Bug Bash — Bug Log (2026-05-XX)

> Source: live demo 2026-05-29. Brief: docs/qa/intake-flow-bug-bash-brief.md
> Agent: <model>, run started <ISO timestamp>

## Status legend
- 🔴 open · 🟡 in-fix · 🟢 fixed (commit + test reference) · ⚪ design-debt (out of scope, logged for later)

---

## BUG-001 — <short title>
- **Severity:** blocker | high | medium | low | design-debt
- **Reported by:** demo 2026-05-29 / bug bash
- **Surface:** parent intake step screen / clinician prep / etc.
- **Repro (numbered steps a non-engineer can follow):**
  1. …
  2. …
- **Expected:** …
- **Actual:** …
- **Evidence:** screenshot path / console log / failing test name
- **Root cause:** (filled in after investigation)
- **Fix:** (commit SHA + one-line description, filled in after the fix)
- **Regression test:** (file + test name)
- **Status:** 🔴 → 🟡 → 🟢
```

Rules:

- BUG-001, BUG-002, BUG-003 are the three known bugs from §2. Fill them in first.
- Pre-fill the log with all bugs found in §4 **before** writing any fix. The full list is the unit of estimation.
- Add `**design-debt**` entries for anything you spot that is real but out of scope (e.g., "the parent welcome screen never shows a privacy notice" — log it, don't fix it).
- Reference every bug from its fix commit message: `fix(intake): scroll resets text — BUG-001` etc.

---

## 6. Fix workflow

After the log is complete and the user has confirmed scope (see §11):

1. **One bug, one commit.** Even small ones. Easier to review, easier to revert.
2. **Sequence:** blockers → high → medium → low. Within a severity, smallest diff first to build momentum.
3. **For each bug:**
   - Write the failing regression test first (TDD — follow `.cursor/skills/test-driven-development/SKILL.md`).
   - Make the minimal change to pass it.
   - Run the relevant test suite: `cd apps/sona && flutter test` for widget tests, `cd apps/api && npx tsc --noEmit && npm test` for API, `cd e2e && npx playwright test bug-bash` for E2E if added.
   - `flutter analyze` must stay clean (info-level lints are OK, errors are not).
   - Commit: `fix(intake): <one-line summary> — BUG-NNN`.
   - Update the bug log entry to 🟢 with the commit SHA and test name.
4. **Do not bundle unrelated bug fixes** in a single commit.
5. **Stop and ask the user** if a fix would touch more than ~5 files or require an API contract change.

---

## 7. PR strategy

Default: **one PR** titled `fix(intake): demo bug bash — N fixes` against `main` from branch `fix/intake-flow-bug-bash` (already exists; this brief was committed on it).

Split into multiple PRs **only if** any of these is true:

- The bug list exceeds 10 fixes.
- Any single bug requires an API contract change (DB migration, response shape change). Land that one alone first.
- Reviewer review-bandwidth is a concern (ask the user — default no).

PR description must include:

- A one-paragraph summary.
- A bullet list of `BUG-NNN — title (status)` mapped to commits.
- The test plan section from `.cursor/skills/mvp-git-workflow/SKILL.md`, with each bug as a checkbox.
- Before/after screenshots for BUG-1 and BUG-3 (browser MCP captures or widget-test golden files).
- Any known follow-ups left in the log as design-debt.

---

## 8. Honesty & quality bar

- **No silent fixes.** Every change must have an entry in the bug log and a regression test. If you can't write a test for it, log it and ask before fixing.
- **No "while I'm here" changes.** If you touch a file and notice an unrelated issue, log it as design-debt and move on.
- **No fake green.** If a test was flaky before your change, do not "fix" it by retrying or by relaxing the assertion. Either fix the underlying flake (and log it) or leave it untouched and flag it in the log.
- **No new dependencies.** All fixes use the existing stack: Flutter widgets, Drizzle/Hono on the API, Playwright for E2E.
- **No PHI.** Use the four personas + your own typed test names ("Test Child Alpha"). Never invent realistic-sounding family details that could be mistaken for real patients.
- **If you can't reproduce a bug** within reasonable effort (30 min including local-stack startup), log it as `severity: cannot-reproduce` with everything you tried, and move on. Do not invent a fix for a phantom.

---

## 9. Constraints (from workspace rules)

- **Git workflow:** PR-only. Never commit or push to `main`. Branch already exists: `fix/intake-flow-bug-bash`. See `.cursor/rules/mvp-git-workflow.mdc`.
- **No GCP deploys.** This is local stack + repo changes only. No `gcloud builds submit` or `gcloud run deploy` — even to "test the fix in dev." Merge → Cloud Build triggers handle the rest.
- **No infra/terraform changes** unless a fix is impossible without one (escalate to the user first).
- **PHI safety.** Personas only. See `.cursor/rules/mvp-security-reminder.mdc`.
- **CORS / env.** If a fix requires a new env var, document it in `apps/api/.env.example` and the `AGENTS.md` env-var block — do **not** change live Cloud Run env from the agent.

---

## 10. Definition of done

- [ ] `docs/qa/intake-flow-bug-bash-log.md` exists, pre-populated with BUG-001..003 plus every bug found in the §4 exploratory pass, before any fix commit lands.
- [ ] Every 🟢 entry in the log references a commit SHA and a regression test name that exists on the branch.
- [ ] `cd apps/sona && flutter analyze` exits clean (no errors; info-level is fine).
- [ ] `cd apps/sona && flutter test` passes including new widget tests.
- [ ] `cd apps/api && npx tsc --noEmit && npm test` passes.
- [ ] `cd e2e && npx playwright test parent-intake-smoke api-bootstrap` passes (the reliable subset).
- [ ] `pwsh scripts/pre-deploy-verify.ps1` passes on the branch.
- [ ] BUG-1, BUG-2, BUG-3 are 🟢 in the log.
- [ ] PR is open from `fix/intake-flow-bug-bash` against `main`, with the description format from §7.
- [ ] Final hand-off message includes: PR URL, count of bugs fixed by severity, count logged as design-debt for follow-up.

---

## 11. Questions to batch to the user before starting (one message, with defaults)

Ask all of these in **one** chat message, with the defaults shown. Wait for confirmation; do not loop.

1. **Scope confirmation.** Is the intake → clinician case-detail loop the only surface for this bug bash, or should it also cover the parent summary email send / clinician booking screen? (Default: intake → case-detail only, as written in §3.)
2. **Personas to test against.** All four (Aria, Jaden, Mia, Theo) + one custom typed case? (Default: yes, all five.)
3. **Severity threshold for fixing now vs logging as design-debt.** (Default: fix all `blocker`/`high`/`medium`; log `low` and `design-debt` for follow-up.)
4. **Maximum bug count before splitting into multiple PRs?** (Default: 10 — see §7.)
5. **Should the stub for `prep_brief` / `session_plan` / `parent_summary` interpolate the case data (BUG-3 secondary fix), or is "generic stub when LLM unavailable" the intended behaviour?** (Default: interpolate at minimum childName + mainConcern + ageAtReferral, deterministic, no randomness.)
6. **Browser scope.** Chrome only, or also Safari/Firefox? (Default: Chrome only — matches Playwright `chromium` project.)
7. **Time-box.** Any hard deadline? (Default: aim for one working session; split the PR if it spills into a second.)

---

## 12. Worked example: how to log + fix BUG-1

(Provided as a template for the depth and shape expected. Apply to every bug.)

### Step 1 — Pre-log

```markdown
## BUG-001 — Text-box contents disappear when scrolling or toggling checkboxes
- **Severity:** high
- **Reported by:** demo 2026-05-29
- **Surface:** apps/sona/lib/features/parent/intake/parent_intake_step_screen.dart, apps/sona/lib/design_system/widgets/sona_text_field.dart
- **Repro:**
  1. Open parent intake on a fresh case (any persona or custom).
  2. Navigate to step with a long-text field (e.g., "Main concern", step 2).
  3. Type "Test concern xyz" into the text field.
  4. Tap a checkbox in the difficulty list below (without leaving the field).
  5. Observe: the typed text disappears from the field.
- **Expected:** Typed text persists across checkbox toggles and scroll events until explicitly edited or the form is reset.
- **Actual:** Text vanishes; controller text reverts to empty.
- **Evidence:** assets/qa/bug-001-before.png (captured via Chrome DevTools MCP)
- **Root cause:** TBD — likely stale `widget.value` from parent rebuild before `onChanged` propagates.
- **Status:** 🔴
```

### Step 2 — Reproduce in a widget test

Add a failing test in `apps/sona/test/widget/parent_intake_text_persistence_test.dart` that pumps the step screen, enters text, toggles a checkbox, and asserts the text is still present. Confirm it fails.

### Step 3 — Find the root cause

Inspect the field's `onChanged` plumbing. Trace from `SonaTextField.onChanged` → step screen handler → `state.intake.X = …` → `notifyListeners`. If any link in the chain is debounced, async, or missing, that's the cause.

### Step 4 — Minimal fix

Make the change. Run the failing test — it passes. Run all widget tests + analyze.

### Step 5 — Commit + update log

```
fix(intake): persist typed text across rebuild — BUG-001

The step-screen rebuild triggered by a checkbox toggle was passing the
pre-typing widget.value back to SonaTextField, whose didUpdateWidget
overwrote the live controller text. Route onChanged through the
SonaAppState mutator synchronously so the parent's next rebuild has the
fresh value.

Test: apps/sona/test/widget/parent_intake_text_persistence_test.dart
```

Update log entry to 🟢 with the SHA and test name.

---

## 13. Anti-patterns (do not do these)

- A 50-bug log that's actually 5 real bugs split 10 ways for status-page optics. One bug = one entry.
- A fix without a regression test. Even one-line CSS-equivalent fixes get a widget test.
- "Refactor the parent intake state management" as a bug fix. That's a redesign — log as design-debt.
- Adding `@Skip` / `@TODO` to existing failing tests. If a test was passing on `main`, it must still pass after your change.
- Disabling `flutter analyze` warnings by adding `// ignore: …` blanket suppressions. Fix the underlying issue or log it.
- Editing the strategy review brief, the marketing demo, or the personas to "fix" things you don't like.
- Inventing realistic-looking child or parent test names. Use the personas and "Test Child Alpha / Bravo / …".

---

## 14. Final hand-off message template

When done, post in the chat (one message, no follow-up pings):

```
Bug bash done.

- PR: <github-pr-url>
- Bug log: docs/qa/intake-flow-bug-bash-log.md

Fixed:
- blocker: <count>
- high: <count>
- medium: <count>
- low: <count>

Logged as design-debt (not fixed this pass):
- <count>, top 3: <BUG-NNN — title>, <BUG-NNN — title>, <BUG-NNN — title>

Tests added: <count> widget, <count> API, <count> E2E.
flutter analyze: clean. flutter test / npx tsc --noEmit / playwright smoke: all green.

Open questions for you:
1. <…>
2. <…>
```

---

## 15. Run summary (filled in by the agent)

_Pending. Append on completion: date, agent model, bug-log path, PR URL, total bugs found / fixed / deferred._
