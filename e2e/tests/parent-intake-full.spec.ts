import { test, expect } from "@playwright/test";
import { e2eChildName, validIntakeAnswers } from "../fixtures/valid-intake.js";
import {
  expectChildOnDashboard,
  fillDateField,
  fillLabeledField,
  getStartedCaptureCase,
  openClinicianDashboard,
  openParentIntake,
  refreshDashboardUntilChildVisible,
} from "../helpers/intake-flow.js";

/**
 * Full parent-intake browser E2E (DEV-36).
 *
 * 1. Parent UI (real Flutter web): launcher → Get started → step 1a, then fill
 *    the step-1 "About you & your child" fields *in the browser*, INCLUDING the
 *    date-of-birth field. The date is typed directly into the (now keyboard-
 *    editable) `SonaDateField` — the previous Material date-picker dialog
 *    rendered unreliably in the headless accessibility tree and was the root
 *    cause of this spec's historical flake. We assert the computed
 *    "age at referral" appears, proving the typed date was accepted by the model.
 * 2. API: the remaining deep history steps (4–8, dozens of below-the-fold
 *    fields) are submitted via the exact endpoints the Flutter app calls. This
 *    keeps the spec hermetic and fast without re-litigating Flutter web's
 *    virtualised-list quirks for every field (covered by the Dart widget
 *    full-flow test).
 * 3. Clinician UI (real Flutter web): Home → Clinician workspace → Refresh →
 *    the submitted child's case appears with a status.
 *
 * Hermetic: each run bootstraps its own demo tenant (via Get started) and uses a
 * unique child name, so repeated runs never collide.
 */
test.describe("Parent intake → submit → clinician dashboard (full browser E2E)", () => {
  test("date entered in the browser submits and appears on the dashboard", async ({
    page,
    request,
  }) => {
    test.setTimeout(300_000);
    const childName = e2eChildName();
    const answers = validIntakeAnswers(childName);

    // --- 1. Real parent UI: start a session and fill step 1a in the browser ---
    await openParentIntake(page);
    const { caseId, apiBaseUrl } = await getStartedCaptureCase(page);

    await fillLabeledField(page, "Email", answers.email);
    await fillLabeledField(page, "Child's name", childName);

    // The load-bearing assertion for DEV-36: type the DOB straight into the
    // date field (no Material picker dialog) and confirm BOTH that the value
    // committed to the field AND that the model accepted it.
    await fillDateField(page, "Date of birth", answers.dateOfBirth);

    // (a) The typed value persisted in the now-editable date field.
    const dob = page
      .getByRole("textbox", { name: /Date of birth/i })
      .first();
    await expect(dob).toHaveValue(answers.dateOfBirth, { timeout: 15_000 });

    // (b) The model absorbed the date: the screen derives an "age at referral"
    // from a valid DOB and exposes it as a single Flutter semantics node, e.g.
    // "Age at referral\n7 years, 1 month\nComputed from date of birth". Matching
    // its accessible label (not a text node — Flutter web renders text into
    // aria-label) proves onChanged reached IntakeFormData.
    await expect(
      page.getByLabel(/Age at referral[\s\S]*\d+\s*(year|month)/i).first(),
    ).toBeVisible({ timeout: 15_000 });

    // --- 2. Submit the full intake via the same API the Flutter app calls ---
    const draft = await request.put(
      `${apiBaseUrl}/v1/cases/${caseId}/intake/draft`,
      {
        data: {
          answers: { ...answers, formStep: 8 },
          parentEmail: answers.email,
          childDisplayName: childName,
        },
      },
    );
    expect(draft.status()).toBe(200);

    const submit = await request.post(
      `${apiBaseUrl}/v1/cases/${caseId}/intake`,
      {
        data: {
          answers,
          consentVersion: "mvp-v1",
          parentEmail: answers.email,
          childDisplayName: childName,
        },
      },
    );
    expect(submit.status()).toBe(201);

    // --- 3. Clinician dashboard reflects the submitted case ---
    await openClinicianDashboard(page);
    await refreshDashboardUntilChildVisible(page, childName);
    await expectChildOnDashboard(page, childName);
  });
});
