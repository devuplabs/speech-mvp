import { serve } from "@hono/node-server";
import { sql } from "drizzle-orm";
import { Hono } from "hono";
import { cors } from "hono/cors";
import { ZodError } from "zod";
import { AuthError, type AuthErrorCode } from "./auth/verifier.js";
import { buildDatabaseUrl, isProdEnv, loadEnv } from "./config.js";
import { resolveCorsOrigin } from "./cors.js";
import { closeDb, getDb } from "./db/client.js";
import { runMigrations } from "./db/migrate.js";
import { SelfHostedLlmClient } from "./llm/client.js";
import { logger, requestLogging, type RequestLogVariables } from "./logger.js";
import { securityHeaders } from "./security-headers.js";
import { createTaskRoutes } from "./routes/tasks.js";
import { createV1Routes } from "./routes/v1.js";
import { createV1DisabledRoutes } from "./v1-disabled.js";

const env = loadEnv();
const llm = new SelfHostedLlmClient(env);
const databaseUrl = buildDatabaseUrl(env);

const app = new Hono<{ Variables: RequestLogVariables }>();

const AUTH_ERROR_STATUS: Record<AuthErrorCode, 401 | 403 | 503> = {
  no_token: 401,
  invalid_token: 401,
  auth_not_configured: 503,
  not_provisioned: 403,
  forbidden: 403,
};

app.onError((err, c) => {
  if (err instanceof ZodError) {
    return c.json(
      {
        error: "validation_failed",
        issues: err.flatten(),
      },
      400,
    );
  }
  if (err instanceof AuthError) {
    return c.json({ error: err.code }, AUTH_ERROR_STATUS[err.code]);
  }
  logger.error("unhandled_error", {
    err,
    requestId: c.get("requestId"),
    method: c.req.method,
    route: c.req.routePath,
  });
  return c.json({ error: "internal_error" }, 500);
});

app.use("*", requestLogging());

// App-wide security response headers (HSTS in prod, nosniff, frame-ancestors,
// Referrer-Policy, an API-appropriate CSP). Registered after requestLogging so
// the request id is still set, and before cors() — it does not touch the
// Access-Control-* headers that cors() owns.
app.use("*", securityHeaders(env));

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

  // RUN_MIGRATIONS_ON_START policy (DEV-45): dev/CI rely on boot-time
  // migrations, so the flag stays. In production migrations SHOULD run as an
  // explicit, gated deploy step (so a rolling/parallel boot can't race schema
  // changes) — see infra/docs/prod-env-matrix.md. Prod + flag set is allowed
  // but flagged loudly so it is a conscious choice, not an accident.
  if (isProdEnv(env) && env.RUN_MIGRATIONS_ON_START) {
    logger.warn("run_migrations_on_start_enabled_in_prod", {
      reason: "prefer_explicit_deploy_step",
    });
  }

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
    app.route("/internal/tasks", createTaskRoutes(db, env));
  }
} else {
  logger.warn("database_not_configured_data_routes_disabled");
  if (env.SONA_MODE === "api") {
    app.route("/v1", createV1DisabledRoutes(env));
  }
}

serve({ fetch: app.fetch, port: env.PORT }, (info) => {
  logger.info("listening", { mode: env.SONA_MODE, port: info.port });
});

process.on("SIGTERM", () => {
  void closeDb();
});

process.on("unhandledRejection", (reason) => {
  logger.error("unhandled_rejection", { err: reason });
});
