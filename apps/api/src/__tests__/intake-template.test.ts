import { describe, expect, it } from "vitest";
import {
  INTAKE_TEMPLATE_STEPS,
  isStepInTemplate,
  nextTemplateStep,
} from "../schemas/intake-template.js";
import { deriveFormStatus } from "../services/intake-forms.js";

describe("intake templates", () => {
  it("short template gates steps", () => {
    expect(INTAKE_TEMPLATE_STEPS.short).toEqual([1, 2, 3]);
    expect(isStepInTemplate("short", 4)).toBe(false);
    expect(nextTemplateStep("short", 2)).toBe(3);
    expect(nextTemplateStep("short", 3)).toBeNull();
  });

  it("follow_up template uses steps 1, 6, 7", () => {
    expect(INTAKE_TEMPLATE_STEPS.follow_up).toEqual([1, 6, 7]);
    expect(nextTemplateStep("follow_up", 1)).toBe(6);
  });
});

describe("deriveFormStatus", () => {
  it("classifies in progress when formStep > 1", () => {
    expect(
      deriveFormStatus({
        submittedAt: null,
        formStep: 2,
        linkExpiresAt: new Date(Date.now() + 86400000),
        hasIntakeRow: true,
      }),
    ).toBe("in_progress");
  });

  it("classifies expired when link past", () => {
    expect(
      deriveFormStatus({
        submittedAt: null,
        formStep: 1,
        linkExpiresAt: new Date(Date.now() - 1000),
        hasIntakeRow: true,
      }),
    ).toBe("expired");
  });
});
