export type MailgunSendInput = {
  apiKey: string;
  domain: string;
  /** API base, e.g. https://api.mailgun.net (US) or https://api.eu.mailgun.net (EU). */
  baseUrl?: string;
  from: string;
  to: string;
  subject: string;
  htmlBody: string;
  textBody?: string;
};

export type MailgunSendResult =
  | { ok: true; messageId: string }
  | { ok: false; error: string; status?: number };

const DEFAULT_BASE_URL = "https://api.mailgun.net";

/** Send a single transactional email via the Mailgun HTTP API. */
export async function sendMailgunEmail(
  input: MailgunSendInput,
): Promise<MailgunSendResult> {
  const baseUrl = (input.baseUrl ?? DEFAULT_BASE_URL).replace(/\/$/, "");
  const auth = Buffer.from(`api:${input.apiKey}`).toString("base64");
  const form = new URLSearchParams({
    from: input.from,
    to: input.to,
    subject: input.subject,
    html: input.htmlBody,
    text: input.textBody ?? stripHtml(input.htmlBody),
  });

  const res = await fetch(
    `${baseUrl}/v3/${encodeURIComponent(input.domain)}/messages`,
    {
      method: "POST",
      headers: {
        Accept: "application/json",
        Authorization: `Basic ${auth}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: form.toString(),
      signal: AbortSignal.timeout(15_000),
    },
  );

  const body = (await res.json().catch(() => ({}))) as {
    id?: string;
    message?: string;
  };

  if (!res.ok) {
    return {
      ok: false,
      status: res.status,
      error: body.message ?? `Mailgun HTTP ${res.status}`,
    };
  }

  return { ok: true, messageId: body.id ?? "unknown" };
}

function stripHtml(html: string): string {
  return html.replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").trim();
}
