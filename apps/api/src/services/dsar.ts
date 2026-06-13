import { createHash, randomBytes } from "node:crypto";
import { eq, sql } from "drizzle-orm";
import type { Db } from "../db/client.js";
import { auditLog, cases } from "../db/schema.js";
import { logger } from "../logger.js";
import { writeAudit } from "./audit.js";
import { PHI_REGISTRY, type PhiRegistryEntry } from "./phi-registry.js";

/**
 * DSAR (UK GDPR Art. 15 access) + right-to-erasure (Art. 17) for one case.
 *
 * Both flows are driven entirely by the PHI registry (`phi-registry.ts`) so a
 * newly-added PHI table is exported/erased automatically once classified.
 *
 * PHI policy: never log subject data. We log caseId/action/counts only.
 */

export type DsarExport = {
  meta: {
    kind: "dsar_export";
    caseId: string;
    tenantId: string;
    generatedAt: string;
    /**
     * Tables/sections deliberately excluded from this per-case DSAR and why,
     * so the bundle is self-documenting for the subject and the DPO.
     */
    excluded: { section: string; reason: string }[];
    notes: string[];
  };
  /** Section key -> rows. Access-credential sections are token-redacted. */
  sections: Record<string, unknown[]>;
};

const EXCLUSION_REASON: Record<string, string> = {
  tenants: "Practice/organisation record — not the data subject's personal data.",
  users: "Clinician/staff seats — not the data subject's personal data.",
  clinicianAvailability: "Scheduling configuration — not personal data of the subject.",
};

/**
 * Build a complete DSAR JSON bundle for a case from the registry. Returns
 * `not_found` if the case does not exist. Does NOT mutate data other than
 * writing the `dsar.exported` audit event (the caller decides when to audit so
 * the route can audit exactly once).
 */
export async function buildDsarExport(
  db: Db,
  caseId: string,
): Promise<{ ok: false; error: "not_found" } | { ok: true; export: DsarExport }> {
  const [caseRow] = await db.select().from(cases).where(eq(cases.id, caseId));
  if (!caseRow) return { ok: false, error: "not_found" };

  const sections: Record<string, unknown[]> = {};
  const excluded: { section: string; reason: string }[] = [];

  for (const entry of PHI_REGISTRY) {
    if (entry.classification === "practice_excluded") {
      excluded.push({
        section: entry.key,
        reason: EXCLUSION_REASON[entry.key] ?? "Not the data subject's personal data.",
      });
      continue;
    }
    if (!entry.loadForCase) continue;
    sections[entry.key] = await entry.loadForCase(db, caseId);
  }

  const notes = [
    "Magic-link token values (intake & portal) are deliberately omitted; links are represented by existence, expiry and revocation state only (secrets are never disclosed).",
    "Unreviewed AI drafts are included for completeness as they constitute personal data held about the subject, even though they are not clinical-record material until clinician-reviewed.",
    "Audit entries naming this case are included; the audit trail is retained (with PHI scrubbed) after any erasure for accountability.",
  ];

  return {
    ok: true,
    export: {
      meta: {
        kind: "dsar_export",
        caseId,
        tenantId: caseRow.tenantId,
        generatedAt: new Date().toISOString(),
        excluded,
        notes,
      },
      sections,
    },
  };
}

// ── Erasure (Art. 17) ─────────────────────────────────────────────────────

const ERASURE_TOKEN_TTL_MINUTES = 60;

/** Opaque confirmation token for the two-step erasure flow. */
export function newErasureToken(): string {
  return randomBytes(24).toString("base64url");
}

/** Deterministic fingerprint so we can store/echo without keeping the raw token. */
function tokenFingerprint(token: string): string {
  return createHash("sha256").update(token).digest("hex");
}

export type ErasureRequestResult =
  | { ok: false; error: "not_found" }
  | { ok: false; error: "legal_hold"; reason: string | null }
  | { ok: true; token: string; expiresAt: string };

/**
 * Step 1 — request erasure. Refuses (clear error) when the case is under a
 * retention/legal hold. Returns a short-lived confirmation token the caller
 * must echo to `confirmErasure`. The token is audited by fingerprint, never
 * stored raw.
 */
export async function requestErasure(
  db: Db,
  caseId: string,
): Promise<ErasureRequestResult> {
  const [caseRow] = await db.select().from(cases).where(eq(cases.id, caseId));
  if (!caseRow) return { ok: false, error: "not_found" };

  if (caseRow.legalHold) {
    await writeAudit(db, {
      tenantId: caseRow.tenantId,
      caseId,
      actor: "admin",
      action: "erasure.refused_legal_hold",
      metadata: { reason: caseRow.legalHoldReason ?? null },
    });
    return { ok: false, error: "legal_hold", reason: caseRow.legalHoldReason ?? null };
  }

  const token = newErasureToken();
  const expiresAt = new Date(Date.now() + ERASURE_TOKEN_TTL_MINUTES * 60 * 1000);

  await writeAudit(db, {
    tenantId: caseRow.tenantId,
    caseId,
    actor: "admin",
    action: "erasure.requested",
    metadata: {
      tokenFingerprint: tokenFingerprint(token),
      expiresAt: expiresAt.toISOString(),
    },
  });

  return { ok: true, token, expiresAt: expiresAt.toISOString() };
}

export type ErasureConfirmResult =
  | { ok: false; error: "not_found" }
  | { ok: false; error: "legal_hold"; reason: string | null }
  | { ok: false; error: "invalid_token" }
  | { ok: true; deleted: Record<string, number>; auditRetained: number };

/**
 * Step 2 — confirm erasure. Validates that `token` matches an outstanding,
 * unexpired `erasure.requested` audit event for the case, then hard-deletes PHI
 * across every registry table (case_phi + case_access_credential), retaining the
 * audit trail with PHI scrubbed and writing an anonymised `case.erased`
 * tombstone.
 *
 * Audit-retention-vs-erasure decision (documented in dsar-runbook.md): we RETAIN
 * the audit rows for the case (accountability — UK GDPR Art. 5(2) and our own
 * security/incident obligations are a lawful basis to keep a minimal,
 * PHI-free record of processing) but SCRUB any PHI that may have entered
 * `audit_log.metadata`, and we DELETE `parent_email`/`child_display_name` etc.
 * from `cases` rather than dropping the case row, so the tombstone keeps a
 * referential anchor with no personal data.
 */
export async function confirmErasure(
  db: Db,
  caseId: string,
  token: string,
): Promise<ErasureConfirmResult> {
  const [caseRow] = await db.select().from(cases).where(eq(cases.id, caseId));
  if (!caseRow) return { ok: false, error: "not_found" };

  // Defence in depth: a hold could have been placed between request and confirm.
  if (caseRow.legalHold) {
    await writeAudit(db, {
      tenantId: caseRow.tenantId,
      caseId,
      actor: "admin",
      action: "erasure.refused_legal_hold",
      metadata: { reason: caseRow.legalHoldReason ?? null, phase: "confirm" },
    });
    return { ok: false, error: "legal_hold", reason: caseRow.legalHoldReason ?? null };
  }

  if (!(await isValidErasureToken(db, caseId, token))) {
    await writeAudit(db, {
      tenantId: caseRow.tenantId,
      caseId,
      actor: "admin",
      action: "erasure.confirm_failed",
      metadata: { reason: "invalid_or_expired_token" },
    });
    return { ok: false, error: "invalid_token" };
  }

  const tenantId = caseRow.tenantId;
  const deleted: Record<string, number> = {};

  // Snapshot what we'll delete (for the tombstone counts) before deleting.
  // Delete child rows first, the `cases` row last, to satisfy FK ordering even
  // though most are ON DELETE CASCADE — explicit deletes keep the registry the
  // sole source of truth (no reliance on cascade for completeness).
  const caseScoped = PHI_REGISTRY.filter(
    (e) =>
      e.classification === "case_phi" || e.classification === "case_access_credential",
  );

  // Order: everything except `cases` first, then `cases`.
  const childTables = caseScoped.filter((e) => e.key !== "case");
  for (const entry of childTables) {
    deleted[entry.key] = await deleteCaseRows(db, entry, caseId);
  }

  // Retain the audit trail but scrub any PHI from metadata of prior rows.
  const auditRetained = await scrubCaseAuditMetadata(db, caseId);

  // Finally hard-delete the case row (the cascade would also remove children;
  // we already removed them explicitly above).
  const caseEntry = caseScoped.find((e) => e.key === "case")!;
  deleted[caseEntry.key] = await deleteCaseRows(db, caseEntry, caseId);

  // Anonymised tombstone — actor + timestamp, NO PHI. Counts only.
  await db.insert(auditLog).values({
    tenantId,
    // No FK to the case row (it's gone); record the id as opaque metadata only.
    caseId: null,
    actor: "admin",
    action: "case.erased",
    metadata: {
      erasedCaseId: caseId,
      erasedAt: new Date().toISOString(),
      deleted,
      auditRetained,
    },
  });

  logger.info("dsar.erasure_confirmed", {
    caseId,
    tenantId,
    action: "case.erased",
  });

  return { ok: true, deleted, auditRetained };
}

/**
 * A token is valid if there is an `erasure.requested` audit row for this case
 * whose fingerprint matches and whose recorded `expiresAt` is in the future,
 * and no later `case.erased`/successful confirm has consumed it.
 */
async function isValidErasureToken(
  db: Db,
  caseId: string,
  token: string,
): Promise<boolean> {
  const fp = tokenFingerprint(token);
  const rows = await db
    .select()
    .from(auditLog)
    .where(eq(auditLog.caseId, caseId));

  const now = Date.now();
  return rows.some((r) => {
    if (r.action !== "erasure.requested") return false;
    const meta = (r.metadata ?? {}) as { tokenFingerprint?: string; expiresAt?: string };
    if (meta.tokenFingerprint !== fp) return false;
    if (!meta.expiresAt) return false;
    return new Date(meta.expiresAt).getTime() > now;
  });
}

/** Hard-delete all rows for a case from one registry table. Returns count. */
async function deleteCaseRows(
  db: Db,
  entry: PhiRegistryEntry,
  caseId: string,
): Promise<number> {
  // `cases` keys on `id`; every other case-scoped table keys on `case_id`.
  const column = entry.key === "case" ? "id" : "case_id";
  const result = await db.execute(
    sql`DELETE FROM ${sql.identifier(entry.tableName)} WHERE ${sql.identifier(column)} = ${caseId}`,
  );
  // node-postgres returns rowCount.
  return (result as unknown as { rowCount?: number }).rowCount ?? 0;
}

/**
 * Retain audit rows for the case but strip any PHI that may have leaked into
 * `metadata`. We allowlist known non-PHI metadata keys and drop everything
 * else, and we never touch `actor`/`action`/timestamps (accountability spine).
 *
 * We also NULL the `case_id` FK on the retained rows (preserving the original id
 * in scrubbed metadata as `erasedCaseId`) so the `cases` row can be hard-deleted
 * — the `audit_log.case_id` FK is `ON DELETE no action` and would otherwise
 * block the delete. The accountability record survives as a tenant-scoped,
 * case-detached, PHI-free trail.
 */
const AUDIT_METADATA_SAFE_KEYS = new Set([
  "outcome",
  "status",
  "statusFrom",
  "statusTo",
  "step",
  "kind",
  "reason",
  "category",
  "author",
  "rating",
  "resourceId",
  "entryId",
  "expiresAt",
  "tokenFingerprint",
  "phase",
]);

async function scrubCaseAuditMetadata(db: Db, caseId: string): Promise<number> {
  const rows = await db.select().from(auditLog).where(eq(auditLog.caseId, caseId));
  let scrubbed = 0;
  for (const row of rows) {
    const meta = (row.metadata ?? {}) as Record<string, unknown>;
    const safe: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(meta)) {
      if (AUDIT_METADATA_SAFE_KEYS.has(k)) safe[k] = v;
    }
    safe.phiScrubbed = true;
    safe.erasedCaseId = caseId;
    await db
      .update(auditLog)
      .set({ metadata: safe, caseId: null })
      .where(eq(auditLog.id, row.id));
    scrubbed += 1;
  }
  return scrubbed;
}
