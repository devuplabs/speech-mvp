import { serve } from "@hono/node-server";
import { sql } from "drizzle-orm";
import { Hono } from "hono";
import { cors } from "hono/cors";
import { buildDatabaseUrl, loadEnv } from "./config.js";
import { resolveCorsOrigin } from "./cors.js";
import { closeDb, getDb } from "./db/client.js";
import { runMigrations } from "./db/migrate.js";
import { SelfHostedLlmClient } from "./llm/client.js";
import { createTaskRoutes } from "./routes/tasks.js";
import { createV1Routes } from "./routes/v1.js";

const env = loadEnv();
const llm = new SelfHostedLlmClient(env);
const databaseUrl = buildDatabaseUrl(env);

const app = new Hono();

app.use(
  "*",
  cors({
    origin: (origin) => resolveCorsOrigin(origin, env),
    allowMethods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allowHeaders: ["Content-Type"],
  }),
);

app.get("/health", (c) =>
  c.json({
    status: "ok",
    mode: env.SONA_MODE,
    jurisdiction: env.JURISDICTION,
    inference: llm.configured ? "configured" : "pending_phase_2",
    parentSummaryDelivery: "portal",
    database: databaseUrl ? "configured" : "not_configured",
  }),
);

app.get("/ready", async (c) => {
  let database = false;
  if (databaseUrl) {
    try {
      const db = getDb(databaseUrl);
      await db.execute(sql`SELECT 1`);
      database = true;
    } catch {
      database = false;
    }
  }
  const inference = await llm.health();
  const ok = database;
  return c.json(
    {
      status: ok ? "ok" : "degraded",
      checks: { api: true, database, inference },
    },
    ok ? 200 : 503,
  );
});

if (databaseUrl) {
  const db = getDb(databaseUrl);

  if (env.RUN_MIGRATIONS_ON_START) {
    await runMigrations(databaseUrl);
  }

  if (env.SONA_MODE === "api") {
    app.route("/v1", createV1Routes(db, env));
    app.get("/v1/meta", (c) =>
      c.json({
        service: "sona-api",
        version: "0.1.0",
        jurisdiction: env.JURISDICTION,
      }),
    );
  }

  if (env.SONA_MODE === "worker") {
    app.route("/internal/tasks", createTaskRoutes(db));
  }
} else {
  console.warn("DATABASE_URL / DB_* not set — API data routes disabled");
  app.get("/v1/meta", (c) =>
    c.json({
      service: "sona-api",
      version: "0.1.0",
      jurisdiction: env.JURISDICTION,
      warning: "database_not_configured",
    }),
  );
}

serve({ fetch: app.fetch, port: env.PORT }, (info) => {
  console.log(`sona-${env.SONA_MODE} listening on http://localhost:${info.port}`);
});

process.on("SIGTERM", () => {
  void closeDb();
});
