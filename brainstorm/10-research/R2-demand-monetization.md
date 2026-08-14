# R2 — Demand Truth & Monetization Diagnosis

**For:** Sona founders (DevUp Labs) · **Date:** 2026-08-14 · **Author:** Claude research worker
**Trigger:** "They always say yes but then don't end up buying."

---

## TL;DR

You don't have a product problem; you have a **signal problem**. Every input you've collected — verbal "yes I'd pay," a design partner's "I wouldn't mind paying," feature feedback — is hypothetical-preference data, which decades of contingent-valuation research show overstates real willingness-to-pay by 35% at the median and 2–3x in the worst cases. Your design partner's exact phrasing ("*I wouldn't mind* paying… *so far as* it saves me time") is a textbook conditional non-commitment, not demand. **Stop counting words; start counting money and inconvenience.** The only signals that predict purchase are: existing spend on the problem, budget line items, and costly pull behaviors (deposits, pre-payment, chasing you). Separately, solo UK private SLTs are a structurally hard buyer — £14.95–£29/mo is their revealed price ceiling for software, they have no procurement muscle, and "saves admin time" doesn't convert because saved time doesn't automatically become revenue. The buyers with real, evidenced budgets for exactly this pain are **local authorities/schools (EHCP/SEND crisis), NHS/ICB waiting-list initiatives, and multi-clinician clinic groups** — where comparable tools (Beam's Magic Notes) are winning £96k–£240k contracts. Any pivot must pass the rules in §6 — chiefly: *someone must already be paying for a worse version of the solution.*

---

## 1. Why "yes, I'd pay" lies

**a) Hypothetical bias is measured and large.** Contingent-valuation research — the economics literature on asking people what they'd pay — finds hypothetical WTP exceeds actual payment with a median ratio of **1.35** across 28 within-subject studies ([Murphy et al., meta-analysis](https://link.springer.com/article/10.1007/s10640-004-3332-z)), ~21% average bias for consumer goods ([Schmidt & Bijmolt, JAMS](https://link.springer.com/article/10.1007/s11747-019-00666-6)), and factors of 2–3x in direct-question formats ([Loomis 2011](https://onlinelibrary.wiley.com/doi/abs/10.1111/j.1467-6419.2010.00675.x)). Critically, the bias is *worst* exactly how you've been asking: direct, open-ended "would you pay for this?" questions. Answering "yes" costs the respondent nothing and buys them your goodwill. That's not lying — it's rational politeness.

**b) Social desirability + relationship preservation.** Your interviewees are clinicians in a caring profession talking to two earnest founders who built something *for them*. Rob Fitzpatrick's *The Mom Test* names this precisely: compliments, fluff ("I would definitely buy that"), and ideas are the three types of bad data, and **"any statement about the future is an over-optimistic lie."** The fix is his rule: talk about *their life and past behavior*, never your idea — "What do you currently do about report-writing? What did it cost you last month? What have you already tried and paid for?"

**c) The "nice idea" trap for solo-clinician buyers specifically.** A solo SLT has no procurement department, no software budget line, and no boss to impress with efficiency. Every subscription comes out of personal drawings. So the gap between "nice idea" (zero cost) and "purchase" (recurring personal cost + admin + data-protection anxiety + workflow change) is *wider* for them than for a corporate buyer, not narrower. They also experience the pain in low-stakes, batched form — admin is annoying but done at 9pm on the sofa, not blocking revenue in the moment. Annoyance without acute cost produces enthusiastic interviews and zero conversions.

**d) Parse your design partner's sentence.** "I *wouldn't mind* paying **so far as** it saves me time & admin effort" contains: (i) minimization ("wouldn't mind" ≠ "want to"), (ii) an unpriced condition (how much time, worth how much?), and (iii) no number, date, or mechanism. Under Mom Test rules the correct response was never to build more — it was: *"Great — it's £30/month, first month starts Monday, here's the payment link."* Her response to that link is the only data point that matters. You've spent months of development buying compliments.

---

## 2. What actually predicts purchase

Ranked by predictive power:

1. **Existing spend on the problem (revealed preference).** What do UK private SLTs *already pay* for adjacent jobs? Practice management software: Cliniko at **~£29/mo** for a solo practitioner ([SchedulingKit](https://schedulingkit.com/pricing-guides/cliniko-pricing)), WriteUpp at **£14.95/user/mo** with a **£27.95 Solo plan** ([Private Practice Hub](https://www.privatepracticehub.co.uk/writeupp-reviews-pricing-cost/), [Medesk](https://www.medesk.net/en/blog/writeupp-review/)); ChatGPT Plus at ~£20/mo (many clinicians already use it informally for reports — ask, don't assume); some pay virtual assistants £15–£30/hr for admin. If a prospect pays for *none* of these, they have revealed a ~£0 software budget and will not be your customer at any feature level.
2. **A budget line item.** Does money for this category already exist (PMS subscription, VA, outsourced typing, locum cover)? New-category creation in a £40–90k solo practice is nearly impossible; *displacing or topping up an existing line* is feasible.
3. **Pull behaviors.** Chasing you for access, asking "when can I start?", pre-paying, deposits, signed LOIs *with money attached*, introducing you to peers unprompted, complaining when the beta breaks. Fitzpatrick's currency framework: real commitment costs the prospect **money, reputation, or meaningful time**. A calendar full of friendly demo calls costs them nothing and predicts nothing.
4. **Frequency × intensity of pain.** Daily + revenue-blocking beats weekly + annoying. Report-writing for an SLT is frequent but *deferrable* — that deferability is exactly why it doesn't force purchase. Contrast an LA facing statutory EHCP deadlines: same task, non-deferrable, legally exposed → real budget (see §4).
5. **A forcing event.** Regulation, backlog crisis, tribunal deadline, insurer requirement. No deadline → no decision.

**Operational rule going forward: no interview datum enters the roadmap unless it is (a) a past behavior, (b) an existing spend, or (c) a commitment that cost the prospect something.**

---

## 3. Validation instruments, ranked for a 2-person startup

| Rank | Instrument | Cost | Time | Evidence strength | How to run it / benchmark |
|---|---|---|---|---|---|
| 1 | **Pre-sale / paid deposit** | ~£0 | 1–2 wks | **Gold.** Actual money before build. | "Founding member: £150 for 6 months, refundable if we don't ship by X." Target: **3–5 of 20 warm prospects (15–25%)**. Below 10% of *warm* prospects = kill signal. |
| 2 | **Paid pilot with invoice** | Low | 4–8 wks | **Gold**, if paid from day 1. Free pilots are compliments with logins. | Even £50/mo pilot fee filters ruthlessly. For B2B (LA/clinic group): 4–6 wk pilot at £1–5k with pre-agreed success metrics *and a pre-agreed price for the rollout*. |
| 3 | **Concierge MVP + invoice** | Time only | 2–4 wks | **High.** Tests demand *and* WTP without code. | You personally turn 5 clinicians' session notes into reports/parent summaries (human + AI behind the curtain). Charge per report (£5–15). Do they send you a *second* batch? Repeat purchase is the signal. |
| 4 | **Annual-prepay discount test** | £0 | 1 wk | **High.** Separates budget-holders from browsers. | Offer £290/yr vs £29/mo. Anyone taking annual has real budget conviction. Also tests cash-flow viability. |
| 5 | **Mock checkout / fake door with real pricing** | £100–300 ads | 2–3 wks | **Medium-high.** Behavioral but pre-payment. | Landing page with actual price and a "Start subscription" button → "launching soon, reserve with £1." Cold-traffic benchmarks: email capture 2–5% is normal; **>15% click-to-pricing-CTA is strong**; genuine pre-order from cold B2B traffic **>1% is noteworthy**; expect **85–95% of "interested" signal to evaporate at the transaction step** ([CleverX](https://cleverx.com/blog/pre-launch-demand-testing-with-real-buyers), [dowhatmatter](https://dowhatmatter.com/guides/fake-door-test), [daydream](https://www.withdaydream.com/library/insights/average-landing-page-conversion-rate)). Distribute via ASLTIP directory outreach and SLT Facebook groups, not generic ads. |
| 6 | **£1 commitment test** | £0 | days | **Medium.** Trivial money, but real card friction. | "Put £1 down to lock founding pricing." Filters the politeness layer; doesn't prove £30/mo tolerance. |
| 7 | **Van Westendorp (done correctly)** | £0 | 1–2 wks | **Low-medium.** Stated-preference; use only to *bracket* price, never to prove demand. | Run only on people who have already exhibited a pull behavior (used concierge service, clicked buy). Four questions (too cheap / bargain / getting expensive / too expensive), n≥30. Then **verify the bracket with instrument 1 or 5**. Never run it on cold interviewees — you'll re-import the hypothetical bias you're trying to escape. |
| 8 | **LOI without money** | £0 | days | **Low** for solos (they'll sign anything friendly). Moderately useful for LAs/clinic groups where signature = internal process. | Only count LOIs that name a price, a date, and a signatory with budget authority. |

**Benchmark reality check for clinician SaaS:** solo-clinician products convert from free trial to paid at roughly 5–15% (self-serve norms); warm-community pre-sales at 15–25% of engaged prospects is a strong result. If 20 warm SLTs produce zero pre-sales at £29/mo, the solo-SLT segment is falsified — that's a *result*, not a failure.

---

## 4. Economics of the solo UK private SLT — and who actually has money

**The buyer.** A full-time private paediatric SLT charges roughly **£60–100+/hr** ([SpeechWise £77/hr](https://speechwisetherapy.co.uk/our-prices/); sector range £35–100+) and grosses ~£40–90k on 20–25 clinical hours/week. Their total software tolerance, revealed by market prices, is **~£15–45/mo** (WriteUpp £14.95–£27.95; Cliniko ~£29). A new tool must fit *under or inside* that envelope: realistically **£19–39/mo**, or replace the PMS entirely. Heidi's 2026 move to ~$150/mo for its Clinician plan ([Twofold](https://www.trytwofold.com/compare/heidi-health-pricing-2026-guide)) is priced for physicians with 5–10x SLT revenue density — it is *not* evidence that solo SLTs will pay that.

**Why "saves you time" underconverts.** For an employed clinician, saved time is the employer's gain; for a solo practitioner, saved *evening admin* time converts to leisure, not cash — unless she backfills it with billable sessions. She won't pay £40/mo to get her Tuesday evening back; she might pay £40/mo to **see 2 more clients/week (+£480/mo)** or to **turn around EHCP/tribunal reports faster and win more referrals**. Reframe every pitch from time → **capacity, revenue, and cash collection**: "one extra billable session per week pays for a year of Sona." If the product can't honestly claim a revenue/capacity mechanism for this buyer, the buyer is wrong, not the copy.

**Adjacent buyers with real, evidenced budgets:**

| Buyer | Evidence of budget | Note |
|---|---|---|
| **Local authorities / SEND & social care** | Beam's *Magic Notes* (same shape as Sona: record → structured assessment → report): **Lambeth £96k/2yr** ([Brixton Buzz](https://www.brixtonbuzz.com/2025/05/lambeth-council-approves-96k-ai-deal-to-transcribe-social-care-meetings-promising-efficiency-gains-despite-privacy-concerns/)), **Angus £240k** ([The Courier](https://www.thecourier.co.uk/fp/news/5552626/angus-council-social-work-ai-tool/)), 100+ LAs, ~7–11 hrs/practitioner/week saved ([LGA](https://www.local.gov.uk/case-studies/kingston-council-using-ai-adult-social-care-administration), [Somerset](https://www.somerset.gov.uk/news/somerset-social-workers-save-time-on-admin-thanks-to-ai-tool-magic-notes/)) | The forcing event is statutory: **~24,000 SEND tribunal appeals registered in 2024/25**, unprecedented demand ([Local Government Lawyer](https://mail.localgovernmentlawyer.co.uk/education-law/394-education-news/99460-send-tribunal-has-faced-unprecedented-demand-registering-24-000-appeals-in-2024-25-senior-judge-reveals)). EHCP Section F requires specified, quantified SLT provision ([RCSLT](https://www.rcslt.org/wp-content/uploads/media/Project/RCSLT/ehc-plans-and-slt-provision.pdf)) — reports are legally load-bearing, non-deferrable, and backlogged. |
| **NHS trusts / ICBs (waiting-list initiatives)** | Children's SLT waits of **6–18 months**, one trust averaging 49 weeks ([The SEND List](https://thesendlist.co.uk/nhs-speech-language-therapy-waiting-times-uk/)) | Triage + assessment throughput tooling maps directly to waiting-list money. Long sales cycles (DTAC, DPIA, procurement frameworks) — a 2-person team needs a partner or framework route. |
| **Clinic groups / multi-clinician SLT practices (5–30 clinicians)** | Pay per-user PMS fees already; owner captures the efficiency gain of every clinician | The sweet spot for a small startup: real budget, one decision-maker, 2–6 wk sales cycle, £200–1,000/mo deals. |
| **Parents paying privately (via therapist)** | Parents already pay £77–100+/session and £300–800 for tribunal-grade reports | Don't sell to parents directly; let therapists charge for premium reports/parent summaries powered by Sona — makes Sona revenue-generating for the clinician, fixing the framing problem above. |
| **Insurers / cash plans** | Weakest near-term: SLT is a small line for UK PMI; no observed spend on SLT admin tooling | Deprioritize. |

---

## 5. "Feature moat is dead" — mostly true, and it doesn't matter

The advice you received is directionally right: in 2026, AI features (summaries, note generation, chat) are table stakes reproducible in weeks; buyers choose on integrations, switching costs, and trust, not on who has AI ([The Reservist](https://thereservist.substack.com/p/a-framework-to-evaluate-the-saas), [Stanford: Defensible Moats for Vertical AI](https://law.stanford.edu/wp-content/uploads/2026/06/Defensible-Moats-for-Vertical-AI-Application-Companies-in-a-New-Competitive-Landscape.pdf)). But "no feature moat" ≠ "no moat." What still works:

1. **Distribution & trusted channel.** Often now the strongest moat ([Valtorian](https://www.valtorian.com/blog/ai-moats-2026)). For Sona: ASLTIP/RCSLT relationships, SLT training-course partnerships, being *the* name in the UK SLT Facebook/WhatsApp communities. A 2-person team can win this in a niche this small; Google can't be bothered to.
2. **Workflow lock-in via system-of-record.** Own the caseload data and the intake→report pipeline, not just a text generator bolted on the side. Caveat: agent-era portability is eroding pure UI lock-in ([Padezhnov](https://padezhnov.com/en/blog/saas-moats-are-eroding-what-survives-the-ai-disruption/)) — lock-in must come from accumulated structured clinical data, not screens.
3. **Data & eval assets.** A proprietary corpus of SLT-specific templates, outcome measures, and clinician-graded evaluation sets (what "good" looks like for an EHCP Section F contribution) is genuinely hard to copy and is what acquirers underwrite ([BigIdeasDB](https://bigideasdb.com/saas-moat-ai-era-2026)).
4. **Compliance posture.** UK GDPR is baseline; **DTAC, DCB0129 clinical safety, ISO 27001/42001, DPIA templates for LA procurement** take years and real money to replicate and are *the* gate for NHS/LA buyers ([Designli Moat Report](https://designli.co/founders-resources-blog/the-moat-report-how-saas-founders-are-building-defensibility-in-2026)). Beam's LA wins ride on exactly this trust posture.
5. **Brand/community + speed.** In a profession of ~20k UK SLTs, being the founder who shows up at every CEN meeting compounds; two-person teams out-ship incumbents weekly.

**Implication:** the moat question is downstream of the demand question. Pick the buyer with money first; build the compliance + data + channel moat for *that* buyer.

---

## 6. Implications for pivot selection — rules any candidate must satisfy

Score every pivot candidate against all seven. **Fail any of 1–4 = disqualified.**

1. **Existing spend rule:** the target buyer already pays money (software, staff, outsourcing) to solve this exact problem today. Name the invoice.
2. **Budget-holder rule:** the person feeling the pain controls a budget that already has a relevant line item — or captures the financial gain personally (clinic owner, LA service manager).
3. **Forcing-event rule:** something makes the purchase non-deferrable (statutory deadline, tribunal backlog, waiting-list target, capacity ceiling). "Annoying admin" alone fails.
4. **Two-week money test:** you can obtain a paid commitment (deposit, paid pilot, concierge invoice) within 14 days without writing new code. If you can't design that test, the candidate is unfalsifiable — reject it.
5. **Revenue-framing rule:** for practitioner buyers, the pitch must convert to capacity/revenue ("+2 sessions/week"), not saved evenings.
6. **Reachability rule:** a 2-person team can reach 50 qualified buyers in 30 days through channels you already touch (ASLTIP, design partner's network, LA SEND contacts).
7. **Moat trajectory rule:** winning this buyer accumulates at least one durable asset — compliance certification, proprietary clinical eval data, or channel ownership — not just features.

**Concrete next 30 days:** (1) Send your design partner a real payment link this week — her answer closes the loop on 6 months of ambiguity. (2) Run the concierge MVP with 5 private SLTs at £10/report. (3) In parallel, use her network to get one conversation with an LA SEND service or a 5–15 clinician group about EHCP report throughput, priced as a £2–5k paid pilot. Where the money moves first is your pivot.

*Sources cited inline throughout.*
