import type { Context } from "hono";
import { Hono } from "hono";
import type { Env } from "./config.js";

const disabledBody = {
  error: "database_not_configured" as const,
  message:
    "Set DATABASE_URL in apps/api/.env (e.g. Cloud SQL Auth Proxy on 127.0.0.1:5432). See docs/DEMO.md.",
};

function disabled(c: Context) {
  return c.json(disabledBody, 503);
}

/** v1 routes when Postgres is not configured — avoids misleading 404s in the browser. */
export function createV1DisabledRoutes(env: Env) {
  const app = new Hono();

  app.get("/meta", (c) =>
    c.json({
      service: "sona-api",
      version: "0.1.0",
      jurisdiction: env.JURISDICTION,
      warning: "database_not_configured",
    }),
  );

  app.post("/demo/bootstrap", disabled);
  app.all("/*", disabled);

  return app;
}
