# Sona — Product Strategy & Differentiation Review: Research log

**Companion to:** `docs/strategy/product-strategy-review-brief.md`
**Branch:** `docs/product-strategy-review-brief`
**Run:** 2026-05-28, agent model: Claude Opus 4.7 (Cursor cloud agent)

The Notion page produced from this run is the primary deliverable. This log is the
underlying working file: sources consulted, decisions taken without founder input,
and gaps that the analysis could not close.

---

## 1. Notion page

- **Title:** Sona — Product Strategy & Differentiation Review (May 2026)
- **Parent database:** Document Hub
  (`https://www.notion.so/345c6894396e8074926bffca1ae0e7e3`)
- **Data source:** `collection://345c6894-396e-8037-92e6-000b2988579e`
- **Category (multi-select):** `Strategy doc`, `Market Research`
- **Icon:** 🧭
- **Created page URL:** https://www.notion.so/36ec6894396e813e8abec00a8f1de755
- **Page ID:** `36ec6894-396e-813e-8abe-c00a8f1de755`

A small post-publish fix-up was needed: two rows in the Q1 audit table contained
literal `|` characters inside cells (the "Breathe | Speak | Be" tagline and the
four-way triage enum). Notion's Markdown table parser ate those as column
separators, mis-aligning two rows on first publish. They were corrected in-place
using `notion-update-page` with `content_updates` against the underlying
`<table>` / `<tr>` / `<td>` block representation. The final page reads cleanly.

---

## 2. Repo inputs read in order

| # | Input | Path | Note |
|---|---|---|---|
| 1 | MVP brief v0.1 | `docs/mvp-brief.md` | Source of truth for the 8-step intake scope, Monal interview, "periphery before clinical core", solo-practitioner default. |
| 2 | Feedback-demo brief | `docs/marketing/feedback-demo-brief.md` | "Real today vs 90-day vision" split. Banned-words list for clinician-facing copy. |
| 3 | Intake form spec | `docs/intake-form-spec.md` | The 8-page Speech-Sanctuary-branded parent form. Single biggest one-customer-tailoring surface — every field audited in Q1. |
| 4 | Triage capture design | `docs/ml/triage-capture.md` | Four triage outcomes: `strategy_only / short_block / full_assessment / refer_out`. Confirms paediatric framing in the prompt. |
| 5 | Session plan design | `docs/ml/session-plan.md` | Zod schema with `domain ∈ {speech_sound, language, social_comm, fluency, voice, feeding, other}`. EHCP flag is binary. |
| 6 | Summary generator design | `docs/ml/summary-generator.md` | Tone slider, reading level, mandatory AI disclosure footer as `z.literal`. |
| 7 | ADR-001 jurisdiction stacks | `docs/decisions/001-data-residency-jurisdiction-stacks.md` | UK and US Postgres are physically separated. |
| 8 | ADR-002 Flutter + GenUI | `docs/decisions/002-flutter-genui-client.md` | A2UI transport, no Firebase AI Logic. |
| 9 | ADR-003 self-hosted LLM | `docs/decisions/003-self-hosted-llm-air-gap.md` | Gemma 3 27B INT4 on L4 in `europe-west2`. |
| 10 | ADR-004 unified envs | `docs/decisions/004-unified-environments-access.md` | No standing developer access in prod. |
| 11 | ADR-005 portal-first comms | `docs/decisions/005-portal-first-patient-communications.md` | Postmark would not sign BAA → portal-first. |
| 12 | Personas | `scripts/personas/{aria,jaden,mia,theo}.json` | Range: 3y feeding → 11y social comm. **No adult voice, adult stutter, AAC, dysphagia, transgender voice cases.** |
| 13 | Architecture | `docs/architecture-gcp-hipaa.md` | UK = `europe-west2`, US = `us-central1`, no global database. |
| 14 | Flutter intake screen | `apps/sona/lib/features/parent/intake/parent_intake_step_screen.dart` | 8 hard-coded steps. Intake is **not** schema-driven today. |
| 15 | Intake context service | `apps/api/src/services/intake-context.ts` | Loads the raw `answers` JSONB blob; no per-tenant template engine. |

`docs/ml/prep-brief.md` is referenced in the brief but **does not exist** in the repo
(only `triage-capture.md`, `session-plan.md`, and `summary-generator.md` are present
under `docs/ml/`). The prep brief shape is described inline in `triage-capture.md`.

---

## 3. Web sources

All retrieved on **2026-05-28** unless noted.

### Competitor pricing and positioning

| Source | URL | Access date | Takeaway |
|---|---|---|---|
| Heidi Health Clinician plan | `https://www.veroscribe.com/blog/heidi-health-review-2026` | 2026-05-28 | Heidi Clinician = **$150 / user / month** billed annually ($1,800/yr); rebrand from $99 Pro in early 2026; BAA available; SLT assessment template exists. |
| Heidi Health pricing — second source | `https://www.deepcura.com/resources/heidi-health-review` | 2026-05-28 | Confirms $150/user/mo Clinician; 110+ languages; BAA at Enterprise tier. |
| Heidi SLT assessment template | `https://www.heidihealth.com/templates/review-speech-pathology-assessment-f07500a5` | 2026-05-28 | Confirms allied-health template marketing — generic SOAP-style. |
| Jane App AI Scribe | `https://jane.app/features/charting-ai-scribe` | 2026-05-28 | **$15 / practitioner / month** unlimited, plus free 5-notes/mo tier. **US + CA only — NOT available in UK.** HIPAA + PIPEDA + PHIPA. SLP sample prompts published. |
| Jane App AI Scribe guide | `https://jane.app/guide/ai-scribe` | 2026-05-28 | Confirms availability gate and recording-based workflow. |
| Cliniko connected apps + AI | `https://www.wisevu.com/blog/cliniko-review-everything-medical-practices-need-to-know-features-pricing-api/` | 2026-05-28 | Cliniko has **no native AI scribe**; integrates with PatientNotes, CliniScribe, CliniScripts, Heidi, Clindoc, Clinic Notes AI, Evie Assist. Form intake via Finger-Ink and Snapforms or PDF upload. |
| Cliniko form upload (image/PDF) | `https://help.cliniko.com/en/articles/9940690-upload-your-own-patient-form-templates` | 2026-05-28 | Cliniko's image-recognition form import maps connected questions to patient profile. Direct evidence that Cliniko *is* moving into adaptive intake territory. |
| Clindoc UK AI scribe | `https://clindoc.ai/pricing` | 2026-05-28 | **£40 / user / month** annual or **£5 / active day**; HIPAA + GDPR; UK-friendly GBP billing. Direct UK competitor on price. |
| PatientNotes (Cliniko/Power Diary integration) | `https://www.patientnotes.app/professions/speech-therapist-st` | 2026-05-28 | **US$19** Essential / **US$49** Professional per practitioner / month; integrates with Cliniko + Power Diary; markets to SLT. |
| Octopus EPR (OEPR) | `https://oepr.co.uk/` | 2026-05-28 | UK SaaS **designed by SLTs for SLTs** — casenotes, **TOMs scores**, RISK tracking, programmes, discharge letters. The most clinically aware UK SLT-specific competitor surfaced in this run. Based in Leeds; markets via ASLTIP events. **Public pricing not posted.** |
| Smilenotes UK | `https://smilenotes.co.uk/profession/speech-therapy-software` | 2026-05-28 | UK PMS for SLT from **£5 / month**, UK-based servers, no AI scribe, basic templates. |
| sprypt.com SLT AI tools guide | `https://www.sprypt.com/blog/speech-therapy-ai-tools` | 2026-05-28 | Treat as marketing for SPRY itself — they target US PT/SLP rehab clinics with EMR + scribe in one. Adjacent, not direct UK. |
| Chatter Labs SLT private-practice AI | `https://chatter-labs.com/blog/slt-private-practice-setup-tips/ai-speech-therapy/` | 2026-05-28 | Reference list of SLT-adjacent tools (Ogma Therapy, IEP Copilot, Constant Therapy, Better Speech "Jessica"). Confirms there is no dominant SLT-specific AI scribe. |
| Jane App practitioner-workflows blog | `https://jane.app/blog/clinical-notes-and-ai-how-practitioners-across-disciplines-are-using-jane-s-ai-scribe` | 2026-05-28 | Real CASLPO-registered Canadian SLP using Jane AI Scribe + Global Prompt — useful framing for "what an SLT actually wants from AI documentation". |

### Regulators and frameworks

| Source | URL | Access date | Takeaway |
|---|---|---|---|
| NHS GP Connect prereqs (NHS Digital) | `https://digital.nhs.uk/developer/api-catalogue/gp-connect-access-record-structured-fhir` | 2026-05-28 | **Prereqs:** DSPT Standards Met + HSCN access + PDS compliance + IG model compliance + use-case approval + SCAL evidence + RBAC. FHIR UK Core built on **FHIR R3**, not R4. |
| GP Connect consumer assurance | `https://github.com/nhsconnect/gpc-consumer-support/wiki/Assurance-Process-Overview` | 2026-05-28 | SCAL + multi-Gate testing process; use-case approval valid 6 months. Confirms onboarding is multi-month even after prereqs are met. |
| NHS Standards Directory — DSPT | `https://standards.nhs.uk/published-standards/data-security-and-protection-toolkit` | 2026-05-28 | DSPT is mandatory for anyone with access to NHS patient data; aligns with NCSC CAF from Sep 2024 for large orgs; small orgs use the NDG-10 framework. |
| DSPT 2025/26 guide (independent providers) | `https://dsptready.co.uk/blog/dspt-complete-guide/` | 2026-05-28 | A **Category 3** small independent provider can complete DSPT as a **self-assessment with no independent audit required**. Deadline **30 June 2026** for Version 8. Achievable for a 2-person team. |
| Evalian DSPT guide | `https://evalian.co.uk/the-data-security-and-protection-toolkit-dspt/` | 2026-05-28 | Confirms category proportionality and that Caldicott Guardian is encouraged but not required for independent sector. |
| ASLTIP about + members | `https://asltip.com/` and `https://asltip.com/why-join/` | 2026-05-28 | **1,800+ UK private SLTs in ASLTIP**, joining £157.50, annual £115.50. This is the realistic upper bound on the UK private-SLT TAM for B2B GTM. |

### Sources I deliberately did **not** rely on

- Sprypt's "AI improves outcomes by 35%" type statistics — found in
  `https://www.sprypt.com/blog/speech-therapy-ai-tools`, treated as vendor-marketing
  numbers without primary citation and not used.
- Heidi pricing aggregators that disagreed with each other (one site still quoted
  $99 Pro, another quoted $150 Clinician). Used the **Vero** and **DeepCura**
  sources that both explicitly cover the early-2026 rebrand. Even-numbered double
  source increases confidence in the $150 figure.
- Crunchbase / Pitchbook free profiles — not consulted in this run because the
  pricing pages and public docs already gave enough granularity for the comparison
  table. Documented here so the founder knows where to push for funding-stage
  detail in a follow-up.

---

## 4. Decisions taken without founder input (defaults from §11 of the brief)

All ten §11 questions were answered using the documented defaults, because the
agent runs autonomously and waiting for confirmation would block the deliverable.

| # | Question | Default chosen | Rationale |
|---|---|---|---|
| 1 | Notion parent | Document Hub data source `345c6894-396e-8037-92e6-000b2988579e`; Category = `Strategy doc` + `Market Research` | Only data source on the database; existing tag taxonomy includes "Strategy doc". |
| 2 | Audience weight | Founders primary, investor secondary | As §2 of the brief specifies (revised post-publish to drop named individuals; the original §2 wording was *Senthil primary, Monal secondary, investor tertiary*). |
| 3 | Geography | UK-first; US/AU/CA in future-proofing and integration sections only | Matches design partner and personas. |
| 4 | Competitor list | The brief's list **plus** Octopus EPR, Smilenotes UK, Clindoc, PatientNotes | Added because they are direct UK or directly-Cliniko-integrated SLT-aware tools surfaced in the web search. |
| 5 | Moat stress-test | All candidates ranked honestly; air-gapped Gemma scored as **medium-low defensibility, short half-life** | The brief explicitly invites this. |
| 6 | Pricing anchor | No anchor; analysed from cost + comparable benchmarks (£5–£150/clinician/mo range) | Honest baseline given the UK private SLT economics. |
| 7 | Integration appetite | Year 1 = adjacent (calendar/video/payments/PMS); Year 2 = NHS DSPT + GP Connect | Default phasing in the brief. |
| 8 | Tone | Sober consultancy memo with one-line punchy summaries | Default. |
| 9 | Confidentiality | Internal-only assumed; no self-censoring of strategy critique | Default. |
| 10 | Deadline | None; treated as a one-working-session deliverable | Default. |

---

## 5. Gaps the analysis could not close

These need founder input or future primary research.

1. **Therapist sample of N=1.** All of Q1 is inferred from the intake spec, the
   `mvp-brief.md` interview synthesis, and the four paediatric personas. A second
   private SLT review (especially adult voice or AAC-shaped) would flip several
   "this generalises fine" calls into hard "needs a template" calls.
2. **Octopus EPR pricing.** No public price on `oepr.co.uk`. To compare on a
   per-clinician-per-month basis, someone needs to request a demo and price.
3. **UK private SLT willingness-to-pay benchmarks.** ASLTIP-internal pricing
   surveys (if they exist) are not on the public web. The £49 / £99 / £149 ladder
   in the brief is reasoned from comparable-tool benchmarks, not from observed
   private-SLT spend on software.
4. **NHS commissioning path costs.** G-Cloud 14 listing fee is small (~£) but the
   real cost is the buyer-side procurement-cycle drag (typically 3–9 months ICB
   procurement). No specific G-Cloud 14 SLT-tool data point found in this run.
5. **Inference cost per case.** ADR-003 commits to L4 INT4 in `uk/dev`. No
   per-case £ figure exists in the repo. The Q5 unit-economics section is
   directional only, with a back-of-envelope assumption explained inline.
6. **DCB0129 / DCB0160 clinical-safety lift.** GP Connect prereqs mention a
   Clinical Safety Officer compliant with these standards. Time-and-cost of
   appointing a CSO for a 2-person company is not researched here — it is the
   single biggest hidden cost of the GP Connect path and the founder should price
   it before committing.
7. **Multi-tenant clinic-mode breakage points.** The MVP brief states
   "solo-practitioner first". The analysis flags clinic mode as a future seam but
   does not enumerate the schema-level changes in `apps/api/src/db/schema.ts` —
   that requires a separate sweep with the engineer that owns the schema.

---

## 6. Run summary (also appears as §16 of the brief)

| Field | Value |
|---|---|
| Date | 2026-05-28 |
| Agent model | Claude Opus 4.7 (Cursor cloud agent) |
| Branch | `docs/product-strategy-review-brief` |
| Notion page URL | https://www.notion.so/36ec6894396e813e8abec00a8f1de755 |
| Research log path | `docs/strategy/product-strategy-review-research-log.md` |
| Key delta vs original brief | Added Octopus EPR, Smilenotes, Clindoc, PatientNotes to the competitor sweep — the brief named only the more general players. |
| Key delta vs original brief | All §11 questions answered with documented defaults rather than batched-to-user, because cloud-agent autonomous mode. |
| Key delta vs original brief | `docs/ml/prep-brief.md` is referenced in §3 of the brief but does not exist; analysis used `triage-capture.md` which contains the prep-brief shape. |

---

## 7. Published Notion page URL

- **URL:** https://www.notion.so/36ec6894396e813e8abec00a8f1de755
- **Title:** Sona — Product Strategy & Differentiation Review (May 2026)
- **Parent database:** Document Hub (`345c6894396e8074926bffca1ae0e7e3`)
- **Category tags:** `Strategy doc`, `Market Research`
- **Icon:** 🧭
