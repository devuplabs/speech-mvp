import { describe, expect, it } from "vitest";
import { newErasureToken } from "../services/dsar.js";
import { PHI_REGISTRY } from "../services/phi-registry.js";

describe("newErasureToken", () => {
  it("produces long url-safe tokens", () => {
    const token = newErasureToken();
    // 24 random bytes base64url-encoded → 32 chars, no padding.
    expect(token).toHaveLength(32);
    expect(token).toMatch(/^[A-Za-z0-9_-]+$/);
  });

  it("never repeats", () => {
    const tokens = new Set(Array.from({ length: 200 }, () => newErasureToken()));
    expect(tokens.size).toBe(200);
  });
});

describe("DSAR export coverage (registry-driven)", () => {
  it("exports every case-scoped PHI section and excludes practice tables", () => {
    const exportedKeys = PHI_REGISTRY.filter(
      (e) => e.classification !== "practice_excluded",
    ).map((e) => e.key);

    // The subject's case data, intake, triage, drafts, carryover, progress,
    // access-credential links and the audit trail must all be exportable.
    for (const key of [
      "case",
      "intakeSubmissions",
      "triageRecords",
      "aiDrafts",
      "carryoverResources",
      "progressEntries",
      "caseIntakeLinks",
      "casePortalLinks",
      "auditLog",
    ]) {
      expect(exportedKeys, `${key} must be exported`).toContain(key);
    }

    const excluded = PHI_REGISTRY.filter(
      (e) => e.classification === "practice_excluded",
    ).map((e) => e.key);
    expect(excluded).toEqual(
      expect.arrayContaining(["tenants", "users", "clinicianAvailability"]),
    );
  });
});
