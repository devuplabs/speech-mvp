import { and, desc, eq, gt } from "drizzle-orm";
import type { Db } from "../db/client.js";
import { auditLog } from "../db/schema.js";

export async function writeAudit(
  db: Db,
  input: {
    tenantId?: string;
    caseId?: string;
    actor: string;
    action: string;
    metadata?: Record<string, unknown>;
  },
): Promise<void> {
  await db.insert(auditLog).values({
    tenantId: input.tenantId,
    caseId: input.caseId,
    actor: input.actor,
    action: input.action,
    metadata: input.metadata ?? {},
  });
}

/**
 * De-dupe window for read-access (`*.viewed`) events (DEV-25).
 *
 * Read-access auditing (GDPR/HCPC: "who accessed which record, when") is
 * inherently noisy — opening a case detail can issue several reads, and a
 * clinician may refresh a record repeatedly while working. Recording one row
 * per HTTP GET would bury the signal and bloat the trail.
 *
 * Choice: collapse repeated identical accesses to **one event per
 * (actor, caseId, action) per 5-minute window**. This preserves the
 * compliance signal — we can still answer "did actor X access record Y around
 * time T" — while keeping volume sane. It is intentionally coarse (per-window,
 * not per-request): a continuous viewing session yields a heartbeat of one row
 * every 5 minutes rather than one per click. Mutations are NEVER de-duped; only
 * `*.viewed` access events use this guard.
 */
export const VIEW_AUDIT_DEDUPE_WINDOW_MS = 5 * 60 * 1000;

/**
 * Record a read-access (`*.viewed`) event, de-duped per the window above. If an
 * identical (actor, caseId, action) event already exists within the window, this
 * is a no-op. Returns whether a new row was written (useful for tests/metrics).
 *
 * De-dupe is **best-effort**: it is a non-transactional read-then-write, so two
 * truly concurrent identical views can both pass the check and write two rows.
 * That is acceptable here — the goal is to suppress the common serial
 * refresh/re-open noise, not to guarantee exactly one row (over-recording an
 * access is harmless for an audit trail; under-recording would not be). We
 * deliberately avoid a unique index / advisory lock for a heartbeat event.
 *
 * Metadata: IDs/counts only — never PHI (same rule as `writeAudit`).
 */
export async function writeViewAudit(
  db: Db,
  input: {
    tenantId?: string;
    /**
     * Case being viewed. De-dupe is keyed on this when present. Omit for
     * tenant-scoped list views (e.g. the intake-submissions index), where
     * de-dupe falls back to (tenant, actor, action).
     */
    caseId?: string;
    actor: string;
    action: string;
    metadata?: Record<string, unknown>;
    now?: Date;
  },
): Promise<boolean> {
  const now = input.now ?? new Date();
  const since = new Date(now.getTime() - VIEW_AUDIT_DEDUPE_WINDOW_MS);

  // De-dupe scope: keyed on the case when present, else the tenant for list
  // views. We never de-dupe globally — if neither id is given there is no scope
  // to dedupe on, so we always write (a `*.viewed` with no case/tenant is not a
  // case we produce, but guard against silently collapsing across tenants).
  const filters = [
    eq(auditLog.actor, input.actor),
    eq(auditLog.action, input.action),
    gt(auditLog.createdAt, since),
  ];
  const scoped = Boolean(input.caseId || input.tenantId);
  if (input.caseId) filters.push(eq(auditLog.caseId, input.caseId));
  else if (input.tenantId) filters.push(eq(auditLog.tenantId, input.tenantId));

  if (scoped) {
    const [recent] = await db
      .select({ id: auditLog.id })
      .from(auditLog)
      .where(and(...filters))
      .orderBy(desc(auditLog.createdAt))
      .limit(1);
    if (recent) return false;
  }

  await writeAudit(db, {
    tenantId: input.tenantId,
    caseId: input.caseId,
    actor: input.actor,
    action: input.action,
    metadata: input.metadata ?? {},
  });
  return true;
}
