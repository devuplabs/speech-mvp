import { and, eq } from "drizzle-orm";
import type { Env } from "../config.js";
import type { Db } from "../db/client.js";
import { aiDrafts, cases, tenants } from "../db/schema.js";
import { writeAudit } from "./audit.js";
import { logger } from "../logger.js";
import { buildIntakeContextForLlm, generateParentSummaryHtmlLlm } from "../llm/generate-drafts.js";
import { draftClinicalReportStub } from "./clinical-report.js";
import { loadIntakeAnswers } from "./intake-context.js";
import { sendFamilySummaryReadyEmail } from "./email.js";
import { buildPortalUrl, getOrCreatePortalToken } from "./portal-links.js";

/**
 * Resolve the public web base URL the family link should point at. Inlined here
 * (rather than imported from a route module) so this service stays self-contained
 * and we avoid touching `index.ts`/route wiring owned by other work in flight.
 */
function resolveWebBaseUrl(env: Env): string {
  return (
    env.SONA_WEB_BASE_URL ??
    (env.NODE_ENV === "development"
      ? "http://localhost:8080"
      : "https://sona-web-dev-3rhenudy6a-nw.a.run.app")
  );
}

/**
 * Best-effort family notification on publish.
 *
 * PHI policy: the email is notification-only — practice name + portal link, no
 * child name or clinical content (ADR-005). We never log the token. A send
 * failure (or unconfigured Mailgun) must NOT fail the publish: the summary is
 * already in the portal, so we log and continue, mirroring the clinician-invite
 * dispatch. Re-publishing re-sends (and reuses the existing active portal link
 * via `getOrCreatePortalToken`) so an amended summary always pings the family.
 */
async function notifyFamilyOfSummary(
  db: Db,
  caseId: string,
  parentEmail: string,
  tenantId: string,
  env: Env,
): Promise<boolean> {
  const [tenant] = await db.select().from(tenants).where(eq(tenants.id, tenantId));
  const practiceName = tenant?.displayName ?? "your speech & language practice";

  const tokenResult = await getOrCreatePortalToken(db, caseId);
  if (!tokenResult.ok) {
    logger.warn("parent_summary.portal_link_failed", { caseId });
    return false;
  }

  const portalUrl = buildPortalUrl(resolveWebBaseUrl(env), tokenResult.token);
  const sent = await sendFamilySummaryReadyEmail(env, {
    to: parentEmail,
    practiceName,
    portalUrl,
  });

  // Never log the recipient address, token or URL — only the safe outcome.
  if (!sent.ok) {
    logger.warn("parent_summary.notify_failed", { caseId, reason: sent.error });
    return false;
  }
  logger.info("parent_summary.notify_sent", { caseId });
  return true;
}

/**
 * A parent summary may only be published once the clinician has triaged the
 * case (DEV-34 — state-machine hardening). `summary_sent` stays eligible so a
 * clinician can re-publish an amended summary; `carryover` stays eligible too
 * (DEV-10) so re-publishing an amended summary still works after the case has
 * moved into the carryover stage.
 */
const SUMMARY_PUBLISHABLE_STATUSES = new Set([
  "triaged",
  "plan_drafting",
  "plan_ready",
  "summary_sent",
  "carryover",
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

  // Close the loop: notify the family their summary is ready (best-effort).
  // Only when we have a parent email and an env to build the link / send mail.
  let notified = false;
  if (existing.parentEmail && env) {
    try {
      notified = await notifyFamilyOfSummary(
        db,
        caseId,
        existing.parentEmail,
        existing.tenantId,
        env,
      );
    } catch (err) {
      // Defensive: notification must never fail the publish.
      logger.warn("parent_summary.notify_failed", { caseId, err });
    }
  }

  return {
    ok: true as const,
    case: updated,
    viewPath: `/v1/cases/${caseId}/parent-summary`,
    familyNotified: notified,
  };
}

export async function getPublishedParentSummary(db: Db, caseId: string) {
  const [row] = await db.select().from(cases).where(eq(cases.id, caseId));
  if (!row) return { ok: false as const, error: "not_found" };
  // A published summary remains viewable once the case advances into carryover
  // (DEV-10) — the portal still renders it alongside shared resources.
  if (row.status !== "summary_sent" && row.status !== "carryover") {
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
