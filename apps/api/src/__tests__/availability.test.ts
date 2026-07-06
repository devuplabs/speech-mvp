import { describe, expect, it } from "vitest";
import {
  computeSlotsFromRules,
  dropAlreadyStartedSlots,
  getZonedParts,
  MIN_BOOKING_LEAD_TIME_MS,
} from "../services/availability.js";

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

describe("dropAlreadyStartedSlots", () => {
  const rules = [
    {
      weekday: 2,
      startMinuteLocal: 9 * 60,
      endMinuteLocal: 17 * 60,
      timezone: "Europe/London",
      active: true,
    },
  ];

  it("never offers the at-'now' slot the booking schema would reject", () => {
    // Grid anchored at `from` ⇒ first slot starts exactly at `from`. When the
    // caller anchors at "now" inside an open window, that slot is already in
    // the past by the time a booking POST lands (the Thursday-evening flake).
    const from = new Date("2026-05-26T10:00:00.000Z"); // Tuesday, in-window
    const to = new Date("2026-05-26T16:00:00.000Z");
    const slots = computeSlotsFromRules(rules, from, to, []);
    expect(slots[0]!.start).toBe(from.toISOString());

    const offered = dropAlreadyStartedSlots(slots, from.getTime());
    expect(offered.length).toBe(slots.length - 1);
    expect(offered[0]!.start).not.toBe(from.toISOString());
    for (const s of offered) {
      expect(Date.parse(s.start)).toBeGreaterThan(from.getTime());
    }
  });

  it("is a no-op without a cutoff (bookConsult re-validation path)", () => {
    const from = new Date("2026-05-26T10:00:00.000Z");
    const to = new Date("2026-05-26T16:00:00.000Z");
    const slots = computeSlotsFromRules(rules, from, to, []);
    expect(dropAlreadyStartedSlots(slots, undefined)).toEqual(slots);
  });

  it("drops slots inside the booking lead-time margin, not just the at-'now' one (the Thursday-evening flake)", () => {
    // The grid's *second* slot (one SLOT_STEP_MINUTES out) used to be treated
    // as a safe margin (DEV-79). A `minStartMs` that already includes the
    // lead-time buffer (as the route now passes) must push past that slot
    // too, since a real booking POST can arrive after enough of that margin
    // has elapsed.
    const from = new Date("2026-05-26T10:00:00.000Z"); // Tuesday, in-window
    const to = new Date("2026-05-26T16:00:00.000Z");
    const slots = computeSlotsFromRules(rules, from, to, []);

    // Without the margin, the very next grid slot is offered.
    const bareNowOffered = dropAlreadyStartedSlots(slots, from.getTime());
    expect(bareNowOffered[0]!.start).toBe(slots[1]!.start);

    // With the margin included in minStartMs (as the route does), that same
    // slot is no longer far enough out and gets dropped too.
    const withMargin = from.getTime() + MIN_BOOKING_LEAD_TIME_MS;
    const offered = dropAlreadyStartedSlots(slots, withMargin);
    expect(offered[0]!.start).not.toBe(slots[1]!.start);
    for (const s of offered) {
      expect(Date.parse(s.start) - from.getTime()).toBeGreaterThan(MIN_BOOKING_LEAD_TIME_MS);
    }
  });
});
