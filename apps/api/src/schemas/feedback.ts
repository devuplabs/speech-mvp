import { z } from "zod";

/**
 * In-app tester feedback (DEV-55). TEXT-ONLY by product decision — no
 * screenshots or any other capture. PHI-safe by construction: the client sends
 * a route *pattern* (never a concrete URL/token), role, journey stage and
 * build/env metadata alongside the free-text comment. The server adds the
 * request id and user-agent from headers; it never trusts the client for those.
 */
export const FEEDBACK_TYPES = ["bug", "confusing", "idea", "praise"] as const;
export const FEEDBACK_SEVERITIES = ["blocker", "annoying", "minor"] as const;

export const submitFeedbackBody = z.object({
  type: z.enum(FEEDBACK_TYPES),
  comment: z.string().trim().min(1).max(4000),
  severity: z.enum(FEEDBACK_SEVERITIES).optional(),
  // Route *name/pattern* (e.g. "clinicianTriage"), never a concrete URL — those
  // can carry magic-link tokens (see logger.ts policy).
  route: z.string().max(128).optional(),
  role: z.string().max(32).optional(),
  journeyStage: z.string().max(64).optional(),
  tenantId: z.string().uuid().optional(),
  buildSha: z.string().max(64).optional(),
  appEnv: z.string().max(32).optional(),
  viewport: z.string().max(32).optional(),
  locale: z.string().max(35).optional(),
});

export type SubmitFeedbackBody = z.infer<typeof submitFeedbackBody>;
