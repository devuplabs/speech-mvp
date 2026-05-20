import { CloudTasksClient } from "@google-cloud/tasks";
import type { Env } from "../config.js";

const client = new CloudTasksClient();

export async function enqueueLlmPrep(
  env: Env,
  payload: { caseId: string },
): Promise<string | null> {
  if (!env.GCP_PROJECT_ID) {
    console.warn("GCP_PROJECT_ID unset; skipping Cloud Tasks enqueue (local dev)");
    return null;
  }

  const parent = client.queuePath(
    env.GCP_PROJECT_ID,
    env.GCP_REGION,
    env.LLM_CLOUD_TASKS_QUEUE,
  );

  const httpRequest: {
    httpMethod: "POST";
    headers: Record<string, string>;
    body: string;
    oidcToken?: { serviceAccountEmail: string };
    url?: string;
  } = {
    httpMethod: "POST",
    headers: { "Content-Type": "application/json" },
    body: Buffer.from(JSON.stringify(payload)).toString("base64"),
  };

  if (env.WORKER_SERVICE_URL) {
    httpRequest.url = `${env.WORKER_SERVICE_URL}/internal/tasks/llm-prep`;
  }
  if (env.RUNTIME_SERVICE_ACCOUNT) {
    httpRequest.oidcToken = { serviceAccountEmail: env.RUNTIME_SERVICE_ACCOUNT };
  }

  const [task] = await client.createTask({
    parent,
    task: { httpRequest },
  });

  return task.name ?? null;
}
