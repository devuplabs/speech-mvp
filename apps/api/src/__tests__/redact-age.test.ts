import { describe, expect, it } from "vitest";
import { dobToAge, parseAgeYears } from "../llm/redact.js";

/**
 * DEV-85 — age derivation must reject calendar-impossible dates rather than let
 * Date.UTC roll them over (Feb 31 → 2 Mar) into a subtly wrong clinical age in
 * LLM prompts. Same lenient-date class as parseIntakeDateToIso (DEV-72).
 */
describe("parseAgeYears calendar validation (DEV-85)", () => {
  const now = new Date("2026-06-16T00:00:00.000Z");

  it("rejects impossible calendar dates", () => {
    expect(parseAgeYears("31/02/2020", now)).toBeNull();
    expect(parseAgeYears("31/04/2020", now)).toBeNull();
    expect(parseAgeYears("2019-02-29", now)).toBeNull(); // 2019 is not a leap year
  });

  it("accepts a valid leap day and computes whole-year age", () => {
    expect(parseAgeYears("29/02/2020", now)).toBe(6);
  });

  it("dobToAge returns null for an impossible date", () => {
    expect(dobToAge("31/02/2020", now)).toBeNull();
    expect(dobToAge("29/02/2020", now)).toBe("6 years");
  });
});
