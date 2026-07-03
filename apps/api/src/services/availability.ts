import { and, eq, gte, lte, ne, isNotNull } from "drizzle-orm";
import type { Db } from "../db/client.js";
import { cases, clinicianAvailability } from "../db/schema.js";

const SLOT_STEP_MINUTES = 30;
const DEFAULT_TZ = "Europe/London";

const WEEKDAY_MAP: Record<string, number> = {
  Mon: 1,
  Tue: 2,
  Wed: 3,
  Thu: 4,
  Fri: 5,
  Sat: 6,
  Sun: 7,
};

export type AvailabilityRule = {
  weekday: number;
  startMinuteLocal: number;
  endMinuteLocal: number;
  timezone: string;
  active: boolean;
};

export type ConsultSlot = {
  start: string;
  end: string;
  available: boolean;
};

export function getZonedParts(date: Date, timeZone: string) {
  const formatter = new Intl.DateTimeFormat("en-US", {
    timeZone,
    weekday: "short",
    hour: "numeric",
    minute: "numeric",
    hour12: false,
  });
  const parts = formatter.formatToParts(date);
  const map: Record<string, string> = {};
  for (const p of parts) {
    if (p.type !== "literal") map[p.type] = p.value;
  }
  const weekday = WEEKDAY_MAP[map.weekday] ?? 0;
  const hour = Number(map.hour);
  const minute = Number(map.minute);
  return { weekday, minuteOfDay: hour * 60 + minute };
}

export function computeSlotsFromRules(
  rules: AvailabilityRule[],
  from: Date,
  to: Date,
  bookedStarts: Date[],
  durationMinutes = 20,
): ConsultSlot[] {
  const slots: ConsultSlot[] = [];
  const stepMs = SLOT_STEP_MINUTES * 60 * 1000;
  const durationMs = durationMinutes * 60 * 1000;

  for (let t = from.getTime(); t < to.getTime(); t += stepMs) {
    const start = new Date(t);
    const end = new Date(t + durationMs);
    const activeRules = rules.filter((r) => r.active);
    if (activeRules.length === 0) continue;

    let inWindow = false;
    for (const rule of activeRules) {
      const parts = getZonedParts(start, rule.timezone || DEFAULT_TZ);
      if (parts.weekday !== rule.weekday) continue;
      if (
        // `<=` admits a slot that ends exactly at endMinuteLocal, so an
        // end-of-day window (endMinuteLocal = 1440 = midnight) is not truncated
        // by a slot-width; a slot ending past midnight is correctly excluded
        // (DEV-79).
        parts.minuteOfDay >= rule.startMinuteLocal &&
        parts.minuteOfDay + durationMinutes <= rule.endMinuteLocal
      ) {
        inWindow = true;
        break;
      }
    }
    if (!inWindow) continue;

    const collides = bookedStarts.some((b) => {
      const diff = Math.abs(b.getTime() - start.getTime());
      return diff < durationMs;
    });

    slots.push({
      start: start.toISOString(),
      end: end.toISOString(),
      available: !collides,
    });
  }

  return slots;
}

export async function listAvailabilityRules(db: Db, tenantId: string) {
  return db
    .select()
    .from(clinicianAvailability)
    .where(eq(clinicianAvailability.tenantId, tenantId));
}

export async function replaceAvailabilityRules(
  db: Db,
  tenantId: string,
  rules: AvailabilityRule[],
) {
  await db.delete(clinicianAvailability).where(eq(clinicianAvailability.tenantId, tenantId));
  if (rules.length === 0) return [];
  const rows = await db
    .insert(clinicianAvailability)
    .values(
      rules.map((r) => ({
        tenantId,
        weekday: r.weekday,
        startMinuteLocal: r.startMinuteLocal,
        endMinuteLocal: r.endMinuteLocal,
        timezone: r.timezone ?? DEFAULT_TZ,
        active: r.active,
      })),
    )
    .returning();
  return rows;
}

export async function ensureDefaultAvailability(db: Db, tenantId: string) {
  const existing = await listAvailabilityRules(db, tenantId);
  if (existing.length > 0) return existing;

  const defaults: AvailabilityRule[] = [
    { weekday: 2, startMinuteLocal: 9 * 60, endMinuteLocal: 20 * 60, timezone: DEFAULT_TZ, active: true },
    { weekday: 4, startMinuteLocal: 9 * 60, endMinuteLocal: 20 * 60, timezone: DEFAULT_TZ, active: true },
  ];
  return replaceAvailabilityRules(db, tenantId, defaults);
}

export async function getAvailabilitySlots(
  db: Db,
  tenantId: string,
  fromIso: string,
  toIso: string,
  excludeCaseId?: string,
  // When set, slots whose start is not strictly after this instant are dropped.
  // The listing route passes Date.now() so we never OFFER a slot the booking
  // schema (bookConsultBody: "start must be in the future", DEV-79) is
  // guaranteed to reject — the slot grid is anchored at `from`, so without this
  // the first slot returned starts at exactly the caller's "now" and is already
  // in the past by the time the booking request arrives. bookConsult's internal
  // re-validation deliberately does NOT pass it (zod already guarantees a
  // future start; filtering on a later wall-clock here would race a
  // last-instant booking into a spurious `outside_window`).
  minStartMs?: number,
) {
  const from = new Date(fromIso);
  const to = new Date(toIso);
  const rules = (await listAvailabilityRules(db, tenantId)).map((r) => ({
    weekday: r.weekday,
    startMinuteLocal: r.startMinuteLocal,
    endMinuteLocal: r.endMinuteLocal,
    timezone: r.timezone,
    active: r.active,
  }));

  const conditions = [
    eq(cases.tenantId, tenantId),
    isNotNull(cases.consultAt),
    gte(cases.consultAt, from),
    lte(cases.consultAt, to),
  ];
  if (excludeCaseId) conditions.push(ne(cases.id, excludeCaseId));

  const booked = await db
    .select({ consultAt: cases.consultAt, id: cases.id })
    .from(cases)
    .where(and(...conditions));

  const bookedStarts = booked
    .map((b) => b.consultAt)
    .filter((d): d is Date => d != null);

  const slots = computeSlotsFromRules(rules, from, to, bookedStarts);
  return dropAlreadyStartedSlots(slots, minStartMs);
}

/**
 * Drops slots whose start is not strictly in the future of `minStartMs`.
 * Pure, so the listing contract ("never offer a slot booking would reject as
 * past", DEV-79) is unit-testable without a DB. No-op when minStartMs is
 * undefined (bookConsult's re-validation path).
 */
export function dropAlreadyStartedSlots(
  slots: ConsultSlot[],
  minStartMs?: number,
): ConsultSlot[] {
  if (minStartMs === undefined) return slots;
  return slots.filter((s) => Date.parse(s.start) > minStartMs);
}

export function slotIsAvailable(
  slots: ConsultSlot[],
  startIso: string,
): boolean {
  const slot = slots.find((s) => s.start === startIso);
  return slot?.available === true;
}
