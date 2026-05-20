import type { Db } from "../db/client.js";
import { auditLog } from "../db/schema.js";

export async function writeAudit(
  db: Db,
  input: {
    tenantId?: string;
    caseId?: string;
    actor: string;
    action: string;
    metadata?: Record<string, unknown>;
  },
): Promise<void> {
  await db.insert(auditLog).values({
    tenantId: input.tenantId,
    caseId: input.caseId,
    actor: input.actor,
    action: input.action,
    metadata: input.metadata ?? {},
  });
}
