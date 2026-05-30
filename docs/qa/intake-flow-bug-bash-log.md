# Intake → Clinician Bug Bash — Bug Log (2026-05-30)

> Source: live demo 2026-05-29. Brief: docs/qa/intake-flow-bug-bash-brief.md
> Agent: Composer, run started 2026-05-30T00:00:00Z
> Scope (§11 defaults): intake → case-detail only; all five personas; fix blocker/high/medium; split PR if >10 fixes; stub interpolation; Chrome only.

## Status legend
- 🔴 open · 🟡 in-fix · 🟢 fixed (commit + test reference) · ⚪ design-debt (out of scope, logged for later)

---

## BUG-001 — Text-box contents disappear when scrolling or toggling checkboxes
- **Severity:** high
- **Reported by:** demo 2026-05-29 / bug bash
- **Surface:** `apps/sona/lib/design_system/widgets/sona_text_field.dart`, `apps/sona/lib/features/parent/intake/parent_intake_step_screen.dart`
- **Repro:**
  1. Open parent intake on a fresh case (step 2).
  2. Type into the "Main concern" field.
  3. Without leaving the field, toggle a difficulty checkbox below (or trigger a parent `setState` while IME text is only in the controller).
  4. Observe typed text can vanish when `didUpdateWidget` applies a stale empty `widget.value`.
- **Expected:** Typed text persists across checkbox toggles and scroll until explicitly edited.
- **Actual:** Text vanishes; controller reverts to empty/stale `widget.value`.
- **Evidence:** `apps/sona/test/widget/parent_intake_text_persistence_test.dart`
- **Root cause:** `SonaTextField.didUpdateWidget` overwrote the live controller when the parent rebuilt with a stale `value` prop (web IME / rebuild before model sync).
- **Root cause:** `SonaTextField.didUpdateWidget` overwrote the live controller when the parent rebuilt with a stale empty `widget.value` (web IME / sibling setState race).
- **Fix:** `fe0f1f5` — guard stale empty parent value; sync via `TextField.onChanged`.
- **Regression test:** `apps/sona/test/widget/parent_intake_text_persistence_test.dart`
- **Status:** 🟢

---

## BUG-002 — Validation error "Please check your answers" is uselessly generic
- **Severity:** high
- **Reported by:** demo 2026-05-29 / bug bash
- **Surface:** `apps/sona/lib/utils/api_errors.dart`, `apps/sona/lib/app/sona_app_shell.dart`
- **Repro:**
  1. Submit intake with invalid API payload (e.g. malformed email in answers).
  2. Observe snackbar shows only "Please check your answers (fieldKey)" or generic fallback.
  3. Form does not scroll to or highlight the failing field.
- **Expected:** All failing fields listed with human labels; first field highlighted and scrolled into view.
- **Actual:** Generic message; user cannot tell what to fix.
- **Evidence:** `apps/sona/test/api_errors_test.dart`, `apps/api/src/__tests__/intake-validation.test.ts`
- **Root cause:** `friendlyApiError` surfaced only the first Zod key (not label); server errors were not routed to `pendingValidationFieldKey`.
- **Fix:** `55da2e7` + `3e7296e` (`_applyApiValidationFailure` in shell) — parse all fieldErrors, human labels, route to form.
- **Regression test:** `apps/sona/test/api_errors_test.dart`, `apps/api/src/__tests__/intake-validation.test.ts`
- **Status:** 🟢

---

## BUG-003 — Clinician dashboard → case detail shows wrong case (often Aria)
- **Severity:** blocker
- **Reported by:** demo 2026-05-29 / bug bash
- **Surface:** `apps/sona/lib/app/sona_app_shell.dart`, `apps/api/src/services/prep-brief.ts`
- **Repro:**
  1. Open case A on clinician Today dashboard.
  2. Click case B before `GET /v1/cases/:id` completes.
  3. Prep screen still shows case A data; AI stub text identical across cases.
- **Expected:** Correct child name/concern for the clicked row; stubs reference that case's intake.
- **Actual:** Stale `caseDetail` until fetch completes; generic stub probe areas look like wrong child.
- **Evidence:** `apps/sona/test/widget/clinician_screens_uses_case_detail_test.dart`, `apps/api/src/__tests__/prep-brief-stub.test.ts`
- **Root cause:** `caseDetail` not cleared when `caseId` changes; MVP prep stub did not interpolate child name/concern.
- **Fix:** `3e7296e` — `_selectClinicianCase` clears stale detail; stub interpolation in `stub-draft-content.ts`.
- **Regression test:** `clinician_screens_uses_case_detail_test.dart`, `prep-brief-stub.test.ts`
- **Status:** 🟢

---

## BUG-004 — Stale case detail while switching cases (subset of BUG-003)
- **Severity:** high
- **Reported by:** bug bash
- **Surface:** `sona_app_shell.dart` (`onOpenPrep`, `onOpenCase`, `_openIntakeReview`)
- **Repro:** Click case B immediately after viewing case A.
- **Expected:** Loading/empty state until B loads; never show A's name for B's row.
- **Actual:** Previous `caseDetail` remains visible during fetch.
- **Root cause:** Same as BUG-003 shell path.
- **Fix:** merged into BUG-003 (`3e7296e`)
- **Status:** 🟢

---

## BUG-005 — MVP AI prep stub identical for every child (subset of BUG-003)
- **Severity:** medium
- **Reported by:** bug bash
- **Surface:** `apps/api/src/services/prep-brief.ts`, `session-plan.ts`
- **Repro:** Submit two different intakes locally; compare `prep_brief` draft content.
- **Expected:** Stub references child name and main concern.
- **Actual:** Generic probe area strings with no case-specific text.
- **Root cause:** Static stub template.
- **Fix:** merged into BUG-003 (`3e7296e`)
- **Status:** 🟢

---

## BUG-006 — parent-intake-full E2E flaky on date picker (design-debt)
- **Severity:** design-debt
- **Reported by:** AGENTS.md / brief §4.2
- **Surface:** `e2e/tests/parent-intake-full.spec.ts`
- **Repro:** Run full E2E headless; date picker step may time out.
- **Expected:** Reliable automation (out of scope for this pass).
- **Actual:** Known flake; smoke test used instead.
- **Status:** ⚪

---

## 15. Run summary (filled in by the agent)

- **Date:** 2026-05-30
- **Agent:** Composer (Cursor Cloud)
- **Bug log:** `docs/qa/intake-flow-bug-bash-log.md`
- **Found / fixed / deferred:** 6 logged (5 fixed, 1 design-debt)
- **Tests added:** 2 widget files, 1 Dart unit file, 2 API vitest files
