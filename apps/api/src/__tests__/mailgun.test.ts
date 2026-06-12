import { afterEach, describe, expect, it, vi } from "vitest";
import { sendMailgunEmail } from "../services/mailgun.js";

describe("sendMailgunEmail", () => {
  afterEach(() => vi.unstubAllGlobals());

  it("posts form-encoded mail with basic auth and returns the message id", async () => {
    const fetchMock = vi.fn(
      async (_url: string, _init: RequestInit) =>
        new Response(JSON.stringify({ id: "<msg-1>", message: "Queued" }), {
          status: 200,
          headers: { "content-type": "application/json" },
        }),
    );
    vi.stubGlobal("fetch", fetchMock);

    const res = await sendMailgunEmail({
      apiKey: "key-abc",
      domain: "mg.example.com",
      from: "no-reply@example.com",
      to: "james@wsl.co.uk",
      subject: "Hi",
      htmlBody: "<p>Hello</p>",
    });

    expect(res).toEqual({ ok: true, messageId: "<msg-1>" });
    const [url, init] = fetchMock.mock.calls[0];
    expect(url).toBe("https://api.mailgun.net/v3/mg.example.com/messages");
    expect((init.headers as Record<string, string>).Authorization).toBe(
      `Basic ${Buffer.from("api:key-abc").toString("base64")}`,
    );
    const body = new URLSearchParams(init.body as string);
    expect(body.get("from")).toBe("no-reply@example.com");
    expect(body.get("html")).toBe("<p>Hello</p>");
    expect(body.get("text")).toBe("Hello");
  });

  it("honours the EU base-url override", async () => {
    const fetchMock = vi.fn(
      async (_url: string, _init: RequestInit) =>
        new Response(JSON.stringify({ id: "x" }), { status: 200 }),
    );
    vi.stubGlobal("fetch", fetchMock);

    await sendMailgunEmail({
      apiKey: "k",
      domain: "d",
      baseUrl: "https://api.eu.mailgun.net",
      from: "a@b.co",
      to: "x@y.co",
      subject: "s",
      htmlBody: "h",
    });

    expect(fetchMock.mock.calls[0][0]).toBe(
      "https://api.eu.mailgun.net/v3/d/messages",
    );
  });

  it("returns an error on a non-2xx response", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn(
        async () =>
          new Response(JSON.stringify({ message: "Forbidden" }), {
            status: 401,
          }),
      ),
    );

    const res = await sendMailgunEmail({
      apiKey: "k",
      domain: "d",
      from: "a@b.co",
      to: "x@y.co",
      subject: "s",
      htmlBody: "h",
    });

    expect(res.ok).toBe(false);
    if (!res.ok) {
      expect(res.status).toBe(401);
      expect(res.error).toBe("Forbidden");
    }
  });
});
