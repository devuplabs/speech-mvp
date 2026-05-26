import { Hono } from "hono";
import { z } from "zod";
import type { Db } from "../db/client.js";
import type { Env } from "../config.js";
import { draftPrepBrief } from "../services/prep-brief.js";

const llmPrepBody = z.object({
  caseId: z.string().uuid(),
});

export function createTaskRoutes(db: Db, env: Env) {
  const app = new Hono();

  app.post("/llm-prep", async (c) => {
    const body = llmPrepBody.parse(await c.req.json());
    const result = await draftPrepBrief(db, body.caseId, env);
    if (!result.ok) return c.json({ error: result.error }, 404);
    return c.json({ ok: true, draft: result.draft, alreadyExists: result.alreadyExists });
  });

  return app;
}
