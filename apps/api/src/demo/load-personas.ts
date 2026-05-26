import { readFileSync, readdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { z } from "zod";

const demoMetaSchema = z.object({
  targetStage: z.enum([
    "intake_pending",
    "intake_submitted",
    "prep_ready",
    "triaged",
    "plan_ready",
    "summary_sent",
  ]),
  triageOutcome: z.enum([
    "strategy_only",
    "short_block",
    "full_assessment",
    "refer_out",
  ]),
  referralSource: z.enum([
    "nhs",
    "school",
    "gp",
    "other_parent",
    "self",
    "other",
  ]),
  parentName: z.string().min(1),
  parentPhone: z.string().optional(),
  initialConcerns: z.string().optional(),
  /** Hours from now for consult_at (negative = in the past). */
  consultInHours: z.number().optional(),
});

export const personaSchema = z.object({
  id: z.string(),
  label: z.string(),
  summary: z.string().optional(),
  childDisplayName: z.string(),
  parentEmail: z.string().email(),
  answers: z.record(z.unknown()),
  demo: demoMetaSchema.optional(),
});

export type DemoPersona = z.infer<typeof personaSchema>;

const personasDir = join(
  dirname(fileURLToPath(import.meta.url)),
  "../../../../scripts/personas",
);

export function loadPersonasFromRepo(): DemoPersona[] {
  return readdirSync(personasDir)
    .filter((f) => f.endsWith(".json"))
    .sort()
    .map((f) => personaSchema.parse(JSON.parse(readFileSync(join(personasDir, f), "utf8"))));
}

export function canonicalDemoPersonas(): DemoPersona[] {
  return loadPersonasFromRepo().filter((p) => p.demo != null);
}
