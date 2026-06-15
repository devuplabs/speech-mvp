import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import {
  JurisdictionError,
  toBundle,
  validateBundle,
  type CaseAggregate,
} from "../fhir/index.js";
import { GOLDEN_NOW, goldenCase } from "../fhir/__fixtures__/golden-case.js";

/**
 * FHIR R4 / UK Core export unit + golden-fixture conformance tests (DEV-27).
 *
 * Two-tier conformance gate:
 *  - This fast in-process `validateBundle` runs under plain `npm test` (no DB,
 *    no JRE) as a cheap pre-check / regression net for the default CI `api` job.
 *  - The **authoritative** gate is the official HL7 FHIR validator run against
 *    the pinned UK Core R4 IG in the `fhir-conformance` CI job, validating the
 *    committed golden Bundle (`fhir/__fixtures__/golden-bundle.json`). See
 *    `validate.ts` for the split.
 *
 * The golden case lives in `fhir/__fixtures__/golden-case.ts` so the unit tests
 * and the committed golden Bundle are generated from the *same* deterministic
 * input.
 */

const NOW = GOLDEN_NOW;

/** A fully-populated UK case — every mappable resource is present. */
const fullyPopulatedCase = (): CaseAggregate => goldenCase();

describe("toBundle — fully populated case", () => {
  it("emits a valid UK Core collection Bundle (errors=0)", () => {
    const bundle = toBundle(fullyPopulatedCase(), NOW);
    const result = validateBundle(bundle);
    expect(result.errors, JSON.stringify(result.errors, null, 2)).toEqual([]);
    // Tolerated warnings are documented; none are expected for the golden case.
    expect(result.warnings).toEqual([]);
  });

  it("committed golden Bundle is up to date with toBundle (no drift)", () => {
    // The official HL7 validator (fhir-conformance CI job) validates the
    // committed golden-bundle.json. It MUST equal the current mapper output,
    // otherwise CI would validate a stale artifact. Regenerate with:
    //   npx tsx scripts/gen-golden-bundle.mts
    const goldenPath = fileURLToPath(
      new URL("../fhir/__fixtures__/golden-bundle.json", import.meta.url),
    );
    const committed = JSON.parse(readFileSync(goldenPath, "utf8"));
    const fresh = toBundle(goldenCase(), GOLDEN_NOW);
    expect(
      committed,
      "golden-bundle.json is stale — run `npx tsx scripts/gen-golden-bundle.mts` and commit",
    ).toEqual(fresh);
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
