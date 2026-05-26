# `assets/marketing/music/` — background audio

## Default: generated ambient pad (CC0)

The demo video uses a soft ambient pad that is **generated at build time
by `ffmpeg`** in `assets/marketing/video/build-video.sh`. The pad is two
stacked sine waves (220 Hz + 277.18 Hz, ~A3 + C♯4), heavily low-pass
filtered, at ~10% volume, with 1.5-s fade in/out.

Because it is synthesized from primitive operators with no third-party
material, it is **CC0** (own work). No attribution required.

## Why generated rather than a track from Pixabay / Free Music Archive

This cloud agent's network policy could not fetch from Pixabay's CDN
(HTTP 403). Free Music Archive and Incompetech reachable but no track was
selected without explicit user sign-off on the vibe. The generated pad is
the most license-clean, deterministic, self-contained option, and is
trivial to swap.

## Swapping in a real track

Drop a file into this folder (recommended licences below) and update
`assets/marketing/video/build-video.sh` to use it instead of the
synthesized pad:

```bash
# In build-video.sh, replace the "Generate gentle ambient pad" block with:
AUDIO="$HERE/music/<your-track>.mp3"
```

Pre-approved sources (per brief Section 8):

| Source | Licence | URL |
|---|---|---|
| Pixabay Music | CC0 (Pixabay licence) | https://pixabay.com/music/ |
| Free Music Archive | per-track (filter for CC-BY / CC0) | https://freemusicarchive.org/ |
| YouTube Audio Library | per-track | https://studio.youtube.com/ → Audio Library |
| Incompetech (Kevin MacLeod) | CC-BY 4.0 | https://incompetech.com/music/royalty-free/ |

Record the chosen track's title, author, source URL, and licence here
when you commit a track.
