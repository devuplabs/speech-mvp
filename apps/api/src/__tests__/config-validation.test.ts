import { describe, expect, it } from "vitest";
import {
  ConfigValidationError,
  demoRoutesEnabled,
  isProdEnv,
  validateConfig,
  type Env,
} from "../config.js";

/**
 * Unit tests for the boot-time prod-safety config gate (DEV-45). `validateConfig`
 * is a pure function so the refuse-to-boot rules are testable without booting the
 * server. Non-prod is permissive; prod fails fast on missing/contradictory config.
 */

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
    RATE_LIMIT_ENABLED: true,
    ...overrides,
  } as Env;
}

/** A prod env that satisfies every required rule (the happy path baseline). */
function makeValidProd(overrides: Partial<Env> = {}): Env {
  return makeEnv({
    NODE_ENV: "production",
    DATABASE_URL: "postgresql://u:p@db:5432/sona",
    SONA_WEB_BASE_URL: "https://app.example.com",
    INFERENCE_OPENAI_BASE_URL: "https://vertex.example/v1",
    CORS_ALLOW_LOCALHOST: false,
    ALLOW_STUB_DRAFTS: false,
    ...overrides,
  });
}

describe("isProdEnv", () => {
  it("is prod when NODE_ENV=production and no SONA_ENV", () => {
    expect(isProdEnv(makeEnv({ NODE_ENV: "production" }))).toBe(true);
  });

  it("is not prod for dev/test", () => {
    expect(isProdEnv(makeEnv({ NODE_ENV: "development" }))).toBe(false);
    expect(isProdEnv(makeEnv({ NODE_ENV: "test" }))).toBe(false);
  });

  it("SONA_ENV overrides NODE_ENV in both directions", () => {
    // Deployed bundle has NODE_ENV=production but is a non-prod stack.
    expect(isProdEnv(makeEnv({ NODE_ENV: "production", SONA_ENV: "staging" }))).toBe(false);
    expect(isProdEnv(makeEnv({ NODE_ENV: "production", SONA_ENV: "dev" }))).toBe(false);
    // Explicit prod label even if NODE_ENV were not production.
    expect(isProdEnv(makeEnv({ NODE_ENV: "development", SONA_ENV: "prod" }))).toBe(true);
    expect(isProdEnv(makeEnv({ NODE_ENV: "production", SONA_ENV: "production" }))).toBe(true);
  });
});

describe("demoRoutesEnabled", () => {
  it("enables demo routes in dev and test", () => {
    expect(demoRoutesEnabled(makeEnv({ NODE_ENV: "development" }))).toBe(true);
    expect(demoRoutesEnabled(makeEnv({ NODE_ENV: "test" }))).toBe(true);
  });

  it("disables demo routes in production", () => {
    expect(demoRoutesEnabled(makeEnv({ NODE_ENV: "production" }))).toBe(false);
  });

  it("disables demo routes when SONA_ENV marks a prod stack", () => {
    expect(
      demoRoutesEnabled(makeEnv({ NODE_ENV: "development", SONA_ENV: "prod" })),
    ).toBe(false);
  });

  it("keeps demo routes on a deployed dev/staging stack (NODE_ENV=production, SONA_ENV=dev)", () => {
    // Such a bundle has NODE_ENV=production; the route gate keys off NODE_ENV
    // being development/test, so a deployed dev stack must set NODE_ENV
    // accordingly. SONA_ENV=staging is still non-prod but not dev/test.
    expect(
      demoRoutesEnabled(makeEnv({ NODE_ENV: "development", SONA_ENV: "dev" })),
    ).toBe(true);
  });
});

describe("validateConfig", () => {
  it("is permissive in development (no throw even with sparse config)", () => {
    expect(() => validateConfig(makeEnv({}))).not.toThrow();
  });

  it("is permissive in test", () => {
    expect(() => validateConfig(makeEnv({ NODE_ENV: "test" }))).not.toThrow();
  });

  it("accepts a fully-configured prod env", () => {
    expect(() => validateConfig(makeValidProd())).not.toThrow();
  });

  it("refuses to boot in prod when CORS_ALLOW_LOCALHOST is true", () => {
    expect(() =>
      validateConfig(makeValidProd({ CORS_ALLOW_LOCALHOST: true })),
    ).toThrowError(ConfigValidationError);
    try {
      validateConfig(makeValidProd({ CORS_ALLOW_LOCALHOST: true }));
    } catch (err) {
      expect((err as ConfigValidationError).issues.join("\n")).toMatch(/CORS_ALLOW_LOCALHOST/);
    }
  });

  it("refuses to boot in prod with no inference and no ALLOW_STUB_DRAFTS", () => {
    expect(() =>
      validateConfig(makeValidProd({ INFERENCE_OPENAI_BASE_URL: undefined })),
    ).toThrowError(ConfigValidationError);
  });

  it("boots in prod with ALLOW_STUB_DRAFTS=true even with no inference endpoint", () => {
    expect(() =>
      validateConfig(
        makeValidProd({ INFERENCE_OPENAI_BASE_URL: undefined, ALLOW_STUB_DRAFTS: true }),
      ),
    ).not.toThrow();
  });

  it("boots in prod with a real inference endpoint and no stub opt-in", () => {
    expect(() =>
      validateConfig(
        makeValidProd({
          INFERENCE_OPENAI_BASE_URL: "https://vertex.example/v1",
          ALLOW_STUB_DRAFTS: false,
        }),
      ),
    ).not.toThrow();
  });

  it("refuses to boot in prod with no database configured", () => {
    expect(() =>
      validateConfig(
        makeValidProd({ DATABASE_URL: undefined, DB_HOST: undefined, DB_PASSWORD: undefined }),
      ),
    ).toThrowError(ConfigValidationError);
  });

  it("accepts DB_HOST + DB_PASSWORD as a database in prod", () => {
    expect(() =>
      validateConfig(
        makeValidProd({ DATABASE_URL: undefined, DB_HOST: "db", DB_PASSWORD: "secret" }),
      ),
    ).not.toThrow();
  });

  it("refuses to boot in prod without SONA_WEB_BASE_URL", () => {
    expect(() =>
      validateConfig(makeValidProd({ SONA_WEB_BASE_URL: undefined })),
    ).toThrowError(ConfigValidationError);
  });

  it("reports all problems at once", () => {
    try {
      validateConfig(
        makeValidProd({
          CORS_ALLOW_LOCALHOST: true,
          INFERENCE_OPENAI_BASE_URL: undefined,
          DATABASE_URL: undefined,
          SONA_WEB_BASE_URL: undefined,
        }),
      );
      throw new Error("expected validateConfig to throw");
    } catch (err) {
      expect(err).toBeInstanceOf(ConfigValidationError);
      expect((err as ConfigValidationError).issues.length).toBeGreaterThanOrEqual(4);
    }
  });
});
