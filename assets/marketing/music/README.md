# `assets/marketing/music/` — background audio

This folder currently holds **three candidate tracks** for the demo video's
background music. They are presented for the reviewer to pick from. The
demo video has **not** been re-rendered yet — `out/sona-demo.mp4` still uses
"Hidden Past" from the previous revision until the new selection is
confirmed (per the follow-up brief's deliverable rules).

The previous selection ("Hidden Past" by Kevin MacLeod) was rejected by the
reviewer as too distracting — too contemplative, with a memorable cello
phrase that pulled attention away from the slide content. The candidates
below have all been auditioned against a hard-coded 6-point gate sourced
from the follow-up brief in `docs/marketing/feedback-demo-brief.md`'s
addendum.

---

## How to listen

```bash
# all three preview clips are 30 s, normalised to ~-21.5 LUFS / LRA ≤ 5 LU
# (i.e. the exact volume the final video will use), with 2 s fade in/out.
mpv assets/marketing/music/candidate-1-warm-documentary-preview.mp3
mpv assets/marketing/music/candidate-2-lasting-hope-preview.mp3
mpv assets/marketing/music/candidate-3-light-awash-preview.mp3
```

Each preview is also reproduced as a video for review:
`/opt/cursor/artifacts/music-candidate-{1,2,3}.mp4`.

---

## Candidate 1 — Jake Hunter · "Warm Documentary Background"

- **Tempo:** ~75 BPM · slow, free-tempo feel
- **Key:** Major / warm modal
- **Instrumentation:** Sparse piano + warm sustained string pad (2 layers max)
- **Intended tone:** Delicate ambient wallpaper. Almost no melodic phrasing,
  pure textural support. The safest "invisible background" pick — closest
  to the brief's reference vibe (Tony Anderson / Ólafur Arnalds direction).
- **Loudness (preview):** −21.6 LUFS · LRA 5.3 LU · TP −6.5 dBFS
- **Source length:** 114.9 s (covers the 92.2 s demo without looping)
- **Source file:** `source-jake-hunter-warm-documentary-background.mp3`
- **Licence:** CC BY 4.0 — https://creativecommons.org/licenses/by/4.0/
- **Source URL:** https://freemusicarchive.org/music/jake-hunter/depression-and-sad-emotional-piano-vol-3/warm-documentary-background/
- **Attribution line (must appear on credits slide + README):**
  > "Warm Documentary Background" by Jake Hunter — licensed under CC BY 4.0
  > https://creativecommons.org/licenses/by/4.0/

## Candidate 2 — Kevin MacLeod · "Lasting Hope"

- **Tempo:** ~70 BPM · slow but with a gentle pulse
- **Key:** Major
- **Instrumentation:** Piano + soft string section (2–3 layers)
- **Intended tone:** Warm, mildly hopeful, slightly more melodic than
  Candidate 1 but still reserved — a steady, reassuring backdrop. Best fit
  if the reviewer wants the video to feel _gently optimistic_ rather than
  purely neutral.
- **Loudness (preview):** −21.2 LUFS · LRA 4.0 LU · TP −5.9 dBFS
- **Source length:** 143.9 s
- **Source file:** `source-kevin-macleod-lasting-hope.mp3`
- **Licence:** CC BY 4.0 — https://creativecommons.org/licenses/by/4.0/
- **Source URL:** https://incompetech.com/music/royalty-free/mp3-royaltyfree/Lasting%20Hope.mp3
- **Attribution line:**
  > "Lasting Hope" by Kevin MacLeod (incompetech.com) — licensed under CC BY 4.0
  > https://creativecommons.org/licenses/by/4.0/

## Candidate 3 — Kevin MacLeod · "Light Awash"

- **Tempo:** 0 BPM (no metric pulse) · pure ambient drift
- **Key:** Warm major / modal — no clear tonic motion
- **Instrumentation:** Glowing synthesised pad (1–2 layers). No piano, no
  strings, no transient attacks at all.
- **Intended tone:** Tonally distinct from the two anchors above — a
  motionless sonic blanket rather than a played piece. The reviewer rated
  this _arguably better than the two anchors_ for true invisibility
  behind on-screen text, because pad textures have no hammer/pluck
  transients that can compete with reading attention.
- **Loudness (preview):** −22.1 LUFS · LRA 3.1 LU · TP −5.6 dBFS
- **Source length:** 1 760 s · trimmed in-repo to a 180 s working slice
  starting from a stable section (saves 38 MB)
- **Source file:** `source-kevin-macleod-light-awash.mp3` (trimmed)
- **Licence:** CC BY 4.0 — https://creativecommons.org/licenses/by/4.0/
- **Source URL:** https://incompetech.com/music/royalty-free/mp3-royaltyfree/Light%20Awash.mp3
- **Attribution line:**
  > "Light Awash" by Kevin MacLeod (incompetech.com) — licensed under CC BY 4.0
  > https://creativecommons.org/licenses/by/4.0/

---

## Gate verification (6-point gate from the follow-up brief)

Every candidate above passes every gate.

| Gate | Method | Candidate 1 | Candidate 2 | Candidate 3 |
|---|---|---|---|---|
| 1 · Lyrics / vocals / "ahh"-pad / breath | `videoReview` listen-through with strict reviewer brief | PASS | PASS | PASS (pure synth pad, no vocal formant) |
| 2 · Forgettability (no hummable hook 10 min later) | Same listen-through, explicit melody-hook test | PASS (textural, no hook) | PASS (defined but reserved melody) | PASS (no melody at all) |
| 3 · Integrated loudness in [−23, −20] LUFS | `ffmpeg -af ebur128` two-pass loudnorm to I=−21.5, LRA target 4 | −21.6 LUFS · PASS | −21.2 LUFS · PASS | −22.1 LUFS · PASS |
| 3a · Loudness range ≤ 6 LU | same | 5.3 LU · PASS | 4.0 LU · PASS | 3.1 LU · PASS |
| 4 · Reading test (does audio pull attention from text?) | `videoReview` over title-card | PASS (anchor reference) | PASS | PASS — best of the three for true invisibility |
| 5 · Loop test (covers 90–120 s cleanly) | Source length vs 92 s video target | 114.9 s · no loop | 143.9 s · no loop | 180 s trim · no loop |
| 6 · Licence + attribution | Verified on FMA / incompetech track page | CC BY 4.0 + attribution line above | CC BY 4.0 + attribution line above | CC BY 4.0 + attribution line above |

What was rejected and why (transparency):

- **Round 1 — Music for Creators** (Corporate Inspirational Ambient,
  Inspirational Corporate Background, Uplifting Acoustic Guitar & Piano):
  all rejected — too fast (115–125 BPM), driving electronic beats, or a
  prominent vocal/choir "ahh" pad on Inspirational Corporate Background.
- **Round 1 — Maarten Schellekens** (My Name Is Marth): rejected — fast
  rolling minor-key arpeggios, too foreground and melancholic.
- **Round 2 — Jake Hunter "Calm Documentary Background"**: tonal duplicate
  of "Warm Documentary Background"; only one of the two is presented.
- **Round 2 — Jake Hunter "Harmony Documentary Background"**: rejected —
  relies on a synthetic vocal/choir-like pad.
- **Round 3 — Kevin MacLeod "Floating Cities"**: rejected — choir-like
  vocal pad.
- **Round 3 — Kevin MacLeod "Sincerely"**: rejected — minor key.
- **Round 3 — Kevin MacLeod "Pleasant Porridge"**: rejected — quirky,
  bouncy, very memorable melodic hook.
- **Round 3 — Kevin MacLeod "Truth in the Stones"**: rejected — minor key,
  melancholic plucked harp foreground.
- **Round 3 — Kevin MacLeod "Almost in F"**: passed gates but reviewer
  judged it "cold and sci-fi" rather than warm/healthcare — "Light Awash"
  preferred from the same ambient family.

Pixabay Music was unreachable from this VM (CDN returned HTTP 403); FMA
and incompetech.com are the only pre-approved sources that worked.

---

## When the user has chosen

Per the follow-up brief, after the reviewer picks one candidate:

1. Place the chosen source track at
   `assets/marketing/music/final-<track-name>.mp3` (already staged as
   `source-*.mp3` — just rename the chosen one).
2. Apply gentle side-chain ducking (−3 dB) under caption moments so the
   on-screen text always reads as the foreground. (This will be wired into
   `assets/marketing/video/build-video.sh`.)
3. Add a 2-second fade-in and a 3-second fade-out.
4. Re-render the demo video to `assets/marketing/video/out/sona-demo.mp4`.
5. Update `docs/marketing/README-feedback-demo.md` and the deck's credits
   slide (`assets/marketing/deck/slides-src/13-credits.html`) with the
   chosen attribution.
6. Open a follow-up PR (branch + PR per workspace rules) with the
   re-rendered video and updated docs.

The two unchosen candidate files remain in this folder as documented
alternatives that any future render can swap to with `MUSIC=…`.

---

## Previous and fallback music (kept for context)

- `kevin-macleod-hidden-past.mp3` — the now-superseded selection from
  PR #47. Retained so a reviewer can A/B against the new candidates.
- `kevin-macleod-heartwarming.mp3` — the warmer alternate from PR #47.
- The build script's CC0 generated ambient pad fallback (no file —
  produced by `ffmpeg` at build time) is still active for fully-offline
  builds.

## Pre-approved sources for further swaps

| Source | Licence | URL |
|---|---|---|
| Pixabay Music | CC0 (Pixabay licence) | https://pixabay.com/music/ — **note: unreachable from the cloud-agent VM** |
| Free Music Archive | per-track (filter for CC-BY 4.0; avoid CC-BY-NC and CC-BY-ND) | https://freemusicarchive.org/ |
| YouTube Audio Library | per-track | https://studio.youtube.com/ → Audio Library |
| Incompetech (Kevin MacLeod) | CC-BY 4.0 (attribution required) | https://incompetech.com/music/royalty-free/ |

When swapping, drop the file here and record the title, composer, source
URL, and licence above. If the licence requires attribution (CC-BY), also
update slide 13 of the deck and the demo-video footer.
