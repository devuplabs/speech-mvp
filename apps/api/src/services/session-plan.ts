import { eq } from "drizzle-orm";
import type { Env } from "../config.js";
import type { Db } from "../db/client.js";
import { aiDrafts, cases, triageRecords } from "../db/schema.js";
import { buildIntakeContextForLlm, generateSessionPlanLlm } from "../llm/generate-drafts.js";
import { writeAudit } from "./audit.js";
import { loadIntakeAnswers } from "./intake-context.js";
import { buildSessionPlanStubContent } from "./stub-draft-content.js";

export async function draftSessionPlanStub(db: Db, caseId: string, env?: Env) {
  const [row] = await db.select().from(cases).where(eq(cases.id, caseId));
  if (!row) return { ok: false as const, error: "not_found" };

  const existing = await db.select().from(aiDrafts).where(eq(aiDrafts.caseId, caseId));
  if (existing.some((d) => d.kind === "session_plan")) {
    return { ok: true as const, alreadyExists: true };
  }

  const answers = await loadIntakeAnswers(db, caseId);
  const intakeContext = buildIntakeContextForLlm(answers);
  const childName = row.childDisplayName ?? (answers.childName as string) ?? "Child";

  const [triage] = await db
    .select()
    .from(triageRecords)
    .where(eq(triageRecords.caseId, caseId))
    .limit(1);

  let content: Record<string, unknown> = buildSessionPlanStubContent({
    childDisplayName: childName,
    mainConcern: answers.mainConcern as string | undefined,
  });
  let modelId = "mvp-stub";

  if (env) {
    const llm = await generateSessionPlanLlm(env, {
      childDisplayName: childName,
      intakeContext,
      triageOutcome: triage?.outcome ?? "short_block",
      mainConcern: answers.mainConcern as string | undefined,
      difficulties: answers.difficulties as string[] | undefined,
    });
    if (llm) {
      content = llm.content;
      modelId = llm.modelId;
    }
  }

  const [draft] = await db
    .insert(aiDrafts)
    .values({
      caseId,
      kind: "session_plan",
      content,
      modelId,
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
    metadata: { modelId },
  });

  return { ok: true as const, draft };
}
