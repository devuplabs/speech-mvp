/**
 * Prompt data-minimisation (DEV-53 / ADR-007 safeguard 7).
 *
 * The pilot uses managed Vertex AI Gemini, so every prompt we build is sent to a
 * third-party data processor. Prompts carry the intake clinical context, which is
 * PHI about a child. To satisfy the GDPR data-minimisation principle (and reduce
 * exposure regardless of provider) we strip / pseudonymise *direct identifiers*
 * before any prompt text leaves this service, while keeping the clinical signal
 * the model actually needs.
 *
 * What we redact (direct identifiers):
 *   - child name
 *   - date of birth  → converted to an age / age-band (clinical signal kept)
 *   - full address(es) + postcode
 *   - parent / carer / mother / father names
 *   - email addresses
 *   - phone / mobile numbers
 *   - NHS number
 *
 * What we keep (clinical signal): age / age-band derived from DOB, main concern,
 * difficulties, developmental history, milestones, temperament, hearing/vision,
 * languages, SEN/EHCP status, etc.
 *
 * Two-layer approach for the *output*:
 *   1. The child's name never enters the prompt — generators send the
 *      {@link CHILD_PLACEHOLDER} token (`[CHILD]`) wherever the model needs to
 *      address the child.
 *   2. After generation, our own layer ({@link reinsertChildName}) swaps the
 *      placeholder back for the real name. The real identifier is therefore only
 *      ever handled inside our service, never sent to the model.
 *
 * PHI policy: this module must never log. Callers must never log the values it
 * receives or returns (they are still PHI in memory).
 */

/**
 * Placeholder token the generators send to the model in place of the child's
 * real name. Re-substituted with the real name by {@link reinsertChildName}
 * after the model returns. Chosen to be stable, obviously-a-token, and unlikely
 * to collide with real content.
 */
export const CHILD_PLACEHOLDER = "[CHILD]";

/**
 * Intake answer keys that are direct identifiers and must never reach a prompt.
 *
 * DOB (`dateOfBirth`) is handled specially — converted to an age band rather
 * than dropped — so it is intentionally NOT in this drop-list; see
 * {@link buildSafeIntakeContext}.
 */
export const DIRECT_IDENTIFIER_KEYS = [
  "childName",
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
] as const;

/**
 * Regex-based scrubber for free-text fields. Intake free-text (mainConcern,
 * anythingElse, schoolNameAddress, …) can contain identifiers a clinician or
 * parent typed inline (an email, a phone number, a postcode, an NHS number),
 * so structured key-dropping alone is not enough — we also scrub the text we do
 * keep. Each pattern replaces the match with a typed placeholder so the clinical
 * sentence stays readable.
 */
const SCRUBBERS: { label: string; pattern: RegExp; replacement: string }[] = [
  // Email addresses.
  {
    label: "email",
    pattern: /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi,
    replacement: "[EMAIL]",
  },
  // NHS number: 10 digits, usually grouped 3-3-4. Check before generic phone
  // so a "123 456 7890" NHS number is not mislabelled as a phone.
  {
    label: "nhs",
    pattern: /\b\d{3}[ -]?\d{3}[ -]?\d{4}\b/g,
    replacement: "[NHS-NUMBER]",
  },
  // UK phone / mobile numbers (e.g. 07700900101, 020 7432 1000, +44 …).
  {
    label: "phone",
    pattern: /(?:\+?\d[\d ()-]{7,}\d)/g,
    replacement: "[PHONE]",
  },
  // UK postcodes (e.g. NW3 2EE, NW3, SW1A 1AA).
  {
    label: "postcode",
    pattern: /\b[A-Z]{1,2}\d[A-Z\d]?(?:[ ]?\d[A-Z]{2})?\b/gi,
    replacement: "[POSTCODE]",
  },
];

/**
 * Re-insert the real child name into model output, replacing every
 * {@link CHILD_PLACEHOLDER} token the model echoed back. This is the second half
 * of the two-layer approach: the prompt used `[CHILD]`, and here — in our own
 * service, after the model has returned — we swap the real name back in. The
 * real identifier therefore never leaves our process boundary.
 *
 * Works on strings or recursively over arrays / plain objects (draft content is
 * a JSON-ish structure), so all four draft kinds can share one re-insertion
 * pass regardless of their output shape.
 */
export function reinsertChildName<T>(value: T, childName: string): T {
  if (typeof value === "string") {
    return value.split(CHILD_PLACEHOLDER).join(childName) as unknown as T;
  }
  if (Array.isArray(value)) {
    return value.map((v) => reinsertChildName(v, childName)) as unknown as T;
  }
  if (value && typeof value === "object") {
    const out: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(value)) {
      out[k] = reinsertChildName(v, childName);
    }
    return out as T;
  }
  return value;
}

/** Escape a string for safe use inside a RegExp. */
function escapeRegExp(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

/**
 * Build a case-insensitive whole-word matcher for a known name. We also match
 * individual name tokens (e.g. "Aria" out of "Aria M.") so a first name typed
 * inline in free text ("Aria want milk") is caught, while ignoring very short
 * tokens / initials that would over-match.
 */
function nameVariants(name: string): string[] {
  const variants = new Set<string>();
  const full = name.trim();
  if (full.length >= 2) variants.add(full);
  for (const token of full.split(/\s+/)) {
    const cleaned = token.replace(/[.,]/g, "");
    if (cleaned.length >= 3) variants.add(cleaned);
  }
  // Longest first so "Aria M." is replaced before the bare "Aria" token.
  return [...variants].sort((a, b) => b.length - a.length);
}

/**
 * Scrub direct identifiers out of an arbitrary free-text string. Order matters
 * (known names → email → NHS number → phone → postcode) so a more specific
 * pattern wins before a more generic one consumes its characters.
 *
 * `names` are known direct identifiers from structured intake fields (child /
 * parent / carer names). They are stripped from free text the parent may have
 * typed (e.g. "Aria want milk" sentence examples) so the child's real name
 * never reaches the prompt via a free-text field either.
 */
export function redactIdentifiers(text: string, names: string[] = []): string {
  let out = text;
  for (const name of names) {
    for (const variant of nameVariants(name)) {
      const re = new RegExp(`\\b${escapeRegExp(variant)}\\b`, "gi");
      out = out.replace(re, "[NAME]");
    }
  }
  for (const { pattern, replacement } of SCRUBBERS) {
    out = out.replace(pattern, replacement);
  }
  return out;
}

/**
 * Parse a date of birth into an age in whole years as of `now`. Accepts the
 * forms the intake form produces, e.g. "15 / 03 / 2022", "15/03/2022",
 * "2022-03-15". Returns null when it can't be parsed (caller then omits DOB
 * entirely rather than risk leaking the raw string).
 */
export function parseAgeYears(dob: string, now: Date = new Date()): number | null {
  const trimmed = dob.trim();
  let year: number, month: number, day: number;

  // ISO-ish: YYYY-MM-DD
  const iso = trimmed.match(/^(\d{4})-(\d{1,2})-(\d{1,2})/);
  // UK day-first: DD / MM / YYYY  (slashes optionally spaced)
  const uk = trimmed.match(/^(\d{1,2})\s*\/\s*(\d{1,2})\s*\/\s*(\d{4})$/);

  if (iso) {
    year = Number(iso[1]);
    month = Number(iso[2]);
    day = Number(iso[3]);
  } else if (uk) {
    day = Number(uk[1]);
    month = Number(uk[2]);
    year = Number(uk[3]);
  } else {
    return null;
  }

  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  const birth = new Date(Date.UTC(year, month - 1, day));
  if (Number.isNaN(birth.getTime())) return null;

  let age = now.getUTCFullYear() - year;
  const beforeBirthdayThisYear =
    now.getUTCMonth() < month - 1 ||
    (now.getUTCMonth() === month - 1 && now.getUTCDate() < day);
  if (beforeBirthdayThisYear) age -= 1;
  if (age < 0 || age > 120) return null;
  return age;
}

/**
 * Convert a DOB to a coarse, prompt-safe age descriptor. We keep the clinical
 * signal (how old the child is) without sending the exact date. Whole-year age
 * is precise enough for SLT prompting and is itself low-identifiability.
 */
export function dobToAge(dob: string, now: Date = new Date()): string | null {
  const years = parseAgeYears(dob, now);
  if (years == null) return null;
  if (years < 1) return "under 1 year";
  return `${years} years`;
}
