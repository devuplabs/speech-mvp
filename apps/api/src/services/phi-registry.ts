import { eq } from "drizzle-orm";
import type { PgTable } from "drizzle-orm/pg-core";
import type { Db } from "../db/client.js";
import {
  aiDrafts,
  auditLog,
  carryoverResources,
  caseIntakeLinks,
  casePortalLinks,
  cases,
  clinicianAvailability,
  feedback,
  intakeSubmissions,
  progressEntries,
  tenants,
  triageRecords,
  users,
} from "../db/schema.js";

/**
 * PHI table registry — the single source of truth for DSAR (UK GDPR Art. 15)
 * export and right-to-erasure (Art. 17).
 *
 * Every table in `schema.ts` is classified here. Both the DSAR export and the
 * erasure routine consume this registry, and a completeness test
 * (`phi-registry.test.ts`) asserts that EVERY table exported from `schema.ts`
 * appears below — so adding a new PHI-bearing table without classifying it
 * fails CI until it is registered. That is the key design guarantee: a future
 * schema change cannot silently leak (or fail to erase) subject data.
 *
 * Scope of a "case DSAR": the data subject is the family for one case. Per the
 * FHIR ADR (006) and the issue, practice-level tables (`tenants`, `users`,
 * `clinicianAvailability`) are NOT the data subject's data and are excluded from
 * a per-case DSAR; the access-credential tables (`caseIntakeLinks`,
 * `casePortalLinks`) hold PHI-adjacent access state but their secret `token`
 * VALUES are never exported — links are represented by existence/expiry/
 * revocation only. The `auditLog` is exported (entries naming the subject) but
 * is RETAINED on erasure as an anonymised accountability record (see below).
 */

/** How a registered table participates in DSAR export and erasure. */
export type PhiClassification =
  /** Case-scoped subject data: exported in full and hard-deleted on erasure. */
  | "case_phi"
  /**
   * Access-credential table for the case: exported WITHOUT the secret token
   * value (existence/expiry/revocation only) and hard-deleted on erasure.
   */
  | "case_access_credential"
  /**
   * Audit trail for the case: exported (the subject is entitled to see who did
   * what), but RETAINED on erasure with PHI scrubbed from metadata, leaving an
   * anonymised tombstone. GDPR-vs-accountability position documented in the
   * runbook.
   */
  | "case_audit"
  /**
   * Practice/operational table — NOT the per-case data subject's data. Excluded
   * from a per-case DSAR and never touched by case erasure. Listed so the
   * completeness test forces an explicit decision for every schema table.
   */
  | "practice_excluded";

/**
 * Columns whose VALUES must never appear in a DSAR export (secret credentials).
 * The export represents the row by existence/expiry/revocation instead.
 */
export type RedactedColumn = string;

export interface PhiRegistryEntry {
  /** Stable export section key (also the schema table identifier). */
  readonly key: string;
  /** Postgres table name (for documentation / cross-checks). */
  readonly tableName: string;
  readonly classification: PhiClassification;
  /** The Drizzle table object — used by erasure to issue the delete. */
  readonly table: PgTable;
  /**
   * Load all rows for a case. `undefined` for practice-excluded tables (never
   * loaded for a per-case DSAR). For `case_access_credential` the loader returns
   * already-redacted projections (no token values).
   */
  readonly loadForCase?: (db: Db, caseId: string) => Promise<unknown[]>;
  /** Column names redacted from export output (token secrets). */
  readonly redactedColumns?: readonly RedactedColumn[];
}

/**
 * The registry. Keep this in sync with `schema.ts` — the completeness test
 * enforces it. When you add a PHI-bearing table, add an entry here and decide
 * its classification; that is what wires it into export + erasure.
 */
export const PHI_REGISTRY: readonly PhiRegistryEntry[] = [
  // ── Practice-level (excluded from a per-case DSAR) ──────────────────────
  {
    key: "tenants",
    tableName: "tenants",
    classification: "practice_excluded",
    table: tenants,
  },
  {
    key: "users",
    tableName: "users",
    classification: "practice_excluded",
    table: users,
  },
  {
    key: "clinicianAvailability",
    tableName: "clinician_availability",
    classification: "practice_excluded",
    table: clinicianAvailability,
  },
  {
    // Tester feedback (DEV-55) — operational data, not a family's case data, and
    // PHI-free by design (no caseId; route/role/stage + free-text comment only).
    // Excluded from a per-case DSAR and untouched by case erasure.
    key: "feedback",
    tableName: "feedback",
    classification: "practice_excluded",
    table: feedback,
  },

  // ── Case-scoped subject data (exported in full; erased) ─────────────────
  {
    key: "case",
    tableName: "cases",
    classification: "case_phi",
    table: cases,
    loadForCase: (db, caseId) =>
      db.select().from(cases).where(eq(cases.id, caseId)),
  },
  {
    key: "intakeSubmissions",
    tableName: "intake_submissions",
    classification: "case_phi",
    table: intakeSubmissions,
    loadForCase: (db, caseId) =>
      db.select().from(intakeSubmissions).where(eq(intakeSubmissions.caseId, caseId)),
  },
  {
    key: "triageRecords",
    tableName: "triage_records",
    classification: "case_phi",
    table: triageRecords,
    loadForCase: (db, caseId) =>
      db.select().from(triageRecords).where(eq(triageRecords.caseId, caseId)),
  },
  {
    key: "aiDrafts",
    tableName: "ai_drafts",
    classification: "case_phi",
    table: aiDrafts,
    loadForCase: (db, caseId) =>
      db.select().from(aiDrafts).where(eq(aiDrafts.caseId, caseId)),
  },
  {
    key: "carryoverResources",
    tableName: "carryover_resources",
    classification: "case_phi",
    table: carryoverResources,
    loadForCase: (db, caseId) =>
      db.select().from(carryoverResources).where(eq(carryoverResources.caseId, caseId)),
  },
  {
    key: "progressEntries",
    tableName: "progress_entries",
    classification: "case_phi",
    table: progressEntries,
    loadForCase: (db, caseId) =>
      db.select().from(progressEntries).where(eq(progressEntries.caseId, caseId)),
  },

  // ── Access-credential tables (exported redacted; erased) ────────────────
  {
    key: "caseIntakeLinks",
    tableName: "case_intake_links",
    classification: "case_access_credential",
    table: caseIntakeLinks,
    redactedColumns: ["token"],
    loadForCase: async (db, caseId) => {
      const rows = await db
        .select()
        .from(caseIntakeLinks)
        .where(eq(caseIntakeLinks.caseId, caseId));
      return rows.map((r) => ({
        id: r.id,
        caseId: r.caseId,
        // token VALUE deliberately omitted — represented by existence + state.
        tokenPresent: Boolean(r.token),
        expiresAt: r.expiresAt,
        usedAt: r.usedAt,
        templateId: r.templateId,
        createdAt: r.createdAt,
      }));
    },
  },
  {
    key: "casePortalLinks",
    tableName: "case_portal_links",
    classification: "case_access_credential",
    table: casePortalLinks,
    redactedColumns: ["token"],
    loadForCase: async (db, caseId) => {
      const rows = await db
        .select()
        .from(casePortalLinks)
        .where(eq(casePortalLinks.caseId, caseId));
      return rows.map((r) => ({
        id: r.id,
        caseId: r.caseId,
        // token VALUE deliberately omitted — represented by existence + state.
        tokenPresent: Boolean(r.token),
        expiresAt: r.expiresAt,
        revokedAt: r.revokedAt,
        createdAt: r.createdAt,
      }));
    },
  },

  // ── Audit trail (exported; RETAINED + scrubbed on erasure) ──────────────
  {
    key: "auditLog",
    tableName: "audit_log",
    classification: "case_audit",
    table: auditLog,
    loadForCase: (db, caseId) =>
      db.select().from(auditLog).where(eq(auditLog.caseId, caseId)),
  },
];
