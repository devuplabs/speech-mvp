# Resource & Homework Hub — Design Spec

*Design spec for **DEV-107**: a central resource library plus homework assignment and
tick-off, for a UK private Speech & Language Therapy (SLT) practice. Portal-first,
link-out, non-forwardable. No PII, no publisher content.*

**Date:** 2026-07-01 · **Status:** Draft → In Review · **Data:** structure only, synthetic examples only
**Depends on:** DEV-100 (licensing guardrails) · DEV-101 (data model) · DEV-108 (school-scoped access)
**Informs:** Figma resource-hub screens; carryover surface (journey stage 9)

---

## 0. Problem & intent (read first)

Resource sharing today is ad hoc: photocopies, phone photos of worksheets, and one-off
links dropped into email or WhatsApp. There is no central library, nothing is reusable,
and — critically — **school "doesn't know which resources to carry over."** Homework goes
out but the clinician cannot see whether a family actually engaged.

Sona's answer is an **upload-once, share-via-link** hub with four resource categories, plus
**homework assignment with tick-off** where the completion signal comes back to the
clinician. The design must hold two hard lines from DEV-100 at all times:

1. **Link-out, never redistribute.** Purchased or copyright materials (e.g. published
   worksheet packs, workbook publishers, teaching-resource libraries) are **linked to their
   source**, never re-hosted, re-uploaded, or emailed as files.
2. **Non-forwardable delivery.** Everything reaches the family through the authenticated
   portal via scoped links, not forwardable attachments — and **school gets its own scoped
   access path (DEV-108)**, never the parent's link.

This is a **carryover** surface (journey stage 9): it exists to make the work travel
off-screen into home and school. It is **adult-facing only** — it must not add children's
screen time (product principle #3). Custom video clips feature the **clinician herself**, so
consent protects her as well as the client.

---

## 1. Resource model & categories

### 1.1 The `Resource` entity (owned library, reusable)

A `Resource` is a **library item the clinician owns and can reuse across any client**. It is
created **once** and then assigned many times (see §2). It is *not* tied to a single case at
creation — reuse is the whole point.

Generic fields (align with DEV-101):

| Field | Notes |
|---|---|
| `id` | stable identifier |
| `title` | clinician-authored, plain-language |
| `category` | one of the four in §1.2 — drives handling + guardrails |
| `description` | short clinician note: what it's for, how to use it |
| `tags[]` | generic tagging (see §1.4) — target area / age band / specialty |
| `source` | provider name + canonical URL (for link-out and external categories) |
| `licence` | `owned` \| `link_out_purchase` \| `external_free` \| `custom_media` (see §4) |
| `consent_ref` | required for `custom_media`; links to the consent record (§4.3) |
| `media_ref` | GCS object handle for owned files / custom clips (never for link-out) |
| `visibility_scope` | who an assignment of this may be shared with: `parent`, `school`, or both |
| `provenance` | `clinician` — authored/curated by the clinician, never model-generated |
| `status` | `active` \| `archived` (soft-delete; assignments keep history) |
| `created_at` / `updated_at` | audit |

Tenanted to the practice; solo-practitioner first (no cross-practice sharing in v1).

### 1.2 The four categories

1. **Purchase link** — a link-out to a paid third-party resource. Sona stores **only the
   title, description, tags, provider name, and the purchase URL**. The family (or school)
   buys directly from the provider; **the provider is paid directly** (DEV-100). Sona never
   hosts the file, never proxies payment, and never caches the content behind the paywall.
2. **File** — a resource the clinician **owns** (her own handout, target sheet, home-practice
   list). Stored in GCS, delivered through the portal. Uploads pass the licence/attribution
   check (§4.2) so purchased/copyright material cannot be smuggled in as a "file".
3. **Custom video clip** — a short clinician-recorded demonstration (target length ~15s;
   confirm max with the partner — see teardown §5 open Q4). The clinician typically appears
   in-frame modelling a sound/strategy. **Requires custom-media consent** before it can be
   assigned or shared (§4.3). Stored in GCS; delivered via short-lived, non-forwardable,
   watermarked playback (§3).
4. **External link (YouTube / free web)** — a link-out to a **free** external resource. Stored
   as title + tags + URL; opens in the provider's own player/site. No re-hosting, no download,
   no re-embedding of paywalled content.

> **Categories 1 & 4 are pointers; 2 & 3 are content we host.** The category is the primary
> switch that decides whether Sona stores bytes or only a URL — and which guardrail applies.

### 1.3 Upload-once, reuse-many

- A resource is authored once into the library and surfaced in a searchable/filterable grid.
- **Assigning** it to a case/block (§2) creates an `Assignment`, not a copy — edits to the
  library item's description/tags propagate; the underlying media is never duplicated per client.
- Archiving a resource hides it from new assignments but preserves the history of past ones.

### 1.4 Tagging (generic)

Tagging is **generic and free-form within controlled vocabularies** (DEV-101 generic tagging),
not hard-coded categories:

- **Target area** — e.g. speech sound, expressive language, receptive language, fluency,
  social communication, attention & listening, voice, feeding/eating (vocabulary-neutral,
  extensible across paediatric + adult).
- **Age band** — 0–3 / 3–7 / 7–11 / 11+ (mirrors intake age bands) — advisory, not a lock.
- **Specialty** — generic specialty tag so the library generalises across ASLTIP.

Tags are filters, not access controls. Filtering by target area is how the clinician (and the
school view) answer *"which resources carry over for this target?"* — the pain called out
directly by schools.

---

## 1a. Adding a resource (DEV-122 addition, 02 Jul)

The "+ Add resource" flow (Figma **D113-07**) — add once to the library, assign to any case
afterwards:

1. **Pick a category** (the category drives the gates):
   - **My file** (PDF / images / audio) → upload + **licence attestation** where the material is
     purchased/copyright (per §4); the clinician's own worksheets need no attestation.
   - **Purchase link** → URL + provider + price; stored as **link-out only** (the provider is
     paid directly; nothing re-hosted).
   - **Custom video** → upload/record once, reuse forever; **consent gate** (the clinician
     appears in frame), plus the parent media-consent check at assignment time; delivered
     watermarked, view-only, expiring (§3).
   - **External link** → YouTube/site URL + preview.
2. **Tag it (segment-neutral):** target area · age band · specialty — tags are data (extended
   per segment pack), so the same hub serves paediatric and adult segments.
3. **Save to library.** Assignment (with the Home / School / Referrer audience split) stays a
   separate step (§2, Figma D113-02).

---

## 2. Assigning resources & homework; tick-off & engagement

### 2.1 The `HomeworkAssignment` entity

An assignment links a `Resource` to a **Case** and (optionally) a **therapy Block**, and
carries the between-session/tick-off state (DEV-101):

| Field | Notes |
|---|---|
| `id` | stable identifier |
| `resource_id` | the library item assigned |
| `case_id` | the client/case |
| `block_id` | optional — ties homework to a therapy block/plan |
| `target_ref` | optional link to a Target (from Target Setting, teardown §2.4) |
| `audience` | `home` \| `school` \| `both` — drives which scoped link is issued (§3) |
| `instructions` | clinician note: what to practise, how often, success criterion |
| `assigned_at` / `due_or_review_at` | timing; review date can align to next session |
| `completion[]` | tick-off events (§2.3) |
| `status` | `assigned` \| `in_progress` \| `done` \| `reviewed` |

The **School vs Home split is first-class** and comes straight from the Target Setting
report's *Carryover for School* / *Carryover for Home* structure (teardown §2.4). `audience`
is that split, expressed as data.

### 2.2 Assigning flow (clinician)

From a case/block, the clinician:
1. Picks resources from the library (filtered by the case's target areas).
2. Sets `audience` (home / school / both), instructions, and a review date.
3. Confirms — Sona checks guardrails (consent present for custom media; licence flag valid)
   before the assignment can be shared.

An assignment can bundle several resources into a single "home practice for this block" set,
mirroring how a session-feedback note references its attached clips (teardown §2.6).

### 2.3 Tick-off (parent / child-via-parent)

- **Access stays with the parent.** Tick-off is an **adult action in the parent portal** —
  the parent marks a home-practice item done (optionally "we did this together"). No child
  login, no child-facing app (principle #3).
- Each tick writes a `completion` event: `who` (parent/school), `when`, optional short note.
  Toggleable (a mis-tick can be undone); the event log is retained for audit.
- Tick-off is **a lightweight engagement signal, not a clinical record** — it is not an AI
  artefact and needs no draft/review badge. The clinical record remains the session notes.

### 2.4 Clinician engagement view

The point of tick-off is to **let the clinician spot non-engaged families**. The clinician's
carryover/engagement view shows, per case/block:

- Assigned vs completed count, and **last-activity date** per assignment.
- A clear **"not started / no recent activity"** state — the flag that surfaces a
  disengaged family early, so she can nudge or adapt.
- School vs home engagement shown **separately** (school activity comes via the school path,
  §3), so she can tell whether carryover is landing at home, at school, or neither.
- No leaderboard, no gamification, no child-facing metrics — an adult clinical triage aid only.

---

## 3. Secure, non-forwardable sharing (ties to DEV-108)

### 3.1 Delivery principles

- **Portal-first.** Content lives in the authenticated portal / GCS. Notification email is
  **notification-only** ("new home practice is ready") and carries **no PHI and no resource
  content** — consistent with the Mailgun notification-only rule in the MVP brief.
- **Non-forwardable.** Access is bound to the recipient's authenticated session, not to a
  link that works for anyone who holds it. A forwarded URL must **not** grant access.
- **Link-out stays link-out.** For purchase/external categories, the "share" is the provider
  URL; Sona adds no wrapper that could be read as re-hosting.
- **Hosted media is short-lived + watermarked.** Files and custom clips are served via
  short-TTL, per-session signed access, no direct download of custom clips, and custom clips
  carry a visible watermark (practice/clinician identifier) to deter re-sharing and to
  protect the clinician who appears in them (§4.3).

### 3.2 Parent path

The parent receives assignments in **their own** portal, tied to their case. Their scoped
link/session only ever exposes **their** case's assignments — never another family's, and
never the school's separate view.

### 3.3 School path (its own scoped access — DEV-108)

- School gets **its own scoped access**, distinct from the parent's. It is **not** the
  parent's link forwarded on, and it **never** exposes the parent's portal or full case PII.
- School sees only assignments with `audience` = `school` or `both`, scoped to the specific
  client(s) that school is authorised for.
- School can **tick off** its own carryover items; those completions are attributed
  `who = school` and feed the clinician's engagement view **separately** from home (§2.4).
- This realises the Target Setting *Carryover for School* branch (teardown §2.4) as a real,
  separately-scoped surface — the direct fix for "school doesn't know which resources to
  carry over."
- Scope, revocation, and the auth mechanics of the school link are owned by **DEV-108**; this
  spec depends on it and must not invent a parallel mechanism.

### 3.4 Audit

Every issue/open/tick event is written to the append-only audit log (who accessed which
assignment, when) per the platform audit guardrail.

---

## 4. Licensing guardrails (from DEV-100)

### 4.1 Link-out & pay-provider-directly

- Purchase-link and external resources are **pointers only** — title, tags, provider, URL.
- The family/school transacts **directly with the provider**; Sona takes no cut, proxies no
  payment, and stores no purchased file.
- The provider's brand/name is shown for attribution and trust; **no publisher content**
  (worksheets, images, workbook pages) is copied into Sona.

### 4.2 No redistribution (upload gate)

- The **File** upload path carries a **licence/attribution check** (mirrors the assessment
  upload check, teardown §1): the clinician attests the file is **her own IP** (or genuinely
  licensed-for-redistribution). Purchased/copyright packs must be added as **purchase links**,
  not uploaded.
- Sona never re-hosts, caches, or emails purchased/copyright materials. If in doubt, the
  category is link-out.
- Owned files may still only be **shared through the non-forwardable portal path** (§3), never
  as a raw forwardable attachment.

### 4.3 Custom-video consent (protect the clinician too)

- A **custom video clip cannot be assigned or shared until custom-media consent is recorded**
  (`consent_ref` populated). The assign action is blocked otherwise.
- Consent is dual-purpose: it covers **the client** appearing/being addressed **and the
  clinician**, who appears in-frame modelling the strategy — she is a data subject in her own
  clips and the design must protect her likeness.
- Clips are delivered watermarked, non-downloadable, and short-lived (§3.1); consent
  withdrawal revokes active shares and archives the clip.
- Consent capture/lawful-basis specifics align with the platform consent + DPIA work; this
  spec requires the **gate**, and defers the record's storage details to the data model /
  compliance owners.

---

## 5. Screen & flow list (for a Figma task)

Design system: existing Sona tokens (Inter; teal `#2D6A6E`; warm off-white `#FAFAF7`; radii
8–16). No AI-draft badge on this surface (tick-off is not an AI artefact). Web 1440×900 for
clinician; mobile 375×812 for parent; school view is web-first, deliberately minimal.

**Clinician (web)**

1. **Resource Library — grid** — searchable/filterable resource cards (category chip, tag
   chips, provider badge for link-out); filters by target area / age band / specialty; empty
   state; "Add resource".
2. **Add / edit resource — category switch** — one form that adapts to the four categories:
   purchase-link (provider + URL), file (upload + **licence attestation**), custom video
   (record/upload + **consent gate**), external link (URL). Show the guardrail inline.
3. **Custom-video consent gate** — blocking modal/state when assigning a clip without
   consent: explains client + clinician protection, links to consent capture.
4. **Assign to case/block** — pick resources → set audience (home / school / both),
   instructions, review date → guardrail confirmation → assign.
5. **Case carryover / engagement view** — per case: assigned vs done, last-activity, **"no
   recent activity" flag**, home vs school split, per-assignment drill-in.

**Parent (mobile)**

6. **Home practice list** — assignments for their case, grouped by block/target;
   category-aware items (open link-out, play clip, open file); clear instructions.
7. **Resource detail + tick-off** — single item; "Mark done" toggle with optional note;
   link-out opens provider; custom clip plays watermarked, non-downloadable.

**School (web, DEV-108 scoped)**

8. **School carryover view** — its **own** scoped entry (not the parent's link); only
   `school`/`both` items for authorised client(s); no parent portal, no full case PII;
   school tick-off with attribution.

**Cross-cutting**

9. **Non-forwardable / notification pattern** — notification-only email ("new home practice
   ready") → authenticated open; watermark + short-TTL playback treatment for hosted media;
   "this link is tied to your account" reassurance copy.

---

## 6. Out of scope (v1) & open questions

**Out of scope:** cross-practice/marketplace resource sharing; affiliate-revenue mechanics
(link-out pays provider directly, full stop); any child login or child-facing gamification;
in-app payment/checkout; automatic resource recommendation (curation stays clinician-led,
provenance = clinician).

**Open questions (confirm with design partner):**
1. Max custom-clip length and consent wording (teardown §5 Q4) — assume ~15s until confirmed.
2. Should home-practice tick-off support a light parent free-text note back to the clinician,
   or done/not-done only, in v1?
3. Review-date semantics: auto-align to next session date vs manual?
4. School scope granularity (per-client vs per-setting) — owned by DEV-108; confirm the model
   this hub renders against.

---

## 7. Cross-references

- Licensing guardrails: **DEV-100** · `docs/compliance/instrument-licensing-guardrails.md`
- Data model (Resource + HomeworkAssignment, generic tagging): **DEV-101**
- School-scoped access: **DEV-108**
- Carryover source signals: `docs/research/assessment-forms-teardown.md` §2.4 (Target Setting
  School/Home carryover), §2.6 (session-feedback video-clip references)
- Product framing: `docs/mvp-brief.md` (carryover / roadmap #3), `docs/design/sona-care-journey-map.md` (stage 9)
- Repo guardrails: `AGENTS.md → Guardrails` (PHI safety, portal-only clinical artifacts)
