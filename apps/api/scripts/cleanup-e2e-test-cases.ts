#!/usr/bin/env npx tsx
/**
 * One-off: delete synthetic test cases left in dev/stage databases.
 *
 * Matches legacy E2E labels and ephemeral seed suffixes. Does not touch
 * canonical demo personas (Aria M., Jaden O., etc.).
 *
 * Usage:
 *   cd apps/api
 *   DATABASE_URL=postgresql://... npx tsx scripts/cleanup-e2e-test-cases.ts --dry-run
 *   DATABASE_URL=postgresql://... npx tsx scripts/cleanup-e2e-test-cases.ts
 *
 * Refuses prod-looking connection strings.
 */

import pg from "pg";
import { buildDatabaseUrl, loadEnv } from "../src/config.js";

const dryRun = process.argv.includes("--dry-run");

const CASE_WHERE = `
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
`;

async function main() {
  const env = loadEnv();
  const url = buildDatabaseUrl(env);
  if (!url) {
    console.error("Set DATABASE_URL (or DB_HOST + DB_PASSWORD).");
    process.exit(2);
  }
  if (/prod|production/i.test(url)) {
    console.error("Refusing prod-looking DATABASE_URL.");
    process.exit(2);
  }

  const client = new pg.Client({ connectionString: url });
  await client.connect();

  const preview = await client.query<{ id: string; child_display_name: string }>(
    `SELECT id, child_display_name FROM cases WHERE ${CASE_WHERE} ORDER BY created_at`,
  );

  if (preview.rows.length === 0) {
    console.log("No matching test cases found.");
    await client.end();
    return;
  }

  console.log(`Found ${preview.rows.length} case(s):`);
  for (const row of preview.rows) {
    console.log(`  ${row.id}  ${row.child_display_name}`);
  }

  if (dryRun) {
    console.log("\nDry run — no rows deleted.");
    await client.end();
    return;
  }

  const ids = preview.rows.map((r) => r.id);
  await client.query(`DELETE FROM audit_log WHERE case_id = ANY($1::uuid[])`, [ids]);
  const deleted = await client.query(`DELETE FROM cases WHERE id = ANY($1::uuid[])`, [ids]);
  console.log(`\nDeleted ${deleted.rowCount} case(s) (related rows cascade).`);
  await client.end();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
