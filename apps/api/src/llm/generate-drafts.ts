import { z } from "zod";
import type { Env } from "../config.js";
import { logger } from "../logger.js";
import { chatCompletion, isLlmConfigured, parseJsonFromLlm } from "./chat.js";
import { buildIntakeContextForLlm } from "./intake-context.js";
import { buildFewShotBlock, selectFewShotExamples } from "./few-shot.js";
import { CHILD_PLACEHOLDER, reinsertChildName } from "./redact.js";

/**
 * Concern signals used to pick a matching few-shot specialty bucket. Both are
 * optional: when omitted (or no match) the general fallback bucket is used, so
 * existing callers keep working and the stub path is unaffected.
 */
export type ConcernSignals = {
  mainConcern?: string | null;
  difficulties?: string[] | null;
};

const prepBriefSchema = z.object({
  probeAreas: z.array(z.string()).min(2).max(8),
});

const sessionPlanSchema = z.object({
  sections: z.object({
    goals: z.array(z.string()).min(1),
    activities: z.array(z.string()).min(1),
    homePractice: z.array(z.string()).min(1),
    materials: z.array(z.string()).optional(),
  }),
});

const clinicalReportSchema = z.object({
  title: z.string(),
  sections: z
    .array(
      z.object({
        heading: z.string(),
        body: z.string(),
      }),
    )
    .min(2),
});

const parentSummarySchema = z.object({
  html: z.string().min(20),
});

const SYSTEM =
  "You are a UK HCPC speech and language therapy assistant. Use British English. " +
  "Be concise, clinically appropriate, and parent-friendly where noted. " +
  "Never invent diagnoses. Output only valid JSON when asked.";

export async function generatePrepBriefLlm(
  env: Env,
  params: { childDisplayName: string; intakeContext: string } & ConcernSignals,
): Promise<{ content: Record<string, unknown>; modelId: string } | null> {
  if (!isLlmConfigured(env)) return null;

  const fewShot = buildFewShotBlock(
    selectFewShotExamples({
      mainConcern: params.mainConcern,
      difficulties: params.difficulties,
      kind: "prep_brief",
    }),
    "prep_brief",
  );

  const res = await chatCompletion({
    env,
    jsonMode: true,
    messages: [
      { role: "system", content: SYSTEM },
      {
        role: "user",
        content:
          `Child: ${CHILD_PLACEHOLDER}\n\n${fewShot}Intake:\n${params.intakeContext}\n\n` +
          `Return JSON: {"probeAreas":["..."]} with 4-6 specific prep probes for the first consult.`,
      },
    ],
  });
  if (!res.ok) {
    logger.warn("llm.generation_failed", { kind: "prep_brief", reason: res.reason });
    return null;
  }
  const parsed = parseJsonFromLlm<unknown>(res.content);
  const brief = prepBriefSchema.safeParse(parsed);
  if (!brief.success) return null;
  return {
    content: {
      label: "DRAFT — clinician must review",
      // Re-insert the real name in our own layer: the prompt only ever saw the
      // [CHILD] placeholder (DEV-53).
      probeAreas: reinsertChildName(brief.data.probeAreas, params.childDisplayName),
      source: "llm",
    },
    modelId: env.LLM_MODEL ?? "gemma-3-27b-it",
  };
}

export async function generateSessionPlanLlm(
  env: Env,
  params: {
    childDisplayName: string;
    intakeContext: string;
    triageOutcome: string;
  } & ConcernSignals,
): Promise<{ content: Record<string, unknown>; modelId: string } | null> {
  if (!isLlmConfigured(env)) return null;

  const fewShot = buildFewShotBlock(
    selectFewShotExamples({
      mainConcern: params.mainConcern,
      difficulties: params.difficulties,
      kind: "session_plan",
    }),
    "session_plan",
  );

  const res = await chatCompletion({
    env,
    jsonMode: true,
    maxTokens: 1500,
    messages: [
      { role: "system", content: SYSTEM },
      {
        role: "user",
        content:
          `Child: ${CHILD_PLACEHOLDER}\nTriage outcome: ${params.triageOutcome}\n\n` +
          `${fewShot}Intake:\n${params.intakeContext}\n\n` +
          `Return JSON: {"sections":{"goals":[],"activities":[],"homePractice":[],"materials":[]}} ` +
          `for a first SLT session plan.`,
      },
    ],
  });
  if (!res.ok) {
    logger.warn("llm.generation_failed", { kind: "session_plan", reason: res.reason });
    return null;
  }
  const parsed = parseJsonFromLlm<unknown>(res.content);
  const plan = sessionPlanSchema.safeParse(parsed);
  if (!plan.success) return null;
  return {
    content: {
      label: "DRAFT — clinician must review",
      sections: reinsertChildName(plan.data.sections, params.childDisplayName),
      source: "llm",
    },
    modelId: env.LLM_MODEL ?? "gemma-3-27b-it",
  };
}

export async function generateClinicalReportLlm(
  env: Env,
  params: {
    childDisplayName: string;
    intakeContext: string;
    triageOutcome?: string;
  } & ConcernSignals,
): Promise<{ content: Record<string, unknown>; modelId: string } | null> {
  if (!isLlmConfigured(env)) return null;

  const fewShot = buildFewShotBlock(
    selectFewShotExamples({
      mainConcern: params.mainConcern,
      difficulties: params.difficulties,
      kind: "clinical_report",
    }),
    "clinical_report",
  );

  const res = await chatCompletion({
    env,
    jsonMode: true,
    maxTokens: 1800,
    messages: [
      { role: "system", content: SYSTEM },
      {
        role: "user",
        content:
          `Draft a clinical report for ${CHILD_PLACEHOLDER}. ` +
          `Triage: ${params.triageOutcome ?? "not recorded"}.\n\n${fewShot}Intake:\n${params.intakeContext}\n\n` +
          `Return JSON: {"title":"Clinical report","sections":[{"heading":"...","body":"..."}]}. ` +
          `Include referral & presentation, assessment summary, and recommendations.`,
      },
    ],
  });
  if (!res.ok) {
    logger.warn("llm.generation_failed", { kind: "clinical_report", reason: res.reason });
    return null;
  }
  const parsed = parseJsonFromLlm<unknown>(res.content);
  const report = clinicalReportSchema.safeParse(parsed);
  if (!report.success) return null;
  return {
    content: {
      label: "DRAFT — clinician must review",
      title: reinsertChildName(report.data.title, params.childDisplayName),
      childDisplayName: params.childDisplayName,
      sections: reinsertChildName(report.data.sections, params.childDisplayName),
      disclaimer: "AI-drafted · clinician-reviewed. Not for distribution until signed.",
      source: "llm",
      generatedAt: new Date().toISOString(),
    },
    modelId: env.LLM_MODEL ?? "gemma-3-27b-it",
  };
}

export async function generateParentSummaryHtmlLlm(
  env: Env,
  params: { childDisplayName: string; intakeContext: string } & ConcernSignals,
): Promise<{ html: string; modelId: string } | null> {
  if (!isLlmConfigured(env)) return null;

  const fewShot = buildFewShotBlock(
    selectFewShotExamples({
      mainConcern: params.mainConcern,
      difficulties: params.difficulties,
      kind: "parent_summary",
    }),
    "parent_summary",
  );

  const res = await chatCompletion({
    env,
    jsonMode: true,
    messages: [
      { role: "system", content: SYSTEM },
      {
        role: "user",
        content:
          `Write a warm parent-facing summary for ${CHILD_PLACEHOLDER} after intake. ` +
          `Use the token ${CHILD_PLACEHOLDER} wherever you refer to the child by name. ` +
          `Reading level: Year 8. No medical jargon.\n\n${fewShot}Intake:\n${params.intakeContext}\n\n` +
          `Return JSON: {"html":"<p>...</p>"} with simple HTML paragraphs only. ` +
          `Include a line that the summary was drafted with AI assistance and reviewed by the clinician.`,
      },
    ],
  });
  if (!res.ok) {
    logger.warn("llm.generation_failed", { kind: "parent_summary", reason: res.reason });
    return null;
  }
  const parsed = parseJsonFromLlm<unknown>(res.content);
  const summary = parentSummarySchema.safeParse(parsed);
  if (!summary.success) return null;
  // The prompt addressed the child as [CHILD]; re-insert the real name here in
  // our own layer so the family-facing summary reads naturally (DEV-53).
  return {
    html: reinsertChildName(summary.data.html, params.childDisplayName),
    modelId: env.LLM_MODEL ?? "gemma-3-27b-it",
  };
}

export { buildIntakeContextForLlm };
