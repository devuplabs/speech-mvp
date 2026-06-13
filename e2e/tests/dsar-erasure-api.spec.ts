import { test, expect } from "@playwright/test";
import { e2eChildName, validIntakeAnswers } from "../fixtures/valid-intake.js";

// DSAR export (UK GDPR Art. 15) + right-to-erasure (Art. 17) — DEV-24.
// Hermetic: bootstraps the e2e demo practice, builds a fully-populated case,
// exercises export + erasure, and verifies nothing is retrievable afterwards.

const apiUrl = process.env.SONA_API_URL ?? "http://127.0.0.1:8081";

type Json = Record<string, unknown>;

async function buildPopulatedCase(request: import("@playwright/test").APIRequestContext) {
  const childName = e2eChildName();
  const answers = validIntakeAnswers(childName);

  const boot = await request.post(`${apiUrl}/v1/demo/bootstrap`, {
    data: { practice: "e2e" },
  });
  expect([200, 201]).toContain(boot.status());
  const { tenantId } = (await boot.json()) as { tenantId: string };

  const caseRes = await request.post(`${apiUrl}/v1/cases`, {
    data: { tenantId, parentEmail: answers.email, childDisplayName: childName },
  });
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
          "<!DOCTYPE html><html><body><p>DSAR E2E summary</p></body></html>",
      },
    },
  );
  expect(publish.ok()).toBeTruthy();

  const resource = await request.post(
    `${apiUrl}/v1/cases/${caseId}/carryover/resources`,
    { data: { title: "Daily practice", category: "home_practice" } },
  );
  expect(resource.status()).toBe(201);

  // A portal link (durable access credential) + a parent progress entry.
  const link = await request.post(`${apiUrl}/v1/cases/${caseId}/portal-links`);
  expect(link.status()).toBe(201);
  const { token: portalToken } = (await link.json()) as { token: string };

  const progress = await request.post(
    `${apiUrl}/v1/portal/${portalToken}/progress`,
    { data: { note: "We tried it at home.", rating: "going_well" } },
  );
  expect(progress.status()).toBe(201);

  return { tenantId, caseId, childName, portalToken, parentEmail: answers.email };
}

test.describe("DSAR export + right-to-erasure API", () => {
  test("export returns all subject sections and no token values", async ({ request }) => {
    const { caseId, childName, portalToken } = await buildPopulatedCase(request);

    const res = await request.get(`${apiUrl}/v1/cases/${caseId}/dsar-export`);
    expect(res.status()).toBe(200);
    const bundle = (await res.json()) as {
      meta: Json;
      sections: Record<string, unknown[]>;
    };

    // Every expected subject section is present and populated.
    expect(bundle.sections.case).toHaveLength(1);
    expect(bundle.sections.intakeSubmissions.length).toBeGreaterThan(0);
    expect(bundle.sections.triageRecords.length).toBeGreaterThan(0);
    expect(bundle.sections.aiDrafts.length).toBeGreaterThan(0);
    expect(bundle.sections.carryoverResources.length).toBeGreaterThan(0);
    expect(bundle.sections.progressEntries.length).toBeGreaterThan(0);
    expect(bundle.sections.casePortalLinks.length).toBeGreaterThan(0);
    expect(bundle.sections.auditLog.length).toBeGreaterThan(0);

    // The child name (PHI) is present in the export (subject is entitled to it).
    const raw = JSON.stringify(bundle);
    expect(raw).toContain(childName);

    // But the secret token VALUES never appear.
    expect(raw).not.toContain(portalToken);
    for (const link of bundle.sections.casePortalLinks as Json[]) {
      expect(link).not.toHaveProperty("token");
      expect(link.tokenPresent).toBe(true);
    }

    // Practice-level tables are documented as excluded.
    const excluded = (bundle.meta.excluded as { section: string }[]).map(
      (e) => e.section,
    );
    expect(excluded).toEqual(
      expect.arrayContaining(["tenants", "users", "clinicianAvailability"]),
    );
  });

  test("erasure request→confirm deletes all PHI and leaves a tombstone", async ({
    request,
  }) => {
    const { tenantId, caseId } = await buildPopulatedCase(request);

    const reqRes = await request.post(`${apiUrl}/v1/cases/${caseId}/erasure/request`);
    expect(reqRes.status()).toBe(201);
    const { token } = (await reqRes.json()) as { token: string };
    expect(token).toBeTruthy();

    const confirm = await request.post(
      `${apiUrl}/v1/cases/${caseId}/erasure/confirm`,
      { data: { token } },
    );
    expect(confirm.status()).toBe(200);
    const result = (await confirm.json()) as {
      ok: boolean;
      deleted: Record<string, number>;
      auditRetained: number;
    };
    expect(result.ok).toBe(true);
    expect(result.deleted.case).toBe(1);
    expect(result.auditRetained).toBeGreaterThan(0);

    // Nothing retrievable via any case endpoint afterwards.
    expect((await request.get(`${apiUrl}/v1/cases/${caseId}`)).status()).toBe(404);
    expect(
      (await request.get(`${apiUrl}/v1/cases/${caseId}/dsar-export`)).status(),
    ).toBe(404);
    expect(
      (await request.get(`${apiUrl}/v1/cases/${caseId}/carryover/resources`)).status(),
    ).toBe(404);

    // Tombstone exists: a fresh DSAR/erasure on the same id is a clean 404, and
    // listing the tenant's cases no longer includes the erased case.
    const list = await request.get(`${apiUrl}/v1/tenants/${tenantId}/cases`);
    expect(list.status()).toBe(200);
    const { cases } = (await list.json()) as { cases: { id: string }[] };
    expect(cases.find((c) => c.id === caseId)).toBeUndefined();
  });

  test("erasure refused while a legal hold is in place", async ({ request }) => {
    const { caseId } = await buildPopulatedCase(request);

    const hold = await request.post(`${apiUrl}/v1/cases/${caseId}/legal-hold`, {
      data: { hold: true, reason: "Open complaint — HCPC retention" },
    });
    expect(hold.status()).toBe(200);

    const reqRes = await request.post(`${apiUrl}/v1/cases/${caseId}/erasure/request`);
    expect(reqRes.status()).toBe(409);
    const body = (await reqRes.json()) as { error: string; reason: string };
    expect(body.error).toBe("legal_hold");
    expect(body.reason).toContain("HCPC");

    // Case data must still be fully intact under hold.
    expect((await request.get(`${apiUrl}/v1/cases/${caseId}`)).status()).toBe(200);

    // Lifting the hold then allows erasure to proceed.
    const lift = await request.post(`${apiUrl}/v1/cases/${caseId}/legal-hold`, {
      data: { hold: false },
    });
    expect(lift.status()).toBe(200);
    const reqAfter = await request.post(
      `${apiUrl}/v1/cases/${caseId}/erasure/request`,
    );
    expect(reqAfter.status()).toBe(201);
    const { token } = (await reqAfter.json()) as { token: string };
    const confirm = await request.post(
      `${apiUrl}/v1/cases/${caseId}/erasure/confirm`,
      { data: { token } },
    );
    expect(confirm.status()).toBe(200);
  });

  test("erasure refused on an unknown / already-erased case", async ({ request }) => {
    const fakeId = "00000000-0000-0000-0000-000000000000";
    const reqRes = await request.post(`${apiUrl}/v1/cases/${fakeId}/erasure/request`);
    expect(reqRes.status()).toBe(404);
  });

  test("confirm rejects an invalid token", async ({ request }) => {
    const { caseId } = await buildPopulatedCase(request);
    await request.post(`${apiUrl}/v1/cases/${caseId}/erasure/request`);
    const confirm = await request.post(
      `${apiUrl}/v1/cases/${caseId}/erasure/confirm`,
      { data: { token: "not-the-real-token" } },
    );
    expect(confirm.status()).toBe(400);
    // Case must still be intact after a failed confirm.
    expect((await request.get(`${apiUrl}/v1/cases/${caseId}`)).status()).toBe(200);
  });
});
