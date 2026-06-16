import { describe, expect, it } from "vitest";
import type { Env } from "../config.js";
import {
  buildInviteAcceptUrl,
  dispatchClinicianInvite,
} from "../services/clinician-provisioning.js";
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

  it("escapes the href attribute value so a quote can't break out of it (DEV-86)", () => {
    const { htmlBody } = renderClinicianInviteEmail({
      to: "x@y.com",
      practiceName: "Whitfield",
      actionLink: 'https://evil.example/"><img src=x onerror=alert(1)>',
      role: "clinician",
    });
    expect(htmlBody).not.toContain('"><img');
    expect(htmlBody).toContain("&quot;&gt;&lt;img");
  });
});

describe("buildInviteAcceptUrl", () => {
  it("rewrites a Firebase link to our invite-accept screen with the code", () => {
    const link = buildInviteAcceptUrl(
      "https://app.sona.dev/",
      "https://proj.firebaseapp.com/__/auth/action?mode=resetPassword&oobCode=ABC123&apiKey=k",
    );
    expect(link).toBe(
      "https://app.sona.dev/auth/accept-invite?mode=resetPassword&oobCode=ABC123",
    );
  });

  it("url-encodes the code and trims a trailing slash", () => {
    const link = buildInviteAcceptUrl(
      "https://app.sona.dev",
      "https://x/action?oobCode=a%2Fb+c",
    );
    expect(link).toContain("/auth/accept-invite?mode=resetPassword&oobCode=");
    // The decoded code round-trips through our URL untouched.
    expect(new URL(link).searchParams.get("oobCode")).toBe("a/b c");
  });

  it("falls back to the original link when there is no code", () => {
    const original = "https://proj.firebaseapp.com/__/auth/action?mode=verifyEmail";
    expect(buildInviteAcceptUrl("https://app.sona.dev", original)).toBe(original);
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
