import type { Env } from "../config.js";
import { sendMailgunEmail } from "./mailgun.js";

/**
 * Transactional email (Mailgun).
 *
 * DESIGN RULE — email is **notification-only** and never carries PHI / clinical
 * content, regardless of any provider BAA/DPA. Clinical content (e.g. parent
 * summaries) is rendered only in the authenticated portal (see ADR-005). An
 * email may say "a report is ready" with a sign-in link — never the report
 * itself. The only sender here today is the clinician invite (a set-password
 * link — no PHI); any future notification email must follow the same pattern
 * and ship behind its own ADR.
 */

export type EmailConfig = {
  configured: boolean;
  from?: string;
};

export function getEmailConfig(env: Env): EmailConfig {
  const apiKey = env.MAILGUN_API_KEY?.trim();
  const domain = env.MAILGUN_DOMAIN?.trim();
  const from = env.MAILGUN_FROM_EMAIL?.trim();
  return {
    configured: Boolean(apiKey && domain && from),
    from: from || undefined,
  };
}

export type ClinicianInviteEmailInput = {
  to: string;
  practiceName: string;
  inviterName?: string;
  /** Firebase password-set / sign-in action link. */
  actionLink: string;
  role: "admin" | "clinician";
};

/** Builds the clinician invite email. Pure — safe to unit test. */
export function renderClinicianInviteEmail(input: ClinicianInviteEmailInput): {
  subject: string;
  htmlBody: string;
} {
  const roleLabel = input.role === "admin" ? "an admin" : "a clinician";
  const invitedBy = input.inviterName ? `${input.inviterName} has invited you` : "You've been invited";
  const subject = `You're invited to join ${input.practiceName} on Sona`;
  const htmlBody = `
    <div style="font-family:Inter,Arial,sans-serif;max-width:480px;margin:0 auto;color:#142433">
      <p style="font-size:18px;font-weight:700;color:#2D6A6E">Sona</p>
      <h1 style="font-size:22px;margin:16px 0 8px">Join ${escapeHtml(input.practiceName)}</h1>
      <p style="font-size:15px;line-height:1.5">
        ${escapeHtml(invitedBy)} to join <strong>${escapeHtml(input.practiceName)}</strong> as ${roleLabel} on Sona.
        Set your password to access your dashboard.
      </p>
      <p style="margin:24px 0">
        <a href="${input.actionLink}"
           style="background:#2D6A6E;color:#fff;text-decoration:none;padding:12px 20px;border-radius:8px;font-weight:600;display:inline-block">
          Set your password
        </a>
      </p>
      <p style="font-size:13px;color:#8597A4">If the button doesn't work, copy this link into your browser:<br>${escapeHtml(input.actionLink)}</p>
      <p style="font-size:12px;color:#8597A4;margin-top:24px">Secured by Firebase Authentication.</p>
    </div>`.trim();
  return { subject, htmlBody };
}

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

export async function sendClinicianInviteEmail(
  env: Env,
  input: ClinicianInviteEmailInput,
): Promise<{ ok: true; messageId: string } | { ok: false; error: string }> {
  const apiKey = env.MAILGUN_API_KEY?.trim();
  const domain = env.MAILGUN_DOMAIN?.trim();
  const from = env.MAILGUN_FROM_EMAIL?.trim();
  if (!apiKey || !domain || !from) {
    return { ok: false, error: "email_not_configured" };
  }

  const { subject, htmlBody } = renderClinicianInviteEmail(input);
  const result = await sendMailgunEmail({
    apiKey,
    domain,
    baseUrl: env.MAILGUN_BASE_URL,
    from,
    to: input.to,
    subject,
    htmlBody,
  });

  if (!result.ok) return { ok: false, error: result.error };
  return { ok: true, messageId: result.messageId };
}
