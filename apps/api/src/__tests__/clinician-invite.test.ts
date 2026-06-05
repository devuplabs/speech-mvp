import { describe, expect, it } from "vitest";
import type { Env } from "../config.js";
import { dispatchClinicianInvite } from "../services/clinician-provisioning.js";
import { renderClinicianInviteEmail } from "../services/email.js";

describe("renderClinicianInviteEmail", () => {
  it("includes the practice name, action link and role", () => {
    const { subject, htmlBody } = renderClinicianInviteEmail({
      to: "james@whitfieldspeech.co.uk",
      practiceName: "Whitfield Speech & Language",
      inviterName: "Dr. Sarah Whitfield",
      actionLink: "https://sona.example/reset?code=abc123",
      role: "clinician",
    });
    expect(subject).toContain("Whitfield Speech & Language");
    expect(htmlBody).toContain("https://sona.example/reset?code=abc123");
    expect(htmlBody).toContain("a clinician");
    expect(htmlBody).toContain("Dr. Sarah Whitfield");
  });

  it("escapes HTML in the practice name and labels admins", () => {
    const { htmlBody } = renderClinicianInviteEmail({
      to: "x@y.com",
      practiceName: "<script>alert(1)</script>",
      actionLink: "https://sona.example/reset",
      role: "admin",
    });
    expect(htmlBody).not.toContain("<script>alert(1)</script>");
    expect(htmlBody).toContain("&lt;script&gt;");
    expect(htmlBody).toContain("an admin");
  });
});

describe("dispatchClinicianInvite", () => {
  it("fails closed when Firebase is not configured", async () => {
    const env = { GCP_PROJECT_ID: undefined } as unknown as Env;
    // db/user are never touched because the Firebase check short-circuits first.
    const user = {
      id: "u1",
      tenantId: "t1",
      email: "james@whitfieldspeech.co.uk",
      fullName: null,
      role: "clinician",
      firebaseUid: null,
    } as never;

    const result = await dispatchClinicianInvite({} as never, env, user, {
      practiceName: "Whitfield Speech & Language",
      webBaseUrl: "http://localhost:8080",
    });

    expect(result.provisioned).toBe(false);
    expect(result.emailSent).toBe(false);
    expect(result.error).toBe("auth_not_configured");
  });
});
