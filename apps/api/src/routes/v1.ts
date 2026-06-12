import { and, eq } from "drizzle-orm";
import { Hono } from "hono";
import { z } from "zod";
import type { Env } from "../config.js";
import type { Db } from "../db/client.js";
import { logger } from "../logger.js";
import {
  aiDrafts,
  cases,
  intakeSubmissions,
  tenants,
  triageRecords,
} from "../db/schema.js";
import { saveIntakeDraftBody, submitIntakeBody } from "../schemas/intake.js";
import { submitIntake as submitIntakeRecord, upsertIntakeDraft } from "../services/intake.js";
import {
  getPublishedParentSummary,
  publishParentSummary,
} from "../services/parent-summary.js";
import { draftPrepBrief } from "../services/prep-brief.js";
import { draftSessionPlanStub } from "../services/session-plan.js";
import { seedCanonicalDemoPractice } from "../services/demo-seed.js";
import { practiceDisplayName, type PracticeVariant } from "../demo/practice.js";
import { isDevMaintenanceAllowed } from "../demo/dev-maintenance.js";
import { cleanupE2eTestCases } from "../services/cleanup-e2e-test-cases.js";
import {
  draftClinicalReportStub,
  getClinicalReportDraft,
  listTenantClinicalReports,
  renderClinicalReportPdfForCase,
} from "../services/clinical-report.js";

import { writeAudit } from "../services/audit.js";
import { enqueueLlmPrep } from "../services/tasks.js";
import { registerPatientBody } from "../schemas/register-patient.js";
import {
  registerPatient,
  resolveIntakeLinkToken,
} from "../services/register-patient.js";
import {
  availabilityRuleSchema,
  bookConsultBody,
  putAvailabilityRulesBody,
} from "../schemas/booking.js";
import {
  ensureDefaultAvailability,
  getAvailabilitySlots,
  listAvailabilityRules,
  replaceAvailabilityRules,
} from "../services/availability.js";
import { bookConsult, buildConsultIcs } from "../services/consult-booking.js";
import {
  listTenantIntakeForms,
  lockIntake,
  resendIntakeLink,
  revokeIntakeLinks,
  assertIntakeNotLocked,
} from "../services/intake-forms.js";
import { intakeTemplateIdEnum } from "../schemas/intake-template.js";
import {
  createCarryoverResourceBody,
  createProgressEntryBody,
  updateCarryoverResourceBody,
} from "../schemas/carryover.js";
import {
  addProgressEntry,
  createCarryoverResource,
  deleteCarryoverResource,
  getPortalPayload,
  listCarryoverResources,
  listProgressEntries,
  updateCarryoverResource,
} from "../services/carryover.js";
import {
  createPortalLink,
  resolvePortalLink,
  revokePortalLinks,
} from "../services/portal-links.js";
import { createPracticeRoutes } from "./practices.js";
import { getTokenVerifier, AuthError } from "../auth/verifier.js";
import { resolveCurrentUser } from "../services/practice.js";



const createTenantBody = z.object({
  displayName: z.string().min(1).max(255),
});

const createCaseBody = z.object({
  tenantId: z.string().uuid(),
  parentEmail: z.string().trim().email().max(320).nullish(),
  childDisplayName: z.string().trim().max(128).nullish(),
});

const triageBody = z.object({
  outcome: z.enum(["strategy_only", "short_block", "full_assessment", "refer_out"]),
  reason: z.string().max(2000).optional(),
});

const publishParentSummaryBody = z.object({
  htmlBody: z.string().min(1).max(100_000).optional(),
});

export function createV1Routes(db: Db, env: Env) {
  const app = new Hono();

  // Practice onboarding & auth-gated admin API (Feature 3).
  app.route("/practices", createPracticeRoutes(db, env));

  // Current-user profile for role-based routing (Auth·14). Token-only so an
  // invited clinician (not yet `active`) can fetch it on first login — which
  // activates their seat. AuthError is mapped to a status by the global handler.
  const verifier = getTokenVerifier(env);
  app.get("/me", async (c) => {
    const match = /^Bearer\s+(.+)$/i.exec((c.req.header("Authorization") ?? "").trim());
    if (!match) throw new AuthError("no_token");
    const identity = await verifier.verify(match[1].trim());
    const me = await resolveCurrentUser(db, identity.uid);
    if (!me) return c.json({ error: "not_provisioned" }, 404);
    if (me.user.status === "disabled") return c.json({ error: "forbidden" }, 403);
    return c.json({ user: me.user, practice: me.practice });
  });

  const webBaseUrl =
    env.SONA_WEB_BASE_URL ??
    (env.NODE_ENV === "development"
      ? "http://localhost:8080"
      : "https://sona-web-dev-3rhenudy6a-nw.a.run.app");

  app.post("/clinicians/me/patients", async (c) => {
    const body = registerPatientBody.parse(await c.req.json());
    const result = await registerPatient(db, body, webBaseUrl);
    return c.json(
      {
        case: result.case,
        intakeLink: result.intakeLink,
        consultBooking: result.consultBooking ?? null,
        idempotent: result.idempotent,
      },
      result.idempotent ? 200 : 201,
    );
  });


  app.get("/tenants/:tenantId/intake-submissions", async (c) => {
    const tenantId = c.req.param("tenantId");
    const items = await listTenantIntakeForms(db, tenantId);
    return c.json({ items });
  });

  app.post("/cases/:caseId/intake-links/resend", async (c) => {
    const caseId = c.req.param("caseId");
    const body = (await c.req.json().catch(() => ({}))) as { templateId?: string };
    const templateId = body.templateId
      ? intakeTemplateIdEnum.safeParse(body.templateId).data
      : undefined;
    const result = await resendIntakeLink(db, caseId, webBaseUrl, templateId);
    if (!result.ok) return c.json({ error: result.error }, 404);
    return c.json({ url: result.url, expiresAt: result.expiresAt, templateId: result.templateId });
  });

  app.post("/cases/:caseId/intake-links/revoke", async (c) => {
    const caseId = c.req.param("caseId");
    await revokeIntakeLinks(db, caseId);
    return c.body(null, 204);
  });

  app.post("/cases/:caseId/intake/lock", async (c) => {
    const caseId = c.req.param("caseId");
    const result = await lockIntake(db, caseId);
    if (!result.ok) return c.json({ error: "not_found" }, 404);
    return c.body(null, 204);
  });

  app.get("/intake-links/:token", async (c) => {
    const token = c.req.param("token");
    const result = await resolveIntakeLinkToken(db, token);
    if (!result.ok) {
      const status = result.error === "expired" ? 410 : 404;
      return c.json({ error: result.error }, status);
    }
    return c.json({
      caseId: result.caseId,
      expiresAt: result.expiresAt,
      templateId: result.templateId,
      locked: result.locked,
    });
  });

  app.post("/tenants", async (c) => {
    const body = createTenantBody.parse(await c.req.json());
    const [row] = await db
      .insert(tenants)
      .values({ displayName: body.displayName, jurisdiction: env.JURISDICTION })
      .returning();
    await writeAudit(db, {
      tenantId: row.id,
      actor: "system",
      action: "tenant.created",
    });
    return c.json(row, 201);
  });

  app.get("/tenants/:tenantId/cases", async (c) => {
    const tenantId = c.req.param("tenantId");
    const rows = await db.select().from(cases).where(eq(cases.tenantId, tenantId));
    return c.json({ cases: rows });
  });

  app.post("/cases", async (c) => {
    const body = createCaseBody.parse(await c.req.json());
    const [row] = await db
      .insert(cases)
      .values({
        tenantId: body.tenantId,
        parentEmail: body.parentEmail ?? undefined,
        childDisplayName: body.childDisplayName ?? undefined,
        status: "intake_pending",
      })
      .returning();
    await writeAudit(db, {
      tenantId: body.tenantId,
      caseId: row.id,
      actor: "clinician",
      action: "case.created",
    });
    return c.json(row, 201);
  });

  app.get("/cases/:caseId", async (c) => {
    const caseId = c.req.param("caseId");
    const [row] = await db.select().from(cases).where(eq(cases.id, caseId));
    if (!row) return c.json({ error: "not_found" }, 404);

    const [intake] = await db
      .select()
      .from(intakeSubmissions)
      .where(eq(intakeSubmissions.caseId, caseId));

    const drafts = await db.select().from(aiDrafts).where(eq(aiDrafts.caseId, caseId));

    // Stage-3 intake review: record that the case detail was opened (IDs only, no PHI).
    await writeAudit(db, { tenantId: row.tenantId, caseId, actor: "clinician", action: "case.viewed" });

    return c.json({ case: row, intake: intake ?? null, drafts });
  });

  app.put("/cases/:caseId/intake/draft", async (c) => {
    const caseId = c.req.param("caseId");
    const body = saveIntakeDraftBody.parse(await c.req.json());

    const [existing] = await db.select().from(cases).where(eq(cases.id, caseId));
    if (!existing) return c.json({ error: "not_found" }, 404);
    if (existing.status !== "intake_pending") {
      return c.json({ error: "intake_already_submitted" }, 409);
    }
    if (!(await assertIntakeNotLocked(db, caseId))) {
      return c.json({ error: "intake_locked" }, 409);
    }

    const intake = await upsertIntakeDraft(db, caseId, body.answers, {
      parentEmail: body.parentEmail ?? undefined,
      childDisplayName: body.childDisplayName ?? undefined,
    });

    await writeAudit(db, {
      tenantId: existing.tenantId,
      caseId,
      actor: "parent",
      action: "intake.draft_saved",
      metadata: { step: body.answers.formStep ?? null },
    });

    return c.json({ ok: true, intake });
  });

  app.post("/cases/:caseId/intake", async (c) => {
    const caseId = c.req.param("caseId");
    const body = submitIntakeBody.parse(await c.req.json());

    const [existing] = await db.select().from(cases).where(eq(cases.id, caseId));
    if (!existing) return c.json({ error: "not_found" }, 404);
    if (existing.status !== "intake_pending") {
      return c.json({ error: "intake_already_submitted" }, 409);
    }
    if (!(await assertIntakeNotLocked(db, caseId))) {
      return c.json({ error: "intake_locked" }, 409);
    }

    const intake = await submitIntakeRecord(
      db,
      caseId,
      body.answers,
      body.consentVersion,
      {
        parentEmail: body.parentEmail ?? undefined,
        childDisplayName: body.childDisplayName ?? undefined,
      },
    );

    const [updated] = await db
      .update(cases)
      .set({
        status: "intake_submitted",
        parentEmail: body.parentEmail ?? existing.parentEmail,
        childDisplayName: body.childDisplayName ?? existing.childDisplayName,
        updatedAt: new Date(),
      })
      .where(eq(cases.id, caseId))
      .returning();

    await writeAudit(db, {
      tenantId: existing.tenantId,
      caseId,
      actor: "parent",
      action: "intake.submitted",
    });

    await db
      .update(cases)
      .set({ status: "prep_drafting", updatedAt: new Date() })
      .where(eq(cases.id, caseId));

    try {
      await enqueueLlmPrep(env, { caseId });
    } catch (err) {
      logger.warn("llm_prep.enqueue_failed_stub_prep_still_runs", { caseId, err });
    }
    await draftPrepBrief(db, caseId, env);

    const [afterPrep] = await db.select().from(cases).where(eq(cases.id, caseId));

    return c.json({ case: afterPrep ?? updated, intake }, 201);
  });

  app.post("/cases/:caseId/triage", async (c) => {
    const caseId = c.req.param("caseId");
    const body = triageBody.parse(await c.req.json());

    const [existing] = await db.select().from(cases).where(eq(cases.id, caseId));
    if (!existing) return c.json({ error: "not_found" }, 404);

    const [triage] = await db
      .insert(triageRecords)
      .values({ caseId, outcome: body.outcome, reason: body.reason })
      .returning();

    const [updated] = await db
      .update(cases)
      .set({ status: "triaged", updatedAt: new Date() })
      .where(eq(cases.id, caseId))
      .returning();

    await writeAudit(db, {
      tenantId: existing.tenantId,
      caseId,
      actor: "clinician",
      action: "triage.recorded",
      metadata: { outcome: body.outcome },
    });

    await draftSessionPlanStub(db, caseId, env);
    const [afterPlan] = await db.select().from(cases).where(eq(cases.id, caseId));

    return c.json({ case: afterPlan ?? updated, triage });
  });

  app.post("/cases/:caseId/parent-summary/publish", async (c) => {
    const caseId = c.req.param("caseId");
    const body = publishParentSummaryBody.parse(
      (await c.req.json().catch(() => ({}))) as unknown,
    );

    const result = await publishParentSummary(db, caseId, body.htmlBody, env);
    if (!result.ok) {
      const status = result.error === "not_found" ? 404 : 400;
      return c.json({ error: result.error }, status);
    }

    return c.json({
      case: result.case,
      viewPath: result.viewPath,
      message: "Published to portal (no email). Parent opens case ID in demo app.",
    });
  });

  app.get("/cases/:caseId/parent-summary", async (c) => {
    const caseId = c.req.param("caseId");
    const result = await getPublishedParentSummary(db, caseId);
    if (!result.ok) {
      if (result.error === "not_found") return c.json({ error: result.error }, 404);
      return c.json({ error: result.error, status: result.status }, 404);
    }
    return c.html(result.html);
  });

  // ── Stage 9 · Carryover ────────────────────────────────────────────────
  // Clinician-side resource/progress management plus a token-only family
  // portal. Same MVP auth posture as the other case routes above (demo).

  const portalRejectionStatus = (error: "not_found" | "expired" | "revoked") =>
    error === "not_found" ? 404 : 410;

  app.post("/cases/:caseId/carryover/resources", async (c) => {
    const caseId = c.req.param("caseId");
    const body = createCarryoverResourceBody.parse(await c.req.json());
    const result = await createCarryoverResource(db, caseId, body);
    if (!result.ok) return c.json({ error: result.error }, 404);
    return c.json({ resource: result.resource }, 201);
  });

  app.get("/cases/:caseId/carryover/resources", async (c) => {
    const caseId = c.req.param("caseId");
    const [existing] = await db.select().from(cases).where(eq(cases.id, caseId));
    if (!existing) return c.json({ error: "not_found" }, 404);
    const resources = await listCarryoverResources(db, caseId);
    return c.json({ resources });
  });

  app.patch("/cases/:caseId/carryover/resources/:resourceId", async (c) => {
    const caseId = c.req.param("caseId");
    const resourceId = c.req.param("resourceId");
    const body = updateCarryoverResourceBody.parse(await c.req.json());
    const result = await updateCarryoverResource(db, caseId, resourceId, body);
    if (!result.ok) return c.json({ error: result.error }, 404);
    return c.json({ resource: result.resource });
  });

  app.delete("/cases/:caseId/carryover/resources/:resourceId", async (c) => {
    const caseId = c.req.param("caseId");
    const resourceId = c.req.param("resourceId");
    const result = await deleteCarryoverResource(db, caseId, resourceId);
    if (!result.ok) return c.json({ error: result.error }, 404);
    return c.body(null, 204);
  });

  app.get("/cases/:caseId/carryover/progress", async (c) => {
    const caseId = c.req.param("caseId");
    const [existing] = await db.select().from(cases).where(eq(cases.id, caseId));
    if (!existing) return c.json({ error: "not_found" }, 404);
    const entries = await listProgressEntries(db, caseId);
    return c.json({ entries });
  });

  app.post("/cases/:caseId/carryover/progress", async (c) => {
    const caseId = c.req.param("caseId");
    const body = createProgressEntryBody.parse(await c.req.json());
    const result = await addProgressEntry(db, caseId, "clinician", body);
    if (!result.ok) return c.json({ error: result.error }, 404);
    return c.json({ entry: result.entry }, 201);
  });

  app.post("/cases/:caseId/portal-links", async (c) => {
    const caseId = c.req.param("caseId");
    const result = await createPortalLink(db, caseId);
    if (!result.ok) return c.json({ error: result.error }, 404);
    return c.json({ token: result.token, expiresAt: result.expiresAt }, 201);
  });

  app.post("/cases/:caseId/portal-links/revoke", async (c) => {
    const caseId = c.req.param("caseId");
    const result = await revokePortalLinks(db, caseId);
    if (!result.ok) return c.json({ error: result.error }, 404);
    return c.body(null, 204);
  });

  app.get("/portal/:token", async (c) => {
    const token = c.req.param("token");
    const result = await getPortalPayload(db, token);
    if (!result.ok) return c.json({ error: result.error }, portalRejectionStatus(result.error));
    return c.json(result.payload);
  });

  app.post("/portal/:token/progress", async (c) => {
    const token = c.req.param("token");
    const body = createProgressEntryBody.parse(await c.req.json());
    const link = await resolvePortalLink(db, token);
    if (!link.ok) return c.json({ error: link.error }, portalRejectionStatus(link.error));
    const result = await addProgressEntry(db, link.caseId, "parent", body);
    if (!result.ok) return c.json({ error: result.error }, 404);
    return c.json({ entry: result.entry }, 201);
  });

  app.get("/tenants/:tenantId/clinical-reports", async (c) => {
    const tenantId = c.req.param("tenantId");
    const items = await listTenantClinicalReports(db, tenantId);
    return c.json({ items });
  });

  app.post("/cases/:caseId/clinical-report/generate", async (c) => {
    const caseId = c.req.param("caseId");
    const result = await draftClinicalReportStub(db, caseId);
    if (!result.ok) {
      const status = result.error === "not_found" ? 404 : 409;
      return c.json({ error: result.error }, status);
    }
    return c.json({ draft: result.draft, alreadyExists: result.alreadyExists ?? false });
  });

  app.get("/cases/:caseId/clinical-report", async (c) => {
    const caseId = c.req.param("caseId");
    const result = await getClinicalReportDraft(db, caseId);
    if (!result.ok) return c.json({ error: result.error }, 404);
    return c.json({
      caseId,
      content: result.content,
      reviewedAt: result.draft.reviewedAt?.toISOString() ?? null,
      createdAt: result.draft.createdAt.toISOString(),
    });
  });

  app.get("/cases/:caseId/clinical-report.pdf", async (c) => {
    const caseId = c.req.param("caseId");
    const result = await renderClinicalReportPdfForCase(db, caseId);
    if (!result.ok) return c.json({ error: result.error }, 404);
    const name = (result.content.childDisplayName || "child").replace(/[^a-zA-Z0-9_-]+/g, "_");
    return c.body(Buffer.from(result.pdf), 200, {
      "Content-Type": "application/pdf",
      "Content-Disposition": `attachment; filename="clinical-report-${name}.pdf"`,
    });
  });


  app.get("/clinicians/me/availability", async (c) => {
    const tenantId = c.req.query("tenantId");
    if (!tenantId) return c.json({ error: "tenant_id_required" }, 400);
    const from = c.req.query("from") ?? new Date().toISOString();
    const to =
      c.req.query("to") ??
      new Date(Date.now() + 14 * 24 * 60 * 60 * 1000).toISOString();
    await ensureDefaultAvailability(db, tenantId);
    const slots = await getAvailabilitySlots(db, tenantId, from, to);
    return c.json({ slots });
  });

  app.get("/clinicians/me/availability/rules", async (c) => {
    const tenantId = c.req.query("tenantId");
    if (!tenantId) return c.json({ error: "tenant_id_required" }, 400);
    await ensureDefaultAvailability(db, tenantId);
    const rules = await listAvailabilityRules(db, tenantId);
    return c.json({ rules });
  });

  app.put("/clinicians/me/availability/rules", async (c) => {
    const body = putAvailabilityRulesBody.parse(await c.req.json());
    const rules = await replaceAvailabilityRules(db, body.tenantId, body.rules);
    return c.json({ rules });
  });

  app.post("/cases/:caseId/consult", async (c) => {
    const caseId = c.req.param("caseId");
    const body = bookConsultBody.parse(await c.req.json());
    const result = await bookConsult(db, caseId, body.start, body.durationMinutes);
    if (!result.ok) {
      const status = result.error === "not_found" ? 404 : result.error === "slot_taken" ? 409 : 422;
      return c.json({ error: result.error }, status);
    }
    return c.json({ case: result.case, consultAt: result.consultAt });
  });

  app.get("/cases/:caseId/consult.ics", async (c) => {
    const caseId = c.req.param("caseId");
    const [row] = await db.select().from(cases).where(eq(cases.id, caseId));
    if (!row || !row.consultAt) return c.json({ error: "not_found" }, 404);
    const ics = buildConsultIcs({
      childDisplayName: row.childDisplayName ?? "Client",
      consultAt: row.consultAt,
      durationMinutes: 20,
    });
    return c.body(ics, 200, { "Content-Type": "text/calendar; charset=utf-8" });
  });

  const demoBootstrapBody = z
    .object({
      practice: z.enum(["demo", "e2e"]).default("demo"),
    })
    .optional();

  /** Demo bootstrap: stable tenant per practice variant (demo vs automated E2E). */
  app.post("/demo/bootstrap", async (c) => {
    const body = demoBootstrapBody.parse((await c.req.json().catch(() => ({}))) as unknown);
    const variant = (body?.practice ?? "demo") as PracticeVariant;
    const displayName = practiceDisplayName(variant);
    const [existing] = await db
      .select()
      .from(tenants)
      .where(
        and(eq(tenants.displayName, displayName), eq(tenants.jurisdiction, env.JURISDICTION)),
      )
      .limit(1);
    if (existing) {
      await ensureDefaultAvailability(db, existing.id);
      return c.json(
        { tenantId: existing.id, jurisdiction: existing.jurisdiction, practice: variant },
        200,
      );
    }
    const [row] = await db
      .insert(tenants)
      .values({ displayName, jurisdiction: env.JURISDICTION })
      .returning();
    return c.json({ tenantId: row.id, jurisdiction: row.jurisdiction, practice: variant }, 201);
  });

  /** Seed realistic canonical demo caseload (dev/stage only). */
  app.post("/demo/seed-canonical", async (c) => {
    if (!isDevMaintenanceAllowed(env)) {
      return c.json({ error: "forbidden" }, 403);
    }
    const body = demoBootstrapBody.parse((await c.req.json().catch(() => ({}))) as unknown);
    const variant = (body?.practice ?? "demo") as PracticeVariant;
    const result = await seedCanonicalDemoPractice(db, env, variant);
    await ensureDefaultAvailability(db, result.tenantId);
    return c.json(result);
  });


  /** Remove legacy E2E / ephemeral test cases (hosted dev only). */
  app.post("/demo/cleanup-e2e-test-cases", async (c) => {
    if (!isDevMaintenanceAllowed(env)) {
      return c.json({ error: "forbidden" }, 403);
    }
    const dryRun = c.req.query("dryRun") === "true";
    const result = await cleanupE2eTestCases(db, { dryRun });
    return c.json(result);
  });

  return app;
}
