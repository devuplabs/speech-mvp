import type { Env } from "../config.js";

/** Hosted dev Cloud Run sets K_SERVICE=sona-api-dev; local uses NODE_ENV=development. */
export function isDevMaintenanceAllowed(env: Env): boolean {
  const service = process.env.K_SERVICE ?? "";
  if (service.endsWith("-dev")) return true;
  return env.NODE_ENV === "development" || env.NODE_ENV === "test";
}
