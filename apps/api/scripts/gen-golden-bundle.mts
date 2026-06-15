#!/usr/bin/env tsx
/**
 * Regenerate the committed golden FHIR Bundle fixture (DEV-27).
 *
 * Produces `src/fhir/__fixtures__/golden-bundle.json` from the deterministic
 * `goldenCase()` aggregate via `toBundle`. This Bundle is what the official HL7
 * FHIR validator validates against the pinned UK Core R4 IG in CI (the
 * authoritative conformance gate — errors must be 0).
 *
 * Run after any mapper/codes change that affects emitted resources:
 *   npx tsx scripts/gen-golden-bundle.mts
 *
 * The `fhir-export.test.ts` "golden Bundle is up to date" test fails the build
 * if the committed JSON drifts from `toBundle`, so this must be re-run and
 * committed alongside mapper changes.
 */

import { writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { toBundle } from "../src/fhir/mappers.js";
import { GOLDEN_NOW, goldenCase } from "../src/fhir/__fixtures__/golden-case.js";

const here = dirname(fileURLToPath(import.meta.url));
const out = join(here, "..", "src", "fhir", "__fixtures__", "golden-bundle.json");

const bundle = toBundle(goldenCase(), GOLDEN_NOW);
writeFileSync(out, JSON.stringify(bundle, null, 2) + "\n", "utf8");

console.log(`Wrote ${out} (${bundle.entry.length} entries)`);
