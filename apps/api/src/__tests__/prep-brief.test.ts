import { describe, expect, it } from "vitest";
import { buildStubPrepBrief } from "../services/prep-brief.js";

describe("buildStubPrepBrief", () => {
  it("renders the DRAFT clinician-review label on every output", () => {
    const out = buildStubPrepBrief({}, null);
    expect(out.label).toBe("DRAFT — clinician must review");
  });

  it("derives child snapshot from intake answers", () => {
    const out = buildStubPrepBrief(
      {
        childName: "Aria M.",
        mainConcern:
          "Hard to understand at nursery — drops final consonants and some sounds replaced.",
        difficulties: ["Speech sounds", "Staying on task"],
        ageAtReferral: "4",
        senPlan: "No EHCP; on SENCO monitor",
      },
      "Aria M.",
    );
    expect(out.childSnapshot.displayName).toBe("Aria M.");
    expect(out.childSnapshot.ageAtReferral).toBe("4");
    expect(out.childSnapshot.difficulties).toEqual([
      "Speech sounds",
      "Staying on task",
    ]);
    expect(out.childSnapshot.mainConcern).toMatch(/Hard to understand/);
  });

  it("starts probe areas with the parent's primary concern, quoted", () => {
    const out = buildStubPrepBrief(
      { mainConcern: "Stuttering since age 4." },
      "Jaden",
    );
    expect(out.probeAreas[0]).toContain('"Stuttering since age 4."');
  });

  it("samples top 3 difficulties as a probe area", () => {
    const out = buildStubPrepBrief(
      {
        difficulties: [
          "Speech sounds",
          "Staying on task",
          "Sharing",
          "Turn taking",
        ],
      },
      null,
    );
    const probe = out.probeAreas.find((p) =>
      p.includes("Sample top difficulties"),
    );
    expect(probe).toBeDefined();
    expect(probe).toContain("Speech sounds");
    expect(probe).toContain("Sharing");
    expect(probe).not.toContain("Turn taking"); // capped at 3
  });

  it("adds family history probe when parent flagged yes", () => {
    const out = buildStubPrepBrief(
      {
        familyHistory: "yes",
        familyHistoryDetails: "Paternal uncle stutters",
      },
      null,
    );
    expect(out.probeAreas.some((p) => /family history/i.test(p))).toBe(true);
  });

  it("adds therapy / prior-assessment probes when parent flagged yes", () => {
    const out = buildStubPrepBrief(
      {
        receivingTherapy: "yes",
        therapyDetails: "Weekly OT",
        assessedByOthers: "yes",
      },
      null,
    );
    expect(out.probeAreas.some((p) => /therapy/i.test(p))).toBe(true);
    expect(out.probeAreas.some((p) => /prior professional reports/i.test(p))).toBe(true);
  });

  it("flags EHCP context when present", () => {
    const out = buildStubPrepBrief(
      { senPlan: "EHCP under annual review" },
      null,
    );
    expect(out.probeAreas.some((p) => /EHCP/i.test(p))).toBe(true);
  });

  it("flags red flags for recurrent ear infections + sensitivity", () => {
    const out = buildStubPrepBrief(
      {
        earInfections: "Recurrent age 2-4; resolved after grommets",
        difficulties: ["Overly sensitive to sounds/noises"],
      },
      null,
    );
    expect(out.redFlags.some((r) => /ear infections/i.test(r))).toBe(true);
    expect(out.redFlags.some((r) => /Sensitivity/i.test(r))).toBe(true);
  });

  it("returns a 'no red flags' notice when none triggered", () => {
    const out = buildStubPrepBrief({ difficulties: ["Speech sounds"] }, null);
    expect(out.redFlags).toEqual([
      "No red flags from intake — confirm in conversation",
    ]);
  });

  it("picks speech-sound references for speech-sound concerns", () => {
    const out = buildStubPrepBrief(
      {
        difficulties: ["Speech sounds"],
        mainConcern: "Speech sound delay",
      },
      null,
    );
    expect(out.references.some((r) => /Speech sound/i.test(r.title))).toBe(true);
  });

  it("picks fluency references for stutter concerns", () => {
    const out = buildStubPrepBrief(
      { mainConcern: "Stuttering since age 4" },
      null,
    );
    expect(out.references.some((r) => /Stammering|fluency/i.test(r.title))).toBe(true);
  });

  it("picks NICE NG87 for social-communication difficulties", () => {
    const out = buildStubPrepBrief(
      {
        difficulties: [
          "Maintaining eye contact",
          "Turn taking",
          "Reading between the lines",
        ],
      },
      null,
    );
    expect(out.references.some((r) => /NG87/i.test(r.title))).toBe(true);
  });

  it("picks feeding references for feeding concerns", () => {
    const out = buildStubPrepBrief(
      { mainConcern: "Very limited food range, refuses mixed textures" },
      null,
    );
    expect(out.references.some((r) => /Eating, drinking/i.test(r.title))).toBe(true);
  });

  it("falls back to DLD reference when nothing matches", () => {
    const out = buildStubPrepBrief({}, null);
    expect(out.references[0].title).toMatch(/Developmental language disorder/i);
  });

  it("is deterministic for the same input (idempotent stub)", () => {
    const input = {
      childName: "X",
      mainConcern: "Y",
      difficulties: ["Speech sounds"],
    };
    const a = buildStubPrepBrief(input, "X");
    const b = buildStubPrepBrief(input, "X");
    expect(a).toEqual(b);
  });
});
