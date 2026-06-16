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

/**
 * Parse a `dd / mm / yyyy` intake date into an ISO `YYYY-MM-DD` calendar date for
 * the `cases.child_dob` column (FHIR `Patient.birthDate`). Returns `undefined`
 * for anything that does not match the strict intake pattern rather than
 * guessing a date. Pure; no time zone applied (a birth date is a plain date).
 */
export function parseIntakeDateToIso(value: string | undefined): string | undefined {
  if (!value) return undefined;
  const m = /^(0[1-9]|[12][0-9]|3[01])\s*\/\s*(0[1-9]|1[0-2])\s*\/\s*((?:19|20)\d{2})$/.exec(
    value.trim(),
  );
  if (!m) return undefined;
  const [, dd, mm, yyyy] = m;
  // The regex only checks the shape (e.g. it accepts 31/02). Confirm the day
  // actually exists in that month/year — including leap years — by building a
  // UTC date and checking it round-trips, so impossible dates (31/02, 30/02,
  // 31/04, 29/02 in a common year) return undefined instead of a malformed ISO
  // string that would corrupt cases.child_dob / FHIR export / age derivation.
  const year = Number(yyyy);
  const month = Number(mm);
  const day = Number(dd);
  const dt = new Date(Date.UTC(year, month - 1, day));
  if (
    dt.getUTCFullYear() !== year ||
    dt.getUTCMonth() !== month - 1 ||
    dt.getUTCDate() !== day
  ) {
    return undefined;
  }
  return `${yyyy}-${mm}-${dd}`;
}

/**
 * Split a single free-text full name into structured given/family parts for a
 * FHIR `HumanName`. Conservative: the last whitespace-separated token is the
 * family name and everything before it is the given name(s). A single token is
 * treated as a given name only (family left absent). Returns `undefined` parts
 * for empty input — the mapper then emits no name rather than a fabricated one.
 */
export function splitFullName(value: string | undefined): {
  given?: string;
  family?: string;
} {
  const trimmed = value?.trim();
  if (!trimmed) return {};
  const parts = trimmed.split(/\s+/);
  if (parts.length === 1) return { given: parts[0] };
  const family = parts[parts.length - 1];
  const given = parts.slice(0, -1).join(" ");
  return { given, family };
}

export async function registerPatient(
  db: Db,
  body: RegisterPatientBody,
  webBaseUrl: string,
) {
  const childDisplayName = body.childFirstName.trim();
  const parentEmail = body.parentEmail.trim().toLowerCase();
  const childName = splitFullName(body.childFirstName);
  const parentName = splitFullName(body.parentName);
  const childDob = parseIntakeDateToIso(body.dateOfBirth);

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
      // Structured demographics for the FHIR export (DEV-27, ADR-006 §5 P0).
      childGivenName: childName.given,
      childFamilyName: childName.family,
      childDob,
      parentGivenName: parentName.given,
      parentFamilyName: parentName.family,
      // The registration form does not yet collect a coded relationship; default
      // to the most common case (a parent) rather than leaving it absent, since
      // the contact registering a child is overwhelmingly a parent. A dedicated
      // relationship picker is a follow-up (ADR-006 §5 P1 fidelity).
      parentRelationship: "parent",
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
