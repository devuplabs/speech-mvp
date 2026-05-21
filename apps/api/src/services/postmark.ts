export type PostmarkSendInput = {
  token: string;
  from: string;
  to: string;
  subject: string;
  htmlBody: string;
  textBody?: string;
  messageStream?: string;
};

export type PostmarkSendResult =
  | { ok: true; messageId: string }
  | { ok: false; error: string; status?: number };

/** Send a single transactional email via Postmark HTTP API. */
export async function sendPostmarkEmail(
  input: PostmarkSendInput,
): Promise<PostmarkSendResult> {
  const res = await fetch("https://api.postmarkapp.com/email", {
    method: "POST",
    headers: {
      Accept: "application/json",
      "Content-Type": "application/json",
      "X-Postmark-Server-Token": input.token,
    },
    body: JSON.stringify({
      From: input.from,
      To: input.to,
      Subject: input.subject,
      HtmlBody: input.htmlBody,
      TextBody: input.textBody ?? stripHtml(input.htmlBody),
      MessageStream: input.messageStream ?? "outbound",
    }),
    signal: AbortSignal.timeout(15_000),
  });

  const body = (await res.json().catch(() => ({}))) as {
    MessageID?: string;
    Message?: string;
    ErrorCode?: number;
  };

  if (!res.ok) {
    return {
      ok: false,
      status: res.status,
      error: body.Message ?? `Postmark HTTP ${res.status}`,
    };
  }

  return { ok: true, messageId: body.MessageID ?? "unknown" };
}

function stripHtml(html: string): string {
  return html.replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").trim();
}
