# Changelog

All notable changes to **ComfyUI-Agent-Kit** are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow
[Semantic Versioning](https://semver.org/). Dates are YYYY-MM-DD. The raw, per-commit history lives in git;
this file is the curated summary.

**How the numbers work (`MAJOR.MINOR.PATCH`):** bump **PATCH** for backward-compatible bug fixes, **MINOR** for
new backward-compatible features (most updates here, e.g. new model recipes or a new agent adapter), and **MAJOR**
for a breaking change (e.g. renaming a config key or the install layout). `0.x` was pre-release development;
`1.0.0` is the first stable public release. To cut a release: decide the bump from what sits under `[Unreleased]`,
rename it to `[x.y.z] - <date>`, tag the commit (`git tag -a vx.y.z -m ...`), and push the tag (`git push origin
vx.y.z`), which can become a GitHub Release.

## [Unreleased]

### Added
- **Node knowledge library (`docs/NODE_LIBRARY/`).** A per-node reference in the spirit of The Foundry's Nuke node docs: for each node, what each input / output is for, how it behaves, strengths, bugs + fixes, anti-patterns, and where it slots in a graph. Live I/O stays sourced from `get_node_info` / `/object_info`; the library holds the durable curated layer on top. Ships the index (`_INDEX.md`), the format + rules (`_SCHEMA.md`), the core text-to-image chain (`core.md`, all I/O confirmed on ComfyUI 0.25.1), and color / transform (`color-and-transform.md`). Routed from `SKILL.md`; grows on encounter (use or meet an undocumented node, add its entry).
- **Log-space transform technique.** Manual (non-AI) pixel geometry (scale, rotate, distort, warp, skew, any resample) should be done in a log-encoded space (Linear->Log, transform, Log->Linear) to preserve highlight / shadow detail, a Nuke / OCIO production practice. We ship the node for it as `OCIOLogConvert` in our new ComfyUI-OCIO pack (ACEScct, HDR-safe, reversible). Documented in `docs/ADVANCED.md`, `docs/NODE_LIBRARY/color-and-transform.md`, and `docs/NODE_LIBRARY/ocio.md`, with the native EXR / linear path via `SaveImageAdvanced` / `REDACTEDSave`.
- **Node inventory (`docs/NODE_LIBRARY/_INVENTORY.md`) + generator (`tools/node_inventory.py`).** The master catalog of every node type used across the kit's workflow library: 552 distinct types across 448 workflows (official template bundles + our saved workflows), classified against a live ComfyUI (185 core, 194 API / cloud partner, 9 custom-author, 3 missing-but-used, 161 subgraph ids). Regenerable, so a future agent sees the full universe before documenting or building.
- **Custom-author node entries (`docs/NODE_LIBRARY/custom-author.md`).** The two author packs whose nodes appear in our workflows, I/O confirmed via get_node_info: ComfyUI-REDACTED (Load / ToTangent / SeedVR2 / FromTangent / Save; its log node moved to ComfyUI-OCIO) and ComfyUI-LTXVideo (HDR decode postprocess, IC-LoRA guide + loader, Gemma API encode). kijai packs stay in `docs/KIJAI.md`.
- **Node library: full category reference (183 entries).** Per-node documentation for every core node used across the kit's workflows, one file per category (loaders, samplers, conditioning x2, image x2, latent, advanced, 3d, video, audio, text, utilities, experimental): purpose, per-input/output semantics, strengths, bugs, anti-patterns, placement. I/O confirmed via get_node_info; built by a subagent-per-category fan-out and validated (0 dashes, no leaked filenames, node-count match). API / cloud-partner nodes (194) are catalogued in `_INVENTORY.md`; per-node entries are the next wave.
- **ComfyUI-OCIO documented (`docs/NODE_LIBRARY/ocio.md`).** Our new OpenColorIO node pack (Slava Sexton; six nodes modelled on Nuke's OCIO set: ColorSpace, LogConvert, Display, CDLTransform, FileTransform, LookTransform) is documented in the library. The log-space node moved here from ComfyUI-REDACTED as `OCIOLogConvert`. Runtime-verified against OpenColorIO 2.5.2.

## [1.9.0] - 2026-06-29

### Added
- **Claude Code plugin + marketplace.** The kit now installs as a Claude Code plugin:
  `/plugin marketplace add SlavaSexton/ComfyUI-Agent-Kit` then `/plugin install comfyui@comfyui-agent-kit`. The
  plugin (`claude-code/`) bundles the full `comfyui` skill + a `.mcp.json` that launches the local `comfyui-mcp`
  driver via `npx` (no manual npm step, no setup hook needed - the skill self-bootstraps the machine block).
  Additive: the multi-agent installer is unchanged and stays the path for Codex / Gemini CLI / Qwen Code (plugins
  are Claude Code only). `tools/build_plugin.py` assembles the bundled skill from the canonical sources so it never
  drifts. This is the local-first counterpart to the official Comfy Cloud MCP, installable the same way.

### Changed
- **README repositioned** to lead with local-first / your-GPU / multi-agent / cloud-independent, framing the kit
  as the deliberate local counterpart to the official Comfy Cloud MCP (gracious, not a knock).

## [1.8.0] - 2026-06-29

### Added
- **Task-recipe layer (`docs/TASKS.md`).** A shortcut over the operating manual: each common job (generate
  image / video / audio / 3D, upscale, remove background) mapped to its local end-to-end flow (find a template,
  hardware-aware model pick, read the MODELS.md dialect, validate, run small, save). Local-first; complements the
  model-centric MODELS.md and is wired into the SKILL.md routing map.
- **Multi-reference identity-compositing technique (`docs/ADVANCED.md`).** Combining two specific faces into one
  image: two real references + `ImageBatch` + explicit "the first image is X" prompting + the face-accuracy
  ranking (Nano Banana 2 HIGH thinking > Nano Banana Pro > Kling O3 > FLUX Kontext > SDXL).

### Changed
- **SKILL.md validation now checks for an output/save node.** Before running, confirm the graph has an input AND
  an output/save node; API and partner nodes (Kling, Nano Banana, Veo, Gemini, ...) often emit a tensor but include
  no save node by default, so the job runs and produces nothing retrievable.

The task-layer shape, the save-node guard, and the compositing technique are adapted from `Comfy-Org/comfy-skills`
(MIT) for the local stack, credited in README + ATTRIBUTION. No files vendored.

## [1.7.0] - 2026-06-27

### Added
- **Four new models from the official Comfy source sweep** (the pre-release check that the v1.6.x cuts had skipped; run now against the live `Comfy-Org/workflow_templates` + blog):
  - **Boogu Image 0.1** - new open-weight (Apache-2.0, not gated) image recipe: Base / Turbo (few-step distilled) / Edit variants, Qwen3-VL-8B text encoder + FLUX VAE, official Comfy-Org templates, GGUF for low VRAM. Recipe families 66 -> 67.
  - **Seedance 2.0 Mini** - faster, cheaper variant noted in the Seedance entry (same `ByteDance2*Node`, `api_seedance2_0_mini_{t2v,r2v}` templates).
  - **Luma Ray 3.3** - added to the Luma entry via `LumaRay32TextToVideoNode` (+ the extend node, chained by `generation_id`).
  - **Qwen3-VL TextGenerate** - in-graph local VLM (caption / VQA / prompt generation), the no-API counterpart to the Claude prompt nodes.
  Counts refreshed everywhere (67 recipes, 545 templates, 149 models) including the cover and both breakdown charts, recomputed from the official template manifest. The REDACTED side was clean (export already triaged through its latest message).

## [1.6.1] - 2026-06-27

### Fixed
- **Bernini-R ComfyUI tutorial URL** corrected to `docs.comfy.org/tutorials/video/bytedance/bernini-r`
  (it had pointed at the Anima tutorial). Caught by the post-release completeness re-check.
- **HappyHorse reference-image count** clarified: the official ComfyUI template wires 3 slots
  (image1-3), now noted alongside the API's "up to 9".

## [1.6.0] - 2026-06-27

### Added
- **ComfyUI build paths for entries that were missing them.** Cited the verified ComfyUI graph for
  model/tool entries that named the model + repo but no build path: official Comfy-Org templates
  (ChronoEdit, FireRed, Capybara, Bernini-R, VOID, OmniGen2), community nodes (HuMo, SCAIL-2,
  ChatterBox, Tripo `TripoAPIDraft`, Rodin `mRodin3D_Gen2`, Meshy), and kijai WanVideoWrapper
  (FlashVSR). Every node class was read from the repo's `NODE_CLASS_MAPPINGS`, not invented.
- **Krea 2 community ecosystem + LTX-2.3 3DREAL.** Enriched the Krea 2 entry: fal's ~1503 community style LoRAs
  (`ilkerzgi/fal-Krea-2-Style-LoRAs`, trigger at prompt end, scale 1.0-1.25), the weak-VAE workaround (swap the
  Qwen-Image VAE for the WAN 2.1 VAE or NVIDIA PiD / Pixel Diffusion Decoder, `nv-tlabs/PiD`), and reference image+mask
  control via `ComfyUI-Krea2TextEncoder` (ethanfel, MIT, the `TextEncodeKrea2` node). Added `fal/LTX-2.3-3DREAL-LoRA`
  (trigger `3DREAL`) to the LTX-2.3 IC-LoRA list: a 3D viewport / Blender render to photoreal video LoRA (run via fal
  render-to-real or as an LTX V2V IC-LoRA). All read from the real cards / repos and credited in ATTRIBUTION.
- **LTX-2.3 Water Simulation IC-LoRA.** Documented `Lightricks/LTX-2.3-22b-IC-LoRA-Water-Simulation` (file
  `ltx-2.3-22b-ic-lora-water-simulation-0.9.safetensors`, gated `license:other`, video-to-video, published
  2026-06-25) in the LTX-2.3 IC-LoRA list: adds realistic water / seawater to a clip. No dedicated workflow ships in
  ComfyUI-LTXVideo yet (pack last updated 2026-06-17), so it runs via the generic
  `LTX-2.3_V2V_ICLoRA_Single_Stage_Distilled.json` + `LTXICLoRALoaderModelOnly`. Full recipe read from the (authenticated)
  gated model card: the `ADD WATER` trigger in a dual-panel reference/edited prompt, strength sweet spot 1.2, and the
  critical "distilled stage-1 only at native resolution" recipe (the two-stage upscaler drifts subject identity), plus
  the 6 official gallery example prompts (read from the card's `widget:` frontmatter).

### Fixed
- **Full-kit audit: 206 entries across 15 sections, adversarially verified.** Each error was
  re-checked at the primary source before fixing (additive/corrective, no degradation): removed a
  fabricated "+ ComfyUI nodes" claim (BRIA) and unverified Krea-1 gallery prompts; corrected Grok
  (five-part to six-part), Seedance (`_real_human` only on r2v/flf2v), ElevenLabs (`duration`
  0.5-30s), SeedVR2 (4n+1 adds 17), the four Krea-2 LoRA trigger capitalizations, and Meshy
  (negatives ARE supported); fixed three licenses against the GitHub API (Marigold GPL-3.0, StableX
  no-LICENSE, Veevee GPL-3.0); Wan2.1-VACE `--model_name` (not `--task`); the LBM weight filename;
  the DDColor maintained fork; the LivePortrait repo move; and several stale source URLs. Four of
  the fixes were errors in this release's own new build paths (Bernini-R URL, HuMo modes, SCAIL-2
  masks, FlashVSR GPU list). The audit also flagged 17 `node template X.md` refs as phantom; they
  were left untouched, being valid pointers to the external `alexmunteanu/comfyui-anthropic-claude`
  templates (a false positive, verified present at source).
- **HF model-card corrections (token-authenticated).** Re-read the full gated cards (frontmatter
  `widget:` prompts + body) and fixed the entries that had drifted from them.

## [1.5.0] - 2026-06-25

### Added
- **kijai ecosystem mega-brain (`docs/KIJAI.md`).** Deep-researched all 62 of kijai's ComfyUI repos (read live from
  github.com/kijai on 2026-06-24, dated) into a structured reference: a "pick a tool by task" table, a supersede map
  (old to better, e.g. HunyuanVideoWrapper to native HunyuanVideo, SUPIR to core SUPIR, CogVideoXWrapper to
  WanVideoWrapper), per-tool node I/O + usage + compat for the 28 active tools, legacy one-liners, and a "what to
  disable now" list. Built by a 62-agent deep-research workflow; every node list read from the real repo code.
- **SKILL.md routing map ("Files in this kit").** SKILL.md now lists every supporting doc with a "when to read it"
  trigger, so MODEL_INDEX / ADVANCED / KNOWN_ISSUES / KIJAI / LTX2_TRAINING / EXAMPLE_WORKFLOWS are pulled on demand
  instead of sitting unread (four were previously orphaned with no pointer in SKILL.md).
- **Crop-and-stitch inpainting technique + HallettVisual Smart Image Crop and Stitch.** New ADVANCED.md section on
  detailed inpainting of a high-res image: crop the masked region, size it to the model's native resolution, generate,
  stitch back. Documents the established `comfyui-inpaint-cropandstitch` and the auto-sizing alternative
  `SmartImageCrop` / `SmartImageStitcher` (HallettVisual, Apache-2.0, ships a Flux Klein workflow), flagged as new.
  Credited in ATTRIBUTION + README. Verified against the repo and its shipped workflow.

### Changed
- **HappyHorse recipe upgraded 1.0 -> 1.1 (synchronized audio).** Native in-pass audio (dialogue / SFX / music),
  up to 9 reference images with no cross-contamination, long-context prompts (2,500+ chars, 6-8 scenes), full
  cinematic language, and the shipped ComfyUI nodes (`HappyHorseTextToVideoApi` / `ImageToVideoApi` /
  `ReferenceVideoApi`) plus the official `api_happyhorse1_1_{t2v,i2v,r2v}` templates. Verified against the
  templates and blog.comfy.org/p/happyhorse-11-is-now-available-in.
- **Seedance 2.0 now does 4K.** Added 4K to the Seedance recipe (smoother gradients, richer tones, detail that
  holds through motion and into post) plus the shipped official ComfyUI templates and modes: T2V, R2V, and
  first/last-frame (FLF2V), each with a `_real_human` variant. Verified against the `api_seedance2_0_*` templates.

## [1.4.0] - 2026-06-24

### Added
- **Flux.2 Klein identity-transfer suite (community field recipe).** Documented `capitan01R/ComfyUI-Flux2Klein-Enhancer`
  in the FLUX.2 entry: training-free multi-reference identity-preserving editing for FLUX.2 Klein 9B via the Identity
  Feature Transfer Final node (attention-output patch, up to 8 reference latents + per-subject masks, HARD/MID/SOFT_LOCK
  presets), plus Color Anchor, Sectioned Encoder, and reference controllers. Credited capitan01R in README and
  ATTRIBUTION and flagged the PolyForm Noncommercial 1.0.0 license.
- **Workflow layout discipline in the skill.** Expanded SKILL.md with a "Lay the graph out cleanly" section:
  columns by stage, a per-column y-cursor for zero node overlap, one Group box per stage, Reroute for long wires,
  and a tidy pass, so assembled graphs read as a structured pipeline instead of a pile of overlapping nodes.
- **Subgraphs guidance in the skill.** Added a "Collapse a stage into one reusable node (Subgraphs)" section to
  SKILL.md: collapse a selection into one super-node, expose only the needed widgets, publish it as a reusable
  Subgraph Blueprint (the kit's `blueprints/` bricks), nest and unpack. Notes that Subgraphs (official 2025-08)
  supersede the legacy Group Nodes. Verified against docs.comfy.org/interface/features/subgraph.
- **Creator-level reference: `docs/ADVANCED.md`.** A new deep reference distilled from primary sources (multi-agent
  research, each tool verified against its real page): ComfyUI's genuine strengths; the real limits and gotchas with
  workarounds (Dynamic VRAM regressions, VAE black/NaN + color shift, the IS_CHANGED footgun, canvas lag, custom-node
  malware/version-hell); temporal stability / anti-flicker for sequences (native video models + VACE + context windows
  + FreeNoise, structure-lock ControlNet, deflicker/interpolation as finishers); the honest state of PBR/material-pass
  generation from footage (not solved temporally in 2026; the realistic per-frame + optical-flow path, with license
  flags); and max-detail/precision + sequence-native EXR I/O. SKILL.md now points to it and carries the top gotchas.
- **High-detail matting recipe in `docs/ADVANCED.md`.** Multi-stage hair/fur/semi-transparent/motion-blur matting:
  coarse select (SAM3/BiRefNet) -> trimap -> alpha matte (ViTMatte / SDMatte / Matte-Anything) -> edge refine
  (LayerStyle), and video temporal matting (MatAnyone2 + a SAM2/SAM3/SeC keyframe, or RVM for clean humans). Notes
  that the official template library ships image BiRefNet bg-removal + SAM3 segmentation but NO free local temporal
  video matte (the video-matte templates are paid Bria API), and flags licenses (RMBG-2.0 CC-BY-NC, MatAnyone NTU
  research-only, RVM GPL). Each model verified against its real page.
- **Living bug log `docs/KNOWN_ISSUES.md` + weekly bug tracking.** A sourced table of ComfyUI's open bugs (with
  workarounds), security notes, and a "Recently fixed" section, so the kit knows what is broken before building a
  workflow. The `comfyui-weekly-update` task now also reads ComfyUI + frontend release notes and the issue tracker
  each week and updates this log (moves fixed items, adds new bugs, bumps the date). SKILL.md and ADVANCED.md point
  to it.
- **Node I/O cheat-sheet in SKILL.md.** The common nodes' exact input/output types (CheckpointLoader, LoraLoader,
  CLIPTextEncode, KSampler, VAEDecode/Encode, ControlNet apply, etc.) so graphs are wired with valid connections
  (no feeding text into a LoRA input or a MODEL into a text box); anything unfamiliar is still read from `/object_info`.
- **Counted the official Subgraph Blueprints (94).** README and MODEL_INDEX now note the library also ships 94
  official Subgraph Blueprints (reusable subgraph bricks) alongside the 534 templates.
- **LTX-2 LoRA training guide `docs/LTX2_TRAINING.md`.** Documents the official Lightricks trainer + their
  `train-model` skill for training a custom LTX-2 LoRA (modes, LoRA-rank guidance, the plan-gated flow, and the
  Linux + >= 32 GB VRAM requirement), credits Lightricks, and tells the kit to offer training when a user works with
  LTX-2 and wants something a LoRA captures. The trained LoRA loads back into ComfyUI here.

### Changed
- **GitHub language stats now reflect the Python tooling.** Marked the per-OS install scripts
  (`*.ps1` Windows, `*.sh` Unix) as `linguist-vendored` so the repo's language bar shows the Python
  tooling, not whichever installer set was larger by bytes. No code change: the kit is a Markdown
  skill with Python tooling.

## [1.3.1] - 2026-06-23

### Changed
- **Krea 2 recipe: added a worked example.** Folded a representative prompt from the official `krea-ai/krea-2`
  prompt guide (`docs/prompting.md`) into the recipe so the "long, detailed, natural language" structure is concrete,
  and cited that doc as a source.

### Fixed
- **Stale coverage-table descriptions.** The README coverage table labeled the Krea row "Krea 1" where the
  shipped recipe is Krea 2; corrected to "Krea 2 / FLUX.1 Krea Dev". Refreshed the stale "Updated:" date in the
  README and MODEL_INDEX to 2026-06-23.

## [1.3.0] - 2026-06-23

### Added
- **Krea 2 (open weights) recipe.** Added a Krea 2 entry: RAW (52 steps, CFG 3.5, for LoRA training) and Turbo
  (8 steps, CFG 0, up to 2K, for inference), built on a Qwen3-VL-4B text encoder + the Qwen-Image VAE. Day-0 native
  ComfyUI via the official `image_krea2_turbo_t2i` template (Comfy-Org repackaged weights + four style LoRAs).
  Recipe families 65 -> 66. Noted the Krea 2 Community License (commercial use needs an Enterprise License). Sources:
  krea-ai/krea-2, Comfy-Org/Krea-2.
- **Reference source: Comfy-Org Creative Campus.** Pointed the SKILL.md shared-workflows section at
  `Comfy-Org/creative-campus`, the official Comfy Education Initiative case-study workflows from award-winning
  artists (e.g. Xindi Zhang's Student Academy Award film) to open and study. Link-and-study only (no license file).

### Changed
- **Coverage charts refreshed to a uniform 2560x1440.** The four `docs/assets` images now share one resolution
  (matching the cover) so the README rows stay aligned. `models_by_modality` updated to 66 with the corrected
  modality and local/API split.
- **Repo renamed to `ComfyUI-Agent-Kit` (capitals).** Capitalized the README title, clone URLs, the installer banners, the changelog header, and the
  directory-tree label so they match the renamed repo; the old lowercase URL still redirects. The cover image
  chip now reads "66 model recipes" (was 65).

### Fixed
- **Utility-tool count 17 -> 18.** The Z-Image Fun-ControlNet-Tile super-res model was added to the enhancement
  section, but the totals in the README and MODEL_INDEX still read 17. Corrected to 18 across the README, MODEL_INDEX, and the coverage chart.

## [1.2.0] - 2026-06-22

### Added
- **Credits for the v1.1.0 sources.** Named Prompt Relay (Gordon Chen, Ziqi Huang, Ziwei Liu), kijai's
  ComfyUI-PromptRelay and ComfyUI-SUPIR, WhatDreamsCost LTX Director 2.0, alibaba-pai Z-Image ControlNet,
  Lightricks LTX-2.3 / HDR, and Real-ESRGAN in the README "Credits and thanks", plus a new ATTRIBUTION.md
  "Optional components" table with licenses. Flagged that SUPIR's weights are non-commercial.
- **Field techniques in wide community use (LTX-2.3 + Flux.2).** Added attribution-verified findings: LTX-2.3
  external-audio sync, GGUF loading to fit the 22B on a 24GB card, CacheDiT speed, NAG quality, chunked feed-forward +
  multi-guide (KJNodes), the GAP LTX 2.3 Motion pack (lipsync / storyboard, with the storyboard-audio caveat), and
  Flux.2 Klein masked-inpaint + multi-angle recipes. Credited KJNodes/kijai, Jasonzzt (CacheDiT), MelBandRoFormer,
  Fannovel16 (Frame-Interpolation), and GeekatplayStudio. Attribution taken from the workflows' own embedded node-pack
  ids, not guessed.

## [1.1.0] - 2026-06-22

### Added
- **Multi-shot / timeline video direction (Prompt Relay + LTX Director 2.0).** Documented the Prompt Relay method
  (arXiv 2604.10030; training-free, inference-time temporal prompt routing via a cross-attention penalty), its
  ComfyUI port `kijai/ComfyUI-PromptRelay` (Smart segment syntax, ready LTX-2.3 + Wan 2.2 graphs), and
  `WhatDreamsCost` LTX Director 2.0 (timeline-editor node for LTX 2.3, GPL-3.0) in the LTX-2.3 entry, plus a Prompt
  Relay note in the Wan 2.1/2.2 entry. Caveats noted: needs current ComfyUI-LTXVideo + KJNodes, a cross-attention
  monkeypatch, and the kijai port ships no license file.
- **Z-Image-Turbo ControlNet + upscale options.** Documented the alibaba-pai Fun-Controlnet-Union (Canny / Depth /
  Pose / HED / MLSD, + Scribble/Gray builds, `control_context_scale` 0.65-1.00, 8-step distilled) in the
  Z-Image-Turbo entry, plus two upscale paths: the hires-fix "controlnet-locked upscale" and the companion
  Fun-ControlNet-Tile super-res model (also added to the upscaler list). Verified against the official HF model card.
- **LTX-2.3 HDR IC-LoRA (SDR -> HDR video).** Documented `Lightricks/LTX-2.3-22b-IC-LoRA-HDR` in the LTX-2.3 entry:
  gated `license:other` weights, the ready `LTX-2.3_ICLoRA_HDR_Distilled.json` workflow in the ComfyUI-LTXVideo pack,
  the arXiv 2604.11788 method, the `LTXICLoRALoaderModelOnly` requirement, and the HDR-format-out caveat.

### Fixed
- **Corrected the controlnet-locked upscale claim.** Live testing showed the Union-ControlNet img2img refine holds
  STRUCTURE but Z-Image regenerates a real subject's IDENTITY at denoise 0.4+ (the earlier "denoise ~0.7 without
  drift" wording was misleading). Reworded to keep denoise ~0.2 for fidelity, or use the Tile model / a GAN / a
  face-ID adapter for an identity-locked face upscale; also flagged the full control model's high-res VRAM/OOM cost.

## [1.0.0] - 2026-06-21

The auto-start and session-protocol release: the agent can now run ComfyUI itself, and never loses your work.

### Added
- **Auto-start the ComfyUI server.** When `:8188` is down, the agent launches the headless server in the
  background and generates, no GUI required. The per-machine launch command is captured in the skill's machine
  block; the owner views a running server via `http://127.0.0.1:8188` in a browser.
- **Session protocol.** Ask the owner how to start ComfyUI (open it themselves vs agent starts headless), with a
  remembered preference; ALWAYS save every built or run workflow to `<ComfyUI>/user/default/workflows/` so it
  persists and the owner can open it later from the Workflows sidebar; hand over name, outputs, and how to view.
- **Configurable start policy for projects and pipelines.** Resolution order: env vars (`COMFY_HOST` /
  `COMFYUI_START_POLICY` / `COMFYUI_LAUNCH_CMD`) > project `.comfyui-agent.json` > skill machine block > ask.
  Ships `.comfyui-agent.example.json`.

### Fixed
- **Headless launch crash.** A custom node logs an emoji; under a non-UTF-8 console codepage (Windows cp1251) the
  server died on startup with a `UnicodeEncodeError`. Set `PYTHONUTF8=1` on the launch. Verified live.

### Changed
- README "What it can do" now lists auto-start and workflow persistence. Reconciled the "do not MCP-restart
  Desktop" gotcha with the new self-start capability (start the server yourself; the Desktop shortcut would start
  a conflicting second server on `:8188`).

## [0.3.0] - 2026-06-20

### Added
- **Workflow composition.** Assemble a new graph from templates and blueprint subgraphs, and wire the nodes
  correctly (output-to-input by type, with converters), validated against `/object_info`.
- **Shared-workflow fetch + model shootout.** `fetch_workflow.py` pulls any ComfyHub workflow by hash; the
  image-edit comparison grid runs a prompt through many models to pick the best. `docs/EXAMPLE_WORKFLOWS.md`.
- **MotionDeblur (restoration) IC-LoRA** and the **OpenRouter in-graph LLM node** (any model via one key).
- **Self-update mechanism.** `check_updates.py` diffs the template repo and reads the ComfyUI blog RSS; an
  optional weekly scheduled task adds recipes for new models. `docs/UPDATING.md`.
- Upscaler-choice and restore-chain ordering guidance (GAN vs diffusion; denoise before upscale).

### Changed
- README capabilities overview added; tagline byline on its own line; coverage tables merged and aligned.
- Stripped all em-dashes repo-wide (house writing canon: 0 long dashes).

## [0.2.0] - 2026-06-19

### Changed
- **Restructured into a multi-agent kit and renamed `comfyui-claude-kit` to `comfyui-agent-kit`** (the old URL
  redirects). One shared core (`shared/`) plus a thin adapter per agent (`agents/{claude,codex,gemini,qwen}`);
  GLM is covered through Claude Code. Per-agent matrix in `docs/AGENTS.md`.

## [0.1.0] - 2026-06-19

### Added
- Initial kit: the `comfyui` skill + stdlib `comfy_client.py`, the `comfyui-mcp` driver, the sparse-cloned 500+
  workflow-template library + quick index, the in-graph Claude nodes, and the node-building skills.
- **Per-model "mega-brain" (`MODELS.md`):** prompt recipes from official sources (grew to 65 models across
  image / video / audio / 3D) plus 17 enhancement and utility tools, auto-pulled when a model is named.
- **Full model index (`docs/MODEL_INDEX.md`):** all 147 library models classified (recipe / utility / template-only).
- **Hardware-aware model selection:** detect VRAM, RAM, and free disk, recommend the variant that fits, refuse a
  download that will not.
- House-style cover, real-data coverage charts, gracious credits, MIT, and full attribution.
