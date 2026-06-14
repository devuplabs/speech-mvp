import { lt, sql } from "drizzle-orm";
import type { Db } from "../db/client.js";
import { auditLog } from "../db/schema.js";
import { logger } from "../logger.js";

/**
 * Audit-log retention (DEV-25).
 *
 * Policy: audit rows are retained for **7 years** then deleted (or archived to
 * cold storage first — see docs/compliance/audit-retention.md). Seven years is
 * the conservative retention chosen for the accountability trail in
 * docs/compliance/audit-retention.md; clinical *records* themselves follow the
 * longer HCPC schedule via the legal-hold mechanism (DEV-24), which is a
 * separate concern from this PHI-free accountability trail.
 *
 * Mechanism: `audit_log` is append-only (DEV-25 trigger blocks DELETE) unless a
 * transaction opts in via `SET LOCAL sona.audit_retention = 'on'`. This routine
 * is the sanctioned deletion path and sets that flag. It is intended to be
 * invoked from a scheduled maintenance task (Cloud Scheduler → a guarded admin
 * endpoint or a worker job); for v1 it is a tested mechanism driven by the
 * runbook rather than auto-scheduled — see the doc for what is automated vs
 * runbooked.
 */

export const AUDIT_RETENTION_YEARS = 7;

/** The cutoff instant: rows with `created_at` strictly older than this expire. */
export function auditRetentionCutoff(now: Date = new Date()): Date {
  const cutoff = new Date(now);
  cutoff.setUTCFullYear(cutoff.getUTCFullYear() - AUDIT_RETENTION_YEARS);
  return cutoff;
}

/**
 * Delete audit rows older than the 7-year window. Returns the number deleted.
 *
 * `dryRun` (default) counts what *would* be deleted without removing anything —
 * the safe default so a scheduled call must opt in to destructive deletion.
 * Runs inside a transaction that flips `sona.audit_retention` so the append-only
 * trigger permits the delete; the flag is `LOCAL` and cannot leak to other
 * requests on a pooled connection.
 */
export async function purgeExpiredAuditRows(
  db: Db,
  opts: { now?: Date; dryRun?: boolean } = {},
): Promise<{ cutoff: string; deleted: number; dryRun: boolean }> {
  const now = opts.now ?? new Date();
  const dryRun = opts.dryRun ?? true;
  const cutoff = auditRetentionCutoff(now);

  if (dryRun) {
    const [{ count }] = await db
      .select({ count: sql<number>`count(*)::int` })
      .from(auditLog)
      .where(lt(auditLog.createdAt, cutoff));
    logger.info("audit_retention.dry_run", { reason: "would_delete", count });
    return { cutoff: cutoff.toISOString(), deleted: count, dryRun: true };
  }

  let deleted = 0;
  await db.transaction(async (tx) => {
    await tx.execute(sql`SET LOCAL sona.audit_retention = 'on'`);
    const result = await tx
      .delete(auditLog)
      .where(lt(auditLog.createdAt, cutoff));
    deleted = (result as unknown as { rowCount?: number }).rowCount ?? 0;
  });
  logger.info("audit_retention.purged", { reason: "expired", count: deleted });
  return { cutoff: cutoff.toISOString(), deleted, dryRun: false };
}
