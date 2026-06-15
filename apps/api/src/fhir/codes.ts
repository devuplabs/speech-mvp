/**
 * UK Core profile URLs, terminology systems and Sona-local CodeSystems for the
 * FHIR export (DEV-27 / ADR-006).
 *
 * Conformance baseline: **UK Core STU2, package `UK.Core.r4.v2@2.0.2`** (per
 * ADR-006 §"Standards baseline"). Profile canonical URLs are
 * `https://fhir.hl7.org.uk/StructureDefinition/UKCore-*`. Where ADR-006 §4
 * records that no UK Core profile exists for a resource in STU2 (Task,
 * EpisodeOfCare, general Observation, Communication) we emit **base FHIR R4**
 * and assert no profile, which is honest and standard practice.
 *
 * Where a SNOMED concept is not confidently known we use a **Sona-local
 * CodeSystem** with a stable URI rather than mis-coding to an approximate SNOMED
 * code (ADR-006 §"Terminology" — "We do not invent SNOMED codes"). Replacing a
 * local code with the verified SNOMED concept later is a serializer change.
 */

/** Pinned UK Core package version (informational; emit-only). */
export const UK_CORE_PACKAGE = "UK.Core.r4.v2@2.0.2";

/** UK Core StructureDefinition canonical URLs (STU2). */
export const UK_CORE = {
  Organization: "https://fhir.hl7.org.uk/StructureDefinition/UKCore-Organization",
  Patient: "https://fhir.hl7.org.uk/StructureDefinition/UKCore-Patient",
  RelatedPerson: "https://fhir.hl7.org.uk/StructureDefinition/UKCore-RelatedPerson",
  ServiceRequest: "https://fhir.hl7.org.uk/StructureDefinition/UKCore-ServiceRequest",
  Appointment: "https://fhir.hl7.org.uk/StructureDefinition/UKCore-Appointment",
  Encounter: "https://fhir.hl7.org.uk/StructureDefinition/UKCore-Encounter",
  QuestionnaireResponse:
    "https://fhir.hl7.org.uk/StructureDefinition/UKCore-QuestionnaireResponse",
  Consent: "https://fhir.hl7.org.uk/StructureDefinition/UKCore-Consent",
  CarePlan: "https://fhir.hl7.org.uk/StructureDefinition/UKCore-CarePlan",
  DocumentReference:
    "https://fhir.hl7.org.uk/StructureDefinition/UKCore-DocumentReference",
  Composition: "https://fhir.hl7.org.uk/StructureDefinition/UKCore-Composition",
} as const;

/** Standard terminology systems. */
export const SYSTEM = {
  snomed: "http://snomed.info/sct",
  nhsNumber: "https://fhir.nhs.uk/Id/nhs-number",
  /** HL7 RoleCode — used by the UK Core RelatedPerson relationship value set. */
  roleCode: "http://terminology.hl7.org/CodeSystem/v3-RoleCode",
  consentScope: "http://terminology.hl7.org/CodeSystem/consentscope",
  consentCategory: "http://terminology.hl7.org/CodeSystem/v3-ActCode",
  encounterClass: "http://terminology.hl7.org/CodeSystem/v3-ActCode",
  loinc: "http://loinc.org",
} as const;

/** Sona-local CodeSystem base — stable URIs for enum→code maps (ADR-006 §5 P2). */
const SONA_CS = "https://sona.health/fhir/CodeSystem";
export const SONA_CODESYSTEM = {
  triageOutcome: `${SONA_CS}/triage-outcome`,
  carryoverCategory: `${SONA_CS}/carryover-category`,
  progressRating: `${SONA_CS}/progress-rating`,
  draftKind: `${SONA_CS}/ai-draft-kind`,
} as const;

/**
 * Parent/carer relationship enum → RelatedPerson.relationship coding.
 * HL7 v3 RoleCode is the value set UK Core's RelatedPerson relationship binds to.
 */
export const RELATIONSHIP_CODE: Record<string, { code: string; display: string }> = {
  parent: { code: "PRN", display: "parent" },
  mother: { code: "MTH", display: "mother" },
  father: { code: "FTH", display: "father" },
  guardian: { code: "GUARD", display: "guardian" },
  carer: { code: "CAREGIVER", display: "caregiver" },
  other: { code: "O", display: "other" },
};

/** progress_rating enum → local coded scale. */
export const PROGRESS_RATING_DISPLAY: Record<string, string> = {
  tried_it: "Tried it",
  going_well: "Going well",
  finding_it_hard: "Finding it hard",
};

/** carryover_resource_category enum → local code display. */
export const CARRYOVER_CATEGORY_DISPLAY: Record<string, string> = {
  home_practice: "Home practice",
  reading: "Reading",
  activity: "Activity",
  other: "Other",
};
