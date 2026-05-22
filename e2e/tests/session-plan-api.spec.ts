import { test, expect } from "@playwright/test";
import { intakePersonas } from "../fixtures/intake-personas.js";

/**
 * API spec for the session-plan PUT endpoint + how it surfaces in
 * `GET /v1/cases/:id` for clinician-screen rehydration.
 *
 * Covers:
 *   - Edits to sections are persisted and round-trip via GET.
 *   - reviewStatus toggles between 'draft' and 'final'.
 *   - PUT before the stub generator has run returns 409.
 *   - Validation rejects items longer than the cap and unknown sections.
 */

const apiUrl =
  process.env.SONA_API_URL ?? "https://sona-api-dev-3rhenudy6a-nw.a.run.app";

const aria = intakePersonas.find((p) => p.id === "aria_speech_sounds_4yo")!;

async function bootstrap(request: import("@playwright/test").APIRequestContext) {
  const boot = await request.post(`${apiUrl}/v1/demo/bootstrap`, { data: {} });
  expect([200, 201]).toContain(boot.status());
  return ((await boot.json()) as { tenantId: string }).tenantId;
}

async function newTriagedCase(
  request: import("@playwright/test").APIRequestContext,
  tenantId: string,
  suffix: string,
) {
  const childName = `${aria.childDisplayName} · plan-spec ${suffix}`;
  const caseRes = await request.post(`${apiUrl}/v1/cases`, {
    data: {
      tenantId,
      parentEmail: aria.parentEmail,
      childDisplayName: childName,
    },
  });
  expect(caseRes.status()).toBe(201);
  const { id: caseId } = (await caseRes.json()) as { id: string };
  await request.post(`${apiUrl}/v1/cases/${caseId}/intake`, {
    data: {
      answers: {
        ...aria.answers,
        formStep: 8,
        consentGuardian: true,
        consentPrivacy: true,
        consentAccurate: true,
      },
      consentVersion: "mvp-v1",
      parentEmail: aria.parentEmail,
      childDisplayName: childName,
    },
  });
  await request.post(`${apiUrl}/v1/cases/${caseId}/triage`, {
    data: { outcome: "short_block", reason: "spec" },
  });
  return caseId;
}

interface PlanDraft {
  content?: {
    sections?: Record<string, string[]>;
    reviewStatus?: string;
    source?: string;
  };
}

async function getPlan(
  request: import("@playwright/test").APIRequestContext,
  caseId: string,
): Promise<PlanDraft | undefined> {
  const res = await request.get(`${apiUrl}/v1/cases/${caseId}`);
  expect(res.status()).toBe(200);
  const body = (await res.json()) as {
    drafts: Array<{ kind: string; content: unknown }>;
  };
  return body.drafts.find((d) => d.kind === "session_plan") as
    | PlanDraft
    | undefined;
}

test.describe("Session-plan endpoint (PUT /v1/cases/:id/session-plan)", () => {
  test("section edits persist and round-trip via GET", async ({ request }) => {
    const tenantId = await bootstrap(request);
    const caseId = await newTriagedCase(request, tenantId, "edits");

    const editedSections = {
      goals: ["Clinician-edited goal 1", "Clinician-edited goal 2"],
      activities: ["DEAP screen", "Picture-naming"],
      homePractice: ["Daily 5-min sound game"],
      materials: ["DEAP cards", "Sound symbol prompts"],
      parentGoals: ["Acknowledge clear speech"],
    };
    const put = await request.put(
      `${apiUrl}/v1/cases/${caseId}/session-plan`,
      { data: { sections: editedSections, reviewStatus: "draft" } },
    );
    expect(put.status()).toBe(200);

    const plan = await getPlan(request, caseId);
    expect(plan?.content?.sections).toEqual(editedSections);
    expect(plan?.content?.reviewStatus).toBe("draft");
    expect(plan?.content?.source).toBe("clinician_edited");
  });

  test("reviewStatus toggles between draft and final", async ({ request }) => {
    const tenantId = await bootstrap(request);
    const caseId = await newTriagedCase(request, tenantId, "status");

    const finalPut = await request.put(
      `${apiUrl}/v1/cases/${caseId}/session-plan`,
      { data: { reviewStatus: "final" } },
    );
    expect(finalPut.status()).toBe(200);

    const planFinal = await getPlan(request, caseId);
    expect(planFinal?.content?.reviewStatus).toBe("final");

    const draftPut = await request.put(
      `${apiUrl}/v1/cases/${caseId}/session-plan`,
      { data: { reviewStatus: "draft" } },
    );
    expect(draftPut.status()).toBe(200);

    const planDraft = await getPlan(request, caseId);
    expect(planDraft?.content?.reviewStatus).toBe("draft");
  });

  test("rejects items longer than the per-bullet cap with 400", async ({
    request,
  }) => {
    const tenantId = await bootstrap(request);
    const caseId = await newTriagedCase(request, tenantId, "validation");

    const oversize = "x".repeat(1001);
    const res = await request.put(
      `${apiUrl}/v1/cases/${caseId}/session-plan`,
      {
        data: {
          sections: {
            goals: [oversize],
            activities: [],
            homePractice: [],
            materials: [],
            parentGoals: [],
          },
        },
      },
    );
    expect(res.status()).toBe(400);
    const body = (await res.json()) as { error?: string };
    expect(body.error).toBe("validation_failed");
  });

  test("returns 404 for an unknown case id", async ({ request }) => {
    const res = await request.put(
      `${apiUrl}/v1/cases/00000000-0000-0000-0000-000000000000/session-plan`,
      { data: { reviewStatus: "draft" } },
    );
    expect(res.status()).toBe(404);
  });

  test("returns 409 if session plan stub hasn't run yet", async ({
    request,
  }) => {
    const tenantId = await bootstrap(request);
    // Make a fresh case that has only submitted intake (no triage yet → no plan).
    const childName = `${aria.childDisplayName} · plan-spec pre-triage`;
    const caseRes = await request.post(`${apiUrl}/v1/cases`, {
      data: {
        tenantId,
        parentEmail: aria.parentEmail,
        childDisplayName: childName,
      },
    });
    const { id: caseId } = (await caseRes.json()) as { id: string };
    await request.post(`${apiUrl}/v1/cases/${caseId}/intake`, {
      data: {
        answers: {
          ...aria.answers,
          formStep: 8,
          consentGuardian: true,
          consentPrivacy: true,
          consentAccurate: true,
        },
        consentVersion: "mvp-v1",
        parentEmail: aria.parentEmail,
        childDisplayName: childName,
      },
    });

    const res = await request.put(
      `${apiUrl}/v1/cases/${caseId}/session-plan`,
      { data: { reviewStatus: "draft" } },
    );
    expect(res.status()).toBe(409);
    const body = (await res.json()) as { error?: string };
    expect(body.error).toBe("session_plan_not_drafted");
  });
});
