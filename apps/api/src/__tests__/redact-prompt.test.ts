import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";
import { beforeEach, describe, expect, it, vi } from "vitest";
import type { ChatMessage } from "../llm/chat.js";
import { assertNoDirectIdentifiers } from "./helpers/no-phi-in-prompt.js";

/**
 * DEV-53 — prompt data-minimisation. We mock the chat transport so we can
 * capture the exact prompt each generator builds, then assert no direct
 * identifier from the (realistic) persona intake survives into it. The personas
 * (scripts/personas/*.json) carry the full set of direct identifiers — child
 * name, DOB, addresses, parent names, emails, phones, postcodes — so they are
 * representative inputs for the no-PHI check.
 */

const captured: { messages: ChatMessage[] }[] = [];

vi.mock("../llm/chat.js", async (importOriginal) => {
  const actual = await importOriginal<typeof import("../llm/chat.js")>();
  return {
    ...actual,
    isLlmConfigured: () => true,
    chatCompletion: vi.fn(async (opts: { messages: ChatMessage[] }) => {
      captured.push({ messages: opts.messages });
      const prompt = opts.messages.find((m) => m.role === "user")?.content ?? "";
      // Each generator validates the whole payload against its own zod schema,
      // and the clinical_report `sections` array conflicts with the session_plan
      // `sections` object — so we branch on the prompt to return a shape that
      // satisfies the calling generator. Every shape echoes [CHILD] so the
      // re-insertion layer is exercised.
      const isReport = prompt.includes("Draft a clinical report");
      const content = isReport
        ? {
            title: "Clinical report for [CHILD]",
            sections: [
              { heading: "Presentation", body: "[CHILD] presents with..." },
              { heading: "Recommendations", body: "We recommend [CHILD]..." },
            ],
          }
        : {
            probeAreas: ["Assess [CHILD]'s speech sounds", "b", "c", "d"],
            sections: {
              goals: ["Help [CHILD] with final consonants"],
              activities: ["act"],
              homePractice: ["hp"],
              materials: ["m"],
            },
            html: "<p>Thank you for telling us about [CHILD]. Drafted with AI assistance and reviewed by the clinician.</p>",
          };
      return { ok: true as const, content: JSON.stringify(content) };
    }),
  };
});

import {
  buildIntakeContextForLlm,
  generateClinicalReportLlm,
  generateParentSummaryHtmlLlm,
  generatePrepBriefLlm,
  generateSessionPlanLlm,
} from "../llm/generate-drafts.js";
import { CHILD_PLACEHOLDER, dobToAge, parseAgeYears, redactIdentifiers } from "../llm/redact.js";
import type { Env } from "../config.js";

const env = {
  INFERENCE_OPENAI_BASE_URL: "https://inference.example/v1",
  LLM_MODEL: "google/gemma-3-27b-it",
} as unknown as Env;

const here = dirname(fileURLToPath(import.meta.url));
const personasDir = resolve(here, "../../../../scripts/personas");
const PERSONA_FILES = [
  "aria_speech_sounds_4yo.json",
  "jaden_stutter_7yo.json",
  "mia_social_comm_11yo.json",
  "theo_feeding_3yo.json",
];

function loadPersona(file: string): {
  childDisplayName: string;
  answers: Record<string, unknown>;
} {
  const raw = JSON.parse(readFileSync(resolve(personasDir, file), "utf8"));
  return { childDisplayName: raw.childDisplayName, answers: raw.answers };
}

function userPrompt(): string {
  const last = captured[captured.length - 1]!;
  return last.messages.find((m) => m.role === "user")!.content;
}

describe("redact unit", () => {
  it("strips email, phone, NHS number and postcode from free text", () => {
    const out = redactIdentifiers(
      "Call 07700 900 101 or email anna.m@example.com. NHS 943 476 5919. Lives at NW3 2EE.",
    );
    expect(out).not.toContain("anna.m@example.com");
    expect(out).not.toContain("07700");
    expect(out).not.toContain("943 476 5919");
    expect(out).not.toContain("NW3 2EE");
    expect(out).toContain("[EMAIL]");
  });

  it("strips known names (incl. first-name tokens) from free text", () => {
    const out = redactIdentifiers('"Aria want milk"', ["Aria M."]);
    expect(out.toLowerCase()).not.toContain("aria");
  });

  it("converts DOB to age band and parses common formats", () => {
    const now = new Date("2026-06-14T00:00:00Z");
    expect(parseAgeYears("15 / 03 / 2022", now)).toBe(4);
    expect(parseAgeYears("2022-03-15", now)).toBe(4);
    expect(dobToAge("15 / 03 / 2022", now)).toBe("4 years");
    expect(parseAgeYears("not a date")).toBeNull();
  });
});

describe("buildIntakeContextForLlm — no direct identifiers", () => {
  for (const file of PERSONA_FILES) {
    it(`context for ${file} carries no direct identifiers`, () => {
      const { answers } = loadPersona(file);
      const context = buildIntakeContextForLlm(answers);
      assertNoDirectIdentifiers(context, answers);
      // DOB raw string gone, age present, placeholder used for the child.
      expect(context).toContain(CHILD_PLACEHOLDER);
      if (answers.dateOfBirth) {
        expect(context).not.toContain(String(answers.dateOfBirth));
      }
    });
  }
});

describe("constructed prompts carry no direct identifiers", () => {
  beforeEach(() => {
    captured.length = 0;
  });

  for (const file of PERSONA_FILES) {
    it(`all four generators — ${file}`, async () => {
      const { childDisplayName, answers } = loadPersona(file);
      const params = {
        childDisplayName,
        intakeContext: buildIntakeContextForLlm(answers),
        mainConcern: answers.mainConcern as string | undefined,
        difficulties: answers.difficulties as string[] | undefined,
      };

      await generatePrepBriefLlm(env, params);
      assertNoDirectIdentifiers(userPrompt(), answers);

      await generateSessionPlanLlm(env, { ...params, triageOutcome: "short_block" });
      assertNoDirectIdentifiers(userPrompt(), answers);

      await generateClinicalReportLlm(env, { ...params, triageOutcome: "short_block" });
      assertNoDirectIdentifiers(userPrompt(), answers);

      await generateParentSummaryHtmlLlm(env, params);
      assertNoDirectIdentifiers(userPrompt(), answers);
    });
  }
});

describe("placeholder re-insertion round-trip", () => {
  beforeEach(() => {
    captured.length = 0;
  });

  it("prompt uses [CHILD] but final draft shows the real name", async () => {
    const { childDisplayName, answers } = loadPersona("aria_speech_sounds_4yo.json");
    const params = {
      childDisplayName,
      intakeContext: buildIntakeContextForLlm(answers),
      mainConcern: answers.mainConcern as string | undefined,
      difficulties: answers.difficulties as string[] | undefined,
    };

    const summary = await generateParentSummaryHtmlLlm(env, params);
    // Prompt sent to the model used the placeholder, not the name.
    expect(userPrompt()).toContain(CHILD_PLACEHOLDER);
    expect(userPrompt()).not.toContain(childDisplayName);
    // Final output has the real name re-inserted, no placeholder left.
    expect(summary!.html).toContain(childDisplayName);
    expect(summary!.html).not.toContain(CHILD_PLACEHOLDER);

    captured.length = 0;
    const report = await generateClinicalReportLlm(env, { ...params, triageOutcome: "short_block" });
    expect(userPrompt()).toContain(CHILD_PLACEHOLDER);
    expect(report!.content.title).toContain(childDisplayName);
    expect(JSON.stringify(report!.content)).not.toContain(CHILD_PLACEHOLDER);

    captured.length = 0;
    const brief = await generatePrepBriefLlm(env, params);
    expect(JSON.stringify(brief!.content)).not.toContain(CHILD_PLACEHOLDER);
    expect(JSON.stringify(brief!.content)).toContain(childDisplayName);
  });
});
