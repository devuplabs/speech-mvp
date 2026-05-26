import { eq } from "drizzle-orm";
import type { Db } from "../db/client.js";
import { intakeSubmissions } from "../db/schema.js";

export async function loadIntakeAnswers(
  db: Db,
  caseId: string,
): Promise<Record<string, unknown>> {
  const [intake] = await db
    .select()
    .from(intakeSubmissions)
    .where(eq(intakeSubmissions.caseId, caseId));
  return (intake?.answers ?? {}) as Record<string, unknown>;
}
