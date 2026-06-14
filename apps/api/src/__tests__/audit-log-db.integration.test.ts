import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { sql } from "drizzle-orm";
import { getDb, closeDb, type Db } from "../db/client.js";
import { runMigrations } from "../db/migrate.js";
import { auditLog, cases, tenants } from "../db/schema.js";
import {
  writeAudit,
  writeViewAudit,
  VIEW_AUDIT_DEDUPE_WINDOW_MS,
} from "../services/audit.js";
import {
  buildCaseAuditExport,
  confirmErasure,
  requestErasure,
} from "../services/dsar.js";
import { purgeExpiredAuditRows } from "../services/audit-retention.js";

/**
 * DB-backed integration tests for the DEV-25 audit controls. These require a
 * real Postgres (the local dev DB or the CI e2e Postgres service); they are
 * skipped when DATABASE_URL is not set so the unit-only `npm test` stays green
 * without a database. The CI e2e-smoke job provides Postgres.
 *
 * IMPORTANT (append-only test): these only *prove* the trigger when the
 * connecting role is the table owner (as `sona_app` is locally and in CI). The
 * trigger is authoritative even for the owner; the migration also REVOKEs
 * UPDATE/DELETE as a second layer (verified by docs/runbook for non-owner roles).
 */

const DATABASE_URL = process.env.DATABASE_URL;

describe.skipIf(!DATABASE_URL)("audit_log DB controls (DEV-25)", () => {
  let db: Db;
  let tenantId: string;

  beforeAll(async () => {
    await runMigrations(DATABASE_URL!);
    db = getDb(DATABASE_URL!);
    const [t] = await db
      .insert(tenants)
      .values({ displayName: `dev25-audit-${Date.now()}`, jurisdiction: "uk" })
      .returning();
    tenantId = t.id;
  }, 30_000);

  afterAll(async () => {
    await closeDb();
  });

  async function newCase(): Promise<string> {
    const [row] = await db.insert(cases).values({ tenantId }).returning();
    return row.id;
  }

  /**
   * Drizzle wraps the pg error ("Failed query: …") and keeps the original on
   * `.cause`. Assert the append-only message appears anywhere in that chain.
   */
  async function expectAppendOnlyRejection(p: Promise<unknown>): Promise<void> {
    let thrown: unknown;
    try {
      await p;
    } catch (err) {
      thrown = err;
    }
    expect(thrown, "expected the query to be rejected by the append-only guard").toBeDefined();
    let msg = "";
    let cur: unknown = thrown;
    while (cur instanceof Error) {
      msg += ` ${cur.message}`;
      cur = (cur as { cause?: unknown }).cause;
    }
    expect(msg).toMatch(/append-only/i);
  }

  it("de-dupes *.viewed within the window but writes again after it", async () => {
    const caseId = await newCase();

    const first = await writeViewAudit(db, {
      tenantId,
      caseId,
      actor: "clinician",
      action: "case.viewed",
    });
    const second = await writeViewAudit(db, {
      tenantId,
      caseId,
      actor: "clinician",
      action: "case.viewed",
    });
    expect(first).toBe(true);
    expect(second).toBe(false);

    // Simulate a view past the window by passing a future `now`.
    const later = new Date(Date.now() + VIEW_AUDIT_DEDUPE_WINDOW_MS + 1000);
    const third = await writeViewAudit(db, {
      tenantId,
      caseId,
      actor: "clinician",
      action: "case.viewed",
      now: later,
    });
    expect(third).toBe(true);

    const rows = await db
      .select()
      .from(auditLog)
      .where(sql`${auditLog.caseId} = ${caseId} AND ${auditLog.action} = 'case.viewed'`);
    expect(rows).toHaveLength(2);
  });

  it("blocks UPDATE on audit_log (append-only)", async () => {
    const caseId = await newCase();
    await writeAudit(db, { tenantId, caseId, actor: "clinician", action: "case.created" });

    await expectAppendOnlyRejection(
      db.execute(sql`UPDATE audit_log SET actor = 'tampered' WHERE case_id = ${caseId}`),
    );
  });

  it("blocks DELETE on audit_log (append-only)", async () => {
    const caseId = await newCase();
    await writeAudit(db, { tenantId, caseId, actor: "clinician", action: "case.created" });

    await expectAppendOnlyRejection(
      db.execute(sql`DELETE FROM audit_log WHERE case_id = ${caseId}`),
    );
  });

  it("allows the DSAR scrub UPDATE via the escape hatch and keeps erasure working", async () => {
    const caseId = await newCase();
    // Seed an audit row carrying a (hypothetical) PHI metadata key.
    await db.insert(auditLog).values({
      tenantId,
      caseId,
      actor: "clinician",
      action: "case.created",
      metadata: { childName: "Should Be Scrubbed", outcome: "ok" },
    });

    const requested = await requestErasure(db, caseId);
    expect(requested.ok).toBe(true);
    if (!requested.ok) return;

    const confirmed = await confirmErasure(db, caseId, requested.token);
    expect(confirmed.ok).toBe(true);
    if (!confirmed.ok) return;

    // The case PHI is gone; the audit rows are retained, detached, scrubbed.
    const [gone] = await db.select().from(cases).where(sql`${cases.id} = ${caseId}`);
    expect(gone).toBeUndefined();

    // Scrubbed (retained) rows carry phiScrubbed:true; the separate `case.erased`
    // tombstone also references erasedCaseId but is a fresh INSERT, so exclude it.
    const retained = await db
      .select()
      .from(auditLog)
      .where(
        sql`(${auditLog.metadata} ->> 'erasedCaseId') = ${caseId} AND (${auditLog.metadata} ->> 'phiScrubbed') = 'true'`,
      );
    expect(retained.length).toBeGreaterThan(0);
    for (const r of retained) {
      const meta = (r.metadata ?? {}) as Record<string, unknown>;
      expect(meta.childName).toBeUndefined();
      expect(meta.phiScrubbed).toBe(true);
      expect(r.caseId).toBeNull();
    }

    // The append-only tombstone exists and carries no PHI.
    const [tombstone] = await db
      .select()
      .from(auditLog)
      .where(sql`${auditLog.action} = 'case.erased' AND (${auditLog.metadata} ->> 'erasedCaseId') = ${caseId}`);
    expect(tombstone).toBeDefined();
  });

  it("retention purge deletes only rows older than 7 years (and dry-run is non-destructive)", async () => {
    const caseId = await newCase();
    // One old row (8 years ago) and one fresh row.
    const oldAt = new Date();
    oldAt.setUTCFullYear(oldAt.getUTCFullYear() - 8);
    await db.insert(auditLog).values({
      tenantId,
      caseId,
      actor: "system",
      action: "old.event",
      createdAt: oldAt,
    });
    await db.insert(auditLog).values({
      tenantId,
      caseId,
      actor: "system",
      action: "fresh.event",
    });

    const dry = await purgeExpiredAuditRows(db, { dryRun: true });
    expect(dry.dryRun).toBe(true);
    expect(dry.deleted).toBeGreaterThanOrEqual(1);
    // Dry run must not delete: the old row is still present.
    const stillThere = await db
      .select()
      .from(auditLog)
      .where(sql`${auditLog.caseId} = ${caseId} AND ${auditLog.action} = 'old.event'`);
    expect(stillThere).toHaveLength(1);

    const applied = await purgeExpiredAuditRows(db, { dryRun: false });
    expect(applied.dryRun).toBe(false);
    expect(applied.deleted).toBeGreaterThanOrEqual(1);

    const afterOld = await db
      .select()
      .from(auditLog)
      .where(sql`${auditLog.caseId} = ${caseId} AND ${auditLog.action} = 'old.event'`);
    expect(afterOld).toHaveLength(0);
    const afterFresh = await db
      .select()
      .from(auditLog)
      .where(sql`${auditLog.caseId} = ${caseId} AND ${auditLog.action} = 'fresh.event'`);
    expect(afterFresh).toHaveLength(1);
  });

  it("buildCaseAuditExport returns the trail oldest-first", async () => {
    const caseId = await newCase();
    await writeAudit(db, { tenantId, caseId, actor: "clinician", action: "a.one" });
    await writeAudit(db, { tenantId, caseId, actor: "clinician", action: "a.two" });

    const result = await buildCaseAuditExport(db, caseId);
    expect(result.ok).toBe(true);
    if (!result.ok) return;
    expect(result.export.meta.entryCount).toBe(result.export.entries.length);
    const actions = result.export.entries.map((e) => e.action);
    expect(actions).toEqual(["a.one", "a.two"]);
  });
});
