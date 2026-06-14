import { CHILD_PLACEHOLDER, dobToAge, redactIdentifiers } from "./redact.js";

/**
 * Build the intake context block injected into LLM prompts.
 *
 * PHI stays in DB only — never log the answers object or the returned string.
 *
 * DEV-53 (ADR-007 safeguard 7 — data minimisation): this is the single
 * prompt-construction chokepoint for the four draft generators, so the
 * direct-identifier redaction lives here and every draft kind inherits it.
 *
 *   - The child's name is never sent: where the model needs to refer to the
 *     child it sees the `[CHILD]` placeholder, re-substituted in our own layer
 *     after generation (see redact.ts / generate-drafts.ts).
 *   - DOB is converted to an age band — the clinical signal is kept, the raw
 *     date never leaves the service.
 *   - Direct-identifier fields (addresses, parent/carer names, emails, phones,
 *     GP contact) are dropped entirely.
 *   - Free-text fields we keep are still scrubbed for inline identifiers
 *     (emails, phone/NHS numbers, postcodes a parent may have typed inline).
 */
export function buildIntakeContextForLlm(answers: Record<string, unknown>): string {
  const pick = (key: string) => {
    const v = answers[key];
    if (v == null || v === "") return null;
    if (Array.isArray(v)) return v.join(", ");
    return String(v);
  };

  // Known direct-identifier names from structured fields. We strip these from
  // any free text we keep so a name typed inline (e.g. the child's name in a
  // "sentence examples" answer) never reaches the prompt either.
  const knownNames = ["childName", "motherName", "fatherName", "completedBy"]
    .map((k) => pick(k))
    .filter((v): v is string => v != null);

  // Free-text fields are kept for clinical signal but scrubbed of any inline
  // direct identifiers (e.g. an email or phone number typed into a notes box).
  const safe = (key: string) => {
    const v = pick(key);
    return v == null ? null : redactIdentifiers(v, knownNames);
  };

  // DOB → age band. The raw date is never emitted; the age carries the signal.
  const dobRaw = pick("dateOfBirth");
  const age =
    (dobRaw ? dobToAge(dobRaw) : null) ?? pick("ageAtReferral") ?? null;

  const lines: string[] = [];
  const fields = [
    // The child is referred to by the placeholder token, not their real name.
    ["Child", CHILD_PLACEHOLDER],
    ["Age", age],
    ["Main concern", safe("mainConcern")],
    ["Difficulties", safe("difficulties")],
    ["Languages", safe("childLanguages")],
    ["Hearing", safe("hearingTestedDetails") ?? safe("hearingTested")],
    ["Milestones — first words", safe("ageFirstWords")],
    ["Milestones — two-word phrases", safe("ageTwoWordPhrases")],
    ["Sentence examples", safe("sentenceExamples")],
    ["School / nursery", safe("schoolNameAddress")],
    ["SEN / EHCP", safe("senPlan")],
    ["Temperament", safe("temperament")],
    ["Anything else", safe("anythingElse")],
  ] as const;

  for (const [label, value] of fields) {
    if (value) lines.push(`${label}: ${value}`);
  }
  return lines.join("\n");
}
