#!/usr/bin/env npx tsx
/**
 * One-off: delete synthetic test cases left in dev/stage databases.
 *
 * Prefer hosted dev (no proxy):
 *   curl -X POST "https://sona-api-dev-3rhenudy6a-nw.a.run.app/v1/demo/cleanup-e2e-test-cases?dryRun=true"
 *   curl -X POST "https://sona-api-dev-3rhenudy6a-nw.a.run.app/v1/demo/cleanup-e2e-test-cases"
 *
 * Local:
 *   cd apps/api
 *   DATABASE_URL=postgresql://... npx tsx scripts/cleanup-e2e-test-cases.ts --dry-run
 */

import { buildDatabaseUrl, loadEnv } from "../src/config.js";
import { closeDb, getDb } from "../src/db/client.js";
import { cleanupE2eTestCases } from "../src/services/cleanup-e2e-test-cases.js";

const dryRun = process.argv.includes("--dry-run");

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

  const db = getDb(url);
  const result = await cleanupE2eTestCases(db, { dryRun });
  await closeDb();

  if (result.matched === 0) {
    console.log("No matching test cases found.");
    return;
  }

  console.log(`Found ${result.matched} case(s):`);
  for (const row of result.cases) {
    console.log(`  ${row.id}  ${row.childDisplayName ?? ""}`);
  }

  if (result.dryRun) {
    console.log("\nDry run — no rows deleted.");
    return;
  }

  console.log(`\nDeleted ${result.deleted} case(s) (related rows cascade).`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
