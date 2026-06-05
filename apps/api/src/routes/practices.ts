import { Hono } from "hono";
import {
  type AuthVariables,
  requireIdentity,
  requireRole,
  requireUser,
} from "../auth/middleware.js";
import { assertSameTenant } from "../auth/rbac.js";
import { getTokenVerifier } from "../auth/verifier.js";
import type { Env } from "../config.js";
import type { Db } from "../db/client.js";
import {
  createPracticeBody,
  importCliniciansBody,
  inviteClinicianBody,
  updatePlanBody,
  updatePracticeConfigBody,
} from "../schemas/practice.js";
import {
  activatePractice,
  createPractice,
  importClinicians,
  inviteClinician,
  listClinicians,
  updatePlan,
  updatePracticeConfig,
} from "../services/practice.js";

/**
 * Practice onboarding API (Feature 3). `POST /` bootstraps a practice from a
 * verified Firebase identity; every other route requires an active **admin**
 * of the practice identified by `:id`.
 */
export function createPracticeRoutes(db: Db, env: Env) {
  const verifier = getTokenVerifier(env);
  const app = new Hono<{ Variables: AuthVariables }>();

  const asAdmin = [requireUser(db, verifier), requireRole("admin")] as const;

  // Screen 01 — admin sign-up: create practice + admin seat.
  app.post("/", requireIdentity(verifier), async (c) => {
    const body = createPracticeBody.parse(await c.req.json());
    const result = await createPractice(db, c.get("identity"), body, env);
    return c.json(
      { practice: result.tenant, admin: result.admin },
      result.idempotent ? 200 : 201,
    );
  });

  // Screen 02 — plan & seats.
  app.patch("/:id/plan", ...asAdmin, async (c) => {
    const tenantId = c.req.param("id");
    assertSameTenant(c.get("auth"), tenantId);
    const body = updatePlanBody.parse(await c.req.json());
    const result = await updatePlan(db, tenantId, body);
    if (!result.ok) {
      if (result.error === "not_found") return c.json({ error: result.error }, 404);
      return c.json(
        { error: result.error, seats: result.seats, used: result.used },
        409,
      );
    }
    return c.json({ practice: result.tenant });
  });

  // Screen 03 — practice config.
  app.patch("/:id", ...asAdmin, async (c) => {
    const tenantId = c.req.param("id");
    assertSameTenant(c.get("auth"), tenantId);
    const body = updatePracticeConfigBody.parse(await c.req.json());
    const result = await updatePracticeConfig(db, tenantId, body);
    if (!result.ok) return c.json({ error: result.error }, 404);
    return c.json({ practice: result.tenant });
  });

  // Screen 04 — clinician roster.
  app.get("/:id/clinicians", ...asAdmin, async (c) => {
    const tenantId = c.req.param("id");
    assertSameTenant(c.get("auth"), tenantId);
    const items = await listClinicians(db, tenantId);
    return c.json({ clinicians: items, seatsUsed: items.filter((u) => u.status !== "disabled").length });
  });

  // Screen 04 — invite a clinician.
  app.post("/:id/clinicians", ...asAdmin, async (c) => {
    const tenantId = c.req.param("id");
    assertSameTenant(c.get("auth"), tenantId);
    const body = inviteClinicianBody.parse(await c.req.json());
    const result = await inviteClinician(db, tenantId, body);
    if (!result.ok) {
      if (result.error === "not_found") return c.json({ error: result.error }, 404);
      if (result.error === "already_member") return c.json({ error: result.error }, 409);
      return c.json(
        { error: result.error, seats: result.seats, used: result.used },
        422,
      );
    }
    return c.json({ clinician: result.user }, 201);
  });

  // Screen 04 — CSV import (bulk invite).
  app.post("/:id/clinicians/import", ...asAdmin, async (c) => {
    const tenantId = c.req.param("id");
    assertSameTenant(c.get("auth"), tenantId);
    const body = importCliniciansBody.parse(await c.req.json());
    const result = await importClinicians(db, tenantId, body);
    return c.json(result, 201);
  });

  // Screen 05 — finish setup / go live.
  app.post("/:id/activate", ...asAdmin, async (c) => {
    const tenantId = c.req.param("id");
    assertSameTenant(c.get("auth"), tenantId);
    const result = await activatePractice(db, tenantId);
    if (!result.ok) return c.json({ error: result.error }, 404);
    return c.json(result.summary);
  });

  return app;
}
