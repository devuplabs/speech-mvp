# Cross-critique — Codex-slot substitute (operator lens)

**Reviewer:** stand-in for the Codex slot (DEV-139), persona: skeptical operator-investor. **Targets:** `brainstorm/20-proposals/proposals-cursor.md` (5 candidates), `brainstorm/20-proposals/proposals-claude.md` (4 candidates). Written blind to other critiques. Evidence standards per PROTOCOL.md applied; spot-checks cited inline.

---

## Cursor — Candidate 1: Speech AI Assurance Lab

- **Verdict:** MAJOR REVISION
- **Evidence audit:** The compliance spend is admissible — vendors do pay Assuric/Naq-class providers for DCB0129 work, and DTAC 2.0 is a live procurement gate. But the proposal's own ASSUMPTION is the whole company: that vendors redirect spend to *specialty* performance evidence **before** anyone mandates it. R4 already documented the bear case Cursor never engages: CHAI's US assurance-lab network collapsed in early 2026 because deployers wouldn't pay third parties to vet vendors. Vendor-pays survives only where evidence unlocks a specific deal.
- **Distribution audit:** Founder-led outbound to a finite vendor list is right for 2 people. But count the list honestly: vendors who care about *SLT specifically* number maybe 10–20 logos (splose, Heidi, Jane, WriteUpp, Zanda, Ambiki, the four EHCP-AI vendors, a few teletherapy players). At £2.5–10k sprints that's a £50–150k/yr consultancy, not a pivot. The proposal has no mechanism to expand the buyer pool.
- **Moat audit:** The failure corpus + yardstick position is a real non-feature moat — *if* the benchmark gets published and cited. Cursor buries the benchmark as a marketing afterthought; without it, this is bilateral consulting a Big-4-adjacent QA shop or the vendors' own eval teams can replicate.
- **Feasibility audit:** Neither founder is a registered clinician; grading clinical outputs at commercial scale rests on one design partner (unpriced, uncontracted). Ratings-agency conflict — paid by the companies you score — is unaddressed, and scoring named vendors invites methodology disputes and legal letters.
- **Steelman fix:** Merge with the public-benchmark posture (see Claude C2): leaderboard first, engagements second, and a contracted clinician-grading bench of 3–5 SLTs on per-case rates before selling the first sprint.
- **What the proposer missed:** R4's CHAI collapse (the direct precedent against this model) and R4's timing hooks — the DCB0129/0160 consultation closing 11 Sep 2026 is free authority-building Cursor leaves on the table.

## Cursor — Candidate 2: Statutory Report Exchange

- **Verdict:** KILL
- **Evidence audit:** The money is real and admissible — £900–1,400 UK tribunal report fees confirmed live ([The Orchid Practice](https://theorchidpractice.co.uk/fee-schedule/)), and IDEA §300.502 IEEs are genuinely publicly funded. The evidence problem is on the *supply* side, where no evidence is offered at all.
- **Distribution audit:** Solicitor referral channels are real and empty (per R3). But a marketplace needs liquidity, and this market is supply-constrained by construction: the 21% vacancy rate and 46-week waits mean tribunal-qualified independent SLTs are already booked out. A clearinghouse creates zero capacity; it inserts a 12–15% toll between a solicitor who already has a rolodex and a clinician who is already oversubscribed. Both sides disintermediate after case one — the classic high-value, low-frequency marketplace death.
- **Moat audit:** "Exclusive referral relationships" with boutique law firms are rentable, not owned — PROTOCOL rule 3 fails. Turnaround data doesn't compound if you never reach volume.
- **Feasibility audit:** Cursor's own asset-leverage paragraph concedes the platform can't currently edit or sign off clinical reports via API, and the riskiest-assumption line admits this becomes a staffing agency. Add safeguarding, expert-witness vetting, conflicts, and a *simultaneous* US IEE lane in a different legal system — for two UK engineers with no legal-market network. Scope dishonesty by their own telling.
- **Steelman fix:** None as a marketplace. The defensible kernel — statutory templates, provenance, attestation — is exactly Claude C1. Collapse this into tooling sold to the report writers and let solicitors be a referral channel, not a market side.
- **What the proposer missed:** R2's warning that the scarce input is clinician hours, and R4's O8 verdict that the parent/solicitor side is "fragmented, per-case" and better served by selling production tooling to practices.

## Cursor — Candidate 3: Speech Authorization Recovery

- **Verdict:** KILL
- **Evidence audit:** Strongest revealed-spend citation in either file: practices already pay 6–10% of collections for RCM, and PA denial overturn rates near 82% are corroborated ([Health Bill Central](https://healthbillcentral.com/blog/prior-authorization-guide)) — though that figure is Medicare Advantage; Medicaid pediatric speech overturn economics are asserted by analogy, not shown.
- **Distribution audit:** White-labelling through therapy-specialist billing firms is plausible on paper, but those firms *are* the fast-follower: once the SLP-specific evidence playbook is visible, an RCM firm with existing BAAs and payer portals copies it in a quarter. Cursor names this risk and offers no answer.
- **Moat audit:** A payer/state rule graph is a real data moat — for whoever has claim volume. Two founders doing manual appeals in one state will never accumulate it faster than an RCM incumbent bolting on the same workflow.
- **Feasibility audit:** This is the clearest founder-market-fit zero in the portfolio. Two UK engineers, no US payer experience, no billing network, servicing contingency-fee recovery across US time zones. Unit economics break at the claim level: pediatric Medicaid speech sessions bill roughly $60–150; a denied series worth $1–3k yields $100–450 at a 10–15% success fee — against hours of manual medical-necessity assembly per case. The validation test's own success bar ($2,500 recoverable pool) wouldn't cover a month of founder labor.
- **Steelman fix:** Not fixable for this team. A fine business for an American RCM insider; DevUp Labs isn't one.
- **What the proposer missed:** R2 rule 6 (reachability: 50 qualified buyers in 30 days through channels *you already touch* — they touch none of these) and the near-total non-transfer of the eval harness and UK compliance posture.

## Cursor — Candidate 4: SLP Capacity Clearinghouse

- **Verdict:** KILL
- **Evidence audit:** The budget lines are real — but the flagship citation self-destructs: the DCPS $100/hr contract Cursor links is signed with **Amergis**, a national staffing incumbent. The evidence proves the buyer pays *agencies that already exist*, not that a slot is open.
- **Distribution audit:** The US school-staffing channel is saturated by Soliant, Amergis, Presence, and Therapy Source, all of whom already sell teletherapy blocks and district relationships ([Soliant](https://www.soliant.com/staffing-services/education-recruitment-agency/), [Amergis](https://www.amergiseducation.com/therapy-and-related-services/)). "Incumbents optimise for FTE placements, leaving micro-blocks fragmented" is asserted, unevidenced, and contradicted by Presence's per-session teletherapy model.
- **Moat audit:** Marketplace liquidity is a moat only at liquidity; in a 21%-vacancy market the binding constraint is clinicians, which software cannot mint. Same structural flaw as Cursor C2.
- **Feasibility audit:** Credentialing, DBS/safeguarding, IR35/worker classification, multi-state licensure, payments, contracting — Cursor's own asset paragraph admits this is "a meaningful operational pivot," i.e., a recruiting business. Asset leverage rounds to zero; founder-market fit rounds to zero; the eval harness is irrelevant.
- **Steelman fix:** None. If capacity brokerage matters, it belongs (much later) as an expansion of Claude C3's referral engine, where the demand-side audience is owned first.
- **What the proposer missed:** That its own DCPS exhibit names the incumbent, and R4's O7/O8 pattern: distribution-game businesses are DevUp's known weakness.

## Cursor — Candidate 5: AI Safety Simulation CPD

- **Verdict:** KILL as a standalone pivot (retain as a channel tactic)
- **Evidence audit:** Honest and admissible: CPD/CE money demonstrably moves (ASHA's $59–77 AI ethics course; HCPC audit anxiety). But the same citation sets the price ceiling: the market pays lecture prices. The ASSUMPTION that simulation commands a premium is stated-preference territory the protocol forbids building on.
- **Distribution audit:** One CE-provider partnership is winnable by 2 people, but it's a rented channel; the provider keeps the learner list and the accreditation. Cursor concedes defensibility is only "semi."
- **Moat audit:** A simulation bank is content; content businesses in CPD are copied by every provider with an LMS the week the format proves out. Professional bodies can release free equivalents and erase pricing power overnight — Cursor's own risk line says so.
- **Feasibility audit:** Cleanest build in the file, and that's the tell: £39 × seats × cohort cadence is a founder-salary business at best. The proposer's candor ("may cap out as a course business") is a self-issued kill notice under a protocol where the pivot must be the company.
- **Steelman fix:** Demote to marketing: "Can you catch unsafe clinical AI?" cohorts are superb top-of-funnel and clinician-grader recruitment for the assurance lab (Cursor C1/Claude C2). Run it; don't fund it.
- **What the proposer missed:** R3's rule that rented touches must fill an owned asset — the design shown fills the *partner's* list, not DevUp's.

## Claude — Candidate 1: Section F tribunal report engine

- **Verdict:** SURVIVES
- **Evidence audit:** Best-evidenced candidate in either file. Money verifiably moves now: ~25,000 SEND appeals in 2024/25, ~99% decided for families ([Tes](https://www.tes.com/magazine/news/specialist-sector/send-appeals-hit-new-record-high), [Browne Jacobson](https://www.brownejacobson.com/insights/send-tribunal-data-released)); report fees of £900–1,400 confirmed on live price lists ([Orchid Practice](https://theorchidpractice.co.uk/fee-schedule/), [Therapy Hive](https://therapyhive.co.uk/ehcp-tribunal-reports/)). Statutory deadlines supply the forcing event. The one ASSUMPTION (drafting throughput is the bottleneck) is correctly flagged and directly tested by the concierge design.
- **Distribution audit:** Solicitor referrals plus founding the practitioner community are genuinely empty channels per R3, and ~1,500 practitioners + a few dozen firms is a surface two people can actually cover. Caveat: community-founding takes quarters, not weeks; the solicitor channel must carry the 90-day plan alone.
- **Moat audit:** The "what survives cross-examination" corpus is the best proposed moat in the portfolio — genuinely uncollectible from the LA side. But it accrues slowly (tribunal outcomes lag by months), so for year one the honest moat is the design partner's network plus audit-trail compliance.
- **Feasibility audit:** Two unpriced landmines. (1) **Expert-integrity risk:** tribunal reports are expert evidence; the SLT signs that the opinion is their own. AI-drafted expert evidence, if surfaced in cross-examination or an RCSLT/HCPC position, could poison the category — the review-gate architecture helps, but the proposal never addresses disclosure norms. (2) **Ceiling honesty:** 1,500 SLTs × £150/mo ≈ £2.7M — this recreates the exact £2.4M bootstrap ceiling that triggered the pivot. It's a wedge, not a destination; the LA-side expansion is the venture claim and it is unvalidated.
- **Steelman fix:** n/a (survives) — but write the expert-evidence/disclosure position paper before the first paid report, and treat the LA/vendor QA expansion as the scored thesis.
- **What the proposer missed:** Some SLTs bill *for* the drafting hours; a tool that compresses 6–10 hours can read as fee compression unless positioned strictly as capacity ("take more instructed cases"), per R2's revenue-framing rule.

## Claude — Candidate 2: SLT-Bench — the assurance layer

- **Verdict:** SURVIVES
- **Evidence audit:** The invoice exists (CSO consultancy spend, compliance SaaS), the regulatory calendar is real, and the riskiest assumption — vendors pay before regulation bites — is correctly named. Still, the timing risk is understated: DTAC 2.0 gates *NHS* sales, and most target vendors' revenue today is private-practice SMB, where no gate exists.
- **Distribution audit:** Publish-the-yardstick is the correct 2-person motion (Beam proved published evidence is the UK channel), and the £499 self-serve tier is the smartest pricing device in either file — it makes first revenue card-payable. Watch the gatekeeper claim "none": in practice RCSLT/press citation is the amplifier, and RCSLT is slow and cautious (R3).
- **Moat audit:** Yardstick position is durable *if seized first*; the corpus compounds. Two unpriced risks: the ratings-agency conflict (paid audits by the scored), and legal exposure from publicly scoring named, funded vendors on synthetic cases — expect methodology war and lawyers' letters, which is survivable but must be budgeted.
- **Feasibility audit:** Highest asset leverage and best founder-market fit in the portfolio — the founders *built* the harness; this is the one candidate where they are the world experts. The CHAI precedent (R4) says don't ever depend on deployer-side buyers. Clinician grading again bottlenecks on one design partner.
- **Steelman fix:** n/a — but submit the DCB consultation response before 11 Sep 2026 (free authority, deadline is 17 days out) and publish a written conflict-of-interest policy with the first leaderboard.
- **What the proposer missed:** The leaderboard doubles as the kill-shot for Cursor C1's weakness — Claude C2 is effectively Cursor C1 done right; synthesis should treat them as one candidate.

## Claude — Candidate 3: Waiting-list referral engine

- **Verdict:** MAJOR REVISION
- **Evidence audit:** Parent-side money is real (£77–100/session, outsourced cohorts). The supply-side claim — SLTs pay to fill diaries — is the weak plank, and the proposer admits the inversion risk: overflow demand may already fill independent diaries organically, making referrals worthless. ASLTIP directory fees are thin evidence of per-referral willingness to pay.
- **Distribution audit:** The channel analysis is R3's best insight and genuinely competitor-proof. But the CAC-zero story is romantic: programmatic SEO takes 6–12 months to rank; SEND parent group admins are ad-hostile and slow to trust; 100 completed structured intakes in 14 days from 2–3 postcodes is a stretch goal dressed as a gate.
- **Moat audit:** An owned parent audience is a real asset — the only consumer-scale one proposed. Local two-sided lock-in only materialises at density; at bootstrap pace that's years.
- **Feasibility audit:** The biggest unpriced item: **triaging children is a clinical function.** A tool that routes red-flag presentations (dysphagia, choking) is making safety-relevant decisions and plausibly drifts into MHRA SaMD territory; children's data engages the ICO Age-Appropriate Design Code. The eval-harness gating helps, but nobody has costed the DPIA/clinical-safety overhead of a *consumer-facing* child triage product run by two engineers.
- **Steelman fix:** Reframe as the free audience-builder run *underneath* Candidate 1 — signposting and waiting-time content first, structured triage later once a clinical safety case exists; monetise referrals only where a postcode shows paying supply.
- **Time-to-revenue is the killer as a lead pivot; as a background asset it's excellent.**
- **What the proposer missed:** R2's finding that "buying revenue" only converts for practitioners with *empty capacity* — the same 21% vacancy statistic powering the demand story undercuts the buyer story.

## Claude — Candidate 4: Pay-per-analysis scoring lab (US-first)

- **Verdict:** MAJOR REVISION
- **Evidence audit:** Revealed per-use spend is real in kind (Q-global scoring subscriptions, SALT licenses, consumable record forms), though Pearson's actual prices are quote-gated rather than public ([Pearson support](https://support.pearson.com/usclinical/s/article/Q-global-Scoring-Subscriptions-Explained)) — the "$40/user/year" anchor is thinner than presented. The whitespace claim (scoring vs planning) matches R1.
- **Distribution audit:** Free-calculator SEO is a legitimate empty channel, but it's a months-long compounding play sold as a 2-week test; the r/slp concierge test partially rescues this.
- **Moat audit:** Graded-LSA golden corpus is credible but slow; SEO ownership is real but fragile against Pearson deciding to publish calculators.
- **Feasibility audit:** This candidate knowingly re-runs the exact failed experiment — solo clinicians as buyers — in a market where the founders have zero network, at 5,000 miles' distance, with HIPAA obligations attached to $8 transactions involving children's audio. LSA is also a practice many working SLPs *skip* because it's unreimbursed time; the tool may be selling virtue, not throughput. The kill criteria (repeat purchase ≥10%) are the right ones and admirably strict.
- **Steelman fix:** Keep the £300 concierge test as a cheap option on the US mandate, run only after C1/C2 revenue exists; if it fires, it becomes the US wedge — but it cannot be the company two UK engineers build first.
- **What the proposer missed:** Focus cost. Nothing in the 90-day plan prices what running a fourth market motion does to the other three.

---

## Cross-portfolio (operator summary)

**Convergence = signal.** Two convergences matter. (1) **Cursor C1 ≈ Claude C2**: two independent agents, plus R4's own ranking, landed on eval-backed assurance — the only candidate class where the founders are already the best in the world at the input. (2) **Cursor C2 and Claude C1** both found the £900–1,400 tribunal-report money; Claude's *tooling* angle beats Cursor's *marketplace* angle on every operator dimension (no liquidity problem, no take-rate resentment, design-partner FMF).

**What I'd fund:** the **Claude C1 + Claude C2 merger** (absorbing Cursor C1, with Cursor C5 demoted to its marketing motion): Section F report engine as the cash-flowing wedge and corpus generator; SLT-Bench as the yardstick and venture arc; the Section F specificity/QA checker as the bridge asset sold onward to the four LA-side EHCP-AI vendors. Both validation tests together cost under £300 and fit inside 30 days. That is executable by two engineers in 90 days; nothing else in the portfolio clearly is.

**Top 3 execution risks the council is underweighting:**
1. **Clinical sign-off is a single human named nowhere in any budget.** Nearly every surviving candidate routes through one design partner for grading, drafting credibility, or expert standing. She is a catastrophic single point of failure — contract and pay a clinician bench before any paid engagement.
2. **AI-drafted expert evidence integrity.** One tribunal cross-examination that discredits an AI-assisted report could close the category and take DevUp's name with it. Disclosure norms, provenance, and an RCSLT-defensible position are pre-revenue work, not polish.
3. **Ceiling recreation and focus.** The favoured wedge tops out near £2.7M — the same bootstrap ceiling that triggered this pivot — and the nine candidates span two countries and four business models. The council should score the *sequence* (wedge → QA-to-vendors → assurance layer), cap active motions at two, and say out loud whether it is building a bootstrap business or a venture, because these proposals quietly do both.

*(Spot-check sources: [Tes](https://www.tes.com/magazine/news/specialist-sector/send-appeals-hit-new-record-high), [Browne Jacobson](https://www.brownejacobson.com/insights/send-tribunal-data-released), [The Orchid Practice](https://theorchidpractice.co.uk/fee-schedule/), [Therapy Hive](https://therapyhive.co.uk/ehcp-tribunal-reports/), [Health Bill Central](https://healthbillcentral.com/blog/prior-authorization-guide), [Soliant](https://www.soliant.com/staffing-services/education-recruitment-agency/), [Amergis](https://www.amergiseducation.com/therapy-and-related-services/), [Pearson](https://support.pearson.com/usclinical/s/article/Q-global-Scoring-Subscriptions-Explained).)*
