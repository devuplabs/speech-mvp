import { and, eq, ne } from "drizzle-orm";
import type { Env } from "../config.js";
import { canAddSeat } from "../auth/rbac.js";
import type { VerifiedIdentity } from "../auth/types.js";
import type { Db } from "../db/client.js";
import { tenants, users } from "../db/schema.js";
import type {
  CreatePracticeBody,
  ImportCliniciansBody,
  InviteClinicianBody,
  UpdatePlanBody,
  UpdatePracticeConfigBody,
} from "../schemas/practice.js";
import { writeAudit } from "./audit.js";

type Tenant = typeof tenants.$inferSelect;
type User = typeof users.$inferSelect;

/** Seats consumed by a practice — every non-disabled seat (invited or active). */
export async function countSeatsUsed(db: Db, tenantId: string): Promise<number> {
  const rows = await db
    .select({ id: users.id })
    .from(users)
    .where(and(eq(users.tenantId, tenantId), ne(users.status, "disabled")));
  return rows.length;
}

/**
 * Create the practice and its admin seat from a verified Firebase identity.
 * Idempotent per Firebase user: a second call returns the existing practice.
 */
export async function createPractice(
  db: Db,
  identity: VerifiedIdentity,
  body: CreatePracticeBody,
  env: Env,
): Promise<{ tenant: Tenant; admin: User; idempotent: boolean }> {
  const [existing] = await db
    .select()
    .from(users)
    .where(eq(users.firebaseUid, identity.uid))
    .limit(1);
  if (existing) {
    const [tenant] = await db
      .select()
      .from(tenants)
      .where(eq(tenants.id, existing.tenantId))
      .limit(1);
    return { tenant, admin: existing, idempotent: true };
  }

  const email = (identity.email ?? body.adminEmail ?? "").trim().toLowerCase();

  const [tenant] = await db
    .insert(tenants)
    .values({ displayName: body.practiceName, jurisdiction: env.JURISDICTION })
    .returning();

  const [admin] = await db
    .insert(users)
    .values({
      tenantId: tenant.id,
      firebaseUid: identity.uid,
      email,
      fullName: body.adminFullName,
      role: "admin",
      status: "active",
      activatedAt: new Date(),
    })
    .returning();

  await writeAudit(db, {
    tenantId: tenant.id,
    actor: email || identity.uid,
    action: "practice.created",
  });

  return { tenant, admin, idempotent: false };
}

type PlanResult =
  | { ok: true; tenant: Tenant }
  | { ok: false; error: "not_found" }
  | { ok: false; error: "seats_below_in_use"; seats: number; used: number };

/** Set plan mode + seat count (screen 02). Single mode is always 1 seat. */
export async function updatePlan(
  db: Db,
  tenantId: string,
  body: UpdatePlanBody,
): Promise<PlanResult> {
  const [tenant] = await db.select().from(tenants).where(eq(tenants.id, tenantId)).limit(1);
  if (!tenant) return { ok: false, error: "not_found" };

  const effectiveSeats = body.mode === "single" ? 1 : body.seats;
  const used = await countSeatsUsed(db, tenantId);
  if (effectiveSeats < used) {
    return { ok: false, error: "seats_below_in_use", seats: effectiveSeats, used };
  }

  const [updated] = await db
    .update(tenants)
    .set({ mode: body.mode, seats: effectiveSeats })
    .where(eq(tenants.id, tenantId))
    .returning();
  return { ok: true, tenant: updated };
}

/** Update practice name / location / specialties (screen 03). */
export async function updatePracticeConfig(
  db: Db,
  tenantId: string,
  body: UpdatePracticeConfigBody,
): Promise<{ ok: true; tenant: Tenant } | { ok: false; error: "not_found" }> {
  const patch: Partial<Tenant> = {};
  if (body.practiceName !== undefined) patch.displayName = body.practiceName;
  if (body.location !== undefined) patch.location = body.location ?? null;
  if (body.specialties !== undefined) patch.specialties = body.specialties;

  const [updated] = await db
    .update(tenants)
    .set(patch)
    .where(eq(tenants.id, tenantId))
    .returning();
  if (!updated) return { ok: false, error: "not_found" };
  return { ok: true, tenant: updated };
}

export async function getPractice(db: Db, tenantId: string): Promise<Tenant | null> {
  const [tenant] = await db.select().from(tenants).where(eq(tenants.id, tenantId)).limit(1);
  return tenant ?? null;
}

export async function getClinician(
  db: Db,
  tenantId: string,
  userId: string,
): Promise<User | null> {
  const [user] = await db
    .select()
    .from(users)
    .where(and(eq(users.tenantId, tenantId), eq(users.id, userId)))
    .limit(1);
  return user ?? null;
}

export async function listClinicians(db: Db, tenantId: string): Promise<User[]> {
  return db
    .select()
    .from(users)
    .where(eq(users.tenantId, tenantId))
    .orderBy(users.createdAt);
}

type InviteResult =
  | { ok: true; user: User }
  | { ok: false; error: "not_found" }
  | { ok: false; error: "already_member" }
  | { ok: false; error: "no_seats_available"; seats: number; used: number };

/**
 * Invite a clinician (screen 04). Enforces the seat limit and de-dupes by email.
 * Creates the seat in `invited` state; the caller then dispatches the Firebase
 * email invite via `dispatchClinicianInvite` (Auth·05).
 */
export async function inviteClinician(
  db: Db,
  tenantId: string,
  input: InviteClinicianBody,
): Promise<InviteResult> {
  const [tenant] = await db.select().from(tenants).where(eq(tenants.id, tenantId)).limit(1);
  if (!tenant) return { ok: false, error: "not_found" };

  const email = input.email.trim().toLowerCase();
  const [dupe] = await db
    .select({ id: users.id })
    .from(users)
    .where(and(eq(users.tenantId, tenantId), eq(users.email, email)))
    .limit(1);
  if (dupe) return { ok: false, error: "already_member" };

  const used = await countSeatsUsed(db, tenantId);
  if (!canAddSeat(tenant.seats, used)) {
    return { ok: false, error: "no_seats_available", seats: tenant.seats, used };
  }

  const [row] = await db
    .insert(users)
    .values({
      tenantId,
      email,
      fullName: input.fullName,
      role: input.role,
      status: "invited",
    })
    .returning();

  await writeAudit(db, {
    tenantId,
    actor: "admin",
    action: "clinician.invited",
    metadata: { email, role: input.role },
  });

  return { ok: true, user: row };
}

/** Best-effort bulk invite (screen 04 CSV import). Reports per-row outcomes. */
export async function importClinicians(
  db: Db,
  tenantId: string,
  body: ImportCliniciansBody,
): Promise<{
  invited: User[];
  skipped: { email: string; reason: string }[];
}> {
  const invited: User[] = [];
  const skipped: { email: string; reason: string }[] = [];
  for (const row of body.clinicians) {
    const result = await inviteClinician(db, tenantId, row);
    if (result.ok) invited.push(result.user);
    else skipped.push({ email: row.email, reason: result.error });
  }
  return { invited, skipped };
}

/** Mark the practice live (screen 05) and return a summary for the UI. */
export async function activatePractice(
  db: Db,
  tenantId: string,
): Promise<
  | { ok: true; summary: { seats: number; admins: number; cliniciansInvited: number; seatsUsed: number } }
  | { ok: false; error: "not_found" }
> {
  const [tenant] = await db.select().from(tenants).where(eq(tenants.id, tenantId)).limit(1);
  if (!tenant) return { ok: false, error: "not_found" };

  const roster = await listClinicians(db, tenantId);
  const admins = roster.filter((u) => u.role === "admin").length;
  const cliniciansInvited = roster.filter((u) => u.role === "clinician").length;
  const seatsUsed = roster.filter((u) => u.status !== "disabled").length;

  await writeAudit(db, { tenantId, actor: "admin", action: "practice.activated" });

  return {
    ok: true,
    summary: { seats: tenant.seats, admins, cliniciansInvited, seatsUsed },
  };
}
