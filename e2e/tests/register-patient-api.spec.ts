import { test, expect } from "@playwright/test";

const apiUrl = process.env.SONA_API_URL ?? "http://127.0.0.1:8081";

test.describe("register patient API", () => {
  test("registration round-trip and list cases", async ({ request }) => {
    const boot = await request.post(`${apiUrl}/v1/demo/bootstrap`, {
      data: {},
    });
    expect(boot.ok()).toBeTruthy();
    const { tenantId } = (await boot.json()) as { tenantId: string };

    const reg = await request.post(`${apiUrl}/v1/clinicians/me/patients`, {
      data: {
        tenantId,
        childFirstName: "E2E Child",
        dateOfBirth: "01 / 06 / 2018",
        parentName: "E2E Parent",
        parentEmail: `e2e-register-${Date.now()}@example.com`,
        referralSource: "gp",
        initialConcerns: "Speech delay",
        sendIntakeLink: true,
      },
    });
    expect(reg.status()).toBe(201);
    const body = (await reg.json()) as {
      case: { id: string; status: string };
      intakeLink: { url: string; expiresAt: string };
    };
    expect(body.case.status).toBe("intake_pending");
    expect(body.intakeLink.url).toContain("?t=");

    const token = new URL(body.intakeLink.url).searchParams.get("t");
    expect(token).toBeTruthy();
    const resolve = await request.get(`${apiUrl}/v1/intake-links/${token}`);
    expect(resolve.ok()).toBeTruthy();
    const resolved = (await resolve.json()) as { caseId: string };
    expect(resolved.caseId).toBe(body.case.id);

    const list = await request.get(`${apiUrl}/v1/tenants/${tenantId}/cases`);
    expect(list.ok()).toBeTruthy();
    const cases = (await list.json()) as { cases: { id: string }[] };
    expect(cases.cases.some((c) => c.id === body.case.id)).toBe(true);
  });

  test("rejects invalid email with 400", async ({ request }) => {
    const boot = await request.post(`${apiUrl}/v1/demo/bootstrap`, { data: {} });
    const { tenantId } = (await boot.json()) as { tenantId: string };

    const reg = await request.post(`${apiUrl}/v1/clinicians/me/patients`, {
      data: {
        tenantId,
        childFirstName: "Bad",
        dateOfBirth: "01 / 01 / 2020",
        parentName: "Parent",
        parentEmail: "invalid",
        referralSource: "self",
        sendIntakeLink: true,
      },
    });
    expect(reg.status()).toBe(400);
  });
});
