import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import pg from "pg";
import { logger } from "../logger.js";

const migrationsDir = path.join(
  path.dirname(fileURLToPath(import.meta.url)),
  "../../drizzle",
);

const MIGRATION_IDS = ["0000_init", "0001_register_patient", "0002_booking", "0003_questionnaire",
  "0004_clinical_report", "0005_practice_and_users", "0006_carryover",
  "0007_journey_statuses", "0008_legal_hold",
  "0009_audit_append_only",
  "0010_fhir_demographics",
  "0011_feedback",
] as const;

export async function runMigrations(connectionString: string): Promise<void> {
  const pool = new pg.Pool({ connectionString });
  const client = await pool.connect();
  try {
    // Serialise concurrent migration runners with a session-level advisory lock.
    // Two real scenarios race: parallel DB-backed test files (vitest runs files
    // concurrently) and multiple Cloud Run instances booting with
    // RUN_MIGRATIONS_ON_START. Without this, two runners both pass the
    // schema_migrations skip-check and then both execute the same migration
    // (e.g. a bare CREATE TYPE), colliding on pg_type's unique index. The lock
    // makes the loser wait; it then sees the migration recorded and skips it.
    // The key is an arbitrary fixed constant shared by all Sona API instances.
    await client.query("SELECT pg_advisory_lock($1)", [4927001]);

    await client.query(`
      CREATE TABLE IF NOT EXISTS schema_migrations (
        id text PRIMARY KEY,
        applied_at timestamptz DEFAULT now() NOT NULL
      )
    `);

    for (const migrationId of MIGRATION_IDS) {
      const existing = await client.query(
        "SELECT 1 FROM schema_migrations WHERE id = $1",
        [migrationId],
      );
      if (existing.rowCount && existing.rowCount > 0) {
        logger.info("migration.already_applied", { migrationId });
        continue;
      }

      const sqlPath = path.join(migrationsDir, `${migrationId}.sql`);
      const sql = readFileSync(sqlPath, "utf8");

      await client.query("BEGIN");
      try {
        await client.query(sql);
        await client.query("INSERT INTO schema_migrations (id) VALUES ($1)", [
          migrationId,
        ]);
        await client.query("COMMIT");
        logger.info("migration.applied", { migrationId });
      } catch (err) {
        await client.query("ROLLBACK");
        throw err;
      }
    }
  } finally {
    // Release the advisory lock before returning the connection to the pool.
    // Best-effort: if the session already errored/closed, the lock is dropped
    // automatically when the backend ends.
    try {
      await client.query("SELECT pg_advisory_unlock($1)", [4927001]);
    } catch {
      // ignore — connection may already be closing; lock auto-releases.
    }
    client.release();
    await pool.end();
  }
}
