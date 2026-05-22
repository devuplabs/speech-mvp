import { test, expect } from "@playwright/test";
import { readFileSync, readdirSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { intakePersonas } from "../fixtures/intake-personas.js";

/**
 * Synthetic intake personas live in three mirrored representations:
 *
 *   - JSON (source of truth):  scripts/personas/*.json
 *   - TypeScript mirror:       e2e/fixtures/intake-personas.ts
 *   - Dart mirror:             apps/sona/lib/test_utils/intake_personas.dart
 *
 * This spec asserts JSON ↔ TS parity.  Dart ↔ JSON parity is asserted by the
 * sibling Dart test at `apps/sona/test/intake_personas_parity_test.dart`.
 *
 * If you change one source you MUST change the others — these tests give you
 * a clear diff per persona so the divergence is impossible to miss.
 */

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(here, "..", "..");
const personasDir = join(repoRoot, "scripts", "personas");

test.describe("Synthetic intake personas — parity (TS ↔ JSON)", () => {
  test("JSON and TS expose the same persona set with identical answers", () => {
    const jsonFiles = readdirSync(personasDir)
      .filter((f) => f.endsWith(".json"))
      .sort();

    expect(jsonFiles).toHaveLength(intakePersonas.length);

    for (const file of jsonFiles) {
      const raw = JSON.parse(
        readFileSync(join(personasDir, file), "utf8"),
      ) as Record<string, unknown>;
      const id = raw.id as string;
      const ts = intakePersonas.find((p) => p.id === id);
      expect(ts, `TS persona missing for ${id}`).toBeDefined();

      const tsCopy = { ...ts! } as Record<string, unknown>;
      const rawCopy = { ...raw } as Record<string, unknown>;
      delete tsCopy.answers;
      delete rawCopy.answers;
      expect(rawCopy, `Top-level mismatch for ${id}`).toEqual(tsCopy);

      const tsKeys = Object.keys(ts!.answers).sort();
      const jsonKeys = Object.keys(
        raw.answers as Record<string, unknown>,
      ).sort();
      expect(jsonKeys, `Key set mismatch for ${id}`).toEqual(tsKeys);

      for (const key of tsKeys) {
        expect(
          (raw.answers as Record<string, unknown>)[key],
          `Mismatch on ${id}.${key}`,
        ).toEqual(ts!.answers[key]);
      }
    }
  });

  test("persona ids are unique and stable", () => {
    const ids = intakePersonas.map((p) => p.id);
    expect(new Set(ids).size).toBe(ids.length);
  });
});
