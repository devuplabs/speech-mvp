import { drizzle } from "drizzle-orm/node-postgres";
import pg from "pg";
import * as schema from "./schema.js";

export type Db = ReturnType<typeof drizzle<typeof schema>>;

let pool: pg.Pool | null = null;
let db: Db | null = null;

export function getDb(connectionString: string): Db {
  if (!db) {
    pool = new pg.Pool({ connectionString, max: 10 });
    db = drizzle(pool, { schema });
  }
  return db;
}

export async function closeDb(): Promise<void> {
  if (pool) {
    await pool.end();
    pool = null;
    db = null;
  }
}
