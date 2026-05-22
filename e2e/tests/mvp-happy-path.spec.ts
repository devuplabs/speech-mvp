import { test, expect } from "@playwright/test";
import { intakePersonas } from "../fixtures/intake-personas.js";

/**
 * End-to-end happy-path spec for the entire MVP flow, against the API.
 *
 * Walks one persona through every stage of the case lifecycle and asserts
 * the artifacts each stage produces. Equivalent to the manual demo flow the
 * brief calls for, in a deterministic <5s test.
 *
 * Stages covered:
 *   1. demo/bootstrap → tenant
 *   2. create case + submit intake (persona)
 *   3. dashboard list includes the case past intake_pending
 *   4. prep_brief AI draft auto-generated, includes intake-derived probes
 *   5. record triage (4-outcome enum) → triage row appears in GET detail
 *   6. session_plan AI draft auto-generated after triage
 *   7. edit session plan, mark final
 *   8. preview parent summary (tone-aware projection)
 *   9. publish parent summary (with chosen options) → case = summary_sent
 *  10. GET parent-summary HTML for portal view
 *  11. GET parent-summary.pdf is a valid %PDF
 *
 * Keep this as the deploy-verification spec for the full flow. The
 * `parent-intake-full.spec.ts` hybrid spec covers the Flutter web UI for
 * parent intake submission separately.
 */

const apiUrl =
  process.env.SONA_API_URL ?? "https://sona-api-dev-3rhenudy6a-nw.a.run.app";

const aria = intakePersonas.find((p) => p.id === "aria_speech_sounds_4yo")!;

const summaryOptions = {
  tone: "warm",
  readingLevel: "standard",
  sections: {
    whatWeDiscussed: true,
    planForFirstSession: true,
    homePractice: true,
    nextSteps: true,
  },
  aiDisclosure: true,
};

test.describe("MVP happy-path E2E (API, single persona)", () => {
  test("intake → dashboard → prep → triage → plan → summary → PDF", async ({
    request,
  }) => {
    test.setTimeout(60_000);

    // 1. Bootstrap tenant.
    const boot = await request.post(`${apiUrl}/v1/demo/bootstrap`, { data: {} });
    expect([200, 201]).toContain(boot.status());
    const { tenantId } = (await boot.json()) as { tenantId: string };

    // 2. Create case + submit intake.
    const childName = `${aria.childDisplayName} · e2e ${new Date()
      .toISOString()
      .slice(11, 19)}`;
    const caseRes = await request.post(`${apiUrl}/v1/cases`, {
      data: {
        tenantId,
        parentEmail: aria.parentEmail,
        childDisplayName: childName,
      },
    });
    expect(caseRes.status()).toBe(201);
    const { id: caseId } = (await caseRes.json()) as { id: string };

    const submit = await request.post(`${apiUrl}/v1/cases/${caseId}/intake`, {
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

    // 3. Dashboard list shows the case past intake_pending.
    const list = await request.get(`${apiUrl}/v1/tenants/${tenantId}/cases`);
    expect(list.status()).toBe(200);
    const { cases } = (await list.json()) as {
      cases: Array<{ id: string; status: string; childDisplayName: string }>;
    };
    const row = cases.find((c) => c.id === caseId);
    expect(row, "case must appear on tenant dashboard").toBeDefined();
    expect(row!.status).not.toBe("intake_pending");
    expect(row!.childDisplayName).toBe(childName);

    // 4. Prep brief auto-generated from intake (persona-derived probes).
    const afterIntake = await request.get(`${apiUrl}/v1/cases/${caseId}`);
    const afterIntakeBody = (await afterIntake.json()) as {
      drafts: Array<{ kind: string; content: Record<string, unknown> }>;
    };
    const prepBrief = afterIntakeBody.drafts.find((d) => d.kind === "prep_brief");
    expect(prepBrief, "prep_brief draft must exist after submit").toBeDefined();
    const probes = prepBrief!.content.probeAreas as string[];
    expect(probes.some((p) => p.includes("Confirm primary concern"))).toBe(true);
    expect(probes.some((p) => p.includes("Speech sounds"))).toBe(true);

    // 5. Record triage; one of the 4 MVP outcomes.
    const triage = await request.post(`${apiUrl}/v1/cases/${caseId}/triage`, {
      data: {
        outcome: "short_block",
        reason: "E2E happy path — block of 6 sessions",
      },
    });
    expect(triage.status()).toBe(200);

    // 6. Session plan auto-drafted after triage; triage row visible on GET.
    const afterTriage = await request.get(`${apiUrl}/v1/cases/${caseId}`);
    const afterTriageBody = (await afterTriage.json()) as {
      drafts: Array<{ kind: string; content: Record<string, unknown> }>;
      triage: Array<{ outcome: string; reason: string | null }>;
    };
    const plan = afterTriageBody.drafts.find((d) => d.kind === "session_plan");
    expect(plan, "session_plan must auto-draft after triage").toBeDefined();
    expect(afterTriageBody.triage.length).toBeGreaterThanOrEqual(1);
    expect(afterTriageBody.triage[0].outcome).toBe("short_block");

    // 7. Edit session plan + mark final.
    const editedSections = {
      goals: [
        "DEAP screen at session 1 (clinician-edited).",
        "Set 2 priority targets (final consonant deletion + stopping).",
      ],
      activities: ["Articulation probe — 24-word picture set."],
      homePractice: ["5 min daily target-sound game with parent."],
      materials: ["DEAP cards", "Sound prompt cards"],
      parentGoals: ["Acknowledge clear speech; never correct mid-flow."],
    };
    const planPut = await request.put(
      `${apiUrl}/v1/cases/${caseId}/session-plan`,
      { data: { sections: editedSections, reviewStatus: "final" } },
    );
    expect(planPut.status()).toBe(200);

    // 8. Preview parent summary with chosen options.
    const preview = await request.post(
      `${apiUrl}/v1/cases/${caseId}/parent-summary/preview`,
      { data: { options: summaryOptions } },
    );
    expect(preview.status()).toBe(200);
    const previewBody = (await preview.json()) as {
      projection: {
        title: string;
        sections: Array<{ heading: string; bullets: string[] }>;
      };
    };
    expect(previewBody.projection.title).toContain("Aria");
    expect(previewBody.projection.sections.length).toBe(4);
    // Clinician-edited bullets surface in the preview.
    const planSection = previewBody.projection.sections.find((s) =>
      s.heading.includes("work on together"),
    );
    expect(planSection?.bullets.some((b) => b.includes("DEAP screen"))).toBe(true);

    // 9. Publish parent summary with options; case advances to summary_sent.
    const pub = await request.post(
      `${apiUrl}/v1/cases/${caseId}/parent-summary/publish`,
      { data: { options: summaryOptions } },
    );
    expect(pub.status()).toBe(200);
    const pubBody = (await pub.json()) as {
      case: { status: string };
      viewPath: string;
      pdfPath: string;
    };
    expect(pubBody.case.status).toBe("summary_sent");
    expect(pubBody.pdfPath).toBe(`/v1/cases/${caseId}/parent-summary.pdf`);

    // 10. Portal HTML for the parent.
    const portal = await request.get(
      `${apiUrl}/v1/cases/${caseId}/parent-summary`,
    );
    expect(portal.status()).toBe(200);
    expect(portal.headers()["content-type"]).toContain("text/html");
    const portalHtml = await portal.text();
    expect(portalHtml).toContain("Aria");

    // 11. PDF download — valid %PDF magic bytes + non-trivial size.
    const pdf = await request.get(
      `${apiUrl}/v1/cases/${caseId}/parent-summary.pdf`,
    );
    expect(pdf.status()).toBe(200);
    expect(pdf.headers()["content-type"]).toContain("application/pdf");
    const pdfBuf = await pdf.body();
    expect(pdfBuf.subarray(0, 4).toString()).toBe("%PDF");
    expect(pdfBuf.byteLength).toBeGreaterThan(1500);
  });
});
