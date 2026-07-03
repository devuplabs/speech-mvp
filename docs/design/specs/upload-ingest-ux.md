# Form / Document Upload & Ingestion UX

**Spec · Linear DEV-103 · v0.2 · 2026-07-02 · Status: Revised (scope cut) → In Review**
**Data:** structure only — no PII, no publisher content. **Language:** UK English.

The clinician still completes **paper/PDF forms by hand** (intake questionnaires, CELF-5 UK
record forms, session-feedback notes), **scans them with her own tools**, and then **uploads the
files** into Sona. This spec covers everything from "I have a scanned document" to "the extracted
values are queued for review" — upload, typing, licence/attestation, states, scan-quality
guidance, and PHI handling. It hands off to the extraction-review screen (DEV-104); it never
scores or derives anything itself.

> ## v0.2 scope decision — Sona is not a scanner
> **In-app camera capture, the offline capture queue, and capture-device management are cut**
> (product decision, 02 Jul 2026). Scanning is a commodity the clinician already owns: phone
> scanner apps (Notes, Google Drive, Adobe Scan…), office multi-page ADF printer/scanners that
> turn a 22-page record form into a single PDF, flatbeds. We do not rebuild existing tools —
> Sona **accepts files**. This also dissolves the phone-banned-setting problem (nothing to
> capture on site; she scans later at home/office) and removes the on-device PHI queue and the
> ~£150 second-tablet question entirely. The privacy trade-off this creates (scans made with
> personal tools before upload) is tracked as **DEV-116** and mitigated in §5/§6 below.

## 0. Decisions this builds on (D0)

| Ref | Decision this spec must honour |
|---|---|
| **DEV-100** Licensing | Never host/compute-from licensed norm tables. Every instrument carries a flag: `licensed_self_scored` · `free_criterion` · `external_thirdparty`. An **upload-time licence/attestation** check runs for `licensed_self_scored` docs. |
| **DEV-101** Data model | `ClientIdentity` (PII) ↔ `Case` (clinical, name-free). Uploads attach to a **Case** and become `SourceDocument`s inside a `CapturedAssessment`. Values carry provenance. |
| **DEV-102** Extraction | Uploads go to **Gemini-on-Vertex** (UK region) for schema-guided extraction with **per-field confidence**. Extraction-only — never derives scores. |
| **DEV-104** Review | This spec ends by handing the extracted, name-free values to the extraction-review screen. |
| **DEV-116** Risk | Source-side scan hygiene (personal devices/clouds) is a human-lane risk decision; this spec carries its product mitigations (§5 hygiene guidance, §6 metadata stripping). |

Design-system anchors (from `docs/mvp-brief.md`): Flutter client; Inter type; primary teal
`#2D6A6E`; accent coral `#F2A878` reserved for AI/extraction markers; semantic
success/warning/danger; `SonaStepProgress`, `SonaButton`, chip/field widgets reused.

---

## 1. Core concepts & vocabulary

- **Case** — the clinical container an upload attaches to (name-free; DEV-101). Every upload
  begins by choosing/confirming a Case.
- **SourceDocument** — one uploaded artifact (a PDF, or a set of page images treated as one
  document). Has a **document type** and, where relevant, an **instrument** + **licence
  attestation**.
- **CapturedAssessment** — the assessment record a SourceDocument feeds. One assessment can hold
  several source documents (e.g. an 18-page record form + a page of classroom observation notes).
- **Page** — a single PDF page or image. Pages are reorderable, rotatable, and deletable
  **before** the document is submitted for extraction (e.g. drop a stray blank sheet the office
  scanner picked up).
- **Batch** — the act of grouping multiple files into one SourceDocument/assessment.

Provenance rule (carried through to DEV-104): every extracted value's provenance is
**clinician** (she wrote it on the form), never **computed**.

---

## 2. Upload flow (one flow, any device)

One pipeline, reachable from laptop, tablet, or phone. **Always attaches to a Case first.**

1. **Attach to Case** — pick an existing Case or create one (name-free clinical record; PII stays
   in `ClientIdentity`, DEV-101).
2. **Choose document type** (§3) and, if `licensed_self_scored`, complete the **licence/attestation
   check** (§3.2) before files are accepted.
3. **Add files** — drag-and-drop or file picker; on mobile, the OS **share sheet** ("Share →
   Sona") accepts a scan straight from whatever scanner app she uses. Accepts **PDF, JPG, PNG,
   HEIC**; multi-file select; a multi-page PDF is expanded into its pages in a **page tray** so
   it can be reordered/trimmed.
4. **Page tray** — ordered thumbnails with per-page **Rotate / Delete**, drag-to-reorder, and a
   per-page legibility badge (§5). "Add another document" starts a second SourceDocument under
   the **same** assessment (e.g. observation notes alongside the record form).
5. **Submit for extraction** — locks the page set and enters the state machine (§4). After
   submit, the page set is immutable (a new upload is required to change it).

There is deliberately **no capture surface**: no camera, no viewfinder, no offline queue. If a
document only exists on paper in front of her, the guidance is "scan it with the tool you already
use, then upload" (§5).

---

## 3. Document typing + licence/attestation at upload

Typing happens **before** upload so the pipeline knows which extraction schema (DEV-102) to apply
and whether the licence gate is required.

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
| **failed** | Upload or extraction error | Danger chip + reason (e.g. "Upload interrupted", "Couldn't read pages — try re-scanning"). **Retry** re-runs from the failed step (re-upload vs re-extract); the stored page set is preserved. |

Notes:
- **Progress & retry** are per-document; a batch shows aggregate progress plus per-document chips.
- **Retry** on an extraction failure re-submits the **same** stored pages (no re-scan). Retry on
  an upload failure resumes the transfer. Both are idempotent server-side.
- **Hand-off (DEV-104):** `needs-review` is the boundary. This spec owns everything up to and
  including the state chip; the review/confirm/edit of extracted values lives in DEV-104. The
  "Review extraction" CTA is the single hand-off point.

---

## 5. Scan-quality & scan-hygiene guidance

Poor scans are the biggest driver of low-confidence extraction and rework — but the scan happens
in the clinician's own tool, so guidance is **static tips + post-upload checks**, not live camera
hints.

**One-time tips (shown at first upload; linkable thereafter):**
- Use your scanner app's **document mode** (auto-crop/deskew), not a plain photo.
- **300 dpi or "high quality"**, greyscale or colour; flatten creases; avoid glare.
- Multi-page forms: an office **ADF scanner → one PDF** is ideal (all 22 pages in one file).
- Small handwriting (record-form trial rows are dense) needs the page **filling the scan area**.

**Per-page legibility badge (post-upload):** every page in the tray gets a quick server-side
legibility check — tick (good) or amber warn ("Looks blurry — re-scan this page?") so problems
are caught **before** submit, not after extraction fails.

**Pre-submit check:** if any page is amber, a soft confirm — *"2 pages may be hard to read.
Re-scan, or submit anyway?"* Never blocks; the clinician decides.

**Scan hygiene (DEV-116 mitigation — shown with the tips, and in the onboarding runbook):**
- After a successful upload, **delete the scan from the device/app you scanned with** (including
  the scanner app's own history and cloud sync — Notes/Drive/Adobe accounts).
- Prefer a scanner app that **doesn't auto-sync to a personal cloud** for client documents.
- Office printer/scanners: collect the paper original, and if the device emails the PDF, delete
  the email after upload.
- Sona confirms receipt explicitly ("Stored securely in the UK — you can delete your local copy
  now") to make the hygiene step a habit.

**Page & size limits (starting points, confirm in build):**
- Per document: up to **~40 pages** (covers the longest record forms with headroom).
- Per page/file: image ≤ **~12 MB**; PDF ≤ **~50 MB**.
- Accepted: **PDF, JPG, PNG, HEIC**. HEIC transcoded server-side.
- Oversize/unsupported files are rejected at pick time with a plain-language reason.

---

## 6. PHI handling (uploads are PHI)

Uploads contain children's health data and handwritten clinical content — treated as **PHI**
under UK GDPR / DPA 2018, consistent with `AGENTS.md → Guardrails`.

- **UK residency.** Files stored in UK-region GCS; extraction runs on **Gemini-on-Vertex in the
  UK region** (DEV-102). No PHI leaves the jurisdiction; no upload content in third-party services.
- **Metadata stripping on ingest.** Uploaded files are stripped of **EXIF/XMP metadata (including
  GPS)** server-side before storage — scanner apps and phones embed location and device data the
  clinical record must not carry.
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
- **Source-side residual (DEV-116).** The scan exists on the clinician's own device/tool before
  upload — outside Sona's control. Product mitigations: the §5 hygiene guidance, the explicit
  "you can delete your local copy now" receipt, and onboarding-runbook policy. The residual risk
  acceptance lives in **DEV-116** (human lane).
- **Attestation as record.** The DEV-100 licence attestation is stored on the SourceDocument with
  clinician identity + timestamp, supporting the compliance trail.

---

## 7. Screen / flow list (for Figma)

A build-ready list. Reuse existing tokens/components (`SonaStepProgress`, `SonaButton`, chips,
fields); coral is reserved for the AI/extraction (extracting) marker.

| # | Screen / surface | Key elements |
|---|---|---|
| U0 | **Upload entry (from a Case)** | "Upload documents" CTA on the Case |
| U1 | **Attach to Case** | Existing-Case picker or new (name-free) Case; confirms clinical container (DEV-101) |
| U2 | **Document type** | Single-select: Intake · Assessment · Session note · Resource |
| U3 | **Instrument + licence/attestation** *(Assessment only)* | Instrument picker with flag badge; "Do you hold a licence?" attestation; DEV-100 reminder copy; "Other / not listed" fallback |
| U4 | **File upload** | Drag-drop + picker (PDF/JPG/PNG/HEIC); mobile share-sheet entry; multi-page PDF expands into the tray; size/type validation |
| U5 | **Page tray** | Ordered thumbnails; per-page Rotate/Delete; drag-reorder; legibility badges; page count; "Add another document" |
| U6 | **Pre-submit review** | Batch summary (Case, type, instrument, page count); amber-page soft confirm; "Submit for extraction" |
| U7 | **Upload progress** | Per-file + aggregate progress; state chips (uploading → queued → extracting); cancel/retry |
| U8 | **Document list on Case** | Every SourceDocument with state chip; `needs-review` shows **"Review extraction"** → DEV-104; `failed` shows reason + Retry |
| U9 | **Scan tips & hygiene sheet** | One-time §5 guidance; linked from the upload surface and the onboarding runbook |
| U10 | **Media-consent prompt** *(conditional)* | Shown when child media is uploaded and Case consent is absent/unknown; explicit confirm + reason |

**Happy path:** U0 → U1 → U2 → (U3 if Assessment) → U4 → U5 → U6 → U7 →
U8 (`needs-review`) → **hand-off to DEV-104**.

**Phone-banned settings:** no special path — nothing is captured on site; she scans later
wherever she normally scans, then U4 from any device.

---

## 8. Open questions / follow-ups

1. **Page/size limits** — confirm the ~40-page / 12 MB / 50 MB ceilings against the longest real
   record forms and typical scanner output.
2. **Instrument picker source** — the instrument list + DEV-100 flags need a single source of truth
   (data, not hard-coded); confirm ownership with DEV-100/DEV-101.
3. **Multi-document assessments** — confirm the UX for one `CapturedAssessment` spanning several
   SourceDocuments (record form + observation + external results) against DEV-104's review model.
4. **HEIC / scanner variance** — confirm server-side transcode + deskew quality on real scanner-app
   and ADF output before pilot.
5. **Share-sheet integration** — confirm the Flutter share-sheet ("Share → Sona") flow lands on U1
   (Case picker) cleanly on iOS and Android.

## 9. Cross-references

- Licensing: **DEV-100** · `docs/compliance/instrument-licensing-guardrails.md`
- Data model: **DEV-101** · Extraction: **DEV-102** · Extraction review: **DEV-104**
- Scan-hygiene risk: **DEV-116** (human lane)
- Teardown: `docs/research/assessment-forms-teardown.md` · Intake: `docs/intake-form-spec.md`
- Journey: `docs/design/sona-care-journey-map.md` · Brief: `docs/mvp-brief.md`
- Guardrails: `AGENTS.md → Guardrails` (PHI safety, licensed instruments)
