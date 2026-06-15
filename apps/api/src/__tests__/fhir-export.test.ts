import { describe, expect, it } from "vitest";
import {
  JurisdictionError,
  toBundle,
  validateBundle,
  type CaseAggregate,
} from "../fhir/index.js";

/**
 * FHIR R4 / UK Core export unit + golden-fixture conformance tests (DEV-27).
 *
 * These run under the plain `npm test` (no DB) so the conformance gate is in the
 * default CI `api` job. The validator (`validateBundle`) is the regression net:
 * the "errors=0" assertion FAILS the moment the export stops conforming
 * structurally to base R4 / the pinned UK Core profiles (see validate.ts for the
 * structural-vs-full-profile trade-off).
 */

const NOW = new Date("2026-06-15T10:00:00.000Z");

/** A fully-populated UK case — every mappable resource is present. */
function fullyPopulatedCase(): CaseAggregate {
  return {
    tenant: {
      id: "11111111-1111-1111-1111-111111111111",
      displayName: "Bright Voices SLT",
      location: "Manchester, UK",
      jurisdiction: "uk",
    },
    case: {
      id: "22222222-2222-2222-2222-222222222222",
      tenantId: "11111111-1111-1111-1111-111111111111",
      status: "carryover",
      parentEmail: "parent@example.com",
      parentPhone: "+447700900000",
      childDisplayName: "Ada Lovelace",
      childGivenName: "Ada",
      childFamilyName: "Lovelace",
      childDob: "2019-12-10",
      parentGivenName: "Mary",
      parentFamilyName: "Lovelace",
      parentRelationship: "mother",
      referralSource: "gp",
      // Past consult -> Encounter.
      consultAt: new Date("2026-05-01T09:00:00.000Z"),
      createdAt: new Date("2026-04-01T09:00:00.000Z"),
      updatedAt: new Date("2026-06-01T09:00:00.000Z"),
    },
    intake: {
      id: "33333333-3333-3333-3333-333333333333",
      answers: { mainConcern: "Speech sounds", photoConsent: "yes", version: 1 },
      consentVersion: "mvp-v1",
      locked: true,
      submittedAt: new Date("2026-04-05T09:00:00.000Z"),
    },
    triage: [
      {
        id: "44444444-4444-4444-4444-444444444444",
        outcome: "strategy_only",
        reason: "Mild; strategies sufficient.",
        recordedAt: new Date("2026-04-10T09:00:00.000Z"),
      },
    ],
    drafts: [
      {
        id: "55555555-5555-5555-5555-555555555555",
        kind: "prep_brief",
        content: { brief: "working notes" },
        reviewedAt: new Date("2026-04-09T09:00:00.000Z"),
        createdAt: new Date("2026-04-08T09:00:00.000Z"),
      },
      {
        id: "66666666-6666-6666-6666-666666666666",
        kind: "session_plan",
        content: { plan: "x" },
        reviewedAt: new Date("2026-04-11T09:00:00.000Z"),
        createdAt: new Date("2026-04-10T09:00:00.000Z"),
      },
      {
        id: "77777777-7777-7777-7777-777777777777",
        kind: "parent_summary",
        content: { html: "<p>summary</p>" },
        reviewedAt: new Date("2026-04-12T09:00:00.000Z"),
        createdAt: new Date("2026-04-11T09:00:00.000Z"),
      },
      {
        id: "88888888-8888-8888-8888-888888888888",
        kind: "clinical_report",
        content: { sections: [] },
        reviewedAt: new Date("2026-04-13T09:00:00.000Z"),
        createdAt: new Date("2026-04-12T09:00:00.000Z"),
      },
      {
        // Unreviewed -> MUST be excluded.
        id: "99999999-9999-9999-9999-999999999999",
        kind: "clinical_report",
        content: {},
        reviewedAt: null,
        createdAt: new Date("2026-04-14T09:00:00.000Z"),
      },
    ],
    carryover: [
      {
        id: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
        title: "Daily sound practice",
        description: "5 minutes a day",
        url: "https://example.com/r",
        category: "home_practice",
        createdAt: new Date("2026-06-01T09:00:00.000Z"),
      },
    ],
    progress: [
      {
        id: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
        author: "parent",
        note: "We tried it.",
        rating: "going_well",
        createdAt: new Date("2026-06-05T09:00:00.000Z"),
      },
    ],
  };
}

describe("toBundle — fully populated case", () => {
  it("emits a valid UK Core collection Bundle (errors=0)", () => {
    const bundle = toBundle(fullyPopulatedCase(), NOW);
    const result = validateBundle(bundle);
    expect(result.errors, JSON.stringify(result.errors, null, 2)).toEqual([]);
    // Tolerated warnings are documented; none are expected for the golden case.
    expect(result.warnings).toEqual([]);
  });

  it("includes one resource of each mapped type", () => {
    const bundle = toBundle(fullyPopulatedCase(), NOW);
    const types = bundle.entry.map((e) => e.resource.resourceType).sort();
    expect(types).toContain("Organization");
    expect(types).toContain("Patient");
    expect(types).toContain("RelatedPerson");
    expect(types).toContain("EpisodeOfCare");
    expect(types).toContain("ServiceRequest");
    expect(types).toContain("Encounter"); // past consult
    expect(types).toContain("QuestionnaireResponse");
    expect(types).toContain("Consent");
    expect(types).toContain("Task"); // triage
    expect(types).toContain("CarePlan"); // session_plan + carryover
    expect(types).toContain("Communication"); // parent_summary
    expect(types).toContain("DocumentReference"); // parent_summary + report
    expect(types).toContain("Composition"); // clinical_report
    expect(types).toContain("Observation"); // progress
  });

  it("maps the Patient demographics from structured columns, not the display string", () => {
    const bundle = toBundle(fullyPopulatedCase(), NOW);
    const patient = bundle.entry.find((e) => e.resource.resourceType === "Patient")
      ?.resource as { name?: { given?: string[]; family?: string }[]; birthDate?: string };
    expect(patient.name?.[0].given).toEqual(["Ada"]);
    expect(patient.name?.[0].family).toBe("Lovelace");
    expect(patient.birthDate).toBe("2019-12-10");
  });

  it("maps the parent relationship code (mother -> MTH)", () => {
    const bundle = toBundle(fullyPopulatedCase(), NOW);
    const rp = bundle.entry.find((e) => e.resource.resourceType === "RelatedPerson")
      ?.resource as { relationship?: { coding?: { code?: string }[] }[] };
    expect(rp.relationship?.[0].coding?.[0].code).toBe("MTH");
  });
});

describe("ADR-006 exclusion rules", () => {
  it("excludes unreviewed AI drafts and prep_brief working notes", () => {
    const bundle = toBundle(fullyPopulatedCase(), NOW);
    // 4 drafts but only session_plan + parent_summary + clinical_report are
    // emitted (prep_brief excluded; unreviewed report excluded). The report
    // produces a DocumentReference + Composition; the parent_summary a
    // DocumentReference + Communication.
    const docRefs = bundle.entry.filter(
      (e) => e.resource.resourceType === "DocumentReference",
    );
    expect(docRefs).toHaveLength(2); // parent_summary + reviewed clinical_report only
    const compositions = bundle.entry.filter(
      (e) => e.resource.resourceType === "Composition",
    );
    expect(compositions).toHaveLength(1); // only the reviewed report
  });

  it("never emits any token/secret value anywhere in the Bundle", () => {
    const bundle = toBundle(fullyPopulatedCase(), NOW);
    const json = JSON.stringify(bundle);
    expect(json).not.toMatch(/token/i);
  });

  it("uses internal UUIDs only as urn:uuid references, never as business identifiers", () => {
    const bundle = toBundle(fullyPopulatedCase(), NOW);
    for (const entry of bundle.entry) {
      const identifiers = (entry.resource as { identifier?: { value?: string }[] }).identifier;
      if (!identifiers) continue;
      for (const id of identifiers) {
        // No internal uuid leaked as an external business identifier.
        expect(id.value).not.toMatch(
          /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/i,
        );
      }
    }
  });
});

describe("jurisdiction guard (ADR-006 §4)", () => {
  it("refuses to emit UK Core for a non-UK tenant", () => {
    const us = fullyPopulatedCase();
    us.tenant.jurisdiction = "us";
    expect(() => toBundle(us, NOW)).toThrow(JurisdictionError);
  });
});

describe("minimal case (only the required spine)", () => {
  function minimalCase(): CaseAggregate {
    const c = fullyPopulatedCase();
    return {
      tenant: c.tenant,
      case: {
        ...c.case,
        status: "intake_pending",
        childGivenName: null,
        childFamilyName: null,
        childDob: null,
        parentGivenName: null,
        parentFamilyName: null,
        parentRelationship: null,
        consultAt: null,
      },
      intake: null,
      triage: [],
      drafts: [],
      carryover: [],
      progress: [],
    };
  }

  it("still emits a valid Bundle with the required spine and no fabricated data", () => {
    const bundle = toBundle(minimalCase(), NOW);
    const result = validateBundle(bundle);
    expect(result.errors, JSON.stringify(result.errors, null, 2)).toEqual([]);
    const types = bundle.entry.map((e) => e.resource.resourceType);
    // Spine only: Organization, Patient, RelatedPerson, EpisodeOfCare, ServiceRequest.
    expect(types).toEqual([
      "Organization",
      "Patient",
      "RelatedPerson",
      "EpisodeOfCare",
      "ServiceRequest",
    ]);
    // No name/birthDate fabricated; display string used only as name.text.
    const patient = bundle.entry.find((e) => e.resource.resourceType === "Patient")
      ?.resource as { name?: { text?: string; given?: string[] }[]; birthDate?: string };
    expect(patient.birthDate).toBeUndefined();
    expect(patient.name?.[0].given).toBeUndefined();
    expect(patient.name?.[0].text).toBe("Ada Lovelace");
  });
});

describe("validateBundle — fails on malformed output (negative control)", () => {
  it("reports an error when a required element is removed", () => {
    const bundle = toBundle(fullyPopulatedCase(), NOW);
    // Corrupt a resource: drop ServiceRequest.status (required).
    const sr = bundle.entry.find((e) => e.resource.resourceType === "ServiceRequest")!
      .resource as unknown as Record<string, unknown>;
    delete sr.status;
    const result = validateBundle(bundle);
    expect(result.errors.length).toBeGreaterThan(0);
    expect(result.errors.some((e) => /status/.test(e.message))).toBe(true);
  });

  it("reports an error on a dangling internal reference", () => {
    const bundle = toBundle(fullyPopulatedCase(), NOW);
    const rp = bundle.entry.find((e) => e.resource.resourceType === "RelatedPerson")!
      .resource as { patient: { reference: string } };
    rp.patient.reference = "urn:uuid:does-not-exist";
    const result = validateBundle(bundle);
    expect(result.errors.some((e) => /dangling/.test(e.message))).toBe(true);
  });

  it("reports an error on an out-of-value-set status", () => {
    const bundle = toBundle(fullyPopulatedCase(), NOW);
    const obs = bundle.entry.find((e) => e.resource.resourceType === "Observation")!
      .resource as unknown as Record<string, unknown>;
    obs.status = "not-a-real-status";
    const result = validateBundle(bundle);
    expect(result.errors.some((e) => /value set/.test(e.message))).toBe(true);
  });
});
