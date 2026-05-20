import { z } from "zod";

const envSchema = z.object({
  PORT: z.coerce.number().default(8080),
  NODE_ENV: z.enum(["development", "production", "test"]).default("development"),
  JURISDICTION: z.enum(["uk", "us"]).default("uk"),
  GCP_PROJECT_ID: z.string().optional(),
  CLOUD_SQL_CONNECTION_NAME: z.string().optional(),
  INFERENCE_OPENAI_BASE_URL: z.string().url().optional(),
  LLM_CLOUD_TASKS_QUEUE: z.string().default("sona-llm-dev"),
  RUNTIME_SERVICE_ACCOUNT: z.string().optional(),
});

export type Env = z.infer<typeof envSchema>;

export function loadEnv(): Env {
  return envSchema.parse(process.env);
}
