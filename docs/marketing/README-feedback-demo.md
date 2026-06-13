# Feedback Demo — build, decisions, and gap log

> Companion to `docs/marketing/feedback-demo-brief.md` and `docs/marketing/outline.md`.
> Reading order for a reviewer: brief → outline → this README → assets.

## What got built

| Deliverable | Path | Notes |
|---|---|---|
| 13-slide marketing deck | `assets/marketing/deck/slides.pdf` (and per-slide PNGs in `slides/`) | 12 storyline slides + 1 credits/licence slide. 1920 × 1080 each. |
| Slide HTML source | `assets/marketing/deck/slides-src/` | Hand-authored; uses `theme.css` mirroring Sona design tokens. |
| Design-fidelity AI mocks | `assets/marketing/screenshots/ai-mocks/` | Prep brief · session plan · parent summary · audit ledger. HTML + rendered PNG. |
| Demo video | `assets/marketing/video/out/sona-demo.mp4` | 1920 × 1080 · 30 fps · 92.2 s · stereo AAC audio · 12 slides with caption strip + crossfades · "Lasting Hope" score at −22 LUFS / LRA 4.1 LU, ducked −3 dB at each caption transition, 2 s fade-in / 3 s fade-out. |
| Build scripts | `assets/marketing/deck/render.mjs`, `deck/build-pdf.sh`, `video/build-video.sh` | Idempotent; re-run any step independently. |

## Rebuild

```bash
# from repo root
node assets/marketing/deck/render.mjs          # slides + mocks → PNGs
assets/marketing/deck/build-pdf.sh             # → assets/marketing/deck/slides.pdf
assets/marketing/video/build-video.sh          # → assets/marketing/video/out/sona-demo.mp4
```

Requirements (already installed in the cloud agent VM and on most dev
boxes):

- Node 22 with `@playwright/test` available under `e2e/node_modules`
  (used by `render.mjs` and `capture-flutter.mjs`).
- `python3 -m pip install --user img2pdf` (for the PDF assembly).
- `ffmpeg` ≥ 6 with libx264, libfreetype, aac.
- Inter (`/usr/share/fonts/truetype/macos/Inter-*.ttf`) or DejaVu Sans
  for the video burn-in caption strip.

## Decisions taken (defaults from brief §11)

Recorded for the reviewer to confirm or amend in the PR:

| # | Question | Decision | Rationale |
|---|---|---|---|
| 1 | Title personalisation | "Speech therapist feedback session — May 2026" | Default; agent left this anonymous pre-confirmation. |
| 2 | Locale | UK | Personas + EHCP + GP framing are all UK. |
| 3 | Format | Slidev → PDF + PNGs was the brief default. **We swapped to a Playwright + img2pdf pipeline.** See "Tooling swaps" below. | Same output (PDF + per-slide PNGs); deterministic, lighter install. |
| 4 | Video length | 92.2 s (target 90–120 s) | Hits the band with headroom; lengthening means longer captions or extra slides. |
| 5 | Voiceover | None — captions + music | Avoids TTS vendor approval; keeps iteration cheap. |
| 6 | Brand colours | Sourced from `apps/sona/lib/design_system/sona_colors.dart` | In-repo truth (primary `#2D6A6E`, accent `#F2A878`, AI badge `#FFF0E6 / #C45A1A`). |
| 7 | Logo | `assets/marketing/brand/wordmark.svg` — built from brand tokens (no logo asset in repo) | `apps/sona/web/` only has the default Flutter icons; flag for replacement when a real wordmark exists. |
| 8 | Clinician character | "Monal Gajjar SLT" (already in `apps/sona/lib/features/clinician/clinician_shell.dart`) | Consistent with the in-app clinician identity. |
| 9 | Music | **"Lasting Hope" by Kevin MacLeod** — CC BY 4.0, ~70 BPM major, piano + soft strings. Picked by the reviewer on PR #48 from a 3-candidate shortlist after PR #47's "Hidden Past" was rejected as too contemplative. Normalised to −22 LUFS · LRA 4.1 LU, ducked −3 dB at each caption transition, 2 s fade-in / 3 s fade-out. See `assets/marketing/music/README.md`. | Pixabay CDN blocked from this VM (HTTP 403); incompetech.com reachable. Attribution reproduced on slide 13. |
| 10 | Distribution | Internal review only | Cautious "vision" framing. Flip later if the deck goes public. |

## Tooling swaps from the brief's recommendations (§8)

| Job | Brief recommended | Used here | Why |
|---|---|---|---|
| Slide authoring | Slidev (`@slidev/cli`) | Hand-authored HTML + `theme.css`, rendered with Playwright (Chromium) | Avoids a global Slidev install; output is identical (per-slide HTML → PNG → PDF). Same Markdown-source-of-truth spirit, more explicit. |
| Video composition | Remotion (React MP4 render) | `ffmpeg` slideshow with `xfade` crossfades + `drawtext` caption strip + synthesized ambient pad | Per brief §15 fallback path. Lighter install, deterministic, re-rendered in ~45 s. |
| PDF export | Slidev's `export` | `img2pdf` over the per-slide PNGs at 1920 × 1080 | Bit-exact, no re-rasterisation. |

Each swap preserves the deliverable shape (PDF + PNGs + MP4). No new
vendors were introduced.

## Design-fidelity mocks — schema sources

Every AI artefact rendered in the deck is a **design-fidelity mock**,
labelled as such on the slide and in slide notes. Schemas:

| Mock | File | Schema source |
|---|---|---|
| Prep brief | `assets/marketing/screenshots/ai-mocks/prep-brief.html` | `docs/ml/triage-capture.md` ("topOutcome / confidence / rationale / probeQuestions / redFlags") |
| Session plan | `assets/marketing/screenshots/ai-mocks/session-plan.html` | `docs/ml/session-plan.md` `sessionPlanSchema` Zod |
| Parent summary | `assets/marketing/screenshots/ai-mocks/parent-summary.html` | `docs/ml/summary-generator.md` `parentSummarySchema` Zod (incl. `aiDisclosureFooter` literal) |
| Audit ledger | `assets/marketing/screenshots/ai-mocks/audit-ledger.html` | `services/audit.ts` shape + the "Ethics" rows in each `docs/ml/*` doc |

All four mocks render with `theme.css`, which mirrors
`apps/sona/lib/design_system/sona_colors.dart` token-for-token. Every
mock carries the **"DRAFT — clinician must review"** badge inside the
mock and a **"Design-fidelity mock — not generated output"** strip
embedded in the slide that uses it.

## Honesty checklist (per brief §6)

- [x] Every AI artefact carries "DRAFT — clinician must review".
- [x] Slide 11 is the dedicated "Real today vs 90-day vision" honesty table.
- [x] Mocks labelled in two places: inside the mock and at slide level.
- [x] No real client data — synthetic personas only (`scripts/personas/*.json`).
- [x] No banned tech jargon in clinician-facing copy (LLM, Gemma, Cloud Run, Drizzle, Hono, OTel, Cursor, Flutter, vLLM, INT4, embeddings).
- [x] Time-saving claims always shown as ranges (e.g. 30–60 min), traceable to specific `docs/ml/*` metric lines (see Slide 10 source column).

## Numeric claim → source map (per brief §12)

| Claim on deck/video | `docs/ml/*` source |
|---|---|
| Intake reading + triage prep: 5–10 min today · –20 % with Sona | `docs/ml/triage-capture.md` § Metrics → "Prep time reduction ≥ 20 %"; caseload 3–8/week from § Problem |
| Session plan: 20–45 min today · ≤ 15 min (T2P) with Sona | `docs/ml/session-plan.md` § Metrics → "Time to plan (T2P) ≤ 15 min" |
| Parent summary: 15–30 min today · ≤ 8 min with Sona | `docs/ml/summary-generator.md` § Metrics → "Clinician edit time ≤ 8 min" |
| 40–85 min today → 15–25 min with Sona per case | Derived (rows above) |
| 2–11 hr/week → 0.75–3 hr/week at 3–8 cases | Derived |
| ~30–60 min saved per prepared case · ~1 admin afternoon back per week | Derived (headline range, never a single number) |
| 0 PHI leaves the tenant region | `docs/ml/*.md` Model / Ethics rows + ADR-003 (self-hosted air-gapped LLM) — referenced by the docs even though `docs/decisions/003-*.md` is not in this clone |

## Known gaps (per brief §15 "ship smaller, more honest" guidance)

1. **`docs/ml/prep-brief.md` does not exist in this repo.** The brief
   references it. The prep-brief mock falls back to the shape implied by
   `docs/ml/triage-capture.md` (probes + red flags + suggested outcome
   + rationale). Recommendation: write the prep-brief ML design doc as a
   follow-up to lock the schema.
2. **Real Flutter web captures of the parent intake + clinician
   dashboard are not included.** `capture-flutter.mjs` successfully
   captures the launcher screen (`assets/marketing/screenshots/flutter/launcher.png`)
   but coordinate-based clicks into the deeper Flutter canvas were
   unreliable in this VM and the parent / clinician contexts hit the
   90-s WASM-bootstrap selector timeout known from `AGENTS.md`. The
   deck uses design-fidelity HTML phone mocks for the parent journey
   (slide 4) and an HTML triage capture mock for slide 6. Both are
   labelled. Recommendation: extend the existing Playwright suite in
   `e2e/` with a "marketing-capture" target driven via the JS-bridge
   tests already use, then re-render slides 4 + 6 with real captures.
3. **`pwsh scripts/pre-deploy-verify.ps1` not run.** PowerShell is not
   installed in the cloud agent VM. As a proxy we exercised the API
   (Postgres + tsx watch, migrations applied, seed-dev succeeded for
   all four personas). Recommendation: a reviewer with `pwsh` should
   run the script before sharing the deck externally.
4. ~~No real royalty-free music track~~ — **fixed.** The video now
   uses Kevin MacLeod's "Hidden Past" (CC BY 4.0) at -21 LUFS with
   2 s fade in/out. Earlier the agent shipped a synthesized two-sine
   pad that read as a drone rather than music — that pad is retained
   only as an offline fallback inside `build-video.sh`. Attribution is
   on credits slide 13 and in `assets/marketing/music/README.md`.

## Decisions / change log

| Date | Author | Decision |
|---|---|---|
| 2026-05-26 | Cursor cloud agent | Drafted outline, locked all 10 §11 defaults, scaffolded `assets/marketing/`. |
| 2026-05-26 | Cursor cloud agent | Authored design-fidelity mocks against the four ML schemas. |
| 2026-05-26 | Cursor cloud agent | Rendered 13-slide deck (1920 × 1080) and 92.2-s demo video. |
| 2026-05-26 | Cursor cloud agent | Swapped Slidev → Playwright/img2pdf and Remotion → ffmpeg per brief §8 ("you may swap any of these"). |
| 2026-05-26 | Cursor cloud agent | Bumped video caption strip from top to bottom and crossfades from 0.5 s to 0.8 s after first video-review feedback. |
| 2026-05-26 | Cursor cloud agent | Replaced synthesized ambient pad with Kevin MacLeod's "Hidden Past" (CC BY 4.0) after user feedback that the original sounded like white noise. Added "Heartwarming" as a warmer alternate. Updated build script to support `MUSIC=…` override and a CC0 fallback for offline builds. |
| 2026-05-26 | Cursor cloud agent | Auditioned 17 CC BY 4.0 candidates against a 6-point gate from the music-revision brief; shortlisted three; reviewer picked **"Lasting Hope" by Kevin MacLeod**. Rebuilt `sona-demo.mp4` with the new track, added timed-volume ducking (−3 dB at each of 11 caption transitions, σ=0.4 s) as a side-chain analog, switched fade-out from 2 s to 3 s per the brief. Final loudness −22.2 LUFS, LRA 4.1 LU. |
| 2026-06-13 | Cursor cloud agent | **Phrasing sync to `docs/design/Sona_Care_Journey_Deck.pdf`.** Adopted the canonical positioning **"AI practice partner"** (supersedes "AI co-pilot" / "AI-assisted"). Cold-open (slide 1) strapline now names Sona as the AI practice partner and its chips became the deck's three anchor principles ("AI drafts; clinician decides" · "Augment, never replace" · "UK data residency"). Slide-10 footer reworded to the anchor principles; removed banned "LLM" jargon from the "0 PHI" card. Opening video caption reworded to lead with the positioning. Re-rendered slides 1 + 10 PNGs, `slides.pdf`, and `sona-demo.mp4`. AI-draft badges left unchanged (already express "AI drafts; clinician decides"). |

## Pre-share checklist (for the reviewer)

- [ ] Confirm the 10 defaults in the table above.
- [x] Confirm the music track. Current choice: **"Lasting Hope" by
      Kevin MacLeod** (CC BY 4.0) — picked by the reviewer on PR #48.
      To swap to another CC-BY-clean track, drop the file at
      `assets/marketing/music/final-<track>.mp3` (or set
      `MUSIC=/path …`) and re-run `assets/marketing/video/build-video.sh`.
      Update the attribution line on slide 13 if the new track is CC-BY.
- [ ] Run `pwsh scripts/pre-deploy-verify.ps1` from a machine with
      PowerShell installed.
- [ ] Optional: extend Playwright to drive `apps/sona` past the
      launcher and replace slides 4 + 6 captures with real screens.
- [ ] Replace `assets/marketing/brand/wordmark.svg` with a real
      Sona logo asset if/when one is added to the repo.
