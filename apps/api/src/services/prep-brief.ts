import { eq } from "drizzle-orm";
import type { Env } from "../config.js";
import type { Db } from "../db/client.js";
import { aiDrafts, cases } from "../db/schema.js";
import { buildIntakeContextForLlm, generatePrepBriefLlm } from "../llm/generate-drafts.js";
import { writeAudit } from "./audit.js";
import { loadIntakeAnswers } from "./intake-context.js";
import { buildPrepBriefStubContent } from "./stub-draft-content.js";

/** Prep brief after intake submit — LLM when configured, else MVP stub. */
export async function draftPrepBrief(db: Db, caseId: string, env?: Env) {
  const [row] = await db.select().from(cases).where(eq(cases.id, caseId));
  if (!row) return { ok: false as const, error: "not_found" };

  const existing = await db
    .select()
    .from(aiDrafts)
    .where(eq(aiDrafts.caseId, caseId));

  if (existing.some((d) => d.kind === "prep_brief")) {
    return { ok: true as const, alreadyExists: true };
  }

  const answers = await loadIntakeAnswers(db, caseId);
  const intakeContext = buildIntakeContextForLlm(answers);
  const childName = row.childDisplayName ?? (answers.childName as string) ?? "Child";

  let stubContent: Record<string, unknown> = buildPrepBriefStubContent({
    childDisplayName: childName,
    mainConcern: answers.mainConcern as string | undefined,
    ageAtReferral: answers.ageAtReferral as string | undefined,
  });
  let modelId = "mvp-stub";

  if (env) {
    const llm = await generatePrepBriefLlm(env, {
      childDisplayName: childName,
      intakeContext,
      mainConcern: answers.mainConcern as string | undefined,
      difficulties: answers.difficulties as string[] | undefined,
    });
    if (llm) {
      stubContent = llm.content;
      modelId = llm.modelId;
    }
  }

  const [draft] = await db
    .insert(aiDrafts)
    .values({
      caseId,
      kind: "prep_brief",
      content: stubContent,
      modelId,
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
    metadata: { modelId },
  });

  return { ok: true as const, draft, alreadyExists: false };
}
