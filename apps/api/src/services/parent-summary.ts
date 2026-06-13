import { and, eq } from "drizzle-orm";
import type { Env } from "../config.js";
import type { Db } from "../db/client.js";
import { aiDrafts, cases } from "../db/schema.js";
import { writeAudit } from "./audit.js";
import { logger } from "../logger.js";
import { buildIntakeContextForLlm, generateParentSummaryHtmlLlm } from "../llm/generate-drafts.js";
import { draftClinicalReportStub } from "./clinical-report.js";
import { loadIntakeAnswers } from "./intake-context.js";

/**
 * A parent summary may only be published once the clinician has triaged the
 * case (DEV-34 — state-machine hardening). `summary_sent` stays eligible so a
 * clinician can re-publish an amended summary.
 */
const SUMMARY_PUBLISHABLE_STATUSES = new Set([
  "triaged",
  "plan_drafting",
  "plan_ready",
  "summary_sent",
]);

/** Pure status guard so the rule is unit-testable without a database. */
export function canPublishParentSummary(status: string): boolean {
  return SUMMARY_PUBLISHABLE_STATUSES.has(status);
}

export function defaultParentSummaryHtml(childName?: string | null): string {
  const who = childName ? ` for ${childName}` : "";
  return `<!DOCTYPE html><html><body>
<p>Thank you for completing the intake${who}.</p>
<p><strong>AI-drafted · clinician-reviewed</strong></p>
<p>Your clinician will follow up with next steps after reviewing your responses.</p>
</body></html>`;
}

/** Portal-first publish: summary stored in DB (GCS optional later). */
export async function publishParentSummary(
  db: Db,
  caseId: string,
  htmlBody?: string,
  env?: Env,
) {
  const [existing] = await db.select().from(cases).where(eq(cases.id, caseId));
  if (!existing) return { ok: false as const, error: "not_found" as const };
  if (!canPublishParentSummary(existing.status)) {
    return { ok: false as const, error: "case_not_ready" as const };
  }

  let html = htmlBody;
  let summaryModelId = "clinician-published";
  if (!html && env) {
    const answers = await loadIntakeAnswers(db, caseId);
    const llm = await generateParentSummaryHtmlLlm(env, {
      childDisplayName: existing.childDisplayName ?? "Child",
      intakeContext: buildIntakeContextForLlm(answers),
    });
    if (llm) {
      html = llm.html;
      summaryModelId = llm.modelId;
    }
  }
  html ??= defaultParentSummaryHtml(existing.childDisplayName);

  const prior = await db
    .select()
    .from(aiDrafts)
    .where(and(eq(aiDrafts.caseId, caseId), eq(aiDrafts.kind, "parent_summary")));

  if (prior.length > 0) {
    await db
      .update(aiDrafts)
      .set({
        content: { html, publishedAt: new Date().toISOString() },
        reviewedAt: new Date(),
      })
      .where(eq(aiDrafts.id, prior[0]!.id));
  } else {
    await db.insert(aiDrafts).values({
      caseId,
      kind: "parent_summary",
      content: { html, publishedAt: new Date().toISOString() },
      modelId: summaryModelId,
      reviewedAt: new Date(),
    });
  }

  const [updated] = await db
    .update(cases)
    .set({ status: "summary_sent", updatedAt: new Date() })
    .where(eq(cases.id, caseId))
    .returning();

  await writeAudit(db, {
    tenantId: existing.tenantId,
    caseId,
    actor: "clinician",
    action: "parent_summary.published",
  });

  try {
    await draftClinicalReportStub(db, caseId, env);
  } catch (err) {
    logger.warn("clinical_report.stub_failed_after_publish", { caseId, err });
  }

  return {
    ok: true as const,
    case: updated,
    viewPath: `/v1/cases/${caseId}/parent-summary`,
  };
}

export async function getPublishedParentSummary(db: Db, caseId: string) {
  const [row] = await db.select().from(cases).where(eq(cases.id, caseId));
  if (!row) return { ok: false as const, error: "not_found" };
  if (row.status !== "summary_sent") {
    return { ok: false as const, error: "not_published", status: row.status };
  }

  const drafts = await db
    .select()
    .from(aiDrafts)
    .where(and(eq(aiDrafts.caseId, caseId), eq(aiDrafts.kind, "parent_summary")));

  const draft = drafts[0];
  const content = draft?.content as { html?: string } | undefined;
  const html = content?.html ?? defaultParentSummaryHtml(row.childDisplayName);

  return { ok: true as const, case: row, html };
}
