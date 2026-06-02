import { describe, expect, it } from "vitest";
import type { Env } from "../config.js";
import { buildChatCompletionsUrl, isLlmEnabledFor } from "../llm/chat.js";

function envWith(over: Partial<Env>): Env {
  return {
    PORT: 8080,
    NODE_ENV: "test",
    JURISDICTION: "uk",
    SONA_MODE: "api",
    GCP_REGION: "europe-west2",
    DB_NAME: "sona",
    DB_USER: "sona_app",
    LLM_CLOUD_TASKS_QUEUE: "sona-llm-dev",
    RUN_MIGRATIONS_ON_START: false,
    CORS_ALLOW_LOCALHOST: false,
    ...over,
  } as Env;
}

describe("buildChatCompletionsUrl", () => {
  it("appends /chat/completions when the base ends with /openapi (Vertex AI)", () => {
    const base =
      "https://europe-west2-aiplatform.googleapis.com/v1beta1/projects/p/locations/europe-west2/endpoints/openapi";
    expect(buildChatCompletionsUrl(base)).toBe(`${base}/chat/completions`);
  });

  it("appends /chat/completions when the base ends with /v1 (vLLM / OpenAI)", () => {
    const base = "http://10.20.0.5:8000/v1";
    expect(buildChatCompletionsUrl(base)).toBe(`${base}/chat/completions`);
  });

  it("appends /v1/chat/completions for a bare host URL", () => {
    const base = "https://my-private-llm.example.com";
    expect(buildChatCompletionsUrl(base)).toBe(`${base}/v1/chat/completions`);
  });

  it("strips a trailing slash before appending", () => {
    const base =
      "https://europe-west2-aiplatform.googleapis.com/v1beta1/projects/p/locations/europe-west2/endpoints/openapi/";
    expect(buildChatCompletionsUrl(base)).toBe(
      "https://europe-west2-aiplatform.googleapis.com/v1beta1/projects/p/locations/europe-west2/endpoints/openapi/chat/completions",
    );
  });
});

describe("isLlmEnabledFor (per-kind feature flag)", () => {
  it("returns false for every kind when no base URL is configured", () => {
    const env = envWith({});
    expect(isLlmEnabledFor(env, "prep_brief")).toBe(false);
    expect(isLlmEnabledFor(env, "session_plan")).toBe(false);
    expect(isLlmEnabledFor(env, "clinical_report")).toBe(false);
    expect(isLlmEnabledFor(env, "parent_summary")).toBe(false);
  });

  it("defaults to prep_brief ONLY when LLM_ENABLED_KINDS is unset", () => {
    const env = envWith({ INFERENCE_OPENAI_BASE_URL: "https://example/v1" });
    expect(isLlmEnabledFor(env, "prep_brief")).toBe(true);
    expect(isLlmEnabledFor(env, "session_plan")).toBe(false);
    expect(isLlmEnabledFor(env, "clinical_report")).toBe(false);
    expect(isLlmEnabledFor(env, "parent_summary")).toBe(false);
  });

  it("respects a comma-separated explicit allowlist", () => {
    const env = envWith({
      INFERENCE_OPENAI_BASE_URL: "https://example/v1",
      LLM_ENABLED_KINDS: "session_plan, parent_summary",
    });
    expect(isLlmEnabledFor(env, "prep_brief")).toBe(false);
    expect(isLlmEnabledFor(env, "session_plan")).toBe(true);
    expect(isLlmEnabledFor(env, "clinical_report")).toBe(false);
    expect(isLlmEnabledFor(env, "parent_summary")).toBe(true);
  });

  it("treats `*` as all kinds enabled", () => {
    const env = envWith({
      INFERENCE_OPENAI_BASE_URL: "https://example/v1",
      LLM_ENABLED_KINDS: "*",
    });
    for (const k of ["prep_brief", "session_plan", "clinical_report", "parent_summary"] as const) {
      expect(isLlmEnabledFor(env, k)).toBe(true);
    }
  });

  it("treats `all` (case-insensitive) as all kinds enabled", () => {
    const env = envWith({
      INFERENCE_OPENAI_BASE_URL: "https://example/v1",
      LLM_ENABLED_KINDS: "ALL",
    });
    expect(isLlmEnabledFor(env, "prep_brief")).toBe(true);
    expect(isLlmEnabledFor(env, "session_plan")).toBe(true);
  });

  it("ignores whitespace + casing in the allowlist", () => {
    const env = envWith({
      INFERENCE_OPENAI_BASE_URL: "https://example/v1",
      LLM_ENABLED_KINDS: " PREP_BRIEF ,session_plan",
    });
    expect(isLlmEnabledFor(env, "prep_brief")).toBe(true);
    expect(isLlmEnabledFor(env, "session_plan")).toBe(true);
    expect(isLlmEnabledFor(env, "clinical_report")).toBe(false);
  });
});
