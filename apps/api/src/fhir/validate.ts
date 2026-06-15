/**
 * Lightweight structural FHIR R4 validator for the export (DEV-27 CI gate).
 *
 * ── Approach & trade-off (ADR-006 / DEV-27 acceptance) ──────────────────────
 * The official HL7 Java validator gives full UK Core *profile* validation but
 * needs a JRE + the multi-hundred-MB UK Core package downloaded in CI — heavy,
 * slow, and network-dependent for a GitHub Actions smoke job. We instead run a
 * dependency-free **structural / base-R4 conformance** check in-process:
 *  - the Bundle is a `collection` with well-formed entries and `urn:uuid:` refs,
 *  - each resource has the required base-R4 elements for its type,
 *  - required-binding codes use the expected fixed values,
 *  - every internal reference resolves to a bundled resource,
 *  - declared `meta.profile`s are the pinned UK Core canonical URLs.
 *
 * What this does NOT do: validate against the full UK Core StructureDefinitions
 * (cardinality slices, value-set membership, invariants). That is the explicit
 * trade-off — full profile validation vs a fast, hermetic structural gate. The
 * gate still **fails when the output stops conforming** structurally, which is
 * the regression we care about for an emit-only layer. Upgrading to the Java
 * validator later is additive (run it over the same golden fixtures).
 *
 * Returns `errors` (must be 0 to pass) and `warnings` (tolerated, documented).
 */

import { UK_CORE } from "./codes.js";
import type { Bundle, FhirResource } from "./types.js";

export interface ValidationIssue {
  path: string;
  message: string;
}

export interface ValidationResult {
  errors: ValidationIssue[];
  warnings: ValidationIssue[];
}

const KNOWN_PROFILES = new Set<string>(Object.values(UK_CORE));

/** Required base-R4 elements per resource type we emit. */
const REQUIRED_ELEMENTS: Record<string, string[]> = {
  Organization: [],
  Patient: [],
  RelatedPerson: ["patient"],
  EpisodeOfCare: ["status", "patient"],
  ServiceRequest: ["status", "intent", "subject"],
  Appointment: ["status", "participant"],
  Encounter: ["status", "class", "subject"],
  QuestionnaireResponse: ["status"],
  Consent: ["status", "scope", "category"],
  Task: ["status", "intent"],
  CarePlan: ["status", "intent", "subject"],
  Communication: ["status"],
  DocumentReference: ["status", "content"],
  Composition: ["status", "type", "date", "title", "author"],
  Observation: ["status", "code"],
};

/** Required-binding fixed/closed codes (base R4 status value sets we use). */
const STATUS_VALUES: Record<string, Set<string>> = {
  EpisodeOfCare: new Set([
    "planned",
    "waitlist",
    "active",
    "onhold",
    "finished",
    "cancelled",
    "entered-in-error",
  ]),
  ServiceRequest: new Set([
    "draft",
    "active",
    "on-hold",
    "revoked",
    "completed",
    "entered-in-error",
    "unknown",
  ]),
  Appointment: new Set([
    "proposed",
    "pending",
    "booked",
    "arrived",
    "fulfilled",
    "cancelled",
    "noshow",
    "entered-in-error",
    "checked-in",
    "waitlist",
  ]),
  Encounter: new Set([
    "planned",
    "arrived",
    "triaged",
    "in-progress",
    "onleave",
    "finished",
    "cancelled",
    "entered-in-error",
    "unknown",
  ]),
  QuestionnaireResponse: new Set([
    "in-progress",
    "completed",
    "amended",
    "entered-in-error",
    "stopped",
  ]),
  Consent: new Set([
    "draft",
    "proposed",
    "active",
    "rejected",
    "inactive",
    "entered-in-error",
  ]),
  Task: new Set([
    "draft",
    "requested",
    "received",
    "accepted",
    "rejected",
    "ready",
    "cancelled",
    "in-progress",
    "on-hold",
    "failed",
    "completed",
    "entered-in-error",
  ]),
  CarePlan: new Set([
    "draft",
    "active",
    "on-hold",
    "revoked",
    "completed",
    "entered-in-error",
    "unknown",
  ]),
  Communication: new Set([
    "preparation",
    "in-progress",
    "not-done",
    "on-hold",
    "stopped",
    "completed",
    "entered-in-error",
    "unknown",
  ]),
  DocumentReference: new Set([
    "current",
    "superseded",
    "entered-in-error",
  ]),
  Composition: new Set([
    "preliminary",
    "final",
    "amended",
    "entered-in-error",
  ]),
  Observation: new Set([
    "registered",
    "preliminary",
    "final",
    "amended",
    "corrected",
    "cancelled",
    "entered-in-error",
    "unknown",
  ]),
};

const isObj = (v: unknown): v is Record<string, unknown> =>
  typeof v === "object" && v !== null && !Array.isArray(v);

/** Collect every `reference` string anywhere inside a resource. */
function collectReferences(node: unknown, acc: string[]): void {
  if (Array.isArray(node)) {
    for (const item of node) collectReferences(item, acc);
    return;
  }
  if (isObj(node)) {
    for (const [key, value] of Object.entries(node)) {
      if (key === "reference" && typeof value === "string") acc.push(value);
      else collectReferences(value, acc);
    }
  }
}

/** Validate one resource's required elements, status binding and profiles. */
function validateResource(
  resource: FhirResource,
  result: ValidationResult,
): void {
  const rt = resource.resourceType;
  const path = `${rt}/${resource.id}`;

  if (!resource.id) {
    result.errors.push({ path, message: "resource.id is required" });
  }

  const required = REQUIRED_ELEMENTS[rt];
  if (!required) {
    result.errors.push({ path, message: `unexpected resourceType "${rt}"` });
    return;
  }
  const asRecord = resource as unknown as Record<string, unknown>;
  for (const el of required) {
    if (asRecord[el] === undefined) {
      result.errors.push({ path, message: `missing required element "${el}"` });
    }
  }

  const statusSet = STATUS_VALUES[rt];
  if (statusSet) {
    const status = asRecord.status;
    if (typeof status === "string" && !statusSet.has(status)) {
      result.errors.push({
        path,
        message: `status "${status}" not in the R4 ${rt}.status value set`,
      });
    }
  }

  const profiles = resource.meta?.profile ?? [];
  for (const profile of profiles) {
    if (profile.startsWith("https://fhir.hl7.org.uk/") && !KNOWN_PROFILES.has(profile)) {
      result.errors.push({
        path,
        message: `unknown/unpinned UK Core profile "${profile}"`,
      });
    }
  }
  // Base-R4 resources (Task, EpisodeOfCare, Observation, Communication) declare
  // no UK Core profile by design (ADR-006 §4) — that is fine, not a warning.
}

/**
 * Validate an exported Bundle. `errors` must be empty for the export to be
 * considered conformant; `warnings` are tolerated and surfaced for visibility.
 */
export function validateBundle(bundle: Bundle): ValidationResult {
  const result: ValidationResult = { errors: [], warnings: [] };

  if (bundle.resourceType !== "Bundle") {
    result.errors.push({ path: "Bundle", message: "resourceType must be Bundle" });
  }
  if (bundle.type !== "collection") {
    result.errors.push({ path: "Bundle", message: 'Bundle.type must be "collection"' });
  }
  if (!Array.isArray(bundle.entry) || bundle.entry.length === 0) {
    result.errors.push({ path: "Bundle", message: "Bundle.entry must be non-empty" });
    return result;
  }

  const fullUrls = new Set<string>();
  for (const [i, entry] of bundle.entry.entries()) {
    const entryPath = `Bundle.entry[${i}]`;
    if (!entry.fullUrl) {
      result.errors.push({ path: entryPath, message: "entry.fullUrl is required" });
    } else {
      if (fullUrls.has(entry.fullUrl)) {
        result.errors.push({
          path: entryPath,
          message: `duplicate fullUrl "${entry.fullUrl}"`,
        });
      }
      fullUrls.add(entry.fullUrl);
    }
    if (!entry.resource) {
      result.errors.push({ path: entryPath, message: "entry.resource is required" });
      continue;
    }
    if (entry.fullUrl !== `urn:uuid:${entry.resource.id}`) {
      result.warnings.push({
        path: entryPath,
        message: "fullUrl does not match urn:uuid:<resource.id>",
      });
    }
    validateResource(entry.resource, result);
  }

  // Referential integrity: every internal urn:uuid: reference must resolve to a
  // bundled resource (external refs like Binary/... are left as-is).
  for (const entry of bundle.entry) {
    if (!entry.resource) continue;
    const refs: string[] = [];
    collectReferences(entry.resource, refs);
    for (const r of refs) {
      if (r.startsWith("urn:uuid:") && !fullUrls.has(r)) {
        result.errors.push({
          path: `${entry.resource.resourceType}/${entry.resource.id}`,
          message: `dangling internal reference "${r}"`,
        });
      }
    }
  }

  return result;
}
