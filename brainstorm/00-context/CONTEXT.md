# Context pack — Sona pivot brainstorm

Curated 2026-08-14 by the orchestrator from `docs/mvp-brief.md`,
`docs/strategy/sona-venture-thesis-2026-06.md`, the strategy review brief, and
founder input. Work from this pack; deep-dive the repos only if a specific
question demands it.

## The company

DevUp Labs — effectively a 2-person team. Product codename **Sona**: a
speech-and-language-therapy (SLT/SLP) practice co-pilot. Built May–Aug 2026.

## What exists (asset inventory, most unusual first)

1. **speech-ml eval harness** — 54 schema-validated synthetic clinical personas
   across 18 SLT specialties, 8 jurisdictions, 5 regulatory regimes, 7 statutory
   frameworks, with golden triage/plan expectations and deterministic CI.
   Rare for a seed-stage company; the seed of a clinical safety case and a
   public benchmark. Currently invisible (private test fixtures).
2. **The loop product (speech-mvp)** — working multi-tenant clinical platform:
   parent intake → triage → clinician consult prep → AI-drafted session plan →
   parent-friendly summary; auth, multi-seat, booking, append-only audit trail,
   review-gate on every AI artifact. Node/Hono/Drizzle/Postgres API + Flutter
   web. AI layer partially stubbed; pre-pilot.
3. **Compliance-by-design posture** — UK data residency, self-hosted
   open-weights inference architecture, HIPAA-aligned GCP terraform, DPIA
   discipline, audit-trail-by-construction. Procurement ammunition for schools,
   ICBs, NHS — but not a moat by itself.
4. **Domain depth + 1 design partner** — UK private paediatric SLT, 23 years,
   ex-NHS. Thinnest asset; binding constraint on every demand claim we've made.

## Market facts (mid-2026)

- UK: 65–72k children on SLT waiting lists; 45.6% waiting >12 weeks; 21% SLT
  vacancy rate; SLT ≈ 21% of the children's community-health waiting list.
  Overflow lands on private practice.
- UK private/independent SLTs: ~1,800 ASLTIP members, true population ~2–4k.
  US: ~218,000 ASHA-certified SLPs (~40% school-based). AU/CA/IE/NZ: ~30–40k.
- Current wedge TAM ceiling: UK private SLTs at £79/seat/mo ≈ **£2.4M ARR at
  100% penetration** — a bootstrap business, not a venture outcome.
- Category signal: AI-native clinical workflow is hot (Abridge $5.3B, Ambience
  $243M Series C, Heidi Health ~$465M from a single-specialty single-market
  start). Ambient documentation ~$600M revenue in 2025.

## Why we are pivoting (the trigger)

- **ASSUMPTION-level fact from founder:** a competitor has shipped roughly our
  MVP (clinician-side intake → triage → plan for SLT) **and captured the
  distribution channels** we were counting on. Competitor name not yet on
  record — R1 research proposes candidates. Treat "the competitor owns the
  obvious SLT community/association/PMS channels" as given.
- **Demand-signal failure:** clinicians consistently *say* they'd pay
  ("I wouldn't mind paying for it so far as it saves me time & admin effort")
  and then don't buy. Months of feature development driven by interview
  feedback produced no revenue. We will not trust stated willingness to pay
  again — see PROTOCOL.md evidence standards.
- **Moat failure:** we've accepted that product-feature moats are dead in
  2026 SaaS; any pivot needs a non-feature moat.

## Hard constraints for this brainstorm

1. **Target customer stays: speech pathologists (SLTs/SLPs) in the UK and US.**
   The buyer-of-record may differ (schools, LAs/EHCP, ICBs, clinic groups,
   parents, platforms), but the pivot must serve SLT/SLP workflows.
2. 2-person team, bootstrap-level capital. Time-to-first-revenue matters more
   than TAM elegance.
3. Compliance obligations (UK GDPR/DPA 2018, HIPAA-alignment for US) are table
   stakes, and also a potential weapon.
4. Reuse the asset inventory above wherever possible; a pivot that discards all
   four assets needs to be extraordinary to survive scoring.

## Prior strategic thinking (don't rediscover; build on or refute)

The June 2026 venture thesis flagged three latent bigger theses already
supported by the codebase:

- **Allied-health horizontal** — same intake→triage→plan shape for OT, physio,
  dietetics. (Note: constrained this run to SLT/SLP-serving products; an
  SLT-first-then-horizontal sequencing argument is allowed.)
- **Capacity multiplier vs the waiting-list crisis** — sell recovered clinician
  hours as workforce capacity, not admin convenience.
- **Clinical-reasoning evaluation layer** — the eval harness as product:
  benchmark for whether AI can do SLT triage safely.

Known failure modes named by the design partner: kid-facing therapy apps failed
on carryover (2011–2015 wave); generic LLMs unacceptable for PII; every AI
artifact must be clinician-reviewed; no added child screen time.
