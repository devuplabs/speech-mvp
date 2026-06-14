import { describe, expect, it } from "vitest";
import {
  AUDIT_RETENTION_YEARS,
  auditRetentionCutoff,
} from "../services/audit-retention.js";

describe("auditRetentionCutoff", () => {
  it("is 7 years before now", () => {
    expect(AUDIT_RETENTION_YEARS).toBe(7);
    const now = new Date("2026-06-14T12:00:00.000Z");
    const cutoff = auditRetentionCutoff(now);
    expect(cutoff.toISOString()).toBe("2019-06-14T12:00:00.000Z");
  });

  it("handles a leap-day origin without throwing", () => {
    const now = new Date("2028-02-29T00:00:00.000Z");
    const cutoff = auditRetentionCutoff(now);
    // 7 years before 2028-02-29 (2021 is not a leap year) normalises to Mar 1.
    expect(cutoff.getUTCFullYear()).toBe(2021);
  });
});
