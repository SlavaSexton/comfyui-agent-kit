---
name: comfyui
description: "Drive a local ComfyUI install for image, video, and audio generation via its HTTP API. Use WHENEVER generating, rendering, or editing images/video/audio/hero assets with ComfyUI, Z-Image, Ideogram, FLUX, LTX, Wan, or when building, parameterizing, or running ComfyUI workflows. Covers the API client, workflow JSON format, model patterns, dual/multi-GPU placement, the MCP driver, in-graph Claude nodes, and VRAM coordination."
metadata:
  type: reference
---

# ComfyUI: driving the local install

Use this whenever the task involves generating or rendering images, video, or audio with ComfyUI, or
building/running a ComfyUI workflow. Read it first, then act.

## Files in this kit (pull the right one on demand)

Only this SKILL.md auto-loads; everything else is read when relevant, so route to it instead of leaving it unread:

- **`MODELS.md`** (next to this file) - a named model's prompt recipe + settings; read its entry BEFORE writing the prompt.
- **`docs/TASKS.md`** - a named common job (generate image / video / audio / 3D, upscale, remove background): the local end-to-end flow for that task, a shortcut layer over this manual.
- **`docs/MODEL_INDEX.md`** - the full classified list of all 147 models (recipe / utility / template-only); check whether a named model has a recipe, is a utility, or is template-only.
- **`docs/ADVANCED.md`** - hard tasks: real strengths, gotchas + workarounds, temporal stability, high-detail matting, crop-and-stitch inpaint, PBR, and the verified tool table with licenses.
- **`docs/KNOWN_ISSUES.md`** - read BEFORE building, so you do not wire around a currently-broken path.
- **`docs/KIJAI.md`** - the kijai ecosystem (his ComfyUI wrappers and nodes: Wan / Hunyuan / CogVideoX / Florence2 / KJNodes / SUPIR / FramePack / SAM2 / FluxTrainer / IC-Light / DepthAnythingV2 and ~50 more) - what each does + node I/O, what is active vs legacy by date, and the supersede map (old -> better). Read it for ANY kijai tool, and to pick the current option over a sunset wrapper.
- **`docs/LTX2_TRAINING.md`** - when the user works with LTX-2 and wants behavior a LoRA captures, offer to train one (official Lightricks trainer).
- **`docs/EXAMPLE_WORKFLOWS.md`** - worked end-to-end examples + the multi-model image-edit shootout.
- **`docs/NODES.md`** the in-graph Claude nodes (billing / purpose); **`docs/LAYERS.md`** the four install layers; **`docs/BOOTSTRAP.md`** first-run machine setup; **`docs/AGENTS.md`** per-agent matrix (Claude / Codex / Gemini / Qwen); **`docs/UPDATING.md`** the weekly model + bug update loop.

## Your machine (FILL THIS IN on first run: see docs/BOOTSTRAP.md)

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
- **Launch command** (to auto-start the server headlessly when :8188 is down): `<detect, e.g. python main.py in
  the ComfyUI dir; for Desktop the venv python + main.py + --base-directory/--extra-model-paths-config>`.

> Example from the kit author's machine (yours WILL differ): ComfyUI Desktop, core `E:\ComfyUI\ComfyUI\ComfyUI`,
> 2x RTX 3090 (24GB each), models `z_image_turbo_bf16`, `ideogram4_fp8_scaled`, VAE `ae`/`flux2-vae`,
> text encoders `qwen3vl_8b_fp8_scaled`/`qwen_3_4b`. Treat as illustration only.

## The four layers (what this kit installs)

1. **Knowledge + client**: this SKILL.md and `comfy_client.py` (stdlib, no deps).
2. **MCP driver**: `comfyui-mcp` (artokun, MIT): ~90 structured tools so Claude operates ComfyUI directly
   (generate, build/edit/validate graphs, model download, queue, VRAM, diagnostics, restart). Prefer its tools
   over hand-POSTing `/prompt` when present.
3. **In-graph Claude nodes**: Claude as a step INSIDE a workflow (prompt enrichment, vision QA on the output).
4. **Node-building skills**: `comfyui-node-*` (V3 API) for when we write or modify a custom node.

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

## Compose a NEW workflow from pieces (assemble + wire it correctly)

When no single template fits, BUILD one by chaining pieces. The skill is for assembling, not only running.

**1. Decompose the task into stages**, one brick per stage, e.g. text-to-image -> upscale -> image-to-video ->
add audio. Pick a template or a `blueprints/` subgraph for each stage (match via `_quick_index.json` / blueprint
names), and read each one to see its real input and output nodes.

**2. Know how nodes connect (the key mechanic).**
- **API format:** every input is EITHER a literal value OR a reference to another node's output, written as a
  2-item list `["<sourceNodeId>", <outputSlotIndex>]`. To run stage B after stage A, set B's input to
  `["<A_id>", <slot>]`, where `<slot>` is the index of A's matching output. Example: feed a decode's IMAGE into an
  upscaler -> `"image": ["8", 0]` (node 8, output 0).
- **GUI format:** connections live in the top-level `links` array; each link is
  `[link_id, src_node, src_slot, dst_node, dst_slot, type]`, and each node's `inputs[].link` / `outputs[].links`
  carry those link ids. Write THIS to show the graph in the canvas (the bridge); write the API form to run.

**3. Match types, or convert.** Every output and input has a TYPE: `IMAGE`, `LATENT`, `MODEL`, `CLIP`, `VAE`,
`CONDITIONING`, `AUDIO`, `MASK`, `CONTROL_NET`, ... You may ONLY connect matching types. Read each node's input +
output types from `/object_info/<NodeType>` (`input.required` / `output` / `output_name`). If a seam's types
differ, insert a converter: `VAEEncode` (IMAGE -> LATENT), `VAEDecode` (LATENT -> IMAGE), `CLIPTextEncode`
(text -> CONDITIONING), `ImageScale` / an upscaler for size. Never wire an IMAGE into a LATENT input.

**Common node I/O (memorize these; for anything else read `/object_info/<NodeType>`).** A node's WIDGETS are values you set; its INPUT SLOTS must receive the matching TYPE from another node's OUTPUT. You cannot feed text into a LoRA input, or a MODEL into a text box.
- `CheckpointLoaderSimple` -> out: MODEL, CLIP, VAE. (Flux/newer split loaders: `UNETLoader` -> MODEL ; `DualCLIPLoader`/`CLIPLoader` -> CLIP ; `VAELoader` -> VAE.)
- `LoraLoader`: in MODEL + CLIP (+ name/strength widgets) -> out MODEL, CLIP. A LoRA is applied ONTO the MODEL+CLIP stream, never wired as text.
- `CLIPTextEncode`: in CLIP + text widget -> out CONDITIONING. Your prompt becomes CONDITIONING here; downstream nodes want CONDITIONING, not raw text.
- `EmptyLatentImage` / `EmptySD3LatentImage`: widgets only -> out LATENT.
- `KSampler` / `KSamplerAdvanced`: in MODEL + positive CONDITIONING + negative CONDITIONING + LATENT (+ seed/steps/cfg/sampler/scheduler/denoise widgets) -> out LATENT.
- `VAEDecode`: in LATENT + VAE -> out IMAGE. `VAEEncode`: in IMAGE + VAE -> out LATENT.
- `ControlNetLoader` -> CONTROL_NET ; `ControlNetApplyAdvanced`: in CONDITIONING + CONTROL_NET + IMAGE -> out CONDITIONING.
- `LoadImage` -> IMAGE, MASK ; `SaveImage` / `PreviewImage`: in IMAGE.
Basic txt2img stream: loader -> (LoraLoader) -> CLIPTextEncode x2 (pos/neg) -> KSampler (+ EmptyLatentImage) -> VAEDecode -> SaveImage. Before building, also check `KNOWN_ISSUES.md` (next to this file or `docs/KNOWN_ISSUES.md`) and ADVANCED.md for current bugs and workarounds, so you do not wire around a known-broken path.

**4. Merge graphs cleanly.** Splicing two templates: renumber one graph's node ids so they do not collide; SHARE
the loaders (one `CheckpointLoader` / `UNETLoader` / `VAELoader` / `CLIPLoader` feeding both stages, do not
duplicate the same model); then wire the seam (stage A's final output -> stage B's first input). Keep each model's
own VAE / encoder with it (a Wan VAE is not an SDXL VAE; LTX bundles its VAE in the checkpoint).

**5. Validate before running.** Check: every `class_type` exists in `/object_info`; every input is a literal or a
`[node, slot]` ref to an existing node; every seam's types match; model filenames exist locally; and the graph has
at least one INPUT node carrying the user's intent AND at least one OUTPUT/save node wired to the final tensor
(`SaveImage` / `SaveAudio` / `SaveVideo` / `VHS_VideoCombine`, or a `PreviewImage`). **API / partner nodes (Kling,
Nano Banana, Veo, Gemini, ...) often emit a tensor but include NO save node by default - add and wire one, or the
job runs "successfully" and produces nothing retrievable, wasting the compute.** Then run SMALL /
low-res FIRST to confirm the wiring, before the full render. Emit both formats: GUI to show in the canvas, API to
run. When unsure of a node's exact inputs/outputs, query `/object_info/<NodeType>` rather than guessing.

## Shared workflows + model shootout (pick the best model for a look)

Beyond the named template library, ComfyHub hosts thousands of community-shared workflows at
`comfy.org/workflows/<hash>`. Any ComfyHub share downloads as plain JSON from a predictable URL:
`https://comfy.org/workflows/download/<hash>.json`. So you can grab any shared workflow on demand, then read or run
it. Helper: `python shared/tools/fetch_workflow.py <hash> <outdir>` (stdlib). The `<hash>` is the id in the share
URL. Note: `cloud.comfy.org/?share=<hash>` links are Comfy Cloud only and are NOT downloadable this way (open in
Comfy Cloud and export from the canvas).

**Model shootout (which model is best for THIS prompt):** the template library already ships a comparison grid,
`templates-all_in_one-image_edit_models` ("1 input and multiple editing model comparison"): it fans one input image
through 7 image-edit models at once (Flux.2 Dev/Klein, GPT-Image-1.5, Grok, Nano Banana Pro, Qwen-Image-Edit,
Seedream) and saves each output side by side, so you pick the best look before committing. For video, the community
"Adjustment Frame" share (hash `7dca0438edf4`) compares video backends (Grok/Kling/Veo/Seedance/Wan2.2/LTX-2). Run
small / low-res first, compare, then scale up the winner. This pairs with the per-model recipes below and the
hardware-aware fit check.

**Real production graphs to study:** `Comfy-Org/creative-campus` (github.com/Comfy-Org/creative-campus) collects the
actual workflows from Comfy Education Initiative case studies, real graphs from award-winning artists (e.g. Xindi
Zhang's *Song of Drifters*, a Student Academy Award film: SD1.5 style transfer with IP-Adapter + ControlNet, plus a
3D + AI morphing graph). Open and study them for production technique. Link-and-study only (no license file; shared
with the artists' permission), so reference it, do not bundle the JSONs.

## Staying current (new models and workflows)

ComfyUI ships new models constantly, and they land in the template library first. To see what is new: `git pull`
the templates clone and regenerate the quick index (`gen_quick_index.py`), then DIFF the model list (names not seen
before = new models / new templates). Also read the announcements RSS at `https://blog.comfy.org/feed`. The kit
ships `shared/tools/check_updates.py`, which does all of this in one command (pull + diff + RSS). When a genuinely
new generative model appears without a recipe, research its OFFICIAL prompting (maker docs / model card /
docs.comfy.org) and add it to `MODELS.md` in the same format; a new utility/upscaler goes to the Enhancement
section. Do NOT scrape LinkedIn (auth-gated, anti-scraping, ToS); the blog RSS and the templates repo carry the
same news, machine-readable. Full loop: the kit's `docs/UPDATING.md`.

## Per-model prompting (the mega-brain): READ before prompting a named model

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

## In-graph Claude nodes (Layer 3): pick the right one

Three Claude nodes can exist after install; they differ by billing and purpose (see `docs/NODES.md`):
- **`AnthropicClaudeNode`** (category `LLM/Anthropic`, community, your own key), 40+ templates that rewrite a
  prompt for a specific model (`Ideogram 3`, `LTX 2.3 / LTX 2 Pro`, `Wan 2.1 & 2.2`, `FLUX`, `Nano Banana`,
  `Veo 3`, `Sora 2`, ...). Vision + extended thinking. Needs `CLAUDE_API_KEY` env. The workhorse for autonomous
  in-graph prompt enrichment.
- **`ClaudeNode`** (category `partner/text/Anthropic`, official Comfy-Org), billed via Comfy.org credits, no
  own key. Models up to the latest Opus. Fallback path.
- **`ClaudeCustomPrompt`** (Claude Prompt Generator), simple, api_key as a string input.

You only NEED a Claude node when a graph must enrich prompts WITHOUT Claude in the loop (e.g. an unattended
auto-hero pipeline). When you are already driving, write the prompt yourself, it is better and free.

## Build a workflow AND show it in the owner's GUI (bidirectional bridge)

The owner wants to SEE the graph Claude builds, in his own ComfyUI canvas, and tweak it. The bridge is the
GUI workflows folder, which both sides read and write: **`<ComfyUI>/user/default/workflows/`**.

Two JSON formats, keep both in mind:
- **GUI format** (what the canvas loads and "Save" produces): top-level `nodes` (each with `id`, `type`, `pos`,
  `size`, `widgets_values`, `inputs`, `outputs`), `links`, `groups`. Write THIS to the workflows folder so the
  owner can OPEN and see the graph. Auto-layout nodes in left-to-right columns (loaders -> encode -> sampler ->
  decode -> save) with a Group box per stage and a per-column y-cursor so nodes never overlap. See "Lay the graph
  out cleanly" below for the exact discipline.
- **API format** (what `/prompt` runs): `{ "<id>": {class_type, inputs} }`. Send THIS to run headlessly.

**Flow:**
- Claude builds -> write the GUI-format `.json` to `user/default/workflows/<name>.json` -> tell the owner to
  refresh the built-in Workflows sidebar (folder icon) and open it -> he sees exactly what Claude built.
- Owner builds/edits -> Save (API Format) into a shared `workflows/` folder -> Claude reads and runs it.

## Lay the graph out cleanly (structured blocks, no overlap)

A graph that piles nodes at 0,0 or lets them overlap is unusable in the canvas. Lay it out like a real pipeline. Every node carries `pos:[x,y]` + `size:[w,h]`; each block is a `groups` entry `{title, bounding:[x,y,w,h], color}`. COMPUTE positions, never eyeball them.

- **Columns = stages, strictly left to right.** One pipeline stage per column (loaders -> conditioning -> sample -> decode -> save -> post). Column x = `x0 + col * COL_W`, `COL_W = widest node width + 80` (~360 typical). Data never flows backward (no right-to-left wire).
- **Per-column y-cursor = zero overlap.** Stack a column top-down: `y = y0`; place a node; then `y += node_h + 60`. The next slot always clears the previous node's full height, so nodes in a column cannot overlap, and `COL_W >= widest + 80` clears them horizontally. Read real `size` from the template (assume ~[320,200], taller for KSampler / CLIPTextEncode). Never give two nodes the same pos.
- **One Group box per stage (this is what makes it read as blocks).** After placing a stage's nodes, add a group whose `bounding` wraps them with padding: `[minX-30, minY-50, (maxX+w)-minX+60, (maxY+h)-minY+80]` (extra top room for the title bar). Title by stage ("Load models", "Conditioning", "Sample", "Decode + Save", "Upscale", "Image to Video"); color-code (loaders grey, conditioning blue, sampler green, decode/save purple, post orange). Shared loaders sit in one group top-left, feeding every stage.
- **Reroute long or crossing wires.** When a shared output must reach a far column, insert `Reroute` nodes and run the wire along a horizontal gutter between groups instead of a diagonal across the graph. Kills the spaghetti look.
- **Tidy pass before saving.** Same node width per column, left edges aligned, seeds + savers last, no node outside its group box, no two group boxes overlapping. With the MCP, `visualize_workflow_hierarchical` renders the layout so you SEE overlaps before handing it to the owner.

## Collapse a stage into one reusable node (Subgraphs)

ComfyUI **Subgraphs** (official since 2025-08; they supersede the old **Group Nodes**, kept only for back-compat) let you select a pile of nodes and fold them into a single super-node that exposes ONLY the few params you care about. This is the cleanest way to build and reuse pipeline bricks: a tested 20-node upscale or video stage becomes one node with 3 knobs, nestable into a bigger pipeline.

In the GUI (tell the owner, or do it yourself when driving):
- **Collapse:** select the nodes (plus groups and reroutes), click the subgraph icon in the toolbar. ComfyUI auto-wires the boundary from the selection's external inputs/outputs.
- **Edit inside:** double-click the subgraph's empty area to enter; `Esc` or the top nav bar to exit (the nav bar shows the nesting level).
- **Expose only what matters:** the **Edit Subgraph Widgets** button (parameters panel) reorders and shows/hides widgets without entering; in edit mode, right-click a boundary slot to rename/delete/disconnect, and the labeled default slot adds a new input/output. Surface seed/steps/cfg/prompt, hide the rest.
- **Make it a reusable brick:** **Add Subgraph to Library** (the publish/book icon, ComfyUI v1.27.7+) turns it into a **Subgraph Blueprint**, searchable and draggable like any node. This is exactly what this kit's `blueprints/` bricks are.
- **Nest** subgraphs inside subgraphs for hierarchical pipelines; **Unpack subgraph** (right-click or the selection toolbox) reverts it to raw nodes.

When BUILDING the JSON yourself (not clicking): the inner graph lives in `definitions.subgraphs[]`; the outer SubgraphNode exposes params through `properties.proxyWidgets` and boundary I/O through the subgraph's input/output nodes (see the template-reading note above). Ship one clean brick per stage instead of 20 loose nodes. Sources: docs.comfy.org/interface/features/subgraph ; blog.comfy.org/p/subgraph-official-release.

## Creator-level depth: strengths, real limits, and advanced sequence work

The full creator-level reference (strengths, the real gotchas with workarounds, advanced sequence techniques, and a verified tool table with licenses) is `ADVANCED.md` (next to this file in the installed skill, or `docs/ADVANCED.md` in the repo). Read it for hard tasks. The load-bearing gotchas to remember even without opening it:
- **Black/NaN images or a color/contrast shift after decode = the VAE.** Use `--fp32-vae` (or `--bf16-vae`), decode once at the end, and a histogram/LAB match to restore the source plate. Never fp16 VAE for VFX.
- **A custom node that never re-runs** is the `IS_CHANGED` footgun: force a rerun with `return float("NaN")`. A seed change that does nothing = stale cache; bust an input.
- **Per-generation model reload thrash or a 4090/5090 slowdown (early 2026+)** is Dynamic VRAM: `--disable-dynamic-vram` if it hurts.
- **Single-digit canvas fps** on a huge graph is litegraph, not the backend: collapse into subgraphs, mute groups.
- **Custom nodes carry real malware risk and break on core/numpy bumps:** install only from verified authors, pin versions.

Advanced tasks the skill can now reason about (verified tools and recipes are in ADVANCED.md):
- **Temporal stability / anti-flicker for sequences:** native video model (Wan 2.2 + VACE / HunyuanVideo 1.5 / LTX-2) > context windows + FreeNoise > per-frame depth/pose ControlNet to lock structure > light RIFE + light deflicker. SD-era: unsampling (Flip Sigma, Euler, add-noise OFF) + flow attention. Fine texture/identity and window seams still flicker.
- **PBR / material passes from footage:** be honest, native temporally-stable PBR from a 2D sequence is NOT solved in 2026. Per-frame decompose (Apache-2.0 Marigold-IID + StableNormal + StableDelight) + optical-flow temporal smoothing is the realistic path; rgb2x / CHORD are higher-fidelity but noncommercial; UniRelight is the only true temporal method (albedo-only, noncommercial, no node); TRELLIS.2 (MIT) gives real PBR but on a 3D mesh, not per-frame.
- **Max detail + precision:** tiled refine (Ultimate SD Upscale / Tiled Diffusion) + ControlNet Tile for seams, Detail Daemon / PAG / FreeU for micro-detail, `dpmpp_2m` + Karras ~20-35 steps, 32-bit EXR sequence I/O (HQ-Image-Save, CoCoTools) + sRGB/Linear conversion for VFX. Per-frame detail vs cross-frame stability is a real tradeoff (SeedVR2 batch >= 5, or lock structure + vary only fine detail).
- **High-detail matting (hair / fur / semi-transparent / motion blur):** multi-stage - coarse select (SAM3 / BiRefNet) -> trimap -> alpha matte (ViTMatte / SDMatte / Matte-Anything) -> edge refine (LayerStyle MaskEdgeUltraDetailV2). Video = temporal model MatAnyone2 (needs a SAM2/SAM3/SeC keyframe mask; NTU research license) or RVM for clean humans. The official library ships `remove_background_birefnet` (image) + SAM3 segmentation, but NO free local temporal video matte (the video-matte templates are paid Bria API). Full recipe in ADVANCED.md.
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
config (fixable: pass `--base-directory` / `--extra-model-paths-config`, see "Start ComfyUI yourself" below), and
the Electron GUI WINDOW cannot be launched from a non-interactive shell (but you do not need the GUI, only the
server). So: do not use the MCP restart on Desktop; start the server yourself, and to load newly installed custom
nodes ask the OWNER to reopen the app. For a CLI/source ComfyUI the MCP restart is fine.

## Start ComfyUI yourself when it is down (auto-start the server)

For GENERATION you need the ComfyUI SERVER (the API on :8188), NOT the GUI window. When it is down, start the
server yourself in the BACKGROUND instead of only asking the owner to open the app. You need the recorded launch
command (captured in the BOOTSTRAP machine block), then start it and wait for :8188 to answer.

- **Source / CLI install:** from the ComfyUI dir, run `python main.py` as a background process. It binds :8188 (a
  console server, not a GUI, so a background shell launches it fine). Add `--listen` / `--port` only if asked.
- **Comfy Desktop (Electron):** start the bundled SERVER headlessly, not the Electron window. Run the Desktop's
  venv python on `main.py` from the core ComfyUI dir, and make it see the shared models: a raw `python main.py`
  may load the wrong (empty) model dir, so pass `--base-directory <Desktop base>` or `--extra-model-paths-config
  <the Desktop's extra_model_paths.yaml>` so the shared models resolve. Capture the exact WORKING command once per
  machine in the BOOTSTRAP machine block (test it: launch, then confirm `/object_info/UNETLoader` lists the real
  models). The GUI is only needed if the owner wants to SEE or tweak the canvas.
- **Windows: set `PYTHONUTF8=1`** (or `PYTHONIOENCODING=utf-8`) on the launch. Custom nodes log emojis (e.g.
  rgthree's "Loaded 48 nodes" with a party emoji); under a non-UTF-8 console codepage (cp1251 and friends) the
  logger throws a `UnicodeEncodeError` that CRASHES startup mid-way (after it already read the model paths). The
  Desktop app sets UTF-8 itself; a raw headless launch must too. Verified: without it the server dies on startup,
  with it it comes up clean.
- **Do NOT** use the MCP `restart_comfyui` / `start_comfyui` on a Desktop install (see the gotcha above); use your
  own recorded command.
- **If the app's processes already exist but :8188 is down**, it may be mid-startup (first-launch model load) or
  stuck. Poll a bit; if it stays dead, ask the owner to reopen the app rather than starting a SECOND server (two
  servers cannot share :8188).

- **Showing the owner the running server:** the headless server already serves the full ComfyUI web UI at
  `http://127.0.0.1:8188`. To let the owner SEE the canvas or what you built, tell them to open that URL in a
  BROWSER (same UI as the Desktop window), NOT to click the Comfy Desktop shortcut: the shortcut launches a SECOND
  server on :8188 and conflicts. Closing the browser tab leaves your server running. If they want the full Desktop
  app instead, STOP your server first, then they open the app and you reconnect to the app's server.

After launching, poll `GET /system_stats` until it answers (first start can take 10-30s for model load), then
proceed, and tell the owner you started the server.

## Session protocol (ask how to start, and SAVE so the owner can find it later)

Two access modes plus one persistence rule. Be explicit with the owner so nothing gets lost.

**Starting (ask first when ComfyUI is down).** If :8188 is already up, just use it (the owner has ComfyUI open, or
a server runs) and do NOT start another. If it is down, ASK once: "open ComfyUI yourself and I connect, or should I
start the server headless (you peek at `http://127.0.0.1:8188` in a browser)?" Follow their choice; if they say
"just auto-start it", remember that preference and skip the question next time.

**Configuring the start policy (projects + pipelines).** Asking only works interactively. For an unattended
pipeline the choice must be set ahead of time so the agent never blocks. Resolve it in this order, first found
wins:
1. **Env vars** (highest, for CI / per-run): `COMFY_HOST` (where the server is); `COMFYUI_START_POLICY` =
   `connect` (use a running server, fail clearly if down) | `autostart` (start the headless server if down) |
   `ask` (interactive); `COMFYUI_LAUNCH_CMD` (the headless launch command used by `autostart`).
2. **Project config:** a `.comfyui-agent.json` at the project root, e.g.
   `{ "host": "127.0.0.1:8188", "startPolicy": "autostart", "launchCmd": "..." }`. Committed with the project so
   the pipeline is reproducible per project.
3. **Machine default:** the launch command + host in this skill's machine block.
4. **Fallback:** interactive -> ASK; non-interactive with nothing configured -> use `connect` and fail with a
   clear message (do NOT silently launch a server in CI without being told to).

So an interactive owner gets asked; a pipeline sets `COMFYUI_START_POLICY=autostart` + `COMFYUI_LAUNCH_CMD` (or a
`.comfyui-agent.json`) once and runs hands-off. `comfy_client` already reads `COMFY_HOST`. The persistence rule
below applies identically in both cases.

**Persistence (ALWAYS, the important one).** Whenever you build or run a workflow for the owner, SAVE it as a
GUI-format `.json` in `<ComfyUI>/user/default/workflows/` with a clear, dated name (e.g.
`2026-06-21_zimage_hero.json`). That file is permanent in the user dir, so the owner can open it from the Workflows
sidebar LATER, even after your headless server stops or in a future Desktop session. An API generation alone leaves
NO artifact on the canvas, so without this save your work is invisible there. (See the bidirectional-bridge section
for the GUI-format mechanics.)

**Handover.** When you finish, tell the owner three things: the saved workflow name (under Workflows), where the
output files are, and how to view now (browser :8188, or open the saved workflow any time). If they want the full
Desktop app, STOP your headless server first so the app can take :8188.

## Procedure (do this each time)

1. `health_check` (MCP) or `comfy_client.alive()`. If up, use it. If down, follow the Session protocol: ask the
   owner how to start it, or auto-start the headless server with the recorded launch command if that is their
   standing preference; wait for :8188, then proceed. Fresh machine -> do the BOOTSTRAP first.
2. Pick or load the right template from the templates clone (match by model/tags via `_quick_index.json`). If
   none fits, build the graph and validate node types against `/object_info`.
3. Check VRAM via `/system_stats`; coordinate with any other GPU workload if low.
4. Parameterize (prompt, varied seed, dims), run, fetch outputs.
5. Verify the output visually (Read the saved image / view via MCP) before using it. Never ship an unseen
   generation.
6. ALWAYS save the workflow you built or ran to `<ComfyUI>/user/default/workflows/` as a GUI-format `.json` with a
   clear dated name (Session protocol), so the owner can find and open it later. Then hand over: name, outputs,
   how to view.
