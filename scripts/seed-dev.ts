#!/usr/bin/env node
/**
 * Seed the dev API with synthetic intake cases.
 *
 * Modes:
 *   SEED_MODE=canonical (default) — idempotent realistic caseload on the demo tenant
 *     via POST /v1/demo/seed-canonical (Aria, Jaden, Mia, Theo at target stages).
 *   SEED_MODE=ephemeral — legacy behaviour: timestamp-suffixed children on the E2E tenant
 *     for load / regression scripts (does not touch the demo caseload).
 *
 * Usage:
 *   node scripts/seed-dev.ts
 *   SEED_MODE=ephemeral SONA_API_URL=http://localhost:8081 node scripts/seed-dev.ts
 *
 * Ephemeral env knobs:
 *   SEED_STAGES, SEED_PER_STAGE, PERSONAS — see below.
 *
 * Privacy: personas are synthetic. Never point this at prod.
 */

import { readFileSync, readdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

type Persona = {
  id: string;
  label: string;
  childDisplayName: string;
  parentEmail: string;
  answers: Record<string, unknown>;
};

type Stage =
  | "intake_pending"
  | "intake_submitted"
  | "prep_ready"
  | "triaged"
  | "plan_ready"
  | "summary_sent";

const STAGE_ORDER: Stage[] = [
  "intake_pending",
  "intake_submitted",
  "prep_ready",
  "triaged",
  "plan_ready",
  "summary_sent",
];

const here = dirname(fileURLToPath(import.meta.url));
const personasDir = join(here, "personas");
const apiUrl = (process.env.SONA_API_URL ?? "http://localhost:8081").replace(
  /\/$/,
  "",
);
const seedMode = (process.env.SEED_MODE ?? "canonical").toLowerCase();
const personasFilter = (process.env.PERSONAS ?? "").split(",").filter(Boolean);
const perStage = Number(process.env.SEED_PER_STAGE ?? "1");
const stages = (
  process.env.SEED_STAGES ?? "intake_submitted,prep_ready,triaged,plan_ready"
)
  .split(",")
  .map((s) => s.trim()) as Stage[];

if (apiUrl.includes("sona-api-prod")) {
  console.error("Refusing to seed against a prod-looking URL:", apiUrl);
  process.exit(2);
}

function loadPersonas(): Persona[] {
  const files = readdirSync(personasDir)
    .filter((f) => f.endsWith(".json"))
    .sort();
  const all = files.map(
    (f) => JSON.parse(readFileSync(join(personasDir, f), "utf8")) as Persona,
  );
  if (personasFilter.length === 0) return all;
  return all.filter((p) => personasFilter.includes(p.id));
}

async function http<T = unknown>(
  method: string,
  path: string,
  body?: unknown,
  acceptable: number[] = [200, 201],
): Promise<T> {
  const res = await fetch(`${apiUrl}${path}`, {
    method,
    headers: { "Content-Type": "application/json" },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  if (!acceptable.includes(res.status)) {
    throw new Error(
      `${method} ${path} -> ${res.status} ${text.slice(0, 400)}`,
    );
  }
  return (text ? JSON.parse(text) : {}) as T;
}

async function seedCanonical() {
  const result = await http<{
    tenantId: string;
    displayName: string;
    cases: Array<{ personaId: string; caseId: string; created: boolean; stage: string }>;
  }>("POST", "/v1/demo/seed-canonical", { practice: "demo" });
  console.log(`Canonical demo tenant: ${result.tenantId} (${result.displayName})`);
  for (const row of result.cases) {
    const tag = row.created ? "created" : "updated";
    console.log(`  ✓ ${row.personaId} -> ${row.stage} (${tag}, case=${row.caseId})`);
  }
  console.log(`\nSeeded ${result.cases.length} canonical case(s).`);
}

async function bootstrapE2eTenant(): Promise<string> {
  const out = await http<{ tenantId: string }>(
    "POST",
    "/v1/demo/bootstrap",
    { practice: "e2e" },
  );
  return out.tenantId;
}

async function seedOneEphemeral(persona: Persona, stage: Stage, tenantId: string) {
  const suffix = ` · e2e ${new Date().toISOString().slice(11, 19)}`;
  const childDisplayName = `${persona.childDisplayName}${suffix}`;

  const caseRow = await http<{ id: string }>(
    "POST",
    "/v1/cases",
    {
      tenantId,
      parentEmail: persona.parentEmail,
      childDisplayName,
    },
    [201],
  );
  const caseId = caseRow.id;

  if (stage === "intake_pending") {
    await http("PUT", `/v1/cases/${caseId}/intake/draft`, {
      answers: { ...persona.answers, formStep: 4 },
      parentEmail: persona.parentEmail,
      childDisplayName,
    });
    return { caseId, stage };
  }

  await http("PUT", `/v1/cases/${caseId}/intake/draft`, {
    answers: { ...persona.answers, formStep: 8 },
    parentEmail: persona.parentEmail,
    childDisplayName,
  });

  await http(
    "POST",
    `/v1/cases/${caseId}/intake`,
    {
      answers: {
        ...persona.answers,
        formStep: 8,
        consentGuardian: true,
        consentPrivacy: true,
        consentAccurate: true,
      },
      consentVersion: "mvp-v1",
      parentEmail: persona.parentEmail,
      childDisplayName,
    },
    [201],
  );

  if (STAGE_ORDER.indexOf(stage) >= STAGE_ORDER.indexOf("triaged")) {
    await http("POST", `/v1/cases/${caseId}/triage`, {
      outcome: persona.id.includes("refer") ? "refer_out" : "short_block",
      reason: `E2E seed (${persona.id})`,
    });
  }

  if (STAGE_ORDER.indexOf(stage) >= STAGE_ORDER.indexOf("summary_sent")) {
    await http("POST", `/v1/cases/${caseId}/parent-summary/publish`, {});
  }

  return { caseId, stage };
}

async function seedEphemeral() {
  const personas = loadPersonas();
  if (personas.length === 0) {
    console.error("No personas matched filter:", personasFilter.join(","));
    process.exit(2);
  }
  console.log(
    `Ephemeral E2E seed: ${personas.length} persona(s) × ${perStage} × ${stages.length} stage(s) -> ${apiUrl}`,
  );

  const tenantId = await bootstrapE2eTenant();
  console.log(`E2E tenant: ${tenantId}`);

  const created: Array<{ persona: string; caseId: string; stage: Stage }> = [];

  for (const persona of personas) {
    for (const stage of stages) {
      for (let i = 0; i < perStage; i++) {
        const out = await seedOneEphemeral(persona, stage, tenantId);
        created.push({ persona: persona.id, ...out });
        console.log(`  ✓ ${persona.id} -> ${stage} (case=${out.caseId})`);
      }
    }
  }

  console.log(`\nSeeded ${created.length} ephemeral case(s).`);
}

(async () => {
  if (seedMode === "canonical") {
    await seedCanonical();
    return;
  }
  if (seedMode === "ephemeral") {
    await seedEphemeral();
    return;
  }
  console.error(`Unknown SEED_MODE=${seedMode} (use canonical or ephemeral)`);
  process.exit(2);
})().catch((err) => {
  console.error(err);
  process.exit(1);
});
