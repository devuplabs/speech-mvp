import { describe, expect, it } from "vitest";
import { availabilityRuleSchema, bookConsultBody } from "../schemas/booking.js";

/** DEV-79 — availability/booking input validation & boundary gaps. */
describe("availabilityRuleSchema", () => {
  const base = { weekday: 1, startMinuteLocal: 9 * 60, endMinuteLocal: 17 * 60 };

  it("accepts a normal window", () => {
    expect(availabilityRuleSchema.safeParse(base).success).toBe(true);
  });

  it("rejects inverted windows (start > end)", () => {
    expect(
      availabilityRuleSchema.safeParse({ ...base, startMinuteLocal: 17 * 60, endMinuteLocal: 9 * 60 })
        .success,
    ).toBe(false);
  });

  it("rejects zero-width windows (start == end)", () => {
    expect(
      availabilityRuleSchema.safeParse({ ...base, startMinuteLocal: 600, endMinuteLocal: 600 }).success,
    ).toBe(false);
  });

  it("allows an end-of-day window (endMinuteLocal = 1440)", () => {
    expect(
      availabilityRuleSchema.safeParse({ ...base, startMinuteLocal: 1320, endMinuteLocal: 1440 }).success,
    ).toBe(true);
  });
});

describe("bookConsultBody", () => {
  it("rejects a start in the past", () => {
    expect(bookConsultBody.safeParse({ start: "2020-01-01T10:00:00.000Z" }).success).toBe(false);
  });

  it("accepts a future start", () => {
    const future = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();
    expect(bookConsultBody.safeParse({ start: future }).success).toBe(true);
  });
});
