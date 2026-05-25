import { test, expect } from "@playwright/test";

const apiUrl = process.env.SONA_API_URL ?? "http://127.0.0.1:8081";

test.describe("questionnaire orchestration API", () => {
  test("resend, lock blocks draft, list includes case", async ({ request }) => {
    const boot = await request.post(`${apiUrl}/v1/demo/bootstrap`, { data: {} });
    const { tenantId } = (await boot.json()) as { tenantId: string };

    const email = `e2e-q-${Date.now()}@example.com`;
    const reg = await request.post(`${apiUrl}/v1/clinicians/me/patients`, {
      data: {
        tenantId,
        childFirstName: "Quest Child",
        dateOfBirth: "01 / 06 / 2018",
        parentName: "Parent",
        parentEmail: email,
        referralSource: "school",
        templateId: "short",
        sendIntakeLink: true,
      },
    });
    expect(reg.status()).toBe(201);
    const { case: caseRow } = (await reg.json()) as { case: { id: string } };
    const caseId = caseRow.id;

    const resend = await request.post(`${apiUrl}/v1/cases/${caseId}/intake-links/resend`, {
      data: { templateId: "short" },
    });
    expect(resend.ok()).toBeTruthy();
    const link = (await resend.json()) as { url: string; templateId: string };
    expect(link.templateId).toBe("short");

    const lock = await request.post(`${apiUrl}/v1/cases/${caseId}/intake/lock`);
    expect(lock.status()).toBe(204);

    const draft = await request.put(`${apiUrl}/v1/cases/${caseId}/intake/draft`, {
      data: { answers: { formStep: 2, version: 1, childName: "X" } },
    });
    expect(draft.status()).toBe(409);
    const draftBody = (await draft.json()) as { error: string };
    expect(draftBody.error).toBe("intake_locked");

    const list = await request.get(`${apiUrl}/v1/tenants/${tenantId}/intake-submissions`);
    expect(list.ok()).toBeTruthy();
    const items = (await list.json()) as {
      items: { caseId: string; locked: boolean }[];
    };
    expect(items.items.some((i) => i.caseId === caseId && i.locked)).toBe(true);
  });
});
