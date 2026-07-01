# Form / Document Upload & Ingestion UX

**Spec · Linear DEV-103 · v0.1 · 2026-07-01 · Status: Draft → In Review**
**Data:** structure only — no PII, no publisher content. **Language:** UK English.

The clinician still completes **paper/PDF forms by hand** (intake questionnaires, CELF-5 UK
record forms, session-feedback notes) and then **uploads the completed documents** into Sona.
This spec covers everything from "I have a finished form" to "the extracted values are queued
for review" — capture, typing, licence/attestation, upload states, quality guidance, device
strategy, and PHI handling. It hands off to the extraction-review screen (DEV-104); it never
scores or derives anything itself.

## 0. Decisions this builds on (D0, in review)

| Ref | Decision this spec must honour |
|---|---|
| **DEV-100** Licensing | Never host/compute-from licensed norm tables. Every instrument carries a flag: `licensed_self_scored` · `free_criterion` · `external_thirdparty`. An **upload-time licence/attestation** check runs for `licensed_self_scored` docs. |
| **DEV-101** Data model | `ClientIdentity` (PII) ↔ `Case` (clinical, name-free). Uploads attach to a **Case** and become `SourceDocument`s inside a `CapturedAssessment`. Values carry provenance. |
| **DEV-102** Extraction | Uploads go to **Gemini-on-Vertex** (UK region) for schema-guided extraction with **per-field confidence**. Extraction-only — never derives scores. |
| **DEV-104** Review | This spec ends by handing the extracted, name-free values to the extraction-review screen. |

Design-system anchors (from `docs/mvp-brief.md`): Flutter client; Inter type; primary teal
`#2D6A6E`; accent coral `#F2A878` reserved for AI/extraction markers; semantic
success/warning/danger; `SonaStepProgress`, `SonaButton`, chip/field widgets reused.

---

## 1. Core concepts & vocabulary

- **Case** — the clinical container an upload attaches to (name-free; DEV-101). Every upload
  begins by choosing/confirming a Case.
- **SourceDocument** — one uploaded artifact (a PDF, or a set of captured page images treated
  as one document). Has a **document type** and, where relevant, an **instrument** + **licence
  attestation**.
- **CapturedAssessment** — the assessment record a SourceDocument feeds. One assessment can hold
  several source documents (e.g. an 18-page record form + a page of classroom observation notes).
- **Page** — a single captured image or PDF page. Pages are ordered, retakeable, reorderable,
  deletable **before** the document is submitted for extraction.
- **Batch** — the act of grouping multiple pages/files into one SourceDocument/assessment.

Provenance rule (carried through to DEV-104): every extracted value's provenance is
**clinician** (she wrote it on the form), never **computed**.

---

## 2. Upload flows

Two entry surfaces, one shared pipeline. Both **always attach to a Case first**.

### 2.1 Multi-page photo capture (in-app camera — phone/tablet)

For settings where cameras are allowed, or for capture after leaving a phone-banned site.

1. **Attach to Case** — pick an existing Case or create one (name-free clinical record; PII stays
   in `ClientIdentity`, DEV-101).
2. **Choose document type** (§3) and, if `licensed_self_scored`, complete the **licence/attestation
   check** (§3.2) before the camera opens.
3. **Capture pages** — full-screen camera with a live **page frame** and edge/contrast hints
   (§5). Tap to shoot; the page is auto-cropped/deskewed to the detected page rectangle.
4. **Page tray** — captured pages appear as a horizontal thumbnail strip with page numbers.
   Per page: **Retake**, **Delete**, **Rotate**; drag-to-**reorder**. A running count
   ("Page 6 of ~18") and a "capture-quality" tick/warn badge per page.
5. **Batch → one assessment** — all pages in the tray form **one SourceDocument** in one
   `CapturedAssessment`. "Add another document" starts a second SourceDocument under the **same**
   assessment (e.g. observation notes alongside the record form).
6. **Submit for extraction** — locks the page set and enters the state machine (§4). After submit,
   the page set is immutable (a new upload is required to change it).

### 2.2 File upload (PDF / images — laptop or tablet)

For the "upload later from a laptop" reality and scanned PDFs.

1. **Attach to Case** (as above).
2. **Choose document type** + licence/attestation (§3) — same gate, before files are accepted.
3. **Drag-and-drop / file-picker** — accepts **PDF, JPG, PNG, HEIC**. Multi-file select; a
   multi-page PDF is expanded into its pages in the same tray as §2.1 so it can be reordered/
   trimmed (e.g. drop a blank cover page).
4. **Batch, reorder, delete** — identical page-tray affordances to camera capture.
5. **Submit for extraction** → state machine (§4).

### 2.3 Offline capture-then-upload (phone-banned settings)

Field reality: **phones are banned in nurseries and some schools** (GDPR / safeguarding); the
SLT uses an **iPad for stimulus** and may capture on a **second cheap tablet** or upload later
from a laptop. The flow must survive **no connectivity at capture time**.

- **Capture offline** — the in-app camera works with **no network**. Pages are stored in an
  **encrypted on-device queue** (device encryption at rest; app-level protection). A visible
  **"On this device — not yet uploaded"** banner and a pending-count badge make the risk legible.
- **Deferred upload** — when the device is back on a trusted network, an **"Upload queue"** screen
  lists pending documents (Case, type, page count, captured time) and uploads them; state resumes
  at §4 `uploading`.
- **Bounded local retention** — the on-device queue is **PHI** (§6): auto-purge from the device
  once server receipt is confirmed; a max local-retention window (e.g. 7 days) after which the app
  warns and refuses new captures until the queue is cleared. No capture content is written to logs.
- **Laptop fallback** — if capture happened on a personal camera in a permitted setting, the same
  images are simply file-uploaded (§2.2) later; no in-app offline queue needed.

---

## 3. Document typing + licence/attestation at upload

Typing happens **before** capture/upload so the pipeline knows which extraction schema (DEV-102)
to apply and whether the licence gate is required.

### 3.1 Document type (single-select, required)

| Type | Feeds | Extraction schema intent |
|---|---|---|
| **Intake** | Intake record on the Case (maps to `intake-form-spec.md` fields) | Parent/carer questionnaire fields; media-consent flag surfaced (§6) |
| **Assessment** | A `CapturedAssessment` | Instrument record form → raw/scaled/percentile + verbatim/qualitative (see §3.2) |
| **Session note** | Session/feedback record (DEV-106) | "What we worked on", targets, next steps; references to any attached clips |
| **Resource** | Attached material / stimulus | Stored as-is; not field-extracted |

Only **Assessment** can be `licensed_self_scored`; the others skip the licence gate.

### 3.2 Instrument + licence/attestation check (DEV-100)

When type = **Assessment**, the SLT selects the **instrument** from a picker. Each instrument
carries its DEV-100 flag:

- **`licensed_self_scored`** (e.g. CELF-5 UK, PLS-5, GFTA-3, BPVS3, WAB-R) →
  **licence/attestation gate is required**:
  - "Which instrument is this?" — instrument confirmed.
  - "Do you hold a current licence for this instrument?" — **attestation checkbox**, recorded with
    timestamp + clinician identity on the SourceDocument (audit trail, DEV-101).
  - Standing reminder copy: *"Sona captures the scaled scores and percentiles **you** derived from
    the publisher's own tables. Sona does not compute or store the publisher's norm tables."*
  - Extraction (DEV-102) pulls **raw scores, the clinician-derived scaled scores/percentiles, and
    verbatim/qualitative content** only. It **never** derives a scaled score/percentile from a raw
    score. No auto-score anywhere in this flow.
- **`free_criterion`** (e.g. Communication Matrix, DAGG-3, CAPE-V, EAT-10) → **no licence gate**;
  extraction proceeds normally.
- **`external_thirdparty`** (e.g. a school-run CTOPP/TOWRE result the SLT is transcribing) →
  captured as free-text values flagged `source = external`; no licence attestation, no derivation.

If the instrument isn't in the picker, the SLT can choose **"Other / not listed"** and provide a
free-text name; it defaults to `external_thirdparty` handling (safest — no derivation, no hosted
norms).

---

## 4. Upload & ingestion states

One state machine drives the status chip on every document, in both the upload tray and the
Case's document list.

```
 uploading ─▶ queued ─▶ extracting ─▶ extracted ─▶ needs-review ─▶ (hand-off to DEV-104)
     │           │            │
     └───────────┴────────────┴─────────────────────────────────▶ failed
```

| State | Meaning | UX |
|---|---|---|
| **uploading** | Bytes transferring to UK storage | Per-file progress bar; overall % for a batch; cancel available. Resumable on flaky mobile connections. |
| **queued** | Received; awaiting extraction worker | Neutral "Queued" chip; no user action needed. |
| **extracting** | Gemini-on-Vertex schema-guided extraction running (DEV-102) | Coral "Extracting…" chip (AI marker colour); indeterminate spinner. |
| **extracted** | Fields returned with per-field confidence | Transient; auto-advances to needs-review. |
| **needs-review** | Values await clinician confirmation | Primary CTA **"Review extraction"** → opens DEV-104 review screen for that document. Low-confidence field count surfaced as a hint ("4 fields need a look"). |
| **failed** | Upload or extraction error | Danger chip + reason (e.g. "Upload interrupted", "Couldn't read pages — try re-capturing"). **Retry** re-runs from the failed step (re-upload vs re-extract); page set is preserved so she isn't re-shooting 18 pages. |

Notes:
- **Progress & retry** are per-document; a batch shows aggregate progress plus per-document chips.
- **Retry** on an extraction failure re-submits the **same** stored pages (no re-capture). Retry on
  an upload failure resumes the transfer. Both are idempotent server-side.
- **Hand-off (DEV-104):** `needs-review` is the boundary. This spec owns everything up to and
  including the state chip; the review/confirm/edit of extracted values lives in DEV-104. The
  "Review extraction" CTA is the single hand-off point.

---

## 5. Capture-quality guidance (maximise extraction accuracy)

Poor captures are the biggest driver of low-confidence extraction and rework. Guidance is
**inline at capture**, not a wall of tips.

**Live camera hints (real-time):**
- **Full page in frame** — page-edge detection; the frame outline turns success-green when all
  four corners are detected, warning-amber if the page is clipped.
- **Lighting** — a "too dark / glare detected" nudge; suggest turning the page to kill reflections.
- **Contrast / focus** — blur-detection warns before the shot is kept; encourage flat, un-creased
  pages.
- **Fill the frame** — prompt to move closer for small handwriting (record-form trial rows are dense).

**Per-page badge (after capture):** each thumbnail gets a quality tick (good) or amber warn
("Looks blurry — retake?") so problems are caught **before** submit, not after extraction fails.

**Pre-submit check:** if any page is amber, a soft confirm — *"2 pages may be hard to read.
Retake, or submit anyway?"* Never blocks; the clinician decides.

**Page & size limits (starting points, confirm in build):**
- Per document: up to **~40 pages** (covers the longest record forms with headroom).
- Per page/file: image ≤ **~12 MB**; PDF ≤ **~50 MB**.
- Accepted: **PDF, JPG, PNG, HEIC**. HEIC transcoded server-side.
- Oversize/unsupported files are rejected at pick time with a plain-language reason.

---

## 6. Device strategy (as UX)

The field reality forces a device decision; the UX must make both paths first-class rather than
assuming a phone in hand.

**Single-device path (default).** The SLT's own tablet/phone captures where permitted, or she
uploads from her laptop after the visit. Everything in §2.1 / §2.2 covers this. The app must not
*require* a camera — file upload is always available.

**Second-device path (~£150 tablet).** For **phone-banned** nurseries/schools, a cheap dedicated
tablet is the capture device:
- The **same Sona app / same login** on the second tablet; captures attach to the same Cases and
  sync to the server (§2.3 offline queue handles no-connectivity sites).
- UX presents this as **"Capture device"** — a labelled device in the account so it's clear which
  hardware holds pending PHI, and so a lost/replaced tablet can be **de-authorised** (remote sign-
  out clears its local queue).
- Onboarding copy positions the £150 tablet as the compliant alternative to a banned phone:
  *stimulus stays on the iPad; capture happens on the dedicated tablet; nothing personal is used
  on-site.*

**Direct phone → app (where allowed).** The wanted "photograph straight into the app" flow is
exactly §2.1; it's simply gated by the permitted-setting reality, not a separate feature.

Decision cue in-product: a short **"Where are you capturing?"** helper (permitted / phone-banned)
that recommends the right path and links the offline-queue explainer — set once per setting, not
per upload.

---

## 7. PHI handling (uploads are PHI)

Uploads contain children's health data and handwritten clinical content — treated as **PHI**
under UK GDPR / DPA 2018, consistent with `AGENTS.md → Guardrails`.

- **UK residency.** Files stored in UK-region GCS; extraction runs on **Gemini-on-Vertex in the
  UK region** (DEV-102). No PHI leaves the jurisdiction; no upload content in third-party services.
- **No content logging.** Upload/extraction telemetry logs **metadata only** (Case id, document
  type, page count, state, timing) — **never** page images, extracted field values, or verbatim
  responses. Aligns with the logger allowlist / `logging-policy.md`.
- **Child-media consent.** The intake form captures *"May the child be photographed/filmed?"*
  (`intake-form-spec.md` p8). Where an upload contains **child media** (photos of the child,
  video-clip references in session notes), the flow **checks the Case's media-consent flag**:
  - consent present → proceed;
  - consent absent/unknown → warn and require explicit confirmation before storing child media,
    with the reason recorded. Assessment record-form pages (handwriting/scores) are clinical
    records, not child media, and are not gated by media consent — but are still PHI.
- **Encryption & audit.** Encrypted in transit and at rest; every upload, state change,
  licence-attestation, and hand-off writes to the **append-only audit log** (who/what/when).
- **On-device PHI (offline queue).** Encrypted at rest on device; auto-purged on confirmed server
  receipt; bounded local-retention window; de-authorisable per §6. Never synced to any personal
  cloud/photo roll — capture writes into the app's protected store, not the OS gallery.
- **Attestation as record.** The DEV-100 licence attestation is stored on the SourceDocument with
  clinician identity + timestamp, supporting the compliance trail.

---

## 8. Screen / flow list (for Figma)

A build-ready list. Reuse existing tokens/components (`SonaStepProgress`, `SonaButton`, chips,
fields); coral is reserved for the AI/extraction (extracting) marker.

| # | Screen / surface | Key elements |
|---|---|---|
| U0 | **Upload entry (from a Case)** | "Add document" CTA on the Case; two paths: *Capture with camera* · *Upload files* |
| U1 | **Attach to Case** | Existing-Case picker or new (name-free) Case; confirms clinical container (DEV-101) |
| U2 | **Document type** | Single-select: Intake · Assessment · Session note · Resource |
| U3 | **Instrument + licence/attestation** *(Assessment only)* | Instrument picker with flag badge; "Do you hold a licence?" attestation; DEV-100 reminder copy; "Other / not listed" fallback |
| U4 | **Camera capture** | Full-screen camera; live page-frame + lighting/contrast/focus hints; shutter; auto-crop/deskew |
| U5 | **Page tray** | Ordered thumbnails; per-page Retake/Delete/Rotate; drag-reorder; quality badges; page count; "Add another document" |
| U6 | **File upload (laptop/tablet)** | Drag-drop + picker (PDF/JPG/PNG/HEIC); multi-page PDF expands into the tray; size/type validation |
| U7 | **Pre-submit review** | Batch summary (Case, type, instrument, page count); amber-page soft confirm; "Submit for extraction" |
| U8 | **Upload progress** | Per-file + aggregate progress; state chips (uploading → queued → extracting); cancel/retry |
| U9 | **Document list on Case** | Every SourceDocument with state chip; `needs-review` shows **"Review extraction"** → DEV-104; `failed` shows reason + Retry |
| U10 | **Upload queue (offline)** | Pending on-device documents; "not yet uploaded" banner + count; upload-all when back online |
| U11 | **Capture-device / setting helper** | "Where are you capturing?" (permitted / phone-banned); recommends path; links offline explainer; manage/ de-authorise capture device |
| U12 | **Media-consent prompt** *(conditional)* | Shown when child media is uploaded and Case consent is absent/unknown; explicit confirm + reason |

**Primary happy path:** U0 → U1 → U2 → (U3 if Assessment) → U4/U6 → U5 → U7 → U8 →
U9 (`needs-review`) → **hand-off to DEV-104**.

**Phone-banned path:** U0 → U1 → U2 → (U3) → U4 (offline) → U5 → U7 (queued on device) →
later U10 → U8 → U9 → DEV-104.

---

## 9. Open questions / follow-ups

1. **Page/size limits** — confirm the ~40-page / 12 MB / 50 MB ceilings against the longest real
   record forms and typical scanner output.
2. **Local-retention window** — confirm the on-device offline-queue max age (proposed 7 days) with
   the DPIA owner.
3. **Instrument picker source** — the instrument list + DEV-100 flags need a single source of truth
   (data, not hard-coded); confirm ownership with DEV-100/DEV-101.
4. **Multi-document assessments** — confirm the UX for one `CapturedAssessment` spanning several
   SourceDocuments (record form + observation + external results) against DEV-104's review model.
5. **HEIC / scanner variance** — confirm server-side transcode + deskew quality on real device
   output before pilot.

## 10. Cross-references

- Licensing: **DEV-100** · `docs/compliance/instrument-licensing-guardrails.md` (to be written)
- Data model: **DEV-101** · Extraction: **DEV-102** · Extraction review: **DEV-104**
- Teardown: `docs/research/assessment-forms-teardown.md` · Intake: `docs/intake-form-spec.md`
- Journey: `docs/design/sona-care-journey-map.md` · Brief: `docs/mvp-brief.md`
- Guardrails: `AGENTS.md → Guardrails` (PHI safety, licensed instruments)
