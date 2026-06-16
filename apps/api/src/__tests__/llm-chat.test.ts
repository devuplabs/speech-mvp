import { afterEach, describe, expect, it, vi } from "vitest";
import type { Env } from "../config.js";
import { chatCompletion } from "../llm/chat.js";
import { SelfHostedLlmClient } from "../llm/client.js";

const env = (over: Partial<Env>): Env => ({ ...over }) as Env;

afterEach(() => vi.restoreAllMocks());

describe("chatCompletion malformed JSON (DEV-84)", () => {
  it("returns ok:false instead of throwing on a non-JSON 200 body", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn(async () => new Response("<html>oops</html>", { status: 200 })),
    );
    const res = await chatCompletion({
      env: env({ INFERENCE_OPENAI_BASE_URL: "http://llm/v1" }),
      messages: [{ role: "user", content: "hi" }],
    });
    expect(res).toEqual({ ok: false, reason: "invalid LLM response" });
  });
});

describe("SelfHostedLlmClient.health URL normalization (DEV-84)", () => {
  it("does not double /v1 when the base already ends in /v1 (and strips trailing slash)", async () => {
    const fetchMock = vi.fn(async (..._args: unknown[]) => new Response("{}", { status: 200 }));
    vi.stubGlobal("fetch", fetchMock);
    await new SelfHostedLlmClient(env({ INFERENCE_OPENAI_BASE_URL: "http://llm/v1/" })).health();
    expect(fetchMock.mock.calls[0]?.[0]).toBe("http://llm/v1/models");
  });

  it("appends /v1 when the base lacks it", async () => {
    const fetchMock = vi.fn(async (..._args: unknown[]) => new Response("{}", { status: 200 }));
    vi.stubGlobal("fetch", fetchMock);
    await new SelfHostedLlmClient(env({ INFERENCE_OPENAI_BASE_URL: "http://llm" })).health();
    expect(fetchMock.mock.calls[0]?.[0]).toBe("http://llm/v1/models");
  });
});
