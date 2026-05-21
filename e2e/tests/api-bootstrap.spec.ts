import { test, expect } from "@playwright/test";

const apiUrl =
  process.env.SONA_API_URL ?? "https://sona-api-dev-3rhenudy6a-nw.a.run.app";

test.describe("API smoke", () => {
  test("demo bootstrap returns 200 or 201 with tenantId", async ({ request }) => {
    const res = await request.post(`${apiUrl}/v1/demo/bootstrap`, {
      data: {},
      headers: { "Content-Type": "application/json" },
    });
    expect([200, 201]).toContain(res.status());
    const body = await res.json();
    expect(body.tenantId).toMatch(
      /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i,
    );
  });

  test("create case and save intake draft", async ({ request }) => {
    const boot = await request.post(`${apiUrl}/v1/demo/bootstrap`, { data: {} });
    const { tenantId } = await boot.json();
    const caseRes = await request.post(`${apiUrl}/v1/cases`, {
      data: {
        tenantId,
        parentEmail: "e2e@example.com",
        childDisplayName: "E2E",
      },
    });
    expect(caseRes.status()).toBe(201);
    const { id: caseId } = await caseRes.json();
    const draft = await request.put(`${apiUrl}/v1/cases/${caseId}/intake/draft`, {
      data: {
        answers: { version: 1, email: "e2e@example.com", formStep: 1 },
        parentEmail: "e2e@example.com",
      },
    });
    expect(draft.status()).toBe(200);
  });
});
