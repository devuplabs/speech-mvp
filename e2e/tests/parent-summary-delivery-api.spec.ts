import { test, expect } from "@playwright/test";
import { e2eChildName, validIntakeAnswers } from "../fixtures/valid-intake.js";

const apiUrl = process.env.SONA_API_URL ?? "http://127.0.0.1:8081";

/**
 * DEV-9 — family summary receive/view loop.
 *
 * Asserts that publishing a parent summary completes the loop: the publish
 * response reports the notification outcome, a working family portal link is
 * available (minted on publish even when Mailgun is unconfigured), and the
 * portal payload renders the published summary plus the AI-assisted /
 * reviewing-clinician context — with NO PHI ever in a notification email (the
 * PHI-free email body itself is asserted deterministically in the API unit
 * test `parent-summary-email.test.ts`; CI runs the API with Mailgun
 * unconfigured, so `familyNotified` is false here).
 */
test.describe("parent summary delivery API", () => {
  test("publish completes the portal delivery loop", async ({ request }) => {
    const childName = e2eChildName();
    const answers = validIntakeAnswers(childName);

    const boot = await request.post(`${apiUrl}/v1/demo/bootstrap`, {
      data: { practice: "e2e" },
    });
    expect([200, 201]).toContain(boot.status());
    const { tenantId } = (await boot.json()) as { tenantId: string };

    const caseRes = await request.post(`${apiUrl}/v1/cases`, { data: { tenantId } });
    expect(caseRes.status()).toBe(201);
    const { id: caseId } = (await caseRes.json()) as { id: string };

    const submit = await request.post(`${apiUrl}/v1/cases/${caseId}/intake`, {
      data: {
        answers,
        consentVersion: "mvp-v1",
        parentEmail: answers.email,
        childDisplayName: childName,
      },
    });
    expect(submit.status()).toBe(201);

    const triage = await request.post(`${apiUrl}/v1/cases/${caseId}/triage`, {
      data: { outcome: "strategy_only" },
    });
    expect(triage.ok()).toBeTruthy();

    // Publish — should report the notification outcome and mint a portal link.
    const publish = await request.post(
      `${apiUrl}/v1/cases/${caseId}/parent-summary/publish`,
      {
        data: {
          htmlBody:
            "<!DOCTYPE html><html><body><p>Family summary delivery E2E</p></body></html>",
        },
      },
    );
    expect(publish.ok()).toBeTruthy();
    const publishBody = (await publish.json()) as {
      familyNotified: boolean;
      case: { status: string };
      message: string;
    };
    expect(typeof publishBody.familyNotified).toBe("boolean");
    expect(publishBody.case.status).toBe("summary_sent");

    // The publish minted a portal link; re-publishing reuses the same one.
    const linkRes = await request.post(`${apiUrl}/v1/cases/${caseId}/portal-links`);
    expect(linkRes.status()).toBe(201);
    const { token } = (await linkRes.json()) as { token: string };

    const portal = await request.get(`${apiUrl}/v1/portal/${token}`);
    expect(portal.status()).toBe(200);
    const payload = (await portal.json()) as {
      case: { id: string };
      summary: { html: string } | null;
      practiceName: string | null;
      reviewingClinicianName: string | null;
    };
    expect(payload.case.id).toBe(caseId);
    expect(payload.summary?.html).toContain("Family summary delivery E2E");
    // Clinician-presentation field is always present (name or null — never
    // fabricated). For the single-seat e2e practice it resolves to the admin.
    expect(payload).toHaveProperty("reviewingClinicianName");

    // Re-publish re-runs the loop and still resolves the same portal link.
    const republish = await request.post(
      `${apiUrl}/v1/cases/${caseId}/parent-summary/publish`,
      {
        data: {
          htmlBody:
            "<!DOCTYPE html><html><body><p>Amended summary E2E</p></body></html>",
        },
      },
    );
    expect(republish.ok()).toBeTruthy();

    const portalAfter = await request.get(`${apiUrl}/v1/portal/${token}`);
    expect(portalAfter.status()).toBe(200);
    const after = (await portalAfter.json()) as { summary: { html: string } | null };
    expect(after.summary?.html).toContain("Amended summary E2E");
  });
});
