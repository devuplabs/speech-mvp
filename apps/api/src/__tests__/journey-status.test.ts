import { describe, expect, it } from "vitest";
import { statusAfterConsultBooked } from "../services/consult-booking.js";
import { statusAfterCarryoverResource } from "../services/carryover.js";

describe("statusAfterConsultBooked (DEV-10 Stage 5)", () => {
  it("advances a prep-ready case to consult_booked", () => {
    expect(statusAfterConsultBooked("prep_ready")).toBe("consult_booked");
  });

  it("advances a prep-drafting case to consult_booked", () => {
    expect(statusAfterConsultBooked("prep_drafting")).toBe("consult_booked");
  });

  it("does not skip intake — a booking at registration leaves intake_pending alone", () => {
    expect(statusAfterConsultBooked("intake_pending")).toBeNull();
    expect(statusAfterConsultBooked("intake_submitted")).toBeNull();
  });

  it("never rewinds a case that has already progressed past prep", () => {
    expect(statusAfterConsultBooked("consult_booked")).toBeNull();
    expect(statusAfterConsultBooked("triaged")).toBeNull();
    expect(statusAfterConsultBooked("plan_drafting")).toBeNull();
    expect(statusAfterConsultBooked("plan_ready")).toBeNull();
    expect(statusAfterConsultBooked("summary_sent")).toBeNull();
    expect(statusAfterConsultBooked("carryover")).toBeNull();
  });

  it("ignores unknown statuses", () => {
    expect(statusAfterConsultBooked("archived")).toBeNull();
    expect(statusAfterConsultBooked("")).toBeNull();
  });
});

describe("statusAfterCarryoverResource (DEV-10 Stage 9)", () => {
  it("advances to carryover when the first resource is shared after the summary", () => {
    expect(statusAfterCarryoverResource("summary_sent")).toBe("carryover");
  });

  it("does not start carryover before the summary has been sent", () => {
    expect(statusAfterCarryoverResource("intake_pending")).toBeNull();
    expect(statusAfterCarryoverResource("intake_submitted")).toBeNull();
    expect(statusAfterCarryoverResource("prep_ready")).toBeNull();
    expect(statusAfterCarryoverResource("consult_booked")).toBeNull();
    expect(statusAfterCarryoverResource("triaged")).toBeNull();
    expect(statusAfterCarryoverResource("plan_ready")).toBeNull();
  });

  it("never rewinds a case already in carryover (idempotent on re-share)", () => {
    expect(statusAfterCarryoverResource("carryover")).toBeNull();
  });

  it("ignores unknown statuses", () => {
    expect(statusAfterCarryoverResource("archived")).toBeNull();
    expect(statusAfterCarryoverResource("")).toBeNull();
  });
});
