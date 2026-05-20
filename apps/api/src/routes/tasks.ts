import { eq } from "drizzle-orm";
import { Hono } from "hono";
import { z } from "zod";
import type { Db } from "../db/client.js";
import { aiDrafts, cases } from "../db/schema.js";
import { writeAudit } from "../services/audit.js";

const llmPrepBody = z.object({
  caseId: z.string().uuid(),
});

/** Stub prep brief until phase-2 inference is live. */
export function createTaskRoutes(db: Db) {
  const app = new Hono();

  app.post("/llm-prep", async (c) => {
    const body = llmPrepBody.parse(await c.req.json());
    const [row] = await db.select().from(cases).where(eq(cases.id, body.caseId));
    if (!row) return c.json({ error: "not_found" }, 404);

    const stubContent = {
      label: "DRAFT — clinician must review",
      probeAreas: [
        "Confirm primary concern and onset from intake answers",
        "Check red flags (feeding, hearing, regression)",
        "EHCP status if indicated in intake",
      ],
      source: "mvp_stub",
    };

    const [draft] = await db
      .insert(aiDrafts)
      .values({
        caseId: body.caseId,
        kind: "prep_brief",
        content: stubContent,
        modelId: "mvp-stub",
      })
      .returning();

    await db
      .update(cases)
      .set({ status: "prep_ready", updatedAt: new Date() })
      .where(eq(cases.id, body.caseId));

    await writeAudit(db, {
      tenantId: row.tenantId,
      caseId: body.caseId,
      actor: "worker",
      action: "prep_brief.drafted",
    });

    return c.json({ ok: true, draft });
  });

  return app;
}
