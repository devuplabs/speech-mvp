import type { Env } from "../config.js";

/** Self-hosted vLLM (OpenAI-compatible). Empty base URL until phase 2 inference is applied. */
export class SelfHostedLlmClient {
  constructor(private readonly env: Env) {}

  get configured(): boolean {
    return Boolean(this.env.INFERENCE_OPENAI_BASE_URL);
  }

  async health(): Promise<{ ok: boolean; reason?: string }> {
    if (!this.env.INFERENCE_OPENAI_BASE_URL) {
      return { ok: false, reason: "INFERENCE_OPENAI_BASE_URL not set (phase 2)" };
    }
    // Normalize the base URL the same way as chat.ts: strip a trailing slash
    // and avoid a doubled /v1 when the configured base already ends in /v1.
    // Otherwise the probe can build …/v1/v1/models or …//v1/models and wrongly
    // report the LLM as down, silently falling back to stub drafts (DEV-84).
    const base = this.env.INFERENCE_OPENAI_BASE_URL.replace(/\/$/, "");
    const url = base.endsWith("/v1") ? `${base}/models` : `${base}/v1/models`;
    const res = await fetch(url, { signal: AbortSignal.timeout(5000) });
    return { ok: res.ok, reason: res.ok ? undefined : `HTTP ${res.status}` };
  }
}
