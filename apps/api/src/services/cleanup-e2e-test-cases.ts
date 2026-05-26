import { inArray, sql } from "drizzle-orm";
import type { Db } from "../db/client.js";
import { auditLog, cases } from "../db/schema.js";

/** Shared predicate for legacy automated test cases (not canonical demo personas). */
const E2E_TEST_CASE_WHERE = sql.raw(`
  child_display_name LIKE 'E2E Child%'
  OR child_display_name = 'E2E'
  OR child_display_name LIKE 'Sam T. · e2e%'
  OR child_display_name LIKE '% · e2e %'
  OR child_display_name LIKE '% · seed %'
  OR child_display_name ~ '^Child [a-z0-9]{6}$'
  OR (
    child_display_name = 'Child'
    AND (
      parent_email = 'e2e@example.com'
      OR tenant_id IN (
        SELECT id FROM tenants WHERE display_name = 'Sona E2E (automated)'
      )
    )
  )
`);

export async function cleanupE2eTestCases(
  db: Db,
  options: { dryRun: boolean },
): Promise<{
  dryRun: boolean;
  matched: number;
  cases: Array<{ id: string; childDisplayName: string | null }>;
  deleted: number;
}> {
  const rows = await db
    .select({ id: cases.id, childDisplayName: cases.childDisplayName })
    .from(cases)
    .where(E2E_TEST_CASE_WHERE);

  const summary = rows.map((r) => ({
    id: r.id,
    childDisplayName: r.childDisplayName,
  }));

  if (options.dryRun || rows.length === 0) {
    return { dryRun: options.dryRun, matched: rows.length, cases: summary, deleted: 0 };
  }

  const ids = rows.map((r) => r.id);
  await db.delete(auditLog).where(inArray(auditLog.caseId, ids));
  const removed = await db.delete(cases).where(inArray(cases.id, ids)).returning({ id: cases.id });

  return {
    dryRun: false,
    matched: rows.length,
    cases: summary,
    deleted: removed.length,
  };
}
