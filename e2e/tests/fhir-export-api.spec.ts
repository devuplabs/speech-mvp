import { test, expect } from "@playwright/test";
import { e2eChildName, validIntakeAnswers } from "../fixtures/valid-intake.js";

// FHIR R4 / UK Core export endpoint — DEV-27 (ADR-006).
// Hermetic: bootstraps the e2e demo practice, builds a fully-populated case
// (intake submit -> triage -> parent summary -> carryover -> progress), then
// fetches GET /v1/cases/:caseId/fhir and asserts the Bundle is a valid R4
// collection, that the P0 demographics flow through from intake, and that the
// export is audited (fhir.exported visible in the case audit trail).

const apiUrl = process.env.SONA_API_URL ?? "http://127.0.0.1:8081";

type Json = Record<string, unknown>;
type BundleEntry = { fullUrl: string; resource: { resourceType: string; [k: string]: unknown } };

test.describe("FHIR export API (DEV-27)", () => {
  test("returns a valid R4 Bundle for a populated case and audits the export", async ({
    request,
  }) => {
    const childName = e2eChildName();
    const answers = validIntakeAnswers(childName);

    const boot = await request.post(`${apiUrl}/v1/demo/bootstrap`, {
      data: { practice: "e2e" },
    });
    expect([200, 201]).toContain(boot.status());
    const { tenantId } = (await boot.json()) as { tenantId: string };

    const caseRes = await request.post(`${apiUrl}/v1/cases`, {
      data: { tenantId, parentEmail: answers.email, childDisplayName: childName },
    });
    expect(caseRes.status()).toBe(201);
    const { id: caseId } = (await caseRes.json()) as { id: string };

    const submit = await request.post(`${apiUrl}/v1/cases/${caseId}/intake`, {
      data: {
        answers,
        consentVersion: "mvp-v1",
        parentEmail: answers.email,
        childDisplayName: childName,
      },
    });
    expect(submit.status()).toBe(201);

    const triage = await request.post(`${apiUrl}/v1/cases/${caseId}/triage`, {
      data: { outcome: "strategy_only", reason: "Mild" },
    });
    expect(triage.ok()).toBeTruthy();

    const publish = await request.post(
      `${apiUrl}/v1/cases/${caseId}/parent-summary/publish`,
      { data: { htmlBody: "<!DOCTYPE html><html><body><p>FHIR E2E</p></body></html>" } },
    );
    expect(publish.ok()).toBeTruthy();

    const resource = await request.post(
      `${apiUrl}/v1/cases/${caseId}/carryover/resources`,
      { data: { title: "Daily practice", category: "home_practice" } },
    );
    expect(resource.status()).toBe(201);

    const progress = await request.post(
      `${apiUrl}/v1/cases/${caseId}/carryover/progress`,
      { data: { note: "We tried it.", rating: "going_well" } },
    );
    expect(progress.status()).toBe(201);

    // ── The export ────────────────────────────────────────────────────────
    const fhirRes = await request.get(`${apiUrl}/v1/cases/${caseId}/fhir`);
    expect(fhirRes.status()).toBe(200);
    expect(fhirRes.headers()["content-type"]).toContain("application/fhir+json");

    const bundle = (await fhirRes.json()) as {
      resourceType: string;
      type: string;
      entry: BundleEntry[];
    };
    expect(bundle.resourceType).toBe("Bundle");
    expect(bundle.type).toBe("collection");
    expect(bundle.entry.length).toBeGreaterThan(0);

    const types = bundle.entry.map((e) => e.resource.resourceType);
    for (const required of [
      "Organization",
      "Patient",
      "RelatedPerson",
      "EpisodeOfCare",
      "ServiceRequest",
      "QuestionnaireResponse",
      "Consent",
      "Task",
      "Observation",
    ]) {
      expect(types, `missing ${required}`).toContain(required);
    }

    // P0 demographics threaded from the submitted intake answers (DOB present).
    const patient = bundle.entry.find((e) => e.resource.resourceType === "Patient")!
      .resource as { birthDate?: string };
    expect(patient.birthDate).toBe("2019-05-01"); // from answers.dateOfBirth

    // No token/secret value anywhere in the Bundle.
    expect(JSON.stringify(bundle)).not.toMatch(/"token"/i);

    // Every internal reference resolves (no dangling urn:uuid).
    const fullUrls = new Set(bundle.entry.map((e) => e.fullUrl));
    const refs = JSON.stringify(bundle).match(/urn:uuid:[0-9a-fA-F-]+/g) ?? [];
    for (const r of refs) expect(fullUrls.has(r)).toBe(true);

    // ── The export is audited ───────────────────────────────────────────────
    const auditRes = await request.get(`${apiUrl}/v1/cases/${caseId}/audit-log`);
    expect(auditRes.status()).toBe(200);
    const audit = (await auditRes.json()) as {
      entries: { action: string; metadata: Json }[];
    };
    const exported = audit.entries.find((e) => e.action === "fhir.exported");
    expect(exported, "fhir.exported audit event must exist").toBeTruthy();
    expect(typeof exported!.metadata.resourceCount).toBe("number");
  });

  test("returns 404 for an unknown case", async ({ request }) => {
    const res = await request.get(
      `${apiUrl}/v1/cases/00000000-0000-0000-0000-000000000000/fhir`,
    );
    expect(res.status()).toBe(404);
  });
});
