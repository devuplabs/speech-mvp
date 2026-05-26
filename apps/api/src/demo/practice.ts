/** Stable tenant display names — separate demo caseload from automated E2E runs. */
export const PRACTICE_NAMES = {
  demo: "Monal Gajjar SLT — Demo",
  e2e: "Sona E2E (automated)",
} as const;

export type PracticeVariant = keyof typeof PRACTICE_NAMES;

export function practiceDisplayName(variant: PracticeVariant): string {
  return PRACTICE_NAMES[variant];
}
