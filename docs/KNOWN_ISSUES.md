# ComfyUI known issues, fixes, and workarounds (living log)

Maintained weekly by the `comfyui-weekly-update` task from ComfyUI + frontend release notes and the issue tracker,
so the kit knows what is broken BEFORE building a workflow instead of wiring around a known-broken path and
repeating the same mistakes. Every row is sourced. Read this (and the "Real limits" section of
[`ADVANCED.md`](ADVANCED.md)) before assembling a non-trivial graph.

**Last updated: 2026-06-24** (seeded from verified primary-source research; statuses are as of this date and move
as ComfyUI ships fixes).

## Open: bites you when building or running

| Symptom | Cause | Workaround | Source |
|---|---|---|---|
| Black or NaN images after decode | fp16 VAE overflow (esp. SD1.5's fp32-trained VAE; also some fp8 models) | `--fp32-vae` (or `--bf16-vae`); VAE on CPU | gh comfyanonymous/ComfyUI 13116, 2229 ; cli_args.py |
| Color/contrast shift, worse over repeated passes | lossy VAE round-trip; tiled decode auto-triggers under VRAM pressure | encode once, stay in latent, decode once; histogram/LAB match to the source plate | gh 500 |
| A custom node never re-runs | `IS_CHANGED` returning `True` reads as unchanged (`True == True`) | the node must `return float("NaN")` to force a rerun | docs custom-nodes/backend/server_overview |
| Hit Queue, nothing happens (runs in ~0.05s) | stale cache served after a seed change | bust an input, or `--cache-classic` | gh 11905 |
| Per-gen model reload thrash / slower on 4090-5090 | Dynamic VRAM (default since ~Mar 2026) regressions | `--disable-dynamic-vram` | Comfy-Org/ComfyUI discussion 12699 ; desktop 1741 |
| `--lowvram` / `--novram` still OOM at slightly higher res | offload granularity does not cover peak activations | tiled VAE decode, lower res, `--cache-none` | cli_args.py ; gh 5 |
| Single-digit canvas fps on a big graph | litegraph renders all on Canvas2D | collapse into subgraphs, mute/collapse groups, lower link-render quality | gh 7322, 4017 |
| Nested/linked subgraphs break after a browser refresh | subgraph load order is list- not dependency-resolved | save often, avoid deep nesting, keep a `.json` backup | gh 10522 ; frontend 6639, 9979 |
| Half your custom nodes break after an update | numpy 1.x->2.x ABI, or core moved an internal symbol nodes import | pin `numpy<2`; wait for the node author or roll core back | gh 9156, 11660 |
| pip clobbers a working torch when installing a node | dependency conflicts; node deps overwrite shared versions | per-pack venvs, loosen exact pins, a constraints file | docs/development/core-concepts/dependencies ; gh 8882 ; Manager 1136 |
| Output not reproducible even on one machine | ComfyUI is not fully deterministic | `--deterministic` (slower); pin node versions for cross-machine | gh 375 ; discussion 118 |
| A downloaded workflow fails to load entirely | one missing custom node blocks the whole graph; PNG metadata stripped on re-encode | Manager "Install Missing Custom Nodes"; share the `.json`, not a screenshot | gh 6844 |

## Security

- Real malware has shipped through the custom-node channel (ComfyUI_LLMVISION, ultralytics, and Akira-Stealer registry packages). Install only from verified Registry authors; the Registry scans at publish but coverage is partial. (blog/comfyui-2025-jan-security-update ; gh 11791)

## Recently fixed / changed

(none recorded yet. The weekly task adds entries here as ComfyUI release notes mark an issue fixed, with the
version it was fixed in, so a stale workaround above can be retired.)

## How this file is maintained

The `comfyui-weekly-update` task (Monday) reads new `comfyanonymous/ComfyUI` and `Comfy-Org/ComfyUI_frontend`
releases and recently closed/opened issues since the "Last updated" date, then: moves anything the release notes
mark FIXED into "Recently fixed" (with the version), adds genuinely new high-signal bugs to "Open" with a one-line
workaround, and bumps the date. Every row keeps a source (issue / PR / release URL). Still-open entries are not
deleted; only confirmed bugs are recorded (no speculation).
