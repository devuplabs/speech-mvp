import { eq } from "drizzle-orm";
import type { Db } from "../db/client.js";
import { aiDrafts, cases } from "../db/schema.js";
import { writeAudit } from "./audit.js";

export async function draftSessionPlanStub(db: Db, caseId: string) {
  const [row] = await db.select().from(cases).where(eq(cases.id, caseId));
  if (!row) return { ok: false as const, error: "not_found" };

  const existing = await db.select().from(aiDrafts).where(eq(aiDrafts.caseId, caseId));
  if (existing.some((d) => d.kind === "session_plan")) {
    return { ok: true as const, alreadyExists: true };
  }

  const content = {
    label: "DRAFT — clinician must review",
    sections: {
      goals: ["Establish baseline for first session"],
      activities: ["Play-based observation", "Parent interview probes from prep brief"],
      homePractice: ["Short daily practice suggestion (clinician to refine)"],
      materials: ["Toys / pictures as appropriate"],
    },
    source: "mvp_stub",
  };

  const [draft] = await db
    .insert(aiDrafts)
    .values({
      caseId,
      kind: "session_plan",
      content,
      modelId: "mvp-stub",
    })
    .returning();

  await db
    .update(cases)
    .set({ status: "plan_ready", updatedAt: new Date() })
    .where(eq(cases.id, caseId));

  await writeAudit(db, {
    tenantId: row.tenantId,
    caseId,
    actor: "system",
    action: "session_plan.drafted",
  });

  return { ok: true as const, draft };
}
