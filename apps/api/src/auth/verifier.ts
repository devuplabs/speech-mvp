import type { Env } from "../config.js";
import type { VerifiedIdentity } from "./types.js";

export type AuthErrorCode =
  | "no_token"
  | "invalid_token"
  | "auth_not_configured"
  | "not_provisioned"
  | "forbidden";

/** Thrown by the auth layer; mapped to an HTTP status in the app error handler. */
export class AuthError extends Error {
  constructor(
    public readonly code: AuthErrorCode,
    message?: string,
  ) {
    super(message ?? code);
    this.name = "AuthError";
  }
}

/** Verifies a Firebase ID token and returns the caller's identity. */
export interface TokenVerifier {
  verify(idToken: string): Promise<VerifiedIdentity>;
}

/**
 * Firebase ID-token verifier.
 *
 * Wiring to the Firebase Admin SDK lands in **Auth·01 (Firebase setup)**, which
 * provides the project credentials via the Cloud Run service account. Until
 * then this fails closed with `auth_not_configured` so no protected route can
 * be reached without real verification.
 */
export class FirebaseTokenVerifier implements TokenVerifier {
  constructor(private readonly env: Env) {}

  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  async verify(_idToken: string): Promise<VerifiedIdentity> {
    throw new AuthError(
      "auth_not_configured",
      "Firebase Admin not configured yet (see Auth·01).",
    );
  }
}

export function getTokenVerifier(env: Env): TokenVerifier {
  return new FirebaseTokenVerifier(env);
}
