import { and, eq } from "drizzle-orm";
import type { Db } from "../db/client.js";
import { aiDrafts, cases } from "../db/schema.js";
import { writeAudit } from "./audit.js";

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
) {
  const [existing] = await db.select().from(cases).where(eq(cases.id, caseId));
  if (!existing) return { ok: false as const, error: "not_found" };

  const html = htmlBody ?? defaultParentSummaryHtml(existing.childDisplayName);

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
      modelId: "clinician-published",
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
