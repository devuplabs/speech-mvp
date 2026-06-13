import { describe, expect, it } from "vitest";
import { getTableName, is } from "drizzle-orm";
import { PgTable } from "drizzle-orm/pg-core";
import * as schema from "../db/schema.js";
import { PHI_REGISTRY } from "../services/phi-registry.js";

/**
 * Completeness guard (DEV-24). Every Drizzle pgTable in `schema.ts` MUST be
 * classified in the PHI registry. This makes adding a new PHI-bearing table
 * without deciding whether it is exported/erased a CI failure — the registry is
 * the single source of truth for DSAR export and right-to-erasure.
 */

function allSchemaTableNames(): string[] {
  const names: string[] = [];
  for (const value of Object.values(schema)) {
    if (is(value, PgTable)) {
      names.push(getTableName(value as PgTable));
    }
  }
  return names.sort();
}

describe("PHI registry completeness", () => {
  it("classifies every table in schema.ts", () => {
    const schemaTables = allSchemaTableNames();
    const registered = new Set(PHI_REGISTRY.map((e) => e.tableName));
    const missing = schemaTables.filter((t) => !registered.has(t));
    expect(
      missing,
      "Every schema.ts table must be classified in PHI_REGISTRY (services/phi-registry.ts). " +
        "Add an entry and choose a classification (case_phi / case_access_credential / " +
        "case_audit / practice_excluded).",
    ).toEqual([]);
  });

  it("has no registry entry for a non-existent table", () => {
    const schemaTables = new Set(allSchemaTableNames());
    const stale = PHI_REGISTRY.filter((e) => !schemaTables.has(e.tableName)).map(
      (e) => e.tableName,
    );
    expect(stale, "Registry references tables not in schema.ts").toEqual([]);
  });

  it("uses unique keys and table names", () => {
    const keys = PHI_REGISTRY.map((e) => e.key);
    const tableNames = PHI_REGISTRY.map((e) => e.tableName);
    expect(new Set(keys).size).toBe(keys.length);
    expect(new Set(tableNames).size).toBe(tableNames.length);
  });

  it("every classification is one of the known values", () => {
    const allowed = new Set([
      "case_phi",
      "case_access_credential",
      "case_audit",
      "practice_excluded",
    ]);
    for (const entry of PHI_REGISTRY) {
      expect(allowed.has(entry.classification)).toBe(true);
    }
  });

  it("case-scoped entries provide a loader; practice-excluded do not", () => {
    for (const entry of PHI_REGISTRY) {
      if (entry.classification === "practice_excluded") {
        expect(entry.loadForCase, `${entry.key} must not load per-case`).toBeUndefined();
      } else {
        expect(
          typeof entry.loadForCase,
          `${entry.key} must provide loadForCase`,
        ).toBe("function");
      }
    }
  });

  it("access-credential tables redact their token column", () => {
    const credential = PHI_REGISTRY.filter(
      (e) => e.classification === "case_access_credential",
    );
    expect(credential.length).toBeGreaterThan(0);
    for (const entry of credential) {
      expect(entry.redactedColumns ?? []).toContain("token");
    }
  });

  it("includes the audit log as a retained-on-erasure section", () => {
    const audit = PHI_REGISTRY.find((e) => e.tableName === "audit_log");
    expect(audit?.classification).toBe("case_audit");
  });
});
