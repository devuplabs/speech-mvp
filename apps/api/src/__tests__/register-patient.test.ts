import { describe, expect, it } from "vitest";
import { registerPatientBody } from "../schemas/register-patient.js";
import {
  buildIntakeLinkUrl,
  resolveIntakeLinkState,
} from "../services/register-patient.js";

describe("registerPatientBody", () => {
  it("rejects invalid email", () => {
    const result = registerPatientBody.safeParse({
      tenantId: "550e8400-e29b-41d4-a716-446655440000",
      childFirstName: "Aria",
      dateOfBirth: "15 / 03 / 2019",
      parentName: "Parent",
      parentEmail: "not-an-email",
      referralSource: "nhs",
      sendIntakeLink: true,
    });
    expect(result.success).toBe(false);
  });

  it("accepts valid registration payload", () => {
    const result = registerPatientBody.safeParse({
      tenantId: "550e8400-e29b-41d4-a716-446655440000",
      childFirstName: "Aria",
      dateOfBirth: "15 / 03 / 2019",
      parentName: "Anna M.",
      parentEmail: "parent@example.com",
      referralSource: "school",
      sendIntakeLink: true,
    });
    expect(result.success).toBe(true);
  });
});

describe("buildIntakeLinkUrl", () => {
  it("embeds token in parent web URL", () => {
    const url = buildIntakeLinkUrl("http://localhost:8080", "abc123");
    expect(url).toBe("http://localhost:8080/?t=abc123");
  });
});

describe("resolveIntakeLinkState", () => {
  const now = new Date("2026-06-12T10:00:00Z");
  const future = new Date("2026-06-20T10:00:00Z");
  const past = new Date("2026-06-01T10:00:00Z");

  it("rejects unknown links (malformed or never issued tokens)", () => {
    expect(resolveIntakeLinkState(null, now)).toEqual({ ok: false, error: "not_found" });
    expect(resolveIntakeLinkState(undefined, now)).toEqual({
      ok: false,
      error: "not_found",
    });
  });

  it("rejects expired links", () => {
    expect(resolveIntakeLinkState({ expiresAt: past }, now)).toEqual({
      ok: false,
      error: "expired",
    });
  });

  it("rejects links exactly at expiry (revoke sets expiresAt = now)", () => {
    expect(resolveIntakeLinkState({ expiresAt: now }, now)).toEqual({
      ok: false,
      error: "expired",
    });
  });

  it("accepts live links", () => {
    expect(resolveIntakeLinkState({ expiresAt: future }, now)).toEqual({ ok: true });
  });
});
