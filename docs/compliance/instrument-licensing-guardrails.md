# Sona — Instrument Licensing Guardrails

*Compliance policy for how Sona handles copyrighted/licensed assessment instruments in the
v1 assessment→report cycle. Sona stores the **SLT's own captured data** and **their uploaded
completed document**; it never redistributes the blank instrument, its norm/lookup tables, or
its stimuli, and it never auto-computes a scaled score or percentile from a raw score.*

**Linear:** DEV-100 · **Date:** 2026-07-01 · **Status:** Draft → In Review (pending legal review)
· **Scope:** policy/structure only — **no PII, no reproduced publisher content** in this doc.
· **Owner:** Data Protection lead (practice admin), with legal-lane items routed to the human/legal reviewer.

---

## 1. Purpose & the bright line (v1 stance)

Sona v1 is deliberately **"upload the completed form"**, not **"digitise CELF"** (or any other
publisher instrument). The reason is the licensing constraint set out in the DEV-99 teardown
§1: the raw→scaled→percentile **norm/conversion tables** *are* the commercial IP of a
norm-referenced instrument, and hosting or computing from them would embed the publisher's
copyrighted norms in our product.

**The bright line — read this as the load-bearing rule of this whole document:**

> Sona stores (a) **the clinician's own captured clinical data** — the values *she* produced —
> and (b) **the document she uploaded** (her purchased, completed form). Sona **never** hosts,
> embeds, ships, redistributes, or computes from a **blank instrument**, its **norm/lookup/
> conversion tables**, or its **stimulus material**; and Sona **never** builds an "auto-score"
> feature that derives a scaled score / index / percentile from a raw score.

What this means concretely, restated as four commitments:

| # | Commitment | Rationale |
|---|---|---|
| 1 | **Never redistribute the blank instrument.** We model the *data* a form captures, never reproduce the form layout, stimulus book, or picture plates. | The blank form / stimulus is publisher IP. |
| 2 | **Never host, embed, ship, or compute from a norm/lookup table.** No raw→scaled, index/composite, or percentile conversion table lives in Sona code, data, config, or model prompt. | Appendices A/B/D (and their equivalents) are the instrument's commercial IP. |
| 3 | **Never auto-score.** No feature maps a raw score to a scaled score/percentile internally. The clinician scores **manually** off the publisher's own tables and enters/uploads the finished value. | Auto-scoring = re-implementing the licensed norm table. |
| 4 | **Store only clinician-produced values + the uploaded document.** Every score field has **provenance = clinician**, never `computed`. Sona removes the *re-keying*, not the *scoring*. | Keeps Sona on the "captured data" side of the line. |

**The two-sides-of-a-line distinction (the mental model for the rest of this doc):**

| The clinician's captured data (ours to store) | Licensed instrument IP (never ours to host) |
|---|---|
| Raw scores she recorded; scaled scores / percentiles / composites **she derived manually**; verbatim child responses she transcribed; her qualitative analysis and banding | The blank record form / stimulus book / picture plates; the raw→scaled→percentile **conversion appendices**; any publisher-authored scoring logic |
| Her **uploaded completed copy** of a form she purchased (her clinical record on a licensed surface) | The **blank** form as a redistributable template; the norm tables printed in the scoring manual |

This generalises across **every** norm-referenced instrument in the landscape report
(`docs/research/SLT_SLP_Assessment_Landscape.md` §3), not just CELF. Free/criterion tools are
carved out below (§3b) via a per-instrument flag, so the rule is a **data attribute**, not a
special case.

---

## 2. Per-provider constraints

Providers in scope for v1. Facts drawn from the landscape report §2.2 (qualification levels)
and §6 (publishers); **price/edition facts are approximate** — the landscape report itself flags
that publisher pricing is gated and was not fetch-verified, so treat every figure below as
"approximate / to confirm" and never as a compliance input.

### 2a. Constraints table

| Provider | Instruments (in scope) | May store | May **not** store / host / reproduce | Qualification gate (approx.) |
|---|---|---|---|---|
| **Pearson** (Pearson Clinical UK / Assessments) | CELF-5 (& CELF-5 UK), CELF Preschool-3, PLS-5, GFTA-3 / KLPA-3, BPVS3, TROG-2, DEAP, RAPT*, WAB-R, Bayley-4, RBANS, CLQT+, FDA-2 (UK) | The clinician's **captured values** (raw/scaled/percentile/composite she derived, verbatim responses, qualitative analysis) and her **uploaded completed record form** | The **blank record form** as a redistributable template; **stimulus books / picture plates**; **scoring-manual conversion appendices** (raw→scaled, core/index, percentile); any **auto-score** derivation | Level B — **HCPC registration generally satisfies** the UK requirement (A/B/C in the US) |
| **Black Sheep Press** | Narrative / language / vocabulary **therapy & activity resources** (not norm-referenced tests) | The clinician's own notes/targets referencing a resource; a **purchase/attribution link**; nothing more | The **resource content itself** (worksheets, picture sets, printable packs) redistributed to parents/schools via Sona; any copy shared outside the purchaser's licence terms | Open purchase (not clinical-restricted); **licence governs redistribution**, not who may buy |
| **Twinkl** | Subscription teaching/therapy printables & activity packs | Reference/attribution + a link for the clinician to obtain under **their own Twinkl subscription** | The **downloaded printables/packs** re-hosted or forwarded through Sona to parents/schools (Twinkl licence is per-subscriber and restricts redistribution) | Subscription-gated; **per-subscriber licence** controls sharing |
| **Noala** | Digital SLT activities / carryover content (partner/third-party) | Reference/link; integration metadata if a partnership exists | Their content **re-hosted or redistributed** by Sona without an explicit content agreement | Per Noala's terms — **confirm any partnership/API terms in the legal lane** |

\* RAPT is distributed by Routledge/Speechmark per the landscape report §6, but is grouped here
because it is a norm-referenced Pearson-family instrument in common UK use; the **distributor
split does not change the rule** — same "captured data vs. instrument IP" line applies.

### 2b. Does a clinician uploading a completed copy of their **own purchased** form change anything?

This is the crux question, so it is answered explicitly.

- **What does not change:** Sona still **never** reproduces the blank instrument, the stimulus,
  or the norm tables, and still **never** auto-scores. Uploading a completed CELF record form
  does **not** give Sona a licence to host CELF's conversion appendices or to regenerate the
  blank form for other users.
- **What the upload *is*:** the completed form is the **clinician's own clinical record**,
  written by her onto a surface she lawfully purchased. The **values she wrote** (raw scores,
  her manually-derived scaled scores/percentiles, verbatim responses, observations) are **her
  captured clinical data** — Sona extracts and stores those (via upload + Gemini extraction +
  clinician verification), exactly as the DEV-99 teardown §3 describes.
- **The residual (route to legal, §5):** the uploaded file is a *single copy of a purchased,
  copyrighted artifact* stored for the purchaser's own record-keeping. Whether each publisher's
  licence permits **storing a completed copy of a purchased form** in a third-party system is a
  **per-licence question** we do not assume our way past — it is an open legal item, and it is
  why the upload is treated as **PHI + copyright** with the handling controls in §4.
- **Design consequence:** we capture and model the **data**, not the **form**. The extracted,
  clinician-confirmed values are first-class records; the uploaded file is retained under the
  §4 controls as the provenance source, access-controlled and never redistributed.

---

## 3. Product guardrails derived from the above

### 3a. Licence / attribution check at upload

At the point a clinician uploads a completed assessment, Sona presents a short **licence /
attribution check** before extraction proceeds:

1. **"Which instrument is this?"** — the clinician selects/confirms the instrument from the
   catalogue (which carries the `licensed / self-scored` flag, §3b).
2. **"Do you hold a licence / are you qualified to administer it?"** — an attestation the
   clinician confirms (mirrors the publisher qualification gate; for UK SLTs, HCPC registration
   generally satisfies Level B per §2). This is an attestation, **not** a licence Sona grants.
3. On confirm, extraction captures **only the clinician-authored values** (raw/scaled/percentile/
   verbatim/qualitative). The check is recorded in the audit log (which instrument, that the
   attestation was made, by whom, when) — **without** logging the instrument's content (§4).

This makes the licence relationship explicit and auditable, and keeps Sona in the position of
capturing *her* data on *her* licensed instrument — never re-selling or granting access to the
instrument itself.

### 3b. The `licensed / self-scored` instrument flag

Each instrument in the catalogue carries a boolean-style flag that drives behaviour:

| Flag value | Meaning | Norm-table restriction (§1) | Examples |
|---|---|---|---|
| **`licensed`** | Norm-referenced, publisher-copyright; scored manually off the publisher's own tables | **Applies in full** — no hosted norm table, no auto-score, provenance = clinician | CELF-5 (UK), PLS-5, GFTA-3, BPVS3, RAPT, WAB-R, and every NR instrument in landscape §3 |
| **`self-scored`** (free / criterion) | Free or criterion-referenced; no proprietary raw→scaled norm table to protect | **Exempt** from the norm-table restriction (still PHI; still clinician-in-the-loop) | Communication Matrix, DAGG-3, CAPE-V, EAT-10, ASQ |

How the distinction is modelled:

- The flag is an **instrument-catalogue attribute**, not per-upload logic — so "free vs
  licensed" is data, and adding a new instrument is a catalogue entry, not a code branch.
- For `licensed` instruments, all score fields are **captured inputs with provenance =
  clinician** (never a computed field) — enforced at the data-model layer (DEV-101/109).
- For `self-scored` tools, Sona **may** legitimately model the criterion structure (levels/
  checklists) since there is no proprietary norm conversion — but it still never adds an
  auto-score behaviour that the tool itself does not define, and still keeps the clinician in
  the loop.
- The flag also gates the resource-hub behaviour (§3c) and the upload check copy (§3a).

### 3c. Resource-hub rule

For the roadmap resource hub (mvp-brief roadmap item 3) and any carryover material:

- Sona provides **purchase / attribution links** and directs clinicians (and parents/schools,
  where relevant) to **pay the provider directly** under their own licence/subscription.
- Sona **does not redistribute** purchased or copyright resources (Black Sheep Press packs,
  Twinkl printables, Noala content, publisher stimulus) through the platform.
- Any affiliate/partner arrangement is **link-out only** unless a **content-redistribution
  agreement** with that provider is signed and recorded (route via §5 / subprocessor +
  contract process). Absent that agreement, the default is **link, don't host**.

---

## 4. Handling of uploaded copyrighted documents

An uploaded completed assessment is treated as **both PHI and copyright** — the strictest
overlap of both regimes applies. It inherits the mvp-brief privacy stack and the DPIA controls,
with these specifics:

| Concern | Control |
|---|---|
| **Classification** | Uploaded completed forms are **special-category PHI** (child health data) **and** third-party **copyright**. Handle under UK GDPR / DPA 2018 with the HIPAA-aligned GCP controls (per AGENTS.md). |
| **Storage & residency** | Stored only in the authenticated app / **GCS in `europe-west2`** for UK tenants; **UK data residency**, no cross-jurisdiction processing (ADR-001). Encrypted at rest (CMEK) and in transit. |
| **Access control** | Access limited to the owning clinician/practice tenant via RBAC (`requireIdentity → requireUser → requireRole`). No cross-tenant access; not exposed to parents/schools. Every access recorded in the append-only audit log. |
| **No content logging** | The **document's content is never written to logs** (the logger allowlists fields; PHI/clinical content stays out of Cloud Logging). The audit log records *that* an upload/extraction happened and *which instrument*, never the extracted content or images. |
| **Extraction path** | Extraction runs via the enterprise **Vertex AI (Gemini)** processor with no-training, Zero Data Retention, EU/UK residency (ADR-007); prompts are data-minimised (DEV-53). The instrument's norm tables are **never** placed in a prompt or used to compute a score. |
| **Retention & deletion** | The uploaded file is retained as the provenance source under the practice's retention schedule and is included in **DSAR / right-to-erasure** flows (`docs/compliance/dsar-runbook.md`). On erasure, the uploaded document is deleted alongside the derived record. |
| **Redistribution** | The uploaded document is **never** re-served to other users, forwarded by email (email is notification-only, ADR-005), or used as a template for other tenants. It is the purchaser's own copy, for the purchaser's own record. |

---

## 5. Open legal questions (route to the human / legal lane)

These are **not** for an agent to resolve; they require the human/legal reviewer and, where
noted, direct confirmation from the publisher. Until resolved, the conservative §1 bright line
and §4 controls hold.

1. **Storing a completed copy of a purchased form.** For **each** provider (Pearson, Black Sheep
   Press, Twinkl, Noala), does the licence permit the purchaser to store a **completed** copy of
   a form they bought inside a third-party SaaS (Sona)? Confirm per-licence; do not assume.
2. **Pearson digitisation / Q-global terms.** Confirm Pearson's exact terms on digitising or
   uploading completed record forms, and whether any Q-global / Q-interactive terms bear on
   capturing values from a paper form administered offline.
3. **Black Sheep Press licence scope.** Confirm redistribution terms for their resources and
   whether *referencing* (vs. hosting) a resource in a clinician's notes is unrestricted.
4. **Twinkl subscriber licence.** Confirm the per-subscriber redistribution limits before any
   feature surfaces Twinkl content to parents/schools.
5. **Noala partnership terms.** Confirm whether any content-integration/API agreement exists or
   is needed before referencing or embedding Noala content.
6. **Attestation sufficiency.** Confirm the upload-time qualification attestation (§3a) is
   sufficient for our position, or whether stronger licence verification is required per provider.
7. **"Captured data vs. instrument IP" boundary review.** Have legal confirm the §1 two-sides
   table holds for each norm-referenced instrument family we onboard (the line is asserted from
   the DEV-99 teardown; it should be legally affirmed, not just engineering-asserted).

Any facts in §2 marked approximate (prices, editions, exact qualification levels) must be
confirmed against the live publisher pages before they inform a decision — per the landscape
report's own sourcing caveat.

---

## 6. Cross-references

- **DEV-99 teardown §1** — the load-bearing norm-table constraint and the captured-data vs.
  licensed-IP line: `docs/research/assessment-forms-teardown.md` (§1, and §3 for the CELF
  capture surface / record-form-vs-appendix split). This doc is the DEV-100 codification of that
  constraint.
- **AGENTS.md → Guardrails (do not violate)** — the *Licensed instruments (do not host norm
  tables)* bullet: never host/embed/ship/compute from a licensed conversion table; no auto-score;
  provenance = clinician; per-instrument `licensed / self-scored` flag.
- **ADR-007** — managed Vertex AI Gemini inference with no-training / Zero Data Retention / UK
  residency; the extraction path (§4) runs under its mandatory safeguards:
  `docs/decisions/007-vertex-gemini-managed-inference.md`.
- **Landscape report** — instrument breadth, free-vs-licensed split, qualification levels (§2.2),
  publishers (§6): `docs/research/SLT_SLP_Assessment_Landscape.md`.
- **Supporting compliance** — `docs/compliance/dpia-v1.md`, `docs/compliance/dsar-runbook.md`,
  `docs/compliance/subprocessors.md`, `docs/compliance/audit-retention.md`.
- **Data model / extraction / report engine** — DEV-101/109 (data model, provenance),
  DEV-102/104 (extraction), DEV-105 (report engine, no auto-score).
