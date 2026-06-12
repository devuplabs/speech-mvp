import { test, expect, type APIRequestContext } from "@playwright/test";
import { e2eChildName, validIntakeAnswers } from "../fixtures/valid-intake.js";

const apiUrl = process.env.SONA_API_URL ?? "http://127.0.0.1:8081";

/**
 * Case state-machine negatives (DEV-34). The clinical journey is
 * intake_pending → intake_submitted → prep_drafting → prep_ready → triaged →
 * plan_drafting → plan_ready → summary_sent; this spec proves the API
 * refuses to jump steps (with a clear 4xx error code, never a silent 200)
 * and refuses repeated/locked writes.
 */

async function bootstrapE2eTenant(request: APIRequestContext): Promise<string> {
  const boot = await request.post(`${apiUrl}/v1/demo/bootstrap`, {
    data: { practice: "e2e" },
  });
  expect([200, 201]).toContain(boot.status());
  return ((await boot.json()) as { tenantId: string }).tenantId;
}

async function createCase(request: APIRequestContext, tenantId: string) {
  const childName = e2eChildName();
  const caseRes = await request.post(`${apiUrl}/v1/cases`, {
    data: { tenantId, childDisplayName: childName },
  });
  expect(caseRes.status()).toBe(201);
  const { id } = (await caseRes.json()) as { id: string };
  return { caseId: id, childName };
}

async function submitIntake(
  request: APIRequestContext,
  caseId: string,
  childName: string,
) {
  const answers = validIntakeAnswers(childName);
  const submit = await request.post(`${apiUrl}/v1/cases/${caseId}/intake`, {
    data: {
      answers,
      consentVersion: "mvp-v1",
      parentEmail: answers.email,
      childDisplayName: childName,
    },
  });
  expect(submit.status()).toBe(201);
  return submit;
}

async function getCase(request: APIRequestContext, caseId: string) {
  const res = await request.get(`${apiUrl}/v1/cases/${caseId}`);
  expect(res.status()).toBe(200);
  return (await res.json()) as {
    case: { status: string };
    intake: { submittedAt: string | null } | null;
    drafts: { kind: string }[];
  };
}

test.describe("state-machine negatives", () => {
  test("triage before intake submission is rejected and has no side effects", async ({
    request,
  }) => {
    const tenantId = await bootstrapE2eTenant(request);
    const { caseId, childName } = await createCase(request, tenantId);

    const early = await request.post(`${apiUrl}/v1/cases/${caseId}/triage`, {
      data: { outcome: "strategy_only" },
    });
    expect(early.status()).toBe(409);
    expect(((await early.json()) as { error: string }).error).toBe(
      "intake_not_submitted",
    );

    // Nothing moved: still awaiting intake, no session plan was drafted.
    const detail = await getCase(request, caseId);
    expect(detail.case.status).toBe("intake_pending");
    expect(detail.drafts).toEqual([]);

    // After submission the same call succeeds.
    await submitIntake(request, caseId, childName);
    const triage = await request.post(`${apiUrl}/v1/cases/${caseId}/triage`, {
      data: { outcome: "short_block" },
    });
    expect(triage.status()).toBe(200);
    const after = await getCase(request, caseId);
    expect(after.case.status).toBe("plan_ready");

    // Triage on an unknown case is a clean 404.
    const ghost = await request.post(
      `${apiUrl}/v1/cases/00000000-0000-0000-0000-000000000000/triage`,
      { data: { outcome: "refer_out" } },
    );
    expect(ghost.status()).toBe(404);
  });

  test("parent summary cannot be published before triage", async ({ request }) => {
    const tenantId = await bootstrapE2eTenant(request);
    const { caseId, childName } = await createCase(request, tenantId);
    const html = "<!DOCTYPE html><html><body><p>Too early</p></body></html>";

    // intake_pending → blocked.
    const beforeIntake = await request.post(
      `${apiUrl}/v1/cases/${caseId}/parent-summary/publish`,
      { data: { htmlBody: html } },
    );
    expect(beforeIntake.status()).toBe(409);
    expect(((await beforeIntake.json()) as { error: string }).error).toBe(
      "case_not_ready",
    );

    // Submitted but not yet triaged (prep_ready) → still blocked.
    await submitIntake(request, caseId, childName);
    const beforeTriage = await request.post(
      `${apiUrl}/v1/cases/${caseId}/parent-summary/publish`,
      { data: { htmlBody: html } },
    );
    expect(beforeTriage.status()).toBe(409);
    expect(((await beforeTriage.json()) as { error: string }).error).toBe(
      "case_not_ready",
    );

    // Nothing was published or sent.
    const detail = await getCase(request, caseId);
    expect(detail.case.status).toBe("prep_ready");
    const view = await request.get(`${apiUrl}/v1/cases/${caseId}/parent-summary`);
    expect(view.status()).toBe(404);

    // Triage unlocks publishing; re-publishing an amended summary stays legal.
    const triage = await request.post(`${apiUrl}/v1/cases/${caseId}/triage`, {
      data: { outcome: "strategy_only" },
    });
    expect(triage.status()).toBe(200);

    const publish = await request.post(
      `${apiUrl}/v1/cases/${caseId}/parent-summary/publish`,
      { data: { htmlBody: html.replace("Too early", "Right on time") } },
    );
    expect(publish.status()).toBe(200);
    expect((await getCase(request, caseId)).case.status).toBe("summary_sent");

    const republish = await request.post(
      `${apiUrl}/v1/cases/${caseId}/parent-summary/publish`,
      { data: { htmlBody: html.replace("Too early", "Amended") } },
    );
    expect(republish.status()).toBe(200);
    const published = await request.get(`${apiUrl}/v1/cases/${caseId}/parent-summary`);
    expect(published.status()).toBe(200);
    expect(await published.text()).toContain("Amended");

    // Publish for an unknown case is a clean 404.
    const ghost = await request.post(
      `${apiUrl}/v1/cases/00000000-0000-0000-0000-000000000000/parent-summary/publish`,
      { data: { htmlBody: html } },
    );
    expect(ghost.status()).toBe(404);
  });

  test("double intake submission and post-submission edits are rejected", async ({
    request,
  }) => {
    const tenantId = await bootstrapE2eTenant(request);
    const { caseId, childName } = await createCase(request, tenantId);
    const answers = validIntakeAnswers(childName);

    await submitIntake(request, caseId, childName);

    const again = await request.post(`${apiUrl}/v1/cases/${caseId}/intake`, {
      data: { answers, consentVersion: "mvp-v1" },
    });
    expect(again.status()).toBe(409);
    expect(((await again.json()) as { error: string }).error).toBe(
      "intake_already_submitted",
    );

    const lateDraft = await request.put(`${apiUrl}/v1/cases/${caseId}/intake/draft`, {
      data: { answers: { ...answers, mainConcern: "Sneaky late edit" } },
    });
    expect(lateDraft.status()).toBe(409);
    expect(((await lateDraft.json()) as { error: string }).error).toBe(
      "intake_already_submitted",
    );

    // The submitted answers were not overwritten.
    const detail = await getCase(request, caseId);
    expect(detail.case.status).toBe("prep_ready");
    expect(detail.intake?.submittedAt).toBeTruthy();
  });

  test("writes to a locked intake are rejected", async ({ request }) => {
    const tenantId = await bootstrapE2eTenant(request);
    const { caseId, childName } = await createCase(request, tenantId);
    const answers = validIntakeAnswers(childName);

    const lock = await request.post(`${apiUrl}/v1/cases/${caseId}/intake/lock`);
    expect(lock.status()).toBe(204);

    const draft = await request.put(`${apiUrl}/v1/cases/${caseId}/intake/draft`, {
      data: { answers: { ...answers, formStep: 3 } },
    });
    expect(draft.status()).toBe(409);
    expect(((await draft.json()) as { error: string }).error).toBe("intake_locked");

    const submit = await request.post(`${apiUrl}/v1/cases/${caseId}/intake`, {
      data: { answers, consentVersion: "mvp-v1" },
    });
    expect(submit.status()).toBe(409);
    expect(((await submit.json()) as { error: string }).error).toBe("intake_locked");

    expect((await getCase(request, caseId)).case.status).toBe("intake_pending");
  });

  test("clinical report cannot be generated before triage", async ({ request }) => {
    const tenantId = await bootstrapE2eTenant(request);
    const { caseId, childName } = await createCase(request, tenantId);

    const beforeIntake = await request.post(
      `${apiUrl}/v1/cases/${caseId}/clinical-report/generate`,
    );
    expect(beforeIntake.status()).toBe(409);
    expect(((await beforeIntake.json()) as { error: string }).error).toBe(
      "case_not_ready",
    );

    await submitIntake(request, caseId, childName);
    const beforeTriage = await request.post(
      `${apiUrl}/v1/cases/${caseId}/clinical-report/generate`,
    );
    expect(beforeTriage.status()).toBe(409);

    const triage = await request.post(`${apiUrl}/v1/cases/${caseId}/triage`, {
      data: { outcome: "full_assessment" },
    });
    expect(triage.status()).toBe(200);

    const after = await request.post(
      `${apiUrl}/v1/cases/${caseId}/clinical-report/generate`,
    );
    expect(after.status()).toBe(200);
  });
});
