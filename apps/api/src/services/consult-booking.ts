import { and, eq, isNotNull, ne } from "drizzle-orm";
import type { Db } from "../db/client.js";
import { cases } from "../db/schema.js";
import { getAvailabilitySlots, slotIsAvailable } from "./availability.js";
import { writeAudit } from "./audit.js";

/**
 * Statuses from which booking a consult advances the case to `consult_booked`
 * (Stage 5). Booking is optional, so we only advance a case that is sitting in
 * the prep window. A case that has already moved on (triaged and beyond) must
 * never be rewound by a (re-)booking, and a case still at `intake_pending`
 * (e.g. a consult booked during initial registration) must not skip intake.
 */
const CONSULT_BOOKING_ADVANCE_FROM = new Set(["prep_drafting", "prep_ready"]);

/**
 * Pure transition rule: given the case's current status, returns the status it
 * should hold after a consult is booked. Returns `null` when booking should not
 * change the status (so callers can skip the update). Unit-testable without a DB.
 */
export function statusAfterConsultBooked(currentStatus: string): "consult_booked" | null {
  return CONSULT_BOOKING_ADVANCE_FROM.has(currentStatus) ? "consult_booked" : null;
}

export async function bookConsult(
  db: Db,
  caseId: string,
  startIso: string,
  durationMinutes: number,
) {
  const [existing] = await db.select().from(cases).where(eq(cases.id, caseId));
  if (!existing) return { ok: false as const, error: "not_found" as const };

  const start = new Date(startIso);
  const end = new Date(start.getTime() + durationMinutes * 60 * 1000);
  const windowStart = new Date(start.getTime() - 24 * 60 * 60 * 1000);
  const windowEnd = new Date(end.getTime() + 24 * 60 * 60 * 1000);

  const slots = await getAvailabilitySlots(
    db,
    existing.tenantId,
    windowStart.toISOString(),
    windowEnd.toISOString(),
    caseId,
  );

  if (!slotIsAvailable(slots, start.toISOString())) {
    const inList = slots.some((s) => s.start === start.toISOString());
    if (!inList) return { ok: false as const, error: "outside_window" as const };
    return { ok: false as const, error: "slot_taken" as const };
  }

  const [collision] = await db
    .select()
    .from(cases)
    .where(
      and(
        eq(cases.tenantId, existing.tenantId),
        isNotNull(cases.consultAt),
        ne(cases.id, caseId),
        eq(cases.consultAt, start),
      ),
    )
    .limit(1);

  if (collision) return { ok: false as const, error: "slot_taken" as const };

  const nextStatus = statusAfterConsultBooked(existing.status);

  const [updated] = await db
    .update(cases)
    .set({
      consultAt: start,
      ...(nextStatus ? { status: nextStatus } : {}),
      updatedAt: new Date(),
    })
    .where(eq(cases.id, caseId))
    .returning();

  await writeAudit(db, {
    tenantId: existing.tenantId,
    caseId,
    actor: "clinician",
    action: "consult.booked",
    metadata: {
      start: startIso,
      durationMinutes,
      ...(nextStatus ? { statusFrom: existing.status, statusTo: nextStatus } : {}),
    },
  });

  return {
    ok: true as const,
    case: updated,
    consultAt: start.toISOString(),
  };
}

export function buildConsultIcs(params: {
  childDisplayName: string;
  consultAt: Date;
  durationMinutes: number;
}): string {
  const { childDisplayName, consultAt, durationMinutes } = params;
  const end = new Date(consultAt.getTime() + durationMinutes * 60 * 1000);

  const fmt = (d: Date) =>
    d
      .toISOString()
      .replace(/[-:]/g, "")
      .replace(/\.\d{3}/, "");

  const uid = `sona-consult-${consultAt.getTime()}@sona.app`;
  return [
    "BEGIN:VCALENDAR",
    "VERSION:2.0",
    "PRODID:-//Sona//Consult//EN",
    "BEGIN:VEVENT",
    `UID:${uid}`,
    `DTSTAMP:${fmt(new Date())}`,
    `DTSTART:${fmt(consultAt)}`,
    `DTEND:${fmt(end)}`,
    `SUMMARY:Free consult — ${childDisplayName.replace(/\n/g, " ")}`,
    "DESCRIPTION:20-minute free consultation (Sona MVP)",
    "END:VEVENT",
    "END:VCALENDAR",
  ].join("\r\n");
}
