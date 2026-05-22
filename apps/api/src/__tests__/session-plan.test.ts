import { describe, expect, it } from "vitest";
import { buildStubSessionPlan } from "../services/session-plan.js";

describe("buildStubSessionPlan", () => {
  it("renders DRAFT label + starts as draft reviewStatus", () => {
    const out = buildStubSessionPlan({});
    expect(out.label).toBe("DRAFT — clinician must review");
    expect(out.reviewStatus).toBe("draft");
    expect(out.source).toBe("mvp_stub");
  });

  it("picks the speech-sounds plan for speech-sound concerns", () => {
    const out = buildStubSessionPlan({
      mainConcern: "Speech sound delay; drops final consonants",
      difficulties: ["Speech sounds"],
    });
    expect(out.sections.goals.some((g) => /DEAP/.test(g))).toBe(true);
    expect(
      out.sections.activities.some((a) => /articulation/i.test(a)),
    ).toBe(true);
    expect(out.sections.materials.some((m) => /DEAP/.test(m))).toBe(true);
  });

  it("picks the fluency plan for stutter concerns", () => {
    const out = buildStubSessionPlan({
      mainConcern: "Stuttering since age 4 — worse in class presentations",
    });
    expect(out.sections.goals.some((g) => /syllables stuttered/i.test(g))).toBe(
      true,
    );
    expect(
      out.sections.activities.some((a) => /Easy-onset|breathing/i.test(a)),
    ).toBe(true);
  });

  it("picks the social-communication plan for social-comm difficulties", () => {
    const out = buildStubSessionPlan({
      difficulties: [
        "Maintaining eye contact",
        "Turn taking",
        "Reading between the lines",
      ],
    });
    expect(out.sections.goals.some((g) => /conversation/i.test(g))).toBe(true);
    expect(
      out.sections.materials.some((m) => /Social inference/i.test(m)),
    ).toBe(true);
  });

  it("picks the feeding plan for feeding concerns", () => {
    const out = buildStubSessionPlan({
      mainConcern: "Limited food range, refuses mixed textures",
    });
    expect(out.sections.goals.some((g) => /accepted.*food/i.test(g))).toBe(true);
    expect(out.sections.parentGoals.some((p) => /coercive/i.test(p))).toBe(true);
  });

  it("falls back to general language plan when nothing matches", () => {
    const out = buildStubSessionPlan({ mainConcern: "Unspecified concern" });
    expect(out.sections.goals[0]).toMatch(/Profile receptive/);
  });

  it("adds child involvement goal for school-age children", () => {
    const out = buildStubSessionPlan({
      ageAtReferral: "11",
      difficulties: ["Speech sounds"],
    });
    expect(
      out.sections.goals.some((g) => /child involvement/i.test(g)),
    ).toBe(true);
  });

  it("adds EHCP-coordination parent goal when EHCP is mentioned", () => {
    const out = buildStubSessionPlan({
      senPlan: "EHCP under annual review",
    });
    expect(
      out.sections.parentGoals.some((p) => /EHCP review/i.test(p)),
    ).toBe(true);
  });

  it("is deterministic for the same input", () => {
    const a = buildStubSessionPlan({
      mainConcern: "Speech sound delay",
      difficulties: ["Speech sounds"],
    });
    const b = buildStubSessionPlan({
      mainConcern: "Speech sound delay",
      difficulties: ["Speech sounds"],
    });
    expect(a).toEqual(b);
  });
});
