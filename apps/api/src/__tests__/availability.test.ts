import { describe, expect, it } from "vitest";
import { computeSlotsFromRules, getZonedParts } from "../services/availability.js";

describe("getZonedParts", () => {
  it("maps Monday in Europe/London", () => {
    // 2026-05-25 is a Monday 12:00 UTC (BST): local 13:00
    const d = new Date("2026-05-25T12:00:00.000Z");
    const parts = getZonedParts(d, "Europe/London");
    expect(parts.weekday).toBe(1);
    expect(parts.minuteOfDay).toBeGreaterThan(0);
  });
});

describe("computeSlotsFromRules", () => {
  it("marks booked slot unavailable", () => {
    const from = new Date("2026-05-26T08:00:00.000Z");
    const to = new Date("2026-05-26T18:00:00.000Z");
    const rules = [
      {
        weekday: 2,
        startMinuteLocal: 9 * 60,
        endMinuteLocal: 17 * 60,
        timezone: "Europe/London",
        active: true,
      },
    ];
    const slots = computeSlotsFromRules(rules, from, to, []);
    expect(slots.length).toBeGreaterThan(0);
    const first = slots[0]!;
    const booked = computeSlotsFromRules(rules, from, to, [new Date(first.start)]);
    const same = booked.find((s) => s.start === first.start);
    expect(same?.available).toBe(false);
  });
});
