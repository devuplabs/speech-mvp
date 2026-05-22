#!/usr/bin/env node
/**
 * Seed the dev API with synthetic intake cases for every persona.
 *
 * Drives the same `/v1/demo/bootstrap` + `POST /v1/cases` + `PUT intake/draft`
 * + `POST intake` + `POST triage` + `POST parent-summary/publish` endpoints
 * the real Flutter app calls — so anything seeded here renders on the
 * clinician dashboard exactly as a real intake would.
 *
 * Usage:
 *   node scripts/seed-dev.ts
 *   SONA_API_URL=http://localhost:8081 node scripts/seed-dev.ts
 *   SONA_API_URL=https://sona-api-dev-3rhenudy6a-nw.a.run.app \
 *     SEED_STAGES=intake_submitted,prep_ready,triaged,plan_ready,summary_sent \
 *     SEED_PER_STAGE=1 \
 *     node scripts/seed-dev.ts
 *
 * Env knobs:
 *   SONA_API_URL    — defaults to http://localhost:8081
 *   SEED_STAGES     — comma list of stages to advance each persona through;
 *                     defaults to "intake_submitted,prep_ready,triaged,plan_ready"
 *                     (omit summary_sent to leave the summary unpublished)
 *   SEED_PER_STAGE  — how many duplicate cases per persona per stage; default 1
 *   PERSONAS        — comma list of persona ids; default: all
 *
 * Privacy: personas are synthetic. Never point this at prod.
 */

import { readFileSync, readdirSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
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

async function bootstrapTenant(): Promise<string> {
  const out = await http<{ tenantId: string }>(
    "POST",
    "/v1/demo/bootstrap",
    {},
  );
  return out.tenantId;
}

async function seedOne(persona: Persona, stage: Stage, tenantId: string) {
  const suffix = ` · seed ${new Date().toISOString().slice(11, 19)}`;
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
    await http(
      "PUT",
      `/v1/cases/${caseId}/intake/draft`,
      {
        answers: { ...persona.answers, formStep: 4 },
        parentEmail: persona.parentEmail,
        childDisplayName,
      },
    );
    return { caseId, stage };
  }

  // Always draft first to mimic the real Flutter pattern.
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
  // Stub prep_brief lands automatically; status becomes prep_ready.

  if (STAGE_ORDER.indexOf(stage) >= STAGE_ORDER.indexOf("triaged")) {
    await http("POST", `/v1/cases/${caseId}/triage`, {
      outcome: persona.id.includes("refer") ? "refer_out" : "short_block",
      reason: `Seed (${persona.id}) — stub triage from seed-dev`,
    });
    // Stub session_plan lands automatically; status becomes plan_ready.
  }

  if (STAGE_ORDER.indexOf(stage) >= STAGE_ORDER.indexOf("summary_sent")) {
    await http("POST", `/v1/cases/${caseId}/parent-summary/publish`, {});
  }

  return { caseId, stage };
}

(async () => {
  const personas = loadPersonas();
  if (personas.length === 0) {
    console.error("No personas matched filter:", personasFilter.join(","));
    process.exit(2);
  }
  console.log(
    `Seeding ${personas.length} persona(s) × ${perStage} × ${stages.length} stage(s) -> ${apiUrl}`,
  );

  const tenantId = await bootstrapTenant();
  console.log(`Demo tenant: ${tenantId}`);

  const created: Array<{
    persona: string;
    caseId: string;
    stage: Stage;
  }> = [];

  for (const persona of personas) {
    for (const stage of stages) {
      for (let i = 0; i < perStage; i++) {
        const out = await seedOne(persona, stage, tenantId);
        created.push({ persona: persona.id, ...out });
        console.log(`  ✓ ${persona.id} -> ${stage} (case=${out.caseId})`);
      }
    }
  }

  console.log(`\nSeeded ${created.length} case(s).`);
})().catch((err) => {
  console.error(err);
  process.exit(1);
});
