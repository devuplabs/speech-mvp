import type { AuthContext, Role } from "./types.js";
import { AuthError } from "./verifier.js";

/** Pure role check — true if the caller holds any of the given roles. */
export function hasRole(auth: AuthContext, ...roles: Role[]): boolean {
  return roles.includes(auth.role);
}

/** Throws `forbidden` unless the caller holds one of the given roles. */
export function assertRole(auth: AuthContext, ...roles: Role[]): void {
  if (!hasRole(auth, ...roles)) {
    throw new AuthError("forbidden", `requires role: ${roles.join(" | ")}`);
  }
}

/** Throws `forbidden` if the caller is acting on a different practice. */
export function assertSameTenant(auth: AuthContext, tenantId: string): void {
  if (auth.tenantId !== tenantId) {
    throw new AuthError("forbidden", "cross-practice access denied");
  }
}

/** Seats still available for invites/activation (never negative). */
export function seatsRemaining(seats: number, used: number): number {
  return Math.max(0, seats - used);
}

/** Whether the practice can take on one more clinician. */
export function canAddSeat(seats: number, used: number): boolean {
  return seatsRemaining(seats, used) > 0;
}
