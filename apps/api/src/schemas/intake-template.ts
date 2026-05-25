import { z } from "zod";

export const intakeTemplateIdEnum = z.enum(["full", "short", "follow_up"]);

export type IntakeTemplateId = z.infer<typeof intakeTemplateIdEnum>;

/** Which parent intake steps (1–8) are shown per template. */
export const INTAKE_TEMPLATE_STEPS: Record<IntakeTemplateId, number[]> = {
  full: [1, 2, 3, 4, 5, 6, 7, 8],
  short: [1, 2, 3],
  follow_up: [1, 6, 7],
};

export function isStepInTemplate(templateId: IntakeTemplateId, step: number): boolean {
  return INTAKE_TEMPLATE_STEPS[templateId].includes(step);
}

export function nextTemplateStep(templateId: IntakeTemplateId, current: number): number | null {
  const steps = INTAKE_TEMPLATE_STEPS[templateId];
  const idx = steps.indexOf(current);
  if (idx < 0) return steps[0] ?? null;
  if (idx >= steps.length - 1) return null;
  return steps[idx + 1] ?? null;
}

export function lastTemplateStep(templateId: IntakeTemplateId): number {
  const steps = INTAKE_TEMPLATE_STEPS[templateId];
  return steps[steps.length - 1]!;
}
