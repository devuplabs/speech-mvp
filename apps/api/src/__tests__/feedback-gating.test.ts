import { describe, expect, it } from "vitest";
import type { Db } from "../db/client.js";
import type { Env } from "../config.js";
import { createV1Routes } from "../routes/v1.js";

/**
 * App-level test (DEV-55): the tester-feedback endpoint must be ABSENT (404,
 * route not registered) in production and PRESENT in non-prod (local/CI and
 * hosted dev/staging UAT). We mount the real v1 router and assert on the routing
 * outcome, not handler behaviour — a deliberately-throwing stub db proves the
 * route exists (it reaches the handler and surfaces a non-404) without a real DB.
 */

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

const VALID_BODY = JSON.stringify({ type: "bug", comment: "x" });
const POST = {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: VALID_BODY,
};

describe("feedback route gating (DEV-55)", () => {
  it("does NOT register POST /feedback in production (404, not 403)", async () => {
    const app = createV1Routes(throwingDb, makeEnv({ NODE_ENV: "production" }));
    const res = await app.request("/feedback", POST);
    expect(res.status).toBe(404);
  });

  it("does NOT register POST /feedback when SONA_ENV marks a prod stack", async () => {
    const app = createV1Routes(
      throwingDb,
      // NODE_ENV development but an explicit prod SONA_ENV — still prod.
      makeEnv({ NODE_ENV: "development", SONA_ENV: "prod" }),
    );
    const res = await app.request("/feedback", POST);
    expect(res.status).toBe(404);
  });

  it("registers POST /feedback in local/CI dev (reaches handler → not 404)", async () => {
    const app = createV1Routes(throwingDb, makeEnv({ NODE_ENV: "development" }));
    const res = await app.request("/feedback", POST);
    // Route exists: it reaches the throwing stub db and surfaces a non-404.
    expect(res.status).not.toBe(404);
  });

  it("registers POST /feedback on a hosted dev/staging UAT stack", async () => {
    const app = createV1Routes(
      throwingDb,
      // Deployed bundle: NODE_ENV=production but SONA_ENV marks it non-prod.
      makeEnv({ NODE_ENV: "production", SONA_ENV: "staging" }),
    );
    const res = await app.request("/feedback", POST);
    expect(res.status).not.toBe(404);
  });
});
