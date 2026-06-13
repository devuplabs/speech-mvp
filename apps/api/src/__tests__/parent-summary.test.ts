import { describe, expect, it } from "vitest";
import {
  canPublishParentSummary,
  defaultParentSummaryHtml,
} from "../services/parent-summary.js";

describe("canPublishParentSummary", () => {
  it("blocks publishing before the parent has submitted intake", () => {
    expect(canPublishParentSummary("intake_pending")).toBe(false);
  });

  it("blocks publishing before the clinician has triaged", () => {
    expect(canPublishParentSummary("intake_submitted")).toBe(false);
    expect(canPublishParentSummary("prep_drafting")).toBe(false);
    expect(canPublishParentSummary("prep_ready")).toBe(false);
  });

  it("allows publishing once triaged and through plan drafting", () => {
    expect(canPublishParentSummary("triaged")).toBe(true);
    expect(canPublishParentSummary("plan_drafting")).toBe(true);
    expect(canPublishParentSummary("plan_ready")).toBe(true);
  });

  it("allows re-publishing an amended summary", () => {
    expect(canPublishParentSummary("summary_sent")).toBe(true);
  });

  it("allows re-publishing once the case has moved into carryover (DEV-10)", () => {
    expect(canPublishParentSummary("carryover")).toBe(true);
  });

  it("still blocks publishing once a consult is booked but before triage", () => {
    expect(canPublishParentSummary("consult_booked")).toBe(false);
  });

  it("rejects unknown statuses", () => {
    expect(canPublishParentSummary("archived")).toBe(false);
    expect(canPublishParentSummary("")).toBe(false);
  });
});

describe("defaultParentSummaryHtml", () => {
  it("personalises the fallback summary when a child name is known", () => {
    expect(defaultParentSummaryHtml("Aria")).toContain("for Aria");
  });

  it("stays generic without a child name", () => {
    const html = defaultParentSummaryHtml(null);
    expect(html).toContain("Thank you for completing the intake.");
    expect(html).not.toContain("intake for");
  });
});
