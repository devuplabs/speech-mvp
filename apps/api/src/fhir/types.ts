/**
 * Minimal FHIR R4 (4.0.1) type surface for Sona's emit-only export (DEV-27).
 *
 * We deliberately hand-roll the slice of the spec we emit rather than pulling in
 * a heavy `@types/fhir` dependency: the export is a *projection* of a handful of
 * resources, the shapes are stable, and keeping them local makes the mapping
 * reviewable and the CI validator self-contained (no external schema fetch).
 *
 * These are structural types only — conformance to UK Core profiles is asserted
 * by the golden-fixture validator (`validate.ts` + the fhir-export test), not by
 * the type system.
 */

export type FhirDateTime = string; // ISO 8601 instant or date
export type FhirDate = string; // YYYY-MM-DD

export interface Coding {
  system?: string;
  code?: string;
  display?: string;
  version?: string;
}

export interface CodeableConcept {
  coding?: Coding[];
  text?: string;
}

export interface Identifier {
  system?: string;
  value?: string;
  use?: string;
}

export interface HumanName {
  use?: string;
  text?: string;
  family?: string;
  given?: string[];
}

export interface ContactPoint {
  system?: "phone" | "email" | "fax" | "pager" | "url" | "sms" | "other";
  value?: string;
  use?: string;
}

export interface Address {
  text?: string;
  line?: string[];
  city?: string;
  postalCode?: string;
  country?: string;
}

export interface Reference {
  reference?: string; // e.g. "urn:uuid:..." or "Patient/123"
  display?: string;
  type?: string;
}

export interface Period {
  start?: FhirDateTime;
  end?: FhirDateTime;
}

export interface Annotation {
  text: string;
  time?: FhirDateTime;
}

export interface Attachment {
  contentType?: string;
  url?: string;
  title?: string;
  creation?: FhirDateTime;
}

export interface Meta {
  profile?: string[];
  lastUpdated?: FhirDateTime;
}

export interface Extension {
  url: string;
  valueCode?: string;
  valueString?: string;
  valueCodeableConcept?: CodeableConcept;
}

/** Base for every resource we emit. */
export interface DomainResource {
  resourceType: string;
  id: string;
  meta?: Meta;
  extension?: Extension[];
}

export interface Organization extends DomainResource {
  resourceType: "Organization";
  name?: string;
  address?: Address[];
  type?: CodeableConcept[];
}

export interface Patient extends DomainResource {
  resourceType: "Patient";
  identifier?: Identifier[];
  name?: HumanName[];
  birthDate?: FhirDate;
  gender?: "male" | "female" | "other" | "unknown";
  managingOrganization?: Reference;
}

export interface RelatedPerson extends DomainResource {
  resourceType: "RelatedPerson";
  patient: Reference;
  relationship?: CodeableConcept[];
  name?: HumanName[];
  telecom?: ContactPoint[];
}

export interface EpisodeOfCare extends DomainResource {
  resourceType: "EpisodeOfCare";
  status: string;
  patient: Reference;
  managingOrganization?: Reference;
  period?: Period;
}

export interface ServiceRequest extends DomainResource {
  resourceType: "ServiceRequest";
  status: string;
  intent: string;
  subject: Reference;
  reasonCode?: CodeableConcept[];
  authoredOn?: FhirDateTime;
}

export interface Appointment extends DomainResource {
  resourceType: "Appointment";
  status: string;
  start?: FhirDateTime;
  end?: FhirDateTime;
  participant: { actor?: Reference; status: string }[];
}

export interface Encounter extends DomainResource {
  resourceType: "Encounter";
  status: string;
  class: Coding;
  subject: Reference;
  period?: Period;
}

export interface QuestionnaireResponseItem {
  linkId: string;
  text?: string;
  answer?: { valueString?: string; valueBoolean?: boolean }[];
}

export interface QuestionnaireResponse extends DomainResource {
  resourceType: "QuestionnaireResponse";
  status: string;
  subject?: Reference;
  source?: Reference;
  authored?: FhirDateTime;
  item?: QuestionnaireResponseItem[];
}

export interface Consent extends DomainResource {
  resourceType: "Consent";
  status: string;
  scope: CodeableConcept;
  category: CodeableConcept[];
  patient?: Reference;
  dateTime?: FhirDateTime;
  policy?: { uri?: string }[];
}

export interface Task extends DomainResource {
  resourceType: "Task";
  status: string;
  intent: string;
  code?: CodeableConcept;
  businessStatus?: CodeableConcept;
  for?: Reference;
  focus?: Reference;
  authoredOn?: FhirDateTime;
  note?: Annotation[];
}

export interface CarePlanActivity {
  detail?: {
    status: string;
    code?: CodeableConcept;
    description?: string;
  };
}

export interface CarePlan extends DomainResource {
  resourceType: "CarePlan";
  status: string;
  intent: string;
  subject: Reference;
  created?: FhirDateTime;
  activity?: CarePlanActivity[];
}

export interface Communication extends DomainResource {
  resourceType: "Communication";
  status: string;
  subject?: Reference;
  recipient?: Reference[];
  sent?: FhirDateTime;
  payload?: { contentString?: string; contentReference?: Reference }[];
}

export interface DocumentReference extends DomainResource {
  resourceType: "DocumentReference";
  status: string;
  type?: CodeableConcept;
  category?: CodeableConcept[];
  subject?: Reference;
  date?: FhirDateTime;
  description?: string;
  content: { attachment: Attachment }[];
}

export interface CompositionSection {
  title?: string;
  text?: { status: string; div: string };
  code?: CodeableConcept;
}

export interface Composition extends DomainResource {
  resourceType: "Composition";
  status: string;
  type: CodeableConcept;
  subject?: Reference;
  date: FhirDateTime;
  title: string;
  author: Reference[];
  attester?: { mode: string; time?: FhirDateTime }[];
  section?: CompositionSection[];
}

export interface Observation extends DomainResource {
  resourceType: "Observation";
  status: string;
  code: CodeableConcept;
  subject?: Reference;
  effectiveDateTime?: FhirDateTime;
  performer?: Reference[];
  valueCodeableConcept?: CodeableConcept;
  valueString?: string;
  note?: Annotation[];
}

export type FhirResource =
  | Organization
  | Patient
  | RelatedPerson
  | EpisodeOfCare
  | ServiceRequest
  | Appointment
  | Encounter
  | QuestionnaireResponse
  | Consent
  | Task
  | CarePlan
  | Communication
  | DocumentReference
  | Composition
  | Observation;

export interface BundleEntry {
  fullUrl: string;
  resource: FhirResource;
}

export interface Bundle {
  resourceType: "Bundle";
  type: "collection";
  timestamp: FhirDateTime;
  entry: BundleEntry[];
}
