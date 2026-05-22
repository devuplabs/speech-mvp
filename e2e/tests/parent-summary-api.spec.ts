import { test, expect } from "@playwright/test";
import { intakePersonas } from "../fixtures/intake-personas.js";

/**
 * API spec for the parent-summary preview + publish + PDF endpoints.
 *
 * Covers:
 *   - Preview returns html + structured projection that mirrors options.
 *   - Tone slider flips section headings (Warm "What we talked about" vs
 *     Clinical "Summary of consultation").
 *   - Section toggles drop entire sections from the projection.
 *   - AI-disclosure toggle adds/removes the footer string.
 *   - Publish persists the chosen options.
 *   - PDF download returns a valid application/pdf payload.
 */

const apiUrl =
  process.env.SONA_API_URL ?? "https://sona-api-dev-3rhenudy6a-nw.a.run.app";

const aria = intakePersonas.find((p) => p.id === "aria_speech_sounds_4yo")!;

const defaultOptions = {
  tone: "balanced",
  readingLevel: "standard",
  sections: {
    whatWeDiscussed: true,
    planForFirstSession: true,
    homePractice: true,
    nextSteps: true,
  },
  aiDisclosure: true,
};

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
  const childName = `${aria.childDisplayName} · summary-spec ${suffix}`;
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
  await request.post(`${apiUrl}/v1/cases/${caseId}/triage`, {
    data: { outcome: "short_block", reason: "spec" },
  });
  return caseId;
}

test.describe("Parent summary preview + publish + PDF", () => {
  test("preview returns html + structured projection", async ({ request }) => {
    const tenantId = await bootstrap(request);
    const caseId = await newTriagedCase(request, tenantId, "preview");

    const res = await request.post(
      `${apiUrl}/v1/cases/${caseId}/parent-summary/preview`,
      { data: { options: defaultOptions } },
    );
    expect(res.status()).toBe(200);
    const body = (await res.json()) as {
      html: string;
      projection: {
        title: string;
        sections: Array<{ heading: string; bullets: string[] }>;
        disclosure: string | null;
      };
    };
    expect(body.html).toContain("<html");
    expect(body.projection.title).toContain("Aria");
    expect(body.projection.sections.length).toBe(4);
    expect(body.projection.disclosure).toContain("AI-drafted");
  });

  test("tone flips section headings + greeting", async ({ request }) => {
    const tenantId = await bootstrap(request);
    const caseId = await newTriagedCase(request, tenantId, "tone");

    const warm = await request.post(
      `${apiUrl}/v1/cases/${caseId}/parent-summary/preview`,
      { data: { options: { ...defaultOptions, tone: "warm" } } },
    );
    const clinical = await request.post(
      `${apiUrl}/v1/cases/${caseId}/parent-summary/preview`,
      { data: { options: { ...defaultOptions, tone: "clinical" } } },
    );

    const warmBody = (await warm.json()) as {
      projection: { sections: Array<{ heading: string }> };
    };
    const clinicalBody = (await clinical.json()) as {
      projection: { sections: Array<{ heading: string }> };
    };
    const warmHeadings = warmBody.projection.sections.map((s) => s.heading);
    const clinicalHeadings = clinicalBody.projection.sections.map((s) => s.heading);
    expect(warmHeadings).toContain("What we talked about");
    expect(clinicalHeadings).toContain("Summary of consultation");
  });

  test("section toggles drop sections from the projection", async ({
    request,
  }) => {
    const tenantId = await bootstrap(request);
    const caseId = await newTriagedCase(request, tenantId, "toggles");

    const res = await request.post(
      `${apiUrl}/v1/cases/${caseId}/parent-summary/preview`,
      {
        data: {
          options: {
            ...defaultOptions,
            sections: {
              whatWeDiscussed: false,
              planForFirstSession: true,
              homePractice: false,
              nextSteps: true,
            },
          },
        },
      },
    );
    const body = (await res.json()) as {
      projection: { sections: Array<{ heading: string }> };
    };
    expect(body.projection.sections.length).toBe(2);
    const headings = body.projection.sections.map((s) => s.heading);
    expect(headings).not.toContain("What we talked about");
    expect(headings).not.toContain("How you can help at home");
  });

  test("AI-disclosure toggle removes the disclosure", async ({ request }) => {
    const tenantId = await bootstrap(request);
    const caseId = await newTriagedCase(request, tenantId, "disclosure");

    const res = await request.post(
      `${apiUrl}/v1/cases/${caseId}/parent-summary/preview`,
      { data: { options: { ...defaultOptions, aiDisclosure: false } } },
    );
    const body = (await res.json()) as {
      projection: { disclosure: string | null };
      html: string;
    };
    expect(body.projection.disclosure).toBeNull();
    expect(body.html).not.toContain("AI-drafted · clinician-reviewed");
  });

  test("publish persists options + advances case to summary_sent", async ({
    request,
  }) => {
    const tenantId = await bootstrap(request);
    const caseId = await newTriagedCase(request, tenantId, "publish");

    const pub = await request.post(
      `${apiUrl}/v1/cases/${caseId}/parent-summary/publish`,
      { data: { options: { ...defaultOptions, tone: "clinical" } } },
    );
    expect(pub.status()).toBe(200);
    const body = (await pub.json()) as {
      case: { status: string };
      viewPath: string;
      pdfPath: string;
    };
    expect(body.case.status).toBe("summary_sent");
    expect(body.viewPath).toBe(`/v1/cases/${caseId}/parent-summary`);
    expect(body.pdfPath).toBe(`/v1/cases/${caseId}/parent-summary.pdf`);
  });

  test("PDF endpoint returns valid application/pdf", async ({ request }) => {
    const tenantId = await bootstrap(request);
    const caseId = await newTriagedCase(request, tenantId, "pdf");

    // Publish first so options are stored.
    await request.post(
      `${apiUrl}/v1/cases/${caseId}/parent-summary/publish`,
      { data: { options: defaultOptions } },
    );

    const res = await request.get(
      `${apiUrl}/v1/cases/${caseId}/parent-summary.pdf`,
    );
    expect(res.status()).toBe(200);
    expect(res.headers()["content-type"]).toContain("application/pdf");
    const buf = await res.body();
    // PDF magic number: "%PDF".
    expect(buf.subarray(0, 4).toString()).toBe("%PDF");
    expect(buf.byteLength).toBeGreaterThan(1000);
  });
});
