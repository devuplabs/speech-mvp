import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import pg from "pg";

const migrationsDir = path.join(
  path.dirname(fileURLToPath(import.meta.url)),
  "../../drizzle",
);

const MIGRATION_IDS = ["0000_init", "0001_register_patient", "0002_booking", "0003_questionnaire",
  "0004_clinical_report", "0005_practice_and_users",
] as const;

export async function runMigrations(connectionString: string): Promise<void> {
  const pool = new pg.Pool({ connectionString });
  const client = await pool.connect();
  try {
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
        console.log(`migration ${migrationId} already applied`);
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
        console.log(`migration ${migrationId} applied`);
      } catch (err) {
        await client.query("ROLLBACK");
        throw err;
      }
    }
  } finally {
    client.release();
    await pool.end();
  }
}
