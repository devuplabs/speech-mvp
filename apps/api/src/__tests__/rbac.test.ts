import { describe, expect, it } from "vitest";
import {
  assertRole,
  assertSameTenant,
  canAddSeat,
  hasRole,
  seatsRemaining,
} from "../auth/rbac.js";
import type { AuthContext } from "../auth/types.js";
import { AuthError } from "../auth/verifier.js";

const admin: AuthContext = {
  userId: "u1",
  tenantId: "t1",
  email: "admin@practice.co.uk",
  role: "admin",
  firebaseUid: "fb1",
};
const clinician: AuthContext = { ...admin, userId: "u2", role: "clinician", firebaseUid: "fb2" };

describe("role guards", () => {
  it("hasRole matches any listed role", () => {
    expect(hasRole(admin, "admin")).toBe(true);
    expect(hasRole(clinician, "admin")).toBe(false);
    expect(hasRole(clinician, "admin", "clinician")).toBe(true);
  });

  it("assertRole throws forbidden for the wrong role", () => {
    expect(() => assertRole(admin, "admin")).not.toThrow();
    expect(() => assertRole(clinician, "admin")).toThrowError(AuthError);
    try {
      assertRole(clinician, "admin");
    } catch (e) {
      expect((e as AuthError).code).toBe("forbidden");
    }
  });

  it("assertSameTenant blocks cross-practice access", () => {
    expect(() => assertSameTenant(admin, "t1")).not.toThrow();
    expect(() => assertSameTenant(admin, "t2")).toThrowError(AuthError);
  });
});

describe("seat accounting", () => {
  it("seatsRemaining never goes negative", () => {
    expect(seatsRemaining(5, 3)).toBe(2);
    expect(seatsRemaining(5, 5)).toBe(0);
    expect(seatsRemaining(5, 9)).toBe(0);
  });

  it("canAddSeat reflects remaining capacity", () => {
    expect(canAddSeat(5, 4)).toBe(true);
    expect(canAddSeat(5, 5)).toBe(false);
  });
});
