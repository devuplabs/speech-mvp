import { describe, expect, it } from "vitest";
import { buildPrepBriefStubContent } from "../services/stub-draft-content.js";

describe("buildPrepBriefStubContent", () => {
  it("interpolates child name and main concern", () => {
    const content = buildPrepBriefStubContent({
      childDisplayName: "Test Child Alpha",
      mainConcern: "Difficulty with /r/ sounds",
      ageAtReferral: "6",
    });
    const probes = content.probeAreas as string[];
    expect(probes[0]).toContain("Test Child Alpha");
    expect(probes[0]).toContain("Difficulty with /r/ sounds");
    expect(probes[1]).toContain("6");
  });

  it("does not reference Aria when given a different child", () => {
    const content = buildPrepBriefStubContent({
      childDisplayName: "Jaden O.",
      mainConcern: "Stuttering since age 4",
      ageAtReferral: "7",
    });
    const joined = (content.probeAreas as string[]).join(" ");
    expect(joined).not.toContain("Aria");
    expect(joined).toContain("Jaden O.");
    expect(joined).toContain("Stuttering");
  });
});
