import type { Env } from "../config.js";
import { sendPostmarkEmail } from "./postmark.js";

export type EmailConfig = {
  configured: boolean;
  from?: string;
};

export function getEmailConfig(env: Env): EmailConfig {
  const token = env.POSTMARK_API_TOKEN?.trim();
  const from = env.POSTMARK_FROM_EMAIL?.trim();
  return {
    configured: Boolean(token && from),
    from: from || undefined,
  };
}

export async function sendParentSummaryEmail(
  env: Env,
  input: { to: string; subject: string; htmlBody: string },
): Promise<{ ok: true; messageId: string } | { ok: false; error: string }> {
  const token = env.POSTMARK_API_TOKEN?.trim();
  const from = env.POSTMARK_FROM_EMAIL?.trim();
  if (!token || !from) {
    return { ok: false, error: "postmark_not_configured" };
  }

  const result = await sendPostmarkEmail({
    token,
    from,
    to: input.to,
    subject: input.subject,
    htmlBody: input.htmlBody,
  });

  if (!result.ok) return { ok: false, error: result.error };
  return { ok: true, messageId: result.messageId };
}
