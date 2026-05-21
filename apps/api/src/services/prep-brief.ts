import { eq } from "drizzle-orm";
import type { Db } from "../db/client.js";
import { aiDrafts, cases } from "../db/schema.js";
import { writeAudit } from "./audit.js";

/** MVP stub prep brief (phase-2 replaces with real LLM). */
export async function draftPrepBrief(db: Db, caseId: string) {
  const [row] = await db.select().from(cases).where(eq(cases.id, caseId));
  if (!row) return { ok: false as const, error: "not_found" };

  const existing = await db
    .select()
    .from(aiDrafts)
    .where(eq(aiDrafts.caseId, caseId));

  if (existing.some((d) => d.kind === "prep_brief")) {
    return { ok: true as const, alreadyExists: true };
  }

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
      caseId,
      kind: "prep_brief",
      content: stubContent,
      modelId: "mvp-stub",
    })
    .returning();

  await db
    .update(cases)
    .set({ status: "prep_ready", updatedAt: new Date() })
    .where(eq(cases.id, caseId));

  await writeAudit(db, {
    tenantId: row.tenantId,
    caseId,
    actor: "worker",
    action: "prep_brief.drafted",
  });

  return { ok: true as const, draft, alreadyExists: false };
}
