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

/**
 * Firebase ID-token verifier backed by the Firebase Admin SDK.
 *
 * Credentials come from **Application Default Credentials** — on Cloud Run that
 * is the runtime service account (no JSON key, no secret). The Identity
 * Platform / Firebase project itself is provisioned via Terraform
 * (`infra/terraform/modules/firebase_auth`). When `GCP_PROJECT_ID` is unset
 * (e.g. local dev with no GCP context) it fails closed with
 * `auth_not_configured` so no protected route can be reached.
 */
export class FirebaseTokenVerifier implements TokenVerifier {
  private auth: Auth | null = null;

  constructor(private readonly env: Env) {}

  private getAuthClient(): Auth {
    const projectId = this.env.GCP_PROJECT_ID;
    if (!projectId) {
      throw new AuthError(
        "auth_not_configured",
        "GCP_PROJECT_ID is not set; cannot verify Firebase tokens.",
      );
    }
    if (!this.auth) {
      const existing = getApps().find((a) => a.name === FIREBASE_APP_NAME);
      const app: App =
        existing ??
        initializeApp(
          { credential: applicationDefault(), projectId },
          FIREBASE_APP_NAME,
        );
      this.auth = getAuth(app);
    }
    return this.auth;
  }

  async verify(idToken: string): Promise<VerifiedIdentity> {
    const client = this.getAuthClient();
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
