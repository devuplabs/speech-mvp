import { describe, expect, it } from "vitest";
import {
  createCarryoverResourceBody,
  createProgressEntryBody,
  updateCarryoverResourceBody,
} from "../schemas/carryover.js";
import {
  newPortalToken,
  portalLinkExpiresAt,
  resolvePortalLinkState,
} from "../services/portal-links.js";

describe("newPortalToken", () => {
  it("produces long url-safe tokens", () => {
    const token = newPortalToken();
    // 32 random bytes base64url-encoded → 43 chars, no padding.
    expect(token).toHaveLength(43);
    expect(token).toMatch(/^[A-Za-z0-9_-]+$/);
  });

  it("never repeats", () => {
    const tokens = new Set(Array.from({ length: 200 }, () => newPortalToken()));
    expect(tokens.size).toBe(200);
  });
});

describe("portalLinkExpiresAt", () => {
  it("expires 90 days out", () => {
    const now = new Date("2026-06-12T10:00:00Z");
    const expires = portalLinkExpiresAt(now);
    const days = (expires.getTime() - now.getTime()) / (24 * 60 * 60 * 1000);
    expect(Math.round(days)).toBe(90);
  });
});

describe("resolvePortalLinkState", () => {
  const now = new Date("2026-06-12T10:00:00Z");
  const future = new Date("2026-07-01T10:00:00Z");
  const past = new Date("2026-06-01T10:00:00Z");

  it("rejects unknown links", () => {
    expect(resolvePortalLinkState(null, now)).toEqual({ ok: false, error: "not_found" });
    expect(resolvePortalLinkState(undefined, now)).toEqual({
      ok: false,
      error: "not_found",
    });
  });

  it("rejects revoked links", () => {
    expect(resolvePortalLinkState({ expiresAt: future, revokedAt: past }, now)).toEqual({
      ok: false,
      error: "revoked",
    });
  });

  it("prefers revoked over expired", () => {
    expect(resolvePortalLinkState({ expiresAt: past, revokedAt: past }, now)).toEqual({
      ok: false,
      error: "revoked",
    });
  });

  it("rejects expired links", () => {
    expect(resolvePortalLinkState({ expiresAt: past, revokedAt: null }, now)).toEqual({
      ok: false,
      error: "expired",
    });
    expect(resolvePortalLinkState({ expiresAt: now, revokedAt: null }, now)).toEqual({
      ok: false,
      error: "expired",
    });
  });

  it("accepts live links", () => {
    expect(resolvePortalLinkState({ expiresAt: future, revokedAt: null }, now)).toEqual({
      ok: true,
    });
  });
});

describe("createCarryoverResourceBody", () => {
  it("accepts a full resource", () => {
    const result = createCarryoverResourceBody.safeParse({
      title: "Daily sound practice",
      description: "Practise /s/ blends for 10 minutes.",
      url: "https://example.com/worksheet",
      category: "home_practice",
    });
    expect(result.success).toBe(true);
  });

  it("rejects a missing title", () => {
    expect(
      createCarryoverResourceBody.safeParse({ category: "reading" }).success,
    ).toBe(false);
    expect(
      createCarryoverResourceBody.safeParse({ title: "  ", category: "reading" }).success,
    ).toBe(false);
  });

  it("rejects an unknown category", () => {
    expect(
      createCarryoverResourceBody.safeParse({ title: "T", category: "homework" }).success,
    ).toBe(false);
  });

  it("rejects a malformed url", () => {
    expect(
      createCarryoverResourceBody.safeParse({
        title: "T",
        category: "other",
        url: "not-a-url",
      }).success,
    ).toBe(false);
  });
});

describe("updateCarryoverResourceBody", () => {
  it("accepts a partial patch", () => {
    expect(updateCarryoverResourceBody.safeParse({ title: "Renamed" }).success).toBe(true);
  });

  it("rejects an empty patch", () => {
    expect(updateCarryoverResourceBody.safeParse({}).success).toBe(false);
  });
});

describe("createProgressEntryBody", () => {
  it("accepts note with optional rating", () => {
    expect(
      createProgressEntryBody.safeParse({ note: "We practised twice." }).success,
    ).toBe(true);
    expect(
      createProgressEntryBody.safeParse({ note: "Going well!", rating: "going_well" })
        .success,
    ).toBe(true);
  });

  it("rejects an empty note", () => {
    expect(createProgressEntryBody.safeParse({ note: "" }).success).toBe(false);
    expect(createProgressEntryBody.safeParse({}).success).toBe(false);
  });

  it("rejects an unknown rating", () => {
    expect(
      createProgressEntryBody.safeParse({ note: "x", rating: "amazing" }).success,
    ).toBe(false);
  });
});
