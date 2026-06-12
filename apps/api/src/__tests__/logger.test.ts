import { afterEach, describe, expect, it } from "vitest";
import { logger, serializeError, setLogSinkForTesting } from "../logger.js";

function capture(): string[] {
  const lines: string[] = [];
  setLogSinkForTesting((line) => lines.push(line));
  return lines;
}

afterEach(() => setLogSinkForTesting(null));

describe("logger field allowlist", () => {
  it("keeps allowlisted identifiers and drops everything else", () => {
    const lines = capture();
    logger.info("intake.submitted", {
      caseId: "case-1",
      tenantId: "tenant-1",
      requestId: "req-1",
      // PHI-shaped fields that must never reach the log line:
      childDisplayName: "Aria T.",
      parentEmail: "parent@example.com",
      answers: { concern: "speech sounds" },
      htmlBody: "<p>summary</p>",
      token: "secret-magic-link",
    });

    expect(lines).toHaveLength(1);
    const entry = JSON.parse(lines[0]);
    expect(entry).toMatchObject({
      severity: "INFO",
      message: "intake.submitted",
      caseId: "case-1",
      tenantId: "tenant-1",
      requestId: "req-1",
    });
    const raw = lines[0];
    expect(raw).not.toContain("Aria");
    expect(raw).not.toContain("parent@example.com");
    expect(raw).not.toContain("speech sounds");
    expect(raw).not.toContain("summary");
    expect(raw).not.toContain("secret-magic-link");
  });

  it("emits valid JSON with severity levels Cloud Logging understands", () => {
    const lines = capture();
    logger.debug("d");
    logger.info("i");
    logger.warn("w");
    logger.error("e");
    const severities = lines.map((l) => JSON.parse(l).severity);
    expect(severities).toEqual(["DEBUG", "INFO", "WARNING", "ERROR"]);
    for (const line of lines) expect(JSON.parse(line).time).toBeTruthy();
  });
});

describe("error serialization", () => {
  it("keeps name/message/code/stack and drops pg-style value-bearing fields", () => {
    const pgStyle = Object.assign(new Error("duplicate key violates constraint"), {
      code: "23505",
      detail: "Key (parent_email)=(parent@example.com) already exists.",
      parameters: ["Aria T."],
      query: "INSERT INTO cases ...",
    });
    const serialized = serializeError(pgStyle);
    expect(serialized.name).toBe("Error");
    expect(serialized.code).toBe("23505");
    expect(serialized.stack).toBeTruthy();
    const raw = JSON.stringify(serialized);
    expect(raw).not.toContain("parent@example.com");
    expect(raw).not.toContain("Aria");
    expect(raw).not.toContain("INSERT INTO");
  });

  it("handles non-Error throwables", () => {
    expect(serializeError("boom").name).toBe("NonError");
    expect(serializeError(42).message).toBe("number");
  });

  it("attaches serialized errors via the err field", () => {
    const lines = capture();
    logger.warn("cloud_tasks.create_task_failed", {
      caseId: "case-1",
      err: new Error("deadline exceeded"),
    });
    const entry = JSON.parse(lines[0]);
    expect(entry.error.message).toBe("deadline exceeded");
    expect(entry.caseId).toBe("case-1");
  });
});
