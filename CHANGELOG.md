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
  section, but the totals in the README and MODEL_INDEX still read 17. Corrected to 18. (The coverage chart image
  still renders 17; regenerate on the next chart refresh.)

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
