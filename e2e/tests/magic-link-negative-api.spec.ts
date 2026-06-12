import { test, expect, type APIRequestContext } from "@playwright/test";
import { e2eChildName } from "../fixtures/valid-intake.js";

const apiUrl = process.env.SONA_API_URL ?? "http://127.0.0.1:8081";

/**
 * Magic-link negative paths (DEV-34): expired / revoked / malformed tokens on
 * the parent intake link (`GET /v1/intake-links/:token`) and the family
 * portal (`GET /v1/portal/:token`). The pure state machines behind these are
 * unit-tested in apps/api (resolveIntakeLinkState, resolvePortalLinkState);
 * this spec proves the HTTP wiring end to end.
 */

// Well-formed (43-char base64url, like a real token) but never issued.
const WELL_FORMED_UNKNOWN_TOKEN = "A".repeat(43);

async function bootstrapE2eTenant(request: APIRequestContext): Promise<string> {
  const boot = await request.post(`${apiUrl}/v1/demo/bootstrap`, {
    data: { practice: "e2e" },
  });
  expect([200, 201]).toContain(boot.status());
  return ((await boot.json()) as { tenantId: string }).tenantId;
}

test.describe("intake link negatives", () => {
  test("malformed and unknown tokens are 404, not 500", async ({ request }) => {
    for (const junk of ["nope", WELL_FORMED_UNKNOWN_TOKEN, "%2e%2e%2f", "a-b_c"]) {
      const res = await request.get(`${apiUrl}/v1/intake-links/${junk}`);
      expect(res.status()).toBe(404);
      expect(((await res.json()) as { error: string }).error).toBe("not_found");
    }
  });

  test("revoked links expire immediately; resend rotates the token", async ({
    request,
  }) => {
    const tenantId = await bootstrapE2eTenant(request);
    const reg = await request.post(`${apiUrl}/v1/clinicians/me/patients`, {
      data: {
        tenantId,
        childFirstName: e2eChildName(),
        dateOfBirth: "01 / 06 / 2019",
        parentName: "Negative Path Parent",
        parentEmail: `e2e-link-neg-${Date.now()}@example.com`,
        referralSource: "gp",
        sendIntakeLink: true,
      },
    });
    expect(reg.status()).toBe(201);
    const body = (await reg.json()) as {
      case: { id: string };
      intakeLink: { url: string };
    };
    const caseId = body.case.id;
    const firstToken = new URL(body.intakeLink.url).searchParams.get("t")!;

    // The live link resolves — and stays resolvable: intake links are
    // multi-use until expiry (usedAt is bookkeeping, not single-use).
    for (let i = 0; i < 2; i++) {
      const ok = await request.get(`${apiUrl}/v1/intake-links/${firstToken}`);
      expect(ok.status()).toBe(200);
      expect(((await ok.json()) as { caseId: string }).caseId).toBe(caseId);
    }

    // Resend revokes the old token and issues a fresh one.
    const resend = await request.post(
      `${apiUrl}/v1/cases/${caseId}/intake-links/resend`,
      { data: {} },
    );
    expect(resend.status()).toBe(200);
    const { url: resendUrl } = (await resend.json()) as { url: string };
    const secondToken = new URL(resendUrl).searchParams.get("t")!;
    expect(secondToken).not.toBe(firstToken);

    const oldAfterResend = await request.get(`${apiUrl}/v1/intake-links/${firstToken}`);
    expect(oldAfterResend.status()).toBe(410);
    expect(((await oldAfterResend.json()) as { error: string }).error).toBe("expired");

    const newToken = await request.get(`${apiUrl}/v1/intake-links/${secondToken}`);
    expect(newToken.status()).toBe(200);

    // Explicit revoke kills the remaining link too.
    const revoke = await request.post(
      `${apiUrl}/v1/cases/${caseId}/intake-links/revoke`,
    );
    expect(revoke.status()).toBe(204);

    const afterRevoke = await request.get(`${apiUrl}/v1/intake-links/${secondToken}`);
    expect(afterRevoke.status()).toBe(410);
    expect(((await afterRevoke.json()) as { error: string }).error).toBe("expired");

    // Resending for a case that does not exist is a clean 404.
    const ghostResend = await request.post(
      `${apiUrl}/v1/cases/00000000-0000-0000-0000-000000000000/intake-links/resend`,
      { data: {} },
    );
    expect(ghostResend.status()).toBe(404);
  });

  test("locked intakes still resolve (read-only) but reject writes", async ({
    request,
  }) => {
    const tenantId = await bootstrapE2eTenant(request);
    const reg = await request.post(`${apiUrl}/v1/clinicians/me/patients`, {
      data: {
        tenantId,
        childFirstName: e2eChildName(),
        dateOfBirth: "01 / 06 / 2019",
        parentName: "Locked Intake Parent",
        parentEmail: `e2e-lock-neg-${Date.now()}@example.com`,
        referralSource: "self",
        sendIntakeLink: true,
      },
    });
    expect(reg.status()).toBe(201);
    const body = (await reg.json()) as {
      case: { id: string };
      intakeLink: { url: string };
    };
    const token = new URL(body.intakeLink.url).searchParams.get("t")!;

    const lock = await request.post(`${apiUrl}/v1/cases/${body.case.id}/intake/lock`);
    expect(lock.status()).toBe(204);

    const resolve = await request.get(`${apiUrl}/v1/intake-links/${token}`);
    expect(resolve.status()).toBe(200);
    expect(((await resolve.json()) as { locked: boolean }).locked).toBe(true);

    const draft = await request.put(
      `${apiUrl}/v1/cases/${body.case.id}/intake/draft`,
      { data: { answers: { version: 1, formStep: 2 } } },
    );
    expect(draft.status()).toBe(409);
    expect(((await draft.json()) as { error: string }).error).toBe("intake_locked");
  });
});

test.describe("portal link negatives", () => {
  test("malformed, unknown and revoked portal tokens are rejected", async ({
    request,
  }) => {
    const tenantId = await bootstrapE2eTenant(request);
    const caseRes = await request.post(`${apiUrl}/v1/cases`, {
      data: { tenantId, childDisplayName: e2eChildName() },
    });
    expect(caseRes.status()).toBe(201);
    const { id: caseId } = (await caseRes.json()) as { id: string };

    for (const junk of ["nope", WELL_FORMED_UNKNOWN_TOKEN, "%2e%2e%2f"]) {
      const res = await request.get(`${apiUrl}/v1/portal/${junk}`);
      expect(res.status()).toBe(404);
      expect(((await res.json()) as { error: string }).error).toBe("not_found");
    }

    // Progress writes against bad tokens fail closed too.
    const junkWrite = await request.post(
      `${apiUrl}/v1/portal/${WELL_FORMED_UNKNOWN_TOKEN}/progress`,
      { data: { note: "Should never land." } },
    );
    expect(junkWrite.status()).toBe(404);

    const linkRes = await request.post(`${apiUrl}/v1/cases/${caseId}/portal-links`);
    expect(linkRes.status()).toBe(201);
    const { token } = (await linkRes.json()) as { token: string };

    // Malformed payloads on a *valid* token are a 400, not a write.
    const badNote = await request.post(`${apiUrl}/v1/portal/${token}/progress`, {
      data: { note: "" },
    });
    expect(badNote.status()).toBe(400);
    expect(((await badNote.json()) as { error: string }).error).toBe(
      "validation_failed",
    );

    const revoke = await request.post(
      `${apiUrl}/v1/cases/${caseId}/portal-links/revoke`,
    );
    expect(revoke.status()).toBe(204);

    const view = await request.get(`${apiUrl}/v1/portal/${token}`);
    expect(view.status()).toBe(410);
    expect(((await view.json()) as { error: string }).error).toBe("revoked");

    const write = await request.post(`${apiUrl}/v1/portal/${token}/progress`, {
      data: { note: "Should be rejected after revoke." },
    });
    expect(write.status()).toBe(410);
    expect(((await write.json()) as { error: string }).error).toBe("revoked");

    // No progress leaked through.
    const entries = await request.get(
      `${apiUrl}/v1/cases/${caseId}/carryover/progress`,
    );
    expect(entries.status()).toBe(200);
    expect(((await entries.json()) as { entries: unknown[] }).entries).toEqual([]);

    // Portal links for unknown cases are a clean 404.
    const ghost = await request.post(
      `${apiUrl}/v1/cases/00000000-0000-0000-0000-000000000000/portal-links`,
    );
    expect(ghost.status()).toBe(404);
  });
});
