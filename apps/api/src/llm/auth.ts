import type { Env } from "../config.js";

/** Bearer token for OpenAI-compatible inference (vLLM private or Vertex endpoint). */
export async function resolveLlmAuthorization(env: Env): Promise<string | undefined> {
  if (env.LLM_API_KEY) {
    return `Bearer ${env.LLM_API_KEY}`;
  }

  const base = env.INFERENCE_OPENAI_BASE_URL ?? "";
  if (!base.includes("googleapis.com")) {
    return undefined;
  }

  try {
    const { GoogleAuth } = await import("google-auth-library");
    const auth = new GoogleAuth({
      scopes: ["https://www.googleapis.com/auth/cloud-platform"],
    });
    const client = await auth.getClient();
    const token = await client.getAccessToken();
    if (token.token) return `Bearer ${token.token}`;
  } catch (err) {
    console.warn("LLM Google ADC auth failed:", err);
  }
  return undefined;
}
