import { eq } from "drizzle-orm";
import type { Db } from "../db/client.js";
import { cases, intakeSubmissions } from "../db/schema.js";
import type { IntakeAnswers } from "../schemas/intake.js";

export async function upsertIntakeDraft(
  db: Db,
  caseId: string,
  answers: IntakeAnswers,
  meta?: { parentEmail?: string; childDisplayName?: string },
) {
  const [existing] = await db
    .select()
    .from(intakeSubmissions)
    .where(eq(intakeSubmissions.caseId, caseId));

  if (existing) {
    const [row] = await db
      .update(intakeSubmissions)
      .set({ answers })
      .where(eq(intakeSubmissions.id, existing.id))
      .returning();
    if (meta?.parentEmail || meta?.childDisplayName) {
      await db
        .update(cases)
        .set({
          parentEmail: meta.parentEmail,
          childDisplayName: meta.childDisplayName,
          updatedAt: new Date(),
        })
        .where(eq(cases.id, caseId));
    }
    return row;
  }

  const [row] = await db
    .insert(intakeSubmissions)
    .values({ caseId, answers, submittedAt: null })
    .returning();

  if (meta?.parentEmail || meta?.childDisplayName) {
    await db
      .update(cases)
      .set({
        parentEmail: meta.parentEmail,
        childDisplayName: meta.childDisplayName,
        updatedAt: new Date(),
      })
      .where(eq(cases.id, caseId));
  }

  return row;
}

export async function submitIntake(
  db: Db,
  caseId: string,
  answers: IntakeAnswers,
  consentVersion?: string,
  meta?: { parentEmail?: string; childDisplayName?: string },
) {
  const [existing] = await db
    .select()
    .from(intakeSubmissions)
    .where(eq(intakeSubmissions.caseId, caseId));

  const submittedAt = new Date();

  // completionDate is no longer collected from the client; derive it server-side
  // so the clinician dashboard continues to receive the expected field.
  if (!answers.completionDate) {
    const d = submittedAt.getDate().toString().padStart(2, "0");
    const m = (submittedAt.getMonth() + 1).toString().padStart(2, "0");
    const y = submittedAt.getFullYear();
    answers = { ...answers, completionDate: `${d} / ${m} / ${y}` };
  }

  let intake;

  if (existing) {
    [intake] = await db
      .update(intakeSubmissions)
      .set({ answers, consentVersion, submittedAt })
      .where(eq(intakeSubmissions.id, existing.id))
      .returning();
  } else {
    [intake] = await db
      .insert(intakeSubmissions)
      .values({ caseId, answers, consentVersion, submittedAt })
      .returning();
  }

  return intake;
}
