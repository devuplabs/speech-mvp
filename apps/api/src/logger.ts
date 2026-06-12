import type { MiddlewareHandler } from "hono";
import { randomUUID } from "node:crypto";

/**
 * PHI-safe structured logger.
 *
 * Hard rule for this codebase: logs must never contain PHI — no child or
 * parent names, dates of birth, emails, intake answers, draft content, or
 * magic-link tokens. To make that the default, context fields are dropped
 * unless they appear in the allowlist below, and errors are reduced to
 * name/code/message/stack (never pg `detail`/`parameters` or HTTP bodies).
 *
 * Error messages must not interpolate user data — see docs/logging-policy.md.
 *
 * Output is one JSON object per line with a `severity` field, which Cloud
 * Logging ingests as structured log entries.
 */

const ALLOWED_FIELDS: ReadonlySet<string> = new Set([
  "requestId",
  "caseId",
  "tenantId",
  "userId",
  "draftId",
  "migrationId",
  "taskName",
  "queue",
  "action",
  "kind",
  "reason",
  "route",
  "method",
  "status",
  "latencyMs",
  "mode",
  "port",
  "jurisdiction",
]);

export type LogFields = Record<string, unknown> & { err?: unknown };

type SerializedError = {
  name: string;
  message: string;
  code?: string;
  stack?: string;
};

/** Reduce an unknown thrown value to safe fields. Never includes pg
 * `detail`/`parameters`/`query` or response bodies, which can carry PHI. */
export function serializeError(err: unknown): SerializedError {
  if (err instanceof Error) {
    const code = (err as { code?: unknown }).code;
    return {
      name: err.name,
      message: err.message,
      ...(typeof code === "string" || typeof code === "number"
        ? { code: String(code) }
        : {}),
      ...(err.stack ? { stack: err.stack } : {}),
    };
  }
  return { name: "NonError", message: typeof err === "string" ? err : typeof err };
}

type Severity = "DEBUG" | "INFO" | "WARNING" | "ERROR";

type LogSink = (line: string) => void;

let sink: LogSink = (line) => {
  process.stdout.write(line + "\n");
};

/** Test seam — lets unit tests capture and assert log output. */
export function setLogSinkForTesting(custom: LogSink | null): void {
  sink = custom ?? ((line) => process.stdout.write(line + "\n"));
}

function emit(severity: Severity, message: string, fields?: LogFields): void {
  const entry: Record<string, unknown> = {
    severity,
    message,
    time: new Date().toISOString(),
  };
  if (fields) {
    for (const [key, value] of Object.entries(fields)) {
      if (key === "err") continue;
      if (ALLOWED_FIELDS.has(key) && value !== undefined) entry[key] = value;
    }
    if (fields.err !== undefined) entry.error = serializeError(fields.err);
  }
  sink(JSON.stringify(entry));
}

export const logger = {
  debug: (message: string, fields?: LogFields) => emit("DEBUG", message, fields),
  info: (message: string, fields?: LogFields) => emit("INFO", message, fields),
  warn: (message: string, fields?: LogFields) => emit("WARNING", message, fields),
  error: (message: string, fields?: LogFields) => emit("ERROR", message, fields),
};

export type RequestLogVariables = { requestId: string };

const UNLOGGED_PATHS = new Set(["/health", "/ready"]);

/**
 * Assigns a request ID (honouring an inbound `x-request-id` so API and worker
 * logs correlate across Cloud Tasks hops) and logs one line per request.
 * Logs the matched route pattern (e.g. `/v1/intake-links/:token`), never the
 * concrete path — concrete paths contain magic-link tokens.
 */
export function requestLogging(): MiddlewareHandler<{
  Variables: RequestLogVariables;
}> {
  return async (c, next) => {
    const requestId = c.req.header("x-request-id") ?? randomUUID();
    c.set("requestId", requestId);
    c.header("x-request-id", requestId);
    const start = Date.now();
    await next();
    if (UNLOGGED_PATHS.has(c.req.path)) return;
    logger.info("request", {
      requestId,
      method: c.req.method,
      route: c.req.routePath,
      status: c.res.status,
      latencyMs: Date.now() - start,
    });
  };
}
