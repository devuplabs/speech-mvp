import { randomBytes } from "node:crypto";
import { and, eq, gt } from "drizzle-orm";
import type { Db } from "../db/client.js";
import { caseIntakeLinks, cases, intakeSubmissions } from "../db/schema.js";
import type { RegisterPatientBody } from "../schemas/register-patient.js";
import { REFERRAL_SOURCE_LABELS } from "../schemas/register-patient.js";
import { upsertIntakeDraft } from "./intake.js";
import { writeAudit } from "./audit.js";
import { bookConsult } from "./consult-booking.js";

const LINK_TTL_DAYS = 14;

function newToken(): string {
  return randomBytes(32).toString("base64url");
}

function linkExpiresAt(): Date {
  const d = new Date();
  d.setDate(d.getDate() + LINK_TTL_DAYS);
  return d;
}

export type IntakeLinkRejection = "not_found" | "expired";

/**
 * Pure expiry check for intake links (mirrors resolvePortalLinkState in
 * portal-links.ts). Revoking an intake link sets `expiresAt = now`, so the
 * revoked path surfaces as "expired" here by design.
 */
export function resolveIntakeLinkState(
  link: { expiresAt: Date } | null | undefined,
  now: Date = new Date(),
): { ok: true } | { ok: false; error: IntakeLinkRejection } {
  if (!link) return { ok: false, error: "not_found" };
  if (link.expiresAt <= now) return { ok: false, error: "expired" };
  return { ok: true };
}

export function buildIntakeLinkUrl(webBaseUrl: string, token: string): string {
  const base = webBaseUrl.replace(/\/$/, "");
  return `${base}/?t=${encodeURIComponent(token)}`;
}

export async function findActiveRegistration(
  db: Db,
  tenantId: string,
  parentEmail: string,
  childDisplayName: string,
) {
  const now = new Date();
  const rows = await db
    .select({ case: cases, link: caseIntakeLinks })
    .from(cases)
    .innerJoin(caseIntakeLinks, eq(caseIntakeLinks.caseId, cases.id))
    .where(
      and(
        eq(cases.tenantId, tenantId),
        eq(cases.parentEmail, parentEmail),
        eq(cases.childDisplayName, childDisplayName),
        eq(cases.status, "intake_pending"),
        gt(caseIntakeLinks.expiresAt, now),
      ),
    )
    .limit(1);
  return rows[0] ?? null;
}

export async function registerPatient(
  db: Db,
  body: RegisterPatientBody,
  webBaseUrl: string,
) {
  const childDisplayName = body.childFirstName.trim();
  const parentEmail = body.parentEmail.trim().toLowerCase();

  const existing = await findActiveRegistration(
    db,
    body.tenantId,
    parentEmail,
    childDisplayName,
  );
  if (existing) {
    let consultBooking = null as { consultAt: string } | null;
    if (body.bookConsult) {
      const duration = body.bookConsult.durationMinutes ?? 20;
      const booked = await bookConsult(db, existing.case.id, body.bookConsult.start, duration);
      if (booked.ok) consultBooking = { consultAt: booked.consultAt };
    }
    return {
      case: existing.case,
      intakeLink: {
        url: buildIntakeLinkUrl(webBaseUrl, existing.link.token),
        expiresAt: existing.link.expiresAt.toISOString(),
        token: existing.link.token,
      },
      consultBooking,
      idempotent: true as const,
    };
  }

  const [caseRow] = await db
    .insert(cases)
    .values({
      tenantId: body.tenantId,
      parentEmail,
      parentPhone: body.parentPhone?.trim() || undefined,
      childDisplayName,
      referralSource: body.referralSource,
      status: "intake_pending",
    })
    .returning();

  const referralLabel = REFERRAL_SOURCE_LABELS[body.referralSource];
  await upsertIntakeDraft(
    db,
    caseRow.id,
    {
      version: 1,
      childName: childDisplayName,
      dateOfBirth: body.dateOfBirth,
      email: parentEmail,
      completedBy: body.parentName.trim(),
      referredBy: referralLabel,
      mainConcern: body.initialConcerns?.trim() ?? "",
      formStep: 1,
    },
    { parentEmail, childDisplayName },
  );

  let linkRow: typeof caseIntakeLinks.$inferSelect | undefined;

  if (body.sendIntakeLink) {
    const expiresAt = linkExpiresAt();
    for (let attempt = 0; attempt < 3; attempt++) {
      try {
        [linkRow] = await db
          .insert(caseIntakeLinks)
          .values({
            caseId: caseRow.id,
            token: newToken(),
            expiresAt,
            templateId: body.templateId ?? "full",
          })
          .returning();
        break;
      } catch (err) {
        const msg = err instanceof Error ? err.message : "";
        if (!msg.includes("unique") || attempt === 2) throw err;
      }
    }
  }

  await writeAudit(db, {
    tenantId: body.tenantId,
    caseId: caseRow.id,
    actor: "clinician",
    action: "patient.registered",
    metadata: {
      referralSource: body.referralSource,
      sendIntakeLink: body.sendIntakeLink,
    },
  });

  let consultBooking: { consultAt: string } | null = null;
  if (body.bookConsult) {
    const duration = body.bookConsult.durationMinutes ?? 20;
    const booked = await bookConsult(db, caseRow.id, body.bookConsult.start, duration);
    if (booked.ok) {
      consultBooking = { consultAt: booked.consultAt };
    }
  }

  return {
    case: (consultBooking
      ? (await db.select().from(cases).where(eq(cases.id, caseRow.id)))[0]
      : caseRow),
    intakeLink: linkRow
      ? {
          url: buildIntakeLinkUrl(webBaseUrl, linkRow.token),
          expiresAt: linkRow.expiresAt.toISOString(),
          token: linkRow.token,
        }
      : null,
    consultBooking,
    idempotent: false as const,
  };
}

export async function resolveIntakeLinkToken(db: Db, token: string) {
  const [row] = await db
    .select()
    .from(caseIntakeLinks)
    .where(eq(caseIntakeLinks.token, token))
    .limit(1);

  if (!row) {
    // Failed-resolve audit event (DEV-31). No tenant/case context exists for an
    // unknown token; never store the token itself (it is the secret).
    await writeAudit(db, {
      actor: "parent",
      action: "intake_link.resolve_failed",
      metadata: { reason: "not_found" },
    });
    return { ok: false as const, error: "not_found" as const };
  }

  const now = new Date();
  const state = resolveIntakeLinkState(row, now);
  if (!state.ok) {
    await writeAudit(db, {
      caseId: row.caseId,
      actor: "parent",
      action: "intake_link.resolve_failed",
      metadata: { reason: state.error },
    });
    return { ok: false as const, error: state.error };
  }

  if (!row.usedAt) {
    await db
      .update(caseIntakeLinks)
      .set({ usedAt: now })
      .where(eq(caseIntakeLinks.id, row.id));
  }

  const [intake] = await db
    .select({ locked: intakeSubmissions.locked })
    .from(intakeSubmissions)
    .where(eq(intakeSubmissions.caseId, row.caseId));

  return {
    ok: true as const,
    caseId: row.caseId,
    expiresAt: row.expiresAt.toISOString(),
    templateId: row.templateId ?? "full",
    locked: intake?.locked ?? false,
  };
}
