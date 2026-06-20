---
name: comfyui
description: "Drive a local ComfyUI install for image, video, and audio generation via its HTTP API. Use WHENEVER generating, rendering, or editing images/video/audio/hero assets with ComfyUI, Z-Image, Ideogram, FLUX, LTX, Wan, or when building, parameterizing, or running ComfyUI workflows. Covers the API client, workflow JSON format, model patterns, dual/multi-GPU placement, the MCP driver, in-graph Claude nodes, and VRAM coordination."
metadata:
  type: reference
---

# ComfyUI — driving the local install

Use this whenever the task involves generating or rendering images, video, or audio with ComfyUI, or
building/running a ComfyUI workflow. Read it first, then act.

## Your machine (FILL THIS IN on first run — see docs/BOOTSTRAP.md)

The facts below are placeholders. On the first ComfyUI task on a new machine, run the bootstrap once:
call the MCP `health_check` (or `comfy_client.alive()` + `GET /system_stats` + `/object_info`) and rewrite
this block with the real values. Do not assume another machine matches the example.

- **ComfyUI**: <Desktop or source install>, core path `<detect>`, API at **`http://127.0.0.1:8188`**
  (alive when the server/app is running). Check: `GET /system_stats` -> 200.
- **GPUs**: `<N>x <model>` (`cuda:0`, `cuda:1`, ...). VRAM per card `<detect>`.
- **Models installed** (query live, do not hardcode): `GET /object_info/UNETLoader`,
  `/object_info/CheckpointLoaderSimple`, `/object_info/CLIPLoader`, `/object_info/VAELoader`.
- **Shared models dir / extra_model_paths**: `<detect from startup log or extra_model_paths.yaml>`.
- **GUI workflows folder** (the bridge, see below): `<ComfyUI>/user/default/workflows/`.

> Example from the kit author's machine (yours WILL differ): ComfyUI Desktop, core `E:\ComfyUI\ComfyUI\ComfyUI`,
> 2x RTX 3090 (24GB each), models `z_image_turbo_bf16`, `ideogram4_fp8_scaled`, VAE `ae`/`flux2-vae`,
> text encoders `qwen3vl_8b_fp8_scaled`/`qwen_3_4b`. Treat as illustration only.

## The four layers (what this kit installs)

1. **Knowledge + client** — this SKILL.md and `comfy_client.py` (stdlib, no deps).
2. **MCP driver** — `comfyui-mcp` (artokun, MIT): ~90 structured tools so Claude operates ComfyUI directly
   (generate, build/edit/validate graphs, model download, queue, VRAM, diagnostics, restart). Prefer its tools
   over hand-POSTing `/prompt` when present.
3. **In-graph Claude nodes** — Claude as a step INSIDE a workflow (prompt enrichment, vision QA on the output).
4. **Node-building skills** — `comfyui-node-*` (V3 API) for when we write or modify a custom node.

`docs/LAYERS.md` explains each; `install.ps1` / `install.sh` wires them up.

## The client (no extra deps, stdlib only)

`comfy_client.py` lives next to this SKILL.md. Import and use:

```python
import sys; sys.path.insert(0, r"<this skill dir>")
import comfy_client as c
c.alive()                                  # True if the API answers (override host with COMFY_HOST env)
c.run("path/to/workflow_api.json",
      overrides={"6.text": "a cinematic dragon, dark studio light", "3.seed": 12345},
      outdir=r"...\assets")                # queues, waits, downloads -> returns saved file paths
```

API surface: `alive()`, `run(workflow_path, overrides, outdir, timeout)`, and the pieces
`queue(workflow)`, `wait(prompt_id)`, `download_outputs(rec, outdir)`, `apply_overrides(wf, overrides)`.
Override keys are `"<nodeId>.<inputName>"` (node ids and input names come straight from the workflow JSON).
The MCP driver (Layer 2) does the same and more; use it when available, fall back to this client otherwise.

## Workflow JSON (API format)

ComfyUI runs the "API format" graph: a dict `{ "<nodeId>": { "class_type": "...", "inputs": {...} }, ... }`.
To get one: in ComfyUI enable **Settings -> Enable Dev mode Options**, build the graph, then **Save (API Format)**.
Official starting graphs: **Workflow -> Templates** browser (per model). Save those as API Format, then parameterize.

**To parameterize a graph**, read it and find:
- the positive prompt: a `CLIPTextEncode` node, override `.text`.
- the seed: a `KSampler` / sampler node, override `.seed` (use a varied seed per call; do not hardcode).
- dimensions: an `EmptyLatentImage` / `EmptySD3LatentImage` node, override `.width` / `.height`.
- steps/cfg/sampler/scheduler: on the sampler node. Keep the template's values unless asked, they are model-tuned.

## Template library (the SOURCE OF TRUTH, mix and match)

The official Comfy-Org workflow templates are the source of truth for how to do any task in ComfyUI. The kit
clones them (sparse) to a local folder and builds a compact lookup index. Default location set by the installer;
record it in the machine block above. Master index: `templates/_quick_index.json` (name -> title, category,
models, tags, mediaType, vram, description), regenerate with `tools/gen_quick_index.py`. Update: `git pull` in
the clone, then rerun the generator.

**Flow:** read `_quick_index.json`, find the template whose name/models/tags match the request, read THAT one
`templates/<name>.json`, parameterize it. New templates use SUBGRAPHS: the real pipeline is inside
`definitions.subgraphs[0]`, exposed params (text, width, height, seed, steps, model names) are in
`subgraphs[0].inputs`, traced to inner nodes via the outer node's `properties.proxyWidgets`. Mix and match the
`blueprints/` (reusable subgraph bricks: `text_to_image_z_image_turbo`, `image_to_video_ltx_2_3`,
`image_upscale_z_image_turbo`, `remove_background_birefnet`, ...).

`widgets_values` are ORDER-based, no field names: KSampler = [seed, control_after_generate, steps, cfg, sampler,
scheduler, denoise]; EmptySD3LatentImage = [width, height, batch]. Model filenames must match installed files
exactly. Validate node types/inputs against `/object_info/<NodeType>` before writing a graph.

## Per-model prompting (the mega-brain) — READ before prompting a named model

Every generative model has its own dialect. SDXL wants comma tags, FLUX wants natural-language sentences, video
models want camera + motion direction, audio models want genre/tempo/instruments, and negative-prompt support
varies (FLUX and many turbo models ignore or break on negatives). The kit ships a per-model prompting reference,
**`MODELS.md`** (next to this file), distilled from OFFICIAL sources: each maker's docs / model cards,
docs.comfy.org, and the `anthropic-claude` node's per-model templates.

**Auto-pull rule:** when a specific model is named in the request, the workflow, or the chosen template, READ
that model's entry in `MODELS.md` BEFORE writing the prompt, and follow its prompt structure, its
negative-prompt rule, and its settings. Never carry one model's style to another.

`MODELS.md` covers (image) FLUX.1/.2 + Kontext, Z-Image-Turbo, Qwen-Image/Edit, SDXL, SD1.5, SD3.5, HiDream,
Ideogram, Nano Banana Pro/2, Seedream 4.x/5 Lite, Recraft, GPT-Image, Grok, Reve, Kandinsky, BRIA, OmniGen,
Chroma, Krea, ERNIE-Image; (image edit) FLUX Kontext, Qwen-Image-Edit, FireRed, LongCat, ChronoEdit; (video)
Wan 2.1-2.7, LTX-2.3 / 2 Pro, Hunyuan Video, SVD, Kling, Veo, Sora, Seedance, Luma, Runway, MiniMax, PixVerse,
Vidu, Pika, HappyHorse, HuMo, SCAIL-2; (audio) Stable Audio, ACE-Step, ElevenLabs, ChatterBox, Sonilo; (3D)
Hunyuan3D, Tripo, Rodin, Meshy; (newer/niche) Capybara, Bernini-R, Anima, NewBie, PixelDiT, Ovis-Image, Lens, Quiver.

It also has an **Enhancement and utility** section (not prompt-driven, use as pipeline steps with settings not
prompts): upscale/restore/interpolation (Real-ESRGAN, SUPIR, SeedVR2, FlashVSR, Topaz, Magnific, FILM, RIFE) and
segmentation/depth/pose/conditioning (SAM3, BiRefNet, Depth Anything, DWPose, MoGe, IP-Adapter, LivePortrait,
Mediapipe) and video object-removal (VOID). For any model not detailed there, the template library + `/object_info`
is the fallback, and the
matching official doc link is the source.

## In-graph Claude nodes (Layer 3) — pick the right one

Three Claude nodes can exist after install; they differ by billing and purpose (see `docs/NODES.md`):
- **`AnthropicClaudeNode`** (category `LLM/Anthropic`, community, your own key) — 40+ templates that rewrite a
  prompt for a specific model (`Ideogram 3`, `LTX 2.3 / LTX 2 Pro`, `Wan 2.1 & 2.2`, `FLUX`, `Nano Banana`,
  `Veo 3`, `Sora 2`, ...). Vision + extended thinking. Needs `CLAUDE_API_KEY` env. The workhorse for autonomous
  in-graph prompt enrichment.
- **`ClaudeNode`** (category `partner/text/Anthropic`, official Comfy-Org) — billed via Comfy.org credits, no
  own key. Models up to the latest Opus. Fallback path.
- **`ClaudeCustomPrompt`** (Claude Prompt Generator) — simple, api_key as a string input.

You only NEED a Claude node when a graph must enrich prompts WITHOUT Claude in the loop (e.g. an unattended
auto-hero pipeline). When you are already driving, write the prompt yourself, it is better and free.

## Build a workflow AND show it in the owner's GUI (bidirectional bridge)

The owner wants to SEE the graph Claude builds, in his own ComfyUI canvas, and tweak it. The bridge is the
GUI workflows folder, which both sides read and write: **`<ComfyUI>/user/default/workflows/`**.

Two JSON formats, keep both in mind:
- **GUI format** (what the canvas loads and "Save" produces): top-level `nodes` (each with `id`, `type`, `pos`,
  `size`, `widgets_values`, `inputs`, `outputs`), `links`, `groups`. Write THIS to the workflows folder so the
  owner can OPEN and see the graph. Auto-layout nodes in left-to-right columns (loaders -> encode -> sampler ->
  decode -> save), spacing ~ x+320 per column, so it reads cleanly.
- **API format** (what `/prompt` runs): `{ "<id>": {class_type, inputs} }`. Send THIS to run headlessly.

**Flow:**
- Claude builds -> write the GUI-format `.json` to `user/default/workflows/<name>.json` -> tell the owner to
  refresh the built-in Workflows sidebar (folder icon) and open it -> he sees exactly what Claude built.
- Owner builds/edits -> Save (API Format) into a shared `workflows/` folder -> Claude reads and runs it.
- Keep the two formats in sync: build once, emit both. Validate node names and inputs against
  `/object_info/<NodeType>` before writing, so the graph is not red/broken when he opens it.

No extra "agent panel" node is required for this; the built-in Workflows sidebar is the bridge. (The
`comfyui-mcp` ecosystem has an optional live-streaming panel; it is polish, not a requirement.)

## Where models live, and how to download one (DETECT, do not assume)

ComfyUI reads models from one or more model roots. On a **source install** it is `<ComfyUI>/models/<type>/`. On
**Comfy Desktop** the active root is usually a SHARED folder set via `extra_model_paths.yaml`, NOT
`<ComfyUI>/models`. Always detect the real root before downloading; a file in the wrong folder is invisible to ComfyUI.

**Detect the real model root first:**
- Read the ComfyUI startup log: it prints `Adding extra search path <type> <PATH>` for every model type, plus
  `Setting output/input directory to: ...`. Those PATHs are the truth (MCP `get_logs`, or the Desktop log file).
- Or read `<ComfyUI>/extra_model_paths.yaml` (and the `.example`).
- Or ask the running server: `/object_info/CheckpointLoaderSimple`, `/UNETLoader`, `/VAELoader`, `/CLIPLoader`
  list the files currently visible, which confirms the folder is wired after you drop a file in.

**Model type -> subfolder** (under the detected root):
- diffusion / UNET single-file model -> `diffusion_models` (sometimes `unet`)
- full checkpoint (model+clip+vae bundled; some video like LTX ship this way) -> `checkpoints`
- text encoder / CLIP (T5, umt5, gemma, clip_l, llava) -> `text_encoders` (older installs: `clip`)
- VAE -> `vae` · LoRA -> `loras` · upscaler (ESRGAN, etc.) -> `upscale_models`
- ControlNet -> `controlnet` · IP-Adapter -> `ipadapter` · CLIP vision -> `clip_vision`

**How to download (Desktop-safe):**
- Direct download is most reliable: `curl -fL -C - -o "<root>/<type>/<filename>" "<url>"`. Use the official
  Comfy-Org repackaged Hugging Face repos (`.../resolve/main/...` direct links). `-C -` resumes a partial file.
  Big models (tens of GB) are fine to run in the background; verify final size after.
- The MCP `download_model` works ONLY if the MCP server has `COMFYUI_PATH` set, and it writes to
  `COMFYUI_PATH/models/<type>`, which on Desktop is usually NOT the shared root, so files can land where ComfyUI
  cannot see them. Prefer direct download to the detected root (or set COMFYUI_PATH to the real root first).
- Gated models (e.g. Stability Stable Audio) need a Hugging Face login + license acceptance: ask the owner to
  accept the license and place the file, or provide an HF token for an authenticated download.
- The exact file set per model (diffusion model + text encoder(s) + VAE, and which folder each goes in) is on the
  model's `docs.comfy.org/tutorials/...` page; follow it rather than guessing quant levels or filenames.
- After download, confirm ComfyUI sees it: re-query `/object_info/<LoaderNode>`. Most model folders refresh live;
  a brand-new subfolder may need a Workflows-sidebar refresh.

## Pick a model variant that fits THIS machine (hardware-aware, recommend before downloading)

Before installing or downloading a model, size it against the real hardware, then RECOMMEND, do not download
blindly. Detect three numbers and compare them to the model's footprint.

**Detect (reuse the bootstrap machine block, or refresh):**
- **VRAM per GPU** (free + total): MCP `get_system_stats` / `health_check`, or `GET /system_stats`
  (`devices[].vram_free` / `vram_total`). With two cards, note each separately.
- **System RAM** (free + total): same `/system_stats`. RAM matters for weight offloading and spill.
- **Free disk on the MODEL drive**: check the drive that holds the detected model root (not the system drive).
  `df -h "<model root>"` in Git Bash, or the platform equivalent. Downloads run to tens of GB; never start one
  that will not fit.

**Estimate a model's footprint:**
- VRAM needed roughly equals the diffusion model's on-disk weight size, plus VAE + text encoder + activations
  (rule of thumb: weights size + ~2-6 GB headroom; video models need much more for the latent frames).
- Precision ladder, smaller fits more: bf16/fp16 (full) > fp8 (~half) > GGUF Q8 > Q6 > Q4 (smallest). `MODELS.md`
  lists the recommended variant and any VRAM note per model.
- Download size on disk roughly equals the sum of every file (model + encoder(s) + VAE). Sum them first.

**Decide and recommend:**
- Fits one card with headroom -> use it, full precision.
- Slightly over one card -> ComfyUI weight offloading (weights in RAM, streamed to VRAM) or the fp8 variant;
  recommend that, do not force bf16.
- Far over one card but fits across both -> MultiGPU DisTorch layer-split (only then; it is slower).
- Over total VRAM even split, but RAM is large -> CPU/RAM offload (slow) or a GGUF Q4/Q5; recommend the quant.
- Not enough VRAM at any precision, or not enough free disk -> DO NOT download. State the exact shortfall (e.g.
  "LTX-2.3 fp8 is ~28 GB on disk and wants ~24 GB VRAM, but the model drive has only 12 GB free") and the
  cheapest fix (smaller variant, free disk, or skip).
- Coordinate with other GPU users (Ollama): free VRAM may be held, see the VRAM section.

**Always, before a download:** compare the summed download size to the model drive's free space, and the model's
VRAM need to the card it will run on. State the verdict so the owner sees the reasoning, not just a result:
"fits, downloading" / "too big for 24 GB, using fp8" / "only 10 GB free on E:, cannot fit ~28 GB, stopping".

## Using multiple GPUs (it is NOT like a layer-split LLM server)

One generation runs on ONE card; ComfyUI does not auto-spread a single small job across cards. Wins from the
MultiGPU nodes (`SelectModelDevice`, `SelectCLIPDevice`, `SelectVAEDevice`, `MultiGPU_WorkUnits`):
- **Offload components across cards** (model -> cuda:0, CLIP + VAE -> cuda:1): frees VRAM on the main card so
  heavy models (large video/image models) fit.
- **DisTorch layer-split** (`MultiGPU_WorkUnits`): distribute model layers across cards for models too big for
  one. Use only when a model will not fit one card.
- **Parallel throughput**: two separate generations at once, one per card (great for batches). Not splitting one
  image, doubling images.

A turbo image model usually fits one 24GB card; reach for multi-GPU on big video.

## VRAM coordination (CRITICAL gotcha)

If the same GPUs serve another workload (e.g. a local LLM via Ollama), they contend. Before a heavy ComfyUI
batch, check `GET /system_stats` free VRAM; if low, the cards are held by the other workload. Options: free it
(`ollama stop <model>` / stop its server), run the batch, then let it reload; or run ComfyUI when the other
workload is idle. After any NVIDIA driver reinstall, restart the other GPU service (it can fall back to CPU).

## NEVER restart Comfy Desktop via the MCP (CRITICAL gotcha)

Do NOT call the MCP `restart_comfyui` / `start_comfyui` / `stop_comfyui` against a **Comfy Desktop** install.
The MCP relaunch assumes a CLI launch (`python main.py`) and fails with `spawn ComfyUI\main.py ENOENT`: it KILLS
the server but cannot bring it back, because Desktop is an Electron app that launches the server with its own
args (port, `extra_model_paths` to the shared models dir). A manual `python main.py` relaunch also misses that
config, and the GUI Electron app cannot be launched from a non-interactive shell. Result: ComfyUI stays down
until the OWNER reopens the app. So: to load newly installed custom nodes, ask the OWNER to relaunch Comfy
Desktop. For a CLI/source ComfyUI the MCP restart is fine.

## Procedure (do this each time)

1. `health_check` (MCP) or `comfy_client.alive()`; if down, ask the owner to start ComfyUI (Desktop = open the
   app; source = run its launcher). If this is a fresh machine, do the BOOTSTRAP first.
2. Pick or load the right template from the templates clone (match by model/tags via `_quick_index.json`). If
   none fits, build the graph and validate node types against `/object_info`.
3. Check VRAM via `/system_stats`; coordinate with any other GPU workload if low.
4. Parameterize (prompt, varied seed, dims), run, fetch outputs.
5. Verify the output visually (Read the saved image / view via MCP) before using it. Never ship an unseen
   generation.
6. If the owner should see the graph, also write the GUI-format JSON to the workflows folder (bridge).
