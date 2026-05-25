import { z } from "zod";

export const bookConsultBody = z.object({
  start: z.string().datetime(),
  durationMinutes: z.number().int().min(15).max(60).default(20),
});

export const bookConsultDraftSchema = z.object({
  start: z.string().datetime(),
  durationMinutes: z.number().int().min(15).max(60).optional(),
});

export const availabilityRuleSchema = z.object({
  weekday: z.number().int().min(1).max(7),
  startMinuteLocal: z.number().int().min(0).max(1439),
  endMinuteLocal: z.number().int().min(1).max(1440),
  timezone: z.string().min(1).max(64).default("Europe/London"),
  active: z.boolean().default(true),
});

export const putAvailabilityRulesBody = z.object({
  tenantId: z.string().uuid(),
  rules: z.array(availabilityRuleSchema).max(14),
});
