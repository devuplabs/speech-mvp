import { migrate } from "drizzle-orm/node-postgres/migrator";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { getDb } from "./client.js";

const migrationsFolder = path.join(
  path.dirname(fileURLToPath(import.meta.url)),
  "../../drizzle",
);

export async function runMigrations(connectionString: string): Promise<void> {
  const database = getDb(connectionString);
  await migrate(database, { migrationsFolder });
  console.log("database migrations applied");
}
