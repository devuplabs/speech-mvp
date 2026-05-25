import { describe, expect, it } from "vitest";
import { registerPatientBody } from "../schemas/register-patient.js";
import { buildIntakeLinkUrl } from "../services/register-patient.js";

describe("registerPatientBody", () => {
  it("rejects invalid email", () => {
    const result = registerPatientBody.safeParse({
      tenantId: "550e8400-e29b-41d4-a716-446655440000",
      childFirstName: "Aria",
      dateOfBirth: "15 / 03 / 2019",
      parentName: "Parent",
      parentEmail: "not-an-email",
      referralSource: "nhs",
      sendIntakeLink: true,
    });
    expect(result.success).toBe(false);
  });

  it("accepts valid registration payload", () => {
    const result = registerPatientBody.safeParse({
      tenantId: "550e8400-e29b-41d4-a716-446655440000",
      childFirstName: "Aria",
      dateOfBirth: "15 / 03 / 2019",
      parentName: "Anna M.",
      parentEmail: "parent@example.com",
      referralSource: "school",
      sendIntakeLink: true,
    });
    expect(result.success).toBe(true);
  });
});

describe("buildIntakeLinkUrl", () => {
  it("embeds token in parent web URL", () => {
    const url = buildIntakeLinkUrl("http://localhost:8080", "abc123");
    expect(url).toBe("http://localhost:8080/?t=abc123");
  });
});
