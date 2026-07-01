# Extraction Review & Correction — "Capture-Once Verify" UX

**Linear:** DEV-104 · **Status:** Draft → In Review · **Date:** 2026-07-01
**Data:** structure only — **no PII, no publisher content**. UK English throughout.

Design spec (no code) for the screen where the clinician **verifies and corrects**
the data Gemini extracted from an uploaded assessment form, before it feeds any
report. This is where "capture once, no re-keying" and clinician-in-the-loop trust
are delivered, and where we stay on the right side of instrument licensing.

---

## 0. What this screen is (and is not)

**Is:** a review-and-correct surface. The model has already extracted structured
fields with per-field confidence (DEV-102). The clinician confirms each value,
edits what's wrong, and fills what the model abstained on. Every confirmed value
becomes a `CapturedValue` with value-level provenance (DEV-101), append-only.

**Is not:** a scoring tool. Sona **never** derives a scaled score or percentile
from a raw score, and never hosts a norm/conversion table (AGENTS.md Guardrails;
teardown §1). Scaled scores and percentiles are values the clinician derived
**manually** off the publisher's own appendix and now **enters or confirms** here.
Provenance for those fields is always `clinician`, never `computed`.

### Anchor principles carried in from the brief

- **AI drafts; the clinician decides.** Nothing here is a final clinical record
  until the clinician confirms it. Everything is labelled **DRAFT** until then.
- **No re-keying.** The model does the transcription; the clinician does the
  judgement. We remove the typing, not the clinical decision.
- **Licensing bright line.** Raw score = transcribed-and-confirmed. Scaled score /
  percentile = **clinician-entered** ("self-scored"). The UI makes that visible.
- **PHI safety.** All content stays in the authenticated app; nothing leaves for
  logs, email, or a third party (AGENTS.md).

---

## 1. Layout — side-by-side source ↔ extracted fields

A two-pane workspace, desktop/laptop-first (clinician workspace is web,
1440×900 baseline; usable down to ~1180 wide). Mobile is out of scope here.

```
┌──────────────────────────────────────────────────────────────────────┐
│  Review header:  ‹ file name ›  ·  Instrument: CELF-5 UK (self-scored) │
│                  DRAFT · 6 of 24 confirmed · 3 need checking           │
│                  [ Re-run extraction ]  [ Save draft ]  [ Confirm all ]│
├───────────────────────────────┬──────────────────────────────────────┤
│  SOURCE PANE (left)           │  FIELDS PANE (right)                   │
│                               │                                        │
│  • Rendered page image        │  • Grouped, scrollable field list      │
│  • Page thumbnails / pager    │  • Each field: label, extracted value, │
│  • Zoom / fit / rotate        │    confidence flag, edit control,      │
│  • Highlight box for the      │    provenance + status chips           │
│    field currently in focus   │  • Score tables render as tables       │
│                               │                                        │
│  ⤺ selecting a field scrolls  │  ⤻ hovering a field highlights its    │
│    the source to its region   │    source region on the left          │
└───────────────────────────────┴──────────────────────────────────────┘
```

**Bi-directional linking.** Selecting a field on the right pans/zooms the source
page on the left to the region the value was read from and draws a highlight box.
Selecting a highlight on the left focuses the corresponding field on the right.
(Region coordinates come from extraction; if a field has no region, the link is
disabled and the field is tagged "no source location".)

**Focus model.** Exactly one field is "in focus" at a time; the source highlight
and the field row stay in sync. This is what makes keyboard review fast (§4).

### Per-field confidence flags

Each field shows a confidence state derived from the model's per-field confidence
(DEV-102). Three visible tiers, colour + icon + text (never colour alone — a11y):

| Tier | Meaning | Treatment | Must check? |
|---|---|---|---|
| **High** | Model confident | Neutral row, subtle tick | No (spot-check only) |
| **Low** | Model unsure | Warning-tinted row, "Check this" flag | **Yes — mandatory** |
| **Abstained** | Model declined to invent a value | Empty field, "Model left this blank" | **Yes — clinician fills** |

Mandatory-check fields (Low + Abstained) cannot be swept into a bulk accept (§4);
they must be individually confirmed or edited. A running counter in the header
("3 need checking") drives the **Jump to next uncertain** control.

**Jump-to-next-uncertain.** A persistent control (button + keyboard `n`) advances
focus to the next Low/Abstained field in reading order, scrolling both panes.
When none remain, it reads "All uncertain fields reviewed" and the header's
"needs checking" count hits zero — the pre-condition for **Confirm all**.

---

## 2. Editing UX by field type

Every editable field shows: the **model-proposed** value (preserved, never
silently overwritten), the **current** value, a **confidence** flag, a
**provenance/status** chip, and an inline **edit** affordance. Editing a value
flips its status from `proposed` to `edited`; accepting flips it to `confirmed`.

### 2.1 Text / short fields
(subtest name, band label, dates as written on the form, free identifiers)

- Inline single-line edit. Enter commits, Esc reverts to model-proposed.
- A **"restore model value"** link appears once edited, so a mis-edit is one click
  back — the model-proposed value is always retained for audit (§4).

### 2.2 Verbatim responses
(per-trial child responses the clinician recorded on the record form)

- Multi-line, monospace-ish field to preserve exact wording, punctuation, and
  the child's actual production — these are quotations, not paraphrase.
- Character-faithful: no autocorrect, no smart-quotes substitution, no trimming.
- Trial/row association is shown (e.g. "Item 4") so the clinician can line each
  response up against the source region highlighted on the left.

### 2.3 Qualitative observations
(free-text clinical notes: attention & listening, child's views, class observation)

- Multi-line rich-ish text (plain text + line breaks; no publisher content, no
  templated clinical claims injected by the model).
- Model may propose a transcription; the clinician edits freely. Long abstentions
  render as an empty, clearly-labelled box ("Model left this blank — add notes").

### 2.4 Score tables (the licensing-critical case)

Score tables render as an editable table matching the confirmed teardown shape
(teardown §2.1): one row per subtest, columns:

```
Subtest | What it tests | Raw score | Scaled score¹ | %ile rank¹ | Analysis / band
```

¹ **Scaled score** and **%ile rank** carry a small **"self-scored"** marker
(§5) and are **clinician-entered** — never auto-computed from the raw score.

Column-by-column editing rules:

| Column | Source of value | Editing behaviour |
|---|---|---|
| Subtest | Extracted / template | Confirm or correct label. |
| What it tests | Template boilerplate | Read-only default; editable. Not model-derived. |
| **Raw score** | **Extracted from form** (clinician wrote it) | Transcribed value; clinician confirms/corrects the number. Confidence-flagged like any field. |
| **Scaled score** | **Clinician-derived, entered here** | Editable number input. Provenance fixed to `clinician`. If extraction found a scaled score the clinician had already written on the form, it is treated as a transcribed value she now **confirms** — still `clinician`, never `computed`. **No auto-fill from raw score.** |
| **%ile rank** | **Clinician-derived, entered here** | Same as scaled score. |
| Analysis / band | Extracted or clinician free-text | Plain-language band ("Within Average Range"); editable. |

**Hard rule surfaced in the UI:** there is **no** "calculate", "auto-score", or
"look up" button anywhere in the score table. Entering a raw score does nothing to
the scaled/percentile cells. A one-line helper under the table states the reason
(§5). Composite/index scores, where reported, are additional clinician-entered
rows with the same `self-scored` treatment.

**Adding / removing rows.** The clinician can add a subtest row the model missed,
or remove a row that doesn't apply. Added rows start as `clinician`-provenance
across all cells. The instrument itself carries a `licensed / self-scored` flag
(teardown §1); for **free/criterion-referenced** instruments (Communication
Matrix, DAGG-3, CAPE-V) the "self-scored" markers and the no-compute rule still
hold, but there is no scaled/percentile column to gate.

---

## 3. Bulk actions, keyboard flow, saves, re-run, and gaps

### 3.1 Bulk accept
- **Accept all high-confidence** — one action confirms every **High** field in a
  group (or the whole form), skipping Low/Abstained (which stay mandatory).
- **Accept group** — confirm all *already-reviewed* fields in a section.
- **Confirm all** — enabled only when zero mandatory-check fields remain; this is
  the gate that lifts the DRAFT label (§4). A confirmation dialog restates that
  scaled scores / percentiles are being recorded as clinician-entered values.
- Bulk accept never touches an empty (abstained) field and never fabricates a
  value — consistent with abstain-don't-invent (DEV-102).

### 3.2 Keyboard-friendly (laptop, no mouse required)

| Key | Action |
|---|---|
| `Tab` / `Shift+Tab` | Next / previous field |
| `n` / `p` | **Next / previous uncertain** field (skips High) |
| `Enter` | Edit focused field / commit edit |
| `Esc` | Cancel edit, restore model-proposed value |
| `a` | Accept (confirm) focused field |
| `r` | Restore model value on focused field |
| `Ctrl/Cmd+S` | Save draft (partial save) |
| `?` | Keyboard-shortcut help overlay |

Focus order follows visual reading order; score-table cells are reachable
cell-by-cell. All controls are keyboard-operable and screen-reader labelled
(confidence conveyed by icon + text, not colour alone).

### 3.3 Partial saves & autosave
- **Autosave** each confirm/edit as an append-only event (§4); the header shows
  "Saved · HH:MM". A network blip queues events locally and re-syncs (mirrors the
  app's local draft-autosave pattern).
- **Save draft & exit** returns the clinician to the client's record with the
  form still DRAFT and progress preserved ("6 of 24 confirmed"). Resuming re-opens
  at the first unreviewed field.

### 3.4 Re-run extraction
- **Re-run extraction** re-invokes the model on the same source (e.g. after a
  better re-scan, or a rotate/crop). It is **non-destructive**: any value the
  clinician has already **confirmed or edited** is preserved; only still-`proposed`
  fields are refreshed. A diff banner summarises "4 unreviewed fields updated;
  your 6 confirmed values kept." Re-run is logged as an event with a new model
  run id.
- Re-run never re-computes or overwrites a clinician-entered scaled/percentile.

### 3.5 Missing / illegible fields
- **Abstained (model blank):** rendered as an empty, flagged field the clinician
  fills. Never pre-filled with a guess.
- **Illegible source:** clinician can mark a field **"Illegible on source"** —
  records that the value could not be read (distinct from "not present"), keeps it
  out of the report, and flags it for a re-scan without blocking Confirm all.
- **Not applicable:** clinician can mark a field/row **"N/A for this client"** so
  the report engine (DEV-105) treats the section as intentionally empty, not
  missing. (Aligns with the informal/score-free report branch, teardown §2.3.)

---

## 4. Audit & DRAFT labelling

### 4.1 Model-proposed vs clinician-confirmed/changed (append-only)
Every field carries, and every change appends to, an audit trail (DEV-101,
append-only; AGENTS.md audit rule):

- **Model-proposed value** + the model run id + the field confidence — retained
  even after the clinician edits, so "what the model said" is always recoverable.
- **Clinician action** per field: `confirmed` (accepted as-is), `edited` (with
  before/after), `filled` (abstained → value), `illegible`, `n/a`, or `restored`.
- **Provenance** on the resulting `CapturedValue`: `clinician` for anything the
  clinician entered or confirmed; scaled score / percentile are **always**
  `clinician`, **never** `computed`. No field on this screen is ever `computed`.
- **Actor + timestamp** on every event; nothing is mutated in place or deleted.

The audit is not shown as a wall of history, but each field exposes a small
**"history"** disclosure (model value → your change → when) for transparency, and
the full trail is queryable for the record.

### 4.2 DRAFT labelling until confirmed
- The whole extraction is **DRAFT** from upload until **Confirm all** succeeds.
- Field-level status chips: `Needs check`, `Proposed`, `Edited`, `Confirmed`.
- A DRAFT extraction **cannot feed a report** (DEV-105 reads confirmed values
  only). The report engine consumes `CapturedValue`s with provenance intact.
- Confirming does not "sign" a report — it marks captured data as
  clinician-verified. Report sign-off is a separate downstream gate.

---

## 5. Explicit "self-scored" affordance (licensing line)

The licensing bright line is made visible, not buried in policy:

- **Instrument header badge:** the review header shows the instrument with a
  **"self-scored"** qualifier for licensed instruments (e.g. "CELF-5 UK ·
  self-scored"), signalling that scaled/percentile values are clinician-derived.
- **Column markers:** the **Scaled score** and **%ile rank** column headers carry
  a small **"self-scored"** note/tooltip: *"Entered by you from the publisher's
  own tables. Sona does not calculate scaled scores or percentiles."*
- **No compute affordance:** the absence of any calculate/lookup button is
  deliberate and stated in a one-line helper under the score table.
- **Confirm-all dialog** restates it once: *"Scaled scores and percentiles are
  recorded as values you derived and entered (provenance: clinician). Sona stored
  them; it did not compute them."*
- Provenance is stored as data (DEV-101), so this holds even if the UI copy
  changes — the licensing stance is a data attribute, not just a label.

This copy is deliberately short and reassuring, not legalistic: it tells the
clinician *she* did the scoring and Sona just carried the number across.

---

## 6. Edge cases & states (quick reference)

- **Multi-page form:** fields group by page; source pager tracks focus; progress
  is across the whole document.
- **Multiple instruments in one upload:** each instrument is its own grouped
  section with its own header badge and its own score table (or none).
- **Third-party / external results** (e.g. school-run CTOPP/TOWRE seen in
  reports, teardown §5): captured as free-text values with a `source = external`
  flag; still clinician-confirmed, never computed.
- **Empty extraction / unreadable upload:** whole-screen empty state with
  "Re-scan" / "Upload a clearer copy" guidance; no fabricated fields.
- **Extraction still running:** skeleton rows with a "Extracting…" state; the
  clinician can begin on ready fields.
- **Conflicting duplicate value** (same field read twice): flagged as a conflict
  for the clinician to resolve; never auto-merged.

---

## 7. Screen / flow list (for the Figma task)

Desktop clinician workspace, 1440×900 baseline. Uses existing design system:
Inter type; primary teal `#2D6A6E`; accent coral `#F2A878` reserved for AI-draft
markers; semantic warning `#F59E0B` for "needs check"; radii 8/10/12/16.

| # | Frame | Purpose | Key elements |
|---|---|---|---|
| R0 | **Entry — form uploaded** | Land from client record after upload | File info, instrument detected + "self-scored" badge, "Extracting…" state |
| R1 | **Review workspace — default** | The two-pane screen | Source pane (image, pager, zoom, highlight box), fields pane (grouped list), header (DRAFT, progress, actions) |
| R2 | **Field focused (High)** | Normal confirm interaction | Focused row, synced source highlight, Accept / Edit / history |
| R3 | **Field focused (Low — needs check)** | Mandatory check | Warning treatment, "Check this" flag, jump-to-next control state |
| R4 | **Field focused (Abstained — blank)** | Model left blank | Empty flagged field, "Model left this blank", fill affordance |
| R5 | **Inline edit — text** | Editing a short field | Inline editor, commit/cancel, "restore model value" link |
| R6 | **Inline edit — verbatim / qualitative** | Long-text editing | Multi-line editor, trial/row association, no-autocorrect note |
| R7 | **Score table — view** | Table rendering | Columns per §2.4; "self-scored" markers on scaled/%ile; no calculate button |
| R8 | **Score table — editing scaled/%ile** | Licensing-critical edit | Number inputs, "self-scored" tooltip, helper line, add/remove row |
| R9 | **Jump-to-next-uncertain in motion** | Keyboard flow | Focus advancing, counter decrementing, "all reviewed" end state |
| R10 | **Bulk accept** | Accept-all-high / accept-group | Selection summary, what's skipped (Low/Abstained) |
| R11 | **Re-run extraction — diff banner** | Non-destructive re-run | "confirmed values kept" banner, updated-field markers |
| R12 | **Illegible / N/A marking** | Gap handling | Mark-illegible, mark-N/A, re-scan prompt |
| R13 | **Field history disclosure** | Audit transparency | model value → change → actor → timestamp |
| R14 | **Confirm-all dialog** | DRAFT → confirmed gate | Restated self-scored/provenance copy, confirm/cancel |
| R15 | **Confirmed state** | Post-confirmation | DRAFT lifted, "ready for report" state, return to record |
| R16 | **Keyboard help overlay** | Shortcut reference | `?` overlay listing §3.2 keys |
| R17 | **Empty / error states** | Unreadable / empty extraction | Re-scan / re-upload guidance, no fabricated fields |

**Suggested happy path for the prototype:**
`R0 → R1 → (n) R3 → R5 → (n) R4 → R6 → R7 → R8 → R9 (all reviewed) → R14 → R15`.

---

## 8. Cross-references
- Licensing bright line: teardown §1 · AGENTS.md → Guardrails (licensed instruments) · DEV-100
- Extraction (confidence, abstain-don't-invent): DEV-102
- Data model (CapturedValue, value-level provenance, append-only audit): DEV-101 / DEV-109
- Report engine (consumes confirmed values, no auto-score): DEV-105 · teardown §4
- Score-table shape: teardown §2.1, §3
- Design system: `docs/mvp-brief.md` → Design system
