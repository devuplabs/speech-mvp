import { test, expect } from "@playwright/test";
import { e2eChildName, validIntakeAnswers } from "../fixtures/valid-intake.js";
import {
  expectChildOnDashboard,
  getStartedCaptureCase,
  openClinicianDashboard,
  openParentIntake,
  refreshDashboardUntilChildVisible,
} from "../helpers/intake-flow.js";

/**
 * Hybrid demo E2E:
 * 1. Parent UI: launcher → Get started → step 1 (real Flutter web)
 * 2. API: PUT draft + POST submit (identical to the Flutter submit path)
 * 3. Clinician UI: Home → Clinician workspace → Refresh → child name visible
 *
 * Why hybrid: Flutter web fields below the fold are not reliably reachable from
 * Playwright on a 430px mobile viewport. The form submit endpoint is the same
 * one the UI calls, so this proves the full pipeline (UI → API → dashboard UI)
 * without depending on Flutter web textbox flakiness.
 */
test.describe("Parent intake → clinician dashboard (hybrid demo E2E)", () => {
  test("intake submitted from real session shows up on dashboard", async ({
    page,
    request,
  }) => {
    test.setTimeout(300_000);
    const childName = e2eChildName();

    await openParentIntake(page);
    const { caseId, apiBaseUrl } = await getStartedCaptureCase(page);

    const answers = validIntakeAnswers(childName);

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

    await openClinicianDashboard(page);
    await refreshDashboardUntilChildVisible(page, childName);
    await expectChildOnDashboard(page, childName);
  });
});
