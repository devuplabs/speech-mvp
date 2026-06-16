import { describe, expect, it } from "vitest";
import { ZodError } from "zod";
import type { Env } from "../config.js";
import type { Db } from "../db/client.js";
import type { VerifiedIdentity } from "../auth/types.js";
import { createPractice } from "../services/practice.js";

/**
 * DEV-83 — onboarding edge cases. A minimal chainable fake db lets us exercise
 * the guards that fire before any insert (empty email rejected; orphaned-seat
 * tenant lookup never returns undefined).
 */
function fakeDb(selectQueue: unknown[][]): Db {
  let i = 0;
  const builder = {
    from: () => builder,
    where: () => builder,
    limit: () => Promise.resolve(selectQueue[i++] ?? []),
  };
  return { select: () => builder } as unknown as Db;
}

const env = {} as Env;
const body = { practiceName: "Whitfield", adminFullName: "Dr W" } as never;

describe("createPractice onboarding guards (DEV-83)", () => {
  it("rejects an empty admin email with a ZodError (mapped to 400)", async () => {
    const db = fakeDb([[]]); // no existing seat for this uid
    const identity = { uid: "u1" } as unknown as VerifiedIdentity; // no email on the token
    await expect(createPractice(db, identity, body, env)).rejects.toBeInstanceOf(ZodError);
  });

  it("never returns an undefined tenant on the idempotent path", async () => {
    const existing = { id: "seat1", tenantId: "t-missing" };
    const db = fakeDb([[existing], []]); // seat found, but its tenant row is missing
    const identity = { uid: "u1", email: "a@b.com" } as unknown as VerifiedIdentity;
    await expect(createPractice(db, identity, body, env)).rejects.toThrow(/no tenant/);
  });
});
