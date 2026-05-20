import { eq } from "drizzle-orm";
import { Hono } from "hono";
import { z } from "zod";
import type { Env } from "../config.js";
import type { Db } from "../db/client.js";
import { aiDrafts, cases, intakeSubmissions, tenants, triageRecords } from "../db/schema.js";
import { writeAudit } from "../services/audit.js";
import { enqueueLlmPrep } from "../services/tasks.js";

const createTenantBody = z.object({
  displayName: z.string().min(1).max(255),
});

const createCaseBody = z.object({
  tenantId: z.string().uuid(),
  parentEmail: z.string().email().optional(),
  childDisplayName: z.string().max(128).optional(),
});

const submitIntakeBody = z.object({
  answers: z.record(z.unknown()),
  consentVersion: z.string().max(64).optional(),
  parentEmail: z.string().email().optional(),
  childDisplayName: z.string().max(128).optional(),
});

const triageBody = z.object({
  outcome: z.enum(["strategy_only", "short_block", "full_assessment", "refer_out"]),
  reason: z.string().max(2000).optional(),
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
        parentEmail: body.parentEmail,
        childDisplayName: body.childDisplayName,
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

  app.post("/cases/:caseId/intake", async (c) => {
    const caseId = c.req.param("caseId");
    const body = submitIntakeBody.parse(await c.req.json());

    const [existing] = await db.select().from(cases).where(eq(cases.id, caseId));
    if (!existing) return c.json({ error: "not_found" }, 404);

    const [intake] = await db
      .insert(intakeSubmissions)
      .values({
        caseId,
        answers: body.answers,
        consentVersion: body.consentVersion,
        submittedAt: new Date(),
      })
      .returning();

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

    await enqueueLlmPrep(env, { caseId });

    return c.json({ case: updated, intake }, 201);
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

    return c.json({ case: updated, triage });
  });

  return app;
}
