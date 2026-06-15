import { z } from "zod";

/** Cloud Run / Terraform often set optional URLs to ""; treat as unset. */
function emptyToUndefined(val: unknown): unknown {
  return typeof val === "string" && val.trim() === "" ? undefined : val;
}

const envSchema = z.object({
  PORT: z.coerce.number().default(8080),
  NODE_ENV: z.enum(["development", "production", "test"]).default("development"),
  /**
   * Deployment environment label, independent of NODE_ENV (which is set to
   * "production" by the Node runtime/bundler for *any* deployed build, including
   * a "dev"/"staging" Cloud Run service). Use SONA_ENV to distinguish a real
   * production stack from non-prod deployed stacks. When set to "prod"/"production"
   * the full refuse-to-boot prod gate applies even if NODE_ENV were "development".
   * Optional; when unset we fall back to NODE_ENV. See infra/docs/prod-env-matrix.md.
   */
  SONA_ENV: z.preprocess(
    emptyToUndefined,
    z.enum(["dev", "development", "staging", "stage", "prod", "production"]).optional(),
  ),
  JURISDICTION: z.enum(["uk", "us"]).default("uk"),
  SONA_MODE: z.enum(["api", "worker"]).default("api"),
  GCP_PROJECT_ID: z.string().optional(),
  GCP_REGION: z.string().default("europe-west2"),
  CLOUD_SQL_CONNECTION_NAME: z.string().optional(),
  DB_HOST: z.string().optional(),
  DB_NAME: z.string().default("sona"),
  DB_USER: z.string().default("sona_app"),
  DB_PASSWORD: z.string().optional(),
  DATABASE_URL: z.string().optional(),
  INFERENCE_OPENAI_BASE_URL: z.preprocess(
    emptyToUndefined,
    z.string().url().optional(),
  ),
  LLM_MODEL: z.preprocess(emptyToUndefined, z.string().min(1).optional()),
  LLM_API_KEY: z.preprocess(emptyToUndefined, z.string().min(1).optional()),
  SONA_WEB_BASE_URL: z.preprocess(emptyToUndefined, z.string().url().optional()),
  LLM_CLOUD_TASKS_QUEUE: z.string().default("sona-llm-dev"),
  RUNTIME_SERVICE_ACCOUNT: z.string().optional(),
  WORKER_SERVICE_URL: z.preprocess(emptyToUndefined, z.string().url().optional()),
  MAILGUN_API_KEY: z.preprocess(emptyToUndefined, z.string().min(1).optional()),
  MAILGUN_DOMAIN: z.preprocess(emptyToUndefined, z.string().min(1).optional()),
  MAILGUN_FROM_EMAIL: z.preprocess(
    emptyToUndefined,
    z.string().email().optional(),
  ),
  // Mailgun API region base, e.g. https://api.eu.mailgun.net for EU. Defaults to US.
  MAILGUN_BASE_URL: z.preprocess(emptyToUndefined, z.string().url().optional()),
  RUN_MIGRATIONS_ON_START: z
    .enum(["true", "false"])
    .default("true")
    .transform((v) => v === "true"),
  /** Comma-separated browser origins allowed to call the API (e.g. https://app.example.com). Required in production for web clients. */
  CORS_ORIGINS: z.preprocess(emptyToUndefined, z.string().optional()),
  /** When true and NODE_ENV=development, also allow http://localhost|127.0.0.1 on ports 3000 and 8080–8099. Never enable in production (refuses to boot). */
  CORS_ALLOW_LOCALHOST: z
    .enum(["true", "false"])
    .default("false")
    .transform((v) => v === "true"),
  /**
   * Deliberate, documented opt-in (ADR-007) that permits production to serve
   * *stub* AI drafts when no real inference endpoint is configured. Default
   * false: in prod, if neither INFERENCE_OPENAI_BASE_URL nor this flag is set,
   * the API refuses to boot so prod can never silently serve stub AI. Only set
   * to "true" for an explicit, eyes-open non-clinical prod (e.g. an infra smoke
   * stack with no real patients). See infra/docs/prod-env-matrix.md.
   */
  ALLOW_STUB_DRAFTS: z
    .enum(["true", "false"])
    .default("false")
    .transform((v) => v === "true"),
  /**
   * Per-IP rate limit for unauthenticated magic-link token endpoints
   * (GET /v1/intake-links/:token, GET /v1/portal/:token,
   * POST /v1/portal/:token/progress). Fixed window. In-memory (single
   * instance) — see docs/security/hardening-checklist.md for the prod story.
   */
  RATE_LIMIT_TOKEN_MAX: z.coerce.number().int().positive().default(30),
  /** Rate-limit window in milliseconds (default 60s). */
  RATE_LIMIT_TOKEN_WINDOW_MS: z.coerce.number().int().positive().default(60_000),
  /** Set to "false" to disable rate limiting entirely (e.g. for load tests). */
  RATE_LIMIT_ENABLED: z
    .enum(["true", "false"])
    .default("true")
    .transform((v) => v === "true"),
});

export type Env = z.infer<typeof envSchema>;

/**
 * True when this process is a real *production* deployment.
 *
 * A build is prod when SONA_ENV says so (prod/production) OR — absent an
 * explicit SONA_ENV — when NODE_ENV is "production". A SONA_ENV of
 * dev/development/staging/stage is treated as non-prod even though NODE_ENV is
 * typically "production" for any deployed bundle. Pure function (testable
 * without booting).
 */
export function isProdEnv(env: Pick<Env, "NODE_ENV" | "SONA_ENV">): boolean {
  if (env.SONA_ENV) return env.SONA_ENV === "prod" || env.SONA_ENV === "production";
  return env.NODE_ENV === "production";
}

/**
 * Whether the dev/demo maintenance endpoints (POST /v1/demo/*) may be
 * *registered at all*. They exist only in dev/test and never in production —
 * in prod they must be absent (404), not guarded (403). Pure function.
 */
export function demoRoutesEnabled(env: Pick<Env, "NODE_ENV" | "SONA_ENV">): boolean {
  if (isProdEnv(env)) return false;
  return env.NODE_ENV === "development" || env.NODE_ENV === "test";
}

/** Thrown by validateConfig when prod config is missing/contradictory. */
export class ConfigValidationError extends Error {
  readonly issues: string[];
  constructor(issues: string[]) {
    super(`Invalid configuration:\n  - ${issues.join("\n  - ")}`);
    this.name = "ConfigValidationError";
    this.issues = issues;
  }
}

/**
 * Boot-time config validation. Fails fast on missing/contradictory production
 * config so prod can never silently run with a dev convenience enabled. Pure
 * function (takes a parsed Env, no process/IO) so it is unit-testable without
 * booting the server. Returns nothing on success; throws ConfigValidationError
 * listing every problem. Non-prod is permissive (returns immediately).
 *
 * Prod (isProdEnv) rules — all enforced here:
 *  - CORS_ALLOW_LOCALHOST must be false (a localhost CORS allowance in prod is
 *    always a mistake).
 *  - Inference: either a real INFERENCE_OPENAI_BASE_URL is set (ADR-007 Vertex
 *    OpenAI-compatible endpoint) OR ALLOW_STUB_DRAFTS=true is the explicit
 *    opt-in. Otherwise refuse to boot so prod never silently serves stub AI.
 *  - Required prod config present: a database (DATABASE_URL or DB_HOST+
 *    DB_PASSWORD), SONA_WEB_BASE_URL, and JURISDICTION.
 */
export function validateConfig(env: Env): void {
  if (!isProdEnv(env)) return;

  const issues: string[] = [];

  if (env.CORS_ALLOW_LOCALHOST) {
    issues.push(
      "CORS_ALLOW_LOCALHOST must be false in production (it allows localhost browser origins; never enable in prod).",
    );
  }

  const hasRealInference = Boolean(env.INFERENCE_OPENAI_BASE_URL);
  if (!hasRealInference && !env.ALLOW_STUB_DRAFTS) {
    issues.push(
      "No inference endpoint configured in production: set INFERENCE_OPENAI_BASE_URL (ADR-007 Vertex) " +
        "or, for a deliberate non-clinical stub stack, set ALLOW_STUB_DRAFTS=true. " +
        "Refusing to boot so prod cannot silently serve stub AI drafts.",
    );
  }

  const hasDatabase =
    Boolean(env.DATABASE_URL) || Boolean(env.DB_HOST && env.DB_PASSWORD);
  if (!hasDatabase) {
    issues.push(
      "No database configured in production: set DATABASE_URL, or both DB_HOST and DB_PASSWORD.",
    );
  }

  if (!env.SONA_WEB_BASE_URL) {
    issues.push(
      "SONA_WEB_BASE_URL is required in production (used to build intake/portal links).",
    );
  }

  if (!env.JURISDICTION) {
    issues.push("JURISDICTION is required in production (uk|us).");
  }

  if (issues.length > 0) throw new ConfigValidationError(issues);
}

export function loadEnv(): Env {
  const env = envSchema.parse(process.env);
  validateConfig(env);
  return env;
}

export function buildDatabaseUrl(env: Env): string | null {
  if (env.DATABASE_URL) return env.DATABASE_URL;
  if (!env.DB_PASSWORD || !env.DB_HOST) return null;
  const user = encodeURIComponent(env.DB_USER);
  const pass = encodeURIComponent(env.DB_PASSWORD);
  return `postgresql://${user}:${pass}@${env.DB_HOST}:5432/${env.DB_NAME}`;
}
