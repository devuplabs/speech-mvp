# Sona MVP — Therapist Feedback Demo: Agent Build Brief

> **For:** an Opus 4.7 agent running in this Cursor workspace.  
> **Goal:** Produce a marketing/sales-grade slide deck and short demo video for an upcoming feedback meeting with a practicing speech-language therapist (SLP). Output must be clinician-credible, brand-consistent, and honest about what is built vs designed.

---

## 1. Mission

Build two deliverables a non-technical SLP can react to in a 30-minute feedback session:

1. **A slide deck** (12–18 slides) that walks a Sona-prepared case from parent intake through clinician triage, plan generation, and parent summary — using realistic patient-like personas, not anonymous test data.
2. **A short product demo video** (90–120 seconds) composed from real screenshots, design-fidelity mocks, and clear text annotations, with royalty-free background music.

This is **marketing and sales** material. Polish, brand consistency, and storytelling matter as much as accuracy. But never invent capabilities — see Section 6 "Honesty constraints".

---

## 2. Audience

A practicing speech-language therapist (the meeting attendee). They care about:

- Hours saved per case on intake reading, plan drafting, and parent communication.
- Clinical defensibility (HCPC/RCSLT alignment, EHCP-aware goals, "DRAFT — clinician must review" labels).
- PHI/GDPR safety.
- Whether this fits the realities of their Tuesday afternoon.

They do **not** care about: tech stack, model names, infra, MLOps. Banned words from any clinician-facing copy: LLM, Gemma, Cloud Run, Drizzle, Hono, OTel, Cursor, Flutter, vLLM, INT4, embeddings.

---

## 3. Inputs available in this repo

| Input | Path | Why it matters |
|---|---|---|
| Four synthetic personas | `scripts/personas/*.json` | UK-flavored, clinically realistic. The "patient-like data, not test data" the demo needs. |
| Persona seed script | `scripts/seed-dev.ts` | Stages cases into `intake_submitted`, `prep_ready`, `triaged`, `plan_ready` so every clinician screen has data when captured. |
| Flutter web app | `apps/sona` | The clinician + parent UI you will screenshot. See `AGENTS.md` for `flutter run` command. |
| API | `apps/api` | Backend that drives the screens. See `AGENTS.md` for env vars. |
| ML feature docs | `docs/ml/{prep-brief,triage-capture,session-plan,summary-generator}.md` | Authoritative source for time-savings claims and AI output shapes (Zod schemas). |
| Repo conventions | `AGENTS.md`, `.cursor/rules/*` | Git workflow (PR-only), PHI rules, security reminders. Follow strictly. |

### The four personas

Use **Aria** as the hero of the demo. The others appear briefly in a "case mix" slide.

| Persona | Age | Profile | Why feature |
|---|---|---|---|
| **Aria M.** (`aria_speech_sounds_4yo`) | 4 | Speech-sound delay + mild attention | Explicitly labeled the "core MVP demo" persona; clean, sympathetic, photogenic case. |
| Jaden O. (`jaden_stutter_7yo`) | 7 | Stutter with EHCP | Shows EHCP-aware goal generation. |
| Mia (`mia_social_comm_11yo`) | 11 | Social communication | Shows the older end of the age range. |
| Theo (`theo_feeding_3yo`) | 3 | Feeding | Shows breadth beyond pure speech sounds. |

---

## 4. Documented time savings (use exactly these — do not invent)

Source: `docs/ml/*.md`.

| Stage | Today (manual) | With Sona target | Source |
|---|---|---|---|
| Intake reading + triage prep | 5–10 min/case | –20 % prep time | `docs/ml/triage-capture.md` |
| Session plan drafting | 20–45 min/case | ≤ 15 min (T2P) | `docs/ml/session-plan.md` |
| Parent summary drafting | 15–30 min/case | ≤ 8 min | `docs/ml/summary-generator.md` |
| **Total per case** | **40–85 min** | **15–25 min** | Derived from above |
| At 3–8 cases/week (Monal's stated volume) | 2–11 hr/week | 0.75–3 hr/week | `docs/ml/triage-capture.md` |

Headline claim for the deck: **~30–60 minutes saved per case · roughly 1 admin afternoon per week back at typical caseloads.** Always show the range, not a single number; do not say "Sona saves you 60 minutes." Say "30–60 minutes."

---

## 5. Feature priority (most important first)

| # | Feature | Build state today | Demo treatment |
|---|---|---|---|
| 1 | **8-step parent intake** | Fully built and tested (E2E + widget tests) | Real screen captures via Playwright on running Flutter web. Use Aria persona via "Fill with sample data" dev affordance on the parent welcome screen. |
| 2 | **Clinician dashboard / case list** | Built, partially tested | Seeded captures via `seed-dev.ts` then Playwright. Show all four personas in a realistic queue. |
| 3 | **AI prep brief on case open** | Stub today; design + Zod schema exist | Either screenshot the stub output (clearly labeled as DRAFT) **or** a design-fidelity mock rendered with Sona styles following `docs/ml/prep-brief` shape. Label every AI artifact "AI-drafted · clinician must review". |
| 4 | **Triage capture** (4 outcomes) | UI built, capture flow built | Screenshot the recording UI after clicking through with seeded data. |
| 5 | **Session plan generation** | Stub + ML design doc only | Design-fidelity mock following the Zod schema in `docs/ml/session-plan.md`. Goals, activities, home practice, materials, parent goals. EHCP badge on Jaden's case to show EHCP-aware behavior. |
| 6 | **Parent summary draft** | Stub today | Design-fidelity mock following `docs/ml/summary-generator.md`. Show the tone/reading-level controls. |
| 7 | **Audit trail / "Where every AI suggestion came from"** | Built (`services/audit.ts`) | One slide showing an audit ledger entry — demonstrates clinical defensibility. |

---

## 6. Honesty constraints (non-negotiable)

A practicing clinician will sniff out vaporware. Trust is the asset.

- Every AI-generated artifact in the deck **must** be labeled "DRAFT — clinician must review" (matches the production schema's `label` field).
- One slide near the end is explicitly **"What's real today vs the 90-day vision"**. Use a 2-column table. Real = parent intake, audit trail, case management, slot-based booking, design system. Vision = AI prep/plan/summary drafts wired end-to-end, calendar sync, telehealth.
- AI output samples are produced by **one of two methods only**:
  1. Captured from the stub running locally (labeled "Stub output").
  2. Hand-crafted by you following the Zod schema in `docs/ml/*.md`, rendered with Sona design tokens, labeled "Design-fidelity mock — not generated output".
- All clinical content must be **plausible**: Aria → speech-sound goals, Jaden → fluency + EHCP goals, etc. Cross-check against the persona's `mainConcern` and `difficulties` fields.
- **No real client data, ever.** Personas only. (`.cursor/rules/mvp-security-reminder.mdc`)

---

## 7. Deliverables (file paths)

```
assets/marketing/
├── screenshots/
│   ├── parent-intake/         # real Playwright captures
│   ├── clinician/             # seeded Playwright captures
│   └── ai-mocks/              # design-fidelity HTML/PNG renders
├── music/
│   └── <track>.mp3            # royalty-free, license in README
├── video/
│   ├── src/                   # Remotion project (recommended)
│   ├── out/sona-demo.mp4      # 1920×1080, 30fps, 90–120s
│   └── README.md              # how to re-render
└── deck/
    ├── slides.md              # Slidev source (recommended)
    ├── slides.pdf             # rendered
    └── slides/                # per-slide PNGs

docs/marketing/
└── README-feedback-demo.md    # build instructions + decisions log
```

---

## 8. Recommended technical approach

You may swap any of these for an equivalent tool — justify the swap in `docs/marketing/README-feedback-demo.md`.

| Job | Tool | Why |
|---|---|---|
| Slide authoring | **Slidev** (`npm i -g @slidev/cli`) | Markdown source, Vue components for animation, exports to PDF + PNGs, version-controllable. |
| Video composition | **Remotion** (React-based MP4 render) | Programmatic, deterministic, can re-render after edits. `npm run build` outputs MP4. |
| Screenshot capture | **Playwright** (already in `e2e/`) | Headed mode with `page.screenshot()`, deterministic viewports (1440×900 for laptop, 390×844 for mobile parent flow). |
| Mock AI output renders | Static HTML + Tailwind or extracted Sona tokens, rendered to PNG via Playwright | Consistent with the real Flutter screens. |
| Music | Pixabay Music, Free Music Archive, or YouTube Audio Library | Verify license; embed attribution in `assets/marketing/music/README.md` and a deck credit slide. |
| Voiceover (optional) | Skip for v1 unless user approves. If approved, OpenAI TTS or Google Cloud TTS — needs API key, ask user first. | Captions + music are sufficient. Adding voiceover doubles the iteration cost. |

---

## 9. Storyline (12-slide outline — adapt as needed)

1. **Cold open** — One sentence. "What if the Tuesday-afternoon admin block came back as therapy time?"
2. **Meet Aria** — 4, North London nursery, "drops final consonants and some sounds replaced." Nursery SENCO referred. Photo-free; use illustrative iconography.
3. **Today, this is your inbox** — referral fragments, a phone call, half a form, an email. The chaos baseline.
4. **Parent journey: 8 steps, one phone, ~15 minutes** — animated walkthrough of the real parent intake (3–4 screenshots).
5. **You open the case. Sona has already read it.** — AI prep brief mock: probe areas, red flags, suggested triage pathway with rationale. DRAFT label.
6. **The 20-min free consult, structured in 3 clicks** — triage capture screen.
7. **First-session plan, drafted while you make tea** — session plan mock: 3 SMART goals, activities, home practice, materials. EHCP badge for Jaden's case.
8. **The parent summary writes itself; you edit it** — parent summary mock with tone/reading-level controls.
9. **Every AI suggestion has a paper trail** — audit ledger screenshot.
10. **The math** — table: 40–85 min today → 15–25 min with Sona, sourced from `docs/ml/*`.
11. **What's real today vs the 90-day vision** — honesty slide, 2-column table.
12. **Ask** — "We're booking 30-min feedback sessions this week. What would make Sona switchable for you?"

---

## 10. Workflow

1. **Read first, build second.** Read all four persona JSONs, all four `docs/ml/*.md` files, and `AGENTS.md`. Sketch the slide outline before writing any code or capturing screens. Save the outline to `docs/marketing/outline.md` and ask the user to confirm in the chat before proceeding.
2. **Confirm open questions** (Section 11) in **one batched message** to the user. Do not ping repeatedly.
3. **Spin up the local stack** per `AGENTS.md` (Postgres + API on 8081 + Flutter web on 8080). Run `pwsh scripts/pre-deploy-verify.ps1` first to confirm a clean baseline.
4. **Seed data:**
   ```bash
   SONA_API_URL=http://localhost:8081 \
     PERSONAS=aria_speech_sounds_4yo,jaden_stutter_7yo,mia_social_comm_11yo,theo_feeding_3yo \
     SEED_STAGES=intake_submitted,prep_ready,triaged,plan_ready \
     SEED_PER_STAGE=1 \
     npx tsx scripts/seed-dev.ts
   ```
5. **Capture in three passes:** real parent intake → seeded clinician screens → design-fidelity AI output mocks.
6. **Author the deck** (Slidev). Cross-check every claim against the source in `docs/ml/*`.
7. **Build the video** (Remotion) using captured assets + music + caption overlays.
8. **Render** PDF + PNGs + MP4.
9. **Open a PR** with all assets and `docs/marketing/README-feedback-demo.md`. Never commit to `main`. (Workspace rule.)
10. **Hand off** with: PR link, a one-paragraph "what's in it", the rendered MP4 URL (or local path), and the list of open decisions you needed the user to make.

---

## 11. Open questions to batch to the user before building

Ask these in a **single message** at start of work, with sensible defaults shown so the user can just confirm:

1. **Therapist's name / personalization?** (Will appear on title slide. Default: no name, just "Speech therapist feedback session — May 2026".)
2. **Locale / region for narrative?** (Personas are UK-flavored — London, Leeds, EHCP, GP. Default: keep UK.)
3. **Presentation format priority?** (Slidev → PDF + PNGs is default. Alternative: PowerPoint via `python-pptx`. Default recommended.)
4. **Video length target?** (90s default, hard cap 120s.)
5. **Voiceover?** (Default no. Captions + music only. If yes, OpenAI TTS or Google Cloud TTS — needs API key.)
6. **Sona brand colors?** (Extract from `apps/sona/lib/design_system/` if present; ask user if anything ambiguous.)
7. **Logo asset path?** (Ask user if not in `apps/sona/web/` or `assets/`.)
8. **Permission to use "Monal" as the clinician character in slides** (referenced in `docs/ml/*` as the design partner) **or use generic "Clinician"?**
9. **Music license preference** (Pixabay Music CC0 is default; user may want a specific track or vibe — "calm clinical", "warm professional", etc.).
10. **Distribution target** — internal review only, or will this be posted publicly? (Affects how cautious the "vision vs real" slide must be.)

---

## 12. Quality bar

A clinician should look at the deck cold and understand the value in 3 minutes. The video should hold a non-clinician's attention for the full duration.

- **Visual consistency:** all slides use Sona tokens (colors, typography). No stock template look. No gradients on text, no drop shadows, no emoji.
- **Typography hierarchy:** one big idea per slide. No bullet walls. Where bullets are needed, max 4 items.
- **Captions on every video clip** explaining what's happening and what time is saved.
- **No tech jargon** in clinician-facing copy. Plain English.
- **Every numeric claim traces to a `docs/ml/*` line.** Cite in slide notes.
- **No "AI magic" language.** Sona is "AI-assisted, clinician-reviewed." Always paired.

---

## 13. Constraints (from this workspace's rules)

- **Git workflow:** branch + PR only. Never commit or push to `main`. See `.cursor/rules/mvp-git-workflow.mdc`.
- **PHI:** synthetic personas only. Never substitute real client data. See `.cursor/rules/mvp-security-reminder.mdc`.
- **No ad-hoc GCP deploys.** This is all local capture + repo assets; no `gcloud` commands needed. If you find yourself wanting to deploy something to demo it, stop and ask.
- **No new vendors without approval.** Royalty-free music sources listed above are pre-approved. TTS, video hosting (Vimeo, etc.) require user sign-off.
- **License hygiene:** any asset under `assets/marketing/` must have a license note in `assets/marketing/README.md`.

---

## 14. Definition of done

- [ ] Outline confirmed by user before slide authoring started.
- [ ] PR open from a feature branch (e.g., `feat/feedback-demo`) with all assets.
- [ ] `docs/marketing/README-feedback-demo.md` includes: build commands, license attributions, list of design-fidelity mocks (with the Zod schema each follows), and open decisions log.
- [ ] Slidev deck renders to PDF without errors (`slidev export slides.md`).
- [ ] Remotion project renders to MP4 without errors (`npm run build`).
- [ ] Video is 90–120s, 1920×1080, 30fps, with captions and music.
- [ ] Every numeric claim cites a `docs/ml/*` source in slide notes.
- [ ] No real client data anywhere.
- [ ] No tech jargon in clinician-facing slide copy.
- [ ] `pre-deploy-verify.ps1` still passes on the branch.
- [ ] Final message to the user includes: PR link, video duration, slide count, list of decisions made by you vs by the user, and any known gaps.

---

## 15. If you get stuck

- Slidev not exporting cleanly → fall back to `reveal-md` or `marp-cli`. Note the swap in the README.
- Remotion install too heavy / fails on this machine → fall back to an `ffmpeg`-driven slideshow with `drawtext` filters for captions. Lower polish ceiling but ships.
- Flutter web won't render a screen needed for capture → produce a design-fidelity HTML mock following the same shape, label it "design preview", and note it in the README's gap list.
- Local stack won't start at all → produce a deck-only deliverable using design-fidelity mocks for everything, and flag this clearly in the README.

When in doubt, **ship a smaller, more honest version**. A clinician seeing 8 polished slides will give better feedback than 18 slides where 10 are obvious mockups.
