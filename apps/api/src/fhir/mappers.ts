/**
 * Pure FHIR R4 / UK Core mappers (DEV-27, implementing ADR-006 §3).
 *
 * Each `to*` function is a pure function of the loaded case aggregate — no DB,
 * no I/O, no persistence. The serializer is emit-only: it projects Sona's
 * relational rows into UK Core resources and assembles a `collection` Bundle.
 *
 * Hard rules enforced here (ADR-006 §3):
 *  - Tokens / access-credential rows (intake & portal links) are NEVER emitted.
 *  - Internal UUIDs are used as in-Bundle `urn:uuid:` references only, never as
 *    external business identifiers.
 *  - Unreviewed AI drafts (`reviewedAt == null`) are excluded — not record
 *    material until a clinician attests. `prep_brief` is working notes: excluded
 *    by default.
 *  - `modelId` is not emitted into the clinical record.
 *  - Absent structured demographics are emitted as absent, never guessed.
 */

import {
  CARRYOVER_CATEGORY_DISPLAY,
  PROGRESS_RATING_DISPLAY,
  RELATIONSHIP_CODE,
  SONA_CODESYSTEM,
  SYSTEM,
  UK_CORE,
} from "./codes.js";
import type {
  Appointment,
  Bundle,
  BundleEntry,
  CarePlan,
  Communication,
  Composition,
  Consent,
  DocumentReference,
  Encounter,
  EpisodeOfCare,
  FhirResource,
  HumanName,
  Observation,
  Organization,
  Patient,
  QuestionnaireResponse,
  RelatedPerson,
  ServiceRequest,
  Task,
} from "./types.js";

// ── Loaded case aggregate (the mapper input) ───────────────────────────────

export interface CaseAggregate {
  tenant: {
    id: string;
    displayName: string;
    location: string | null;
    jurisdiction: string;
  };
  case: {
    id: string;
    tenantId: string;
    status: string;
    parentEmail: string | null;
    parentPhone: string | null;
    childDisplayName: string | null;
    childGivenName: string | null;
    childFamilyName: string | null;
    childDob: string | null;
    parentGivenName: string | null;
    parentFamilyName: string | null;
    parentRelationship: string | null;
    referralSource: string | null;
    consultAt: Date | null;
    createdAt: Date;
    updatedAt: Date;
  };
  intake:
    | {
        id: string;
        answers: Record<string, unknown>;
        consentVersion: string | null;
        locked: boolean;
        submittedAt: Date | null;
      }
    | null;
  triage: {
    id: string;
    outcome: string;
    reason: string | null;
    recordedAt: Date;
  }[];
  drafts: {
    id: string;
    kind: string;
    content: Record<string, unknown>;
    reviewedAt: Date | null;
    createdAt: Date;
  }[];
  carryover: {
    id: string;
    title: string;
    description: string | null;
    url: string | null;
    category: string;
    createdAt: Date;
  }[];
  progress: {
    id: string;
    author: string;
    note: string;
    rating: string | null;
    createdAt: Date;
  }[];
}

// ── Reference helpers ──────────────────────────────────────────────────────

const urn = (id: string) => `urn:uuid:${id}`;
const ref = (resourceType: string, id: string) => ({
  reference: urn(id),
  type: resourceType,
});
const iso = (d: Date | null | undefined) => (d ? d.toISOString() : undefined);

/** Stable deterministic child ids so the Bundle is reproducible per case. */
const childId = (caseId: string, suffix: string) => `${caseId}-${suffix}`;

function buildHumanName(
  given: string | null | undefined,
  family: string | null | undefined,
  fallbackText: string | null | undefined,
): HumanName[] | undefined {
  const givenParts = given ? given.split(/\s+/).filter(Boolean) : [];
  if (givenParts.length === 0 && !family) {
    // No structured name. Use the display string as `name.text` only (never
    // guess a given/family split) so the resource still carries a name when the
    // P0 structured columns are not yet populated.
    if (fallbackText) return [{ text: fallbackText }];
    return undefined;
  }
  const name: HumanName = { use: "official" };
  if (givenParts.length > 0) name.given = givenParts;
  if (family) name.family = family;
  return [name];
}

// ── Resource mappers ───────────────────────────────────────────────────────

export function toOrganization(agg: CaseAggregate): Organization {
  return {
    resourceType: "Organization",
    id: agg.tenant.id,
    meta: { profile: [UK_CORE.Organization] },
    name: agg.tenant.displayName,
    ...(agg.tenant.location
      ? { address: [{ text: agg.tenant.location }] }
      : {}),
  };
}

export function toPatient(agg: CaseAggregate): Patient {
  const c = agg.case;
  const patient: Patient = {
    resourceType: "Patient",
    id: c.id,
    meta: { profile: [UK_CORE.Patient], lastUpdated: iso(c.updatedAt) },
    managingOrganization: ref("Organization", agg.tenant.id),
  };
  const name = buildHumanName(c.childGivenName, c.childFamilyName, c.childDisplayName);
  if (name) patient.name = name;
  if (c.childDob) patient.birthDate = c.childDob;
  return patient;
}

export function toRelatedPerson(agg: CaseAggregate): RelatedPerson {
  const c = agg.case;
  const rp: RelatedPerson = {
    resourceType: "RelatedPerson",
    id: childId(c.id, "parent"),
    meta: { profile: [UK_CORE.RelatedPerson] },
    patient: ref("Patient", c.id),
  };
  const rel = c.parentRelationship ? RELATIONSHIP_CODE[c.parentRelationship] : undefined;
  if (rel) {
    rp.relationship = [
      { coding: [{ system: SYSTEM.roleCode, code: rel.code, display: rel.display }] },
    ];
  }
  const name = buildHumanName(c.parentGivenName, c.parentFamilyName, null);
  if (name) rp.name = name;
  const telecom: RelatedPerson["telecom"] = [];
  if (c.parentEmail) telecom.push({ system: "email", value: c.parentEmail });
  if (c.parentPhone) telecom.push({ system: "phone", value: c.parentPhone });
  if (telecom.length > 0) rp.telecom = telecom;
  return rp;
}

/** Map the case lifecycle enum to an EpisodeOfCare.status (base R4 value set). */
function episodeStatus(caseStatus: string): string {
  switch (caseStatus) {
    case "intake_pending":
    case "intake_submitted":
      return "onhold";
    case "carryover":
      return "active";
    default:
      return "active";
  }
}

export function toEpisodeOfCare(agg: CaseAggregate): EpisodeOfCare {
  const c = agg.case;
  return {
    resourceType: "EpisodeOfCare",
    id: childId(c.id, "episode"),
    status: episodeStatus(c.status),
    patient: ref("Patient", c.id),
    managingOrganization: ref("Organization", agg.tenant.id),
    period: { start: iso(c.createdAt) },
  };
}

export function toServiceRequest(agg: CaseAggregate): ServiceRequest {
  const c = agg.case;
  const sr: ServiceRequest = {
    resourceType: "ServiceRequest",
    id: childId(c.id, "referral"),
    meta: { profile: [UK_CORE.ServiceRequest] },
    status: c.status === "intake_pending" ? "draft" : "active",
    intent: "order",
    subject: ref("Patient", c.id),
    authoredOn: iso(c.createdAt),
  };
  if (c.referralSource) {
    // Free-text referral source — no confident SNOMED concept, so carry as text
    // (ADR-006 §3: code only if mappable; never fabricate a code).
    sr.reasonCode = [{ text: `Referral source: ${c.referralSource}` }];
  }
  return sr;
}

/**
 * The consult event: an Appointment while in the future, an Encounter once it
 * has happened (ADR-006 §3). Returns `null` when no consult was booked.
 */
export function toConsultEvent(
  agg: CaseAggregate,
  now: Date = new Date(),
): Appointment | Encounter | null {
  const c = agg.case;
  if (!c.consultAt) return null;
  if (c.consultAt.getTime() > now.getTime()) {
    const appt: Appointment = {
      resourceType: "Appointment",
      id: childId(c.id, "consult"),
      meta: { profile: [UK_CORE.Appointment] },
      status: "booked",
      start: iso(c.consultAt),
      participant: [{ actor: ref("Patient", c.id), status: "accepted" }],
    };
    return appt;
  }
  const enc: Encounter = {
    resourceType: "Encounter",
    id: childId(c.id, "consult"),
    meta: { profile: [UK_CORE.Encounter] },
    status: "finished",
    class: { system: SYSTEM.encounterClass, code: "AMB", display: "ambulatory" },
    subject: ref("Patient", c.id),
    period: { start: iso(c.consultAt) },
  };
  return enc;
}

export function toQuestionnaireResponse(
  agg: CaseAggregate,
): QuestionnaireResponse | null {
  if (!agg.intake) return null;
  const c = agg.case;
  const intake = agg.intake;
  const items = Object.entries(intake.answers)
    // Skip nulls/empties so we don't emit empty answers; arrays/objects are
    // serialised to a string value (the canonical Questionnaire linkId contract
    // is ADR-006 §5 P1 future work — until then linkId == answer key).
    .filter(([, v]) => v !== null && v !== undefined && v !== "")
    .map(([key, value]) => ({
      linkId: key,
      answer: [
        typeof value === "boolean"
          ? { valueBoolean: value }
          : {
              valueString:
                typeof value === "string" ? value : JSON.stringify(value),
            },
      ],
    }));
  return {
    resourceType: "QuestionnaireResponse",
    id: childId(c.id, "intake"),
    meta: { profile: [UK_CORE.QuestionnaireResponse] },
    status: intake.locked || intake.submittedAt ? "completed" : "in-progress",
    subject: ref("Patient", c.id),
    source: ref("RelatedPerson", childId(c.id, "parent")),
    authored: iso(intake.submittedAt),
    item: items,
  };
}

export function toConsent(agg: CaseAggregate): Consent | null {
  if (!agg.intake?.consentVersion) return null;
  const c = agg.case;
  return {
    resourceType: "Consent",
    id: childId(c.id, "consent"),
    meta: { profile: [UK_CORE.Consent] },
    status: "active",
    scope: {
      coding: [
        { system: SYSTEM.consentScope, code: "patient-privacy", display: "Privacy Consent" },
      ],
    },
    category: [
      {
        coding: [{ system: SYSTEM.consentCategory, code: "IDSCL", display: "information disclosure" }],
      },
    ],
    patient: ref("Patient", c.id),
    dateTime: iso(agg.intake.submittedAt),
    policy: [{ uri: `urn:sona:consent:${agg.intake.consentVersion}` }],
  };
}

/** Triage → Task (ADR-006 §3 recommendation; base R4 Task). */
export function toTriageTasks(agg: CaseAggregate): Task[] {
  const c = agg.case;
  return agg.triage.map((t, i) => {
    const task: Task = {
      resourceType: "Task",
      id: childId(c.id, `triage-${i}`),
      status: "completed",
      intent: "order",
      code: {
        coding: [{ system: SONA_CODESYSTEM.triageOutcome, code: t.outcome }],
        text: t.outcome,
      },
      businessStatus: {
        coding: [{ system: SONA_CODESYSTEM.triageOutcome, code: t.outcome }],
      },
      for: ref("Patient", c.id),
      focus: ref("ServiceRequest", childId(c.id, "referral")),
      authoredOn: iso(t.recordedAt),
    };
    if (t.reason) task.note = [{ text: t.reason }];
    return task;
  });
}

const renderedAttachmentTitle = (kind: string) =>
  kind === "clinical_report" ? "Clinical report" : "Parent summary";

/**
 * AI drafts → resources by kind, gated on `reviewedAt` (ADR-006 §3 hard rule).
 * Returns every emittable resource for the reviewed drafts.
 */
export function toDraftResources(agg: CaseAggregate): FhirResource[] {
  const c = agg.case;
  const out: FhirResource[] = [];
  for (const d of agg.drafts) {
    // Only clinician-reviewed drafts are record material. `prep_brief` is
    // working notes — excluded by default even when reviewed.
    if (!d.reviewedAt) continue;
    if (d.kind === "prep_brief") continue;

    if (d.kind === "session_plan") {
      const plan: CarePlan = {
        resourceType: "CarePlan",
        id: childId(c.id, `careplan-${d.id}`),
        meta: { profile: [UK_CORE.CarePlan] },
        status: "active",
        intent: "plan",
        subject: ref("Patient", c.id),
        created: iso(d.createdAt),
      };
      out.push(plan);
      continue;
    }

    if (d.kind === "parent_summary") {
      const docId = childId(c.id, `doc-${d.id}`);
      const doc: DocumentReference = {
        resourceType: "DocumentReference",
        id: docId,
        meta: { profile: [UK_CORE.DocumentReference] },
        status: "current",
        type: { text: "Parent summary" },
        subject: ref("Patient", c.id),
        date: iso(d.reviewedAt),
        description: "Parent summary (portal artefact)",
        content: [
          {
            attachment: {
              contentType: "text/html",
              title: renderedAttachmentTitle(d.kind),
              creation: iso(d.createdAt),
            },
          },
        ],
      };
      const comm: Communication = {
        resourceType: "Communication",
        id: childId(c.id, `comm-${d.id}`),
        status: "completed",
        subject: ref("Patient", c.id),
        recipient: [ref("RelatedPerson", childId(c.id, "parent"))],
        sent: iso(d.reviewedAt),
        payload: [{ contentReference: ref("DocumentReference", docId) }],
      };
      out.push(doc, comm);
      continue;
    }

    if (d.kind === "clinical_report") {
      const docId = childId(c.id, `doc-${d.id}`);
      const doc: DocumentReference = {
        resourceType: "DocumentReference",
        id: docId,
        meta: { profile: [UK_CORE.DocumentReference] },
        status: "current",
        type: { text: "Clinical report" },
        subject: ref("Patient", c.id),
        date: iso(d.reviewedAt),
        description: "Clinical report (PDF)",
        content: [
          {
            attachment: {
              contentType: "application/pdf",
              title: renderedAttachmentTitle(d.kind),
              url: `Binary/clinical-report-${c.id}`,
              creation: iso(d.createdAt),
            },
          },
        ],
      };
      const comp: Composition = {
        resourceType: "Composition",
        id: childId(c.id, `comp-${d.id}`),
        meta: { profile: [UK_CORE.Composition] },
        status: "final",
        type: {
          coding: [{ system: SYSTEM.loinc, code: "11488-4", display: "Consult note" }],
          text: "Clinical report",
        },
        subject: ref("Patient", c.id),
        date: iso(d.reviewedAt) ?? iso(d.createdAt) ?? new Date().toISOString(),
        title: "Clinical report",
        author: [ref("Organization", agg.tenant.id)],
        attester: [{ mode: "professional", time: iso(d.reviewedAt) }],
        // R4 invariant cmp-1: a section must have at least one of text/entry/
        // section. The rendered body lives in the linked DocumentReference; here
        // we carry a minimal generated narrative so the Composition section is
        // self-valid (the PDF is the authoritative artefact).
        section: [
          {
            title: "Report",
            code: { text: "Clinical report" },
            text: {
              status: "generated",
              div: '<div xmlns="http://www.w3.org/1999/xhtml">Clinical report — see attached document.</div>',
            },
          },
        ],
      };
      out.push(doc, comp);
      continue;
    }
  }
  return out;
}

/** Carryover home-practice resources → CarePlan with activities. */
export function toCarryoverCarePlan(agg: CaseAggregate): CarePlan | null {
  if (agg.carryover.length === 0) return null;
  const c = agg.case;
  return {
    resourceType: "CarePlan",
    id: childId(c.id, "carryover-plan"),
    meta: { profile: [UK_CORE.CarePlan] },
    status: "active",
    intent: "plan",
    subject: ref("Patient", c.id),
    created: iso(c.updatedAt),
    activity: agg.carryover.map((r) => ({
      detail: {
        status: "scheduled",
        code: {
          coding: [
            {
              system: SONA_CODESYSTEM.carryoverCategory,
              code: r.category,
              display: CARRYOVER_CATEGORY_DISPLAY[r.category] ?? r.category,
            },
          ],
          text: r.title,
        },
        description: [r.description, r.url].filter(Boolean).join(" — ") || undefined,
      },
    })),
  };
}

/** Progress entries → Observation (ADR-006 §3 recommendation; base R4). */
export function toProgressObservations(agg: CaseAggregate): Observation[] {
  const c = agg.case;
  return agg.progress.map((p, i) => {
    const performerId =
      p.author === "parent" ? childId(c.id, "parent") : agg.tenant.id;
    const performerType = p.author === "parent" ? "RelatedPerson" : "Organization";
    const obs: Observation = {
      resourceType: "Observation",
      id: childId(c.id, `progress-${i}`),
      status: "final",
      code: {
        coding: [{ system: SONA_CODESYSTEM.progressRating, code: "home-practice-progress" }],
        text: "Home-practice progress",
      },
      subject: ref("Patient", c.id),
      effectiveDateTime: iso(p.createdAt),
      performer: [ref(performerType, performerId)],
      note: [{ text: p.note }],
    };
    if (p.rating) {
      obs.valueCodeableConcept = {
        coding: [
          {
            system: SONA_CODESYSTEM.progressRating,
            code: p.rating,
            display: PROGRESS_RATING_DISPLAY[p.rating] ?? p.rating,
          },
        ],
      };
    }
    return obs;
  });
}

// ── Bundle assembly ────────────────────────────────────────────────────────

export class JurisdictionError extends Error {
  constructor(public readonly jurisdiction: string) {
    super(`fhir_export_unsupported_jurisdiction`);
    this.name = "JurisdictionError";
  }
}

/**
 * Assemble a UK Core `collection` Bundle for one case (ADR-006 §2 `toBundle`).
 * Pure: a function of the loaded aggregate. Asserts UK jurisdiction (ADR-006 §4
 * — UK Core profiles are a UK concept; no cross-jurisdiction export).
 */
export function toBundle(agg: CaseAggregate, now: Date = new Date()): Bundle {
  if (agg.tenant.jurisdiction !== "uk") {
    throw new JurisdictionError(agg.tenant.jurisdiction);
  }

  const resources: FhirResource[] = [
    toOrganization(agg),
    toPatient(agg),
    toRelatedPerson(agg),
    toEpisodeOfCare(agg),
    toServiceRequest(agg),
  ];

  const consult = toConsultEvent(agg, now);
  if (consult) resources.push(consult);

  const qr = toQuestionnaireResponse(agg);
  if (qr) resources.push(qr);

  const consent = toConsent(agg);
  if (consent) resources.push(consent);

  resources.push(...toTriageTasks(agg));
  resources.push(...toDraftResources(agg));

  const carryoverPlan = toCarryoverCarePlan(agg);
  if (carryoverPlan) resources.push(carryoverPlan);

  resources.push(...toProgressObservations(agg));

  const entry: BundleEntry[] = resources.map((resource) => ({
    fullUrl: urn(resource.id),
    resource,
  }));

  return {
    resourceType: "Bundle",
    type: "collection",
    timestamp: now.toISOString(),
    entry,
  };
}
