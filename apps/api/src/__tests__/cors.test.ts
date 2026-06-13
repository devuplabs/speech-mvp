import { describe, expect, it } from "vitest";
import type { Env } from "../config.js";
import { resolveCorsOrigin } from "../cors.js";

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
    RATE_LIMIT_TOKEN_MAX: 30,
    RATE_LIMIT_TOKEN_WINDOW_MS: 60_000,
    RATE_LIMIT_ENABLED: true,
    ...overrides,
  } as Env;
}

describe("resolveCorsOrigin", () => {
  it("returns null when there is no Origin header", () => {
    expect(resolveCorsOrigin(undefined, makeEnv({}))).toBeNull();
  });

  it("allows an exact configured prod origin", () => {
    const env = makeEnv({
      NODE_ENV: "production",
      CORS_ORIGINS: "https://app.example.com",
    });
    expect(resolveCorsOrigin("https://app.example.com", env)).toBe(
      "https://app.example.com",
    );
  });

  it("denies an unlisted prod origin (never reflects arbitrary origins)", () => {
    const env = makeEnv({
      NODE_ENV: "production",
      CORS_ORIGINS: "https://app.example.com",
    });
    expect(resolveCorsOrigin("https://evil.example.com", env)).toBeNull();
  });

  it("allows localhost in development only when CORS_ALLOW_LOCALHOST is set", () => {
    const dev = makeEnv({
      NODE_ENV: "development",
      CORS_ALLOW_LOCALHOST: true,
      CORS_ORIGINS: "https://app.example.com",
    });
    expect(resolveCorsOrigin("http://localhost:3000", dev)).toBe(
      "http://localhost:3000",
    );
  });

  it("does NOT allow localhost in production even with CORS_ALLOW_LOCALHOST=true", () => {
    const prod = makeEnv({
      NODE_ENV: "production",
      CORS_ALLOW_LOCALHOST: true,
      CORS_ORIGINS: "https://app.example.com",
    });
    expect(resolveCorsOrigin("http://localhost:3000", prod)).toBeNull();
  });

  it("allows localhost in dev when no origins are configured (zero-config dev)", () => {
    const dev = makeEnv({ NODE_ENV: "development", CORS_ALLOW_LOCALHOST: false });
    expect(resolveCorsOrigin("http://localhost:8080", dev)).toBe(
      "http://localhost:8080",
    );
  });

  it("rejects non-http(s) and off-list localhost ports", () => {
    const dev = makeEnv({ NODE_ENV: "development", CORS_ALLOW_LOCALHOST: true });
    expect(resolveCorsOrigin("http://localhost:9999", dev)).toBeNull();
    expect(resolveCorsOrigin("https://localhost:3000", dev)).toBeNull();
  });
});
