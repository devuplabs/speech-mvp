import { applicationDefault, getApps, initializeApp, type App } from "firebase-admin/app";
import { getAuth, type Auth } from "firebase-admin/auth";
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

/** Dedicated Admin SDK app name so we never clash with any default app. */
const FIREBASE_APP_NAME = "sona-auth";
let cachedAuth: Auth | null = null;

/**
 * Shared Firebase Admin **Auth** client, backed by Application Default
 * Credentials — on Cloud Run that is the runtime service account (no JSON key,
 * no secret). The Identity Platform / Firebase project is provisioned via
 * Terraform (`infra/terraform/modules/firebase_auth`). Throws
 * `auth_not_configured` when `GCP_PROJECT_ID` is unset (e.g. local dev with no
 * GCP context) so callers fail closed.
 *
 * Used by both token verification and clinician credential provisioning.
 */
export function getAdminAuth(env: Env): Auth {
  const projectId = env.GCP_PROJECT_ID;
  if (!projectId) {
    throw new AuthError(
      "auth_not_configured",
      "GCP_PROJECT_ID is not set; Firebase Admin is unavailable.",
    );
  }
  if (!cachedAuth) {
    const existing = getApps().find((a) => a.name === FIREBASE_APP_NAME);
    const app: App =
      existing ??
      initializeApp(
        { credential: applicationDefault(), projectId },
        FIREBASE_APP_NAME,
      );
    cachedAuth = getAuth(app);
  }
  return cachedAuth;
}

/**
 * Firebase ID-token verifier backed by the Firebase Admin SDK (see
 * {@link getAdminAuth} for the credential/secret posture).
 */
export class FirebaseTokenVerifier implements TokenVerifier {
  constructor(private readonly env: Env) {}

  async verify(idToken: string): Promise<VerifiedIdentity> {
    const client = getAdminAuth(this.env);
    let decoded;
    try {
      decoded = await client.verifyIdToken(idToken);
    } catch (err) {
      throw new AuthError(
        "invalid_token",
        err instanceof Error ? err.message : "token verification failed",
      );
    }
    return { uid: decoded.uid, email: decoded.email ?? null };
  }
}

export function getTokenVerifier(env: Env): TokenVerifier {
  return new FirebaseTokenVerifier(env);
}
