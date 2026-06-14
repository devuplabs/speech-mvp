import { and, desc, eq } from "drizzle-orm";
import type { Env } from "../config.js";
import type { Db } from "../db/client.js";
import { aiDrafts, cases, triageRecords } from "../db/schema.js";
import { buildIntakeContextForLlm, generateClinicalReportLlm } from "../llm/generate-drafts.js";
import { writeAudit } from "./audit.js";
import { loadIntakeAnswers } from "./intake-context.js";
import {
  renderClinicalReportPdf,
  type ClinicalReportPdfInput,
} from "./clinical-report-pdf.js";

export type ClinicalReportSection = { heading: string; body: string };

export type ClinicalReportContent = {
  label: string;
  title: string;
  childDisplayName: string;
  sections: ClinicalReportSection[];
  disclaimer: string;
  source: string;
  generatedAt: string;
};

const REPORT_ELIGIBLE_STATUSES = new Set([
  "triaged",
  "plan_drafting",
  "plan_ready",
  "summary_sent",
]);

function buildStubSections(childName: string): ClinicalReportSection[] {
  const who = childName || "the child";
  return [
    {
      heading: "Referral & presentation",
      body: `Initial concerns and intake responses for ${who} were reviewed. Presentation is consistent with a speech and language therapy assessment pathway.`,
    },
    {
      heading: "Assessment summary",
      body: "Baseline observation and parent interview themes from the first consult are summarised here. Clinician to refine with session notes.",
    },
    {
      heading: "Recommendations",
      body: "Therapy block and home practice suggestions follow the triage outcome and session plan. Export is for clinician sign-off before sharing externally.",
    },
  ];
}

export function clinicalReportContentFromDraft(
  content: unknown,
  childDisplayName: string | null,
): ClinicalReportContent | null {
  if (!content || typeof content !== "object") return null;
  const c = content as Record<string, unknown>;
  if (typeof c.title !== "string" || !Array.isArray(c.sections)) return null;
  return {
    label: typeof c.label === "string" ? c.label : "DRAFT",
    title: c.title,
    childDisplayName:
      typeof c.childDisplayName === "string"
        ? c.childDisplayName
        : childDisplayName ?? "Child",
    sections: c.sections as ClinicalReportSection[],
    disclaimer:
      typeof c.disclaimer === "string"
        ? c.disclaimer
        : "AI-drafted · clinician-reviewed",
    source: typeof c.source === "string" ? c.source : "mvp_stub",
    generatedAt:
      typeof c.generatedAt === "string" ? c.generatedAt : new Date().toISOString(),
  };
}

export async function draftClinicalReportStub(db: Db, caseId: string, env?: Env) {
  const [row] = await db.select().from(cases).where(eq(cases.id, caseId));
  if (!row) return { ok: false as const, error: "not_found" as const };

  if (!REPORT_ELIGIBLE_STATUSES.has(row.status)) {
    return { ok: false as const, error: "case_not_ready" as const };
  }

  const existing = await db
    .select()
    .from(aiDrafts)
    .where(and(eq(aiDrafts.caseId, caseId), eq(aiDrafts.kind, "clinical_report")));
  if (existing.length > 0) {
    return { ok: true as const, alreadyExists: true, draft: existing[0]! };
  }

  const childName = row.childDisplayName?.trim() || "Child";
  const answers = await loadIntakeAnswers(db, caseId);
  const intakeContext = buildIntakeContextForLlm(answers);
  const [triage] = await db
    .select()
    .from(triageRecords)
    .where(eq(triageRecords.caseId, caseId))
    .limit(1);

  let content: ClinicalReportContent = {
    label: "DRAFT — clinician must review",
    title: "Clinical report",
    childDisplayName: childName,
    sections: buildStubSections(childName),
    disclaimer: "AI-drafted · clinician-reviewed. Not for distribution until signed.",
    source: "mvp_stub",
    generatedAt: new Date().toISOString(),
  };
  let modelId = "mvp-stub";

  if (env) {
    const llm = await generateClinicalReportLlm(env, {
      childDisplayName: childName,
      intakeContext,
      triageOutcome: triage?.outcome,
      mainConcern: answers.mainConcern as string | undefined,
      difficulties: answers.difficulties as string[] | undefined,
    });
    if (llm) {
      content = llm.content as ClinicalReportContent;
      modelId = llm.modelId;
    }
  }

  const [draft] = await db
    .insert(aiDrafts)
    .values({
      caseId,
      kind: "clinical_report",
      content,
      modelId,
    })
    .returning();

  await writeAudit(db, {
    tenantId: row.tenantId,
    caseId,
    actor: "system",
    action: "clinical_report.drafted",
  });

  return { ok: true as const, draft };
}

export async function listTenantClinicalReports(db: Db, tenantId: string) {
  const rows = await db
    .select({ case: cases, draft: aiDrafts })
    .from(cases)
    .innerJoin(
      aiDrafts,
      and(eq(aiDrafts.caseId, cases.id), eq(aiDrafts.kind, "clinical_report")),
    )
    .where(eq(cases.tenantId, tenantId))
    .orderBy(desc(aiDrafts.createdAt));

  return rows.map((row) => ({
    caseId: row.case.id,
    childDisplayName: row.case.childDisplayName,
    caseStatus: row.case.status,
    createdAt: row.draft.createdAt.toISOString(),
    reviewedAt: row.draft.reviewedAt?.toISOString() ?? null,
    title:
      (row.draft.content as { title?: string } | null)?.title ?? "Clinical report",
  }));
}

export async function getClinicalReportDraft(db: Db, caseId: string) {
  const [row] = await db.select().from(cases).where(eq(cases.id, caseId));
  if (!row) return { ok: false as const, error: "not_found" as const };

  const [draft] = await db
    .select()
    .from(aiDrafts)
    .where(and(eq(aiDrafts.caseId, caseId), eq(aiDrafts.kind, "clinical_report")));

  if (!draft) return { ok: false as const, error: "not_found" as const };

  const content = clinicalReportContentFromDraft(draft.content, row.childDisplayName);
  if (!content) return { ok: false as const, error: "invalid_content" as const };

  return { ok: true as const, case: row, draft, content };
}

export async function renderClinicalReportPdfForCase(db: Db, caseId: string) {
  const result = await getClinicalReportDraft(db, caseId);
  if (!result.ok) return result;

  const pdf = renderClinicalReportPdf({
    title: result.content.title,
    childDisplayName: result.content.childDisplayName,
    sections: result.content.sections,
    disclaimer: result.content.disclaimer,
  } satisfies ClinicalReportPdfInput);

  // Surface tenantId so the route can audit the PHI download (DEV-25) without
  // re-querying the case row the service already loaded.
  return { ok: true as const, pdf, content: result.content, tenantId: result.case.tenantId };
}
