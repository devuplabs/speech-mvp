import { test, expect } from "@playwright/test";
import { e2eChildName, validIntakeAnswers } from "../fixtures/valid-intake.js";

const apiUrl =
  process.env.SONA_API_URL ?? "https://sona-api-dev-3rhenudy6a-nw.a.run.app";

test.describe("API full intake flow", () => {
  test("bootstrap, create case, draft, submit — case on clinician list", async ({
    request,
  }) => {
    const childName = e2eChildName();
    const answers = validIntakeAnswers(childName);

    const boot = await request.post(`${apiUrl}/v1/demo/bootstrap`, { data: {} });
    expect([200, 201]).toContain(boot.status());
    const { tenantId } = await boot.json();

    const caseRes = await request.post(`${apiUrl}/v1/cases`, {
      data: { tenantId },
    });
    expect(caseRes.status()).toBe(201);
    const { id: caseId } = await caseRes.json();

    const draft = await request.put(
      `${apiUrl}/v1/cases/${caseId}/intake/draft`,
      {
        data: {
          answers: { ...answers, formStep: 4 },
          parentEmail: answers.email,
          childDisplayName: childName,
        },
      },
    );
    expect(draft.status()).toBe(200);

    const submit = await request.post(`${apiUrl}/v1/cases/${caseId}/intake`, {
      data: {
        answers,
        consentVersion: "mvp-v1",
        parentEmail: answers.email,
        childDisplayName: childName,
      },
    });
    expect(submit.status()).toBe(201);

    const list = await request.get(`${apiUrl}/v1/tenants/${tenantId}/cases`);
    expect(list.status()).toBe(200);
    const { cases } = await list.json();
    const row = (cases as Array<Record<string, string>>).find(
      (c) => c.id === caseId,
    );
    expect(row).toBeDefined();
    expect(row!.childDisplayName).toBe(childName);
    // Submitted intakes appear on Today; worker may advance status past intake_submitted.
    expect(row!.status).not.toBe("intake_pending");
  });

  test("create case accepts nullish parentEmail (Flutter may send null)", async ({
    request,
  }) => {
    const boot = await request.post(`${apiUrl}/v1/demo/bootstrap`, { data: {} });
    const { tenantId } = await boot.json();
    const res = await request.post(`${apiUrl}/v1/cases`, {
      data: { tenantId, parentEmail: null },
    });
    expect(res.status()).toBe(201);
  });
});
