import { eq } from "drizzle-orm";
import { createMiddleware } from "hono/factory";
import type { Db } from "../db/client.js";
import { users } from "../db/schema.js";
import { assertRole } from "./rbac.js";
import type { AuthContext, Role, VerifiedIdentity } from "./types.js";
import { AuthError, type TokenVerifier } from "./verifier.js";

/** Hono context variables set by the auth middlewares below. */
export type AuthVariables = {
  identity: VerifiedIdentity;
  auth: AuthContext;
};

function parseBearer(header: string | undefined): string | null {
  if (!header) return null;
  const match = /^Bearer\s+(.+)$/i.exec(header.trim());
  return match ? match[1].trim() : null;
}

/**
 * Verifies the Firebase token and exposes the raw identity as `identity`,
 * without requiring a provisioned `users` row. Used by the practice-creation
 * route, where the admin's seat does not exist yet.
 */
export function requireIdentity(verifier: TokenVerifier) {
  return createMiddleware<{ Variables: AuthVariables }>(async (c, next) => {
    const token = parseBearer(c.req.header("Authorization"));
    if (!token) throw new AuthError("no_token");
    const identity = await verifier.verify(token);
    c.set("identity", identity);
    await next();
  });
}

/**
 * Verifies the Firebase token, resolves it to an active `users` row, and
 * exposes the full `auth` context. Rejects unprovisioned or inactive seats.
 */
export function requireUser(db: Db, verifier: TokenVerifier) {
  return createMiddleware<{ Variables: AuthVariables }>(async (c, next) => {
    const token = parseBearer(c.req.header("Authorization"));
    if (!token) throw new AuthError("no_token");
    const identity = await verifier.verify(token);

    const [row] = await db
      .select()
      .from(users)
      .where(eq(users.firebaseUid, identity.uid))
      .limit(1);
    if (!row) throw new AuthError("not_provisioned");
    if (row.status !== "active") {
      throw new AuthError("forbidden", "seat is not active");
    }

    c.set("identity", identity);
    c.set("auth", {
      userId: row.id,
      tenantId: row.tenantId,
      email: row.email,
      role: row.role as Role,
      firebaseUid: identity.uid,
    });
    await next();
  });
}

/** Role guard — must run after `requireUser`. */
export function requireRole(...roles: Role[]) {
  return createMiddleware<{ Variables: AuthVariables }>(async (c, next) => {
    const auth = c.get("auth");
    if (!auth) throw new AuthError("no_token");
    assertRole(auth, ...roles);
    await next();
  });
}
