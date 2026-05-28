# Sona — Product Strategy, Differentiation & Generalizability Review: Agent Brief

> **For:** an Opus 4.7 agent running in this Cursor workspace, with the **user-notion** and **user-google-developer-knowledge** MCP servers enabled, and web search available.
> **Goal:** Produce a single, founder-grade **strategy review** of the Sona MVP that answers the hard questions a non-technical reviewer would ask after watching the demo deck and video — and publish it as a structured page in the team's Notion document hub.
> **Output is strategy advice, not code.** No files in `apps/`, `infra/`, or `e2e/` should change.

---

## 1. Mission

The MVP demo (`assets/marketing/`, brief: `docs/marketing/feedback-demo-brief.md`) is convincing for **one** speech therapist (Monal Gajjar — UK private-practice SLT, the design partner). That has surfaced the next-order questions the founder needs answered before pitching to a second therapist, an NHS commissioner, or an investor:

1. **Single-customer fit risk.** The product was scoped from one interview with one clinician. Will a different SLT walk into the demo, see Speech-Sanctuary-shaped flows, and immediately discount Sona? Where exactly does the "one-therapist tailoring" leak through — intake fields, plan templates, vocabulary, branding, workflow assumptions?
2. **Unique selling point.** In a sentence and in a paragraph, why would an SLT buy Sona instead of (a) staying with ChatGPT + Cliniko, (b) using a generic AI scribe like Heidi/Nabla/Suki, or (c) waiting for their existing PMS (Cliniko, Jane App, Power Diary, WriteUpp) to ship AI features? What is the **moat** — not the feature list?
3. **Generic & future-proof.** What architectural and product seams would let Sona serve adjacent segments (NHS SLTs, US/AU/CA private practice, paediatric vs adult SLT, AAC/voice/feeding/stutter sub-specialties, schools-based SLTs, charity providers) **without forking the product**?
4. **External-systems integration.** Sona currently asks the parent for GP details as free text. In reality that data lives in **NHS GP systems** (TPP SystmOne, EMIS Web, INPS Vision) reached via NHS Spine / GP Connect / FHIR UK Core, with NHS DSPT and CIS2 identity. What's the realistic integration roadmap, and the equivalent in other jurisdictions (US: USCDI/FHIR/EHR vendors; AU: My Health Record / FHIR AU Base)?
5. **Pricing & commercial model.** Per-clinician subscription vs per-case vs tiered AI-usage vs NHS framework procurement (G-Cloud, DPS, Spark DPS, ICB direct award).

The deliverable answers these in one place, with sourced reasoning, and is reviewable in a 30-minute founder reading session.

---

## 2. Audience for the Notion page

- **Primary:** the founders (technical; read strategy docs end-to-end).
- **Secondary:** a future investor / NHS commissioner — sections must be quotable in a pitch deck without rewriting.

The page must work for **both** audiences in one read. Use clear section headers, short paragraphs, tables where comparing options, and a TL;DR at the top.

---

## 3. Inputs available in this repo (read these first, in this order)

Do not skip. The credibility of the output depends on grounding the analysis in what actually exists.

| Order | Input | Path | Why it matters |
|---|---|---|---|
| 1 | MVP brief | `docs/mvp-brief.md` | Original positioning, scope, principles, roadmap, the Monal interview synthesis. Source of truth for "what we said we'd build." |
| 2 | Feedback-demo brief | `docs/marketing/feedback-demo-brief.md` | What was actually pitched in the demo (deck + video). Honesty constraints and the "real vs vision" split live here. |
| 3 | Demo deliverables | `assets/marketing/deck/slides-src/`, `assets/marketing/video/captions.json` | The exact words and visuals the reviewers will have just seen. Quote them sparingly when grounding gaps. |
| 4 | Intake form spec (original) | `docs/intake-form-spec.md` | The 8-page Speech-Sanctuary-branded parent form. Single biggest one-customer-tailoring surface. Read every field. |
| 5 | ML feature designs | `docs/ml/{triage-capture,session-plan,summary-generator,prep-brief}.md` | What the AI outputs look like (Zod schemas, tone controls, EHCP awareness). |
| 6 | Architecture & ADRs | `docs/architecture-gcp-hipaa.md`, `docs/architecture-review-gcp-2026.md`, `docs/decisions/00{1..5}-*.md` | UK/US data-residency split, Flutter+GenUI, self-hosted Gemma, unified envs, portal-first comms. |
| 7 | Personas | `scripts/personas/*.json` | Four UK paediatric cases. Range = 3y feeding → 11y social comm. Adult voice, adult stutter, AAC, dysphagia are **not** in the persona set. |
| 8 | Workspace rules | `AGENTS.md`, `.cursor/rules/*.mdc` | PHI rules, git PR workflow, no manual GCP deploys. Follow strictly when committing. |

Optional but useful for differentiation framing:

- `docs/DEMO.md` and `docs/DEMO-DATA-AND-LLM.md` for the "what runs where" picture.
- `infra/terraform/` headers for the air-gapped LLM posture (a real differentiator vs ChatGPT).

---

## 4. The five questions to answer

Address all five. Order in the Notion page is up to you, but the TL;DR must touch each one in one or two sentences.

### Q1 — Single-customer fit: where does Speech-Sanctuary leak through?

Audit the MVP for assumptions that came from one clinician and would be wrong for the next. Cover at minimum:

- **Parent intake form.** Compare `docs/intake-form-spec.md` field-by-field against what a generalist paediatric SLT would actually ask. Flag fields that are Speech-Sanctuary-specific copy, UK-specific (GP, EHCP, nursery SENCO), age-band-specific (0–11 child framing — no adult clients), or specialty-specific (no AAC, dysphagia, transgender voice, adult stutter intake variants).
- **Clinician workflow.** Triage outcomes (`strategy only / short block / full assessment / refer out`) — are these universal or Monal-shaped? Booking flow (20-min free consult) — assumes private practice, not NHS.
- **AI output shapes.** Session plan structure (goals / activities / home practice / materials / parent goals), parent-summary tone slider — do these generalise to adult voice therapy, AAC sessions, feeding clinics?
- **Vocabulary & branding.** "Parent" (not "carer" / "client" / "patient" / "family"), "consult" (not "appointment"), EHCP references, UK-only regulators (HCPC, RCSLT). What changes for US (ASHA, IEP, IDEA), AU (SPA), CA (SAC)?
- **Data model.** Schema and persona files — anything hard-coded for one practice?

Output: a table with columns `Surface | Assumption today | Who it fits | Who it breaks | Fix class (config / template / branch)`.

### Q2 — Unique selling point and moat

Produce:

- **One-sentence USP** (under 25 words).
- **One-paragraph positioning** suitable for a pitch deck.
- **Comparison table** of Sona vs the realistic alternatives an SLT actually evaluates:
  - ChatGPT / Gemini / Claude (free or paid) with a custom GPT.
  - Generic AI scribes pivoting to allied health: Heidi Health, Nabla, Suki, Abridge, Freed.
  - SLT-aware practice management: Cliniko, Jane App, Power Diary, WriteUpp, SimplePractice, TheraPlatform.
  - SLT-specific tools: Therapy Tools UK, Black Sheep Press, Twinkl SLT, Quick Articulation, plus any newer AI entrants (search the web — be specific, name companies and dates).
  - DIY (status quo: ChatGPT + Cliniko + email + Word templates).
  - Doing nothing.
  Columns: `Tool | What it does | What it costs | Where it wins | Where it loses for SLT intake→first-session loop | Why Sona is different`.
- **Moat analysis.** What is defensible about Sona over a 24-month horizon? Candidates to evaluate honestly (some are weak): UK-region air-gapped Gemma + HCPC-aware audit trail, the structured intake → triage → plan loop (not just a scribe), Speech-Sanctuary-quality clinical templates, RCSLT/EHCP-aware language, design-partner relationship, GenUI/A2UI client architecture, the parent-facing artifact quality. Rank them by defensibility and time-to-erosion.

### Q3 — Generic & future-proof architecture

Propose the seams that let Sona serve more segments without a fork. Concrete recommendations, not platitudes. For each, name the file/module that would change and the rough effort (S/M/L). Cover:

- **Intake template engine.** From hard-coded 8 steps to a versioned, brandable, conditionally-branching schema (JSON/DSL) authored per-practice. Reference any existing scaffolding in `apps/api/src/services/intake-context.ts` or `apps/sona/lib/features/parent/`.
- **Plan & summary template library.** Per-specialty (paediatric speech-sounds, adult voice, AAC intro, feeding, stutter, social comm) with the Zod schema becoming a family, not a single shape.
- **Vocabulary & locale pack.** "Parent/carer/family", "consult/appointment", regulator names, statutory frameworks (EHCP/IEP/NDIS), units, date formats.
- **Multi-jurisdiction (already partially designed).** ADR-001 splits UK/US Postgres. What's still missing for a real US/AU rollout (Stripe vs GoCardless, US BAA vs UK DPA, ASHA-aware language, USCDI fields)?
- **Multi-tenant clinic mode.** Sona is solo-practitioner-first today (`docs/mvp-brief.md` §"Working agreements"). When does multi-therapist become unavoidable, and what's the smallest change to support it?
- **Customisable branding.** White-label per practice — logo, colours on parent-facing artefacts, sender email/domain.

### Q4 — Integration with external systems (GP, NHS, US/AU equivalents)

The parent currently types GP details by hand. In production, structured GP data is the single most valuable enrichment for the triage brief.

For each integration, give: **what it unlocks**, **what it costs** (technical, certification, commercial), **prerequisites**, **realistic phasing** (MVP / Year 1 / Year 2+).

UK (priority):

- **NHS Login** for parent identity (vs magic link).
- **GP Connect** (HL7 FHIR UK Core) for read-only GP record access — requires NHS DSPT, Information Governance Toolkit, Spine connection via TPP/EMIS, end-user identity via NHS CIS2 or HSCN routing.
- **NHS e-Referral Service (e-RS)** if positioning for NHS-funded private referrals.
- **NHS DSPT** certification path itself — what's the realistic timeline for a 2-person company?
- **ICB / commissioning routes** — G-Cloud 14, Spark DPS, NHS Digital Marketplace, direct ICB award.

US (year 2+):

- **FHIR R4 + USCDI** as the lingua franca.
- **EHR connectors** — Epic App Orchard, Cerner CODE, Athena Marketplace, eClinicalWorks, ModMed for therapy clinics.
- **HIPAA BAA** with GCP (already partially in place per `docs/architecture-gcp-hipaa.md`).
- **IEP / IDEA** workflow if school-district market is in scope.

AU/CA (year 2+, briefer treatment):

- **My Health Record** + FHIR AU Base, SPA accreditation; CA: SAC, provincial PHIPA/PIPEDA.

Adjacent (lower-effort, high-value) integrations that aren't EHR but matter:

- Calendar (Google / Outlook / iCloud) round-trip for the 20-min consult.
- Video (Zoom, Whereby, Google Meet) — the consult itself is out-of-band today.
- E-sign (DocuSign, Dropbox Sign) for T&Cs / consent.
- Payments (Stripe, GoCardless) when invoicing lands on the roadmap.
- Existing PMS (Cliniko, Jane App) — "Sona for Cliniko" as a distribution wedge rather than a competitor.

### Q5 — Pricing & commercial model

Three to five options laid out side-by-side. For each: target segment, headline price, what's included, gross-margin sketch (Gemma inference is real cost — pull a back-of-envelope from `docs/architecture-gcp-hipaa.md` and `decisions/003-self-hosted-llm-air-gap.md`), and pros/cons.

Candidates to score:

- **Per-clinician monthly subscription** (e.g., £49 / £99 / £149/mo solo / small / clinic).
- **Per-case (intake → first session loop)** — pay only when a parent submits intake.
- **Freemium** with paid AI drafting after N cases/month.
- **NHS framework procurement** — different sales motion, different unit economics.
- **Per-practice flat with seat add-ons** — supports the multi-therapist roadmap.

End with a recommended starting model and the rationale.

---

## 5. Deliverable

### 5.1 The Notion page (primary)

Create **one** page (not a database row, not a collection of pages) in the Sona document hub at:

> `https://www.notion.so/345c6894396e8074926bffca1ae0e7e3?v=345c6894396e80378613000c3c40680d`

Steps:

1. Call `notion-fetch` on the database URL above to read the schema and discover the `data_source_id` (per `mcps/user-notion/tools/notion-fetch.json` and `notion-create-pages.json`). If the database has multiple data sources, choose the one whose schema matches a strategy / research document (not a tasks board).
2. If the database has required properties (e.g., Type, Status, Owner), fill them sensibly: Type ≈ "Strategy" or "Research", Status ≈ "Draft" or "In review", Owner ≈ Senthil.
3. **Page title:** `Sona — Product Strategy & Differentiation Review (May 2026)`.
4. **Icon:** `🧭`. **Cover:** none.

**Page structure** (use these as H1/H2 — adapt sub-structure as the analysis demands):

```
# TL;DR — answers in 60 seconds
  - 5–7 bullets, one per question (Q1–Q5) + one "what to do next week".
# Context
  - What the demo showed, who saw it, what questions came back. Link to the deck + video paths.
# Q1 — Where the one-therapist tailoring shows
  - Table (Surface / Assumption / Fits / Breaks / Fix class). Narrative around it.
# Q2 — Unique selling point and moat
  - One-sentence USP + one-paragraph positioning.
  - Competitive landscape table.
  - Moat ranking with time-to-erosion.
# Q3 — Generic & future-proof: the seams to add
  - For each seam: what it is, files involved, S/M/L, why now or why later.
# Q4 — External-systems integration roadmap
  - UK (priority) → US → AU/CA → adjacent (calendar/video/e-sign/payments/PMS).
  - Phased table (MVP / Year 1 / Year 2+).
# Q5 — Pricing options
  - Comparison table + recommended starting model.
# Recommendations — top 5 things to do in the next 30 / 60 / 90 days
  - Ordered, concrete, each with a one-line rationale.
# Open questions for the founder
  - Things this analysis couldn't resolve without input.
# Sources
  - Repo paths cited above.
  - Web sources (URL + access date) for any competitor, regulator, or integration claim.
```

Constraints on the Notion page:

- **No invented facts.** Every numeric or competitor claim needs a source — either a repo path or a URL with access date. Use web search for competitors, regulators, framework specs. The `user-google-developer-knowledge` MCP is good for GCP/FHIR specifics; the web is best for competitor pricing and NHS framework status.
- **UK-first frame** (matches design partner and current personas). US/AU/CA appear in the future-proofing and integration sections, not the headline.
- **Honesty about MVP gaps.** If something the strategy depends on isn't built yet, say so plainly. Reuse the "Real today vs 90-day vision" split from `docs/marketing/feedback-demo-brief.md` §6.
- **No tech jargon in the Q1, Q2, and recommendations sections** (those will be skimmed by Monal). Tech detail is fine in Q3–Q4 and the architecture footnotes.
- **No PHI, ever.** Personas only when illustrating.

### 5.2 The PR (this brief + a short research log)

This brief is already staged on branch `docs/product-strategy-review-brief`. Your job is to:

1. **Read every file in §3.** Do not skip.
2. **Run the analysis** and create the Notion page per §5.1.
3. **Add a research log** at `docs/strategy/product-strategy-review-research-log.md` covering:
   - The exact Notion page URL you created.
   - Web sources you consulted (URL, title, access date, one-line takeaway).
   - Decisions you had to make without founder input (and what you chose).
   - Gaps you couldn't fill (and why).
4. **Append a "Run summary" section to this brief** at the bottom, under a heading `## 16. Run summary (filled in by the agent)`, listing: date, agent model, Notion page URL, research log path, and any deltas vs the original brief.
5. **Commit & push** to the `docs/product-strategy-review-brief` branch, following `.cursor/skills/mvp-git-workflow/SKILL.md` (PR-only, never push to `main`).
6. **Open or update the PR** with title `docs(strategy): product strategy & differentiation review brief + run output` and the body template from the skill. Include the Notion page URL prominently in the PR description.
7. **Hand back to the user** with: PR URL, Notion page URL, a 4-bullet "what's in the analysis" summary, and the top three open questions you need answered.

---

## 6. Workflow

1. **Confirm scope in one batched message to the user** (see §11) **before** doing the analysis. Surface any assumption that would change the deliverable materially. Wait for confirmation; do not loop.
2. **Read inputs in order.** Take notes as you go in `docs/strategy/product-strategy-review-research-log.md` (this file is created by you).
3. **Search the web** for competitor pricing, NHS framework status, GP Connect / FHIR UK Core current state, ASHA / SPA / SAC equivalents. Save URLs + access dates.
4. **Draft the Notion page locally first** as Markdown in your research log, iterate, then publish via `notion-create-pages`.
5. **Publish to Notion.** If `notion-create-pages` fails (auth, schema mismatch), fall back to creating the page under your private workspace and noting the URL in the research log — never duplicate the page or pollute the database with placeholder rows.
6. **Update the brief** with §16 and commit.
7. **PR.**

---

## 7. Honesty & quality constraints (non-negotiable)

A founder will spot a generic, ChatGPT-flavoured strategy memo in 30 seconds. The credibility of this deliverable rests on:

- **Cite or strike.** Every competitor name, price, regulation, or framework claim has either a repo citation or a URL. No "industry experts say" hand-waving.
- **Specificity over completeness.** Better to deeply analyse five competitors than skim fifteen. Better to propose three sharp seams than ten vague ones.
- **Distinguish "is" from "should".** Q1 documents the MVP as-is. Q3 and recommendations are proposals. Don't blur them.
- **Disagree with the founder when warranted.** If the air-gapped Gemma is a weak moat, say so. If per-case pricing is wrong for this market, say so. Useful is more important than agreeable.
- **No vapourware in the moat.** Do not list features that are not built or designed as moats. Cross-check against `docs/marketing/feedback-demo-brief.md` §6 "What's real today vs the 90-day vision."

---

## 8. Constraints from this workspace's rules

- **Git workflow:** PR-only. Never commit or push to `main`. The branch `docs/product-strategy-review-brief` already exists. See `.cursor/rules/mvp-git-workflow.mdc` and `.cursor/skills/mvp-git-workflow/SKILL.md`.
- **No GCP deploys.** This is a documentation + Notion task. No `gcloud` commands. No infra changes. No app code changes.
- **PHI safety.** Personas only in any examples. Never invent or reuse real client details. See `.cursor/rules/mvp-security-reminder.mdc`.
- **No new vendors.** Notion (existing), GitHub (existing), Google search and the Google Developer Knowledge MCP (existing) are the only tools needed. Do not stand up new SaaS to produce this deliverable.
- **No tool name dropping in the Notion page.** Same banned-words list as `docs/marketing/feedback-demo-brief.md` §2: LLM, Gemma, Cloud Run, Drizzle, Hono, OTel, Cursor, Flutter, vLLM, INT4, embeddings — these may appear in Q3/Q4 footnotes labelled "engineering notes", never in Q1/Q2/recommendations.

---

## 9. Definition of done

- [ ] Every file listed in §3 has been read.
- [ ] All five questions in §4 are answered in the Notion page with cited reasoning.
- [ ] The Notion page exists at a URL under the document hub (`345c6894396e8074926bffca1ae0e7e3`), with title, icon, and structure per §5.1.
- [ ] `docs/strategy/product-strategy-review-research-log.md` exists, with sources, decisions, and gaps.
- [ ] This file (`docs/strategy/product-strategy-review-brief.md`) has a §16 "Run summary" appended.
- [ ] The PR is open against `main` from `docs/product-strategy-review-brief`, with the Notion URL in the description.
- [ ] No changes to `apps/`, `infra/`, `e2e/`, or `scripts/`.
- [ ] No PHI, no real client data, no fabricated sources.
- [ ] Final message to the user contains: PR URL, Notion URL, 4-bullet summary, top 3 open questions.

---

## 10. If you get stuck

- **Notion MCP fails or the database schema is unfamiliar.** Try `notion-fetch` on the database URL and inspect the data-source list and required properties. If the database is the wrong shape (e.g., a tasks board), search the user's workspace for a "Strategy", "Research", or "Docs" parent page and create the page underneath it instead — note this in the run summary.
- **Competitor data behind paywall or login.** Use Pitchbook-free signals: their pricing page, G2 reviews, Crunchbase free profile, press releases, podcast appearances. Always cite the URL and access date. If a number is uncertain, say "~£X (Crunchbase, May 2026)" rather than asserting it.
- **NHS / GP Connect specifics in flux.** Cite NHS Digital's own pages (digital.nhs.uk) over third-party blogs. If a programme has been renamed or merged (common in NHS), say so and link both names.
- **Founder hasn't answered §11 questions in a timely way.** Proceed with the documented defaults; flag every default-taken in the run summary so the founder can correct in review.
- **The analysis would exceed one Notion page comfortably.** Keep the published page tight (≤ 4000 words). Park supporting material — full competitor profiles, full integration spec sheets — as expandable toggles inside the page, not as separate pages.

---

## 11. Questions to batch to the user before starting (one message, with defaults)

1. **Notion parent.** Confirm the database at `345c6894396e8074926bffca1ae0e7e3` is the right place. (Default: yes, create the page as a row in that database; pick the data source whose schema fits a strategy doc.)
2. **Audience emphasis.** Founders + investor — equal weight, or weighted? (Default: founders primary, investor secondary — as written in §2.)
3. **Geography scope.** UK only, UK+US, or global? (Default: UK-first headline, US/AU/CA in future-proofing only.)
4. **Competitor list.** Anyone specific you already know is a real comparator? (Default: the list in Q2 — open to add/remove based on your input.)
5. **Moat candidates.** Any you specifically want stress-tested, or any you suspect are weaker than you've been telling people? (Default: rank all candidates honestly, including the air-gapped LLM posture.)
6. **Pricing — anchor.** Do you have a starting price hypothesis (e.g., £99/clinician/month)? (Default: no anchor; analyse from cost + comparable-tool benchmarks.)
7. **Integration appetite.** Is NHS DSPT / GP Connect on the table for the next 12 months, or strictly Year-2+? (Default: phased — Year 1 = adjacent integrations (calendar, video, payments); Year 2 = NHS DSPT + GP Connect.)
8. **Tone.** "Sober consultancy memo" vs "punchy founder voice" — pick one. (Default: sober consultancy memo with one-line punchy summaries.)
9. **Confidentiality.** Is this Notion page internal-only or shareable with prospective customers? (Default: internal-only; do not write anything that couldn't survive a screenshot leak, but do not self-censor strategy critique.)
10. **Deadline.** Anything time-sensitive driving when this needs to be merged + published? (Default: no hard deadline; aim for one working session.)

---

## 12. Worked example: how to handle Q1's intake-form audit

(Provided as a model for the level of specificity expected — apply the same depth to the other questions.)

Read `docs/intake-form-spec.md` page-by-page. For each field, classify it into one of:

- **Universal** — every paediatric SLT asks this (child name, DOB, main concern, difficulty checklist with speech-sound + language + attention categories).
- **UK-specific** — would not be asked in US/AU/CA in this form (GP details, EHCP, nursery SENCO, mother/father vs caregiver framing).
- **Practice-branded** — Speech Sanctuary copy that needs to become configurable (`Confidential Speech & Language Parent/Carer Questionnaire`, "Breathe | Speak | Be" tagline echoes, consent language).
- **Paediatric-only** — adult SLT clients (voice, fluency, post-stroke, head & neck cancer) would never see this form (school year, EHCP, parental consent framing).
- **Sub-specialty-thin** — works for speech-sounds + general language but is shallow for AAC users (no symbol-set / device questions), feeding (no food-texture log), or transgender voice clients (no goals framing for adult voice transition).

Output as a table per the format in §4 Q1. Then map each "Fix class" to a concrete proposal in Q3 (e.g., "intake template engine — JSON schema authored per practice + per specialty, branching by age band and presenting concern").

---

## 13. Web research starter list (not exhaustive — extend as you go)

- **AI scribes pivoting into allied health:** heidihealth.com, nabla.com, suki.ai, abridge.com, freed.ai. Look for pricing, BAA posture, allied-health beta programmes, UK availability.
- **SLT practice management:** cliniko.com, jane.app, powerdiary.com, writeupp.com, simplepractice.com, theraplatform.com. Look for AI features shipped or announced, intake-form capability, UK presence.
- **SLT-specific tools:** therapy-tools.uk, blacksheeppress.co.uk, twinkl.co.uk SLT pack, quickarticulation.com. Plus newer AI entrants — search "AI speech therapy private practice 2026" and "AI SLT clinical notes 2026".
- **UK regulators / frameworks:** rcslt.org, hcpc-uk.org, asltip.com, digital.nhs.uk (DSPT, GP Connect, e-Referral Service, NHS Login), nhsx.nhs.uk, england.nhs.uk (commissioning), gov.uk/digital-marketplace (G-Cloud).
- **US/AU/CA regulators:** asha.org, healthit.gov (USCDI), speechpathologyaustralia.org.au, sac-oac.ca.
- **Integration standards:** hl7.org/fhir, simplifier.net/HL7FHIRUKCorer4, hl7.org.au.

Always note URL + access date. Note when a page is dated (e.g., "GP Connect v1.6.0, retrieved 2026-05-27").

---

## 14. Anti-patterns (do not do these)

- A 30-page memo. Long ≠ rigorous. Target 3000–4000 words on the Notion page.
- A SWOT table as the headline output. SWOTs hide weak thinking.
- A competitor comparison where Sona wins every cell. Real analyses have losses.
- Recommendations without an owner, effort estimate, or success metric.
- Citing "industry reports" without naming and linking them.
- Quietly skipping a question because it's hard (especially Q4, the integration roadmap).
- Editing code or infrastructure to "fix" something noticed during the audit. File issues / tasks in the research log instead.

---

## 15. Final hand-off message template

When done, post in the chat (one message, no follow-up pings):

```
Done. Strategy review published.

- PR: <github-pr-url>
- Notion page: <notion-page-url>
- Research log: docs/strategy/product-strategy-review-research-log.md

What's in it (4 bullets):
1. <Q1 headline finding>
2. <Q2 USP + moat ranking>
3. <Q4 integration phasing>
4. <Q5 recommended pricing model + top recommendation>

Top 3 open questions for you:
1. <…>
2. <…>
3. <…>
```

---

## 16. Run summary (filled in by the agent)

| Field | Value |
|---|---|
| **Date** | 2026-05-28 |
| **Agent model** | Claude Opus 4.7 (Cursor cloud agent, autonomous run) |
| **Branch** | `docs/product-strategy-review-brief` |
| **Notion page URL** | https://www.notion.so/36ec6894396e813e8abec00a8f1de755 |
| **Notion page title** | Sona — Product Strategy & Differentiation Review (May 2026) |
| **Notion category tags** | `Strategy doc`, `Market Research` |
| **Research log** | `docs/strategy/product-strategy-review-research-log.md` |

### Deltas from the original brief

- **All §11 questions answered with the documented defaults** rather than batched
  to the user. Cloud-agent autonomous mode does not include a synchronous user
  loop, so waiting on confirmation would have blocked the deliverable. Each
  default is logged in §4 of the research log.
- **Competitor sweep extended** beyond the named tools in Q2. The web search
  surfaced four UK-relevant SLT-specific or SLT-integrated competitors that the
  brief did not name: **Octopus EPR (OEPR)**, **Smilenotes UK**, **Clindoc**,
  and **PatientNotes**. OEPR in particular changes the UK competitive picture
  and is flagged as a possible future integration target rather than a pure
  competitor.
- **`docs/ml/prep-brief.md` does not exist** in the repo. The brief's §3 input
  list references it; only `triage-capture.md`, `session-plan.md`, and
  `summary-generator.md` are present under `docs/ml/`. The prep-brief shape is
  described inline in `triage-capture.md`, which the analysis used as the
  source. No correction made to the brief — flagging in the run summary is
  sufficient.
- **Notion table fix-up.** Two rows in the published Q1 audit table contained
  literal `|` characters inside cells (the Speech Sanctuary tagline and the
  four-way triage enum). The Notion Markdown table parser broke those rows on
  first publish; they were repaired in-place via `notion-update-page` against
  the table block representation. The final page reads cleanly. The lesson, for
  future Notion publishing runs, is to avoid raw `|` inside table cells — use
  `/` or commas instead.
- **No code, infra, or test changes** were made. The brief explicitly scopes
  this run to strategy advice. Only two files changed on the branch:
  `docs/strategy/product-strategy-review-brief.md` (this file, §16 only) and
  the new `docs/strategy/product-strategy-review-research-log.md`.

