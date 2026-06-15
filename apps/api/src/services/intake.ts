import { eq } from "drizzle-orm";
import type { Db } from "../db/client.js";
import { cases, intakeSubmissions } from "../db/schema.js";
import type { IntakeAnswers } from "../schemas/intake.js";
import { parseIntakeDateToIso, splitFullName } from "./register-patient.js";

/**
 * Derive the structured FHIR demographics (ADR-006 §5 P0) from intake answers so
 * a parent-submitted form populates `cases` for the export. Only returns fields
 * that are actually present — absent fields stay absent (the mapper never
 * guesses). The parent contact prefers the mother's name, then the father's.
 */
export function deriveDemographicsFromAnswers(answers: IntakeAnswers): {
  childGivenName?: string;
  childFamilyName?: string;
  childDob?: string;
  parentGivenName?: string;
  parentFamilyName?: string;
} {
  const child = splitFullName(answers.childName);
  const parentSource = answers.motherName ?? answers.fatherName ?? answers.completedBy;
  const parent = splitFullName(parentSource);
  const result: ReturnType<typeof deriveDemographicsFromAnswers> = {};
  if (child.given) result.childGivenName = child.given;
  if (child.family) result.childFamilyName = child.family;
  const dob = parseIntakeDateToIso(answers.dateOfBirth);
  if (dob) result.childDob = dob;
  if (parent.given) result.parentGivenName = parent.given;
  if (parent.family) result.parentFamilyName = parent.family;
  return result;
}

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
