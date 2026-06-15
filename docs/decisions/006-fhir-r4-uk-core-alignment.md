# ADR 006 — FHIR R4 / UK Core alignment (data model → FHIR resources)

**Status:** Proposed
**Date:** 2026-06-13
**Depends on:** ADR-001 (jurisdiction stacks — UK data residency)
**Informs:** DEV-27 (FHIR export layer implementation)

## Context

Sona is a UK private speech & language therapy (SLT) app. **FHIR/HL7 compliance is a
v1 non-functional requirement**, but **full bidirectional FHIR APIs are explicitly out of
scope for v1.** The v1 goal is narrower and deliberate:

1. **FHIR-aligned data semantics** — our relational tables carry the fields a FHIR
   serializer needs, with the right shape (structured names, DOB, relationship type),
   so we do not have to remodel later.
2. **A standards-compliant export** — the ability to emit a UK Core-conformant FHIR
   `Bundle` for a case, for clinician/parent data portability (UK GDPR Art. 20) and
   to seed a Year-2 integration without a migration.

**Why now:** the carryover tables (`carryoverResources`, `progressEntries`,
`casePortalLinks`) have just landed, so the data model is feature-complete enough for
v1 that we can map it end-to-end. Doing the mapping now is cheap; doing it after the
schema ossifies is not. Year-2 work (PMS handover, NHS e-Referral / GP Connect-style
integration) needs FHIR-shaped data; if v1 stores e.g. a single `childDisplayName`
string with no DOB, the Year-2 export *invents* clinical data — unacceptable.

**Scope boundary (hard):**
- ✅ In scope: a design for an **export/serialization layer**, and the **schema deltas**
  v1 needs so that layer never fabricates data.
- ❌ Out of scope: a FHIR server, `$validate`/search endpoints, `_history`, ingest of
  external FHIR, real-time sync, or storing resources FHIR-native. Those are Year 2.
- This ADR is **design only**. Implementation is **DEV-27**; schema changes are
  sub-tasks consumed from §5.

### Standards baseline (what we are conforming to, with versions)

- **Base spec:** HL7 FHIR **R4 (4.0.1)** — UK Core is built on R4. ([HL7 FHIR R4 4.0.1](https://hl7.org/fhir/R4/))
- **National profiles:** **NHS England FHIR UK Core**. The latest *published / balloted*
  release at time of writing is the **STU2 sequence, version `2.0.2`** (released
  2025-02-24 per the NHS Digital staging repo). The canonical, resolvable FHIR
  package id is **`fhir.r4.ukcore.stu2#2.0.2`** (Simplifier / packages.fhir.org);
  this is the id the official HL7 validator loads in CI (DEV-27) and that
  resolves the `UKCore-*` profile canonicals. The **STU3 sequence**
  is in active development (pre-release builds only) and is **not** yet a stable
  publication. ([FHIR UK Core — NHS England](https://digital.nhs.uk/services/fhir-uk-core),
  [NHS Digital UK Core releases (GitHub)](https://github.com/NHSDigital/FHIR-R4-UKCORE-STAGING-MAIN/releases),
  [HL7 FHIR UK Core R4 — Simplifier](https://simplifier.net/hl7fhirukcorer4))
- **Decision on version pinning:** the export layer **targets UK Core STU2 (`2.0.2`)**
  as the conformance baseline and pins the exact package version in code (DEV-27). We do
  **not** chase STU3 pre-releases. Profile URLs are canonical (`https://fhir.hl7.org.uk/StructureDefinition/UKCore-*`);
  the pinned package resolves them. When STU3 publishes, bumping the package is a
  contained change because we only *emit* (never validate-ingest) resources.
- **Terminology:** **SNOMED CT (UK Edition)** for clinical concepts; **ISO/UK** value
  sets for administrative codes (gender, relationship). NHS-specific identifier systems
  where applicable. ([NHS number identifier system `https://fhir.nhs.uk/Id/nhs-number`](https://digital.nhs.uk/services/fhir-uk-core))

## Decision

### 1. Keep the internal relational model; add FHIR as an export/serialization layer

We **reject** FHIR-native storage (storing resources as JSON documents / running a FHIR
server as the source of truth) for v1, and **adopt** a thin **export layer** that maps
our existing Drizzle/Postgres tables to UK Core resources on demand.

| Option | Verdict | Rationale |
|--------|---------|-----------|
| **A. Relational source of truth + FHIR export layer** | **Chosen** | Keeps the fast, type-safe, tenant-scoped relational model the whole app already depends on. FHIR is a *projection*, generated when needed (export, future API). Cheapest path to "aligned semantics + compliant export". |
| B. FHIR-native (resources stored as JSON, FHIR server is the DB) | Rejected | Massive rewrite; loses relational integrity/RLS/tenancy guarantees; over-engineered for a v1 with no FHIR *consumers* yet; couples our data model to spec churn (STU2→STU3). |
| C. Dual-write (relational + FHIR docs kept in sync) | Rejected | Two sources of truth = drift + double the write path + reconciliation burden, for zero v1 benefit. |

**Trade-offs accepted:** the export layer must re-derive resources each time (no stored
FHIR) and must own the mapping logic — but mapping logic is exactly the thing that should
live in code review, not in stored data. Because we only **emit**, we are not bound to
pass `$validate` on ingest; we target conformance but the blast radius of a profile
change is one serializer module.

### 2. Mechanism

A `fhir/` module in `apps/api` exposes (DEV-27):
- `toBundle(caseId): Bundle` — a `collection` (or `document` for report exports) Bundle
  for one case, tenant-scoped, jurisdiction-checked (UK only — see §4).
- Per-resource mappers (`toPatient`, `toRelatedPerson`, …) that are pure functions of a
  loaded case aggregate. No new persistence.
- Emitted as JSON; PDF artefacts referenced (not inlined) where they already exist.

## 3. Field-level resource mapping

Every PHI-bearing table/field below is mapped or **explicitly marked not-exported**.
"Resource" names are UK Core profiles (FHIR R4). `cases.id` (and child rows' `id`) become
resource `id`s / `fullUrl` references inside the Bundle.

### `tenants` → `Organization` (+ context for jurisdiction)

| Field | FHIR target | Notes |
|-------|-------------|-------|
| `id` | `Organization.id` | The practice. |
| `displayName` | `Organization.name` | |
| `location` | `Organization.address` (text) | Free-text UK location. |
| `specialties` | `Organization.type` / `HealthcareService.specialty` | SNOMED/role codes if mapped; else omit (do not fabricate codes). |
| `jurisdiction`, `mode`, `seats` | **Not exported** | Internal billing/ops; not clinical. |

### `users` → `Practitioner` (+ `PractitionerRole`)

| Field | FHIR target | Notes |
|-------|-------------|-------|
| `id` | `Practitioner.id` | |
| `fullName` | `Practitioner.name` | **Schema delta:** currently a single string; FHIR `HumanName` wants given/family (see §5). |
| `email`, `role` | `PractitionerRole` (`telecom`, role code) | |
| *(new)* HCPC reg no. | `Practitioner.identifier` | **Schema delta §5** — SLTs are HCPC-registered; identifier system `https://fhir.hl7.org.uk/Id/hcpc-number` (confirm system URL with §"Open questions"). |
| `firebaseUid`, `status`, `invitedAt`, `tenantId` | **Not exported** | Auth/provisioning internals, not clinical identity. |

### `cases` → `Patient` (child) + `RelatedPerson` (parent/carer) + `EpisodeOfCare` + `ServiceRequest` + `Appointment`/`Encounter`

A `case` is a composite. It does **not** map 1:1 to one resource.

| Field | FHIR target | Profile | Notes |
|-------|-------------|---------|-------|
| `id` | `Patient.id`; anchors `EpisodeOfCare`, `ServiceRequest` | UKCore-Patient | The **child** is the Patient (the person receiving care). |
| `childDisplayName` | `Patient.name` (`HumanName`) | UKCore-Patient | **Schema delta §5:** split to given/family. A single display string is not safely splittable; mapper would guess — forbidden. |
| *(new)* child DOB | `Patient.birthDate` | UKCore-Patient | **Schema delta §5** — mandatory-quality demographic; required for any real handover. Not currently stored. |
| *(new)* child sex/gender | `Patient.gender` + sex extension | UKCore-Patient | **Schema delta §5** (optional but recommended). |
| *(new, optional)* NHS number | `Patient.identifier` (system `https://fhir.nhs.uk/Id/nhs-number`) | UKCore-Patient | Optional in private practice — see §4. |
| `parentEmail`, `parentPhone` | `RelatedPerson.telecom` | UKCore-RelatedPerson | The **parent/carer**, linked via `RelatedPerson.patient → Patient(child)`. |
| *(new)* parent name | `RelatedPerson.name` | UKCore-RelatedPerson | **Schema delta §5.** |
| *(new)* relationship type | `RelatedPerson.relationship` | UKCore-RelatedPerson | **Schema delta §5** — code (e.g. `PRN` parent) from the UK Core RelatedPerson relationship value set. Today we cannot say *who* the contact is to the child. |
| `referralSource` | `ServiceRequest.requester` / `.reasonReference` text | UKCore-ServiceRequest | The **referral** → `ServiceRequest` (intent `order`, status from case lifecycle). Free-text source; code only if mappable. |
| `consultAt` | `Appointment.start` (future) → `Encounter.period` (after it happens) | UKCore-Appointment / UKCore-Encounter | Pre-consult = `Appointment`; once consulted, the same event is the `Encounter` the clinical artefacts attach to. |
| `status` (`case_status` enum) | `EpisodeOfCare.status` + drives `ServiceRequest`/`Task` status | UKCore (EpisodeOfCare base R4) | The episode of care spans the whole case; the enum is the lifecycle. **No UKCore-EpisodeOfCare profile exists in STU2 — use base FHIR R4 `EpisodeOfCare`** (documented gap, see §4/Open questions). |
| `tenantId` | `Patient.managingOrganization → Organization` | | |
| `createdAt`, `updatedAt` | resource `meta.lastUpdated` (informational) | | Not authoritative clinical timestamps. |

### `clinicianAvailability` → **Not exported**

Scheduling configuration, not patient data. (`Slot`/`Schedule` resources exist but are
operational and out of v1 export scope.) Marked deliberately excluded.

### `caseIntakeLinks` → **Not exported**

`token` is a **secret single-use credential**; `expiresAt`/`usedAt`/`templateId` are
access-control internals. **Exporting tokens would be a security defect.** Excluded with
prejudice. `templateId` is represented indirectly via the `Questionnaire` (below).

### `intakeSubmissions` → `QuestionnaireResponse` (+ `Questionnaire`) + `Consent`

| Field | FHIR target | Profile | Notes |
|-------|-------------|---------|-------|
| `answers` (JSONB) | `QuestionnaireResponse.item[]` | UKCore-QuestionnaireResponse | Each branching answer → a `QR.item` with `linkId` matching the template. |
| (the template) | `Questionnaire` | UKCore-Questionnaire | The intake form definition → a `Questionnaire` resource (`linkId`s are the contract between `Questionnaire` and `QuestionnaireResponse`). **Schema/asset delta §5:** intake templates are currently app-internal; to export valid `linkId`s we need a stable, versioned template definition. |
| `consentVersion` | `Consent.policy` / `.sourceReference` + `Provision` | UKCore-Consent | Consent to assessment/processing. Maps the *fact and version* of consent. |
| `submittedAt` | `QuestionnaireResponse.authored` | | |
| `locked` | `QuestionnaireResponse.status` (`completed` vs `in-progress`) | | |
| `caseId` | `QR.subject → Patient`, `QR.source → RelatedPerson` (parent answered) | | |

### `triageRecords` → `Task` (recommended) — *not* `ClinicalImpression`

| Field | FHIR target | Notes |
|-------|-------------|-------|
| `outcome` | `Task.businessStatus` / `Task.code` | See recommendation below. |
| `reason` | `Task.note` (or `ClinicalImpression.summary` if B) | |
| `recordedAt` | `Task.authoredOn` | |

**Recommendation: model triage as `Task` (option A), not `ClinicalImpression` (option B).**

- **Triage is a workflow decision** ("route this referral to X / accept / decline /
  needs-info"), not a documented clinical assessment of the patient's condition.
  `Task` (status, `businessStatus`, `output`, fulfilling the `ServiceRequest`) is the
  natural fit and links cleanly to the referral.
- `ClinicalImpression` is for a clinician's **assessment of the patient's state** at a
  point in time — that is closer to what the *consult* produces (the clinical narrative),
  not what the *triage outcome* records.
- **Justification of the trade-off:** if a Year-2 consumer expects triage as an
  assessment, re-projecting `Task → ClinicalImpression` is a serializer change, not a
  data change — because the source fields (`outcome`, `reason`, `recordedAt`) are
  sufficient for either. We pick the semantically honest one now.
- Note: **no UKCore-Task profile in STU2** — use base R4 `Task`. (Open question §"Confirm".)

### `aiDrafts` → mapped *by `kind`* (and only after clinician review)

**Hard rule:** AI drafts are clinician-reviewed artefacts (per existing schema comment
"never auto-sent"). The export layer **only emits a draft whose `reviewedAt` is set** —
an unreviewed AI draft is **not** clinical record material and must be excluded. The
mapper enforces this.

| `kind` | FHIR target | Profile | Notes / recommendation |
|--------|-------------|---------|------------------------|
| `prep_brief` | **Internal — not exported by default**; if exported, `Composition` (section) | (UKCore-Composition if used) | Pre-consult clinician aide-mémoire. It is *workspace*, not record. Recommend **excluded** from the standard export; include only behind an explicit "include working notes" flag. |
| `session_plan` | `CarePlan` | UKCore-CarePlan | The intervention plan → `CarePlan` (`activity[]`, `addresses → Condition` if present). |
| `parent_summary` | `Communication` (the act of summarising to parent) **+** `DocumentReference` (the rendered artefact) | UKCore (Communication base R4) / UKCore-DocumentReference | Aligns with ADR-005 (portal-first parent summary). `Communication.recipient → RelatedPerson`. The HTML/PDF body is a `DocumentReference`. |
| `clinical_report` | `DocumentReference` (the PDF) **+** `Composition` (its structured header/sections) | UKCore-DocumentReference + UKCore-Composition | The formal clinical report. `Composition.section` for structure; `DocumentReference.content.attachment` for the PDF (referenced, not inlined for large files). |

| Field | FHIR target | Notes |
|-------|-------------|-------|
| `content` (JSONB) | resource body per `kind` above | |
| `modelId` | `*.extension` (provenance) or `Provenance.agent` (future) | **Recommend not** putting raw model id into the clinical record by default; capture via `Provenance` if needed (Year 2). |
| `reviewedAt` | gating condition (see rule) + `Composition.attester` time | The reviewing clinician is the attester. |
| `createdAt`, `caseId` | `*.date`, `subject → Patient` | |

### `carryoverResources` → `CarePlan` activity / `DocumentReference`

| Field | FHIR target | Notes |
|-------|-------------|-------|
| `title`, `description` | `CarePlan.activity.detail` (`code`/`description`) **or** `DocumentReference.description` | Home-practice items belong to the `CarePlan` (preferred — they *are* the plan's activities). A linked resource (`url`) → `DocumentReference.content.attachment.url`. |
| `url` | `DocumentReference.content.attachment.url` | External resource link. |
| `category` (`carryover_resource_category` enum) | `CarePlan.activity.detail.category` / `DocumentReference.category` | Map enum → coding; SNOMED where a sensible concept exists, else local code system. |
| `sourceDraftId` | provenance link to the `CarePlan` from `session_plan` | Internal lineage; informational. |

### `progressEntries` → `Observation` (recommended) — over `Communication`

| Field | FHIR target | Notes |
|-------|-------------|-------|
| `note` | `Observation.note` (or `.valueString`) | |
| `rating` (`progress_rating` enum) | `Observation.valueCodeableConcept` | `tried_it`/`going_well`/`finding_it_hard` → a coded scale (local CodeSystem; SNOMED if a suitable concept exists). |
| `author` (`parent`/`clinician`) | `Observation.performer → RelatedPerson | Practitioner` | |
| `createdAt`, `caseId` | `Observation.effectiveDateTime`, `subject → Patient` | |

**Recommendation: `Observation` over `Communication`.** Progress entries are *graded
home-practice outcomes over time* (a `rating` + note) — that is observational data a
clinician tracks longitudinally, which is exactly `Observation`'s purpose.
`Communication` would model them as messages and lose the rating's analyzable semantics.
Trade-off: parent-authored `Observation`s are slightly unusual (performer is a
`RelatedPerson`), but valid in R4 and more useful downstream than chat-style messages.
(No UKCore-Observation *general* profile beyond domain-specific ones like
UKCore-Observation-Lab in STU2 — use base R4 `Observation`; see Open questions.)

### `casePortalLinks` → **Not exported**

Same reasoning as `caseIntakeLinks`: `token` is a durable secret credential;
`expiresAt`/`revokedAt` are access-control state. This table is the **access mechanism**,
not patient data. **Explicitly excluded.** (Stated here because the issue asks us to say
so plainly.)

### `auditLog` → `AuditEvent` (optional / future)

| Field | FHIR target | Notes |
|-------|-------------|-------|
| `actor`, `action`, `metadata`, `caseId`, `createdAt` | `AuditEvent.agent`/`.action`/`.entity`/`.recorded` | Maps cleanly, but **marked optional/Year-2**: audit export is not part of the v1 data-portability goal and pulls in its own access-control questions. Documented as a known, deferred mapping. |

### Deliberately NOT exported — summary (with rationale)

| Item | Why excluded |
|------|--------------|
| `caseIntakeLinks.token`, `casePortalLinks.token` | Secret credentials — exporting is a security defect. |
| `*.expiresAt`/`usedAt`/`revokedAt`/`firebaseUid`/`status` | Access-control & provisioning internals; not clinical/portable data. |
| Internal surrogate `uuid` PKs (as identifiers) | Used as in-Bundle `fullUrl` references only, **not** emitted as external business `identifier`s (they are meaningless outside Sona and could leak internal structure). |
| `tenants.mode/seats/jurisdiction`, billing fields | Commercial/ops data. |
| `clinicianAvailability` | Scheduling config, not patient data. |
| Unreviewed `aiDrafts` (`reviewedAt IS NULL`) | Not record material until a clinician attests. |
| `aiDrafts.modelId` (by default) | Provenance handled separately (Year 2) to avoid polluting the clinical record. |

## 4. UK Core profiles, terminology, identifiers, jurisdiction

### Profile choice per resource (UK Core STU2 `2.0.2` unless noted)

| Resource | Profile | Status |
|----------|---------|--------|
| Practice | `UKCore-Organization` | Verified exists. |
| Clinician | `UKCore-Practitioner` (+ `UKCore-PractitionerRole`) | Verified exists. ([Simplifier — UKCore-Practitioner](https://simplifier.net/HL7FHIRUKCoreR4/UKCore-Practitioner)) |
| Child | `UKCore-Patient` | Verified. ([Simplifier — UKCore-Patient](https://simplifier.net/hl7fhirukcorer4/ukcore-patient)) |
| Parent/carer | `UKCore-RelatedPerson` | Verified. ([Simplifier — UKCore-RelatedPerson](https://simplifier.net/hl7fhirukcorer4/ukcore-relatedperson)) |
| Appointment | `UKCore-Appointment` | Verified. ([Simplifier — UKCore-Appointment](https://simplifier.net/HL7FHIRUKCoreR4/UKCore-Appointment)) |
| Encounter | `UKCore-Encounter` | Verified. ([Simplifier — UKCore-Encounter](https://simplifier.net/hl7fhirukcorer4/ukcore-encounter)) |
| Referral | `UKCore-ServiceRequest` | Verified (a `-Lab` variant exists; general SR profile present). ([Simplifier — UKCore-ServiceRequest-Lab](https://simplifier.net/hl7fhirukcorer4/ukcore-servicerequest-lab)) |
| Intake | `UKCore-QuestionnaireResponse` + `UKCore-Questionnaire` | Verified family exists. |
| Consent | `UKCore-Consent` | Verified (was in-development assets; present in STU2). |
| Care plan | `UKCore-CarePlan` | Verified (last updated 2024-07-17). ([Simplifier — UKCore-CarePlan](https://simplifier.net/hl7fhirukcorer4/ukcore-careplan)) |
| Parent summary / report | `UKCore-Communication`*, `UKCore-DocumentReference`, `UKCore-Composition` | DocumentReference/Composition verified in family; Communication may fall back to base R4 — **confirm in pinned package**. |
| Triage | base R4 `Task` | **No UKCore-Task profile confirmed in STU2** — use base R4, conform loosely. |
| Episode | base R4 `EpisodeOfCare` | **No UKCore-EpisodeOfCare profile confirmed in STU2** — use base R4. |
| Progress | base R4 `Observation` | Only domain-specific UKCore Observation profiles (e.g. `-Lab`) confirmed; use base R4 for general progress. |
| Audit (future) | base R4 `AuditEvent` | Year 2. |

> Where no UK Core profile exists, the export uses **base FHIR R4** for that resource and
> still conforms to UK Core for everything that *does* have a profile. This is honest and
> standard practice; it is flagged in Open questions for human confirmation against the
> pinned package contents (a profile may exist that the public Simplifier search did not
> surface).

### Terminology

- **SNOMED CT (UK Edition)** for clinical concepts (SLT concern categories, progress
  ratings, carryover categories) **where a suitable concept exists**. Where it does not,
  use a **local Sona CodeSystem** with a stable URI rather than mis-coding to an
  approximate SNOMED concept. We do not invent SNOMED codes.
- **SLT concern categories:** map intake concern types to SNOMED where available (e.g.
  speech/language/communication disorder concepts). The exact concept set is a DEV-27
  terminology sub-task; this ADR mandates *that* it be coded, not the specific codes.
- **Administrative codes:** UK Core value sets for gender, `RelatedPerson.relationship`,
  contact method.
- **Funding / ICB coding:** Sona is **private practice** — funding is self-pay, not
  NHS/ICB-commissioned. ICB/commissioner coding is **not applicable in v1** and is left
  unmodelled; if a case is later NHS-funded, `EpisodeOfCare.account`/`Coverage` would
  carry it (Year 2). Documented so no one fabricates ICB codes.

### Identifiers

- **NHS number is OPTIONAL** in private practice and frequently absent at intake. Modelled
  as an **optional** `Patient.identifier` with system
  `https://fhir.nhs.uk/Id/nhs-number`. When absent, the Patient still validates via other
  identifiers/demographics. **If present, it MUST carry the NHS Number Verification Status
  extension** unless traced (per UK Core guidance). We do **not** require it for export.
  ([NHS number identifier system — NHS England](https://digital.nhs.uk/services/fhir-uk-core))
- **Internal UUIDs** are used as Bundle `fullUrl` references only — never emitted as
  external business identifiers.
- **HCPC registration** for clinicians → `Practitioner.identifier` (system to confirm —
  see Open questions; candidate `https://fhir.hl7.org.uk/Id/hcpc-number`).

### Jurisdiction / data residency

- Per **ADR-001**, UK clinical data lives in the UK data plane. The **FHIR export runs
  inside the UK stack only** and a Bundle for a UK tenant is generated, stored (if at
  all), and delivered within `europe-west2`. The mapper **must assert tenant
  `jurisdiction = 'uk'`** before emitting UK Core resources (UK Core profiles are a UK
  concept; a US tenant would use US Core — out of scope). No cross-jurisdiction export.

## 5. Schema deltas needed now (checklist for DEV-27 + schema sub-tasks)

So the export layer **never fabricates data**, the following are required. Each is a
discrete, mergeable schema change. Grouped by priority.

**P0 — without these the export invents clinical data (blockers for a *real* export):**

- [ ] **Child structured name** — replace/supplement `cases.childDisplayName` with
      `childGivenName` + `childFamilyName` (keep display as derived/optional). A single
      string cannot be safely split into `HumanName`.
- [ ] **Child date of birth** — add `cases.childDob` (date). Required for any credible
      `Patient`/handover; currently absent.
- [ ] **Parent/carer name** — add structured `parentGivenName`/`parentFamilyName` (today
      we only have email/phone, so `RelatedPerson` has no name).
- [ ] **Parent relationship type** — add `cases.parentRelationship` (coded: parent,
      guardian, carer, …) → `RelatedPerson.relationship`. Today we cannot state who the
      contact is to the child.

**P1 — needed for fidelity / correct coding:**

- [ ] **Child sex/gender** — add `cases.childGender` (+ optional birth-sex) for
      `Patient.gender`.
- [ ] **Optional NHS number** — add nullable `cases.childNhsNumber` (+ verification
      status when used).
- [ ] **Clinician HCPC identifier** — add `users.hcpcNumber` (nullable) →
      `Practitioner.identifier`.
- [ ] **Clinician structured name** — split `users.fullName` into given/family (or store
      both) for `Practitioner.name`.
- [ ] **Versioned intake `Questionnaire` definition** — make intake templates a stable,
      versioned asset with explicit `linkId`s (today `templateId` is a string and answers
      are free JSONB). Without canonical `linkId`s, `QuestionnaireResponse.item` cannot be
      reliably produced. (May be an *asset*/config delta, not a table change.)
- [ ] **Coded SLT concern category** on intake — ensure the concern type is captured as a
      discrete, codable field (not only buried in free-text `answers`) so it can be
      SNOMED-coded on `Condition`/`ServiceRequest.reasonCode`.

**P2 — provenance / nice-to-have:**

- [ ] **Consent richer than a version string** — consider capturing consent scope/grantor
      so `Consent.provision` is meaningful (today only `consentVersion`).
- [ ] **AI provenance** — if model attribution is wanted in exports, design a
      `Provenance`-friendly capture (don't overload `modelId` into clinical fields).
- [ ] **Carryover/progress local CodeSystem** — define stable URIs for the enum→code maps
      (`carryover_resource_category`, `progress_rating`).

> These are inputs to **DEV-27** and any schema sub-tasks. This ADR does **not** change
> the schema — it specifies what those changes must achieve.

## Consequences

**Positive**
- v1 ships with FHIR-*aligned* semantics and a clear export design; Year-2 integration
  is an additive serializer, not a remodel.
- The mapping is reviewable in code, version-pinned to UK Core STU2 `2.0.2`, and
  emit-only (low blast radius for spec changes).
- Security posture preserved: tokens/secrets/internal IDs are explicitly never exported.

**Costs / risks**
- The schema deltas in §5 (esp. P0 DOB + structured names + relationship) are real work
  and touch the intake flow UI/forms — they must land *before* the export is meaningful.
- Where no UK Core profile exists (Task, EpisodeOfCare, general Observation), we conform
  to base R4 only; a strict UK Core consumer might want more — acceptable for export,
  revisit if Year-2 partners demand stricter conformance.
- SNOMED coding requires terminology effort; until done, some concepts use local
  CodeSystems (honest but less interoperable).
- Risk of spec drift STU2→STU3; mitigated by emit-only design + pinned package.

**Explicitly deferred to Year 2**
- A FHIR server, search, `$validate` on ingest, `_history`, real-time sync, ingest of
  external FHIR (e-RS/GP Connect-style), `AuditEvent` export, `Provenance`, `Coverage`/
  ICB funding, US Core (US jurisdiction), and any bidirectional PMS/NHS integration.

## Open questions (human to confirm against the pinned package)

1. **Confirm exact pinned package** — STU2 `UK.Core.r4.v2@2.0.2` vs adopting a later
   STU3 *pre-release*. Recommendation: pin `2.0.2` (stable) for v1.
2. **Profiles that public search did not confirm** — verify whether the pinned package
   actually ships `UKCore-Task`, `UKCore-EpisodeOfCare`, a general `UKCore-Observation`,
   and `UKCore-Communication`. If yes, use them instead of base R4.
3. **HCPC identifier system URI** — confirm the canonical system for HCPC registration
   numbers (candidate `https://fhir.hl7.org.uk/Id/hcpc-number`).
4. **Triage as `Task` vs `ClinicalImpression`** — sign-off on the §3 recommendation
   (`Task`) with the clinical lead.
5. **Progress entries as `Observation` vs `Communication`** — sign-off on `Observation`.
6. **Whether `prep_brief` is ever exported** — default is "no (working notes)"; confirm.

## References

- [HL7 FHIR R4 (4.0.1)](https://hl7.org/fhir/R4/)
- [FHIR UK Core — NHS England Digital](https://digital.nhs.uk/services/fhir-uk-core)
- [NHS Digital UK Core R4 releases (GitHub) — latest STU2 `2.0.2`, 2025-02-24](https://github.com/NHSDigital/FHIR-R4-UKCORE-STAGING-MAIN/releases)
- [HL7 FHIR UK Core R4 — Simplifier project](https://simplifier.net/hl7fhirukcorer4)
- [UKCore-Patient](https://simplifier.net/hl7fhirukcorer4/ukcore-patient) ·
  [UKCore-RelatedPerson](https://simplifier.net/hl7fhirukcorer4/ukcore-relatedperson) ·
  [UKCore-Appointment](https://simplifier.net/HL7FHIRUKCoreR4/UKCore-Appointment) ·
  [UKCore-Encounter](https://simplifier.net/hl7fhirukcorer4/ukcore-encounter) ·
  [UKCore-CarePlan](https://simplifier.net/hl7fhirukcorer4/ukcore-careplan) ·
  [UKCore-Practitioner](https://simplifier.net/HL7FHIRUKCoreR4/UKCore-Practitioner)
- [NHS number identifier system `https://fhir.nhs.uk/Id/nhs-number`](https://digital.nhs.uk/services/fhir-uk-core)
- [UK Core FHIR Release 4 — Governance, NHS Standards Directory](https://standards.nhs.uk/published-standards/uk-core-fhir-release-4-governance)
- Internal: ADR-001 (jurisdiction stacks), ADR-005 (portal-first parent summary),
  [`apps/api/src/db/schema.ts`](../../apps/api/src/db/schema.ts)
