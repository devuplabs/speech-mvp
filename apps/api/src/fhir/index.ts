/**
 * FHIR R4 / UK Core export layer (DEV-27, ADR-006).
 *
 * Emit-only: pure mappers from a loaded case aggregate to a UK Core `collection`
 * Bundle. No persistence, no FHIR server. See ADR-006 for the field-level
 * mapping and the deliberately-excluded list.
 */
export * from "./types.js";
export * from "./mappers.js";
export * from "./validate.js";
export { UK_CORE, UK_CORE_PACKAGE } from "./codes.js";
