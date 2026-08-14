# R4 — Asset Leverage & Adjacent Opportunity Spaces

**DevUp Labs / Sona pivot memo — 2026-08-14 · Author: Claude research worker**

> Scope note added by orchestrator: ideation is constrained to products serving SLTs/SLPs in UK+US.
> This memo's adjacencies inform *buyer-of-record and wedge* choices within that constraint.

## TL;DR

Sona lost the SLT co-pilot race on distribution, not on assets. The assets that remain — a jurisdiction-aware clinical eval harness, a compliance-grade multi-tenant platform, and deep SLT/SEND domain knowledge — transfer best into markets where **the buyer already spends money under statutory compulsion**. Three spaces clear that bar decisively: (1) **SEND/EHCP statutory workflow and evidence tooling for local authorities**, which now sit on a government-underwritten ~£5.6bn deficit bailout and are already buying AI EHCP tools from four vendors ([schoolsweek.co.uk](https://schoolsweek.co.uk/government-to-write-off-90-of-councils-send-deficits/)); (2) **clinical safety-case / assurance tooling for clinical AI deployments**, riding the April 2026 DTAC 2.0 mandate and the live DCB0129/0160 revision consultation (open until 11 Sep 2026) ([digital.nhs.uk](https://digital.nhs.uk/data-and-information/information-standards/governance/latest-activity/standards-and-collections/review-of-digital-clinical-safety-standards-dcb0129-and-dcb0160)); and (3) **eval/benchmark licensing to clinical-AI vendors facing MHRA scrutiny**, where the AI Airlock now has £1.2m/yr through 2029 and an AI framework due this year ([gov.uk](https://www.gov.uk/government/collections/ai-airlock-the-regulatory-sandbox-for-aiamd)). The "clinicians say they'd pay" trap is avoided by ranking every option on whether a purchase order already exists somewhere. Several beloved options — school screening, parent-side tribunal tools, adult niches — fail that test or fail 2-person feasibility and should be parked.

---

## Asset → Advantage Map

**A1. Speech-ML eval harness** (54 schema-validated synthetic clinical personas, 18 SLT specialties, 8 jurisdictions, 5 regulatory regimes, 7 statutory frameworks, golden triage/plan expectations, deterministic CI). Confers unfair advantage in: clinical-AI vendor QA/regulatory evidence (MHRA AIaMD submissions, DCB0129 hazard-log evidence); benchmark licensing to labs and health systems (MedHELM/HealthBench-style evals exist but are US-centric, generalist, and jurisdiction-blind — nothing covers UK statutory frameworks or allied health at all: [pacific.ai](https://pacific.ai/evaluating-frontier-llms-for-healthcare-with-medhelm-40-clinical-scenarios-and-a-new-q2-2026-leaderboard/), [pmc.ncbi.nlm.nih.gov](https://pmc.ncbi.nlm.nih.gov/articles/PMC12547120/)); synthetic test-data licensing; and QA of LAs' own AI-drafted EHCPs. This is the rarest asset. The persona *methodology* (schema-validated, jurisdiction-parameterised, golden-expectation) generalises beyond SLT.

**A2. Multi-tenant clinical platform** (Node/Hono/Postgres + Flutter, auth, audit-by-construction, review-gate). Advantage in: any regulated document workflow where a human must review AI output and the trail must survive a tribunal or audit — EHCP advice drafting, statutory reporting, clinical triage. Commodity as an app; differentiated as an *evidence-producing* workflow engine.

**A3. Compliance-by-design posture** (UK residency, self-hosted open-weights, DPIA discipline, HIPAA-aligned terraform). Advantage in: NHS and LA procurement, where DTAC 2.0 (mandatory from 6 Apr 2026) and DSPT are gating ([protectclinical.co.uk](https://protectclinical.co.uk/articles/dtac-and-dcb0160-what-gp-practices-need-to-know)). Also the credibility base for selling assurance to others: "we run the stack we assure."

**A4. SLT domain depth + design partner.** Advantage in: anything SEND/SLCN-adjacent; the design partner is a live source of EHCP reports, tribunal evidence patterns, and referral packs. Narrow but deep.

**A5. UK market context knowledge** (66,695 children waiting for SLT as of April 2026, ~46-week average wait ([thesendlist.co.uk](https://thesendlist.co.uk/nhs-speech-language-therapy-waiting-times-uk/)); SEND system in fiscal crisis). Advantage: knowing exactly where the statutory money is.

---

## Opportunity Deep-Dives

### O1. LA-side SEND statutory workflow: professional-advice drafting, QA, and annual-review tooling

- **Buyer & budget:** English local authorities (153 with SEND duties). Real, existing budget: high-needs deficits hit ~£5bn and the government wrote off 90% (~£5.6bn) in Feb 2026, extending the statutory override to 2027/28 ([schoolsweek.co.uk](https://schoolsweek.co.uk/government-to-write-off-90-of-councils-send-deficits/), [ifs.org.uk](https://ifs.org.uk/articles/ad-hoc-bolt-ons-are-undermining-governments-aims-local-government-funding-reform-support)). LAs are demonstrably buying AI here *today*: Agilisys EHCP Tool live in 40 councils; Invision360 VITA, EHCP Genie, GovMetric Nexa all selling ([agilisys.co.uk](https://www.agilisys.co.uk/agilisys-ehcp-tool/), [imosphere.com](https://www.imosphere.com/send/ehcp-genie)).
- **Pain evidence:** 718,800 EHCPs at Jan 2026 (+12.5% YoY); 110,700 new plans in 2025; only 46.4% issued within the statutory 20 weeks ([explore-education-statistics.service.gov.uk](https://explore-education-statistics.service.gov.uk/find-statistics/education-health-and-care-plans/2026)). SEND tribunal appeals hit 25,002 in 2024/25 (+83% in 24 months), parents win ~99% of decided cases ([disabilityrightsuk.org](https://www.disabilityrightsuk.org/news/send-tribunal-appeals-record-high), [brownejacobson.com](https://www.brownejacobson.com/insights/send-tribunal-data-released)). Every lost appeal costs the LA legal spend plus the provision anyway.
- **Competition:** Crowded on generic plan-drafting (four named vendors + in-house tools like Barking & Dagenham's BD Notes). **Gap:** none of them can *quality-assure* the clinical advice going into Section F, and none has an eval harness to prove their drafting is safe. The wedge is the un-crowded corner: drafting and QA of the *therapy advice* (SLT/OT appendices) that feeds EHCPs — the input LAs can't get because of the 21% SLT vacancy rate — and audit-defensible QA of AI-drafted plans.
- **Why us:** A1 (golden expectations = automated QA of plan quality against statutory frameworks — 7 already encoded), A2 (review-gate + audit trail is exactly what a tribunal-exposed LA needs), A4 (we know what a defensible Section F looks like).
- **Market size:** 153 LAs × £30–80k/yr plausible ACV for statutory SEND tooling → £5–12m serviceable; Agilisys's traction proves willingness to pay.
- **2-person feasibility:** High. LA sales cycles are slow (3–9 months) but frameworks (G-Cloud) and the current bailout-driven "improve or lose funding" pressure help. One lighthouse LA is enough.
- **Trap check:** PASSES. Statutory 20-week deadline, Ofsted/DfE inspection pressure, live budget line, incumbent purchases prove it.

### O2. Clinical-AI evaluation & benchmarking as a product

- **Buyer & budget:** Three candidate buyers. (a) **Clinical-AI vendors** needing regulatory-grade evidence — the strongest: MHRA's AI framework lands in 2026 and AI Airlock is funded £1.2m/yr to 2029, so UK AIaMD vendors will need pre-market and post-market performance evidence ([fieldfisher.com](https://www.fieldfisher.com/en/insights/mhra-ai-airlock-from-pilot-sandbox-to-scaling-regulatory-pathway-for-ai-medical-devices), [medregs.blog.gov.uk](https://medregs.blog.gov.uk/2026/06/09/advancing-ai-regulation-in-healthcare-insights-from-ai-airlock-phase-2/)). (b) **Frontier labs**: OpenAI shipped HealthBench (May 2025) and HealthBench Professional (Apr 2026) built on paid clinician rubrics — labs demonstrably pay for clinical eval data, but they buy people-hours at scale via Mercor/Surge-type pipelines, and a 2-person shop sells there once, not recurringly. (c) **Health systems**: cautionary tale — CHAI's US assurance-lab network collapsed in early 2026 ([fiercehealthcare.com](https://www.fiercehealthcare.com/ai-and-machine-learning/inside-chais-failed-assurance-labs)); hospitals didn't want to pay third parties to vet vendors.
- **Pain evidence:** Existing benchmarks (MedHELM 40+ scenarios, HealthBench 5,000 conversations) are physician-centric, US-centric, and contain **zero allied-health, zero UK-statutory content**. Any vendor selling triage/planning AI into UK community services has no off-the-shelf way to evidence safety.
- **Competition:** Pacific AI/John Snow Labs (MedHELM commercialisation), Vals AI, academic benchmarks. None in allied health or UK jurisdictional coverage.
- **Why us:** A1 is the entire company here — "beginning of a clinical safety case and a benchmark" is literally the product. A3 makes us credible to regulated buyers.
- **Market size:** Small today as a standalone (UK AIaMD vendor pool is maybe low hundreds; £10–50k/vendor eval engagements → ~£1–3m near-term). Grows if MHRA framework mandates performance evidence.
- **2-person feasibility:** High for services-led ("eval engagements"), moderate for product. Danger: becomes a consultancy.
- **Trap check:** PARTIAL. Vendor buyers have regulatory compulsion arriving in 2026 but not yet biting; health-system buyers just failed this test in the US. Sell to the regulated, not the deployers.

### O3. AI safety cases & clinical-safety compliance tooling (DCB0129/0160, DTAC)

- **Buyer & budget:** Digital health vendors (must hold DCB0129 safety case + hazard log + named CSO to sell to the NHS) and NHS deploying organisations (DCB0160). DTAC 2.0 became the mandatory procurement gate on 6 Apr 2026 ([protectclinical.co.uk](https://protectclinical.co.uk/articles/dtac-and-dcb0160-what-gp-practices-need-to-know)). Budget is real: vendors pay CSO consultancies £5–25k per safety case today; platforms like Assuric and Naq already sell DCB0129 compliance SaaS ([assuric.com](https://www.assuric.com/dcb0129), [naqcyber.com](https://www.naqcyber.com/blog/clinical-safety-officer-requirements-under-dcb-0129)).
- **Pain evidence:** NHS England is revising DCB0129/0160 explicitly because AI "introduces new categories of clinical risk that the current standards were not designed to address"; consultation open 29 Jun–11 Sep 2026 ([digital.nhs.uk](https://digital.nhs.uk/data-and-information/information-standards/governance/latest-activity/standards-and-collections/review-of-digital-clinical-safety-standards-dcb0129-and-dcb0160)). Nobody knows how to write a hazard log for an LLM. A safety case with *continuous, deterministic eval evidence attached* is a category the incumbents (document-template SaaS + consultants) cannot produce.
- **Competition:** Assuric, Naq, DigiSafe, boutique CSO consultancies — all documentation-first, none eval-backed.
- **Why us:** A1 (the harness *is* the evidence engine: personas + golden expectations + CI = living hazard-log verification), A3 (we've done DPIA/DTAC ourselves), A2 (audit-trail machinery). Differentiated as "safety case as code."
- **Market size:** Hundreds of UK clinical-AI vendors + every NHS trust deploying LLMs under DCB0160. £2–10m serviceable near-term; expands with the revised standards.
- **2-person feasibility:** High. Sell to vendors (fast cycles, existential pain) first, trusts later. Caveat: neither founder is a registered clinician — a CSO must be; partner with a CSO network or use the design partner.
- **Trap check:** PASSES. Compliance is a condition of revenue for the buyer; budget lines exist (they pay consultants today).

### O4. NHS community-paediatrics waiting-list triage (capacity multiplier)

- **Buyer & budget:** ICBs and community trusts. New money attached to targets: 2026/27 planning guidance requires ICBs to publish plans to eliminate 52-week community waits; 80%-within-18-weeks target by 2028/29 ([thesendlist.co.uk](https://thesendlist.co.uk/nhs-speech-language-therapy-waiting-times-uk/), [nuffieldtrust.org.uk](https://www.nuffieldtrust.org.uk/resource/how-will-waiting-times-in-community-health-services-affect-the-shift-towards-neighbourhood-health)). Trusts already outsource: one service is transferring 900 CYP to independent providers Sept 2025–Mar 2026.
- **Pain evidence:** 66,695 children waiting for SLT alone; ~1 in 4 CYP waiting >1 year across community services; 21% SLT vacancy rate. This is the original "capacity multiplier" thesis.
- **Competition:** Waiting-list validation vendors (mostly acute-sector), triage AI, and inertia. Low competition in *community paediatrics specifically*.
- **Why us:** This is the straight-line reuse of the dead product — A1's triage goldens, A2's review-gate, A4. Highest asset transfer of all options.
- **Market size:** ~200 community providers/ICB footprints; £30–100k ACVs → £5–15m serviceable.
- **2-person feasibility:** LOW-MODERATE. NHS sales cycles (12–18 months, DTAC, clinical safety, procurement) nearly killed the company once; 2 people without an NHS anchor customer will burn out before first PO.
- **Trap check:** MIXED. Targets are statutory-ish and budgets exist, but the buyer is the slowest in the memo. Only viable *after* revenue from O1/O3 funds the sales cycle.

### O5. Allied-health horizontal (OT, physio, dietetics)

- **Buyer & budget:** Same buyers as O4 plus private allied-health groups. OT and physio are each ~6% of the CYP community waiting list; physio workforce not keeping pace ([csp.org.uk](https://www.csp.org.uk/news/2025-08-14-nhs-waiting-lists-rise-demonstrates-need-graduate-physio-job-guarantee)).
- **Pain evidence:** Real but diffuse; no single statutory trigger.
- **Competition:** Generic clinical-documentation AI (Heidi, Tandem, etc.) racing into allied health from the scribe side.
- **Why us:** A2 transfers fully; A1 only structurally (the persona schema and harness generalise; the 54 personas don't — new golden content per discipline is months of clinical-expert work we'd have to buy).
- **2-person feasibility:** LOW as a direct move. Right as a *sequencing* thesis: whatever we build for O1/O3/O4 should be discipline-parameterised so allied-health expansion is config, not rebuild.
- **Trap check:** FAILS today — this is "clinicians would pay" again, multiplied across three professions.

### O6. Synthetic clinical persona / test-data licensing

- **Buyer & budget:** Healthtech vendors' QA teams, EHR integrators, and eval companies. Healthcare synthetic-data market ~$1.8bn (2025) growing to ~$12bn by 2034 ([snsinsider.com](https://www.snsinsider.com/press-release/global-healthcare-synthetic-data-market)) — but dominated by tabular/EHR-statistical synthesis (Syntegra, MDClone, Mostly AI), not behavioural clinical personas.
- **Why us:** A1 licensed as data + schema. Near-zero marginal cost.
- **2-person feasibility:** Very high — but as a **feature of O2/O3, not a company**. 54 personas is a wedge, not a catalogue; standalone licensing at this scale is a £100–300k/yr side revenue line, not a venture.
- **Trap check:** PASSES weakly (QA budgets exist) but ceiling is low.

### O7. School/MAT-facing SLCN screening at scale

- **Buyer & budget:** Schools/MATs buy screening today: WellComm Primary £449, Language Link £180–400/school/yr ([gl-assessment.co.uk](https://www.gl-assessment.co.uk/products/wellcomm/), [teachwire.net](https://www.teachwire.net/products/gl-assessment-wellcomm-primary-speech-and-language-toolkit-for-screening-and-intervention/)). SLCN is the most common primary SEN type in state schools.
- **Pain evidence:** Real (screening feeds the EHCP pipeline), but budgets are small, per-school, and discretionary; GL Assessment and Speech Link are entrenched with NHS-co-developed credibility.
- **Why us:** A4 only; A1/A2 barely transfer to teacher-administered screening. Selling £300/yr SKUs to 20,000 primaries is a distribution game — our known weakness.
- **2-person feasibility / trap check:** FAILS both. Park it.

### O8. Parent/solicitor-side SEND tribunal evidence tooling; adult niches (dysphagia/voice)

- **Tribunal parent-side:** 25,002 appeals, 99% parent win rate, private SLT tribunal reports run £900–1,400+ ([thesendlist.co.uk](https://thesendlist.co.uk/private-send-assessment-cost-calculator/), [flourishslt.uk](https://flourishslt.uk/ehcp-and-send-tribunal-reports/)). Money is real but fragmented (B2C/small solicitor firms), demand is per-case, and arming parents against LAs forecloses O1. Better: sell report-production tooling to the *independent SLT practices* writing those reports — our design partner is one. Modest, immediate revenue (£100–200/mo/practice × ~1,500 independent SLTs), good cashflow bridge, small ceiling.
- **Adult dysphagia/voice:** clinically important, but no statutory buyer, personas don't exist yet, and no design partner. Park.

---

## Ranked Shortlist (budget reality × asset leverage × 2-person feasibility)

| # | Option | Budget reality | Asset leverage | 2p feasibility | Composite |
|---|--------|---------------|----------------|----------------|-----------|
| 1 | **O3 — AI safety-case/eval-backed compliance tooling** | Strong (compliance = condition of revenue; consultants paid today; DTAC 2.0 live, DCB revision landing) | Very high (A1+A2+A3) | High (vendor buyers, fast cycles) | **Best risk-adjusted** |
| 2 | **O1 — LA SEND statutory advice/QA tooling** | Strongest in memo (£5.6bn bailout, 4 vendors already paid, 20-week statutory deadline) | High (A1+A2+A4) | Medium-high (slow but provable) | **Biggest prize** |
| 3 | **O2 — Eval/benchmark product for clinical-AI vendors** | Medium, improving as MHRA framework lands | Maximal (A1) | High | Combine with O3, don't run standalone |
| 4 | O6 — Synthetic persona licensing | Weak-medium | High | Very high | Revenue side-dish to #1–3 |
| 5 | O4 — NHS community-paeds triage | Medium (targets + money, glacial buyer) | Maximal | Low now | Year-2 move, funded by #1–2 |
| 6 | O8a — Independent-practice tribunal report tooling | Medium (real per-case fees) | Medium | Very high | Cashflow bridge via design partner |
| 7 | O5 — Allied-health horizontal | Weak trigger | Medium | Low | Architecture principle, not a pivot |
| 8 | O7 — School SLCN screening | Weak | Low | Low | Park |

---

## Implications for Pivot

1. **The eval harness is the company now; the co-pilot was the demo.** Every top-ranked option monetises A1 — as regulatory evidence (O3), plan QA (O1), benchmark (O2), or licensed data (O6). The pivot should reposition Sona from "AI that does clinical work" to "the system that proves clinical AI is safe and statutorily compliant" — a position the competitor who beat us has just created demand for, since *they* now need exactly this evidence.
2. **Recommended shape: O3 + O2 fused, with O1 as the vertical proof.** Ship "safety case as code" for UK clinical-AI vendors (eval harness + hazard-log evidence + DTAC/DCB artefacts), timed to the DCB0129/0160 revision (respond to the consultation before 11 Sep 2026 — cheap authority-building) and the 2026 MHRA framework. Use the SEND/EHCP domain as the first vertical: sell QA-of-AI-drafted-plans to one LA or *to the four EHCP-AI vendors themselves* (Agilisys, Invision360, Imosphere, GovMetric) — vendors with revenue, tribunal-exposed customers, and no eval story.
3. **Escape the old trap explicitly.** Every qualified lead must answer: what statute, deadline, or contract clause forces this purchase, and what did you spend on it last year? LAs (20-week duty, tribunal losses), vendors (DTAC/DCB as revenue gate) pass. Clinicians-who'd-pay, schools, and parents do not.
4. **What dies:** direct NHS sales in year one; horizontal allied-health ambitions except as schema design; school screening; adult niches. **What survives quietly:** the design partner becomes the tribunal-report tooling beta (O8a) for near-term cash and continued clinical grounding.
5. **90-day tests:** (a) one paid eval/safety-case engagement with a clinical-AI vendor at ≥£10k; (b) one EHCP-AI vendor or LA discovery converting to a paid QA pilot; (c) DCB consultation response published. Two of three validates; zero of three means the assets are worth more sold or open-sourced-for-hire than as a venture.
