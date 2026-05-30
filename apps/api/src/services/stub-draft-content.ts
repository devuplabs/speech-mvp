/** Deterministic MVP stub copy — interpolates intake so demos are case-specific. */

function clip(text: string, max = 120): string {
  const t = text.trim();
  if (t.length <= max) return t;
  return `${t.slice(0, max - 1)}…`;
}

export function buildPrepBriefStubContent(input: {
  childDisplayName: string;
  mainConcern?: string | null;
  ageAtReferral?: string | null;
}): Record<string, unknown> {
  const name = input.childDisplayName.trim() || "Child";
  const concern = clip((input.mainConcern ?? "").trim() || "primary concern from intake");
  const age = (input.ageAtReferral ?? "").trim() || "see date of birth in intake";

  return {
    label: "DRAFT — clinician must review",
    probeAreas: [
      `Confirm primary concern with parent (${name}): "${concern}"`,
      `Review age band (${age}) and red flags from intake`,
      "EHCP / SEN plan status if indicated in intake",
    ],
    source: "mvp_stub",
  };
}

export function buildSessionPlanStubContent(input: {
  childDisplayName: string;
  mainConcern?: string | null;
}): Record<string, unknown> {
  const name = input.childDisplayName.trim() || "Child";
  const concern = clip((input.mainConcern ?? "").trim() || "areas flagged in intake");

  return {
    label: "DRAFT — clinician must review",
    sections: {
      goals: [
        `Establish baseline for ${name} aligned with: ${concern}`,
        "Agree parent priorities for first block",
      ],
      activities: [
        "Play-based observation",
        `Parent interview probes from prep brief (${name})`,
      ],
      homePractice: ["Short daily practice suggestion (clinician to refine)"],
      materials: ["Toys / pictures as appropriate"],
    },
    source: "mvp_stub",
  };
}
