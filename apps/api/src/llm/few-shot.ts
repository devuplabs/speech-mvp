/**
 * Few-shot example selection + rendering for the draft-generation prompts.
 *
 * DEV-14: the production prompts in generate-drafts.ts were zero-shot. This
 * module injects 1-3 vendored persona examples (from speech-ml's few_shot
 * exports, see ./few-shot/few-shot-data.ts) that match the case's specialty,
 * to improve draft quality and consistency.
 *
 * Design notes
 * ------------
 * - Selection is deterministic: buckets are sorted by persona_id so the same
 *   case always yields the same examples, keeping prompt snapshots reviewable.
 * - The model context budget is respected with a token estimate + hard caps
 *   (see MAX_EXAMPLES / MAX_EXAMPLE_TOKENS / MAX_TOTAL_EXAMPLE_TOKENS).
 * - Specialty is derived from the live intake (mainConcern free text +
 *   difficulties enum). When nothing matches we fall back to the general
 *   `all` bucket so every case still gets examples.
 * - PHI safety: this module never logs. The vendored examples are synthetic
 *   personas (no real PHI), but the rendered block is part of the prompt and
 *   must never be logged either (the existing logger drops prompt content).
 * - Parity: the rendered example block mirrors the gist fields the eval
 *   harness scores against (speech-ml/eval/runner/prompts.py), so the
 *   production few-shot format stays consistent with the eval format.
 */
import { FEW_SHOT_BUCKETS, type FewShotRecord } from "./few-shot/few-shot-data.js";

export type DraftKind = "prep_brief" | "session_plan" | "parent_summary" | "clinical_report";

/**
 * Caps that keep the few-shot block well inside the model context budget.
 *
 * Each vendored example renders to ~60-90 tokens (a handful of short labelled
 * lines), so 3 examples is ~270 tokens worst case — small next to the ~1200-1800
 * max_tokens generation budget and the intake context. We still enforce a hard
 * per-example and total-block token ceiling so an unusually large upstream
 * example can never blow the budget.
 */
export const MAX_EXAMPLES = 3;
export const MAX_EXAMPLE_TOKENS = 160;
export const MAX_TOTAL_EXAMPLE_TOKENS = 360;

/** General fallback bucket name (speech-ml/eval/few_shot/all.jsonl). */
export const FALLBACK_BUCKET = "all";

/**
 * Rough token estimate without a tokenizer dependency: ~4 chars/token is the
 * usual English heuristic. Deliberately conservative (rounds up) so the cap
 * never under-counts.
 */
export function estimateTokens(text: string): number {
  return Math.ceil(text.length / 4);
}

/**
 * Map the live intake concern signals to a few-shot specialty bucket.
 *
 * The live intake form (schemas/intake.ts) does not carry an explicit
 * `specialty` field — it has a free-text `mainConcern` plus a `difficulties`
 * enum array. We map both to the speech-ml bucket names. The difficulties enum
 * is the stronger, structured signal so it is checked first; mainConcern
 * keyword matching is a secondary signal.
 *
 * Returns the matched bucket name, or null when nothing matches (caller falls
 * back to the general bucket).
 */
export function resolveSpecialtyBucket(params: {
  mainConcern?: string | null;
  difficulties?: string[] | null;
}): string | null {
  const difficulties = (params.difficulties ?? []).map((d) => d.toLowerCase());
  const concern = (params.mainConcern ?? "").toLowerCase();

  // Ordered rules: first match wins. Each rule names a bucket and the
  // difficulty-enum substrings / concern keywords that select it.
  const rules: { bucket: string; difficulty: string[]; keywords: string[] }[] = [
    {
      bucket: "speech_sounds",
      difficulty: ["speech sounds", "saying longer words"],
      keywords: ["speech sound", "articulat", "pronunc", "/r/", "/s/", "lisp", "phonolog", "unclear speech"],
    },
    {
      bucket: "fluency",
      difficulty: [],
      keywords: ["stutter", "stammer", "fluency", "dysfluen", "disfluen"],
    },
    {
      bucket: "social_communication",
      difficulty: [
        "maintaining eye contact",
        "turn taking",
        "sharing",
        "playing with others appropriately",
        "staying on topic of conversation",
        "reading between the lines",
      ],
      keywords: ["social communication", "autis", "asd", "pragmatic", "eye contact"],
    },
    {
      bucket: "language",
      difficulty: [
        "expressing ideas clearly",
        "understanding what is said to them",
        "following directions/instructions",
        "maintaining interest in story books",
        "understanding stories and answering questions",
        "reading and spelling words",
        "letter/number formation",
        "writing stories",
      ],
      keywords: [
        "language",
        "vocabulary",
        "understanding",
        "expressive",
        "receptive",
        "grammar",
        "sentence",
        "comprehension",
        "literacy",
        "reading",
      ],
    },
    {
      bucket: "voice",
      difficulty: [],
      keywords: ["voice", "hoarse", "vocal", "raspy"],
    },
    {
      bucket: "feeding",
      difficulty: [],
      keywords: ["feeding", "swallow", "eating", "mealtime", "dysphagia"],
    },
    {
      bucket: "hearing_impairment",
      difficulty: ["overly sensitive to sounds/noises"],
      keywords: ["hearing", "deaf", "cochlear"],
    },
  ];

  for (const rule of rules) {
    if (rule.difficulty.some((d) => difficulties.some((have) => have.includes(d)))) {
      return rule.bucket;
    }
  }
  for (const rule of rules) {
    if (rule.keywords.some((k) => concern.includes(k))) {
      return rule.bucket;
    }
  }
  return null;
}

/** Deterministic copy of a bucket, sorted by persona_id for stable ordering. */
function sortedBucket(name: string): FewShotRecord[] {
  const bucket = FEW_SHOT_BUCKETS[name];
  if (!bucket) return [];
  return [...bucket].sort((a, b) => a.persona_id.localeCompare(b.persona_id));
}

export type FewShotSelection = {
  /** The bucket the examples came from (after fallback resolution). */
  bucket: string;
  /** Whether the general fallback bucket was used. */
  usedFallback: boolean;
  examples: FewShotRecord[];
};

/**
 * Select up to MAX_EXAMPLES examples for a case, respecting the token caps.
 *
 * Specialty match returns that bucket; no match falls back to `all`. If the
 * matched specialty bucket is empty it also falls back. Examples are added in
 * stable order until either the count cap or the total token cap is hit; any
 * single example over MAX_EXAMPLE_TOKENS is skipped.
 */
export function selectFewShotExamples(params: {
  mainConcern?: string | null;
  difficulties?: string[] | null;
  kind: DraftKind;
}): FewShotSelection {
  const matched = resolveSpecialtyBucket(params);
  let bucketName = matched ?? FALLBACK_BUCKET;
  let candidates = sortedBucket(bucketName);
  let usedFallback = matched == null;

  if (candidates.length === 0 && bucketName !== FALLBACK_BUCKET) {
    bucketName = FALLBACK_BUCKET;
    candidates = sortedBucket(bucketName);
    usedFallback = true;
  }

  const examples: FewShotRecord[] = [];
  let totalTokens = 0;
  for (const candidate of candidates) {
    if (examples.length >= MAX_EXAMPLES) break;
    const rendered = renderExample(candidate, params.kind);
    const tokens = estimateTokens(rendered);
    if (tokens > MAX_EXAMPLE_TOKENS) continue;
    if (totalTokens + tokens > MAX_TOTAL_EXAMPLE_TOKENS) break;
    examples.push(candidate);
    totalTokens += tokens;
  }

  return { bucket: bucketName, usedFallback, examples };
}

/**
 * Render a single example for a given draft kind. The rendered shape mirrors
 * the gist fields the eval harness uses (presenting_concern + the kind-specific
 * *_gist), so the few-shot signal matches what the eval scores against.
 */
export function renderExample(record: FewShotRecord, kind: DraftKind): string {
  const lines: string[] = [];
  if (record.presenting_concern) lines.push(`Concern: ${record.presenting_concern}`);
  if (record.care_model) lines.push(`Care model: ${record.care_model}`);

  switch (kind) {
    case "prep_brief":
      if (record.prep_brief_gist) lines.push(`Prep focus: ${record.prep_brief_gist}`);
      break;
    case "session_plan":
      if (record.expected_triage_outcome)
        lines.push(`Triage: ${record.expected_triage_outcome}`);
      if (record.session_plan_gist) lines.push(`Plan focus: ${record.session_plan_gist}`);
      break;
    case "parent_summary":
      if (record.summary_gist) lines.push(`Summary tone: ${record.summary_gist}`);
      break;
    case "clinical_report":
      if (record.expected_triage_outcome)
        lines.push(`Triage: ${record.expected_triage_outcome}`);
      if (record.prep_brief_gist) lines.push(`Presentation: ${record.prep_brief_gist}`);
      if (record.session_plan_gist) lines.push(`Plan focus: ${record.session_plan_gist}`);
      break;
  }
  return lines.join("\n");
}

/**
 * Build the few-shot block injected into a prompt. Returns "" when there are no
 * examples so callers can append unconditionally without changing zero-example
 * prompts.
 */
export function buildFewShotBlock(selection: FewShotSelection, kind: DraftKind): string {
  if (selection.examples.length === 0) return "";
  const rendered = selection.examples
    .map((ex, i) => `Example ${i + 1}:\n${renderExample(ex, kind)}`)
    .join("\n\n");
  return (
    `Reference examples (similar cases, for tone and focus only — do not copy details):\n` +
    `${rendered}\n\n`
  );
}
