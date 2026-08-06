---
title: "Sona — Product Strategy & Differentiation Review"
subtitle: "May 2026"
date: "2026-05-28"
lang: en-GB
---

> Internal strategy memo. Written for the founders first and a future investor second.



# TL;DR — answers in 60 seconds

- **Single-customer fit risk is real and concentrated.** The 8-step parent form, the four triage outcomes, and every persona are paediatric, UK, English-speaking, EHCP-aware, and Speech-Sanctuary-branded. A second private SLT — especially adult voice, AAC, dysphagia, or stutter — will spot the tailoring inside one screen. **Fixable by configuration, not by re-engineering**, but the configuration layer does not yet exist.
- **USP in one line.** *Sona turns the first 30 days of a private speech-therapy case — intake, triage, first-session plan, parent summary — into one reviewed loop, with UK-region data and a clinician sign-off on every artifact.* The defensible part is the **loop** and the **review-gated trust posture**, not any single AI feature.
- **Moat ranking, honest.** Strongest: design-partner-shaped intake-to-summary loop and the audit-trail-by-construction posture. Medium: UK data residency and the structured, schema-validated AI output shapes. **Weakest: the self-hosted Gemma posture itself** — competitors will match it within twelve months, and most clinicians cannot tell a self-hosted Gemma from a BAA-covered API.
- **Integration headline.** Adjacent integrations (calendar, video, e-sign, payments, and a "Sona for Cliniko" wedge) are the realistic Year-1 path. **NHS GP Connect is a Year-2+ programme**, not a Year-1 feature — it requires DSPT Standards Met, HSCN access, PDS compliance, a Clinical Safety Officer compliant with DCB0129/0160, SCAL evidence, and use-case approval. (NHS Digital, *GP Connect Access Record: Structured*, retrieved 2026-05-28.)
- **Pricing recommendation.** Per-clinician monthly subscription with a free-trial-on-cases mechanic. **Start at £79 / clinician / month** including AI drafting on a usage cap, with a £39 "starter" tier for new graduates. Sits between Smilenotes (£5, no AI) and Heidi Clinician ($150 ≈ £120, scribe-only). Per-case is wrong for this market: 3–8 cases / week / clinician puts revenue too close to a single Cliniko seat to be defensible.
- **What to do next week.** (1) Run the one-therapist-fit audit with a second SLT before any code lands. (2) Decide whether the next sprint is the intake template engine or the AI loop, and only one — both at once is the failure mode. (3) Price a DSPT readiness pass with a specialist consultancy. (4) Talk to ASLTIP about a member-benefit slot.
- **⚠ Material change since this memo was written (added 2026-08-06).** **Ogma** — filed in section 3 below as a minor "kid-facing app" — is in fact the **closest direct competitor to Sona**, and in **June 2026 it was acquired by SaltRoad** (which raised a **£1.5M seed** to do it). The Ogma Assistant is live on iOS + Android, **England-hosted**, **accepted onto NHS G-Cloud 14**, and now sits behind SaltRoad's **1,000+ UK therapist marketplace**. It drafts notes, assessment reports, parent summaries and referrals *today*, while Sona's AI loop is still stub. It also owns a genuine data/tech moat — a phoneme-level ASR model trained on proprietary atypical-child-speech data — the "big invention" the founders worried Sona lacks. This **neutralises the UK-residency moat** and **wins the distribution fight this memo itself named as decisive**. Full analysis in the **2026-08-06 update** immediately below; the "SLT-specific AI entrants" table row and moat 4 are annotated accordingly. **Sona's surviving wedge is the pre-session new-case loop — intake, triage, consult prep — which Ogma does not occupy.**

# Update — 2026-08-06: Ogma / SaltRoad is the closest competitor to date

*Added after the founders surfaced [ogmatherapy.com](https://www.ogmatherapy.com). This section supersedes the "SLT-specific AI entrants" row in section 3 and revises moat 4. The May analysis under-rated Ogma by filing it as a "kid-facing app". It is not — it is the most direct competitor we have found, and since June 2026 it is owned by SaltRoad. All web facts below retrieved 2026-08-06.*

## What Ogma actually is

Two products behind one **data flywheel**:

1. **The Ogma Assistant** — an AI documentation tool for SLTs. The therapist adds it to a teletherapy call or uploads a recording; it drafts clinical notes (**SOAP, ROCAIP**), **assessment reports, parent summaries, nursery summaries, and onward referrals**, exported as Word / PDF. Headline claims: report writing from ~3 hours to ~3 minutes, ~3 hours saved per child, **~600 hours/year per NHS therapist**, ~20% efficiency. Hosted encrypted **in England**, and **accepted onto NHS G-Cloud 14**.
2. **The "Ogs"** — animated, kid-facing AI therapeutic agents delivering evidence-based intervention through naturalistic speech, powered by a **phoneme-level speech-recognition model trained on a proprietary dataset of atypical child speech**. The training corpus is *harvested by the Assistant*. That is the flywheel: the admin tool captures the speech data that trains the intervention model.

Founded in the UK (Louise — PhD Developmental Cognitive Neuroscience, UCL Institute of Child Health, ex-founder of the resale platform dotte — plus a technical co-founder), backed by Founders Factory.

## The acquisition changes the board

In **June 2026, SaltRoad acquired Ogma**, funded by a **£1.5M seed** (Techstart Ventures lead; Ascension, ScaleX, and angels). SaltRoad is the two-sided marketplace from the section-3 landscape — it matches families to therapists and runs a network of **1,000+ UK SLTs**. The stated plan is to embed the Ogma Assistant across that network to raise the number of children each therapist can see.

**This kills the "SaltRoad as a distribution channel for Sona" idea** raised in discussion: SaltRoad now owns a direct competitor. The combined entity spans **demand (marketplace) → session → documentation** — three of the nine lifecycle steps in section 1, end to end, with real distribution attached.

## Sona vs Ogma — honest comparison

<table class="competitors">
<thead>
<tr><th>Dimension</th><th>Sona</th><th>Ogma (now SaltRoad)</th><th>Who's ahead</th></tr>
</thead>
<tbody>
<tr><td><strong>Core job</strong></td><td>The pre-session new-case loop: adaptive intake → consult prep → triage → first-session plan → parent summary</td><td>Session capture → AI documentation (notes, assessment reports, parent/nursery summaries, referrals) + kid-facing intervention (the Ogs)</td><td>Different jobs; they overlap on drafting &amp; summaries</td></tr>
<tr><td><strong>Where it enters the case lifecycle</strong></td><td><strong>Before</strong> the session (enquiry → intake → triage → consult prep)</td><td><strong>At / after</strong> the session (record → document)</td><td>Sona owns the front of the funnel; Ogma owns the middle/back</td></tr>
<tr><td><strong>Build status</strong></td><td>Intake form + case management live; the AI loop is stub today</td><td>Live and shipping — iOS + Android apps, G-Cloud 14 listed, published efficiency claims</td><td><strong>Ogma</strong></td></tr>
<tr><td><strong>AI drafting surface</strong></td><td>Prep brief, session plan, parent summary (vision)</td><td>Notes (SOAP/ROCAIP), assessment reports, parent + nursery summaries, referrals (live)</td><td><strong>Ogma</strong> (broader &amp; shipped)</td></tr>
<tr><td><strong>Data residency / trust</strong></td><td>UK-region, self-hosted Gemma, air-gapped, review-gated, append-only audit</td><td>Encrypted, England-hosted; clinician-in-the-loop</td><td>Parity — Ogma matched the headline claim</td></tr>
<tr><td><strong>Proprietary tech moat</strong></td><td>None yet; domain ASR deferred to roadmap (<code>speech-train</code>, v0.4+)</td><td>Phoneme-level ASR on a proprietary atypical-child-speech corpus + Assistant→Ogs data flywheel</td><td><strong>Ogma</strong></td></tr>
<tr><td><strong>Distribution</strong></td><td>Direct; planned ASLTIP slot + "Sona for Cliniko" (both unbuilt)</td><td>SaltRoad marketplace: 1,000+ UK SLTs + inbound family demand</td><td><strong>Ogma</strong> (decisive)</td></tr>
<tr><td><strong>NHS readiness</strong></td><td>Year-2+ (DSPT / G-Cloud on the roadmap)</td><td>On G-Cloud 14 <em>now</em>; NHS-time-saving framing</td><td><strong>Ogma</strong></td></tr>
<tr><td><strong>Target buyer</strong></td><td>Solo independent private SLT owning their own brand and client relationship</td><td>Therapists in / around a managed network; NHS efficiency</td><td>Different segments</td></tr>
<tr><td><strong>Statutory / specialty structure</strong></td><td>EHCP-aware, four-outcome triage, specialty-keyed output schemas</td><td>Format templates (SOAP/ROCAIP); paediatric</td><td><strong>Sona</strong></td></tr>
<tr><td><strong>Kid-facing intervention</strong></td><td>Explicit non-goal (principle: no child screen time)</td><td>Core to the product (the Ogs)</td><td>Divergent philosophies — not a scoreable axis</td></tr>
</tbody>
</table>

## What this does to the moat analysis

Ogma neutralises, matches, or leads on several things the May memo treated as Sona advantages:

- **UK data residency (moat 4) is no longer a differentiator against the competitor that matters most.** Ogma is England-hosted and encrypted. Downgrade moat 4 from "medium-low, 12 months" to **price-of-entry — already matched**.
- **"AI drafting for SLTs" is not whitespace.** Ogma is **live** while Sona's AI loop is stub. On the drafting surface itself — notes, reports, **parent summaries**, referrals — Ogma is ahead on both shipping and format breadth.
- **Distribution — the factor this memo named as decisive — now favours Ogma.** Section 8's honest read said Sona is "bootstrappable but not venturable" without a distribution mechanic. SaltRoad *is* that mechanic, and Ogma has it.
- **Ogma has the data/tech moat Sona lacks.** The atypical-child-speech ASR + Assistant-fed flywheel is exactly the "single big invention" the founders worried Sona doesn't have. Sona deferred ASR to roadmap; Ogma built it first and compounds it monthly.

## Where Sona is still genuinely differentiated

The survivable wedge is narrower than "AI admin for SLTs" — because Ogma owns that — but it is real:

- **Ogma starts at the session; Sona starts before it.** The Assistant is fundamentally a session-capture-and-document tool (record → generate), like the scribes. It does **not** own the **pre-session new-case loop**: smart adaptive parent **intake**, the 20-minute **free-consult prep**, and the **triage decision** (strategy only / short block / full assessment / refer out). That front-of-funnel is Sona's actual wedge, and Ogma does not currently occupy it.
- **Self-pay independent practice vs managed network.** Sona is built for the solo private practitioner who owns their own brand, intake form and client relationship (white-label, own question tree). SaltRoad+Ogma is oriented to a *managed therapist network* and NHS-efficiency framing. The independent who does **not** want to route their clients through a marketplace is Sona's customer, not Ogma's.
- **Structured, statutory-framework-aware output.** EHCP-awareness, four-outcome triage and specialty-keyed schemas are structural, not format-templated (SOAP/ROCAIP).

**Contested, no longer owned:** the parent-facing summary. Both draft it. Sona's tone-slider / reading-level / disclosure-footer treatment is more considered, but it is no longer a "nobody else does this" moment.

## Implications — what to actually do

1. **Re-sharpen the one-liner away from Ogma's.** Drop "speech &amp; language therapy, less admin" — that is now effectively Ogma's pitch. Lead with the pre-session loop: *"Sona gets the case ready before the first session — smart intake, triage, and a consult-ready brief — for independent SLTs who run their own practice."*
2. **Treat intake → triage → consult-prep as the defensible core**, not the AI drafting. Ship that front-of-funnel end-to-end before the drafting loop, because the drafting loop is now a red-ocean fight against a live, funded, distribution-backed incumbent.
3. **Decide the honest strategic posture** (open question 8 below): compete head-on on the independent-private-practice wedge; complement Ogma (write Sona's structured intake/triage into whatever the SLT documents with); or reconsider whether the AI-admin thesis is still investable now that SaltRoad+Ogma exists.
4. **Watch the flywheel.** Ogma's data advantage compounds every month the Assistant runs. Any Sona ASR ambition (<code>speech-train</code>) is now a fast-follow against a moving target, not a greenfield.

# Context

The MVP brief and the demo deck pitch Sona as a co-pilot for the first 30 days of a private SLT-to-family relationship: smart parent intake → consult prep → triage → first-session plan → parent summary. The demo video and slides — the artifacts a reviewer will have seen — quote a **30–60 minute saving per case at 3–8 cases per week**, which lines up with the per-stage time-saving targets the team has set internally for the triage step, the session-plan step, and the parent-summary step.

The MVP was scoped from a 1.5-hour interview with **one** private SLT (the design partner). That is enough to ship a demo; it is not enough to know whether the next ten therapists who watch the same demo see themselves on the screen. That is the question this memo exists to answer.

What is **real today**: the 8-step parent intake form, case management, audit trail, the design system, and slot-based booking. What is **vision**: AI prep brief, AI plan, AI parent summary, telehealth, calendar sync. Anything below that relies on the vision side is flagged as such.

# 1. The full case lifecycle

The founder's flow for a case end-to-end. Each step is tagged with what is built today, what is on the 90-day vision side, and what is roadmap. The MVP's "first 30 days" loop is a subset of this lifecycle, not the whole shape.

<table class="lifecycle">
<thead>
<tr><th>#</th><th>Step</th><th>What happens</th><th>State today</th></tr>
</thead>
<tbody>
<tr><td>1</td><td>Omni-channel enquiry</td><td>Parent reaches the practice via any channel — web form, phone, email, WhatsApp, social, school or GP referral.</td><td>Not built. Inbound is ad-hoc today; the practice consolidates into a contact-us form and an email inbox.</td></tr>
<tr><td>2</td><td>Basic-details questionnaire</td><td>Short, low-friction initial capture: child name, age, one-line concern, parent contact. ~2 minutes to complete.</td><td><strong>Missing.</strong> Today the parent's first form is the deep 8-step intake — too much for first contact.</td></tr>
<tr><td>3</td><td>Assessment &amp; summary by the clinician</td><td>Clinician reviews the enquiry + basic details and decides whether to invite, refer out, or signpost.</td><td>Vision. The clinician makes this call by hand today; an AI-drafted triage suggestion is on the 90-day vision side.</td></tr>
<tr><td>4</td><td>Appointment booking</td><td>Confirm the 20-min free consult slot; auto-attach calendar invite and video link.</td><td>Slot-based booking is built. Calendar round-trip and video deep-link are Year-1 integrations (see section 5).</td></tr>
<tr><td>5</td><td>Pre-appointment details capture</td><td>The deeper structured intake the clinician needs before the consult — the 8-step form lives here.</td><td><strong>Built.</strong> The audited subject of section 2.</td></tr>
<tr><td>6</td><td>Appointment + summary-report preparation &amp; sharing</td><td>The 20-min consult itself, then AI-drafted prep brief, first-session plan, and parent summary, reviewed and published by the clinician.</td><td>The screens are built; the AI drafting is stub today and is the 90-day vision side.</td></tr>
<tr><td>7</td><td>Follow-up actions: arrangement &amp; communication</td><td>Between-session carryover — home-practice prompts, school / TA comms, parent feedback fed back into the next session plan.</td><td>Roadmap v0.2. The single biggest unaddressed pain after intake / triage.</td></tr>
<tr><td>8</td><td>Referral to other agencies</td><td>When the case is out of scope (ENT, OT, paediatrics, audiology) the parent is handed off cleanly with a structured referral packet.</td><td>The triage "refer out" outcome captures the decision today; no integration with external referral systems yet. Natural Year-2 integration play.</td></tr>
<tr><td>9</td><td>Analysis of cases &amp; planning for future cases</td><td>Caseload-level analytics — override rates, demographics, outcome trends, capacity planning.</td><td>Roadmap. The natural up-sell at clinic scale and the foundation for the multi-clinician version of the product.</td></tr>
</tbody>
</table>

Three observations the rest of this memo turns on:

- **The MVP "first 30 days" loop is steps 2 → 6**, with light footprint on step 4. Steps 1, 7, 8, 9 are out of scope today and each opens a distinct future direction.
- **Steps 1 and 2 are the highest-leverage missing pieces near-term.** Today the parent's first touch is the deep 8-step intake (step 5). That is a high-friction first interaction. A lighter "enquiry → basic-details → clinician triage" funnel in front of the deep intake materially reduces drop-off before the free consult, and re-orders the parent journey to feel less like a bureaucratic form and more like a conversation. Doing this does not require any change to the AI loop.
- **Steps 7, 8, 9 are the platform plays.** Step 7 is the obvious roadmap-next item (carryover was the design partner's second-biggest pain after intake). Step 8 is the integration play for Year-2 referrals. Step 9 is the analytics layer that unlocks clinic-scale and NHS-framework conversations.

# 2. Where the one-therapist tailoring leaks through

The audit walks the intake spec, the AI output shapes, the triage outcomes, and the vocabulary choices. Each surface is classified by **who it fits**, **who it breaks**, and a **fix class** — *config* (a per-practice setting toggle in existing infrastructure), *template* (a new template family), or *branch* (a fork in the product).

<table class="audit">
<thead>
<tr><th>Surface</th><th>Assumption today</th><th>Fits</th><th>Breaks for</th><th>Fix class</th></tr>
</thead>
<tbody>
<tr>
<td>Intake form: 8 hard-coded steps in the Flutter app</td>
<td>One global question tree</td>
<td>Paediatric speech-sounds and language clients</td>
<td>Adult voice, adult stutter, AAC, dysphagia, transgender voice — each needs its own tree</td>
<td><strong>template engine</strong></td>
</tr>
<tr>
<td>Form header copy: "Confidential Speech &amp; Language Parent/Carer Questionnaire", tagline "Breathe / Speak / Be"</td>
<td>Speech Sanctuary brand</td>
<td>Speech Sanctuary</td>
<td>Every other practice — visibly someone else's form</td>
<td>config (white-label)</td>
</tr>
<tr>
<td>Mother / Father labelled fields, page 1</td>
<td>Two-parent UK paediatric household</td>
<td>Most paediatric cases</td>
<td>Single-parent, same-sex parents, kinship carers, looked-after children, <strong>all adult clients</strong></td>
<td>config (rename → "Parent / carer 1 / 2") + template variants</td>
</tr>
<tr>
<td>GP details as free text (practice, address, phone)</td>
<td>UK</td>
<td>UK paediatric</td>
<td>US (PCP), AU (GP via My Health Record), CA (family physician) — and even UK if/when GP Connect provides structured data</td>
<td>config + integration (see roadmap)</td>
</tr>
<tr>
<td>EHCP yes/no + EHCP-aware prompt path</td>
<td>English statutory framework</td>
<td>England-based school-age clients</td>
<td>Wales (IDP), Scotland (CSP), NI (Statement), Republic of Ireland, US (IEP under IDEA), AU (NDIS) — different statutory wrappers entirely</td>
<td><strong>template</strong> (statutory-framework pack)</td>
</tr>
<tr>
<td>Nursery / SENCO referral language</td>
<td>Early-years UK</td>
<td>Aria-shaped paediatric cases</td>
<td>Adult clients (post-stroke, head &amp; neck cancer, voice, gender-affirming voice)</td>
<td>config (referral-source enum) + template (adult intake)</td>
</tr>
<tr>
<td>Difficulty checklist of 21 items across 4 domains (speech &amp; language, attention, social, reading &amp; writing)</td>
<td>Paediatric general SLT</td>
<td>Paediatric general SLT</td>
<td>AAC users (no symbol-set / device questions); feeding clients (no food-texture / mealtime log); transgender voice (no goals framing for adult voice transition); stutter sub-specialty (no severity rating scale)</td>
<td><strong>template</strong> per specialty</td>
</tr>
<tr>
<td>Triage outcomes: a 4-way enum (strategy only, short block, full assessment, refer out)</td>
<td>The design partner's private-practice funnel</td>
<td>Solo UK private practice</td>
<td>NHS-funded routes; US insurance-coded plans; AU NDIS pathway — different funnels entirely</td>
<td>config (per-tenant outcome enum)</td>
</tr>
<tr>
<td>Session-plan output schema's specialty enum: speech sounds, language, social communication, fluency, voice, feeding, other</td>
<td>Broad paediatric SLT</td>
<td>Most paediatric and some adult</td>
<td>Dysphagia/swallow as a first-class domain; AAC; tracheostomy / laryngectomy voice; transgender voice goals</td>
<td>template (extend enum + per-domain prompt fragments)</td>
</tr>
<tr>
<td>Parent-summary tone slider (warm ↔ clinical, 5 points) + reading-level (primary/secondary/adult)</td>
<td>Parent of a child</td>
<td>Almost everyone — generalises well</td>
<td>Pure adult-client cases where there is no parent ("client summary", not "parent summary")</td>
<td>config (rename to "recipient summary")</td>
</tr>
<tr>
<td>"Parent" used in field labels, audit events, UI strings</td>
<td>Paediatric model of care</td>
<td>UK paediatric private</td>
<td>Schools-based SLT (TA, SENCO), residential care (key worker), adult clinic (client / patient), public-sector NHS contexts (carer)</td>
<td>config (vocabulary pack)</td>
</tr>
<tr>
<td>Magic-link parent identity (no NHS Login)</td>
<td>Self-pay private</td>
<td>Self-pay private UK</td>
<td>Anyone using NHS-funded routes; ICB-commissioned services; school SLA workflows</td>
<td>integration (see roadmap)</td>
</tr>
<tr>
<td>Solo-practitioner default (from the MVP brief)</td>
<td>One therapist owns a tenant</td>
<td>Sole practitioners ≈ majority of ASLTIP's 1,800 members</td>
<td>Small group practices (the natural growth path for design partners); schools-based teams; charity providers</td>
<td><strong>branch (multi-tenant clinic mode)</strong></td>
</tr>
<tr>
<td>Regulators baked into copy: HCPC, RCSLT</td>
<td>UK</td>
<td>UK</td>
<td>US (ASHA), AU (SPA), CA (SAC), IE (CORU)</td>
<td>config (regulator pack tied to jurisdiction)</td>
</tr>
<tr>
<td>Demo personas: 3y feeding → 11y social-comm, all UK English</td>
<td>Paediatric demo coverage</td>
<td>Paediatric general SLT</td>
<td>Anything outside paediatric general SLT — the design partner has not been tested on adult, AAC, or English-as-additional-language cases</td>
<td><strong>persona library expansion</strong> before any external pitch beyond paediatric</td>
</tr>
</tbody>
</table>

Three leaks matter more than the others, and each maps to a single concrete fix.

**Leak 1: the form is the product, and the form is one practice's form.** The 8-step intake is hard-coded in the Flutter app, and the API just persists whatever the form sends as an opaque blob — there is no form-template subsystem on either side. A second SLT cannot author her own form without an engineer. **Fix: an intake template engine** (seam 1 below). Until then, the strongest demo recommendation is to white-label the existing form for the *next* SLT — change the practice name, drop the Speech Sanctuary tagline — but **do not change the questions**, so the underlying assumption is visibly stress-tested.

**Leak 2: paediatric is doing all the heavy lifting.** The four personas, the EHCP wiring, the "parent" vocabulary, and the triage outcomes are all paediatric-shaped. Sona will demo well to a paediatric private SLT. It will demo badly to an adult voice SLT, an AAC specialist, or anyone running a feeding clinic. There is no shame in narrowing the pitch — **paediatric private SLT** is a credible wedge — but the pitch deck and the website have to say that out loud, not pretend Sona is for "speech and language therapy, less admin" in general.

**Leak 3: the AI output schemas are tight, which is good for safety and bad for portability.** The session-plan output schema enumerates seven specialty domains. Extending to dysphagia or AAC means schema + prompt + few-shot examples + UI badge. That is doable, but the *cost* per new specialty is non-trivial, and Sona should not invite an AAC clinician to a feedback session until that work is scoped.

# 3. Unique selling point and moat

## One-sentence USP

**Sona is the AI co-pilot for private speech-and-language therapy that takes the first 30 days of every new case — intake, triage, first-session plan, parent summary — from sixty minutes of admin per case to fifteen, with a clinician review on every output and UK data residency by default.**

## One-paragraph positioning

Private speech-and-language therapy is a 1,800-clinician UK profession in which most practitioners juggle a generic practice-management tool, a Word template, and ChatGPT-in-a-browser. The result: hours per week of admin, real client data leaving the UK, and no audit trail. Sona collapses the first 30 days of every case — adaptive parent intake, consult prep, four-outcome triage, first-session plan, parent summary — into one loop, with every AI artifact labelled and clinician-reviewed before it leaves the practice. The data and the inference both stay in the UK region. The output is structured by specialty and by statutory framework, not free-text-and-pray. The clinician owns every word that reaches the family.

## Comparison table — what an SLT actually evaluates

The alternatives below are what a paediatric private SLT in 2026 is already weighing. Prices are headline, billed annually where annual pricing exists, **per practitioner per month** unless noted. Currencies preserved from the source.

<table class="competitors">
<thead>
<tr><th>Tool</th><th>What it does for an SLT</th><th>Headline price</th><th>Where it wins</th><th>Where it loses for the intake → first-session loop</th><th>Why Sona is different</th></tr>
</thead>
<tbody>
<tr>
<td><strong>ChatGPT / Claude / Gemini + a custom GPT</strong></td>
<td>Free-text drafting; clinician copy-pastes from intake email</td>
<td>£0–£20/mo</td>
<td>Familiarity; zero adoption cost; very fast</td>
<td>PHI leaves the UK and the practice's control; no audit trail; no schema, every output drifts; no structured intake</td>
<td>UK-region inference; review-gated outputs; structured intake feeds the drafting context</td>
</tr>
<tr>
<td><strong>Heidi Health</strong></td>
<td>Ambient AI scribe — generates clinical notes from a session recording</td>
<td><strong>$150 / user / mo</strong> (Clinician, annual); BAA at Enterprise</td>
<td>Strong note quality across specialties; multilingual; mature</td>
<td>Scribes a session that has already happened — does nothing for intake, triage, or first-session drafting; no UK-specific data-residency claim by default</td>
<td>Sona owns the pre-session and post-session admin loop, which Heidi by design does not</td>
</tr>
<tr>
<td><strong>Jane App AI Scribe</strong></td>
<td>Recording-based scribe inside Jane PMS, SLP sample prompts</td>
<td><strong>$15 / mo unlimited</strong>, plus 5/mo free</td>
<td>Cheapest credible AI scribe; SLP-aware prompts; HIPAA/PIPEDA/PHIPA</td>
<td><strong>Not available in the UK</strong> as of 2026-05-28; tied to Jane PMS; scribe-only</td>
<td>Available in the UK by construction; not a scribe — owns the structured first-30-days workflow</td>
</tr>
<tr>
<td><strong>Cliniko + AI-scribe add-on</strong> (PatientNotes, CliniScripts, Clindoc, Heidi, Clinic Notes AI)</td>
<td>Generic PMS with bring-your-own scribe via marketplace</td>
<td>Cliniko from ~£35 + scribe $19–$150</td>
<td>The market default; calendar + invoicing + records already exist</td>
<td>Two products, two logins, two audit trails; intake is upload-a-PDF; no SLT-specific structure</td>
<td>Sona is <strong>one product</strong> with one audit trail and SLT-specific structure — and a "Sona for Cliniko" wedge is a wedge, not a competitor (see the integration roadmap)</td>
</tr>
<tr>
<td><strong>Clindoc</strong></td>
<td>UK-friendly AI scribe + clinical documentation, GDPR + HIPAA</td>
<td><strong>£40 / user / mo annual</strong> or <strong>£5 / active day</strong></td>
<td>UK GBP billing; per-active-day pricing for variable caseloads; lighter procurement</td>
<td>Scribe-only; no intake; no triage; no parent-facing artefacts</td>
<td>Sona is the workflow product the scribe-only tools complement</td>
</tr>
<tr>
<td><strong>PatientNotes</strong></td>
<td>AI clinical notes + integrations with Cliniko and Power Diary; SLT-aware marketing</td>
<td><strong>$19 / $49 / mo</strong></td>
<td>Cheap; honest about its scope; SLT-aware copy</td>
<td>Note-taker only; no parent-facing summary; no UK-only inference posture</td>
<td>Sona is end-to-end, not bring-your-own</td>
</tr>
<tr>
<td><strong>Octopus EPR (OEPR)</strong></td>
<td>UK SLT-specific EPR — casenotes, TOMs scores, RISK, programmes, discharge letters; ASLTIP-marketed</td>
<td>Pricing not posted</td>
<td><strong>The most clinically aware UK SLT-specific competitor</strong>; designed by SLTs; speaks the domain language</td>
<td>Records-keeping tool — no AI drafting; intake is not the focus; tools-not-loops</td>
<td>Sona owns the <em>new-case</em> loop; OEPR owns the <em>ongoing-record</em> loop. Different problem, today. Same RFP, eventually.</td>
</tr>
<tr>
<td><strong>Smilenotes UK</strong></td>
<td>UK SLT PMS; clinical notes templates; UK-hosted</td>
<td><strong>From £5 / mo</strong></td>
<td>Cheapest credible UK option; GDPR-compliant; UK data centres</td>
<td>No AI; basic templates; no triage / plan / parent-summary structure</td>
<td>Sona is the AI loop that sits on top of (or alongside) a tool like Smilenotes</td>
</tr>
<tr>
<td><strong>Ogma Assistant</strong> (Ogma Therapy — acquired by SaltRoad, June 2026)</td>
<td>Records / uploads a session → AI-drafts notes (SOAP/ROCAIP), assessment reports, parent &amp; nursery summaries, onward referrals; plus kid-facing "Ogs" intervention</td>
<td>Not posted; on NHS G-Cloud 14</td>
<td><strong>The closest direct competitor.</strong> Live (iOS+Android), England-hosted, SLT-specific drafting, backed by SaltRoad's 1,000+ therapist marketplace and a proprietary atypical-child-speech ASR flywheel</td>
<td>Starts <em>at</em> the session (record → document); does not own pre-session intake, consult prep, or triage</td>
<td>Sona owns the pre-session new-case loop Ogma does not — but Ogma matches Sona's UK-residency claim and beats it on shipping and distribution. <strong>See the 2026-08-06 update above.</strong></td>
</tr>
<tr>
<td><strong>Other SLT-specific AI entrants</strong> (Constant Therapy, Better Speech "Jessica", IEP Copilot, SPRY)</td>
<td>A grab-bag of client-facing apps, IEP drafters, and US PT/SLP rehab platforms</td>
<td>Variable</td>
<td>Some are UK-friendly; some are clinically rich</td>
<td>Mostly client-facing kid-facing apps (Sona has an explicit principle against adding to children's screen time) or US-only EMR</td>
<td>Sona is adult-facing tooling that helps the SLT help the family, not another kid-app <em>(Ogma is now treated as its own row — it is not just a kid-app)</em></td>
</tr>
<tr>
<td><strong>The status quo</strong> (ChatGPT + Cliniko + Word template + email)</td>
<td>What every private SLT already does</td>
<td>Already paid for</td>
<td>Already adopted; already familiar</td>
<td>Hours of admin per week; PHI in ChatGPT; no audit trail</td>
<td>The thing Sona has to beat. The competitor in every meeting.</td>
</tr>
<tr>
<td><strong>Doing nothing</strong></td>
<td>—</td>
<td>£0</td>
<td>No change-management cost</td>
<td>Admin burnout is a documented driver of attrition out of private practice (per the design-partner interview)</td>
<td>Sona aims to be a measurable hour-a-week back</td>
</tr>
</tbody>
</table>

## Moat analysis

No single item below is a 5-year moat on its own. The strength is in the **stack**. Time-to-erosion = how long until a well-funded competitor could match this if they prioritised it.

<table class="moats">
<thead>
<tr><th>#</th><th>Candidate moat</th><th>Defensibility</th><th>Time-to-erosion</th><th>Read</th></tr>
</thead>
<tbody>
<tr>
<td>1</td>
<td><strong>Design-partner-shaped intake → triage → plan → summary <em>loop</em></strong></td>
<td>Medium-high</td>
<td>18–24 months</td>
<td>The end-to-end loop, structured by schema-validated output formats and clinician-review gates at each step, is the actual product. Replicating it requires a design-partner relationship <em>and</em> the discipline not to ship a generic scribe. Most competitors will ship the scribe.</td>
</tr>
<tr>
<td>2</td>
<td><strong>Audit trail and review-gated AI as a posture, not a feature</strong></td>
<td>Medium-high</td>
<td>18 months</td>
<td>An append-only audit log, clinician-review gates on every artifact, and a hard-coded AI-disclosure footer mean nothing can leave the system without a clinician act. That posture sells trust in a profession trained to fear AI. Heidi can match the controls; the <em>posture</em> — small clinician-first product, not enterprise scribe — is harder to copy.</td>
</tr>
<tr>
<td>3</td>
<td><strong>Specialty-aware structured outputs</strong></td>
<td>Medium</td>
<td>12–18 months</td>
<td>The seven-domain session-plan output, the EHCP flag, the four triage outcomes — these are specificity that a generic scribe will not invest in until the SLT segment is bigger. Becomes weaker as more competitors target SLT specifically (Jane App is already there for note quality).</td>
</tr>
<tr>
<td>4</td>
<td><strong>UK-region data residency + self-hosted Gemma in a London Google Cloud region</strong></td>
<td>Medium-low</td>
<td>12 months</td>
<td>A genuine differentiator vs ChatGPT and US-only Jane App. But — and this is the honest part — most clinicians cannot tell a self-hosted Gemma from a BAA-covered Vertex Gemini at the demo. Heidi already runs in-region and signs BAAs. <strong>The deployment posture is a feature for procurement, not a moat for the clinician.</strong> It buys NHS-ready <em>language</em> without buying NHS-ready <em>certification</em> (see the integration roadmap). <strong>Downgraded 2026-08-06:</strong> Ogma — the closest direct competitor — is also England-hosted and encrypted <em>and</em> already on NHS G-Cloud 14, so this is now <strong>parity, not a differentiator</strong>, against the competitor that matters most. Treat as price-of-entry. See the 2026-08-06 update.</td>
</tr>
<tr>
<td>5</td>
<td><strong>Carryover-aware parent-facing artefacts</strong> (tone slider, reading level, mandatory AI disclosure footer)</td>
<td>Medium</td>
<td>18 months</td>
<td>The parent-facing surface is the genuinely under-served space — most competitors stop at the clinician note. Becomes a stronger moat if Sona invests in the parent portal experience.</td>
</tr>
<tr>
<td>6</td>
<td><strong>Solo-practitioner-first product shape</strong></td>
<td>Low</td>
<td>6 months</td>
<td>Pleasant, not defensible. A larger competitor can ship a "solo" SKU in a quarter. The real solo-practitioner moat is <strong>price + onboarding speed</strong>, not architecture.</td>
</tr>
<tr>
<td>7</td>
<td><strong>GenUI / A2UI client architecture</strong></td>
<td>Low</td>
<td>12 months</td>
<td>Important engineering choice, not a customer-visible moat. Do not list this in a pitch deck.</td>
</tr>
<tr>
<td>8</td>
<td><strong>"Clinician-in-the-loop, always" principle</strong></td>
<td>Low (as a moat)</td>
<td>0 months</td>
<td>Every competitor in 2026 says this. Calling it a moat dilutes the real moats above. It is a <strong>price of entry</strong>, not a differentiator.</td>
</tr>
</tbody>
</table>

The net: **moats 1, 2, and 3 are real and reinforce each other** — the loop, the posture, and the specialty-aware shape. Moat 4 deserves to be marketed but is a *trust* play, not a *defensibility* play. Moats 6, 7, and 8 should be dropped from the moat conversation; they belong in the principles / engineering footnotes.

# 4. The seams to add so Sona generalises without forking

Each seam is a single named change to a single subsystem. T-shirt sizes are relative to a 2-person team.

## Seam 1 — Intake template engine (S → M)

**Today:** the 8 intake steps are hard-coded in the Flutter app; the API persists whatever the form sends. **Tomorrow:** a versioned, branded, conditionally-branching intake schema authored per practice and per specialty, stored as data, rendered by a single generic Flutter component. **What changes:** a new intake-template subsystem — a database table to hold the templates, an API service to fetch the right template for a given tenant, and a generic Flutter renderer that replaces today's hard-coded steps. **Why now:** it is the single biggest single-customer-tailoring risk and the prerequisite for every other generalisation. **Effort:** S to ship the engine with the existing 8-step paediatric template baked in as the first row; M to author a second template (adult voice) end-to-end. **Decision the founders own:** how schemas are *authored* — engineer-touch-only in source, a CMS-style editor (the design partner can edit their own), or a hybrid. Pick a side before the engineer starts.

## Seam 2 — Plan and summary template library (M)

**Today:** one output-schema family for session plans, one tone-slider for summaries. **Tomorrow:** a *domain × specialty* template family — paediatric speech-sounds, adult voice, AAC introduction, feeding, stutter, social communication — each with its own prompt fragments, synthetic few-shot examples, and acceptance metrics. Specialty becomes the **key**, not a field. **What changes:** the session-plan and parent-summary services gain a prompt-template subsystem keyed by specialty. **Why now:** this is what stops the second SLT meeting from being "that's a kid's product".

## Seam 3 — Vocabulary and statutory-framework pack (S)

**Today:** "Parent", "consult", "EHCP", "HCPC/RCSLT" are baked into strings throughout the code. **Tomorrow:** a per-tenant pack with three axes — recipient noun (parent / carer / client / patient), encounter noun (consult / appointment / session), statutory wrapper (EHCP for England, IDP for Wales, CSP for Scotland, Statement for NI, IEP for the US, NDIS for Australia, none), and regulator block (the UK pair HCPC+RCSLT vs ASHA in the US, SPA in Australia, SAC in Canada). One data file per pack; **no code** changes when adding a new jurisdiction. The Flutter app already has the localisation framework in place. **Why now:** trivial effort, large adoption-blocker removed. Cleanest "S" item on this list.

## Seam 4 — Multi-jurisdiction plumbing extensions (M)

**Today:** an architecture decision already splits the UK and US data planes. **Tomorrow** for a real US/AU launch: payments (Stripe for cards vs GoCardless for UK direct debit, chosen per tenant), HIPAA business-associate agreements with US subprocessors (already in place for the AI-inference vendor, not yet for payment or email vendors), US-specific consent wording (the data model has a slot for it; needs to be populated per jurisdiction), and a small mapping layer so US fields line up with the US healthcare-data standard (USCDI) rather than the UK one (FHIR UK Core). **Why later:** Year 2+. The MVP and the design-partner pilot do not need this; build the seams so it is not a rewrite when it lands.

## Seam 5 — Multi-tenant clinic mode (M → L)

**Today:** the team's working agreements in the MVP brief explicitly say *"Solo practitioner first. If a feature needs a 'team' concept to make sense, it's too early."* **Tomorrow:** a small-group-practice mode with **shared client list, per-clinician audit identity, shared template library, per-clinician inference budgets**. **When it becomes unavoidable:** the second time the design partner says "my associate is starting next month". Plan for it; do not build it yet. **Effort:** medium if the authentication and tenant model are set up correctly now (they appear to be — intake submissions are already tenant-scoped); large if a multi-clinician concept has to be retrofitted later.

## Seam 6 — White-label / per-practice branding (S)

**Today:** Sona brand on every parent-facing artefact. **Tomorrow:** per-tenant logo, primary colour token, practice name in the form header, sender display name. The team's portal-first parent-comms model is unaffected. **Effort:** small — Flutter theming, a per-tenant branding store on the data side, and a logo-upload endpoint. **Why now:** it removes the "that's Speech Sanctuary's form" objection in one sprint.

## Seam 7 — Specialty-aware persona library (S, ongoing)

Not a code seam, but a product seam. Today: four UK paediatric personas. Add three minimum before the first non-paediatric pitch: **adult voice (38yo gender-affirming voice), AAC introduction (5yo, non-verbal), feeding (3yo with progressed sensory profile)**. Personas drive the demo, the seed scripts, and the few-shot examples for the AI prompts. The cost of *not* adding them is showing up to the next SLT with a paediatric demo and learning nothing.

# 5. External-systems integration roadmap

Integrations are graded by **what they unlock** vs **what they cost**. "Cost" includes technical work, certification, and commercial / contracting overhead. Phasing is realistic for a two-person team plus one design partner.

## UK (priority)

<table class="integrations">
<thead>
<tr><th>Integration</th><th>What it unlocks</th><th>Cost</th><th>Phase</th></tr>
</thead>
<tbody>
<tr>
<td><strong>Calendar (Google / Outlook / iCloud)</strong> — round-trip booking for the 20-min free consult</td>
<td>Closes the biggest "two products, two diaries" pain raised in the design-partner interview.</td>
<td>Low. Standard OAuth flows. Both Google Calendar API and Microsoft Graph have well-documented patterns.</td>
<td><strong>MVP / Year 1</strong></td>
</tr>
<tr>
<td><strong>Video (Zoom, Whereby, Google Meet) deep-link generation</strong> — auto-attach a join URL to the consult slot</td>
<td>Removes the manual "send a Zoom link" step.</td>
<td>Low. Deep-link templating; no SDK needed.</td>
<td><strong>MVP / Year 1</strong></td>
</tr>
<tr>
<td><strong>E-sign (DocuSign, Dropbox Sign)</strong> — T&amp;Cs and consent on intake submit</td>
<td>Replaces the manual T&amp;Cs PDF path; better-than-tickbox audit trail.</td>
<td>Medium. DocuSign for enterprise audit, Dropbox Sign cheaper. Both have free tiers below ~5 envelopes/mo.</td>
<td><strong>Year 1</strong></td>
</tr>
<tr>
<td><strong>Payments (Stripe, GoCardless)</strong> — invoicing for the first session after triage</td>
<td>Direct revenue path. Stripe is faster to integrate; GoCardless is cheaper for UK direct debit recurring.</td>
<td>Medium. Dual-rail (Stripe for cards, GoCardless for DD) is what Cliniko already does.</td>
<td><strong>Year 1</strong></td>
</tr>
<tr>
<td><strong>Cliniko / Jane App / Power Diary push</strong> — <em>"Sona for Cliniko"</em> — write Sona's intake + plan + summary into the existing PMS record</td>
<td>Distribution wedge: stop being "a Cliniko replacement" and become "the thing that makes your Cliniko worth keeping". This is the single highest-leverage GTM bet in this memo.</td>
<td>Medium. Cliniko has a public API; Jane has documented chart-attachment endpoints. PatientNotes already demonstrates that this distribution model works for AI tooling on top of Cliniko.</td>
<td><strong>Year 1</strong></td>
</tr>
<tr>
<td><strong>NHS Login</strong> (parent identity vs magic link)</td>
<td>Parent-side identity matched to a real NHS account. Removes some magic-link friction.</td>
<td>Medium. Documented OIDC integration; vendor approval required but not gated on DSPT.</td>
<td><strong>Year 2</strong></td>
</tr>
<tr>
<td><strong>NHS DSPT — Standards Met</strong></td>
<td>Mandatory floor for anything NHS-adjacent. Confirmed <strong>Category 3 small-independent-provider self-assessment, no audit required, deadline 30 June 2026</strong>.</td>
<td><strong>Achievable for a 2-person company</strong> but requires real preparation — policy docs, asset register, Caldicott-Guardian-equivalent, backup evidence. Budget weeks not months.</td>
<td><strong>Year 2 (mandatory prereq for everything below)</strong></td>
</tr>
<tr>
<td><strong>GP Connect — Access Record: Structured</strong> (HL7 FHIR UK Core, NHS Digital)</td>
<td>Pull structured GP record into the intake brief — replaces the "type your GP's address" field. The single most valuable data enrichment available.</td>
<td><strong>High.</strong> Prereqs: DSPT Standards Met + HSCN access + PDS compliance + IG model compliance + use-case approval + SCAL evidence + RBAC + a Clinical Safety Officer compliant with DCB0129 and DCB0160. Use-case approval is the gate before development starts; testing is a multi-Gate process.</td>
<td><strong>Year 2+</strong></td>
</tr>
<tr>
<td><strong>NHS e-Referral Service (e-RS)</strong></td>
<td>Only relevant if Sona ever takes NHS-funded private referrals.</td>
<td>High. Separate procurement path; not on the critical path for a private-practice product.</td>
<td><strong>Year 2+ if positioning shifts to NHS-adjacent</strong></td>
</tr>
<tr>
<td><strong>NHS commissioning routes — G-Cloud 14, Spark DPS, NHS Digital Marketplace, direct ICB award</strong></td>
<td>Path to NHS revenue. G-Cloud listing is cheap and quick; the real cost is the buyer-side ICB procurement cycle.</td>
<td>Low listing cost; high pipeline cost (3–9 months typical ICB procurement).</td>
<td><strong>Year 2+</strong></td>
</tr>
</tbody>
</table>

## US (Year 2+)

<table class="integrations">
<thead>
<tr><th>Integration</th><th>What it unlocks</th><th>Cost</th><th>Phase</th></tr>
</thead>
<tbody>
<tr>
<td><strong>FHIR R4 + USCDI</strong> as the lingua franca</td>
<td>Anything US-integration-adjacent</td>
<td>Low if seam 4 is done correctly</td>
<td><strong>Year 2+</strong></td>
</tr>
<tr>
<td><strong>EHR connectors</strong> — Epic App Orchard, Cerner / Oracle Health CODE, Athena Marketplace, eClinicalWorks, ModMed for therapy clinics</td>
<td>The real US distribution path. Epic alone has a multi-month onboarding.</td>
<td>High — each marketplace is months.</td>
<td><strong>Year 2+</strong></td>
</tr>
<tr>
<td><strong>HIPAA BAA with GCP + subprocessors</strong></td>
<td>Lawful US PHI processing</td>
<td>Partly done — the Google Cloud BAA is in place. The team has already concluded no transactional-email vendor will sign a BAA at this scale, so parent communications are delivered via an authenticated portal (the Epic MyChart model) rather than email.</td>
<td><strong>Year 2+</strong></td>
</tr>
<tr>
<td><strong>IEP / IDEA</strong> workflow if school-district market is in scope</td>
<td>A different product really — schools-based SLT is enormous in the US.</td>
<td>High. Probably a Y3 conversation, not a Y2 one.</td>
<td><strong>Year 3+</strong></td>
</tr>
</tbody>
</table>

## AU / CA (Year 2+, brief)

<table class="integrations">
<thead>
<tr><th>Integration</th><th>What it unlocks</th><th>Cost</th><th>Phase</th></tr>
</thead>
<tbody>
<tr>
<td><strong>My Health Record + FHIR AU Base; SPA accreditation</strong></td>
<td>AU private SLT market</td>
<td>Medium — FHIR AU Base is well-documented; SPA is the regulator analogue.</td>
<td><strong>Year 2+</strong></td>
</tr>
<tr>
<td><strong>CA — SAC, provincial PHIPA / PIPEDA</strong></td>
<td>Canadian SLT market</td>
<td>Medium — Jane App's own footprint shows the path.</td>
<td><strong>Year 2+</strong></td>
</tr>
</tbody>
</table>

## Phased summary

<table class="phasing">
<thead>
<tr><th>Phase</th><th>UK</th><th>US</th><th>AU / CA</th></tr>
</thead>
<tbody>
<tr><td><strong>MVP (now)</strong></td><td>Magic link, GCS exports, in-tenant audit</td><td>—</td><td>—</td></tr>
<tr><td><strong>Year 1</strong></td><td>Calendar + video + e-sign + payments + "Sona for Cliniko"</td><td>—</td><td>—</td></tr>
<tr><td><strong>Year 2</strong></td><td>NHS Login + DSPT Standards Met</td><td>FHIR R4 / USCDI scaffolding</td><td>—</td></tr>
<tr><td><strong>Year 2+</strong></td><td>GP Connect + e-RS + G-Cloud listing</td><td>EHR connectors (Epic, Cerner, Athena)</td><td>MHR / FHIR AU; SPA; PHIPA</td></tr>
<tr><td><strong>Year 3+</strong></td><td>ICB direct award</td><td>IEP / IDEA school-district workflows</td><td>—</td></tr>
</tbody>
</table>

# 6. Authentication and security

Sona's commercial story depends on a defensible trust posture. This section pulls together what is in place today, what is designed but not yet built, and where the gaps are. Most of this is sourced from the team's architecture decisions and is mentioned in passing elsewhere in the memo — it lives in one place here so an investor or NHS commissioner does not have to assemble it from fragments.

**Identity.** Parents authenticate via signed, time-limited magic links sent to a verified email at intake submission; each link is single-use and the parent portal is the only place clinical content is rendered (no PHI in email bodies). Clinicians authenticate via passkeys / WebAuthn — no shared passwords, no SMS one-time codes. A future migration to NHS Login for parents is a documented Year-2 integration. Every published artifact carries the clinician's HCPC registration number on its audit trail.

**Data residency and AI inference.** UK tenant data lives only in the London Google Cloud region — database, file storage, audit logs, and AI inference all pinned to the same region. AI inference runs on a self-hosted open-weights model inside a private network with no external internet egress; client data never reaches a third-party AI vendor. US tenants (when launched) get a physically separate stack in a US region; cross-jurisdiction queries, backups, and analytics on raw clinical data are forbidden by an architecture decision.

**Audit and AI disclosure.** Every clinical artifact is constructed so it cannot leave the system without a clinician act: an append-only audit log records who accessed which case, when, and what changed, with 7-year retention; review gates require a clinician timestamp before any AI draft can be published; a hard-coded AI-disclosure footer sits at the bottom of every parent-facing summary and cannot be removed by the clinician. Audit data is non-mutable at the application layer.

**Encryption and subprocessors.** TLS 1.2+ in transit. Encryption at rest by default, plus customer-managed encryption keys (CMEK) on UK clinical data. A public subprocessor list is maintained and refreshed when any vendor changes. Email-as-channel is rejected for clinical content because no transactional-email vendor will sign a BAA at this scale — parent communications go via the authenticated portal (the Epic MyChart model).

**Compliance posture.** UK GDPR Article 9 lawful basis (explicit parent consent for special-category child data, plus clinician legitimate interest) is captured on the intake review screen and versioned per submission. Children's data is collected only at the level needed for clinical triage. DSAR (data-subject access request) and right-to-erasure endpoints are first-class. A documented 72-hour ICO breach-notification runbook is in place.

**What is not done yet.** NHS DSPT Standards Met, HIPAA BAA audit for any new payment / email vendors, a third-party penetration test, and a formal Data Protection Impact Assessment (DPIA). All four are Year-2 prerequisites for the NHS path and are called out as such in the integration roadmap (section 5). None are blockers for the private-practice pilot.

# 7. Pricing options

## Cost-side reality check

Per the team's architecture, Sona runs a single mid-tier GPU in the UK Google Cloud region for the AI inference. Each case triggers up to three inference passes: prep brief, session plan, parent summary. Per-case token budgets total roughly **10–15K tokens of input + 3K of output**, twice over (the parent summary runs a second simplification pass to hit a target reading age). A single L4 supports ~4 concurrent jobs; on-demand GCP L4 reservation rates put per-case inference cost in the **single-digit pence range at scale, mid-double-digit pence at MVP utilisation**. This is a directional figure — the founders should price-validate it against the bill before pricing materially below £49 / clinician / mo.

At the design partner's stated 3–8 cases / week / clinician, inference cost per clinician per month is in the **£10–£25 range, not the £200 range**. That keeps gross margin healthy at any of the per-clinician price points below.

## Pricing options scored

<table class="pricing">
<thead>
<tr><th>Model</th><th>Target segment</th><th>Headline price</th><th>What's included</th><th>Gross margin (directional)</th><th>Pros</th><th>Cons</th></tr>
</thead>
<tbody>
<tr>
<td><strong>A — Per-clinician monthly subscription (recommended)</strong></td>
<td>ASLTIP-member solo and 2–3 person practices</td>
<td><strong>£79 / clinician / mo</strong> annual, <strong>£99 monthly</strong></td>
<td>Unlimited intakes, AI drafting on a soft cap (e.g. 30 cases/mo), parent portal, audit trail</td>
<td>75–85% at typical volume</td>
<td>Predictable revenue; matches how Heidi, Jane, Clindoc, Smilenotes already bill; clinician understands the unit</td>
<td>Has to be "worth a Cliniko seat" — £79 is below Cliniko's own £45 + a £40 scribe combination, so it stays defensible</td>
</tr>
<tr>
<td><strong>B — Per-case (intake → first-session loop)</strong></td>
<td>Practices with very variable caseload (new graduates, returners)</td>
<td>£15–£25 / case</td>
<td>Single completed loop</td>
<td>Variable; lower at low volume</td>
<td>Aligns price to value; low-risk for new practices</td>
<td>Disincentivises high-volume usage; revenue too volatile to plan against; Sona's whole reason-to-exist is to <em>increase</em> throughput</td>
</tr>
<tr>
<td><strong>C — Freemium</strong></td>
<td>Top-of-funnel awareness; ASLTIP new-grads</td>
<td>First 5 cases / mo free; £49 / mo after</td>
<td>Free tier capped at 5 cases</td>
<td>Marketing line; not a revenue line at scale</td>
<td>Distribution; brings clinicians in via a friend</td>
<td>Cannibalises (a) — small practices stay in free tier; high free-tier inference cost</td>
</tr>
<tr>
<td><strong>D — NHS framework procurement (G-Cloud 14 / DPS)</strong></td>
<td>NHS-adjacent later</td>
<td>£15–£25k / ICB / year (typical small-tool framework)</td>
<td>Whatever scope an ICB tenders</td>
<td>Higher gross margin but longer DSO</td>
<td>Bigger ACV; multi-clinician deployment</td>
<td>Different sales motion; gated on DSPT + GP Connect (see roadmap); is a Y2+ conversation</td>
</tr>
<tr>
<td><strong>E — Per-practice flat + seat add-ons</strong></td>
<td>The growth path for design partners onto small clinic mode</td>
<td><strong>£149 / practice base + £49 / additional seat</strong></td>
<td>Base = 1 clinician's loops; seats = additional clinicians</td>
<td>Highest gross margin at clinic scale</td>
<td>Supports the multi-tenant clinic-mode seam; good investor narrative on expansion revenue</td>
<td>More complex billing; needs the clinic-mode work to land first</td>
</tr>
</tbody>
</table>

## Recommended starting model

**Pick A with a tiered headline:** £39 "Starter" (cap 5 cases/mo; new-grad / returner / ASLTIP-affiliate path), **£79 "Practice"** (the default; cap 30 cases/mo), £149 "Practice+" (no cap; priority support). Move to model E (per-practice + seats) **only when the second clinician at the design-partner practice signs**, not before. Avoid (B) and (C) until the price-sensitivity of the ASLTIP base is measured. Pursue (D) only after DSPT in Year 2.

**Why £79 and not £49 (Clindoc) or £99 (Heidi Pro era):** Sona is not a scribe-only product, so it should not be priced like one. £79 sits exactly between Smilenotes (£5, no AI) and Heidi Clinician (~£120 GBP, scribe-only) and quantifies the bundle: PMS-light + AI loop + UK residency + audit. The price-anchor effect of being deliberately "between" two known reference points helps the discovery call.

# 8. Market size and growth path

Sona has three concentric markets, each with a different shape. All figures below are directional sketches from public membership data and the team's pricing recommendation, not primary survey data — they should be tightened with a willingness-to-pay study before being put in a deck.

**Wedge: UK private SLT (Years 1–2).** ASLTIP lists ~1,800 members; another ~500–1,000 independents work outside it. At the recommended £79 / clinician / month, the UK private-SLT vertical is **~£2.4M ARR at 100% capture**. A realistic 5-year ceiling of 15–25% capture is **£350–600k ARR** — a profitable 2–5 person business, but below the bar for a venture return on its own.

**Expansion: NHS and clinic mode (Years 2–4).** Clinic mode (£149 base + £49 / seat) lifts average revenue per practice 2–3x. DSPT + a G-Cloud listing opens ICB-level deals at typical small-tool framework sizes of **£15–25k per ICB per year** (England has 42 ICBs). 8–12 ICB wins over Years 3–4 add **£120–300k of NHS ARR** on top of the private base. UK ceiling at this stage: **~£1.5–2.5M ARR**.

**Prize: US, AU, CA (Year 3+).** US private-practice SLPs number around 25,000 — roughly 10x the UK (ASHA workforce data, ~14% of certified SLPs in private settings). At equivalent pricing that is a **~£20–25M ARR ceiling**. Distribution is the bottleneck; the realistic entry is the Jane App and Cliniko marketplaces (the "Sona for Cliniko" wedge from section 5), not direct sales. AU + CA add another **~£3–4M ARR ceiling**.

**What this implies for investment.** Year-1 milestones (20–50 paying clinicians, £20–50k ARR) are reachable on **seed funding of £400–800k** for an 18-month runway for a 2–3 person team. The clinic-mode + DSPT bet is the **Series A test**: 10–15% UK base capture plus 3–5 NHS framework wins inside two years puts the company on a credible **£5–10M ARR trajectory** by Years 4–5.

**Honest read.** The UK private-SLT market alone sustains a profitable small business, not a venture return. The investable thesis hinges on the **Cliniko marketplace wedge proving the model in the UK, then porting to Jane App for US distribution (10x the market)**. Without that distribution mechanic, Sona is bootstrappable but not venturable.

# Recommendations — what to do in the next 30 / 60 / 90 days

Ordered by leverage. Day windows are windows, not deadlines — the slice that fits the team's actual capacity is the right one.

1. **(Days 1–14) Run the one-therapist-fit audit with a second SLT.** Specifically: an SLT outside the design-partner practice, ideally adult voice or AAC, ideally an ASLTIP member. Use the audit table above as the agenda; ask them to walk the demo and call out leaks. **Owner:** founders. **Effort:** 1 working day of prep + 90 minutes interview. **Metric:** at least 5 leaks confirmed, at least 2 contradicted (i.e. *not* a problem for that SLT).
2. **(Days 1–30) Ship seam 6 (white-label branding) and seam 3 (vocabulary pack).** The smallest possible product changes that remove the "that's Speech Sanctuary's form" objection. **Owner:** engineering. **Effort:** S each. **Metric:** the demo runs end-to-end under a fictional second-practice name, with no Speech Sanctuary string visible.
3. **(Days 15–60) Pick one of: intake template engine (seam 1) OR the AI-loop completion — i.e. shipping the prep brief, session plan, and parent summary end-to-end with real model output rather than stub content. Not both.** This is the single biggest engineering decision in the next quarter. The template engine generalises the product. The AI loop completes the demo's most fragile claims. The wrong call is to try to do both at half-speed. **Owner:** founders. **Effort:** decision-only this sprint; M–L next quarter.
4. **(Days 30–60) Stand up a costed DSPT readiness plan with a specialist consultancy.** Three quotes; choose one; book the work for the autumn. DSPT is the gate for everything NHS-adjacent and is achievable as a self-assessment — but real evidence files, an asset register, and a backup-restore drill take preparation. **Owner:** founders. **Effort:** half a day of vendor calls. **Metric:** chosen consultancy, scoped quote.
5. **(Days 30–90) Approach ASLTIP about a member-benefit slot or directory listing.** ASLTIP markets to 1,800 of the highest-quality UK private SLTs and explicitly hosts events that surface tooling (OEPR, the most clinically aware UK competitor, markets via ASLTIP events). A discounted listing or a co-marketed launch is the single highest-leverage GTM move available. **Owner:** founders. **Effort:** S. **Metric:** a meeting with the ASLTIP board.
6. **(Days 60–90) Build "Sona for Cliniko" — write the intake brief, plan, and summary into a Cliniko patient record.** Stop competing with Cliniko; complement it. PatientNotes' existence on Cliniko's connected-apps marketplace is proof the distribution model works. This converts every Cliniko-using ASLTIP member into a prospect rather than a defended account. **Owner:** engineering. **Effort:** M. **Metric:** one paying clinician using both products in production.

# Open questions for the founders

In priority order; each blocks something downstream.

1. **Is the next bet generalisation (intake template engine) or completion (AI loop end-to-end)?** Both at half-speed is the failure mode (Recommendation 3).
2. **What is the actual paying-customer hypothesis: paediatric-only private SLT, or all-of-SLT-on-launch?** The honest answer changes everything in section 2 and the pitch deck. The current personas and the EHCP wiring suggest paediatric-only is the truthful framing.
3. **Are you willing to be priced below Heidi and above Smilenotes, or do you want a wedge price?** £79 / clinician / mo is a defensible middle. A £29 wedge price changes the product (closer to Smilenotes) and the moat conversation (less "premium UK posture", more "low-cost ASLTIP default").
4. **DSPT — Year-2 commit or Year-3 "wait and see"?** A real DSPT commit unlocks GP Connect, NHS Login, and the G-Cloud listing in series. A wait-and-see lets the product mature on private-pay first. Both are defensible; the deck cannot be vague about which one.
5. **OEPR (Octopus EPR) — competitor, co-existent, or eventual partner?** OEPR is the most clinically aware UK SLT-specific competitor surfaced in this review. They market via ASLTIP. The interesting future is a Sona-on-OEPR integration, not a Sona-vs-OEPR fight. The founders need to decide whether to reach out now or later.
6. **Multi-tenant clinic mode — explicit non-goal for 2026, or a Q4 2026 build?** The design-partner relationship will demand it once a second clinician joins the design-partner practice.
7. **Persona expansion — agreed scope of three new personas (adult voice, AAC, feeding) before the next external pitch?** Without this, every non-paediatric meeting is uphill.
8. **Ogma / SaltRoad — compete, complement, or rethink? (Added 2026-08-06.)** Ogma is the closest direct competitor: live, England-hosted, on NHS G-Cloud 14, backed by SaltRoad's 1,000+ therapist marketplace and a proprietary atypical-child-speech ASR flywheel. Three postures, and the founders must pick one before the pitch deck goes out: (a) **compete** by owning the pre-session new-case loop (intake → triage → consult prep) that Ogma does not touch, for independent SLTs who won't route clients through a marketplace; (b) **complement** — write Sona's structured intake/triage into whatever the SLT documents with, treating Ogma as a downstream target not a rival; (c) **rethink** whether the AI-admin thesis is still investable now that a funded, distributed incumbent exists. See the 2026-08-06 update for the full analysis.

# Glossary

For readers new to UK private speech-and-language therapy. Skip if these are familiar.

**Speech and language therapy**

- **SLT** — speech-and-language therapist (UK / Ireland / Australia).
- **SLP** — speech-language pathologist (US / Canada equivalent of SLT).
- **AAC** — augmentative and alternative communication; tools and techniques for clients who can't rely on speech (symbol boards, eye-gaze devices, speech-generating apps).
- **SENCO** — Special Educational Needs Co-ordinator; the teacher in a UK school responsible for SEN provision.
- **TOMs** — Therapy Outcome Measures; a standardised UK clinical outcome-tracking framework used in SLT.

**Statutory plans for children with additional needs**

- **EHCP** — Education, Health and Care Plan (England). Legally binding document setting out a child's SEN provision.
- **IDP** — Individual Development Plan (Wales). Welsh equivalent of EHCP.
- **CSP** — Co-ordinated Support Plan (Scotland). Scottish equivalent.
- **IEP / IDEA** — Individualized Education Program, issued under the US Individuals with Disabilities Education Act.
- **NDIS** — National Disability Insurance Scheme (Australia). Funds disability supports including SLT.

**Regulators and professional bodies**

- **ASLTIP** — Association of Speech and Language Therapists in Independent Practice (UK). ~1,800 members; the directory most UK private SLT clients find their therapist through.
- **HCPC** — Health and Care Professions Council. UK statutory regulator; all UK SLTs must be HCPC-registered.
- **RCSLT** — Royal College of Speech and Language Therapists. UK professional body that sets clinical standards.
- **ASHA** — American Speech-Language-Hearing Association. US equivalent of HCPC + RCSLT combined.
- **SPA** — Speech Pathology Australia.
- **SAC** — Speech-Language and Audiology Canada.
- **CORU** — the Health and Social Care Professionals Council of Ireland.

**NHS and UK integration standards**

- **GP** — General Practitioner; UK family doctor. Equivalent to a US PCP (primary care provider).
- **NHS** — National Health Service. UK state healthcare system.
- **DSPT** — NHS Data Security and Protection Toolkit. Mandatory annual self-assessment for any organisation accessing NHS data.
- **ICB** — Integrated Care Board. NHS bodies that commission local services; the procurement counterparty for NHS contracts.
- **GP Connect** — NHS England's API suite (FHIR UK Core) for reading structured data from GP record systems.
- **HSCN** — Health and Social Care Network. The private NHS network; GP Connect callers must be on HSCN.
- **PDS** — Personal Demographics Service. NHS patient-identity register.
- **CSO** — Clinical Safety Officer. The accountable individual for clinical risk under NHS standards.
- **DCB0129 / DCB0160** — NHS clinical risk-management standards for manufacturers (DCB0129) and deploying organisations (DCB0160).
- **SCAL** — Supplier Conformance Assessment List. The evidence document NHS Digital uses to assure suppliers connecting to NHS APIs.
- **e-RS** — NHS e-Referral Service. The booking platform for NHS-funded referrals.
- **G-Cloud** — UK government framework for buying cloud services from approved suppliers. G-Cloud 14 is the current edition.
- **DPS** — Dynamic Purchasing System. Another UK public-sector procurement framework.

**Healthcare data and privacy standards (international)**

- **FHIR** — Fast Healthcare Interoperability Resources. The global standard data format for exchanging healthcare records. UK Core and AU Base are national variants.
- **USCDI** — United States Core Data for Interoperability. The US equivalent.
- **HIPAA** — US Health Insurance Portability and Accountability Act. Governs US patient-data handling.
- **BAA** — Business Associate Agreement. The contract a US healthcare provider must have with any vendor that touches patient data, under HIPAA.
- **PHI** — Protected Health Information. The HIPAA-defined category of patient data.
- **GDPR** — General Data Protection Regulation. The UK / EU equivalent. "UK GDPR" is the post-Brexit UK version.
- **PHIPA** — Personal Health Information Protection Act (Ontario, Canada).
- **PIPEDA** — Personal Information Protection and Electronic Documents Act (Canada-wide).

**Practice tooling**

- **PMS** — Practice Management System. The category of tool that holds the diary, the patient list, and the invoices (Cliniko, Jane App, Power Diary, Smilenotes, etc.).
- **EPR / EHR** — Electronic Patient Record / Electronic Health Record. The category that holds clinical notes and records.
- **OEPR** — Octopus EPR. A UK SLT-specific electronic patient record, marketed via ASLTIP.
- **MyChart** — Epic Systems' patient portal. The reference design for delivering clinical content to patients via authenticated portal rather than email.
- **Ogma / Ogma Assistant** — UK AI documentation tool for SLTs (notes, reports, parent summaries, referrals) plus kid-facing "Ogs" intervention agents; acquired by SaltRoad in June 2026. Sona's closest direct competitor — see the 2026-08-06 update.
- **SaltRoad** — UK two-sided marketplace matching families to SLTs, with a network of 1,000+ therapists; acquirer of Ogma (June 2026).
- **SOAP / ROCAIP** — standard clinical-note formats (Subjective-Objective-Assessment-Plan; and an SLT-oriented variant) that the Ogma Assistant generates.

# Sources

## Internal source artefacts (non-public, team repository)

- **MVP brief** — original positioning, scope, design-partner interview synthesis.
- **Feedback-demo brief** — the "real today vs 90-day vision" split that underpins every honesty claim in this memo.
- **Intake-form specification** — the 8-page Speech Sanctuary parent questionnaire the MVP form is built from.
- **AI design notes for triage, session-plan, and parent-summary** — output schemas, prompt structures, target metrics.
- **Five architecture decision records** covering data residency, the Flutter front-end, the self-hosted AI model, environment access controls, and portal-first parent communications.
- **Architecture overview** — UK/US split, region pinning, business-associate-agreement chain.
- **Four synthetic demo personas** — 4-year-old speech-sounds, 7-year-old stutter with EHCP, 11-year-old social communication, 3-year-old feeding.
- **Flutter app and API source for the parent intake form** — the current hard-coded eight-step flow.

## Web sources (URL + access date, all 2026-05-28)

- Heidi Health Clinician plan ($150/user/mo) — *veroscribe.com/blog/heidi-health-review-2026*
- Heidi Health, second pricing source — *deepcura.com/resources/heidi-health-review*
- Heidi Health SLP assessment template — *heidihealth.com/templates/review-speech-pathology-assessment*
- Jane App AI Scribe ($15/mo, US+CA only) — *jane.app/features/charting-ai-scribe*
- Jane App AI Scribe — guide — *jane.app/guide/ai-scribe*
- Cliniko connected-apps and AI marketplace — *wisevu.com Cliniko Review*
- Cliniko form upload — *help.cliniko.com upload-form-templates*
- Clindoc UK pricing (£40 / £5 active day) — *clindoc.ai/pricing*
- PatientNotes for speech therapists — *patientnotes.app/professions/speech-therapist-st*
- Octopus EPR (OEPR) — *oepr.co.uk*
- Smilenotes UK — *smilenotes.co.uk/profession/speech-therapy-software*
- ASLTIP membership statistics — *asltip.com* and *asltip.com/why-join*
- NHS GP Connect Access Record: Structured (FHIR API) — *digital.nhs.uk/developer/api-catalogue/gp-connect-access-record-structured-fhir*
- NHS GP Connect — Consumer Assurance Process — *github.com/nhsconnect/gpc-consumer-support*
- NHS DSPT — Standards Directory — *standards.nhs.uk/published-standards/data-security-and-protection-toolkit*
- DSPT 2025/26 small-org guide — *dsptready.co.uk/blog/dspt-complete-guide*
- Evalian DSPT 2025 guide — *evalian.co.uk/the-data-security-and-protection-toolkit-dspt*
- Chatter Labs — adjacent SLT AI landscape — *chatter-labs.com/blog/slt-private-practice-setup-tips/ai-speech-therapy*

## Web sources for the 2026-08-06 Ogma / SaltRoad update (URL + access date, all 2026-08-06)

- Ogma Therapy — product site — *ogmatherapy.com*
- Ogma Assistant — how it works (notes/reports/parent summaries; SOAP, ROCAIP, referrals; ~3hr→3min; England-hosted) — *ogmatherapy.com/post/how-does-the-ogma-assistant-work*
- Ogma Assistant joins NHS G-Cloud 14 — *ogmatherapy.com/post/the-ogma-assistant-joins-nhs-g-cloud-14*
- Ogma Assistant — G-Cloud 14 service definition — *assets.applytosupply.digitalmarketplace.service.gov.uk/g-cloud-14/documents/721948/...service-definition-document*
- Ogma — why it exists / the Ogs / phoneme-level ASR on atypical child speech — *ogmatherapy.com/post/why-ogma-exists-revolutionising-speech-and-language-therapy-with-ai*
- Founders Factory — launching Ogma (Ogs, proprietary dataset, founders) — *foundersfactory.com/articles/launching-ogma*
- Ogma Therapy Ltd — DigitalHealth.London innovation directory — *digitalhealth.london/innovation-directory/profile/ogma-therapy-ltd*
- Ogma apps (live, iOS + Android) — *apps.apple.com/app/ogma-therapy/id6740515626* and *play.google.com/store/apps/details?id=com.ogmatherapy*
- SaltRoad raises £1.5M and acquires Ogma (June 2026; Techstart Ventures lead; Ascension, ScaleX, angels; 1,000+ therapists) — *tech.eu/2026/06/30/saltroad-raises-ps15m-and-acquires-ai-platform-ogma-to-scale-speech-therapy-for-children*
- SaltRoad — earlier £575k pre-seed / marketplace model — *uktech.news/medtech/saltroad-speech-language-therapy-funding-20240705*

# Engineering footnotes

- **Intake template engine concrete shape.** A new database table holds versioned, per-tenant, per-specialty intake schemas (id, tenant, specialty, locale, version, steps, branches, vocabulary-pack reference). The Flutter renderer reads the steps and dispatches to widget types keyed by field kind (text, date, multi-select, yes/no-with-detail, composite GP details, consent block). The current 8-step form ships as the first row, version `v1-paediatric-uk`. The AI context window for prep brief / session plan / summary already operates on the form's answers blob rather than on hard-coded step IDs — so the template engine is purely a client + per-tenant authoring change, not an AI-context change.
- **Self-hosted Gemma economics.** L4 24 GB INT4 AWQ Gemma 3 27B in the London Google Cloud region. Per the AI architecture decision, 4 concurrent jobs / GPU; per-job P95 ≤ 8 s (prep) + ≤ 15 s (plan) + ≤ 20 s (summary). At an L4 reservation rate and pilot caseload (design partner ≈ 8 cases/wk ≈ 32/mo), per-clinician inference cost is in the **£10–£25/mo** range, dominated by reservation rather than utilisation. At 50 clinicians on the same L4, marginal per-clinician cost compresses below £5.
- **GP Connect — concrete onboarding shape.** Per NHS Digital, retrieved 2026-05-28: prereqs are DSPT Standards Met + HSCN access + PDS-compliant identity (or third-party PDS proxy) + IG model compliance + RBAC + CSO appointment compliant with DCB0129 + DCB0160. Onboarding = use-case submission → approval → 6-month dev window → SCAL evidence → multi-Gate testing (test environments per Gate) → go-live. The self-hosted AI stack is irrelevant to GP Connect onboarding; the API and tenant-routing layers are where the FHIR R3 client lives.
- **OEPR and Cliniko on the same diagram.** OEPR is a domain-specific record system; Cliniko is a generalist PMS with an AI-scribe marketplace. Sona's natural position is on the **A2UI / read-modify side**, not on the records side — i.e. Sona writes intake/plan/summary objects into whichever record system the practice runs (OEPR via TOMs-aware mapping; Cliniko via patient-form templates + chart notes). Treat OEPR as a future read/write target, not a competitor to be displaced.
