import { Hono } from "hono";
import { afterEach, describe, expect, it } from "vitest";
import {
  clientIpFromHeaders,
  createRateLimiter,
} from "../rate-limit.js";
import { setLogSinkForTesting } from "../logger.js";

afterEach(() => setLogSinkForTesting(null));

describe("clientIpFromHeaders", () => {
  it("uses the left-most x-forwarded-for hop (the original client)", () => {
    expect(
      clientIpFromHeaders({ "x-forwarded-for": "203.0.113.5, 35.0.0.1, 130.0.0.2" }),
    ).toBe("203.0.113.5");
  });

  it("falls back to x-real-ip then 'unknown'", () => {
    expect(clientIpFromHeaders({ "x-real-ip": "198.51.100.7" })).toBe("198.51.100.7");
    expect(clientIpFromHeaders({})).toBe("unknown");
  });
});

describe("createRateLimiter.check", () => {
  it("allows up to max then blocks within the window", () => {
    const limiter = createRateLimiter({ max: 3, windowMs: 60_000, name: "test" });
    const t0 = 1_000;
    expect(limiter.check("ip-a", t0).allowed).toBe(true);
    expect(limiter.check("ip-a", t0).allowed).toBe(true);
    expect(limiter.check("ip-a", t0).allowed).toBe(true);
    const blocked = limiter.check("ip-a", t0);
    expect(blocked.allowed).toBe(false);
    expect(blocked.retryAfterSeconds).toBeGreaterThan(0);
  });

  it("isolates buckets per IP", () => {
    const limiter = createRateLimiter({ max: 1, windowMs: 60_000, name: "test" });
    expect(limiter.check("ip-a", 0).allowed).toBe(true);
    expect(limiter.check("ip-a", 0).allowed).toBe(false);
    // A different IP is unaffected.
    expect(limiter.check("ip-b", 0).allowed).toBe(true);
  });

  it("resets after the window elapses", () => {
    const limiter = createRateLimiter({ max: 1, windowMs: 1_000, name: "test" });
    expect(limiter.check("ip-a", 0).allowed).toBe(true);
    expect(limiter.check("ip-a", 500).allowed).toBe(false);
    // Window rolled over.
    expect(limiter.check("ip-a", 1_500).allowed).toBe(true);
  });
});

describe("rate-limit middleware", () => {
  it("returns 429 with a clear body and Retry-After once the limit is exceeded", async () => {
    setLogSinkForTesting(() => {}); // silence the rate_limit.exceeded warn
    const limiter = createRateLimiter({ max: 2, windowMs: 60_000, name: "token_endpoint" });
    const app = new Hono();
    app.use("/portal/:token", limiter.middleware);
    app.get("/portal/:token", (c) => c.json({ ok: true }));

    const hit = () =>
      app.request("/portal/abc", {
        headers: { "x-forwarded-for": "203.0.113.9" },
      });

    expect((await hit()).status).toBe(200);
    expect((await hit()).status).toBe(200);

    const limited = await hit();
    expect(limited.status).toBe(429);
    expect(limited.headers.get("Retry-After")).toBeTruthy();
    const body = await limited.json();
    expect(body.error).toBe("rate_limited");
    expect(typeof body.retryAfterSeconds).toBe("number");
  });

  it("limits each IP independently in the middleware path", async () => {
    setLogSinkForTesting(() => {});
    const limiter = createRateLimiter({ max: 1, windowMs: 60_000, name: "token_endpoint" });
    const app = new Hono();
    app.use("/portal/:token", limiter.middleware);
    app.get("/portal/:token", (c) => c.json({ ok: true }));

    const req = (ip: string) =>
      app.request("/portal/abc", { headers: { "x-forwarded-for": ip } });

    expect((await req("1.1.1.1")).status).toBe(200);
    expect((await req("1.1.1.1")).status).toBe(429);
    // Distinct client still served.
    expect((await req("2.2.2.2")).status).toBe(200);
  });
});
