/**
 * FHIR export service (DEV-27) — loads the case aggregate and projects it to a
 * UK Core Bundle via the pure mappers in `../fhir`. This is the only place that
 * touches the DB for the export; the mapping itself is pure and emit-only.
 *
 * Loads ONLY what the export emits (ADR-006 §3). Deliberately never loads the
 * access-credential tables (`caseIntakeLinks`, `casePortalLinks`) — their tokens
 * are secret and the ADR excludes them with prejudice.
 *
 * PHI policy: never log subject data or Bundle content — IDs/counts only.
 */

import { eq } from "drizzle-orm";
import type { Db } from "../db/client.js";
import {
  aiDrafts,
  carryoverResources,
  cases,
  intakeSubmissions,
  progressEntries,
  tenants,
  triageRecords,
} from "../db/schema.js";
import { JurisdictionError, toBundle, type CaseAggregate } from "../fhir/index.js";
import type { Bundle } from "../fhir/index.js";

export type FhirExportResult =
  | { ok: false; error: "not_found" }
  | { ok: false; error: "unsupported_jurisdiction"; jurisdiction: string }
  | {
      ok: true;
      tenantId: string;
      bundle: Bundle;
      /** Counts only (for the audit metadata) — never PHI. */
      resourceCount: number;
    };

/** Load the case aggregate and emit the UK Core Bundle. */
export async function buildFhirExport(
  db: Db,
  caseId: string,
): Promise<FhirExportResult> {
  const [caseRow] = await db.select().from(cases).where(eq(cases.id, caseId));
  if (!caseRow) return { ok: false, error: "not_found" };

  const [tenantRow] = await db
    .select()
    .from(tenants)
    .where(eq(tenants.id, caseRow.tenantId));
  if (!tenantRow) return { ok: false, error: "not_found" };

  const [intakeRow] = await db
    .select()
    .from(intakeSubmissions)
    .where(eq(intakeSubmissions.caseId, caseId));
  const triageRows = await db
    .select()
    .from(triageRecords)
    .where(eq(triageRecords.caseId, caseId));
  const draftRows = await db.select().from(aiDrafts).where(eq(aiDrafts.caseId, caseId));
  const carryoverRows = await db
    .select()
    .from(carryoverResources)
    .where(eq(carryoverResources.caseId, caseId));
  const progressRows = await db
    .select()
    .from(progressEntries)
    .where(eq(progressEntries.caseId, caseId));

  const aggregate: CaseAggregate = {
    tenant: {
      id: tenantRow.id,
      displayName: tenantRow.displayName,
      location: tenantRow.location ?? null,
      jurisdiction: tenantRow.jurisdiction,
    },
    case: {
      id: caseRow.id,
      tenantId: caseRow.tenantId,
      status: caseRow.status,
      parentEmail: caseRow.parentEmail ?? null,
      parentPhone: caseRow.parentPhone ?? null,
      childDisplayName: caseRow.childDisplayName ?? null,
      childGivenName: caseRow.childGivenName ?? null,
      childFamilyName: caseRow.childFamilyName ?? null,
      childDob: caseRow.childDob ?? null,
      parentGivenName: caseRow.parentGivenName ?? null,
      parentFamilyName: caseRow.parentFamilyName ?? null,
      parentRelationship: caseRow.parentRelationship ?? null,
      referralSource: caseRow.referralSource ?? null,
      consultAt: caseRow.consultAt ?? null,
      createdAt: caseRow.createdAt,
      updatedAt: caseRow.updatedAt,
    },
    intake: intakeRow
      ? {
          id: intakeRow.id,
          answers: (intakeRow.answers ?? {}) as Record<string, unknown>,
          consentVersion: intakeRow.consentVersion ?? null,
          locked: intakeRow.locked,
          submittedAt: intakeRow.submittedAt ?? null,
        }
      : null,
    triage: triageRows.map((t) => ({
      id: t.id,
      outcome: t.outcome,
      reason: t.reason ?? null,
      recordedAt: t.recordedAt,
    })),
    drafts: draftRows.map((d) => ({
      id: d.id,
      kind: d.kind,
      content: (d.content ?? {}) as Record<string, unknown>,
      reviewedAt: d.reviewedAt ?? null,
      createdAt: d.createdAt,
    })),
    carryover: carryoverRows.map((r) => ({
      id: r.id,
      title: r.title,
      description: r.description ?? null,
      url: r.url ?? null,
      category: r.category,
      createdAt: r.createdAt,
    })),
    progress: progressRows.map((p) => ({
      id: p.id,
      author: p.author,
      note: p.note,
      rating: p.rating ?? null,
      createdAt: p.createdAt,
    })),
  };

  try {
    const bundle = toBundle(aggregate);
    return {
      ok: true,
      tenantId: tenantRow.id,
      bundle,
      resourceCount: bundle.entry.length,
    };
  } catch (err) {
    if (err instanceof JurisdictionError) {
      return {
        ok: false,
        error: "unsupported_jurisdiction",
        jurisdiction: err.jurisdiction,
      };
    }
    throw err;
  }
}
