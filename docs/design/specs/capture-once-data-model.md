# Capture-once data model & information architecture (v1)

*The concrete v1 information architecture built on the DEV-101 conceptual model. This is
the **backbone** every other assessment→report spec (DEV-102/104/105/106/107/108) binds
to. Linear **DEV-109**.*

**Date:** 2026-07-01 · **Status:** Draft → In Review · **Depends on:** DEV-101 (conceptual
model), DEV-100 (licensing guardrails), ADR-006 (FHIR R4 / UK Core), ADR-001 (residency) ·
**Data:** structure only — **no PII, no publisher content**

---

## 0. The one fundamental this exists to enforce

> **Capture once → no re-keying.** A value the clinician enters or confirms exactly once —
> at intake, or when reviewing an extracted assessment — becomes the single source of truth
> and flows into every report, summary and export **without being typed again**. PII lives
> in one partition; clinical data is name-free and identifier-linked; a name is re-attached
> **only at render** for authorised outputs, and can be withheld entirely for a de-identified
> export. The "find-and-replace the child's name across a Word doc" problem is designed out.

Three properties follow, and the rest of this document is how the model guarantees them:

1. **Single source of truth (§3):** every downstream artefact *binds* to a captured value; it
   never holds its own copy to be re-edited out of sync.
2. **PII↔clinical separation (§2):** clinical rows carry no names; the name is a join away,
   behind its own access boundary, and omittable.
3. **Provenance on every value (§3.3):** each value knows where it came from (intake / extraction
   / clinician entry / clinician-confirmed) and is never silently *computed* where licensing
   forbids it (§1, DEV-100).

---

## 1. The load-bearing licensing rule (inherited, non-negotiable)

Per `assessment-forms-teardown.md §1` and AGENTS.md → Guardrails: **scaled scores, percentile
ranks, index/composite scores are captured inputs with `provenance = clinician`, never computed
fields.** Sona never hosts, embeds, ships, or computes from a licensed raw→scaled→percentile
norm table. The clinician scores manually off the publisher's own tables; Sona captures and
tabulates the value she produced.

The model makes this a **data attribute, not a special case**: every `Instrument` carries a
`licensingClass` flag —

| `licensingClass` | Meaning | Example |
|---|---|---|
| `licensed_self_scored` | Publisher-normed; scores are clinician-derived off the publisher's tables. No auto-scoring. | CELF‑5 UK, PLS‑5, GFTA‑3, BPVS3, WAB‑R |
| `free_criterion` | Free / criterion-referenced; no norm-table restriction. | Communication Matrix, DAGG‑3, CAPE‑V, EAT‑10 |
| `external_thirdparty` | Result produced by another service (school, ENT, prior clinician); captured as reported. | school-run CTOPP / TOWRE |

A `CapturedValue` whose parent instrument is `licensed_self_scored` **cannot** be written with
`provenance = computed`. That invariant is enforced at the data layer, not left to the UI.

---

## 2. Concrete v1 entities & relationships

The DEV-101 conceptual model, made concrete. Names below are logical; physical table names
follow `apps/api/src/db/schema.ts` conventions. **PII entities are shaded** with 🔒.

```
🔒 ClientIdentity ───(identity link)─── Case ───┬── CapturedAssessment ──┬── SourceDocument
      (PII partition)      (clinical, name-free) │      (one per admin)    └── CapturedValue*  (value-level provenance)
                                                 │
                                                 ├── Instrument / FormTemplate   (config: field schema + licensingClass)
                                                 ├── ReportTemplate ──(binding DSL)── GeneratedReport   (draft→in_review→signed)
                                                 ├── TherapyBlock ── SessionFeedback
                                                 └── Resource ── HomeworkAssignment
```

### 2.1 `ClientIdentity` 🔒 — the PII partition (one per person)
The **only** place names, addresses and contact details live. Never referenced by clinical prose.

| Field | Notes |
|---|---|
| `id` (uuid) | The identity key. Clinical rows reference this, nothing else. |
| `tenantId` | Owning practice; residency-scoped (§5). |
| `childGivenName`, `childFamilyName` | Structured (ADR‑006 §5 P0) — never a single display string. |
| `childDob` (date) | ADR‑006 P0. Enables *age-at-event* without storing an age string. |
| `childGender`, `childBirthSex?` | ADR‑006 P1. |
| `childNhsNumber?` | Optional in private practice (ADR‑006 §4). Verification-status when present. |
| `parentGivenName`, `parentFamilyName`, `parentEmail`, `parentPhone` | Carer contact. |
| `parentRelationship` (coded) | parent / guardian / carer → `RelatedPerson.relationship`. |
| `homeAddress`, `gpPractice`, `gpAddress`, `gpPhone` | Structured; from intake page 1. |
| `createdAt`, `updatedAt` | |

**DSAR / erasure boundary:** a right-to-erasure request can be satisfied by deleting/tombstoning
`ClientIdentity` while retaining anonymised clinical records for audit/aggregate — because the
clinical side never embedded the name (§2.2, §2.4).

### 2.2 `Case` — the clinical spine (name-free, one live record per episode)
The one record where intake + uploaded assessment data + session notes converge. **Carries no
name.** This is the aggregate ADR‑006 projects to `Patient` + `EpisodeOfCare`.

| Field | Notes |
|---|---|
| `id` (uuid) | Clinical anchor; becomes `Patient.id`/`EpisodeOfCare` anchor in export. |
| `clientIdentityId` → `ClientIdentity` | **The identity link.** The *only* bridge to PII. |
| `tenantId`, `jurisdiction` | Residency (§5). |
| `status` | `referred → intake → triaged → in_assessment → in_therapy → discharged` (`case_status`). |
| `assignedClinicianId` → user | Owning SLT. |
| `ageBand` (derived) | Computed from `childDob` at event time — held as a label, not re-keyed. |
| `ehcpFlag`, `statutoryPlan?` | EHCP awareness (mvp-brief); statutory-plan branch is a config value, not a template fork. |
| `presentingConcerns` (coded[]) | SNOMED-codable concern categories (ADR‑006 §5 P1) — discrete, not buried in free-text. |
| `createdAt`, `updatedAt` | |

Everything clinical hangs off `Case.id`. A report renderer walking a Case can produce a full
document and only needs `ClientIdentity` for the header block — which it may skip (§2.6).

### 2.3 `Instrument` / `FormTemplate` — the config-driven field schema
One row per assessment instrument or intake form. **Config, not code** — adding an instrument is
data entry, matching the teardown's generalisation guardrail.

| Field | Notes |
|---|---|
| `id`, `tenantId?` | Global catalogue + per-tenant additions. |
| `name`, `version` | e.g. "CELF‑5 UK", form version. |
| `kind` | `intake_form` \| `assessment_instrument`. |
| `licensingClass` | `licensed_self_scored` \| `free_criterion` \| `external_thirdparty` (§1). |
| `fieldSchema` (json) | Ordered field definitions: `key`, `label`, `dataType` (`raw_score`/`scaled_score`/`percentile`/`composite`/`band`/`verbatim`/`qualitative`/`bool`/`text`/`date`), `subtest?`, `required`. **No norm/lookup tables** — field *shape* only. |
| `linkId` map | Stable `linkId`s per field for `Questionnaire`/`QuestionnaireResponse` export (ADR‑006 §5). |

The intake form (`intake-form-spec.md`, 8 pages) is one `FormTemplate` of `kind = intake_form`;
CELF‑5 UK is one `Instrument` of `kind = assessment_instrument`, `licensingClass = licensed_self_scored`.

### 2.4 `CapturedAssessment` (+ `SourceDocument` + `CapturedValue`) — where data actually lands
One `CapturedAssessment` per administration of an instrument for a Case.

**`CapturedAssessment`**

| Field | Notes |
|---|---|
| `id`, `caseId` → Case, `instrumentId` → Instrument | |
| `administeredAt`, `capturedByClinicianId` | |
| `status` | `uploaded → extracting → in_review → confirmed`. Values are only a source of truth once `confirmed`. |

**`SourceDocument`** — the uploaded record form / third-party report the data came from.

| Field | Notes |
|---|---|
| `id`, `capturedAssessmentId` | |
| `gcsUri`, `mimeType`, `pageCount` | Stored in the jurisdiction's GCS bucket (§5); never inlined into exports. |
| `licenceCheckAt`, `licenceAttestation` | Upload-time licence/attribution check hook (DEV‑100). We store *her* filled form's values; we do not reproduce the blank publisher layout. |

**`CapturedValue`** — the atomic unit of "captured once". **This is the single source of truth
for one datum.**

| Field | Notes |
|---|---|
| `id`, `capturedAssessmentId` | |
| `fieldKey`, `subtest?` | Matches `Instrument.fieldSchema` (e.g. `word_classes.scaled_score`). |
| `dataType` | As per field schema. |
| `valueNumeric?` / `valueText?` / `valueCode?` | The value the clinician produced. |
| `provenance` | `intake` \| `extraction` \| `clinician_entry` \| `clinician_confirmed` \| `external`. **Never `computed`** when the instrument is `licensed_self_scored` (§1 invariant). |
| `sourceDocumentId?`, `sourcePage?`, `sourceBBox?` | Extraction lineage — back to the exact spot on the upload. |
| `confidence?` | Extractor confidence; drives the review queue, not report content. |
| `confirmedByClinicianId?`, `confirmedAt?` | Human confirmation stamp (§3.3). |
| `supersedesValueId?` | Edits create a new version; the old value is retained (audit), never overwritten. |

Scaled scores, percentiles and composites are `CapturedValue`s with `provenance ∈ {extraction,
clinician_entry, clinician_confirmed}` — **captured, human-owned, never computed.**

### 2.5 `ReportTemplate` (+ binding DSL) → `GeneratedReport`
**`ReportTemplate`** — the clinician's own IP skeleton (teardown §2). Sections are typed:

| Section `type` | Bound to |
|---|---|
| `static` | Boilerplate (credentials blurb, scaled-score explainer) — never generated. |
| `bound` | A specific captured value / field via the **binding DSL**. |
| `score_table` | A set of `CapturedValue`s laid out as rows (subtest → scaled score → %ile → band). Optional section (informal reports omit it). |
| `ai_drafted` | AI-drafted from bound inputs, **always clinician-edited** before signing. |

**Binding DSL (declarative, read-only over captured data):** a section declares *where its
content comes from*, e.g. `bind: case.identity.childGivenName` (header), `bind:
assessment("CELF-5 UK").value("word_classes.scaled_score")`, `table:
assessment("CELF-5 UK").subtests[receptive] → [scaled_score, percentile, band]`. The DSL only
**reads** confirmed `CapturedValue`s — it cannot compute a scaled score, and a `score_table` that
references a `licensed_self_scored` instrument renders only confirmed captured values (teardown §4).

**`GeneratedReport`** — a rendered instance with a lifecycle.

| Field | Notes |
|---|---|
| `id`, `caseId`, `reportTemplateId` | |
| `status` | `draft → in_review → signed`. Only `signed` is a clinical record (mirrors ADR‑006's "emit only reviewed" rule). |
| `bindingSnapshotAt` | When bindings were last resolved. |
| `renderedArtifactUri?` | PDF in jurisdiction GCS; referenced, not inlined (ADR‑006). |
| `signedByClinicianId?`, `signedAt?`, `hcpcNumberStamp?` | Sign-off + HCPC stamp (mvp-brief). |
| `includeIdentity` (bool) | If false, renders name-free (§2.6). |

### 2.6 De-identified rendering (the find-and-replace problem, solved)
Because prose and score tables bind to `Case`-side `CapturedValue`s and **never contain the name
inline**, the renderer composes the whole document from name-free data and only *joins*
`ClientIdentity` for the header/`bind: case.identity.*` fields. With `includeIdentity = false`
those binds resolve to a neutral token ("the child") and **no name appears anywhere** — no search,
no replace, no risk of a missed occurrence. A de-identified export is the *default-safe* path, not
a post-processing scrub.

### 2.7 `TherapyBlock` / `SessionFeedback` and `Resource` / `HomeworkAssignment`
Carry the post-assessment loop (teardown §2.4–2.6; mvp-brief roadmap #1).

- **`TherapyBlock`** — `id`, `caseId`, `dateRange`, `blockTargets[]`, `sessionCount` (e.g. 10). The
  end-of-block summary (DEV‑106) is composed from its sessions — not re-keyed.
- **`SessionFeedback`** — `id`, `therapyBlockId`, `sessionIndex` ("5 of 10"), `whatWeWorkedOn[]`
  (activity/strategy → notes), `videoClipRefs[]` (non-forwardable resources, DEV‑107/108),
  `nextSteps`, `nextSessionAt`. Rolls up into the block summary.
- **`Resource`** — `id`, `title`, `category`, `assetUri`, `forwardable` (false for video clips).
- **`HomeworkAssignment`** — `id`, `caseId`, `resourceId`, `carryoverForHome`, `carryoverForSchool`
  (first-class split → parent portal + separate school-access path, DEV‑108).

---

## 3. Single source of truth — how a value flows without re-entry

### 3.1 Two capture doors, one store
Every clinical datum enters through exactly one of two doors and lands as a `CapturedValue`:

1. **Intake door** — parent answers the `intake_form` template; each answer becomes a
   `CapturedValue` with `provenance = intake` (structured PII answers route to `ClientIdentity`,
   clinical answers to the Case). This feeds "Relevant Background Information" verbatim.
2. **Extraction-review door** — an uploaded record form / third-party report is extracted
   (DEV‑102/104) into candidate `CapturedValue`s with `provenance = extraction` + source lineage;
   the clinician reviews, corrects, and **confirms**, flipping each to `clinician_confirmed`.

Direct `clinician_entry` is the fallback when there is no document.

### 3.2 Propagation is by reference, not by copy
Reports, summaries and exports **bind** to `CapturedValue`s through the binding DSL (§2.5). No
downstream artefact stores its own editable copy of a captured datum. Consequences:

- Confirm a percentile once → it appears, identically, in the score table of every report that
  binds it. Correct it once → every bound report reflects the correction on next resolve.
- The header name is bound, not typed, so it is consistent across all outputs and removable (§2.6).
- The only place a value is *authored* is its `CapturedValue`; the only place it is *decided* is
  the clinician's confirm action.

### 3.3 Provenance & audit on every value
Each `CapturedValue` records `provenance`, optional source lineage (`sourceDocumentId`/`page`/`bbox`),
`confidence`, and — once accepted — `confirmedByClinicianId` + `confirmedAt`. Edits are **versioned**
via `supersedesValueId` (append-only; old values retained), and every create/confirm/supersede is
written to the append-only `auditLog` (`actor`, `action`, `caseId`, `metadata`, `createdAt`; 7‑year
retention per mvp-brief). This yields, per value, a defensible chain: *what it is → where it came
from → who confirmed it → what it replaced*. Because scores are captured (never computed), the audit
trail also **evidences the licensing bright line** (§1).

---

## 4. FHIR R4 / UK Core mapping (ADR‑006) & residency (ADR‑001)

The relational model is the source of truth; FHIR is an **emit-only projection** (ADR‑006 §1). The
capture-once entities map cleanly:

| Entity | UK Core / R4 target (ADR‑006) |
|---|---|
| `ClientIdentity` (child) | `UKCore-Patient` (structured name, `birthDate`, `gender`, optional NHS number). |
| `ClientIdentity` (carer) | `UKCore-RelatedPerson` (name, `telecom`, `relationship`). |
| `Case` | `UKCore-Patient` anchor + base‑R4 `EpisodeOfCare`; `presentingConcerns` → `ServiceRequest.reasonCode` / `Condition`. |
| `FormTemplate` (intake) + intake `CapturedValue`s | `UKCore-Questionnaire` + `UKCore-QuestionnaireResponse` (via `linkId`s, §2.3). |
| `Instrument` assessment + `CapturedValue`s | base‑R4 `Observation` per captured score (`valueQuantity`/`valueCodeableConcept`); `performer → Practitioner`. Confirmed values only. |
| `SourceDocument` | `UKCore-DocumentReference` (`content.attachment.url` → GCS; **not inlined**). |
| `GeneratedReport` (`signed`) | `UKCore-Composition` (structured sections) + `UKCore-DocumentReference` (PDF). Unsigned/`draft` reports are **not** exported (parity with ADR‑006's reviewed-only rule). |
| `TherapyBlock` / `HomeworkAssignment` | `UKCore-CarePlan` (`activity[]`). |
| `SessionFeedback` progress | base‑R4 `Observation`. |

**Provenance in FHIR:** `CapturedValue.provenance` carries the same honesty the ADR requires — a
score whose provenance is clinician-owned is emitted as a normal `Observation`; **nothing is
serialised as computed** where licensing forbids it. Emit-only means a profile change is a
one-serializer change, never a schema remodel.

**Residency (ADR‑001):** every entity is `tenantId`/`jurisdiction`-scoped. `ClientIdentity`,
`Case`, `SourceDocument` blobs and any generated Bundle live entirely in the tenant's jurisdiction
plane (UK = `europe-west2` Cloud SQL + GCS). The export mapper **asserts `jurisdiction = 'uk'`**
before emitting UK Core resources; **no cross-jurisdiction query, replication, or export.** The
PII↔clinical split is *within* one jurisdiction — it is a confidentiality boundary, not a residency
one; both partitions stay in-region.

---

## 5. Optional migration hook (out of v1 build; model must not block it)

Several design-partner clients have **multi-year** histories (prior reports, past blocks, historic
assessments). v1 does **not** build a bulk importer, but the model is shaped so one can be added
later without a remodel:

- **Back-dating is native.** `administeredAt`, `SessionFeedback.sessionIndex`/dates, and
  `TherapyBlock.dateRange` are explicit event dates, independent of `createdAt`. A historic
  assessment imports with its real date; nothing assumes "now".
- **Provenance has room.** Add `provenance = migrated` (+ a `MigrationBatch` reference) as an
  additional enum value — no structural change; the audit/versioning fields already exist.
- **Documents attach cleanly.** Historic PDFs land as `SourceDocument`s under a
  `CapturedAssessment` with `status = confirmed` and un-extracted (or best-effort-extracted)
  `CapturedValue`s — the same shape as live capture.
- **Identity de-dupe is possible.** Because clinical data links to `ClientIdentity` by id, a
  migrated case can be attached to a new or matched identity without touching clinical rows.
- **Export stays valid.** Migrated data flows through the same FHIR projection; no special path.

This is explicitly **deferred** (like ADR‑006's Year‑2 items) — noted here only so the v1 schema
does not paint the later importer into a corner.

---

## 6. Cross-references & consistency

- Conceptual model: **DEV-101** · this IA: **DEV-109** · Licensing: **DEV-100** (`docs/compliance/instrument-licensing-guardrails.md`).
- Forms/report teardown: `docs/research/assessment-forms-teardown.md` (§1 bright line, §2 templates, §3 CELF capture surface, §4 section→input map).
- Extraction: **DEV-102 / DEV-104** (fill `CapturedValue`, provenance `extraction`) · Report engine: **DEV-105** (consumes binding DSL) · Session/progress: **DEV-106** · Carryover/portal: **DEV-107 / DEV-108**.
- Standards: **ADR-006** (FHIR R4 / UK Core STU2 `2.0.2`, emit-only) · **ADR-001** (jurisdiction stacks).
- Repo guardrail: `AGENTS.md → Guardrails` — licensed-instrument bullet, PHI safety.

**Consistency check vs DEV-101:** entity set, the `licensed_self_scored | free_criterion |
external_thirdparty` flag, value-level provenance, the report lifecycle (`draft→in_review→signed`),
and "scores are captured, never computed" are carried through unchanged; this document only makes
the fields, the binding DSL, the PII↔clinical join, and the FHIR/residency edges **concrete for v1**.
