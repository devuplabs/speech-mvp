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
    const res = await fetch(`${this.env.INFERENCE_OPENAI_BASE_URL}/v1/models`, {
      signal: AbortSignal.timeout(5000),
    });
    return { ok: res.ok, reason: res.ok ? undefined : `HTTP ${res.status}` };
  }
}
