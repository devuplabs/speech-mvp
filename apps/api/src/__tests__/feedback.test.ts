import { describe, expect, it } from "vitest";
import type { Db } from "../db/client.js";
import { submitFeedbackBody } from "../schemas/feedback.js";
import { recordFeedback } from "../services/feedback.js";

describe("submitFeedbackBody (DEV-55)", () => {
  it("accepts a minimal valid submission", () => {
    const parsed = submitFeedbackBody.parse({ type: "idea", comment: "Nice flow" });
    expect(parsed.type).toBe("idea");
    expect(parsed.comment).toBe("Nice flow");
  });

  it("trims and rejects an empty comment", () => {
    expect(() => submitFeedbackBody.parse({ type: "bug", comment: "   " })).toThrow();
  });

  it("rejects an unknown feedback type", () => {
    expect(() =>
      submitFeedbackBody.parse({ type: "rant", comment: "x" }),
    ).toThrow();
  });

  it("rejects an over-long comment", () => {
    expect(() =>
      submitFeedbackBody.parse({ type: "bug", comment: "x".repeat(4001) }),
    ).toThrow();
  });

  it("rejects a non-uuid tenantId", () => {
    expect(() =>
      submitFeedbackBody.parse({ type: "bug", comment: "x", tenantId: "not-a-uuid" }),
    ).toThrow();
  });
});

describe("recordFeedback (DEV-55) — PHI safety", () => {
  function makeCapturingDb(captured: Record<string, unknown>[]): Db {
    return {
      insert() {
        return {
          values(v: Record<string, unknown>) {
            captured.push(v);
            return {
              returning() {
                return Promise.resolve([{ id: "fb-test-id" }]);
              },
            };
          },
        };
      },
    } as unknown as Db;
  }

  it("stores only allowlisted, non-PHI columns", async () => {
    const captured: Record<string, unknown>[] = [];
    const db = makeCapturingDb(captured);

    const { id } = await recordFeedback(db, {
      type: "bug",
      comment: "Triage button did nothing",
      severity: "annoying",
      route: "clinicianTriage",
      role: "clinician",
      journeyStage: "triage",
      buildSha: "abc1234",
      appEnv: "dev",
      viewport: "1280x800",
      locale: "en-GB",
      requestId: "req-1",
      userAgent: "Mozilla/5.0",
    });

    expect(id).toBe("fb-test-id");

    const row = captured[0]!;
    expect(row.feedbackType).toBe("bug");
    expect(row.comment).toBe("Triage button did nothing");
    expect(row.route).toBe("clinicianTriage");

    // No PHI-shaped fields may ever reach the feedback row.
    const forbidden = ["name", "email", "dob", "birth", "answers", "token", "child", "parent"];
    for (const key of Object.keys(row)) {
      for (const bad of forbidden) {
        expect(key.toLowerCase().includes(bad), `column "${key}" looks PHI-shaped`).toBe(false);
      }
    }
  });
});
