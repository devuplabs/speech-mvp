# `assets/marketing/music/` — background audio

## Current track — "Lasting Hope" by Kevin MacLeod

The demo video at `assets/marketing/video/out/sona-demo.mp4` uses
**"Lasting Hope" by Kevin MacLeod**, chosen by the reviewer from a
three-candidate shortlist on PR #48.

- **File:** `final-lasting-hope.mp3`
- **Tempo:** ~70 BPM · slow with a gentle pulse
- **Key:** Major
- **Instrumentation:** Piano + soft string section (2–3 layers)
- **Source URL:** https://incompetech.com/music/royalty-free/mp3-royaltyfree/Lasting%20Hope.mp3
- **Licence:** Creative Commons Attribution 4.0 International (CC BY 4.0) ·
  https://creativecommons.org/licenses/by/4.0/

In the final render the track is:

- Normalised to **−22 LUFS** with **LRA 4.1 LU** (verified by `ebur128`).
- Ducked by **−3 dB** at each of the eleven caption-transition moments
  using a Gaussian envelope (σ = 0.4 s), so on-screen text always reads
  as the foreground.
- Faded in over **2 s** at the start and out over **3 s** at the end.

### Required attribution

Reproduce this line wherever the rendered video or deck is shared:

> "Lasting Hope" by Kevin MacLeod (incompetech.com)
> Licensed under Creative Commons: By Attribution 4.0 License
> https://creativecommons.org/licenses/by/4.0/

The attribution is already on:

- Credits slide 13 of the deck (`assets/marketing/deck/slides-src/13-credits.html`).
- This README.
- `docs/marketing/README-feedback-demo.md` decisions log.

## Candidate previews & alternates (kept in folder)

The two unchosen shortlist tracks remain available as documented
alternates. To swap, run the build script with `MUSIC=…`:

```bash
# Use Jake Hunter — Warm Documentary Background instead:
MUSIC=$(pwd)/assets/marketing/music/source-jake-hunter-warm-documentary-background.mp3 \
  assets/marketing/video/build-video.sh
```

Wait — those source files were **removed** when "Lasting Hope" was
promoted. To swap, redownload from FMA / incompetech, drop into this
folder, and point `MUSIC=…` at it.

The 30-second auditioning previews are still present so anyone reviewing
the PR can re-listen without re-downloading sources:

| File | Track | Licence | Notes |
|---|---|---|---|
| `candidate-1-warm-documentary-preview.mp3` | Jake Hunter — Warm Documentary Background | CC BY 4.0 | Sparse piano + warm string pad. Was the alternate. |
| `candidate-2-lasting-hope-preview.mp3` | Kevin MacLeod — Lasting Hope | CC BY 4.0 | **The chosen track.** |
| `candidate-3-light-awash-preview.mp3` | Kevin MacLeod — Light Awash | CC BY 4.0 | Pure ambient pad, no piano transients. Was the alternate. |

## Selection history

| Round | Outcome |
|---|---|
| PR #46 (initial) | Synthesized two-sine pad. Reviewer feedback: "sounds like white noise." |
| PR #47 | Kevin MacLeod — "Hidden Past". Reviewer feedback: too contemplative, memorable cello melody pulled attention. |
| PR #48 | Three CC BY 4.0 candidates auditioned against a 6-point gate. Reviewer picked **"Lasting Hope"**. |

The previous "Hidden Past" and "Heartwarming" files are kept in this
folder for traceability but are no longer the default. The build script
defaults to `final-lasting-hope.mp3` and falls back to a CC0
sine-generated pad only if the file is missing.

## Pre-approved sources for further swaps

| Source | Licence | URL |
|---|---|---|
| Pixabay Music | CC0 (Pixabay licence) | https://pixabay.com/music/ — **unreachable from cloud-agent VM** |
| Free Music Archive | per-track (filter for CC-BY 4.0; avoid CC-BY-NC and CC-BY-ND) | https://freemusicarchive.org/ |
| YouTube Audio Library | per-track | https://studio.youtube.com/ → Audio Library |
| Incompetech (Kevin MacLeod) | CC-BY 4.0 (attribution required) | https://incompetech.com/music/royalty-free/ |

When swapping, drop the file at `final-<track>.mp3`, update this
README's "Current track" block, the credits slide, and the demo-video
docs.
