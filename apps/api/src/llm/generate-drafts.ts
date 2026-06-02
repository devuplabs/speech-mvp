import { z } from "zod";
import type { Env } from "../config.js";
import { chatCompletion, isLlmConfigured, isLlmEnabledFor, parseJsonFromLlm } from "./chat.js";
import { buildIntakeContextForLlm } from "./intake-context.js";

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
  params: { childDisplayName: string; intakeContext: string },
): Promise<{ content: Record<string, unknown>; modelId: string } | null> {
  if (!isLlmEnabledFor(env, "prep_brief")) return null;

  const res = await chatCompletion({
    env,
    jsonMode: true,
    messages: [
      { role: "system", content: SYSTEM },
      {
        role: "user",
        content:
          `Child: ${params.childDisplayName}\n\nIntake:\n${params.intakeContext}\n\n` +
          `Return JSON: {"probeAreas":["..."]} with 4-6 specific prep probes for the first consult.`,
      },
    ],
  });
  if (!res.ok) {
    console.warn("prep brief LLM:", res.reason);
    return null;
  }
  const parsed = parseJsonFromLlm<unknown>(res.content);
  const brief = prepBriefSchema.safeParse(parsed);
  if (!brief.success) return null;
  return {
    content: {
      label: "DRAFT — clinician must review",
      probeAreas: brief.data.probeAreas,
      source: "llm",
    },
    modelId: env.LLM_MODEL ?? "gemma-3-27b-it",
  };
}

export async function generateSessionPlanLlm(
  env: Env,
  params: { childDisplayName: string; intakeContext: string; triageOutcome: string },
): Promise<{ content: Record<string, unknown>; modelId: string } | null> {
  if (!isLlmEnabledFor(env, "session_plan")) return null;

  const res = await chatCompletion({
    env,
    jsonMode: true,
    maxTokens: 1500,
    messages: [
      { role: "system", content: SYSTEM },
      {
        role: "user",
        content:
          `Child: ${params.childDisplayName}\nTriage outcome: ${params.triageOutcome}\n\n` +
          `Intake:\n${params.intakeContext}\n\n` +
          `Return JSON: {"sections":{"goals":[],"activities":[],"homePractice":[],"materials":[]}} ` +
          `for a first SLT session plan.`,
      },
    ],
  });
  if (!res.ok) {
    console.warn("session plan LLM:", res.reason);
    return null;
  }
  const parsed = parseJsonFromLlm<unknown>(res.content);
  const plan = sessionPlanSchema.safeParse(parsed);
  if (!plan.success) return null;
  return {
    content: {
      label: "DRAFT — clinician must review",
      sections: plan.data.sections,
      source: "llm",
    },
    modelId: env.LLM_MODEL ?? "gemma-3-27b-it",
  };
}

export async function generateClinicalReportLlm(
  env: Env,
  params: { childDisplayName: string; intakeContext: string; triageOutcome?: string },
): Promise<{ content: Record<string, unknown>; modelId: string } | null> {
  if (!isLlmEnabledFor(env, "clinical_report")) return null;

  const res = await chatCompletion({
    env,
    jsonMode: true,
    maxTokens: 1800,
    messages: [
      { role: "system", content: SYSTEM },
      {
        role: "user",
        content:
          `Draft a clinical report for ${params.childDisplayName}. ` +
          `Triage: ${params.triageOutcome ?? "not recorded"}.\n\nIntake:\n${params.intakeContext}\n\n` +
          `Return JSON: {"title":"Clinical report","sections":[{"heading":"...","body":"..."}]}. ` +
          `Include referral & presentation, assessment summary, and recommendations.`,
      },
    ],
  });
  if (!res.ok) {
    console.warn("clinical report LLM:", res.reason);
    return null;
  }
  const parsed = parseJsonFromLlm<unknown>(res.content);
  const report = clinicalReportSchema.safeParse(parsed);
  if (!report.success) return null;
  return {
    content: {
      label: "DRAFT — clinician must review",
      title: report.data.title,
      childDisplayName: params.childDisplayName,
      sections: report.data.sections,
      disclaimer: "AI-drafted · clinician-reviewed. Not for distribution until signed.",
      source: "llm",
      generatedAt: new Date().toISOString(),
    },
    modelId: env.LLM_MODEL ?? "gemma-3-27b-it",
  };
}

export async function generateParentSummaryHtmlLlm(
  env: Env,
  params: { childDisplayName: string; intakeContext: string },
): Promise<{ html: string; modelId: string } | null> {
  if (!isLlmEnabledFor(env, "parent_summary")) return null;

  const res = await chatCompletion({
    env,
    jsonMode: true,
    messages: [
      { role: "system", content: SYSTEM },
      {
        role: "user",
        content:
          `Write a warm parent-facing summary for ${params.childDisplayName} after intake. ` +
          `Reading level: Year 8. No medical jargon.\n\nIntake:\n${params.intakeContext}\n\n` +
          `Return JSON: {"html":"<p>...</p>"} with simple HTML paragraphs only. ` +
          `Include a line that the summary was drafted with AI assistance and reviewed by the clinician.`,
      },
    ],
  });
  if (!res.ok) {
    console.warn("parent summary LLM:", res.reason);
    return null;
  }
  const parsed = parseJsonFromLlm<unknown>(res.content);
  const summary = parentSummarySchema.safeParse(parsed);
  if (!summary.success) return null;
  return { html: summary.data.html, modelId: env.LLM_MODEL ?? "gemma-3-27b-it" };
}

export { buildIntakeContextForLlm };
// Re-export for callers (services) that need to check whether to even
// attempt the LLM path (e.g. for logging / branching), and for tests.
export { isLlmConfigured, isLlmEnabledFor };
