import { describe, expect, it } from "vitest";
import { parseJsonFromLlm } from "../llm/chat.js";

describe("parseJsonFromLlm", () => {
  it("parses plain JSON", () => {
    expect(parseJsonFromLlm<{ a: number }>('{"a":1}')).toEqual({ a: 1 });
  });

  it("extracts JSON from markdown fences", () => {
    const raw = 'Here is the result:\n```json\n{"probeAreas":["a","b"]}\n```';
    expect(parseJsonFromLlm<{ probeAreas: string[] }>(raw)?.probeAreas).toEqual([
      "a",
      "b",
    ]);
  });

  it("returns null for invalid payloads", () => {
    expect(parseJsonFromLlm("not json")).toBeNull();
  });
});
