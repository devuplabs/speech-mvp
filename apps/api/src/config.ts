import { z } from "zod";

/** Cloud Run / Terraform often set optional URLs to ""; treat as unset. */
function emptyToUndefined(val: unknown): unknown {
  return typeof val === "string" && val.trim() === "" ? undefined : val;
}

const envSchema = z.object({
  PORT: z.coerce.number().default(8080),
  NODE_ENV: z.enum(["development", "production", "test"]).default("development"),
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
  LLM_CLOUD_TASKS_QUEUE: z.string().default("sona-llm-dev"),
  RUNTIME_SERVICE_ACCOUNT: z.string().optional(),
  WORKER_SERVICE_URL: z.preprocess(emptyToUndefined, z.string().url().optional()),
  POSTMARK_API_TOKEN: z.preprocess(emptyToUndefined, z.string().min(1).optional()),
  POSTMARK_FROM_EMAIL: z.preprocess(
    emptyToUndefined,
    z.string().email().optional(),
  ),
  RUN_MIGRATIONS_ON_START: z
    .enum(["true", "false"])
    .default("true")
    .transform((v) => v === "true"),
  /** Comma-separated browser origins allowed to call the API (e.g. https://app.example.com). Required in production for web clients. */
  CORS_ORIGINS: z.preprocess(emptyToUndefined, z.string().optional()),
  /** When true and NODE_ENV=development, also allow http://localhost|127.0.0.1 on ports 3000 and 8080–8099. Never enable in production. */
  CORS_ALLOW_LOCALHOST: z
    .enum(["true", "false"])
    .default("false")
    .transform((v) => v === "true"),
  /** Parent web app base URL for magic intake links (no trailing slash required). */
  SONA_WEB_BASE_URL: z.preprocess(
    emptyToUndefined,
    z.string().url().optional(),
  ),
});

export type Env = z.infer<typeof envSchema>;

export function loadEnv(): Env {
  return envSchema.parse(process.env);
}

export function buildDatabaseUrl(env: Env): string | null {
  if (env.DATABASE_URL) return env.DATABASE_URL;
  if (!env.DB_PASSWORD || !env.DB_HOST) return null;
  const user = encodeURIComponent(env.DB_USER);
  const pass = encodeURIComponent(env.DB_PASSWORD);
  return `postgresql://${user}:${pass}@${env.DB_HOST}:5432/${env.DB_NAME}`;
}
