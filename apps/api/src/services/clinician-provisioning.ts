import { eq } from "drizzle-orm";
import { getAdminAuth } from "../auth/verifier.js";
import type { Env } from "../config.js";
import type { Db } from "../db/client.js";
import { users } from "../db/schema.js";
import { writeAudit } from "./audit.js";
import { sendClinicianInviteEmail } from "./email.js";

type User = typeof users.$inferSelect;

export type InviteDispatchContext = {
  practiceName: string;
  inviterName?: string | null;
  /** Web origin used to build the post-action continue URL. */
  webBaseUrl: string;
};

export type InviteDispatchResult = {
  /** True once a Firebase user exists and a set-password link was generated. */
  provisioned: boolean;
  emailSent: boolean;
  firebaseUid?: string;
  error?: string;
};

/**
 * Provision a Firebase credential for an invited clinician (Auth·05).
 *
 * Creates (or reuses) the Firebase user, links it to the seat via
 * `firebase_uid`, generates a "set your password" action link, and emails it.
 * Best-effort: if Firebase or Postmark is not configured, the invited seat is
 * left intact and the admin can resend — we never roll back the invite.
 */
export async function dispatchClinicianInvite(
  db: Db,
  env: Env,
  user: User,
  ctx: InviteDispatchContext,
): Promise<InviteDispatchResult> {
  let auth: ReturnType<typeof getAdminAuth>;
  try {
    auth = getAdminAuth(env);
  } catch {
    return { provisioned: false, emailSent: false, error: "auth_not_configured" };
  }

  // 1. Ensure a Firebase user exists for this email (idempotent re-invite).
  let firebaseUid: string;
  try {
    const existing = await auth.getUserByEmail(user.email).catch(() => null);
    firebaseUid = existing
      ? existing.uid
      : (
          await auth.createUser({
            email: user.email,
            displayName: user.fullName ?? undefined,
            emailVerified: false,
          })
        ).uid;
  } catch (err) {
    return {
      provisioned: false,
      emailSent: false,
      error: err instanceof Error ? err.message : "firebase_user_failed",
    };
  }

  // 2. Link the Firebase user to the seat.
  if (user.firebaseUid !== firebaseUid) {
    await db.update(users).set({ firebaseUid }).where(eq(users.id, user.id));
  }

  // 3. Generate a set-password link that returns to the invite-accept screen.
  const continueUrl = `${ctx.webBaseUrl.replace(/\/$/, "")}/auth/accept-invite`;
  let actionLink: string;
  try {
    actionLink = await auth.generatePasswordResetLink(user.email, { url: continueUrl });
  } catch (err) {
    return {
      provisioned: true,
      emailSent: false,
      firebaseUid,
      error: err instanceof Error ? err.message : "link_generation_failed",
    };
  }

  // 4. Send the invite email (best-effort).
  const email = await sendClinicianInviteEmail(env, {
    to: user.email,
    practiceName: ctx.practiceName,
    inviterName: ctx.inviterName ?? undefined,
    actionLink,
    role: user.role,
  });

  await writeAudit(db, {
    tenantId: user.tenantId,
    actor: "system",
    action: "clinician.invite_dispatched",
    metadata: { email: user.email, emailSent: email.ok },
  });

  return {
    provisioned: true,
    emailSent: email.ok,
    firebaseUid,
    error: email.ok ? undefined : email.error,
  };
}
