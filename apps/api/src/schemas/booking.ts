import { z } from "zod";

export const bookConsultBody = z
  .object({
    start: z.string().datetime(),
    durationMinutes: z.number().int().min(15).max(60).default(20),
  })
  // Reject bookings in the past explicitly rather than relying on the computed
  // slot set to exclude them (DEV-79).
  .refine((b) => new Date(b.start).getTime() > Date.now(), {
    message: "start must be in the future",
    path: ["start"],
  });

export const bookConsultDraftSchema = z.object({
  start: z.string().datetime(),
  durationMinutes: z.number().int().min(15).max(60).optional(),
});

export const availabilityRuleSchema = z
  .object({
    weekday: z.number().int().min(1).max(7),
    startMinuteLocal: z.number().int().min(0).max(1439),
    // 1440 = end of day (midnight); a slot may end exactly at this minute.
    endMinuteLocal: z.number().int().min(1).max(1440),
    timezone: z.string().min(1).max(64).default("Europe/London"),
    active: z.boolean().default(true),
  })
  // Reject inverted / zero-width windows (start >= end) that silently yield no
  // slots (DEV-79).
  .refine((r) => r.startMinuteLocal < r.endMinuteLocal, {
    message: "startMinuteLocal must be before endMinuteLocal",
    path: ["endMinuteLocal"],
  });

export const putAvailabilityRulesBody = z.object({
  tenantId: z.string().uuid(),
  rules: z.array(availabilityRuleSchema).max(14),
});
