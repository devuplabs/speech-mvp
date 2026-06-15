import { describe, expect, it } from "vitest";
import type { Db } from "../db/client.js";
import type { Env } from "../config.js";
import { createV1Routes } from "../routes/v1.js";

/**
 * App-level test (DEV-45): the demo/dev-maintenance endpoints must be ABSENT
 * (404, route not registered) in production and PRESENT in dev. We mount the
 * real v1 router and assert on the routing outcome, not handler behaviour — a
 * deliberately-throwing stub db proves the route exists (it reaches the handler
 * and surfaces a non-404) without needing a real database.
 */

// Stub db: any query throws. Reaching it means the route is registered. The
// global error handler is not mounted here, so a thrown error from a registered
// route surfaces as a 500 — still distinct from a 404 (route absent).
const throwingDb = new Proxy(
  {},
  {
    get() {
      throw new Error("db_not_available_in_test");
    },
  },
) as unknown as Db;

function makeEnv(overrides: Partial<Env>): Env {
  return {
    PORT: 8080,
    NODE_ENV: "development",
    JURISDICTION: "uk",
    SONA_MODE: "api",
    GCP_REGION: "europe-west2",
    DB_NAME: "sona",
    DB_USER: "sona_app",
    LLM_CLOUD_TASKS_QUEUE: "sona-llm-dev",
    RUN_MIGRATIONS_ON_START: true,
    CORS_ALLOW_LOCALHOST: false,
    ALLOW_STUB_DRAFTS: false,
    RATE_LIMIT_TOKEN_MAX: 30,
    RATE_LIMIT_TOKEN_WINDOW_MS: 60_000,
    RATE_LIMIT_ENABLED: false,
    ...overrides,
  } as Env;
}

const DEMO_ROUTES = [
  "/demo/bootstrap",
  "/demo/seed-canonical",
  "/demo/cleanup-e2e-test-cases",
];

describe("demo route gating (DEV-45)", () => {
  it("does NOT register demo routes in production (404, not 403)", async () => {
    const app = createV1Routes(throwingDb, makeEnv({ NODE_ENV: "production" }));
    for (const path of DEMO_ROUTES) {
      const res = await app.request(path, { method: "POST" });
      expect(res.status, `${path} should be absent in prod`).toBe(404);
    }
  });

  it("does NOT register demo routes when SONA_ENV marks a prod stack", async () => {
    const app = createV1Routes(
      throwingDb,
      makeEnv({ NODE_ENV: "development", SONA_ENV: "prod" }),
    );
    for (const path of DEMO_ROUTES) {
      const res = await app.request(path, { method: "POST" });
      expect(res.status, `${path} should be absent on a prod SONA_ENV`).toBe(404);
    }
  });

  it("registers demo routes in development (route present, not 404)", async () => {
    const app = createV1Routes(throwingDb, makeEnv({ NODE_ENV: "development" }));
    for (const path of DEMO_ROUTES) {
      const res = await app.request(path, { method: "POST" });
      // Route exists ⇒ handler reached ⇒ throwing stub db yields a non-404
      // (500 from the unhandled error). The point is the route is registered.
      expect(res.status, `${path} should be present in dev`).not.toBe(404);
    }
  });

  it("registers demo routes in test env", async () => {
    const app = createV1Routes(throwingDb, makeEnv({ NODE_ENV: "test" }));
    const res = await app.request("/demo/bootstrap", { method: "POST" });
    expect(res.status).not.toBe(404);
  });
});
