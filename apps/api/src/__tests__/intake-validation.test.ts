import { describe, expect, it } from "vitest";
import { ZodError } from "zod";
import { intakeAnswersSchema } from "../schemas/intake.js";

describe("intakeAnswersSchema API validation shape", () => {
  it("returns fieldErrors keyed by field for bad email", () => {
    let caught: ZodError | null = null;
    try {
      intakeAnswersSchema.parse({
        motherEmail: "not-an-email",
        childName: "Test Child Alpha",
      });
    } catch (e) {
      caught = e as ZodError;
    }
    expect(caught).toBeInstanceOf(ZodError);
    const flat = caught!.flatten();
    expect(flat.fieldErrors.motherEmail).toBeDefined();
    expect(flat.fieldErrors.motherEmail!.length).toBeGreaterThan(0);
    expect(flat.fieldErrors.motherEmail![0]).toMatch(/email/i);
  });
});
