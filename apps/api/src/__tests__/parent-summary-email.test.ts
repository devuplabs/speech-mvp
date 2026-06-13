import { afterEach, describe, expect, it, vi } from "vitest";
import type { Env } from "../config.js";
import {
  renderFamilySummaryReadyEmail,
  sendFamilySummaryReadyEmail,
} from "../services/email.js";
import { buildPortalUrl } from "../services/portal-links.js";

// PHI that must NEVER appear in a family notification email (notification-only
// policy, ADR-005). Includes child name, clinical content and the raw token.
// Distinct PHI fragments (chosen not to collide with boilerplate like the
// "Arial" font-family) that must NEVER appear in a notification email.
const PHI_FRAGMENTS = [
  "Zephyrine", // child display name
  "stammer", // clinical concern
  "diagnosis",
  "intake answer",
  "speech sound disorder",
];

describe("renderFamilySummaryReadyEmail", () => {
  const input = {
    to: "parent@example.com",
    practiceName: "Whitfield Speech Practice",
    portalUrl: "https://app.sona.dev/?portal=tok-xyz",
  };

  it("uses a PHI-free subject naming only the practice", () => {
    const { subject } = renderFamilySummaryReadyEmail(input);
    expect(subject).toBe("Your summary from Whitfield Speech Practice is ready");
    for (const phi of PHI_FRAGMENTS) expect(subject).not.toContain(phi);
  });

  it("links to the portal and carries no PHI / clinical content", () => {
    const { htmlBody } = renderFamilySummaryReadyEmail(input);
    expect(htmlBody).toContain(input.portalUrl);
    expect(htmlBody).toContain("Whitfield Speech Practice");
    for (const phi of PHI_FRAGMENTS) expect(htmlBody).not.toContain(phi);
    // The summary itself is never inlined — only a link to the authed portal.
    expect(htmlBody).toContain("only inside the portal");
  });

  it("escapes the practice name to prevent HTML injection", () => {
    const { htmlBody } = renderFamilySummaryReadyEmail({
      ...input,
      practiceName: "<script>alert(1)</script>",
    });
    expect(htmlBody).not.toContain("<script>alert(1)</script>");
    expect(htmlBody).toContain("&lt;script&gt;");
  });
});

describe("buildPortalUrl", () => {
  it("builds a ?portal= magic link and trims a trailing slash", () => {
    expect(buildPortalUrl("https://app.sona.dev/", "tok-1")).toBe(
      "https://app.sona.dev/?portal=tok-1",
    );
  });

  it("url-encodes the token", () => {
    expect(buildPortalUrl("https://app.sona.dev", "a/b c")).toBe(
      "https://app.sona.dev/?portal=a%2Fb%20c",
    );
  });
});

describe("sendFamilySummaryReadyEmail", () => {
  afterEach(() => vi.unstubAllGlobals());

  const env = {
    MAILGUN_API_KEY: "key-abc",
    MAILGUN_DOMAIN: "mg.example.com",
    MAILGUN_FROM_EMAIL: "no-reply@example.com",
  } as unknown as Env;

  it("returns email_not_configured when Mailgun is not set up (publish must still succeed)", async () => {
    const res = await sendFamilySummaryReadyEmail({} as unknown as Env, {
      to: "parent@example.com",
      practiceName: "Practice",
      portalUrl: "https://app.sona.dev/?portal=t",
    });
    expect(res).toEqual({ ok: false, error: "email_not_configured" });
  });

  it("posts a PHI-free body to Mailgun and returns the message id", async () => {
    const fetchMock = vi.fn(
      async (_url: string, _init: RequestInit) =>
        new Response(JSON.stringify({ id: "<msg-1>" }), { status: 200 }),
    );
    vi.stubGlobal("fetch", fetchMock);

    const res = await sendFamilySummaryReadyEmail(env, {
      to: "parent@example.com",
      practiceName: "Whitfield Speech Practice",
      portalUrl: "https://app.sona.dev/?portal=tok-xyz",
    });

    expect(res).toEqual({ ok: true, messageId: "<msg-1>" });
    const init = fetchMock.mock.calls[0][1];
    const body = new URLSearchParams(init.body as string);
    const html = body.get("html") ?? "";
    const text = body.get("text") ?? "";
    expect(html).toContain("https://app.sona.dev/?portal=tok-xyz");
    for (const phi of PHI_FRAGMENTS) {
      expect(html).not.toContain(phi);
      expect(text).not.toContain(phi);
    }
  });

  it("surfaces a send failure without throwing (caller treats as best-effort)", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn(
        async () =>
          new Response(JSON.stringify({ message: "Forbidden" }), { status: 401 }),
      ),
    );
    const res = await sendFamilySummaryReadyEmail(env, {
      to: "parent@example.com",
      practiceName: "Practice",
      portalUrl: "https://app.sona.dev/?portal=t",
    });
    expect(res.ok).toBe(false);
  });
});
