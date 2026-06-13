import { and, asc, desc, eq, ne } from "drizzle-orm";
import type { Db } from "../db/client.js";
import { carryoverResources, cases, progressEntries, tenants, users } from "../db/schema.js";
import type {
  CreateCarryoverResourceBody,
  CreateProgressEntryBody,
  UpdateCarryoverResourceBody,
} from "../schemas/carryover.js";
import { writeAudit } from "./audit.js";
import { getPublishedParentSummary } from "./parent-summary.js";
import { resolvePortalLink } from "./portal-links.js";

export type ProgressAuthor = "parent" | "clinician";

/**
 * Pure transition rule for the carryover stage (Stage 9 — DEV-10).
 *
 * Trigger choice: we advance to `carryover` when the **first home-practice
 * resource is shared**, not when a portal link is created. A portal link can be
 * minted before any home-practice content exists (it is just an access grant),
 * so resource creation is the clearer, content-bearing signal that the family
 * has actually entered the carryover loop. We only advance from `summary_sent`
 * so the case must have had its summary published first, and a re-published /
 * already-carryover case is never rewound.
 *
 * Returns the status the case should hold after a resource is created, or `null`
 * when no status change is warranted. Unit-testable without a database.
 */
export function statusAfterCarryoverResource(currentStatus: string): "carryover" | null {
  return currentStatus === "summary_sent" ? "carryover" : null;
}

export async function createCarryoverResource(
  db: Db,
  caseId: string,
  input: CreateCarryoverResourceBody,
) {
  const [caseRow] = await db.select().from(cases).where(eq(cases.id, caseId));
  if (!caseRow) return { ok: false as const, error: "not_found" as const };

  const [row] = await db
    .insert(carryoverResources)
    .values({
      caseId,
      title: input.title,
      description: input.description ?? undefined,
      url: input.url ?? undefined,
      category: input.category,
      sourceDraftId: input.sourceDraftId ?? undefined,
    })
    .returning();

  await writeAudit(db, {
    tenantId: caseRow.tenantId,
    caseId,
    actor: "clinician",
    action: "carryover.resource_created",
    metadata: { resourceId: row.id, category: row.category },
  });

  // Advance to the carryover stage when the first resource is shared for a case
  // whose summary has been sent (see statusAfterCarryoverResource).
  const nextStatus = statusAfterCarryoverResource(caseRow.status);
  if (nextStatus) {
    await db
      .update(cases)
      .set({ status: nextStatus, updatedAt: new Date() })
      .where(eq(cases.id, caseId));
    await writeAudit(db, {
      tenantId: caseRow.tenantId,
      caseId,
      actor: "clinician",
      action: "case.carryover_started",
      metadata: { statusFrom: caseRow.status, statusTo: nextStatus, resourceId: row.id },
    });
  }

  return { ok: true as const, resource: row };
}

export async function listCarryoverResources(db: Db, caseId: string) {
  return db
    .select()
    .from(carryoverResources)
    .where(eq(carryoverResources.caseId, caseId))
    .orderBy(asc(carryoverResources.createdAt));
}

export async function updateCarryoverResource(
  db: Db,
  caseId: string,
  resourceId: string,
  patch: UpdateCarryoverResourceBody,
) {
  const [caseRow] = await db.select().from(cases).where(eq(cases.id, caseId));
  if (!caseRow) return { ok: false as const, error: "not_found" as const };

  const [row] = await db
    .update(carryoverResources)
    .set({
      ...(patch.title !== undefined ? { title: patch.title } : {}),
      ...(patch.description !== undefined ? { description: patch.description } : {}),
      ...(patch.url !== undefined ? { url: patch.url } : {}),
      ...(patch.category !== undefined ? { category: patch.category } : {}),
      ...(patch.sourceDraftId !== undefined ? { sourceDraftId: patch.sourceDraftId } : {}),
    })
    .where(
      and(eq(carryoverResources.id, resourceId), eq(carryoverResources.caseId, caseId)),
    )
    .returning();
  if (!row) return { ok: false as const, error: "not_found" as const };

  await writeAudit(db, {
    tenantId: caseRow.tenantId,
    caseId,
    actor: "clinician",
    action: "carryover.resource_updated",
    metadata: { resourceId: row.id, category: row.category },
  });

  return { ok: true as const, resource: row };
}

export async function deleteCarryoverResource(db: Db, caseId: string, resourceId: string) {
  const [caseRow] = await db.select().from(cases).where(eq(cases.id, caseId));
  if (!caseRow) return { ok: false as const, error: "not_found" as const };

  const deleted = await db
    .delete(carryoverResources)
    .where(
      and(eq(carryoverResources.id, resourceId), eq(carryoverResources.caseId, caseId)),
    )
    .returning({ id: carryoverResources.id });
  if (deleted.length === 0) return { ok: false as const, error: "not_found" as const };

  await writeAudit(db, {
    tenantId: caseRow.tenantId,
    caseId,
    actor: "clinician",
    action: "carryover.resource_deleted",
    metadata: { resourceId },
  });

  return { ok: true as const };
}

export async function listProgressEntries(db: Db, caseId: string) {
  return db
    .select()
    .from(progressEntries)
    .where(eq(progressEntries.caseId, caseId))
    .orderBy(desc(progressEntries.createdAt));
}

export async function addProgressEntry(
  db: Db,
  caseId: string,
  author: ProgressAuthor,
  input: CreateProgressEntryBody,
) {
  const [caseRow] = await db.select().from(cases).where(eq(cases.id, caseId));
  if (!caseRow) return { ok: false as const, error: "not_found" as const };

  const [row] = await db
    .insert(progressEntries)
    .values({ caseId, author, note: input.note, rating: input.rating ?? undefined })
    .returning();

  await writeAudit(db, {
    tenantId: caseRow.tenantId,
    caseId,
    actor: author,
    action: "carryover.progress_added",
    metadata: { entryId: row.id, author, rating: row.rating ?? null },
  });

  return { ok: true as const, entry: row };
}

/**
 * Everything the family portal renders for one magic link: case display info,
 * the published parent summary (null until published), shared resources and
 * the progress log. Records `portal.viewed` in the audit trail.
 */
/**
 * Best-effort reviewing-clinician name for the family-facing "reviewed by your
 * clinician" line. The MVP has no per-case clinician assignment (no FHIR
 * Practitioner link yet — see the FHIR ADR backlog), so we surface a real name
 * only when it is unambiguous: a practice with exactly one active member. We
 * never fabricate a name (and never expose HCPC, which has no field yet);
 * otherwise we return null and the portal falls back to "your clinician".
 */
export async function resolveReviewingClinicianName(
  db: Db,
  tenantId: string,
): Promise<string | null> {
  const roster = await db
    .select({ fullName: users.fullName })
    .from(users)
    .where(and(eq(users.tenantId, tenantId), ne(users.status, "disabled")));
  const named = roster.filter((u) => u.fullName && u.fullName.trim().length > 0);
  if (named.length === 1) return named[0]!.fullName!.trim();
  return null;
}

export async function getPortalPayload(db: Db, token: string) {
  const link = await resolvePortalLink(db, token);
  if (!link.ok) return link;

  const [caseRow] = await db.select().from(cases).where(eq(cases.id, link.caseId));
  if (!caseRow) return { ok: false as const, error: "not_found" as const };
  const [tenant] = await db.select().from(tenants).where(eq(tenants.id, caseRow.tenantId));

  const summary = await getPublishedParentSummary(db, link.caseId);
  const resources = await listCarryoverResources(db, link.caseId);
  const progress = await listProgressEntries(db, link.caseId);
  const reviewingClinicianName = await resolveReviewingClinicianName(
    db,
    caseRow.tenantId,
  );

  await writeAudit(db, {
    tenantId: caseRow.tenantId,
    caseId: caseRow.id,
    actor: "parent",
    action: "portal.viewed",
  });

  return {
    ok: true as const,
    payload: {
      case: {
        id: caseRow.id,
        childDisplayName: caseRow.childDisplayName,
        status: caseRow.status,
      },
      practiceName: tenant?.displayName ?? null,
      reviewingClinicianName,
      summary: summary.ok ? { html: summary.html } : null,
      resources,
      progress,
      expiresAt: link.expiresAt,
    },
  };
}
