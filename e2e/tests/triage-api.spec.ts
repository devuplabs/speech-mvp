import { test, expect } from "@playwright/test";
import { intakePersonas } from "../fixtures/intake-personas.js";

/**
 * API spec for the triage endpoint + how it surfaces in `GET /v1/cases/:id`.
 *
 * Covers:
 *   - Each of the 4 MVP outcomes is accepted.
 *   - Unknown outcomes are rejected with 400.
 *   - Triage advances case status to triaged → plan_ready (stub session plan
 *     runs automatically after triage).
 *   - The triage row appears in `GET /v1/cases/:id` `triage[]` so the
 *     clinician UI can rehydrate the selected outcome on revisit.
 *   - Repeat triage is allowed (audit-friendly); the latest row wins for UI
 *     rehydration ordering.
 */

const apiUrl =
  process.env.SONA_API_URL ?? "https://sona-api-dev-3rhenudy6a-nw.a.run.app";

const aria = intakePersonas.find((p) => p.id === "aria_speech_sounds_4yo")!;

async function bootstrap(request: import("@playwright/test").APIRequestContext) {
  const boot = await request.post(`${apiUrl}/v1/demo/bootstrap`, { data: {} });
  expect([200, 201]).toContain(boot.status());
  return ((await boot.json()) as { tenantId: string }).tenantId;
}

async function newSubmittedCase(
  request: import("@playwright/test").APIRequestContext,
  tenantId: string,
  childSuffix: string,
) {
  const childName = `${aria.childDisplayName} · triage-spec ${childSuffix}`;
  const caseRes = await request.post(`${apiUrl}/v1/cases`, {
    data: {
      tenantId,
      parentEmail: aria.parentEmail,
      childDisplayName: childName,
    },
  });
  expect(caseRes.status()).toBe(201);
  const { id } = (await caseRes.json()) as { id: string };
  const submit = await request.post(`${apiUrl}/v1/cases/${id}/intake`, {
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
  expect(submit.status()).toBe(201);
  return id;
}

test.describe("Triage endpoint (POST /v1/cases/:id/triage)", () => {
  test("accepts each of the 4 MVP outcomes", async ({ request }) => {
    const outcomes = [
      "strategy_only",
      "short_block",
      "full_assessment",
      "refer_out",
    ] as const;
    const tenantId = await bootstrap(request);
    for (const outcome of outcomes) {
      const caseId = await newSubmittedCase(request, tenantId, outcome);
      const res = await request.post(`${apiUrl}/v1/cases/${caseId}/triage`, {
        data: { outcome, reason: `Spec accepts ${outcome}` },
      });
      expect(res.status(), `outcome=${outcome}`).toBe(200);
      const body = (await res.json()) as {
        case: { status: string };
        triage: { outcome: string };
      };
      expect(body.triage.outcome).toBe(outcome);
      // Stub session plan runs immediately after triage → status moves to plan_ready.
      expect(["plan_ready", "triaged"]).toContain(body.case.status);
    }
  });

  test("rejects unknown outcomes with 400", async ({ request }) => {
    const tenantId = await bootstrap(request);
    const caseId = await newSubmittedCase(request, tenantId, "bad-outcome");
    const res = await request.post(`${apiUrl}/v1/cases/${caseId}/triage`, {
      data: { outcome: "no_such_outcome", reason: "should be rejected" },
    });
    expect(res.status()).toBe(400);
    const body = (await res.json()) as { error?: string };
    expect(body.error).toBe("validation_failed");
  });

  test("triage row appears in GET /v1/cases/:id triage[] for rehydration", async ({
    request,
  }) => {
    const tenantId = await bootstrap(request);
    const caseId = await newSubmittedCase(request, tenantId, "rehydrate");
    await request.post(`${apiUrl}/v1/cases/${caseId}/triage`, {
      data: { outcome: "short_block", reason: "Spec rehydrate" },
    });
    const detail = await request.get(`${apiUrl}/v1/cases/${caseId}`);
    expect(detail.status()).toBe(200);
    const body = (await detail.json()) as {
      triage?: Array<{ outcome: string; reason: string | null }>;
    };
    expect(body.triage, "GET /v1/cases must include triage[]").toBeDefined();
    expect(body.triage!.length).toBeGreaterThanOrEqual(1);
    expect(body.triage![0].outcome).toBe("short_block");
    expect(body.triage![0].reason).toContain("rehydrate");
  });

  test("repeat triage is allowed (audit trail)", async ({ request }) => {
    const tenantId = await bootstrap(request);
    const caseId = await newSubmittedCase(request, tenantId, "repeat");
    const first = await request.post(`${apiUrl}/v1/cases/${caseId}/triage`, {
      data: { outcome: "short_block", reason: "first pass" },
    });
    expect(first.status()).toBe(200);
    const second = await request.post(`${apiUrl}/v1/cases/${caseId}/triage`, {
      data: { outcome: "full_assessment", reason: "clinician changed mind" },
    });
    expect(second.status()).toBe(200);
    const detail = await request.get(`${apiUrl}/v1/cases/${caseId}`);
    const body = (await detail.json()) as {
      triage: Array<{ outcome: string; reason: string | null; recordedAt: string }>;
    };
    expect(body.triage.length).toBeGreaterThanOrEqual(2);
    const outcomes = body.triage.map((t) => t.outcome);
    expect(outcomes).toContain("short_block");
    expect(outcomes).toContain("full_assessment");
  });
});
