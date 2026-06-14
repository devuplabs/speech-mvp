import { beforeEach, describe, expect, it, vi } from "vitest";
import type { ChatMessage } from "../llm/chat.js";

/**
 * Prompt snapshot tests (DEV-14). We mock the chat transport so we can capture
 * the exact messages the generators construct — few-shot injection included —
 * and snapshot them. Drift in the few-shot block, intake rendering, or output
 * contract then shows up in the snapshot diff for review (mirroring speech-ml's
 * golden prompt snapshots).
 */

const captured: { messages: ChatMessage[] }[] = [];

vi.mock("../llm/chat.js", async (importOriginal) => {
  const actual = await importOriginal<typeof import("../llm/chat.js")>();
  return {
    ...actual,
    isLlmConfigured: () => true,
    chatCompletion: vi.fn(async (opts: { messages: ChatMessage[] }) => {
      captured.push({ messages: opts.messages });
      // Return a payload that satisfies every generator's zod schema so the
      // generator runs to completion (we only care about the request prompt).
      return {
        ok: true as const,
        content: JSON.stringify({
          probeAreas: ["a", "b", "c", "d"],
          sections: {
            goals: ["g"],
            activities: ["act"],
            homePractice: ["hp"],
            materials: ["m"],
          },
          html: "<p>Summary drafted with AI assistance and reviewed by the clinician.</p>",
          title: "Clinical report",
        }),
      };
    }),
  };
});

import {
  generateParentSummaryHtmlLlm,
  generatePrepBriefLlm,
  generateSessionPlanLlm,
} from "../llm/generate-drafts.js";
import type { Env } from "../config.js";

const env = {
  INFERENCE_OPENAI_BASE_URL: "https://inference.example/v1",
  LLM_MODEL: "google/gemma-3-27b-it",
} as unknown as Env;

// Two representative cases: a speech-sounds case (specialty match) and an
// uncategorised case (general `all` fallback). The intakeContext mirrors what
// buildIntakeContextForLlm now produces post-DEV-53 — the child is referred to
// by the [CHILD] placeholder, never a real name.
const speechSoundsCase = {
  childDisplayName: "Case A",
  intakeContext:
    "Child: [CHILD]\nMain concern: Hard to understand, substitutes sounds\nDifficulties: Speech sounds",
  mainConcern: "Hard to understand, substitutes sounds",
  difficulties: ["Speech sounds"],
};

const fallbackCase = {
  childDisplayName: "Case B",
  intakeContext: "Child: [CHILD]\nMain concern: general developmental check",
  mainConcern: "general developmental check",
  difficulties: [] as string[],
};

function lastUserPrompt(): string {
  const last = captured[captured.length - 1]!;
  return last.messages.find((m) => m.role === "user")!.content;
}

describe("few-shot prompt snapshots", () => {
  beforeEach(() => {
    captured.length = 0;
  });

  for (const c of [speechSoundsCase, fallbackCase]) {
    it(`prep_brief prompt — ${c.childDisplayName}`, async () => {
      await generatePrepBriefLlm(env, c);
      expect(lastUserPrompt()).toMatchSnapshot();
    });

    it(`session_plan prompt — ${c.childDisplayName}`, async () => {
      await generateSessionPlanLlm(env, { ...c, triageOutcome: "short_block" });
      expect(lastUserPrompt()).toMatchSnapshot();
    });

    it(`parent_summary prompt — ${c.childDisplayName}`, async () => {
      await generateParentSummaryHtmlLlm(env, c);
      expect(lastUserPrompt()).toMatchSnapshot();
    });
  }

  it("speech-sounds case injects a specialty few-shot block; fallback uses general examples", async () => {
    await generatePrepBriefLlm(env, speechSoundsCase);
    const specialtyPrompt = lastUserPrompt();
    expect(specialtyPrompt).toContain("Reference examples");

    captured.length = 0;
    await generatePrepBriefLlm(env, fallbackCase);
    const fallbackPrompt = lastUserPrompt();
    expect(fallbackPrompt).toContain("Reference examples");

    // The two should differ — different buckets feed different examples.
    expect(specialtyPrompt).not.toEqual(fallbackPrompt);
  });
});
