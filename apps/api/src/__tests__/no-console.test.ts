import { readdirSync, readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const SRC_DIR = path.join(path.dirname(fileURLToPath(import.meta.url)), "..");

function listSourceFiles(dir: string): string[] {
  const out: string[] = [];
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      if (entry.name === "__tests__") continue;
      out.push(...listSourceFiles(full));
    } else if (entry.name.endsWith(".ts")) {
      out.push(full);
    }
  }
  return out;
}

describe("no PHI-unsafe logging", () => {
  it("source contains no console.* calls — use logger (PHI-safe) instead", () => {
    const offenders: string[] = [];
    for (const file of listSourceFiles(SRC_DIR)) {
      const content = readFileSync(file, "utf8");
      const lines = content.split("\n");
      lines.forEach((line, i) => {
        if (/\bconsole\.(log|warn|error|info|debug|trace)\(/.test(line)) {
          offenders.push(`${path.relative(SRC_DIR, file)}:${i + 1}`);
        }
      });
    }
    expect(offenders, "use src/logger.ts — see docs/logging-policy.md").toEqual([]);
  });
});
