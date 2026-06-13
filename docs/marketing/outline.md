# Sona — Therapist Feedback Demo · Slide Outline

> Draft outline produced per `docs/marketing/feedback-demo-brief.md`.
> Run autonomously by the Cursor cloud agent. The "Decisions taken" block below
> records the defaults applied for the open questions in Section 11 of the brief
> so the reviewing clinician/PM can confirm or amend in the PR.

---

## Storyline (12 slides)

| # | Slide | One-liner | Source / asset |
|---|-------|-----------|----------------|
| 1 | **Cold open** | "What if Tuesday afternoon's admin block came back as therapy time?" — strapline introduces Sona as the **AI practice partner** for private SLT. | Plain title card; brand teal background. |
| 2 | **Meet Aria** | 4-year-old, North London nursery, "drops final consonants and some sounds replaced." Nursery SENCO referral. | Persona `aria_speech_sounds_4yo` — illustrative iconography, no photo. |
| 3 | **Today this is your inbox** | A referral fragment, a phone call, a half-finished form, an email — chaos baseline. | Static visual; no real PHI. |
| 4 | **Parent journey: 8 steps, one phone, ~15 minutes** | Animated walk-through of the real parent intake (Aria). | Real Playwright captures from `apps/sona` parent flow (3–4 stills). |
| 5 | **You open the case. Sona has already read it.** | AI prep brief — probe areas, red flags, suggested triage pathway with rationale. | Design-fidelity mock following `docs/ml/triage-capture.md` Zod shape. DRAFT label. |
| 6 | **The 20-minute consult, structured in 3 clicks** | Triage capture screen with 4 outcomes. | Seeded Playwright capture of the triage screen (Aria → `short_block`). |
| 7 | **First-session plan, drafted while you make tea** | Session plan mock — 3 SMART goals, activities, home practice, materials, parent goals. EHCP badge for Jaden. | Design-fidelity mock following `docs/ml/session-plan.md` schema. |
| 8 | **The parent summary writes itself; you edit it** | Parent summary mock with tone & reading-level controls. | Design-fidelity mock following `docs/ml/summary-generator.md` schema. |
| 9 | **Every AI suggestion has a paper trail** | Audit ledger entry — clinician defensibility. | Design-fidelity mock from `services/audit.ts` shape. |
| 10 | **The math** | 40–85 min today → 15–25 min with Sona. ~1 admin afternoon/week back at typical caseloads. | Numbers traced to `docs/ml/triage-capture.md`, `session-plan.md`, `summary-generator.md`. |
| 11 | **Real today vs the 90-day vision** | Honesty slide, two columns. | Real: parent intake, audit, case management, slot booking, design system. Vision: AI prep/plan/summary wired end-to-end, calendar sync, telehealth. |
| 12 | **Ask** | "We're booking 30-minute feedback sessions this week. What would make Sona switchable for you?" | Plain CTA card. |

A bonus credit card (off-numbering) covers music & data licensing.

---

## Positioning & phrasing (synced to `docs/design/Sona_Care_Journey_Deck.pdf`)

The marketing visuals use the canonical positioning from the Care Journey deck:

- **Sona is the "AI practice partner"** for private speech & language therapy
  (supersedes the earlier "AI co-pilot" / "AI-assisted" framing).
- **Anchor principles** (used as the cold-open chips and the slide-10 footer):
  1. "AI drafts; the clinician decides."
  2. "Augment people, never replace them."
  3. "UK data residency + audit."
- AI artefacts remain labelled **"DRAFT — clinician must review"**, which is the
  product-schema expression of principle 1 — already consistent, left unchanged.
- No banned tech jargon in clinician-facing copy (the slide-10 "0 PHI" card no
  longer mentions "LLM").

---

## Hero persona

**Aria M.** — `aria_speech_sounds_4yo`
- 4 years, London NW3, nursery SENCO referral.
- Concern: "drops final consonants, some sound replacement." Mild attention drift.
- Demo path: `intake_submitted → prep_ready → triaged (short_block) → plan_ready`.

Case-mix appearances (Slide 11 strip): **Jaden (EHCP badge)**, Mia, Theo.

---

## Quantitative claims (every number cites a source)

| Claim | Source line |
|---|---|
| Intake reading + triage prep, today 5–10 min, target –20 % | `docs/ml/triage-capture.md` § Metrics → "Prep time reduction ≥ 20 %", caseload 3–8/week |
| Session plan today 20–45 min, target ≤ 15 min (T2P) | `docs/ml/session-plan.md` § Metrics → "Time to plan ≤ 15 min" |
| Parent summary today 15–30 min, target ≤ 8 min | `docs/ml/summary-generator.md` § Metrics → "Clinician edit time ≤ 8 min" |
| Headline: 30–60 min/case · ~1 admin afternoon/week back | Derived from rows above. Use range, never single number. |

Banned words in clinician copy: LLM, Gemma, Cloud Run, Drizzle, Hono, OTel, Cursor, Flutter, vLLM, INT4, embeddings.

---

## Honesty rules applied

- Every AI artefact in deck/video carries **"DRAFT — clinician must review"** and **"AI-drafted · clinician reviewed"** badges.
- Mocks rendered using Sona design tokens (`apps/sona/lib/design_system/sona_colors.dart`) and labeled **"Design-fidelity mock — not generated output"** in slide notes and on-asset where space allows.
- Real-vs-vision slide is mandatory and explicit.
- No real client data; personas only.

---

## Decisions taken (defaults from Section 11)

| # | Question | Decision | Rationale |
|---|---|---|---|
| 1 | Title personalisation | "Speech therapist feedback session — May 2026" | Default; safer pre-confirmation. |
| 2 | Locale | UK | Personas + EHCP + GP language are all UK. |
| 3 | Format | Slidev → PDF + PNGs | Default; version-controllable. |
| 4 | Video length | 95 s (within 90–120) | Hits the target; leaves headroom. |
| 5 | Voiceover | None — captions + music | Captures key value in slide notes; avoids TTS vendor approval. |
| 6 | Brand colors | From `apps/sona/lib/design_system/sona_colors.dart` (primary `#2D6A6E`, accent `#F2A878`, AI badge `#FFF0E6 / #C45A1A`). | In-repo source of truth. |
| 7 | Logo | Wordmark composed from brand tokens (no logo file in repo). | No PNG in `apps/sona/web/`; flagged for replacement when one exists. |
| 8 | "Monal" in slides | Use "Monal Gajjar SLT" — she already appears in the clinician shell UI (`apps/sona/lib/features/clinician/clinician_shell.dart`). | Consistent with screen captures. |
| 9 | Music | Pixabay (CC0) — "calm clinical / warm professional". Will fall back to a soft generated pad if network access in CI/cloud is unavailable, and document the swap. | Pre-approved source per brief Section 8. |
| 10 | Distribution | Internal review only (cautious "vision" framing). | Default; flip later if a public version is needed. |

---

## Known risks & gaps (kept honest)

- `docs/ml/prep-brief.md` is referenced by the brief but **does not exist** in this repo. The prep brief mock therefore follows the Zod shape implied by `docs/ml/triage-capture.md` (probes + red flags + suggested outcome + rationale). Noted in `docs/marketing/README-feedback-demo.md`.
- The brief calls for `pwsh scripts/pre-deploy-verify.ps1` as a clean-baseline check. The cloud agent's Linux VM may not have `pwsh` installed; if so the README will document the fallback (run `npx tsc --noEmit` in `apps/api` and `flutter analyze` in `apps/sona`).
- If the Flutter web build cannot be captured in this environment (WASM cold-start exceeds budget, or `flutter` device unavailable), the deck falls back to design-fidelity mocks for those slides and the README records each substitution per brief Section 15.

---

## Build order

1. Scaffold `assets/marketing/` directories.
2. Author design-fidelity HTML mocks (prep brief, session plan, parent summary, audit ledger).
3. Spin up Postgres + API; seed canonical personas via `scripts/seed-dev.ts`.
4. Capture parent intake + clinician screens with Playwright at 1440×900 / 390×844.
5. Render mocks to PNG via Playwright.
6. Author Slidev `slides.md`, render PDF + per-slide PNGs.
7. Compose 95-s MP4 from the per-slide PNGs (Remotion if it installs cleanly, otherwise `ffmpeg` slideshow per brief Section 15).
8. Write `docs/marketing/README-feedback-demo.md` (build commands, licences, decisions log, gap list).
9. Push branch, open PR.
