import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import pg from "pg";

const migrationsDir = path.join(
  path.dirname(fileURLToPath(import.meta.url)),
  "../../drizzle",
);

const MIGRATION_ID = "0000_init";

export async function runMigrations(connectionString: string): Promise<void> {
  const sqlPath = path.join(migrationsDir, `${MIGRATION_ID}.sql`);
  const sql = readFileSync(sqlPath, "utf8");

  const pool = new pg.Pool({ connectionString });
  const client = await pool.connect();
  try {
    await client.query(`
      CREATE TABLE IF NOT EXISTS schema_migrations (
        id text PRIMARY KEY,
        applied_at timestamptz DEFAULT now() NOT NULL
      )
    `);

    const existing = await client.query(
      "SELECT 1 FROM schema_migrations WHERE id = $1",
      [MIGRATION_ID],
    );
    if (existing.rowCount && existing.rowCount > 0) {
      console.log(`migration ${MIGRATION_ID} already applied`);
      return;
    }

    await client.query("BEGIN");
    try {
      await client.query(sql);
      await client.query("INSERT INTO schema_migrations (id) VALUES ($1)", [
        MIGRATION_ID,
      ]);
      await client.query("COMMIT");
      console.log(`migration ${MIGRATION_ID} applied`);
    } catch (err) {
      await client.query("ROLLBACK");
      throw err;
    }
  } finally {
    client.release();
    await pool.end();
  }
}
