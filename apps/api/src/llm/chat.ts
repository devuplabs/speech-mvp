import type { Env } from "../config.js";
import { resolveLlmAuthorization } from "./auth.js";

export type ChatMessage = {
  role: "system" | "user" | "assistant";
  content: string;
};

export type ChatCompletionOptions = {
  env: Env;
  messages: ChatMessage[];
  jsonMode?: boolean;
  maxTokens?: number;
  temperature?: number;
};

export function isLlmConfigured(env: Env): boolean {
  return Boolean(env.INFERENCE_OPENAI_BASE_URL?.trim());
}

/** AI draft kinds the operator allows the LLM to generate. Anything else
 * falls back to the deterministic stub regardless of LLM availability —
 * used to roll AI artifacts out one at a time (prep brief first per the
 * "first AI loop" plan). Default: `prep_brief` only. */
export type LlmKind =
  | "prep_brief"
  | "session_plan"
  | "clinical_report"
  | "parent_summary";

const DEFAULT_ENABLED_KINDS: ReadonlySet<LlmKind> = new Set(["prep_brief"]);

export function isLlmEnabledFor(env: Env, kind: LlmKind): boolean {
  if (!isLlmConfigured(env)) return false;
  const raw = env.LLM_ENABLED_KINDS?.trim();
  if (!raw) return DEFAULT_ENABLED_KINDS.has(kind);
  if (raw === "*" || raw.toLowerCase() === "all") return true;
  const allowed = new Set(
    raw
      .split(",")
      .map((s) => s.trim().toLowerCase())
      .filter(Boolean),
  );
  return allowed.has(kind);
}

/**
 * Build the chat-completions URL for an OpenAI-compatible base.
 *
 * Handles three deployment shapes:
 *   - Vertex AI:  `…/endpoints/openapi`               → append `/chat/completions`.
 *   - vLLM / OpenAI: `…/v1`                            → append `/chat/completions`.
 *   - Bare host: `https://host[:port]`                 → append `/v1/chat/completions`.
 *
 * Exported for unit testing.
 */
export function buildChatCompletionsUrl(base: string): string {
  const trimmed = base.replace(/\/$/, "");
  if (/\/(openapi|v1)$/.test(trimmed)) {
    return `${trimmed}/chat/completions`;
  }
  return `${trimmed}/v1/chat/completions`;
}

export async function chatCompletion(
  options: ChatCompletionOptions,
): Promise<{ ok: true; content: string } | { ok: false; reason: string }> {
  const base = options.env.INFERENCE_OPENAI_BASE_URL?.replace(/\/$/, "");
  if (!base) {
    return { ok: false, reason: "INFERENCE_OPENAI_BASE_URL not set" };
  }

  const model = options.env.LLM_MODEL ?? "google/gemma-3-27b-it";
  const auth = await resolveLlmAuthorization(options.env);
  const url = buildChatCompletionsUrl(base);

  const startedAt = Date.now();
  let outcome: "ok" | "http" | "empty" | "network" | "timeout" = "ok";
  let httpStatus: number | null = null;

  try {
    const res = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        ...(auth ? { Authorization: auth } : {}),
      },
      body: JSON.stringify({
        model,
        messages: options.messages,
        max_tokens: options.maxTokens ?? 1200,
        temperature: options.temperature ?? 0.4,
        ...(options.jsonMode ? { response_format: { type: "json_object" } } : {}),
      }),
      signal: AbortSignal.timeout(90_000),
    });
    httpStatus = res.status;

    if (!res.ok) {
      outcome = "http";
      const text = await res.text().catch(() => "");
      logLlmCall({ model, host: hostOf(url), latencyMs: Date.now() - startedAt, outcome, httpStatus });
      return { ok: false, reason: `LLM HTTP ${res.status}: ${text.slice(0, 200)}` };
    }

    const data = (await res.json()) as {
      choices?: { message?: { content?: string } }[];
    };
    const content = data.choices?.[0]?.message?.content;
    if (!content) {
      outcome = "empty";
      logLlmCall({ model, host: hostOf(url), latencyMs: Date.now() - startedAt, outcome, httpStatus });
      return { ok: false, reason: "empty LLM response" };
    }
    logLlmCall({ model, host: hostOf(url), latencyMs: Date.now() - startedAt, outcome, httpStatus });
    return { ok: true, content };
  } catch (err) {
    outcome = err instanceof DOMException && err.name === "TimeoutError" ? "timeout" : "network";
    logLlmCall({ model, host: hostOf(url), latencyMs: Date.now() - startedAt, outcome, httpStatus });
    return { ok: false, reason: `LLM ${outcome}: ${(err as Error).message}` };
  }
}

/** PHI-free structured log line — only metadata, never prompt or completion content. */
function logLlmCall(fields: {
  model: string;
  host: string;
  latencyMs: number;
  outcome: string;
  httpStatus: number | null;
}): void {
  console.log(
    JSON.stringify({
      event: "llm.call",
      ...fields,
    }),
  );
}

function hostOf(url: string): string {
  try {
    return new URL(url).host;
  } catch {
    return "unknown";
  }
}

export function parseJsonFromLlm<T>(raw: string): T | null {
  const trimmed = raw.trim();
  try {
    return JSON.parse(trimmed) as T;
  } catch {
    const start = trimmed.indexOf("{");
    const end = trimmed.lastIndexOf("}");
    if (start >= 0 && end > start) {
      try {
        return JSON.parse(trimmed.slice(start, end + 1)) as T;
      } catch {
        return null;
      }
    }
    return null;
  }
}
