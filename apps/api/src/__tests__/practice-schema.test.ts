import { describe, expect, it } from "vitest";
import {
  createPracticeBody,
  importCliniciansBody,
  inviteClinicianBody,
  updatePlanBody,
  updatePracticeConfigBody,
} from "../schemas/practice.js";

describe("createPracticeBody", () => {
  it("accepts a valid admin sign-up", () => {
    const r = createPracticeBody.safeParse({
      practiceName: "Whitfield Speech & Language",
      adminFullName: "Dr. Sarah Whitfield",
      adminEmail: "sarah@whitfieldspeech.co.uk",
    });
    expect(r.success).toBe(true);
  });

  it("requires a practice name", () => {
    const r = createPracticeBody.safeParse({ practiceName: "", adminFullName: "X" });
    expect(r.success).toBe(false);
  });
});

describe("updatePlanBody", () => {
  it("rejects zero seats", () => {
    expect(updatePlanBody.safeParse({ mode: "group", seats: 0 }).success).toBe(false);
  });
  it("accepts a group plan with seats", () => {
    expect(updatePlanBody.safeParse({ mode: "group", seats: 5 }).success).toBe(true);
  });
});

describe("updatePracticeConfigBody", () => {
  it("requires at least one field", () => {
    expect(updatePracticeConfigBody.safeParse({}).success).toBe(false);
  });
  it("accepts specialties", () => {
    const r = updatePracticeConfigBody.safeParse({
      location: "Manchester, England",
      specialties: ["Paediatric", "Dysphagia"],
    });
    expect(r.success).toBe(true);
  });
});

describe("inviteClinicianBody", () => {
  it("defaults role to clinician", () => {
    const r = inviteClinicianBody.parse({ email: "james@whitfieldspeech.co.uk" });
    expect(r.role).toBe("clinician");
  });
  it("rejects an invalid email", () => {
    expect(inviteClinicianBody.safeParse({ email: "nope" }).success).toBe(false);
  });
});

describe("importCliniciansBody", () => {
  it("requires at least one row", () => {
    expect(importCliniciansBody.safeParse({ clinicians: [] }).success).toBe(false);
  });
});
