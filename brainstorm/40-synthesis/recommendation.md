# Pivot Council — Final Synthesis & Recommendation

**Date:** 2026-08-25 · **Author:** Claude orchestrator (P4, per PROTOCOL.md)
**Inputs:** 4 research memos (R1–R4) · 3 independent proposal sets (Cursor ×5, Claude ×4, Codex-slot substitute ×4 — 13 candidates) · 4 cross-critiques (Claude on Cursor; Claude on substitute; operator-lens substitute on Cursor+Claude; technical-due-diligence substitute on substitute+Claude, grounded in the actual codebases)

---

## TL;DR — the recommendation in five sentences

Three frontier-model agents, working independently under a no-stated-willingness-to-pay evidence regime, converged on the same two pools of real money: **UK statutory/tribunal report fees that parents already pay (£900–1,400/report)** and **compliance/assurance budgets that clinical-AI vendors already spend (£5–25k/safety case)**. The scored winner is **Lane A: a UK statutory report engine for independent SLTs** — per-case tooling (never a marketplace — two critics found employment-agency and expert-independence landmines in the brokered version), sold at £40–75/report out of fees that already exist, with your design partner as customer zero and education-law firms as the demand channel. **Lane C (SLT-Bench, the assurance layer built on your eval harness)** is the venture arc and runs a cheap vendor-deposit probe now, but its honest build cost (10–14 engineer-weeks for a credible benchmark) and the CHAI assurance-lab collapse precedent keep it second. **Lane B (US per-use scoring→evaluation engine)** is the contrarian's best surviving idea and stays live, gated on one condition: no test runs until a named US SLP clinical partner signs on. Total cost to falsify or validate all three lanes: **under £1,100 and 30 days, no new product code** — the money, not the memos, picks the winner.

---

## 1. What the council killed (with cause)

| Candidate | Source | Cause of death |
|---|---|---|
| Speech Authorization Recovery (US Medicaid denials) | Cursor C3 | Percentage-of-recovery pricing legally prohibited/disfavored for Medicaid (NY regs, OIG); white-label channel runs the wrong way; near-zero asset transfer. Both critics: KILL. |
| SLP Capacity Clearinghouse | Cursor C4 | Its own evidence names the incumbent (Amergis/ex-Maxim); supply-constrained market breaks marketplace economics; makes DevUp a regulated employment agency. Both critics: KILL. |
| Statutory Report **Exchange** (brokered marketplace form) | Cursor C2 | UK Employment Agencies Act/Conduct Regs exposure + expert-independence rules (contingency-type fees effectively prohibited before tribunals) + INNEG already incumbent. Killed as a marketplace; its demand evidence survives inside Lane A. |
| AI Safety Simulation CPD (standalone) | Cursor C5 | HCPC has no CPD-hours mandate (weak UK forcing event); content copyable; referee/player conflict with assurance lane. Demoted to a marketing motion for Lane C. |
| Medicaid clean-claims OEM layer | Substitute C3 | Billing vendors are building this themselves (GoSolutions, eLuma, Frontline/Accelify); the channel gatekeeper is the natural fast-follower; 14–20+ engineer-weeks; contradicts its own author's weeks-not-months thesis. Parked, not pursued. |
| Waiting-list referral engine | Claude C3 | MAJOR REVISION twice: parent-facing automated triage is a new clinical-risk surface (possibly medical-device territory) the current harness cannot support (1 safeguarding persona of 54); 8–12 engineer-weeks. **Parked pending a zero-build supply-side test**: do independent SLTs pay £25 deposits for referrals? If yes, revisit after Lane A revenue. |
| Agent-app-store SLP workbench (standalone) | Substitute C4 | "PII-safe Pro inside ChatGPT" is architecturally incoherent (consumer chat transits OpenAI before the app sees it; no BAA); GPT-builder monetisation history is poor. Demoted to Lane B's list-building funnel probe. |

## 2. The three surviving lanes, scored (PROTOCOL rubric, max 65)

| Dimension (weight) | **Lane A: UK Statutory Report Engine** | **Lane C: SLT-Bench / Assurance** | **Lane B: US Scoring Lab** |
|---|---|---|---|
| Demand evidence (×3) | **5** — £900–1,400/report being paid now; 25k appeals, 99% parent win rate; statutory deadlines; found independently by all three agents | **3** — £5–25k safety-case invoices real but for *documentation*, not specialty evals; CHAI collapse is the cautionary precedent | **4** — revealed per-use spend (Pearson Q-global, SALT, Evalubox $5/credit); IDEA 60-day clocks; Austin ISD $4M settlement |
| Distribution (×3) | **4** — education-law firms/SEND advocates: near-zero saturation, BD-call reachable, immune to the competitor's channel capture; found + admin the "SLTs doing EHCP work" community | **4** — finite vendor list (~a dozen named targets) + publish-the-yardstick; needs an RCSLT/academic co-signature to be un-ignorable | **3** — free calculators + SEO genuinely open, but creator channel is rented and incumbents (Double Time Docs, slptools.ai, Ambiki) own US SLP lists |
| Moat, non-feature (×2) | **3** — corpus of what survives tribunal cross-examination + provenance-by-construction + community admin; compounds with every report | **4** — yardstick position + jurisdiction-labelled failure corpus; strongest long-run moat in the portfolio | **3** — graded interpretation corpus + SEO position; slow to compound |
| Asset leverage (×2) | **4** — audit trail, PDF pipeline, intake, design partner transfer; caveat: statutory goldens are a 3–5-week build, review-gate must be completed | **5** — the harness *is* the product; methodology, schemas, CI all load-bearing | **2** — HIPAA terraform + methodology only; persona content mostly doesn't transfer |
| Time to first revenue (×2) | **5** — concierge at £40/report, invoiced day 1, ~1 week of setup, zero new product code | **2** — deposit probe is cheap, but a credible benchmark v1 is 10–14 engineer-weeks | **4** — concierge with a paywall on the second use; but gated on securing a US partner first |
| 2-person feasibility (×1) | **4** — software-only; known debts: complete the review-gate (1–2 wks) and PHI auth (2–3 wks) before real client data | **3** — needs a registered-clinician CSO (design partner), a published independence policy, and legal budget for scoring named vendors | **3** — zero US presence/credibility today; publisher-IP care required (never reproduce Pearson interpretive content) |
| **Total /65** | **55** | **46** | **42** |

## 3. Recommended shape: one company, two acts

**Act one (now): the Statutory Report Engine.** Sell independent UK SLTs a per-case production workflow for EHCP Section F contributions and tribunal reports — secure intake, evidence bundling, statutory-specificity checking, append-only provenance that survives cross-examination — at £40–75/report against the £900–1,400 they earn per report. Demand-gen through education-law firms (they wait 4–6 weeks for reports today; the pitch is 10 days). This is the fusion the critics kept arriving at: Claude C1's tooling + the substitute C2's solicitor channel + Cursor C2's steelmanned remains. It keeps DevUp a software company and steps around every legal landmine the marketplace version trips.

**Act two (the arc): SLT-Bench.** The report engine's QA layer — the statutory-specificity checker, clinician-graded — grows into the public benchmark for AI in SLT workflows, monetised as specialty-validation engagements sold to the very vendors that beat you (splose, Jane, Heidi, WriteUpp, the four LA-side EHCP-AI vendors). Preconditions from the critiques: design partner (or contracted registered clinician) as CSO; a published independence policy (no vendor-sponsored training, ever); an RCSLT/academic co-signature hunt from day one. **Free authority move with a hard deadline: submit a response to the DCB0129/0160 revision consultation before 11 Sep 2026.**

**Kept warm, strictly gated:** the US scoring→evaluation lane (substitute C1 + Claude C4 merged; scoring wedge first for IP safety) — activates only when a named US school-SLP clinical partner signs on as grader and co-face. The US market is 100× larger and the contrarian was right that the council underweighted it; the gate exists because two UK founders drafting US eligibility-bearing reports without a US clinician is the one way this lane blows up.

## 4. The 30-day, ≤£1,100 validation plan (no new product code)

| # | Test | Lane | Cost | Success bar | Kill bar |
|---|---|---|---|---|---|
| 1 | **Concierge Section F engine**: via design partner + one solicitor intro, 5 SLTs send anonymised assessment data → draft + provenance table in 48h at **£40/report, invoiced day 1** | A | ~£100 | ≥8 paid reports across ≥3 clinicians AND ≥2 unprompted repeat batches in 14 days | <4 paid reports or zero repeats |
| 2 | **Solicitor demand test**: 20 education-law firms + 10 SEND advocates offered "10-working-day SLT tribunal report, £950, £100 deposit to reserve" (fulfilled by design partner + one recruited SLT) | A | ~£100 | ≥2 paid deposits AND ≥5 firms requesting slots in writing | 0 deposits, or the supply side (design partner + 3 SLTs) declines the work |
| 3 | **Vendor assurance probe**: 5-case sample scorecard from the existing harness → 10 named vendor clinical-safety leads offered a £2,500 SLT eval sprint with **£500 non-refundable deposit** | C | ~£150 | ≥1 paid deposit, or ≥2 formal tool submissions under agreement | 20 qualified contacts, zero money, zero submissions |
| 4 | **US supply gate**: recruit one named US school-SLP partner (grader + methodology co-face); only then run the $8-per-second-analysis concierge | B | ~£300 | Partner signed + ≥10 paid analyses from ≥8 SLPs, free→paid ≥10% | No partner in 30 days → lane stays parked |

Engineering pre-work in parallel (from the code audit, before any real client data): finish the review-gate as an actual gate (reviewer identity, explicit approve step, edit diffs — 1–2 wks) and wire auth onto the PHI routes (2–3 wks). These are prerequisites for *whichever* lane wins.

**Decision rule:** run tests 1–3 in the same fortnight. Two hits in Lane A → commit to act one. Test 3 hits regardless → book the sprint revenue and fold it into the arc. Everything misses → the assets are worth more sold or open-sourced than as a venture, and that answer will have cost £1,100 instead of another six months of building on politeness.

## 5. Dissents preserved (so the decision is honest)

- The contrarian substitute maintains the assurance lane is a **consultancy trap** (small buyer pool, one-shot engagements, CHAI's collapse) and that self-serve US channels are the main event. The operator critic partially endorsed the first point by scoring benchmark build-cost honestly. This is why Lane C runs a *deposit probe* now rather than a build.
- The technical due-diligence critic found every proposal **overstated asset leverage**: the review-gate is currently a stamp, the statutory goldens don't exist yet, and the crown-jewel harness genuinely powers only Lane C. Lane A's scores above already price this in.
- Nobody funded the original thesis: **the private-paeds co-pilot wedge is dead on every analysis** — crowded, channel-captured, small. The pivot is real.

---

*Full texts: `20-proposals/` (13 candidates), `30-critiques/` (4 critiques), `10-research/` (R1–R4). Decision gate: Linear DEV-143.*
