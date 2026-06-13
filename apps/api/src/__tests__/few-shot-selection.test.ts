import { describe, expect, it } from "vitest";
import { FEW_SHOT_BUCKETS } from "../llm/few-shot/few-shot-data.js";
import {
  buildFewShotBlock,
  estimateTokens,
  MAX_EXAMPLES,
  MAX_TOTAL_EXAMPLE_TOKENS,
  renderExample,
  resolveSpecialtyBucket,
  selectFewShotExamples,
} from "../llm/few-shot.js";

describe("resolveSpecialtyBucket", () => {
  it("maps speech-sound difficulties to speech_sounds", () => {
    expect(
      resolveSpecialtyBucket({ difficulties: ["Speech sounds"] }),
    ).toBe("speech_sounds");
  });

  it("maps language-domain difficulties to language", () => {
    expect(
      resolveSpecialtyBucket({ difficulties: ["Understanding what is said to them"] }),
    ).toBe("language");
  });

  it("maps social-communication difficulties to social_communication", () => {
    expect(
      resolveSpecialtyBucket({ difficulties: ["Maintaining eye contact"] }),
    ).toBe("social_communication");
  });

  it("matches fluency keywords in free-text concern", () => {
    expect(
      resolveSpecialtyBucket({ mainConcern: "Has started stuttering recently" }),
    ).toBe("fluency");
  });

  it("matches articulation keyword in free-text concern", () => {
    expect(
      resolveSpecialtyBucket({ mainConcern: "Articulation of /r/ is unclear" }),
    ).toBe("speech_sounds");
  });

  it("prefers the structured difficulties signal over concern keywords", () => {
    expect(
      resolveSpecialtyBucket({
        difficulties: ["Speech sounds"],
        mainConcern: "worried about stuttering",
      }),
    ).toBe("speech_sounds");
  });

  it("returns null when nothing matches", () => {
    expect(resolveSpecialtyBucket({ mainConcern: "general check up" })).toBeNull();
    expect(resolveSpecialtyBucket({})).toBeNull();
  });
});

describe("selectFewShotExamples", () => {
  it("specialty match returns examples from that bucket", () => {
    const sel = selectFewShotExamples({
      difficulties: ["Speech sounds"],
      kind: "prep_brief",
    });
    expect(sel.bucket).toBe("speech_sounds");
    expect(sel.usedFallback).toBe(false);
    expect(sel.examples.length).toBeGreaterThan(0);
    for (const ex of sel.examples) {
      expect(ex.specialty).toBe("speech_sounds");
    }
  });

  it("falls back to the all bucket when no specialty matches", () => {
    const sel = selectFewShotExamples({
      mainConcern: "no clear category",
      kind: "session_plan",
    });
    expect(sel.bucket).toBe("all");
    expect(sel.usedFallback).toBe(true);
    expect(sel.examples.length).toBeGreaterThan(0);
  });

  it("never returns more than MAX_EXAMPLES", () => {
    const sel = selectFewShotExamples({
      difficulties: ["Understanding what is said to them"], // language: 14 records
      kind: "session_plan",
    });
    expect(sel.bucket).toBe("language");
    expect(sel.examples.length).toBeLessThanOrEqual(MAX_EXAMPLES);
  });

  it("enforces the total token cap", () => {
    const sel = selectFewShotExamples({
      difficulties: ["Understanding what is said to them"],
      kind: "session_plan",
    });
    const total = sel.examples
      .map((ex) => estimateTokens(renderExample(ex, "session_plan")))
      .reduce((a, b) => a + b, 0);
    expect(total).toBeLessThanOrEqual(MAX_TOTAL_EXAMPLE_TOKENS);
  });

  it("is deterministic — same input yields the same persona ordering", () => {
    const a = selectFewShotExamples({
      difficulties: ["Speech sounds"],
      kind: "prep_brief",
    });
    const b = selectFewShotExamples({
      difficulties: ["Speech sounds"],
      kind: "prep_brief",
    });
    expect(a.examples.map((e) => e.persona_id)).toEqual(
      b.examples.map((e) => e.persona_id),
    );
  });

  it("orders examples by persona_id (stable)", () => {
    const sel = selectFewShotExamples({
      difficulties: ["Understanding what is said to them"],
      kind: "session_plan",
    });
    const ids = sel.examples.map((e) => e.persona_id);
    expect([...ids].sort((x, y) => x.localeCompare(y))).toEqual(ids);
  });
});

describe("buildFewShotBlock", () => {
  it("returns empty string when there are no examples", () => {
    expect(buildFewShotBlock({ bucket: "all", usedFallback: true, examples: [] }, "prep_brief")).toBe("");
  });

  it("renders a labelled examples block", () => {
    const sel = selectFewShotExamples({
      difficulties: ["Speech sounds"],
      kind: "prep_brief",
    });
    const block = buildFewShotBlock(sel, "prep_brief");
    expect(block).toContain("Reference examples");
    expect(block).toContain("Example 1:");
  });
});

describe("vendored data integrity", () => {
  it("ships an `all` fallback bucket and specialty buckets", () => {
    expect(FEW_SHOT_BUCKETS.all?.length ?? 0).toBeGreaterThan(0);
    expect(FEW_SHOT_BUCKETS.speech_sounds?.length ?? 0).toBeGreaterThan(0);
    expect(FEW_SHOT_BUCKETS.language?.length ?? 0).toBeGreaterThan(0);
  });
});
