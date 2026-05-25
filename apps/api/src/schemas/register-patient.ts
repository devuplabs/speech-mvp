import { z } from "zod";
import { bookConsultDraftSchema } from "./booking.js";

export const referralSourceEnum = z.enum([
  "nhs",
  "school",
  "gp",
  "other_parent",
  "self",
  "other",
]);

const dateOfBirthPattern =
  /^(0[1-9]|[12][0-9]|3[01])\s*\/\s*(0[1-9]|1[0-2])\s*\/\s*(19|20)\d{2}$/;

export const registerPatientBody = z.object({
  tenantId: z.string().uuid(),
  childFirstName: z.string().trim().min(1).max(128),
  dateOfBirth: z.string().trim().regex(dateOfBirthPattern, "Use dd / mm / yyyy"),
  parentName: z.string().trim().min(1).max(255),
  parentEmail: z.string().trim().email().max(320),
  parentPhone: z.string().trim().max(64).optional(),
  referralSource: referralSourceEnum,
  initialConcerns: z.string().trim().max(8000).optional(),
  sendIntakeLink: z.boolean().default(true),
  bookConsult: bookConsultDraftSchema.optional(),
});

export type RegisterPatientBody = z.infer<typeof registerPatientBody>;

export const REFERRAL_SOURCE_LABELS: Record<z.infer<typeof referralSourceEnum>, string> = {
  nhs: "NHS",
  school: "School",
  gp: "GP",
  other_parent: "Other parent",
  self: "Self-referral",
  other: "Other",
};
