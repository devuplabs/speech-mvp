# Cross-critique — Cursor-slot substitute (technical due-diligence lens)

**By:** substitute red-team critic (DEV-140) · **Targets:** `proposals-codex-substitute.md`, `proposals-claude.md` · **Date:** 2026-08-25
**Method note:** I read PROTOCOL.md, CONTEXT.md, R1–R4, and both target files only (no other critiques), then audited the actual code: `/home/user/speech-mvp/apps/api/src` and `/home/user/speech-ml`. My lens: does the code actually deliver what the "asset leverage" bullets claim?

**Code ground truth (applies to all 8 candidates; proposers, adjust your claims):**

1. **The "review-gate" does not exist as a gate.** `services/parent-summary.ts` stamps `reviewedAt: new Date()` *automatically inside the same call that generates the LLM draft* (`publishParentSummary`, lines ~135–150). There is no approve endpoint, no reviewer identity (audit `actor` is the hardcoded string `"clinician"`), no edit-diff or sign-off record. It is a review *stamp*, not a gate. Making it evidence-grade (reviewer ID, versioned edits, explicit approval step) is ~1–2 engineer-weeks — but every "review-gate transfers whole" claim is currently false.
2. **PHI routes are unauthenticated-by-design.** `routes/v1.ts` says it in comments (lines ~626–663): FHIR export, DSAR, legal-hold, parent summaries and all case routes ship with "TODO(DEV-31/auth)". Firebase auth middleware exists (`auth/middleware.ts`) but is wired only to `/practices`. Budget 2–3 engineer-weeks of auth/RBAC before *any* candidate touches real client data.
3. **The audit trail is genuinely excellent** — the one under-claimed asset. `drizzle/0009_audit_append_only.sql` enforces append-only at the DB level (trigger + `REVOKE UPDATE, DELETE`), with a sanctioned 7-year retention path (`services/audit-retention.ts`) and de-duplicated read-access auditing (`services/audit.ts`). This survives cross-examination. It transfers.
4. **The AI layer is stubbed and triage is human.** All four artifact services fall back to `modelId: "mvp-stub"`; `POST /cases/:caseId/triage` just inserts a clinician-chosen enum. The product has **no AI triage path** — only the harness has an eval-only triage prompt (`eval/runner/prompts.py:143`).
5. **"7 statutory frameworks encoded" means a 7-value enum.** In `speech-ml/personas`, `statutory_framework` is metadata: **44 of 54 personas are `none`; `ehcp` appears twice; `iep_idea` three times.** There is no Section F content, no statutory-wording golden anywhere. Goldens are one-line gist strings (~10 words) scored by ≥0.4 content-word overlap, plus zod structure checks, a British-English word ban, and triage-enum match (`eval/runner/score.py`, README). CI runs **stub mode only** ("stub numbers check plumbing and prompt parity, not model quality" — speech-ml README). And **50 of 54 personas are `status: draft`**; only 4 are clinician-reviewed. Jurisdictions: 37 England, 6 US, 4 CA, 2 AU, 5 other. The harness is a real, well-engineered *regression scaffold*; it is not yet a clinical benchmark, a safety case, or a statutory QA engine.

---

## Codex-sub — Candidate 1: US evaluation-report engine

- **Verdict:** SURVIVES (with corrected asset math)
- **Evidence audit:** Strongest revealed-spend case in either file, and it checks out: Evalubox really sells at $5/credit PAYG with $12.50/mo tiers ([evalubox.com/pricing](https://www.evalubox.com/pricing/)), and the IDEA 60-day forcing event is real. Nothing stated-preference here; the price envelope is inherited from live competitors. Honest flag: Evalubox's smallness may mean small market, and the proposer says so.
- **Distribution audit:** Creator sponsorship + free calculator → owned list is R3-consistent and 2-person-sized. Weakness: rented until the list exists, and the proposer's own R3 rule says so. Acceptable.
- **Moat audit:** "Clinician-graded golden corpus" is a *future* asset — today there are zero graded US reports, zero psychometric-score content in any persona (`intake_answers` carry names and ages, not CELF scaled scores). The moat is a plan, not a holding.
- **Feasibility audit:** "54 UK-weighted personas partially transfer (2 of 8 jurisdictions US-relevant)" — actually **6 US personas, 3 `iep_idea`, none containing test data**. Honest MVP: 9–12 engineer-weeks plus real US-clinician grading time, after the auth and review-gate debts. Concierge validation needs ~0 code, which saves the candidate. Publisher-IP risk (reproducing Pearson interpretive content) is unaddressed — Claude C4 handles this better.
- **Steelman fix:** Merge with Claude C4 (below); start scoring-adjacent (deterministic LSA/score interpretation) and grow into full reports as the graded corpus accumulates.
- **What the proposer missed:** R1 lists Ambiki — ASHA corporate partner with IEP integration — one templating sprint from this product. First-mover window is narrower than implied.

## Codex-sub — Candidate 2: Expert-report capacity network (tribunal/IEE)

- **Verdict:** SURVIVES
- **Evidence audit:** Admissible on both sides: £900–1,400 parent fees (R4-cited), INNEG's 328-expert panel proving brokerage margin exists, 4–6-week turnarounds as the pain. The US IEE mirror is thinner — one settlement anecdote — but UK alone carries the test.
- **Distribution audit:** Education-law firms are R3's near-zero-saturation channel and genuinely BD-callable by two people. Correctly notes the competitor's clinician-channel capture is irrelevant here.
- **Moat audit:** Two-sided network takes years; the honest near-term moat is *provenance as a legal feature* — and this is the one candidate where the code actually backs the claim: the DB-level append-only audit trail (finding #3) is real and rare. But the review-gate half of "provenance" needs the 1–2 weeks of completion first (finding #1) — an unsigned `reviewedAt` timestamp stamped at publish would embarrass you under cross-examination.
- **Feasibility audit:** Validation is zero-code BD — excellent. Supply is correctly named as the killer risk; a 21%-vacancy economy means clinicians refuse overflow. Scope honesty is good: the production engine (6–10 engineer-weeks) can follow revenue.
- **Steelman fix:** None required for the test; for the build, complete the review-gate before marketing "audit-defensible."
- **What the proposer missed:** Claude C1 is the same statutory artifact sold tool-first instead of marketplace-first — synthesis must pick one entry motion, and tool-first has no supply-side cold-start.

## Codex-sub — Candidate 3: Medicaid clean-claims OEM layer

- **Verdict:** MAJOR REVISION
- **Evidence audit:** The dollars are real and verified — NYC alone failed to collect up to $431.6M, with $132.8M attributed to missing documentation ([NYC Comptroller, Jul 2026](https://comptroller.nyc.gov/newsroom/press-releases/comptroller-audit-finds-nyc-schools-failed-to-collect-up-to-431m-in-medicaid-reimbursements-for-special-education-services/)); contingency-fee vendors exist (GAO). Best macro-evidence in the portfolio.
- **Distribution audit:** OEM-to-a-dozen-vendors is countable, but the proposer's own riskiest-assumption admits the flaw: vendors with 3–25% contingency margins and engineering teams will *build* a margin-critical layer, not rent it. B2B2B partner sales at 2-person scale routinely takes 6–12 months — past bootstrap patience.
- **Moat audit:** A "50-state claim-eligibility golden corpus under deterministic CI" does not exist and is the product's entire value; the harness contributes schema and CI plumbing only (finding #5). That corpus is months of paralegal-grade state-rule work with ongoing upkeep.
- **Feasibility audit:** "5-minute demo from the existing platform (no new code beyond prompts)" is optimistic — the platform has no session-logging workflow and no Medicaid rules; a credible demo is 1–2 weeks. Real MVP inside a vendor's rails: 14–20+ engineer-weeks plus likely SOC 2 demands. Largest build in the portfolio; discards nearly all persona content.
- **Steelman fix:** Demote to a partnership *option*: run the outbound test as discovery, build nothing past the demo until a vendor pays a deposit, and let the (good) kill criterion execute.
- **What the proposer missed:** Ambiki and Frontline both sit closer to this data than any outsider; R1's channel-inheritance lesson cuts against a UK team here, not for it.

## Codex-sub — Candidate 4: Agent-app-store SLP workbench

- **Verdict:** MAJOR REVISION
- **Evidence audit:** SLPs using ChatGPT for admin is admissible behavior (AJSLP survey). But the monetization substrate is overstated: as of now, Apps SDK in-app payment is **not generally available** — external checkout approval is currently limited to physical goods, with agentic checkout "coming in 2026" ([OpenAI Apps SDK docs](https://developers.openai.com/apps-sdk/build/monetization), [community thread](https://community.openai.com/t/clarity-on-monetization-policy/1380478)) — and OpenAI's health surface is being pulled into its own ChatGPT Health experience with restrictive health policies ([WebFX summary](https://www.webfx.com/blog/healthcare/chatgpt-advertising-for-healthcare/)). The proposal's Stripe-link workaround survives, but "in-chat commerce arriving" is doing load-bearing work it can't hold.
- **Distribution audit:** Empty niche, yes; but ranking/discovery mechanics in the directory are opaque and platform-revocable. R3 called it a lottery ticket; the proposer's rebuttal ("cheapest channel experiment") is fair *as an experiment*, not as a pivot.
- **Moat audit:** "Compliance posture as the paywall" requires the Pro backend to exist: auth (absent, finding #2), BAA execution, and a hardened LLM path. The free tier has near-zero switching cost and the host model cannibalizes it continuously.
- **Feasibility audit:** De-identified workbench in days: plausible (3–5 engineer-weeks to done-well). Harness leverage is marginal — regression-testing prompts, nothing more. Flutter and most of the platform are discarded; this candidate leverages posture, not code.
- **Steelman fix:** Reclassify as a **£500 channel probe that feeds Candidate 1's email list** — run it, but it cannot absorb the company. The proposer half-concedes this in the wedge section.
- **What the proposer missed:** ChatGPT Health (Jan 2026) means the platform itself is the fastest-funded competitor inside this channel.

## Claude — Candidate 1: Section F tribunal report engine

- **Verdict:** SURVIVES (with asset claims corrected)
- **Evidence audit:** Clean: 25k appeals, 99% win rate, £900–1,400 fees already paid — all R4-corroborated. The ASSUMPTION flag on drafting-throughput-as-bottleneck is honest and is exactly what the concierge test measures. Invoiced-from-day-one design with a repeat-purchase metric is the best-constructed test in either file.
- **Distribution audit:** Solicitor referral economics + founding the practitioner community is R3-aligned; ~1,500-person surface is 2-person-sized. Risk: community-founding takes months and the solicitor channel overlaps Codex C2's — they will collide at synthesis.
- **Moat audit:** "What survives cross-examination" corpus is credible *because the audit substrate is real* (finding #3). But it accrues per report; day-one moat is only the design partner.
- **Feasibility audit:** Here the code audit bites: "platform transfers ~80%" is generous — intake, audit, and the PDF pipeline (`services/clinical-report-pdf.ts`) transfer; the review-gate needs completing (finding #1) and auth is absent (finding #2). Worse, "the 7 encoded statutory frameworks become an automated specificity/quantification checker" is **false today** — there is no statutory content in the harness (finding #5); the checker is a 3–5-week build plus design-partner grading. Honest first sellable artifact: concierge at ~1 week; real engine ~7–10 engineer-weeks.
- **Steelman fix:** Restate asset leverage honestly and budget the checker as new build; the candidate still clears the bar.
- **What the proposer missed:** R1 §8's timing warning — Beam is "one templating decision away" — makes the concierge-now, build-later sequencing not just cheap but strategically necessary.

## Claude — Candidate 2: SLT-Bench assurance layer

- **Verdict:** MAJOR REVISION
- **Evidence audit:** The invoice exists (£5–25k safety cases, Assuric/Naq), but the buyer count is low-hundreds and the regulatory bite is 2027 — the proposer's own riskiest-assumption concedes the timing gap. R4's cited CHAI assurance-lab collapse is the base rate for third-party assurance.
- **Distribution audit:** Publish-the-yardstick works only if the yardstick survives scrutiny — and this is where the code audit is fatal to the current plan.
- **Moat audit:** "The eval harness is the entire product" — the harness scores one-line gists by 0.4 word-overlap, in stub mode, against 50/54 *draft-status* personas with **no session transcripts** (finding #5). Scribes transcribe audio; you cannot benchmark a scribe with text personas that contain no speech samples. A leaderboard published on this methodology would be publicly dismantled by the first $65M vendor it embarrasses — reputational risk, not just wasted effort.
- **Feasibility audit:** "Week 1: run 5 named tools through 10 personas" requires per-tool adapters, transcript synthesis, and a defensible rubric — that is 4–6 weeks, not one. Credible benchmark v1: 10–14 engineer-weeks plus heavy clinician grading. Neither founder is a registered clinician (R4's CSO caveat).
- **Steelman fix:** Invert public/private: sell *private* specialty-validation engagements (the £1,500/£500-deposit outreach — keep that test verbatim) and file the DCB0129/0160 consultation response before 11 Sep, but publish no leaderboard until the corpus has transcripts and reviewed goldens. The harness's true role this year is the invisible QA engine inside C1-class products — which is also the Codex-sub author's independent conclusion in their dissent section.
- **What the proposer missed:** the harness's own README disclaims exactly the capability this candidate sells ("stub numbers check plumbing and prompt parity, not model quality").

## Claude — Candidate 3: Waiting-list referral engine

- **Verdict:** MAJOR REVISION
- **Evidence audit:** Parent-side pain is real; SLT-side demand rests on "ASLTIP fees + ASSUMPTION: many run ads" — the thinnest revealed-spend claim of the eight, and the candidate's economics live entirely on that side. The £25-deposit test is well-built and would settle it.
- **Distribution audit:** Genuinely the R3-preferred quadrant, competitor-irrelevant, ownable. Best channel thesis in the portfolio.
- **Feasibility/moat audit:** "Highest platform reuse" is half-true: intake links, portal, magic-link plumbing (`register-patient.ts`, `portal-links.ts`) genuinely transfer. But "eval harness triage goldens gate safety" oversells badly: the product's triage is a **clinician-entered enum** (finding #4), the harness has exactly **one safeguarding-flagged persona** out of 54, and an automated *parent-facing* triage that signposts red flags (dysphagia, safeguarding) is a new clinical-risk surface — plausibly nudging toward medical-device territory, and certainly needing a safety case the current corpus cannot support. That build plus safety work is 8–12 engineer-weeks, the largest true build among the survivors' claims.
- **Steelman fix:** Run the two-sided test *supply-first*: collect the five £25 SLT deposits against manually-triaged referrals before spending anything on parent acquisition. If supply pays, fund the safety-cased triage build with its revenue.
- **What the proposer missed:** Mable Therapy's MELCS (R1) is adjacent intake/screening with an existing schools base — the "structurally invisible to competitors" claim has at least one sighted neighbor.

## Claude — Candidate 4: Pay-per-analysis scoring lab (US)

- **Verdict:** SURVIVES
- **Evidence audit:** Best revealed-spend chain in the file: Q-global per-assessment subscriptions, usage-priced Q-interactive, SALT licenses — all consumables budgets that exist today. Correctly self-flags the solo-buyer risk and makes repeat purchase the kill metric.
- **Distribution audit:** Free-calculator SEO into an owned list, with rented podcast top-ups — textbook R3. Slow to compound; the concierge test wisely doesn't depend on SEO.
- **Moat audit:** The publisher-IP navigation (compute literature norms, never reproduce Pearson tables) is the most legally-aware paragraph in either file. The graded-LSA corpus moat is future-tense, same caveat as Codex C1.
- **Feasibility audit:** LSA metrics (MLU, TTR) are deterministic code — genuinely buildable without clinical sign-off; interpretation paragraphs need clinician grading. Personas contain no language samples, so goldens start from zero (finding #5); harness contributes methodology and CI only. Honest MVP: 7–10 engineer-weeks; HIPAA terraform finally load-bearing.
- **Steelman fix:** None structural — merge with Codex C1 (same buyer, same channel, same corpus; scoring is the wedge, full evaluation reports the expansion).
- **What the proposer missed:** Evalubox already bundles an LSA tool (ELSA) at $5/credit — whitespace is thinner than "no modern web competitor" implies; differentiation must be interpretation quality, which is exactly the ungraded part.

---

## Cross-portfolio: build cost, real leverage, and what synthesis should merge

**Engineer-weeks to first sellable artifact** (including the shared debts — auth ~2–3 wks and true review-gate ~1–2 wks — wherever PHI is handled; concierge modes noted):

| Rank | Candidate | To first sale | To real product |
|---|---|---|---|
| 1 | Codex C2 network (concierge brokerage) | ~1–2 | 6–10 |
| 2 | Claude C1 Section F (concierge) | ~1 | 7–10 |
| 3 | Codex C4 app-store workbench | 3–5 | +4 for Pro |
| 4 | Claude C4 scoring lab | 4 (concierge) | 7–10 |
| 5 | Codex C1 US report engine | 4 (concierge) | 9–12 |
| 6 | Claude C3 referral engine | 5 (manual triage) | 8–12 |
| 7 | Claude C2 SLT-Bench (credible) | 6 (private engagements) | 10–14 |
| 8 | Codex C3 Medicaid OEM | demo 1–2 | 14–20+ |

**What the codebase genuinely accelerates:** the statutory-report pair (Claude C1 + Codex C2) — append-only audit, PDF pipeline, intake, design partner — and Claude C3's parent-side plumbing. **What quietly discards it:** Codex C4 (posture only), Codex C3 (methodology only), and — uncomfortably — both US candidates, which reuse terraform and schema but almost no content. **What no candidate can honestly claim yet:** a working review-gate, statutory goldens, or a benchmark-grade harness.

**Synthesis should merge to two lanes plus one probe:** (1) **UK statutory reports** — Claude C1's tool-first concierge fused with Codex C2's solicitor-channel demand test, run both £500 tests in the same fortnight, with the completed review-gate + audit trail as the shared "provenance" spine and Claude C2 demoted to its QA layer plus the DCB consultation response; (2) **US per-use scoring→reports** — Claude C4 fused with Codex C1, scoring wedge first for IP safety; (3) Codex C4 run only as a list-building channel probe for lane 2. Codex C3 parks as a discovery option; Claude C3 runs its supply-side deposit test before any build. The money from four cheap tests — not the memos, and not the asset nostalgia — picks between the lanes.
