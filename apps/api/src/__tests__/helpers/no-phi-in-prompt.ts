import { expect } from "vitest";

/**
 * Reusable no-PHI-in-prompt assertion (DEV-53 / ADR-007 safeguard 7).
 *
 * Given a constructed prompt string and the raw intake answers it was built
 * from, assert that none of the direct identifiers survived into the text we
 * would send to the third-party model. Made a shared helper so every current
 * and future prompt-builder test inherits the same check — if a generator later
 * starts leaking an identifier, the existing tests that call this fail.
 *
 * Checks the direct identifiers DEV-53 names: child name, DOB string, full
 * address, parent/carer names, email, phone, postcode, NHS number.
 */

/** Intake keys whose verbatim values must never appear in a prompt. */
const DIRECT_IDENTIFIER_VALUE_KEYS = [
  "childName",
  "dateOfBirth",
  "childAddress",
  "motherName",
  "motherAddress",
  "motherMobile",
  "motherEmail",
  "fatherName",
  "fatherAddress",
  "fatherMobile",
  "fatherEmail",
  "email",
  "gpAddress",
  "gpPhone",
  "completedBy",
];

/** Name keys whose individual tokens (first names) must also not appear. */
const NAME_KEYS = ["childName", "motherName", "fatherName", "completedBy"];

function values(answers: Record<string, unknown>, key: string): string[] {
  const v = answers[key];
  if (v == null || v === "") return [];
  if (Array.isArray(v)) return v.map(String);
  return [String(v)];
}

/**
 * Assert the prompt contains none of the direct identifiers from `answers`.
 * Throws (failing the test) on the first leak found, naming the field.
 */
export function assertNoDirectIdentifiers(
  prompt: string,
  answers: Record<string, unknown>,
): void {
  const haystack = prompt.toLowerCase();

  for (const key of DIRECT_IDENTIFIER_VALUE_KEYS) {
    for (const value of values(answers, key)) {
      const needle = value.trim().toLowerCase();
      if (needle.length < 3) continue;
      expect(
        haystack.includes(needle),
        `prompt leaked direct identifier "${key}" (${value})`,
      ).toBe(false);
    }
  }

  // Individual name tokens (e.g. first name "Aria" out of "Aria M.").
  for (const key of NAME_KEYS) {
    for (const value of values(answers, key)) {
      for (const token of value.split(/\s+/)) {
        const cleaned = token.replace(/[.,]/g, "").toLowerCase();
        if (cleaned.length < 3) continue;
        const wordRe = new RegExp(`\\b${cleaned.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\b`);
        expect(
          wordRe.test(haystack),
          `prompt leaked name token "${cleaned}" from "${key}" (${value})`,
        ).toBe(false);
      }
    }
  }
}
