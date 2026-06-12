import { z } from "zod";

export const carryoverResourceCategories = [
  "home_practice",
  "reading",
  "activity",
  "other",
] as const;
export type CarryoverResourceCategory = (typeof carryoverResourceCategories)[number];

export const progressRatings = ["tried_it", "going_well", "finding_it_hard"] as const;
export type ProgressRating = (typeof progressRatings)[number];

export const createCarryoverResourceBody = z.object({
  title: z.string().trim().min(1).max(255),
  description: z.string().trim().max(2000).nullish(),
  url: z.string().trim().url().max(2048).nullish(),
  category: z.enum(carryoverResourceCategories),
  sourceDraftId: z.string().uuid().nullish(),
});
export type CreateCarryoverResourceBody = z.infer<typeof createCarryoverResourceBody>;

export const updateCarryoverResourceBody = createCarryoverResourceBody
  .partial()
  .refine((patch) => Object.keys(patch).length > 0, { message: "empty_patch" });
export type UpdateCarryoverResourceBody = z.infer<typeof updateCarryoverResourceBody>;

export const createProgressEntryBody = z.object({
  note: z.string().trim().min(1).max(4000),
  rating: z.enum(progressRatings).nullish(),
});
export type CreateProgressEntryBody = z.infer<typeof createProgressEntryBody>;
