import { randomBytes } from "node:crypto";
import { and, eq, isNull } from "drizzle-orm";
import type { Db } from "../db/client.js";
import { casePortalLinks, cases } from "../db/schema.js";
import { writeAudit } from "./audit.js";

const PORTAL_LINK_TTL_DAYS = 90;

export function newPortalToken(): string {
  return randomBytes(32).toString("base64url");
}

export function portalLinkExpiresAt(now: Date = new Date()): Date {
  const d = new Date(now);
  d.setDate(d.getDate() + PORTAL_LINK_TTL_DAYS);
  return d;
}

/** Family portal magic-link URL for a token (mirrors the intake `?t=` pattern). */
export function buildPortalUrl(webBaseUrl: string, token: string): string {
  const base = webBaseUrl.replace(/\/$/, "");
  return `${base}/?portal=${encodeURIComponent(token)}`;
}

/**
 * Return a still-active portal token for a case, minting one only when none
 * exists — so re-publishing a summary reuses the same family link rather than
 * invalidating the one the family may already have bookmarked.
 */
export async function getOrCreatePortalToken(
  db: Db,
  caseId: string,
  now: Date = new Date(),
): Promise<{ ok: true; token: string } | { ok: false; error: "not_found" }> {
  const active = await db
    .select()
    .from(casePortalLinks)
    .where(and(eq(casePortalLinks.caseId, caseId), isNull(casePortalLinks.revokedAt)));
  const live = active.find((row) => row.expiresAt > now);
  if (live) return { ok: true, token: live.token };

  const created = await createPortalLink(db, caseId);
  if (!created.ok) return { ok: false, error: "not_found" };
  return { ok: true, token: created.token };
}

export type PortalLinkRejection = "not_found" | "revoked" | "expired";

/**
 * Pure expiry/revocation check. Revocation (an explicit clinician action)
 * wins over expiry so the family sees the more meaningful reason.
 */
export function resolvePortalLinkState(
  link: { expiresAt: Date; revokedAt: Date | null } | null | undefined,
  now: Date = new Date(),
): { ok: true } | { ok: false; error: PortalLinkRejection } {
  if (!link) return { ok: false, error: "not_found" };
  if (link.revokedAt) return { ok: false, error: "revoked" };
  if (link.expiresAt <= now) return { ok: false, error: "expired" };
  return { ok: true };
}

export async function createPortalLink(db: Db, caseId: string) {
  const [caseRow] = await db.select().from(cases).where(eq(cases.id, caseId));
  if (!caseRow) return { ok: false as const, error: "not_found" as const };

  const expiresAt = portalLinkExpiresAt();
  let linkRow: typeof casePortalLinks.$inferSelect | undefined;
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      [linkRow] = await db
        .insert(casePortalLinks)
        .values({ caseId, token: newPortalToken(), expiresAt })
        .returning();
      break;
    } catch (err) {
      const msg = err instanceof Error ? err.message : "";
      if (!msg.includes("unique") || attempt === 2) throw err;
    }
  }
  if (!linkRow) return { ok: false as const, error: "not_found" as const };

  await writeAudit(db, {
    tenantId: caseRow.tenantId,
    caseId,
    actor: "clinician",
    action: "portal_link.created",
  });

  return {
    ok: true as const,
    token: linkRow.token,
    expiresAt: linkRow.expiresAt.toISOString(),
  };
}

export async function revokePortalLinks(db: Db, caseId: string) {
  const [caseRow] = await db.select().from(cases).where(eq(cases.id, caseId));
  if (!caseRow) return { ok: false as const, error: "not_found" as const };

  await db
    .update(casePortalLinks)
    .set({ revokedAt: new Date() })
    .where(and(eq(casePortalLinks.caseId, caseId), isNull(casePortalLinks.revokedAt)));

  await writeAudit(db, {
    tenantId: caseRow.tenantId,
    caseId,
    actor: "clinician",
    action: "portal_link.revoked",
  });

  return { ok: true as const };
}

export async function resolvePortalLink(db: Db, token: string) {
  const [row] = await db
    .select()
    .from(casePortalLinks)
    .where(eq(casePortalLinks.token, token))
    .limit(1);
  if (!row) return { ok: false as const, error: "not_found" as const };

  const state = resolvePortalLinkState(row);
  if (!state.ok) return { ok: false as const, error: state.error };

  return { ok: true as const, caseId: row.caseId, expiresAt: row.expiresAt.toISOString() };
}
