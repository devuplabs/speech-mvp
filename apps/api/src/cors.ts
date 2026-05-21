import type { Env } from "./config.js";

const LOCALHOST_PORTS = new Set([
  3000, 8080, 8081, 8082, 8083, 8084, 8085, 8086, 8087, 8088, 8089, 8090,
]);

function parseAllowedOrigins(env: Env): Set<string> {
  const fromEnv = env.CORS_ORIGINS?.split(",").map((s) => s.trim()).filter(Boolean) ?? [];
  return new Set(fromEnv);
}

function isLocalDevOrigin(origin: string): boolean {
  try {
    const url = new URL(origin);
    if (url.protocol !== "http:") return false;
    if (url.hostname !== "localhost" && url.hostname !== "127.0.0.1") return false;
    const port = url.port ? Number(url.port) : 80;
    return LOCALHOST_PORTS.has(port);
  } catch {
    return false;
  }
}

/**
 * Returns the origin to echo in Access-Control-Allow-Origin, or null to deny.
 * Never reflects arbitrary origins (avoids accidental wildcard behaviour).
 */
export function resolveCorsOrigin(origin: string | undefined, env: Env): string | null {
  if (!origin) return null;

  const allowed = parseAllowedOrigins(env);
  if (allowed.has(origin)) return origin;

  const localDevOk =
    env.NODE_ENV === "development" &&
    (env.CORS_ALLOW_LOCALHOST || allowed.size === 0) &&
    isLocalDevOrigin(origin);

  if (localDevOk) return origin;

  return null;
}
