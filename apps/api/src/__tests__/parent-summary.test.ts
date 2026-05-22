import { describe, expect, it } from "vitest";
import {
  buildParentSummaryHtml,
  buildParentSummaryText,
  defaultParentSummaryOptions,
  type ParentSummaryOptions,
} from "../services/parent-summary.js";

const ariaArgs = {
  childDisplayName: "Aria M.",
  answers: {
    mainConcern:
      "Hard to understand at nursery — drops final consonants and some sounds replaced.",
    difficulties: ["Speech sounds", "Staying on task"],
  },
  sessionPlan: {
    sections: {
      goals: ["Baseline of speech-sound inventory (DEAP screen)."],
      activities: ["Articulation probe."],
      homePractice: ["5 minutes daily 'silly sound' play."],
      materials: ["DEAP cards"],
      parentGoals: ["Notice + acknowledge clear speech."],
    },
    reviewStatus: "final",
  },
};

function opt(p: Partial<ParentSummaryOptions> = {}): ParentSummaryOptions {
  return { ...defaultParentSummaryOptions, ...p };
}

describe("buildParentSummaryHtml", () => {
  it("renders child name in the greeting", () => {
    const html = buildParentSummaryHtml({ ...ariaArgs, options: opt() });
    expect(html).toContain("Aria M.");
  });

  it("changes greeting + tone by tone slider", () => {
    const warm = buildParentSummaryHtml({ ...ariaArgs, options: opt({ tone: "warm" }) });
    const clinical = buildParentSummaryHtml({ ...ariaArgs, options: opt({ tone: "clinical" }) });
    expect(warm).toContain("Thanks for chatting with us");
    expect(clinical).toContain("Consultation summary");
  });

  it("renames sections under clinical tone", () => {
    const html = buildParentSummaryHtml({ ...ariaArgs, options: opt({ tone: "clinical" }) });
    expect(html).toContain("Summary of consultation");
    expect(html).toContain("Therapeutic goals");
    expect(html).toContain("Home practice + parent goals");
    expect(html).toContain("Next steps");
  });

  it("uses parent-friendly section names under warm/balanced tone", () => {
    const html = buildParentSummaryHtml({ ...ariaArgs, options: opt({ tone: "warm" }) });
    expect(html).toContain("What we talked about");
    expect(html).toContain("What we'll work on together");
    expect(html).toContain("How you can help at home");
    expect(html).toContain("What happens next");
  });

  it("limits difficulties under simple reading level", () => {
    const html = buildParentSummaryHtml({
      ...ariaArgs,
      answers: {
        mainConcern: "x",
        difficulties: ["A", "B", "C", "D", "E"],
      },
      options: opt({ readingLevel: "simple" }),
    });
    expect(html).toContain("A, B");
    expect(html).not.toContain("A, B, C");
  });

  it("toggles individual sections off via options.sections.*", () => {
    const html = buildParentSummaryHtml({
      ...ariaArgs,
      options: opt({
        sections: {
          whatWeDiscussed: false,
          planForFirstSession: false,
          homePractice: true,
          nextSteps: true,
        },
      }),
    });
    expect(html).not.toContain("What we talked about");
    expect(html).not.toContain("work on together");
    expect(html).toContain("help at home");
    expect(html).toContain("What happens next");
  });

  it("renders the AI-disclosure footer when toggle is on", () => {
    const html = buildParentSummaryHtml({ ...ariaArgs, options: opt({ aiDisclosure: true }) });
    expect(html).toContain("AI-drafted · clinician-reviewed");
  });

  it("omits the AI-disclosure footer when toggle is off", () => {
    const html = buildParentSummaryHtml({ ...ariaArgs, options: opt({ aiDisclosure: false }) });
    expect(html).not.toContain("AI-drafted · clinician-reviewed");
  });

  it("includes the goals from the session-plan draft when present", () => {
    const html = buildParentSummaryHtml({ ...ariaArgs, options: opt() });
    expect(html).toContain("DEAP screen");
  });

  it("falls back gracefully when no plan exists yet", () => {
    const html = buildParentSummaryHtml({
      childDisplayName: "X",
      answers: {},
      sessionPlan: null,
      options: opt(),
    });
    expect(html).toMatch(/firm up the plan|Plan to follow/);
  });

  it("html-escapes the parent concern (no script injection)", () => {
    const html = buildParentSummaryHtml({
      childDisplayName: "Y",
      answers: { mainConcern: '<script>alert("x")</script> Concern' },
      sessionPlan: null,
      options: opt(),
    });
    expect(html).not.toContain("<script>");
    expect(html).toContain("&lt;script&gt;");
  });

  it("text projection mirrors the HTML section ordering", () => {
    const projection = buildParentSummaryText({ ...ariaArgs, options: opt() });
    expect(projection.sections.map((s) => s.heading)).toEqual([
      "What we talked about",
      "What we'll work on together",
      "How you can help at home",
      "What happens next",
    ]);
  });

  it("text projection respects section toggles", () => {
    const projection = buildParentSummaryText({
      ...ariaArgs,
      options: opt({
        sections: {
          whatWeDiscussed: false,
          planForFirstSession: true,
          homePractice: false,
          nextSteps: true,
        },
      }),
    });
    expect(projection.sections.map((s) => s.heading)).toEqual([
      "What we'll work on together",
      "What happens next",
    ]);
  });
});
