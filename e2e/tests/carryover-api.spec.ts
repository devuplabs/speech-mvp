import { test, expect } from "@playwright/test";
import { e2eChildName, validIntakeAnswers } from "../fixtures/valid-intake.js";

const apiUrl = process.env.SONA_API_URL ?? "http://127.0.0.1:8081";

test.describe("carryover + family portal API", () => {
  test("resources, portal link, parent progress, revoke", async ({ request }) => {
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

    const publish = await request.post(
      `${apiUrl}/v1/cases/${caseId}/parent-summary/publish`,
      {
        data: {
          htmlBody:
            "<!DOCTYPE html><html><body><p>Carryover summary E2E</p></body></html>",
        },
      },
    );
    expect(publish.ok()).toBeTruthy();

    // Clinician shares two resources, renames one and removes the other.
    const res1 = await request.post(
      `${apiUrl}/v1/cases/${caseId}/carryover/resources`,
      {
        data: {
          title: "Daily sound practice",
          description: "Practise /s/ blends for 10 minutes a day.",
          category: "home_practice",
        },
      },
    );
    expect(res1.status()).toBe(201);
    const { resource } = (await res1.json()) as { resource: { id: string } };

    const res2 = await request.post(
      `${apiUrl}/v1/cases/${caseId}/carryover/resources`,
      {
        data: {
          title: "Book list",
          url: "https://example.com/reading",
          category: "reading",
        },
      },
    );
    expect(res2.status()).toBe(201);
    const second = (await res2.json()) as { resource: { id: string } };

    const patch = await request.patch(
      `${apiUrl}/v1/cases/${caseId}/carryover/resources/${resource.id}`,
      { data: { title: "Daily sound practice (week 2)" } },
    );
    expect(patch.status()).toBe(200);

    const del = await request.delete(
      `${apiUrl}/v1/cases/${caseId}/carryover/resources/${second.resource.id}`,
    );
    expect(del.status()).toBe(204);

    // Clinician also logs a progress note directly.
    const clinNote = await request.post(
      `${apiUrl}/v1/cases/${caseId}/carryover/progress`,
      { data: { note: "Introduced the home practice pack in session." } },
    );
    expect(clinNote.status()).toBe(201);

    const linkRes = await request.post(`${apiUrl}/v1/cases/${caseId}/portal-links`);
    expect(linkRes.status()).toBe(201);
    const { token, expiresAt } = (await linkRes.json()) as {
      token: string;
      expiresAt: string;
    };
    expect(token.length).toBeGreaterThanOrEqual(40);
    expect(new Date(expiresAt).getTime()).toBeGreaterThan(Date.now());

    // Family opens the portal: summary + resources visible, no account needed.
    const portal = await request.get(`${apiUrl}/v1/portal/${token}`);
    expect(portal.status()).toBe(200);
    const payload = (await portal.json()) as {
      case: { id: string; childDisplayName: string | null };
      summary: { html: string } | null;
      resources: Array<{ title: string; category: string }>;
      progress: Array<{ author: string }>;
    };
    expect(payload.case.id).toBe(caseId);
    expect(payload.case.childDisplayName).toBe(childName);
    expect(payload.summary?.html).toContain("Carryover summary E2E");
    expect(payload.resources).toHaveLength(1);
    expect(payload.resources[0].title).toBe("Daily sound practice (week 2)");
    expect(payload.progress).toHaveLength(1);

    // Parent logs progress through the portal.
    const parentNote = await request.post(`${apiUrl}/v1/portal/${token}/progress`, {
      data: { note: "We tried the sound games twice this week.", rating: "going_well" },
    });
    expect(parentNote.status()).toBe(201);

    const progressList = await request.get(
      `${apiUrl}/v1/cases/${caseId}/carryover/progress`,
    );
    expect(progressList.status()).toBe(200);
    const { entries } = (await progressList.json()) as {
      entries: Array<{ author: string; rating: string | null }>;
    };
    expect(entries).toHaveLength(2);
    expect(
      entries.some((e) => e.author === "parent" && e.rating === "going_well"),
    ).toBeTruthy();

    // Revoke: the portal link stops working with a distinct reason.
    const revoke = await request.post(
      `${apiUrl}/v1/cases/${caseId}/portal-links/revoke`,
    );
    expect(revoke.status()).toBe(204);

    const afterView = await request.get(`${apiUrl}/v1/portal/${token}`);
    expect(afterView.status()).toBe(410);
    expect(((await afterView.json()) as { error: string }).error).toBe("revoked");

    const afterNote = await request.post(`${apiUrl}/v1/portal/${token}/progress`, {
      data: { note: "Should be rejected." },
    });
    expect(afterNote.status()).toBe(410);

    const unknown = await request.get(`${apiUrl}/v1/portal/not-a-real-token`);
    expect(unknown.status()).toBe(404);
  });
});
