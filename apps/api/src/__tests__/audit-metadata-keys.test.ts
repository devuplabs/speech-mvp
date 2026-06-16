import { readFileSync, readdirSync, statSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import { AUDIT_METADATA_SAFE_KEYS } from "../services/dsar.js";

/**
 * Completeness guard (DEV-80). Every metadata key any service attaches to a
 * `writeAudit` / `writeViewAudit` call must be deliberately classified as either
 * RETAINED on Art. 17 erasure (in `AUDIT_METADATA_SAFE_KEYS`) or intentionally
 * DROPPED. A newly-written, unclassified key fails this test — mirroring the
 * PHI-registry completeness guard — so the scrubbed-but-intact audit trail is a
 * conscious decision, not an accident.
 *
 * Keys deliberately dropped on erasure: PII (email/role), counts/IDs on
 * export/maintenance events, model/persona identifiers, and metadata on events
 * that are not case-scoped (feedback, practice provisioning, retention purge) so
 * never reach the case-scoped scrub anyway.
 */
const DROPPED_ON_ERASURE = new Set([
  "count",
  "cutoff",
  "deleted",
  "email",
  "emailSent",
  "entryCount",
  "feedbackType",
  "journeyStage",
  "modelId",
  "personaId",
  "resourceCount",
  "role",
  "route",
  "sections",
]);

const SRC_DIR = join(dirname(fileURLToPath(import.meta.url)), "..");

function tsFiles(dir: string): string[] {
  let out: string[] = [];
  for (const entry of readdirSync(dir)) {
    const p = join(dir, entry);
    const s = statSync(p);
    if (s.isDirectory()) {
      if (entry === "__tests__") continue;
      out = out.concat(tsFiles(p));
    } else if (entry.endsWith(".ts")) {
      out.push(p);
    }
  }
  return out;
}

/** Index of the char closing the bracket that opens at `from` (inclusive). */
function matchBracket(s: string, from: number, open: string, close: string): number {
  let depth = 0;
  for (let i = from; i < s.length; i++) {
    if (s[i] === open) depth++;
    else if (s[i] === close) {
      depth--;
      if (depth === 0) return i;
    }
  }
  return -1;
}

/** Top-level keys (incl. shorthand) of a `{ ... }` object body. */
function topLevelKeys(body: string): string[] {
  const keys: string[] = [];
  let depth = 0;
  for (let i = 0; i < body.length; i++) {
    if (depth === 0) {
      const prev = body.slice(0, i).replace(/\s+$/, "").slice(-1);
      if (prev === "" || prev === "{" || prev === ",") {
        const km = /^([a-zA-Z_]\w*)\s*(:|,|}|$)/.exec(body.slice(i));
        if (km) keys.push(km[1]);
      }
    }
    const c = body[i];
    if (c === "{" || c === "(" || c === "[") depth++;
    else if (c === "}" || c === ")" || c === "]") depth--;
  }
  return keys;
}

function writtenAuditMetadataKeys(): Set<string> {
  const keys = new Set<string>();
  for (const file of [...tsFiles(join(SRC_DIR, "services")), ...tsFiles(join(SRC_DIR, "routes"))]) {
    const text = readFileSync(file, "utf8");
    const re = /write(?:View)?Audit\s*\(/g;
    let m: RegExpExecArray | null;
    while ((m = re.exec(text))) {
      const paren = text.indexOf("(", m.index);
      const parenEnd = matchBracket(text, paren, "(", ")");
      if (parenEnd < 0) continue;
      const call = text.slice(paren, parenEnd);
      const mi = call.indexOf("metadata:");
      if (mi < 0) continue;
      const brace = call.indexOf("{", mi);
      const braceEnd = matchBracket(call, brace, "{", "}");
      if (braceEnd < 0) continue;
      for (const k of topLevelKeys(call.slice(brace + 1, braceEnd))) keys.add(k);
    }
  }
  return keys;
}

describe("audit metadata key classification (DEV-80)", () => {
  it("classifies every key written to an audit event as retained or dropped", () => {
    const written = writtenAuditMetadataKeys();
    expect(written.size).toBeGreaterThan(0);
    const unclassified = [...written].filter(
      (k) => !AUDIT_METADATA_SAFE_KEYS.has(k) && !DROPPED_ON_ERASURE.has(k),
    );
    expect(
      unclassified,
      "New audit metadata key(s) found. Add each to AUDIT_METADATA_SAFE_KEYS " +
        "(services/dsar.ts) if PHI-free and worth retaining post-erasure, or to " +
        "DROPPED_ON_ERASURE in this test if it should be scrubbed.",
    ).toEqual([]);
  });

  it("retains the DEV-80 operational keys", () => {
    for (const k of ["start", "durationMinutes", "referralSource", "sendIntakeLink", "templateId"]) {
      expect(AUDIT_METADATA_SAFE_KEYS.has(k), `${k} should be retained`).toBe(true);
    }
  });

  it("keeps retained and dropped sets disjoint", () => {
    const overlap = [...DROPPED_ON_ERASURE].filter((k) => AUDIT_METADATA_SAFE_KEYS.has(k));
    expect(overlap).toEqual([]);
  });
});
