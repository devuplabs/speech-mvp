import { Hono } from "hono";
import { describe, expect, it } from "vitest";
import type { Env } from "../config.js";
import { securityHeaders } from "../security-headers.js";

function makeEnv(nodeEnv: Env["NODE_ENV"]): Env {
  return {
    PORT: 8080,
    NODE_ENV: nodeEnv,
    JURISDICTION: "uk",
    SONA_MODE: "api",
    GCP_REGION: "europe-west2",
    DB_NAME: "sona",
    DB_USER: "sona_app",
    LLM_CLOUD_TASKS_QUEUE: "sona-llm-dev",
    RUN_MIGRATIONS_ON_START: true,
    CORS_ALLOW_LOCALHOST: false,
    RATE_LIMIT_TOKEN_MAX: 30,
    RATE_LIMIT_TOKEN_WINDOW_MS: 60_000,
    RATE_LIMIT_ENABLED: true,
  } as Env;
}

function appFor(nodeEnv: Env["NODE_ENV"]) {
  const app = new Hono();
  app.use("*", securityHeaders(makeEnv(nodeEnv)));
  app.get("/x", (c) => c.json({ ok: true }));
  return app;
}

describe("securityHeaders", () => {
  it("sets the baseline hardening headers on every response", async () => {
    const res = await appFor("development").request("/x");
    expect(res.headers.get("X-Content-Type-Options")).toBe("nosniff");
    expect(res.headers.get("X-Frame-Options")).toBe("DENY");
    expect(res.headers.get("Referrer-Policy")).toBe("no-referrer");
    expect(res.headers.get("Content-Security-Policy")).toContain("frame-ancestors 'none'");
    expect(res.headers.get("Content-Security-Policy")).toContain("default-src 'none'");
  });

  it("omits HSTS in development", async () => {
    const res = await appFor("development").request("/x");
    expect(res.headers.get("Strict-Transport-Security")).toBeNull();
  });

  it("emits HSTS in production", async () => {
    const res = await appFor("production").request("/x");
    expect(res.headers.get("Strict-Transport-Security")).toContain("max-age=31536000");
  });
});
