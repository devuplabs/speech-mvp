import { randomBytes } from "node:crypto";
import { and, desc, eq, gt } from "drizzle-orm";
import type { Db } from "../db/client.js";
import { caseIntakeLinks, cases, intakeSubmissions } from "../db/schema.js";
import type { IntakeTemplateId } from "../schemas/intake-template.js";
import { intakeTemplateIdEnum } from "../schemas/intake-template.js";
import { buildIntakeLinkUrl } from "./register-patient.js";
import { writeAudit } from "./audit.js";

const LINK_TTL_DAYS = 14;

function newToken(): string {
  return randomBytes(32).toString("base64url");
}

function linkExpiresAt(): Date {
  const d = new Date();
  d.setDate(d.getDate() + LINK_TTL_DAYS);
  return d;
}

export type IntakeFormListStatus = "sent" | "in_progress" | "submitted" | "expired";

export function deriveFormStatus(params: {
  submittedAt: Date | null;
  formStep: number;
  linkExpiresAt: Date | null;
  hasIntakeRow: boolean;
}): IntakeFormListStatus {
  const now = new Date();
  if (params.submittedAt) return "submitted";
  if (params.linkExpiresAt && params.linkExpiresAt <= now) return "expired";
  if (!params.hasIntakeRow) return "sent";
  if (params.formStep > 1) return "in_progress";
  return "sent";
}

export async function listTenantIntakeForms(db: Db, tenantId: string) {
  const rows = await db
    .select({
      case: cases,
      intake: intakeSubmissions,
    })
    .from(cases)
    .leftJoin(intakeSubmissions, eq(intakeSubmissions.caseId, cases.id))
    .where(eq(cases.tenantId, tenantId))
    .orderBy(desc(cases.updatedAt));

  const items = [];
  for (const row of rows) {
    const [latestLink] = await db
      .select()
      .from(caseIntakeLinks)
      .where(eq(caseIntakeLinks.caseId, row.case.id))
      .orderBy(desc(caseIntakeLinks.createdAt))
      .limit(1);

    const answers = (row.intake?.answers ?? {}) as Record<string, unknown>;
    const formStep = typeof answers.formStep === "number" ? answers.formStep : 1;
    const status = deriveFormStatus({
      submittedAt: row.intake?.submittedAt ?? null,
      formStep,
      linkExpiresAt: latestLink?.expiresAt ?? null,
      hasIntakeRow: row.intake != null,
    });

    items.push({
      caseId: row.case.id,
      childDisplayName: row.case.childDisplayName,
      caseStatus: row.case.status,
      dateOfBirth: typeof answers.dateOfBirth === "string" ? answers.dateOfBirth : null,
      status,
      lastActivityAt: (row.intake?.updatedAt ?? row.case.updatedAt).toISOString(),
      templateId: (latestLink?.templateId as IntakeTemplateId) ?? "full",
      locked: row.intake?.locked ?? false,
    });
  }

  return items;
}

export async function getActiveLinkForCase(db: Db, caseId: string) {
  const now = new Date();
  const [row] = await db
    .select()
    .from(caseIntakeLinks)
    .where(and(eq(caseIntakeLinks.caseId, caseId), gt(caseIntakeLinks.expiresAt, now)))
    .orderBy(desc(caseIntakeLinks.createdAt))
    .limit(1);
  return row ?? null;
}

export async function revokeIntakeLinks(db: Db, caseId: string) {
  const now = new Date();
  await db
    .update(caseIntakeLinks)
    .set({ expiresAt: now })
    .where(and(eq(caseIntakeLinks.caseId, caseId), gt(caseIntakeLinks.expiresAt, now)));
}

export async function resendIntakeLink(
  db: Db,
  caseId: string,
  webBaseUrl: string,
  templateId?: IntakeTemplateId,
) {
  const [caseRow] = await db.select().from(cases).where(eq(cases.id, caseId));
  if (!caseRow) return { ok: false as const, error: "not_found" as const };

  const tid = templateId ?? intakeTemplateIdEnum.parse(
    (await getActiveLinkForCase(db, caseId))?.templateId ?? "full",
  );

  await revokeIntakeLinks(db, caseId);

  const expiresAt = linkExpiresAt();
  const [linkRow] = await db
    .insert(caseIntakeLinks)
    .values({
      caseId,
      token: newToken(),
      expiresAt,
      templateId: tid,
    })
    .returning();

  await writeAudit(db, {
    tenantId: caseRow.tenantId,
    caseId,
    actor: "clinician",
    action: "intake_link.resent",
    metadata: { templateId: tid },
  });

  return {
    ok: true as const,
    url: buildIntakeLinkUrl(webBaseUrl, linkRow.token),
    expiresAt: linkRow.expiresAt.toISOString(),
    templateId: tid,
  };
}

export async function lockIntake(db: Db, caseId: string) {
  const [intake] = await db
    .select()
    .from(intakeSubmissions)
    .where(eq(intakeSubmissions.caseId, caseId));

  if (!intake) {
    await db.insert(intakeSubmissions).values({
      caseId,
      answers: { formStep: 1, version: 1 },
      locked: true,
    });
  } else {
    await db
      .update(intakeSubmissions)
      .set({ locked: true, updatedAt: new Date() })
      .where(eq(intakeSubmissions.id, intake.id));
  }

  const [caseRow] = await db.select().from(cases).where(eq(cases.id, caseId));
  if (caseRow) {
    await writeAudit(db, {
      tenantId: caseRow.tenantId,
      caseId,
      actor: "clinician",
      action: "intake.locked",
    });
  }

  return { ok: true as const };
}

export async function assertIntakeNotLocked(db: Db, caseId: string) {
  const [intake] = await db
    .select({ locked: intakeSubmissions.locked })
    .from(intakeSubmissions)
    .where(eq(intakeSubmissions.caseId, caseId));
  if (intake?.locked) return false;
  return true;
}
