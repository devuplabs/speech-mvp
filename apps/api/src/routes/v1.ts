import { and, eq } from "drizzle-orm";
import { Hono } from "hono";
import { z } from "zod";
import type { Env } from "../config.js";
import type { Db } from "../db/client.js";
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
import { writeAudit } from "../services/audit.js";
import { enqueueLlmPrep } from "../services/tasks.js";

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
      console.warn("enqueueLlmPrep failed (stub prep still runs):", err);
    }
    await draftPrepBrief(db, caseId);

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

    await draftSessionPlanStub(db, caseId);
    const [afterPlan] = await db.select().from(cases).where(eq(cases.id, caseId));

    return c.json({ case: afterPlan ?? updated, triage });
  });

  app.post("/cases/:caseId/parent-summary/publish", async (c) => {
    const caseId = c.req.param("caseId");
    const body = publishParentSummaryBody.parse(
      (await c.req.json().catch(() => ({}))) as unknown,
    );

    const result = await publishParentSummary(db, caseId, body.htmlBody);
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

  /** Demo bootstrap: reuse one demo tenant per jurisdiction (stable tenantId across sessions). */
  app.post("/demo/bootstrap", async (c) => {
    const displayName = "Demo practice";
    const [existing] = await db
      .select()
      .from(tenants)
      .where(
        and(eq(tenants.displayName, displayName), eq(tenants.jurisdiction, env.JURISDICTION)),
      )
      .limit(1);
    if (existing) {
      return c.json({ tenantId: existing.id, jurisdiction: existing.jurisdiction }, 200);
    }
    const [row] = await db
      .insert(tenants)
      .values({ displayName, jurisdiction: env.JURISDICTION })
      .returning();
    return c.json({ tenantId: row.id, jurisdiction: env.JURISDICTION }, 201);
  });

  return app;
}
