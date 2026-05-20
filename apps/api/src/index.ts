import { serve } from "@hono/node-server";
import { Hono } from "hono";
import { loadEnv } from "./config.js";
import { SelfHostedLlmClient } from "./llm/client.js";

const env = loadEnv();
const llm = new SelfHostedLlmClient(env);

const app = new Hono();

app.get("/health", (c) =>
  c.json({
    status: "ok",
    jurisdiction: env.JURISDICTION,
    inference: llm.configured ? "configured" : "pending_phase_2",
  }),
);

app.get("/ready", async (c) => {
  const inference = await llm.health();
  return c.json({
    status: "ok",
    checks: {
      api: true,
      inference,
    },
  });
});

app.get("/v1/meta", (c) =>
  c.json({
    service: "sona-api",
    version: "0.1.0",
    jurisdiction: env.JURISDICTION,
  }),
);

serve({ fetch: app.fetch, port: env.PORT }, (info) => {
  console.log(`sona-api listening on http://localhost:${info.port}`);
});
