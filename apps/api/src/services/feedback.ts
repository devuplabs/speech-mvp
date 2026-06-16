import type { Db } from "../db/client.js";
import { feedback } from "../db/schema.js";
import { writeAudit } from "./audit.js";
import { logger } from "../logger.js";
import type { SubmitFeedbackBody } from "../schemas/feedback.js";

/**
 * Persist a tester feedback submission (DEV-55) and record a content-free audit
 * event. PHI rule: only the fields below are stored — never names, DOB, intake
 * answers, draft content, emails or tokens. The free-text `comment` is the
 * tester's own words; testers are told (in-app) not to paste real patient data,
 * and UAT runs on synthetic data only.
 */
export async function recordFeedback(
  db: Db,
  input: SubmitFeedbackBody & { requestId?: string; userAgent?: string },
): Promise<{ id: string }> {
  const [row] = await db
    .insert(feedback)
    .values({
      tenantId: input.tenantId,
      role: input.role,
      route: input.route,
      journeyStage: input.journeyStage,
      feedbackType: input.type,
      severity: input.severity,
      comment: input.comment,
      buildSha: input.buildSha,
      appEnv: input.appEnv,
      viewport: input.viewport,
      locale: input.locale,
      userAgent: input.userAgent,
      requestId: input.requestId,
    })
    .returning({ id: feedback.id });

  // Audit the event only (no comment text). Best-effort: a failed audit insert
  // must never fail the submission. tenantId is intentionally omitted here —
  // audit_log.tenant_id is FK-constrained and feedback's tenant id is not
  // verified, so passing it could 500 on a stale/foreign id.
  try {
    await writeAudit(db, {
      actor: input.role ?? "tester",
      action: "feedback.submitted",
      metadata: {
        feedbackType: input.type,
        route: input.route,
        journeyStage: input.journeyStage,
      },
    });
  } catch (err) {
    logger.warn("feedback.audit_failed", { err });
  }

  return { id: row!.id };
}
