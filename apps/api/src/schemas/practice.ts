import { z } from "zod";

export const practiceModeSchema = z.enum(["single", "group"]);
export const seatRoleSchema = z.enum(["admin", "clinician"]);

/** Admin sign-up — screen 01 (creates the practice + admin seat). */
export const createPracticeBody = z.object({
  practiceName: z.string().trim().min(1).max(255),
  adminFullName: z.string().trim().min(1).max(255),
  /** Optional fallback; the verified Firebase token email is preferred. */
  adminEmail: z.string().trim().email().max(320).optional(),
});
export type CreatePracticeBody = z.infer<typeof createPracticeBody>;

/** Plan & seats — screen 02. */
export const updatePlanBody = z.object({
  mode: practiceModeSchema,
  seats: z.number().int().min(1).max(500),
});
export type UpdatePlanBody = z.infer<typeof updatePlanBody>;

/** Practice config — screen 03. */
export const updatePracticeConfigBody = z
  .object({
    practiceName: z.string().trim().min(1).max(255).optional(),
    location: z.string().trim().max(255).nullish(),
    specialties: z.array(z.string().trim().min(1).max(64)).max(50).optional(),
  })
  .refine((v) => Object.keys(v).length > 0, {
    message: "at least one field is required",
  });
export type UpdatePracticeConfigBody = z.infer<typeof updatePracticeConfigBody>;

/** Invite clinician — screen 04. */
export const inviteClinicianBody = z.object({
  email: z.string().trim().email().max(320),
  // Optional, but reject blank-after-trim so "   " is not stored as "" (DEV-83).
  fullName: z.string().trim().min(1).max(255).optional(),
  role: seatRoleSchema.default("clinician"),
});
export type InviteClinicianBody = z.infer<typeof inviteClinicianBody>;

/** Bulk invite via CSV import — screen 04 ("Import from CSV"). */
export const importCliniciansBody = z.object({
  clinicians: z.array(inviteClinicianBody).min(1).max(200),
});
export type ImportCliniciansBody = z.infer<typeof importCliniciansBody>;
