import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { getDb, closeDb, type Db } from "../db/client.js";
import { runMigrations } from "../db/migrate.js";
import {
  aiDrafts,
  carryoverResources,
  cases,
  intakeSubmissions,
  progressEntries,
  tenants,
  triageRecords,
} from "../db/schema.js";
import { buildFhirExport } from "../services/fhir-export.js";
import { validateBundle } from "../fhir/index.js";

/**
 * DB-backed integration test for the FHIR export (DEV-27). Requires Postgres
 * (the local dev DB or the CI e2e Postgres service); skipped when DATABASE_URL
 * is unset so the unit-only `npm test` stays green without a database. The CI
 * e2e-smoke job provides Postgres and runs this. It proves the loader reads the
 * new P0 demographic columns from a real row and the emitted Bundle validates.
 */

const DATABASE_URL = process.env.DATABASE_URL;

describe.skipIf(!DATABASE_URL)("buildFhirExport (DEV-27, DB-backed)", () => {
  let db: Db;
  let tenantId: string;

  beforeAll(async () => {
    await runMigrations(DATABASE_URL!);
    db = getDb(DATABASE_URL!);
    const [t] = await db
      .insert(tenants)
      .values({ displayName: `dev27-fhir-${Date.now()}`, jurisdiction: "uk" })
      .returning();
    tenantId = t.id;
  }, 30_000);

  afterAll(async () => {
    await closeDb();
  });

  it("emits a valid UK Core Bundle for a fully-populated case", async () => {
    const [caseRow] = await db
      .insert(cases)
      .values({
        tenantId,
        status: "carryover",
        parentEmail: "parent@example.com",
        parentPhone: "+447700900111",
        childDisplayName: "Ada Lovelace",
        childGivenName: "Ada",
        childFamilyName: "Lovelace",
        childDob: "2019-12-10",
        parentGivenName: "Mary",
        parentFamilyName: "Lovelace",
        parentRelationship: "mother",
        referralSource: "gp",
      })
      .returning();

    await db.insert(intakeSubmissions).values({
      caseId: caseRow.id,
      answers: { mainConcern: "Speech sounds", version: 1 },
      consentVersion: "mvp-v1",
      locked: true,
      submittedAt: new Date(),
    });
    await db
      .insert(triageRecords)
      .values({ caseId: caseRow.id, outcome: "strategy_only", reason: "Mild." });
    await db.insert(aiDrafts).values({
      caseId: caseRow.id,
      kind: "session_plan",
      content: { plan: "x" },
      reviewedAt: new Date(),
    });
    // Unreviewed -> must NOT appear in the Bundle.
    await db.insert(aiDrafts).values({
      caseId: caseRow.id,
      kind: "clinical_report",
      content: {},
      reviewedAt: null,
    });
    await db.insert(carryoverResources).values({
      caseId: caseRow.id,
      title: "Daily practice",
      category: "home_practice",
    });
    await db.insert(progressEntries).values({
      caseId: caseRow.id,
      author: "parent",
      note: "We tried it.",
      rating: "going_well",
    });

    const result = await buildFhirExport(db, caseRow.id);
    expect(result.ok).toBe(true);
    if (!result.ok) return;

    const validation = validateBundle(result.bundle);
    expect(validation.errors, JSON.stringify(validation.errors, null, 2)).toEqual([]);

    const patient = result.bundle.entry.find(
      (e) => e.resource.resourceType === "Patient",
    )?.resource as { birthDate?: string; name?: { family?: string }[] };
    expect(patient.birthDate).toBe("2019-12-10");
    expect(patient.name?.[0].family).toBe("Lovelace");

    // The unreviewed clinical_report did not leak in.
    const compositions = result.bundle.entry.filter(
      (e) => e.resource.resourceType === "Composition",
    );
    expect(compositions).toHaveLength(0);
  });

  it("returns not_found for an unknown case", async () => {
    const result = await buildFhirExport(
      db,
      "00000000-0000-0000-0000-000000000000",
    );
    expect(result).toEqual({ ok: false, error: "not_found" });
  });

  it("refuses export for a non-UK tenant (jurisdiction guard)", async () => {
    const [usTenant] = await db
      .insert(tenants)
      .values({ displayName: `dev27-us-${Date.now()}`, jurisdiction: "us" })
      .returning();
    const [usCase] = await db
      .insert(cases)
      .values({ tenantId: usTenant.id, childDisplayName: "Child" })
      .returning();

    const result = await buildFhirExport(db, usCase.id);
    expect(result.ok).toBe(false);
    if (result.ok) return;
    expect(result.error).toBe("unsupported_jurisdiction");
  });
});
