import { describe, expect, it } from "vitest";
import { registerPatientBody } from "../schemas/register-patient.js";
import {
  buildIntakeLinkUrl,
  parseIntakeDateToIso,
  resolveIntakeLinkState,
  splitFullName,
} from "../services/register-patient.js";
import { deriveDemographicsFromAnswers } from "../services/intake.js";

describe("parseIntakeDateToIso (DEV-27 FHIR demographics)", () => {
  it("parses dd / mm / yyyy to ISO YYYY-MM-DD", () => {
    expect(parseIntakeDateToIso("15 / 03 / 2019")).toBe("2019-03-15");
    expect(parseIntakeDateToIso("01/12/2020")).toBe("2020-12-01");
  });
  it("returns undefined for malformed or absent input rather than guessing", () => {
    expect(parseIntakeDateToIso(undefined)).toBeUndefined();
    expect(parseIntakeDateToIso("")).toBeUndefined();
    expect(parseIntakeDateToIso("2019-03-15")).toBeUndefined();
    expect(parseIntakeDateToIso("32 / 01 / 2019")).toBeUndefined();
  });
  it("rejects calendar-impossible dates the format regex would otherwise pass (DEV-72)", () => {
    expect(parseIntakeDateToIso("31/02/2025")).toBeUndefined();
    expect(parseIntakeDateToIso("30/02/2025")).toBeUndefined();
    expect(parseIntakeDateToIso("31/04/2025")).toBeUndefined();
    // 2019 is not a leap year, so 29 Feb does not exist.
    expect(parseIntakeDateToIso("29/02/2019")).toBeUndefined();
  });
  it("accepts a valid leap day", () => {
    expect(parseIntakeDateToIso("29/02/2020")).toBe("2020-02-29");
  });
});

describe("splitFullName (DEV-27 FHIR HumanName)", () => {
  it("splits the last token as family, the rest as given", () => {
    expect(splitFullName("Ada Lovelace")).toEqual({ given: "Ada", family: "Lovelace" });
    expect(splitFullName("Mary Anne Lovelace")).toEqual({
      given: "Mary Anne",
      family: "Lovelace",
    });
  });
  it("treats a single token as given only (no fabricated family)", () => {
    expect(splitFullName("Ada")).toEqual({ given: "Ada" });
  });
  it("returns empty parts for empty input", () => {
    expect(splitFullName(undefined)).toEqual({});
    expect(splitFullName("  ")).toEqual({});
  });
});

describe("deriveDemographicsFromAnswers (DEV-27)", () => {
  it("derives structured child/parent name and DOB; omits absent fields", () => {
    const result = deriveDemographicsFromAnswers({
      version: 1,
      childName: "Ada Lovelace",
      dateOfBirth: "10 / 12 / 2019",
      motherName: "Mary Lovelace",
    });
    expect(result.childGivenName).toBe("Ada");
    expect(result.childFamilyName).toBe("Lovelace");
    expect(result.childDob).toBe("2019-12-10");
    expect(result.parentGivenName).toBe("Mary");
    expect(result.parentFamilyName).toBe("Lovelace");
  });
  it("falls back to father then completedBy for the parent contact", () => {
    expect(deriveDemographicsFromAnswers({ version: 1, fatherName: "Tom Smith" }))
      .toMatchObject({ parentGivenName: "Tom", parentFamilyName: "Smith" });
    expect(deriveDemographicsFromAnswers({ version: 1, completedBy: "Jo Bloggs" }))
      .toMatchObject({ parentGivenName: "Jo", parentFamilyName: "Bloggs" });
  });
});

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
