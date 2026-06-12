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

export async function chatCompletion(
  options: ChatCompletionOptions,
): Promise<{ ok: true; content: string } | { ok: false; reason: string }> {
  const base = options.env.INFERENCE_OPENAI_BASE_URL?.replace(/\/$/, "");
  if (!base) {
    return { ok: false, reason: "INFERENCE_OPENAI_BASE_URL not set" };
  }

  const model = options.env.LLM_MODEL ?? "google/gemma-3-27b-it";
  const auth = await resolveLlmAuthorization(options.env);

  const url = base.endsWith("/v1")
    ? `${base}/chat/completions`
    : `${base}/v1/chat/completions`;

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

  if (!res.ok) {
    // Deliberately drop the response body: inference error bodies can echo
    // the prompt, which contains intake context (PHI). Status only.
    return { ok: false, reason: `LLM HTTP ${res.status}` };
  }

  const data = (await res.json()) as {
    choices?: { message?: { content?: string } }[];
  };
  const content = data.choices?.[0]?.message?.content;
  if (!content) return { ok: false, reason: "empty LLM response" };
  return { ok: true, content };
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
