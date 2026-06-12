import { and, asc, desc, eq } from "drizzle-orm";
import type { Db } from "../db/client.js";
import { carryoverResources, cases, progressEntries, tenants } from "../db/schema.js";
import type {
  CreateCarryoverResourceBody,
  CreateProgressEntryBody,
  UpdateCarryoverResourceBody,
} from "../schemas/carryover.js";
import { writeAudit } from "./audit.js";
import { getPublishedParentSummary } from "./parent-summary.js";
import { resolvePortalLink } from "./portal-links.js";

export type ProgressAuthor = "parent" | "clinician";

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
export async function getPortalPayload(db: Db, token: string) {
  const link = await resolvePortalLink(db, token);
  if (!link.ok) return link;

  const [caseRow] = await db.select().from(cases).where(eq(cases.id, link.caseId));
  if (!caseRow) return { ok: false as const, error: "not_found" as const };
  const [tenant] = await db.select().from(tenants).where(eq(tenants.id, caseRow.tenantId));

  const summary = await getPublishedParentSummary(db, link.caseId);
  const resources = await listCarryoverResources(db, link.caseId);
  const progress = await listProgressEntries(db, link.caseId);

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
      summary: summary.ok ? { html: summary.html } : null,
      resources,
      progress,
      expiresAt: link.expiresAt,
    },
  };
}
