# Vendored few-shot seeds (DEV-14)

This directory holds a **checked-in snapshot** of the few-shot persona seeds
exported by [speech-ml](../../../../../speech-ml) (`eval/few_shot/*.jsonl`). They
are injected as few-shot examples into the draft-generation prompts in
[`../generate-drafts.ts`](../generate-drafts.ts) via
[`../few-shot.ts`](../few-shot.ts), to improve draft quality and consistency over
the previous zero-shot prompts.

## Why vendored

API deploys must be **hermetic** — no runtime dependency on the speech-ml repo.
So the seeds are copied in and compiled into the build:

- `data/*.jsonl` + `data/index.json` — verbatim copy of the upstream export.
  Kept in-tree so changes show up in review diffs (provenance / golden-data
  style). Not loaded at runtime.
- `few-shot-data.ts` — **generated** TypeScript module that the API imports.
  Generating a `.ts` (instead of reading `.jsonl` at runtime) means `tsc`
  bundles the data into `dist/` normally, with no file IO and no copy step in
  the production build.
- `PROVENANCE.json` — source commit/date + per-bucket counts.

Both `few-shot-data.ts` and `data/` are auto-generated — **do not edit by hand.**

## Re-syncing

```sh
cd apps/api
npm run sync:few-shot                       # default source: /home/user/speech-ml/eval/few_shot
FEW_SHOT_SRC=/path/to/eval/few_shot npm run sync:few-shot
```

The sync script is [`../../../scripts/sync-few-shot.mjs`](../../../scripts/sync-few-shot.mjs).
After re-syncing, run `npm test` — the prompt snapshot tests will flag any
example/prompt drift for review.

## Parity with the eval harness

The rendered example format in `../few-shot.ts` mirrors the gist fields that
speech-ml's eval harness scores against
(`speech-ml/eval/runner/prompts.py`). If the upstream export schema or the eval
prompt shapes change, re-sync here and keep the rendering in step so prompt
parity is maintained.
