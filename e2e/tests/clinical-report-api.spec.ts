import { test, expect } from "@playwright/test";

const apiUrl = process.env.SONA_API_URL ?? "http://127.0.0.1:8081";

test.describe("clinical report API", () => {
  test("publish summary generates report list and PDF export", async ({ request }) => {
    const boot = await request.post(`${apiUrl}/v1/demo/bootstrap`, { data: {} });
    const { tenantId } = (await boot.json()) as { tenantId: string };

    const created = await request.post(`${apiUrl}/v1/cases`, {
      data: { tenantId, childDisplayName: "Report Child", parentEmail: "report@example.com" },
    });
    expect(created.status()).toBe(201);
    const { id: caseId } = (await created.json()) as { id: string };

    await request.put(`${apiUrl}/v1/cases/${caseId}/intake/draft`, {
      data: { answers: { formStep: 1, version: 1, childName: "Report Child" } },
    });
    await request.post(`${apiUrl}/v1/cases/${caseId}/intake`, {
      data: {
        answers: { formStep: 8, version: 1, childName: "Report Child" },
        consentVersion: "mvp-v1",
      },
    });

    await request.post(`${apiUrl}/v1/cases/${caseId}/triage`, {
      data: { outcome: "short_block" },
    });

    const publish = await request.post(`${apiUrl}/v1/cases/${caseId}/parent-summary/publish`, {
      data: {},
    });
    expect(publish.ok()).toBeTruthy();

    const list = await request.get(`${apiUrl}/v1/tenants/${tenantId}/clinical-reports`);
    expect(list.ok()).toBeTruthy();
    const items = (await list.json()) as { items: { caseId: string }[] };
    expect(items.items.some((i) => i.caseId === caseId)).toBe(true);

    const pdf = await request.get(`${apiUrl}/v1/cases/${caseId}/clinical-report.pdf`);
    expect(pdf.status()).toBe(200);
    expect(pdf.headers()["content-type"]).toContain("application/pdf");
    const bytes = await pdf.body();
    expect(bytes.slice(0, 5).toString()).toBe("%PDF-");
  });
});
