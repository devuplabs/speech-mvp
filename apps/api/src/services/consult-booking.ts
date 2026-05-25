import { and, eq, isNotNull, ne } from "drizzle-orm";
import type { Db } from "../db/client.js";
import { cases } from "../db/schema.js";
import { getAvailabilitySlots, slotIsAvailable } from "./availability.js";
import { writeAudit } from "./audit.js";

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

  const [updated] = await db
    .update(cases)
    .set({ consultAt: start, updatedAt: new Date() })
    .where(eq(cases.id, caseId))
    .returning();

  await writeAudit(db, {
    tenantId: existing.tenantId,
    caseId,
    actor: "clinician",
    action: "consult.booked",
    metadata: { start: startIso, durationMinutes },
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
