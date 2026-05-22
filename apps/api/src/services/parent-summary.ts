import { and, eq } from "drizzle-orm";
import type { Db } from "../db/client.js";
import { aiDrafts, cases, intakeSubmissions } from "../db/schema.js";
import { writeAudit } from "./audit.js";

/**
 * Tone slider stop. `warm` = informal / encouraging; `clinical` = neutral /
 * factual; `balanced` is the default middle.
 */
export type ParentSummaryTone = "warm" | "balanced" | "clinical";

/** Plain-language vs detailed clinical phrasing. */
export type ParentSummaryReadingLevel = "simple" | "standard" | "detailed";

export interface ParentSummaryOptions {
  tone: ParentSummaryTone;
  readingLevel: ParentSummaryReadingLevel;
  /** Toggle individual sections off the parent-facing artifact. */
  sections: {
    whatWeDiscussed: boolean;
    planForFirstSession: boolean;
    homePractice: boolean;
    nextSteps: boolean;
  };
  /** Show the explicit "AI-drafted" disclosure footer to the parent. */
  aiDisclosure: boolean;
}

export const defaultParentSummaryOptions: ParentSummaryOptions = {
  tone: "balanced",
  readingLevel: "standard",
  sections: {
    whatWeDiscussed: true,
    planForFirstSession: true,
    homePractice: true,
    nextSteps: true,
  },
  aiDisclosure: true,
};

/**
 * Backwards-compatible helper — used by the existing publish path when no
 * options are passed.
 */
export function defaultParentSummaryHtml(childName?: string | null): string {
  return buildParentSummaryHtml({
    childDisplayName: childName ?? null,
    answers: {},
    sessionPlan: null,
    options: defaultParentSummaryOptions,
  });
}

/**
 * Render the parent-facing summary HTML. Pure function so the same shape
 * works from the preview endpoint, the publish endpoint, and the PDF
 * renderer.
 */
export function buildParentSummaryHtml(args: {
  childDisplayName: string | null;
  answers: Record<string, unknown>;
  sessionPlan: {
    sections?: {
      goals?: string[];
      activities?: string[];
      homePractice?: string[];
      materials?: string[];
      parentGoals?: string[];
    };
    reviewStatus?: string;
  } | null;
  options: ParentSummaryOptions;
}): string {
  const { childDisplayName, answers, sessionPlan, options } = args;
  const sections = options.sections;
  const tone = options.tone;
  const readingLevel = options.readingLevel;
  const planSections = sessionPlan?.sections ?? {};

  const greeting = greetingFor(tone, childDisplayName);
  const intro = introFor(tone, readingLevel);

  const parts: string[] = [];
  parts.push(`<header style="margin-bottom:24px;">
    <h1 style="font-size:22px;color:#2D6A6E;margin:0 0 4px;">${greeting}</h1>
    <p style="margin:0;color:#4A5B6B;font-size:14px;">${intro}</p>
  </header>`);

  if (sections.whatWeDiscussed) {
    parts.push(htmlSection(
      tone === "clinical" ? "Summary of consultation" : "What we talked about",
      whatWeDiscussedItems(answers, tone, readingLevel),
    ));
  }

  if (sections.planForFirstSession) {
    const goals = (planSections.goals ?? []).slice(0, 6);
    parts.push(htmlSection(
      tone === "clinical" ? "Therapeutic goals" : "What we'll work on together",
      goals.length === 0
        ? [planFallback(tone, readingLevel)]
        : goals,
    ));
  }

  if (sections.homePractice) {
    const home = [
      ...(planSections.homePractice ?? []),
      ...(planSections.parentGoals ?? []),
    ].slice(0, 6);
    parts.push(htmlSection(
      tone === "clinical" ? "Home practice + parent goals" : "How you can help at home",
      home.length === 0 ? [homePracticeFallback(tone)] : home,
    ));
  }

  if (sections.nextSteps) {
    parts.push(htmlSection(
      tone === "clinical" ? "Next steps" : "What happens next",
      nextStepsItems(tone, readingLevel),
    ));
  }

  if (options.aiDisclosure) {
    parts.push(`<footer style="margin-top:28px;padding:12px 14px;background:#F4EDE3;border-radius:8px;color:#4A5B6B;font-size:12px;line-height:1.5;">
      <strong style="color:#A55727;">AI-drafted · clinician-reviewed.</strong>
      This summary was drafted by Sona using your intake answers and your
      clinician's consult notes, then reviewed and approved by your
      HCPC-registered clinician before being shared.
    </footer>`);
  }

  return `<!DOCTYPE html><html><head><meta charset="utf-8"/><title>Your summary</title></head>
<body style="font-family:'Inter',system-ui,sans-serif;color:#142433;background:#FAFAF7;margin:0;padding:24px;max-width:640px;">
${parts.join("\n")}
</body></html>`;
}

/**
 * Plain-text projection of the same content for environments without an HTML
 * renderer (PDF generator, simple Flutter preview). Matches the HTML section
 * ordering 1:1.
 */
export function buildParentSummaryText(args: {
  childDisplayName: string | null;
  answers: Record<string, unknown>;
  sessionPlan: Parameters<typeof buildParentSummaryHtml>[0]["sessionPlan"];
  options: ParentSummaryOptions;
}): { title: string; sections: Array<{ heading: string; bullets: string[] }>; disclosure: string | null } {
  const { childDisplayName, answers, sessionPlan, options } = args;
  const sections: Array<{ heading: string; bullets: string[] }> = [];
  const planSections = sessionPlan?.sections ?? {};

  if (options.sections.whatWeDiscussed) {
    sections.push({
      heading:
        options.tone === "clinical"
          ? "Summary of consultation"
          : "What we talked about",
      bullets: whatWeDiscussedItems(answers, options.tone, options.readingLevel),
    });
  }
  if (options.sections.planForFirstSession) {
    const goals = (planSections.goals ?? []).slice(0, 6);
    sections.push({
      heading:
        options.tone === "clinical"
          ? "Therapeutic goals"
          : "What we'll work on together",
      bullets:
        goals.length === 0
          ? [planFallback(options.tone, options.readingLevel)]
          : goals,
    });
  }
  if (options.sections.homePractice) {
    const home = [
      ...(planSections.homePractice ?? []),
      ...(planSections.parentGoals ?? []),
    ].slice(0, 6);
    sections.push({
      heading:
        options.tone === "clinical"
          ? "Home practice + parent goals"
          : "How you can help at home",
      bullets:
        home.length === 0 ? [homePracticeFallback(options.tone)] : home,
    });
  }
  if (options.sections.nextSteps) {
    sections.push({
      heading: options.tone === "clinical" ? "Next steps" : "What happens next",
      bullets: nextStepsItems(options.tone, options.readingLevel),
    });
  }

  return {
    title: greetingFor(options.tone, childDisplayName),
    sections,
    disclosure: options.aiDisclosure
      ? "AI-drafted, clinician-reviewed. Drafted by Sona using your intake answers and consult notes; reviewed and approved by your HCPC-registered clinician before being shared."
      : null,
  };
}

function htmlSection(heading: string, bullets: string[]): string {
  return `<section style="margin-bottom:20px;">
    <h2 style="font-size:16px;color:#2D6A6E;margin:0 0 6px;">${escapeHtml(heading)}</h2>
    <ul style="margin:0;padding-left:18px;color:#142433;font-size:14px;line-height:1.5;">
      ${bullets.map((b) => `<li>${escapeHtml(b)}</li>`).join("")}
    </ul>
  </section>`;
}

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function greetingFor(tone: ParentSummaryTone, childDisplayName: string | null): string {
  const name = (childDisplayName ?? "").trim();
  const who = name ? ` for ${name}` : "";
  switch (tone) {
    case "warm":
      return `Thanks for chatting with us${who}`;
    case "clinical":
      return `Consultation summary${who}`;
    default:
      return `Your consultation summary${who}`;
  }
}

function introFor(tone: ParentSummaryTone, level: ParentSummaryReadingLevel): string {
  if (tone === "clinical") {
    return level === "detailed"
      ? "This document summarises the free consultation, the agreed clinical pathway, and home-practice recommendations."
      : "Summary of today's free consultation and agreed next steps.";
  }
  if (tone === "warm") {
    return level === "simple"
      ? "Here's a quick recap so you've got everything in one place."
      : "Here's a friendly recap of what we covered together and what comes next.";
  }
  return level === "simple"
    ? "Here's a short summary of today's consult."
    : "Here's a summary of today's consult and what we agreed for next steps.";
}

function whatWeDiscussedItems(
  answers: Record<string, unknown>,
  tone: ParentSummaryTone,
  level: ParentSummaryReadingLevel,
): string[] {
  const items: string[] = [];
  const concern = (answers.mainConcern as string | undefined)?.trim() ?? "";
  const difficulties =
    (answers.difficulties as string[] | undefined)?.filter((x) => typeof x === "string") ?? [];

  if (concern) {
    items.push(
      tone === "clinical"
        ? `Presenting concern: ${truncate(concern, 240)}`
        : `Your main worry: ${truncate(concern, 200)}`,
    );
  }
  if (difficulties.length > 0) {
    const top = difficulties.slice(0, level === "simple" ? 2 : 4);
    items.push(
      tone === "clinical"
        ? `Difficulties flagged: ${top.join(", ")}`
        : `Things you wanted to focus on: ${top.join(", ")}`,
    );
  }
  if (items.length === 0) {
    items.push(
      tone === "clinical"
        ? "Initial concerns reviewed; baseline information gathered."
        : "We talked through your intake and agreed where to start.",
    );
  }
  return items;
}

function planFallback(tone: ParentSummaryTone, level: ParentSummaryReadingLevel): string {
  if (tone === "clinical") {
    return level === "detailed"
      ? "Session plan to be finalised after baseline assessment."
      : "Plan to follow.";
  }
  return "We'll firm up the plan in your first session.";
}

function homePracticeFallback(tone: ParentSummaryTone): string {
  return tone === "clinical"
    ? "Home-practice recommendations to follow."
    : "We'll share simple home-practice ideas in your first session.";
}

function nextStepsItems(
  tone: ParentSummaryTone,
  level: ParentSummaryReadingLevel,
): string[] {
  if (tone === "clinical") {
    return [
      "Book first therapy session (60 min).",
      "Review home-practice progress at session 2.",
      level === "detailed"
        ? "Reassess clinical priorities at end of agreed block."
        : "Reassess at end of agreed block.",
    ];
  }
  if (tone === "warm") {
    return [
      "Book your first session — we'll send you a few times to pick from.",
      "Try the home ideas a couple of times before we meet.",
      "Bring any questions to the next call — there are no silly ones!",
    ];
  }
  return [
    "Book your first therapy session.",
    "Try the home practice ideas before we meet again.",
    "Bring any questions to the next session.",
  ];
}

function truncate(s: string, max: number): string {
  if (s.length <= max) return s;
  return `${s.slice(0, max - 1).trim()}…`;
}

/**
 * Build a parent-summary preview (no persistence). Used by the clinician UI
 * to render the live preview as they tweak tone / reading level / sections.
 */
export async function previewParentSummary(
  db: Db,
  caseId: string,
  options: ParentSummaryOptions,
) {
  const [row] = await db.select().from(cases).where(eq(cases.id, caseId));
  if (!row) return { ok: false as const, error: "not_found" };
  const [intake] = await db
    .select()
    .from(intakeSubmissions)
    .where(eq(intakeSubmissions.caseId, caseId));
  const drafts = await db
    .select()
    .from(aiDrafts)
    .where(eq(aiDrafts.caseId, caseId));
  const plan = drafts.find((d) => d.kind === "session_plan");
  const html = buildParentSummaryHtml({
    childDisplayName: row.childDisplayName,
    answers: (intake?.answers ?? {}) as Record<string, unknown>,
    sessionPlan: (plan?.content ?? null) as Parameters<typeof buildParentSummaryHtml>[0]["sessionPlan"],
    options,
  });
  return { ok: true as const, html };
}

/** Portal-first publish: summary stored in DB (GCS optional later). */
export async function publishParentSummary(
  db: Db,
  caseId: string,
  htmlBody?: string,
  options?: ParentSummaryOptions,
) {
  const [existing] = await db.select().from(cases).where(eq(cases.id, caseId));
  if (!existing) return { ok: false as const, error: "not_found" };

  let html = htmlBody;
  if (!html) {
    const [intake] = await db
      .select()
      .from(intakeSubmissions)
      .where(eq(intakeSubmissions.caseId, caseId));
    const drafts = await db
      .select()
      .from(aiDrafts)
      .where(eq(aiDrafts.caseId, caseId));
    const plan = drafts.find((d) => d.kind === "session_plan");
    html = buildParentSummaryHtml({
      childDisplayName: existing.childDisplayName,
      answers: (intake?.answers ?? {}) as Record<string, unknown>,
      sessionPlan: (plan?.content ?? null) as Parameters<typeof buildParentSummaryHtml>[0]["sessionPlan"],
      options: options ?? defaultParentSummaryOptions,
    });
  }

  const prior = await db
    .select()
    .from(aiDrafts)
    .where(and(eq(aiDrafts.caseId, caseId), eq(aiDrafts.kind, "parent_summary")));

  if (prior.length > 0) {
    await db
      .update(aiDrafts)
      .set({
        content: {
          html,
          publishedAt: new Date().toISOString(),
          options: options ?? null,
        },
        reviewedAt: new Date(),
      })
      .where(eq(aiDrafts.id, prior[0]!.id));
  } else {
    await db.insert(aiDrafts).values({
      caseId,
      kind: "parent_summary",
      content: {
        html,
        publishedAt: new Date().toISOString(),
        options: options ?? null,
      },
      modelId: "clinician-published",
      reviewedAt: new Date(),
    });
  }

  const [updated] = await db
    .update(cases)
    .set({ status: "summary_sent", updatedAt: new Date() })
    .where(eq(cases.id, caseId))
    .returning();

  await writeAudit(db, {
    tenantId: existing.tenantId,
    caseId,
    actor: "clinician",
    action: "parent_summary.published",
  });

  return {
    ok: true as const,
    case: updated,
    viewPath: `/v1/cases/${caseId}/parent-summary`,
  };
}

export async function getPublishedParentSummary(db: Db, caseId: string) {
  const [row] = await db.select().from(cases).where(eq(cases.id, caseId));
  if (!row) return { ok: false as const, error: "not_found" };
  if (row.status !== "summary_sent") {
    return { ok: false as const, error: "not_published", status: row.status };
  }

  const drafts = await db
    .select()
    .from(aiDrafts)
    .where(and(eq(aiDrafts.caseId, caseId), eq(aiDrafts.kind, "parent_summary")));

  const draft = drafts[0];
  const content = draft?.content as { html?: string } | undefined;
  const html = content?.html ?? defaultParentSummaryHtml(row.childDisplayName);

  return { ok: true as const, case: row, html };
}
