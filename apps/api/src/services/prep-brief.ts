import { eq } from "drizzle-orm";
import type { Db } from "../db/client.js";
import { aiDrafts, cases, intakeSubmissions } from "../db/schema.js";
import { writeAudit } from "./audit.js";

/**
 * Drafts a clinician prep brief for the consult.
 *
 * MVP "stub": we don't yet call the air-gap LLM (parked behind GPU work in
 * ADR-003). Instead we derive a deterministic prep brief from the parent's
 * intake answers — child snapshot, concerns, difficulties, red flags
 * inferred from yes/no fields, and a curated references list. Real LLM
 * inference replaces `buildStubPrepBrief` once `INFERENCE_OPENAI_BASE_URL`
 * is reachable. The shape of the returned content is stable across stub +
 * real LLM so the clinician UI doesn't change.
 *
 * Every artifact carries the "DRAFT — clinician must review" label per the
 * MVP brief.
 */
export async function draftPrepBrief(db: Db, caseId: string) {
  const [row] = await db.select().from(cases).where(eq(cases.id, caseId));
  if (!row) return { ok: false as const, error: "not_found" };

  const [intake] = await db
    .select()
    .from(intakeSubmissions)
    .where(eq(intakeSubmissions.caseId, caseId));

  const answers = (intake?.answers ?? {}) as Record<string, unknown>;

  const existing = await db
    .select()
    .from(aiDrafts)
    .where(eq(aiDrafts.caseId, caseId));

  if (existing.some((d) => d.kind === "prep_brief")) {
    return { ok: true as const, alreadyExists: true };
  }

  const content = buildStubPrepBrief(answers, row.childDisplayName);

  const [draft] = await db
    .insert(aiDrafts)
    .values({
      caseId,
      kind: "prep_brief",
      content,
      modelId: "mvp-stub",
    })
    .returning();

  await db
    .update(cases)
    .set({ status: "prep_ready", updatedAt: new Date() })
    .where(eq(cases.id, caseId));

  await writeAudit(db, {
    tenantId: row.tenantId,
    caseId,
    actor: "worker",
    action: "prep_brief.drafted",
  });

  return { ok: true as const, draft, alreadyExists: false };
}

/**
 * Deterministic prep-brief generator. Stable across runs for the same
 * intake answers — the clinician UI can rely on the same probe order for
 * the same case.
 */
export function buildStubPrepBrief(
  answers: Record<string, unknown>,
  childDisplayName?: string | null,
) {
  const concerns = str(answers.mainConcern);
  const difficulties = arr(answers.difficulties);
  const ageAtReferral = str(answers.ageAtReferral);
  const senPlan = str(answers.senPlan);

  const probeAreas: string[] = [];

  // Always start with confirming the headline.
  if (concerns) {
    probeAreas.push(
      `Confirm primary concern with parent: "${truncate(concerns, 140)}"`,
    );
  } else {
    probeAreas.push("Confirm primary concern and onset with parent");
  }

  if (difficulties.length > 0) {
    probeAreas.push(
      `Sample top difficulties in 1:1 play: ${difficulties.slice(0, 3).join(", ")}`,
    );
  }

  if (
    yes(answers.familyHistory) ||
    str(answers.familyHistoryDetails).trim() !== ""
  ) {
    probeAreas.push(
      "Explore family history of SLT / learning / attention difficulties (parent flagged)",
    );
  }

  if (
    yes(answers.receivingTherapy) ||
    str(answers.therapyDetails).trim() !== ""
  ) {
    probeAreas.push(
      "Check current / recent therapy involvement and what's been tried",
    );
  }

  if (yes(answers.assessedByOthers)) {
    probeAreas.push(
      "Ask for and request consent to view prior professional reports",
    );
  }

  if (senPlan && senPlan.toLowerCase() !== "none" && senPlan.toLowerCase() !== "no") {
    probeAreas.push(`EHCP / SEN context: "${truncate(senPlan, 120)}"`);
  }

  const redFlags: string[] = [];

  if (containsAny(answers.earlyIllnesses, ["regression", "lost"])) {
    redFlags.push("Possible regression mentioned in early illnesses");
  }
  if (containsAny(answers.hearingTested, ["abnormal", "fail", "concern"])) {
    redFlags.push("Hearing screen concerns flagged on intake");
  }
  if (containsAny(answers.earInfections, ["recurrent", "many", "grommet"])) {
    redFlags.push("Recurrent ear infections / glue ear");
  }
  if (
    difficulties.includes("Overly sensitive to sounds/noises") ||
    containsAny(answers.communicationAwareness, ["aware", "self-conscious", "worry"])
  ) {
    redFlags.push("Sensitivity / self-consciousness — handle pacing carefully");
  }
  if (containsAny(answers.medications, ["seizure", "asthma severe", "stimulant"])) {
    redFlags.push("Note current medications");
  }
  if (redFlags.length === 0) {
    redFlags.push("No red flags from intake — confirm in conversation");
  }

  const references = pickReferences(difficulties, concerns);

  return {
    label: "DRAFT — clinician must review",
    childSnapshot: {
      displayName: childDisplayName ?? str(answers.childName) ?? "Child",
      ageAtReferral,
      mainConcern: concerns,
      difficulties: difficulties.slice(0, 6),
      senPlan,
    },
    probeAreas,
    redFlags,
    references,
    source: "mvp_stub",
  };
}

function str(v: unknown): string {
  return typeof v === "string" ? v : "";
}

function arr(v: unknown): string[] {
  return Array.isArray(v) ? v.filter((x): x is string => typeof x === "string") : [];
}

function yes(v: unknown): boolean {
  return typeof v === "string" && v.toLowerCase() === "yes";
}

function containsAny(v: unknown, needles: string[]): boolean {
  const s = str(v).toLowerCase();
  if (!s) return false;
  return needles.some((n) => s.includes(n.toLowerCase()));
}

function truncate(s: string, max: number): string {
  if (s.length <= max) return s;
  return `${s.slice(0, max - 1).trim()}…`;
}

/**
 * Map difficulty + concern keywords to curated, citation-friendly references.
 * Static for now — when RAG over RCSLT / SLI references lands these become
 * dynamic.
 */
function pickReferences(
  difficulties: string[],
  concern: string,
): Array<{ title: string; source: string; url: string }> {
  const lc = concern.toLowerCase();
  const refs: Array<{ title: string; source: string; url: string }> = [];

  if (
    difficulties.some((d) => d.toLowerCase().includes("speech sound")) ||
    lc.includes("speech sound") ||
    lc.includes("articulat")
  ) {
    refs.push({
      title: "Speech sound disorder",
      source: "RCSLT clinical guidance",
      url: "https://www.rcslt.org/members/clinical-guidance/speech-sound-disorder/",
    });
  }
  if (
    lc.includes("stutter") ||
    lc.includes("fluency") ||
    difficulties.some((d) => d.toLowerCase().includes("expressing"))
  ) {
    refs.push({
      title: "Stammering / fluency overview",
      source: "RCSLT clinical guidance",
      url: "https://www.rcslt.org/members/clinical-guidance/stammering/",
    });
  }
  if (
    difficulties.some((d) =>
      ["eye contact", "turn taking", "reading between the lines"]
        .some((k) => d.toLowerCase().includes(k)),
    ) ||
    lc.includes("social communication")
  ) {
    refs.push({
      title: "NG87 — Autism spectrum disorder in under 19s (recognition + referral)",
      source: "NICE guideline",
      url: "https://www.nice.org.uk/guidance/ng87",
    });
  }
  if (
    lc.includes("feed") ||
    lc.includes("fussy") ||
    lc.includes("texture") ||
    lc.includes("food")
  ) {
    refs.push({
      title: "Eating, drinking and swallowing — paediatric",
      source: "RCSLT clinical guidance",
      url: "https://www.rcslt.org/members/clinical-guidance/eating-drinking-and-swallowing/",
    });
  }
  if (refs.length === 0) {
    refs.push({
      title: "Developmental language disorder (DLD)",
      source: "RCSLT clinical guidance",
      url: "https://www.rcslt.org/members/clinical-guidance/developmental-language-disorder/",
    });
  }
  return refs;
}
