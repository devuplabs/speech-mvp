/** Roles a seat can hold (Feature 2 — admin vs clinician access). */
export type Role = "admin" | "clinician";

/** Identity extracted from a verified Firebase ID token. */
export interface VerifiedIdentity {
  uid: string;
  email: string | null;
}

/**
 * Request-scoped auth context, attached after the Firebase identity has been
 * resolved to a provisioned `users` row. All tenant-scoped routes read this.
 */
export interface AuthContext {
  userId: string;
  tenantId: string;
  email: string;
  role: Role;
  firebaseUid: string;
}
