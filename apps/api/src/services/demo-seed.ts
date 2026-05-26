import { and, eq } from "drizzle-orm";
import type { Env } from "../config.js";
import type { Db } from "../db/client.js";
import { cases, tenants, triageRecords } from "../db/schema.js";
import { canonicalDemoPersonas, type DemoPersona } from "../demo/load-personas.js";
import { practiceDisplayName, type PracticeVariant } from "../demo/practice.js";
import { bookConsult } from "./consult-booking.js";
import { draftPrepBrief } from "./prep-brief.js";
import type { IntakeAnswers } from "../schemas/intake.js";
import { submitIntake, upsertIntakeDraft } from "./intake.js";
import { publishParentSummary } from "./parent-summary.js";
import { registerPatient } from "./register-patient.js";
import { draftSessionPlanStub } from "./session-plan.js";
import { writeAudit } from "./audit.js";

type Stage =
  | "intake_pending"
  | "intake_submitted"
  | "prep_ready"
  | "triaged"
  | "plan_ready"
  | "summary_sent";

const STAGE_ORDER: Stage[] = [
  "intake_pending",
  "intake_submitted",
  "prep_ready",
  "triaged",
  "plan_ready",
  "summary_sent",
];

function stageIndex(stage: Stage): number {
  return STAGE_ORDER.indexOf(stage);
}

async function findCanonicalCase(db: Db, tenantId: string, childDisplayName: string) {
  const [row] = await db
    .select()
    .from(cases)
    .where(and(eq(cases.tenantId, tenantId), eq(cases.childDisplayName, childDisplayName)))
    .limit(1);
  return row ?? null;
}

async function recordTriage(
  db: Db,
  env: Env,
  caseId: string,
  outcome: "strategy_only" | "short_block" | "full_assessment" | "refer_out",
  personaId: string,
) {
  await db.insert(triageRecords).values({
    caseId,
    outcome,
    reason: `Demo caseload (${personaId})`,
  });
  await db
    .update(cases)
    .set({ status: "triaged", updatedAt: new Date() })
    .where(eq(cases.id, caseId));
  await draftSessionPlanStub(db, caseId, env);
}

async function advanceCaseToStage(
  db: Db,
  env: Env,
  caseId: string,
  persona: DemoPersona,
  target: Stage,
) {
  const demo = persona.demo!;
  const childDisplayName = persona.childDisplayName;
  const answers = {
    ...persona.answers,
    formStep: 8,
    consentGuardian: true,
    consentPrivacy: true,
    consentAccurate: true,
  } as IntakeAnswers;

  if (target === "intake_pending") {
    await upsertIntakeDraft(
      db,
      caseId,
      { ...persona.answers, formStep: 3 } as IntakeAnswers,
      { parentEmail: persona.parentEmail, childDisplayName },
    );
    return;
  }

  await upsertIntakeDraft(db, caseId, answers, {
    parentEmail: persona.parentEmail,
    childDisplayName,
  });

  if (stageIndex(target) < stageIndex("intake_submitted")) return;

  await submitIntake(db, caseId, answers, "mvp-v1", {
    parentEmail: persona.parentEmail,
    childDisplayName,
  });
  await db
    .update(cases)
    .set({ status: "intake_submitted", updatedAt: new Date() })
    .where(eq(cases.id, caseId));
  await draftPrepBrief(db, caseId, env);

  if (stageIndex(target) < stageIndex("triaged")) return;

  await recordTriage(db, env, caseId, demo.triageOutcome, persona.id);

  if (stageIndex(target) < stageIndex("summary_sent")) return;

  await publishParentSummary(db, caseId, undefined, env);
}

async function ensureTenant(db: Db, env: Env, variant: PracticeVariant) {
  const displayName = practiceDisplayName(variant);
  const [existing] = await db
    .select()
    .from(tenants)
    .where(and(eq(tenants.displayName, displayName), eq(tenants.jurisdiction, env.JURISDICTION)))
    .limit(1);
  if (existing) return existing;
  const [row] = await db
    .insert(tenants)
    .values({ displayName, jurisdiction: env.JURISDICTION })
    .returning();
  return row!;
}

/** Idempotent canonical demo caseload (realistic names, no seed timestamps). */
export async function seedCanonicalDemoPractice(
  db: Db,
  env: Env,
  variant: PracticeVariant = "demo",
) {
  const personas = canonicalDemoPersonas();
  const webBaseUrl =
    env.SONA_WEB_BASE_URL ??
    (env.NODE_ENV === "development"
      ? "http://localhost:8080"
      : "https://sona-web-dev-3rhenudy6a-nw.a.run.app");

  const tenant = await ensureTenant(db, env, variant);
  const results: Array<{ personaId: string; caseId: string; created: boolean; stage: Stage }> =
    [];

  for (const persona of personas) {
    const demo = persona.demo!;
    const target = demo.targetStage as Stage;
    let created = false;
    let caseRow = await findCanonicalCase(db, tenant.id, persona.childDisplayName);

    if (!caseRow) {
      const reg = await registerPatient(
        db,
        {
          tenantId: tenant.id,
          childFirstName: persona.childDisplayName.replace(/\.$/, ""),
          dateOfBirth: (persona.answers.dateOfBirth as string) ?? "01 / 01 / 2020",
          parentName: demo.parentName,
          parentEmail: persona.parentEmail,
          parentPhone: demo.parentPhone,
          referralSource: demo.referralSource,
          initialConcerns: demo.initialConcerns,
          sendIntakeLink: false,
          templateId: "full",
        },
        webBaseUrl,
      );
      caseRow = reg.case;
      created = true;

      if (demo.consultInHours != null) {
        const start = new Date(Date.now() + demo.consultInHours * 60 * 60 * 1000);
        start.setMinutes(0, 0, 0);
        await bookConsult(db, caseRow.id, start.toISOString(), 30);
      }

      await writeAudit(db, {
        tenantId: tenant.id,
        caseId: caseRow.id,
        actor: "system",
        action: "demo.canonical_seeded",
        metadata: { personaId: persona.id },
      });
    }

    await advanceCaseToStage(db, env, caseRow.id, persona, target);
    results.push({
      personaId: persona.id,
      caseId: caseRow.id,
      created,
      stage: target,
    });
  }

  return { tenantId: tenant.id, displayName: practiceDisplayName(variant), cases: results };
}
