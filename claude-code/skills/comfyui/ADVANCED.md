# ComfyUI at creator level: strengths, real limits, and advanced techniques

Distilled from primary sources (official docs and blog, the ComfyUI GitHub and its issues, model cards) on
2026-06-24. Every tool named below was checked against its real page; licenses are flagged because several are
non-commercial. This is the "know the engine, including where it bites" reference. Pair it with
[`MODELS.md`](../skills/comfyui/MODELS.md) (per-model prompting) and [`SKILL.md`](../skills/comfyui/SKILL.md)
(driving and building). Where a claim is community consensus rather than a measured fact, it says so.

## What ComfyUI is genuinely best at

- **The graph IS the pipeline.** Every step (load, encode, sample, decode, save) is an exposed, rewireable node, so multi-model / multi-ControlNet / iterative-refine pipelines that are awkward in A1111/Forge/Invoke are first-class here. This is why it became the de-facto studio/automation backend.
- **Headless API + batch.** The server is headless by default; the web UI is just one client. `POST /prompt` (validate + queue), `GET /history`, `GET /view`, `GET /object_info` (every node's schema), `/ws` (live progress). Any HTTP client can drive it and scale it horizontally.
- **One graph across modalities.** image -> upscale -> video -> audio -> 3D in a single graph, mixing a different model per stage.
- **Reproducibility.** The full workflow with seeds is embedded in output PNG/WebP/FLAC and drag-droppable back into the canvas; only changed branches re-execute (caching). Caveat: re-encoding to WebP/JPG or resizing strips the metadata, so share the `.json`, not a screenshot.
- **Day-0 model support + the Registry.** A new architecture usually only needs a new loader node, so support often ships the day a model drops. The Comfy Registry adds semantic versioning ("reinstall the exact node version") and security scanning.
- **Subgraphs / blueprints** (collapse a stage into one reusable super-node), **deep control** (stacked ControlNet + IPAdapter + per-region masks + direct latent surgery), **Dynamic VRAM** (run models larger than VRAM, default since ~March 2026), and **partner/API nodes** (closed SOTA models as native nodes in the same graph).

Sources: github.com/comfyanonymous/ComfyUI ; docs.comfy.org/development/comfyui-server/comms_routes ; blog.comfy.org/p/subgraph-official-release ; blog.comfy.org/p/dynamic-vram-in-comfyui-saving-local ; blog.comfy.org/p/comfyui-native-api-nodes ; blog.comfy.org/p/launching-comfyui-registry.

## Real limits and gotchas (and the workaround)

Live status of these (newly fixed / newly appeared) is tracked weekly in [`KNOWN_ISSUES.md`](KNOWN_ISSUES.md).

- **Big graphs lag the canvas, not the backend.** litegraph renders the whole canvas on Canvas2D; 80+ node packs can drop to single-digit fps while the backend is fine. Workaround: collapse stages into subgraphs, mute/collapse groups, lower link-render quality in settings. (gh issues 7322, 4017)
- **Dynamic VRAM fixed OOMs but added regressions.** On some setups it reloads the whole model every generation (full unload then reload), is slower per-image on 4090/5090, or forces multi-GPU onto one card. Workaround: `--disable-dynamic-vram`. (Comfy-Org/ComfyUI discussion 12699 ; desktop issue 1741)
- **`--lowvram` / `--novram` still OOM at slightly higher res** because offload granularity does not cover peak activations. Workaround: tiled VAE decode, lower res, `--cache-none`.
- **VAE round-trip shifts color and contrast and compounds across passes;** fp16 VAE can overflow to NaN -> black images (SD1.5's fp32-trained VAE is the classic offender, but it still happens on newer fp8 models). Workaround: `--fp32-vae` (or `--bf16-vae`); encode once, stay in latent, decode once at the end; a histogram/LAB color-match node to restore the source plate. (gh issues 500, 13116, 2229)
- **The `IS_CHANGED` footgun.** A custom node that returns `True` to signal "I changed" reads as unchanged (`True == True`) and never re-runs; force a rerun with `return float("NaN")` (NaN != NaN). Caching can also serve a stale image after a seed change (queue runs in ~0.05s, nothing visibly happens). Workaround: bust an input, or `--cache-classic`. (docs/custom-nodes/backend/server_overview ; issue 11905)
- **Custom-node version hell and real malware.** A core or numpy 1.x->2.x bump can break half your packs; ComfyUI does not guarantee backward compat for internal symbols custom nodes import. Verified malware has shipped through the node channel (ComfyUI_LLMVISION, ultralytics, and Akira Stealer packages). Workaround: install only from verified authors, pin versions, prefer per-pack isolation. (blog/comfyui-2025-jan-security-update ; issues 11791, 9156, 11660 ; docs/development/core-concepts/dependencies)
- **No native layers / timeline / compositing, and no real color management** (sRGB/linear handled naively, ICC effectively ignored; production color needs OCIO/ACES nodes). Output is **not deterministic** even on one machine; `--deterministic` narrows it (slower). These are design choices, not bugs.
- **Myth check:** ComfyUI is NOT slower than A1111 (roughly equal-to-faster, ~15-25% less VRAM in community benchmarks). The real cost is the steep curve and build/iteration friction, not throughput.

## Temporal stability / anti-flicker for sequences

The 2026 stack moved from SD-era flow hacks to native video models. Honest hierarchy, best first:

1. **Use a native video model** (it enforces frame coherence inside the model, not as a post-pass): **Wan 2.2** (+ **VACE** for control / vid2vid / inpaint), **HunyuanVideo 1.5**, **LTX-2**. Far more stable than per-frame image diffusion. Wan 2.2 leads on photoreal humans, HunyuanVideo 1.5 on natural motion/physics, LTX-2 trades some coherence for speed (rankings are practitioner consensus, not a controlled flicker benchmark).
2. **Length** via **WanVideoWrapper** context windows (`uniform_looped` / `uniform_standard` / `static_standard`, with blend masks) + **FreeNoise** (reuse/permute window noise so frames correlate). SD1.5/SDXL equivalent: **AnimateDiff-Evolved** sliding Context Options + FreeNoise.
3. **Lock structure** with per-frame **depth/pose ControlNet** (`comfyui_controlnet_aux`: DepthAnythingV2, DWPose). This suppresses geometry flicker; it does NOT lock texture or identity.
4. **SD-era vid2vid** (when not using a video model): **unsampling** (Flip Sigma node + a converging sampler like Euler, NOT Euler-a; turn add-noise OFF on the resample or you reintroduce flicker; weak ControlNet) + flow attention (**Veevee**, **FLATTEN**, both stale and SD-only now).
5. **Finishers, not fixers:** RIFE / FILM interpolation smooths judder but can hide flicker and ghost on fast motion; **SuperBeasts** Deflicker / PixelDeflicker fixes luminance shimmer only (it is temporal blur and will smear fine detail). Use lightly.
6. **Cheap levers:** fixed seed, "prompt lock" (tiny prompt deltas only), reuse stage-1's seed in a multi-stage upscale, and **SeedVR2** video upscaler (temporally coherent, needs batch >= 5 to engage).

**What still flickers (say so):** fine texture and identity (hair, fabric weave, foliage) that depth/pose do not constrain, context-window seams despite blend masks, and high-denoise restyling. The realistic recipe: native video model + VACE depth/pose + context windows + FreeNoise, then optional light RIFE + a light Deflicker pass.

## PBR / material passes from a sequence (the honest state)

**Native, high-quality, temporally-stable PBR from arbitrary 2D footage is NOT solved in ComfyUI in 2026.** Tell users this plainly, then give the closest real path. The reason: every quality single-image material model is one independent diffusion sample per frame, so running it on a clip flickers (swimming normals, shifting albedo, jittery roughness).

- **Single-image decomposition (run per-frame, then fight flicker externally):**
  - **Marigold + IID** (`kijai/ComfyUI-Marigold`, GPL-3.0 node wrapper; the Marigold model weights are Apache-2.0) - the practical route: depth, normals, and Intrinsic Image Decomposition into albedo + roughness + metallic (Appearance) or albedo + shading (Lighting).
  - **StableNormal + StableDelight** (`Stable-X`, via `kijai/ComfyUI-StableXWrapper`, no LICENSE file; the Stable-X models are Apache-2.0) - sharp/stable normals and specular removal (de-light toward true albedo).
  - **StableMaterials** (`gvecchio/StableMaterials`, openrail, commercial-OK) - basecolor/normal/height/roughness/metallic, tileable, but it SYNTHESIZES a material rather than faithfully decomposing your exact frame. Load the pipeline with `trust_remote_code=True` (custom pipeline, won't run without it); recommended `guidance_scale=10.0`, `num_inference_steps=50` (or the LCM fast variant: load subfolder `unet_lcm` + swap in `LCMScheduler`, 4 steps); `inference: false` in the card means no hosted API, run it locally.
  - **DeepBump** (`HugoTini/DeepBump` via `comfy_mtb`, GPL-3.0) - normal + height only, filter-grade.
  - **QFX-PBRGenerator** / **TextureAlchemy** - full-channel packs, but their "intelligence" is mostly Marigold/Lotus underneath plus procedural tooling (tiling, channel-pack, AO/curvature).
  - **Higher fidelity but NON-COMMERCIAL:** **rgb2x / RGB-X** (`zheng95z/rgbx` + `toyxyz/ComfyUI_rgbx_Wrapper`; albedo/normal/roughness/metallic/irradiance; Adobe Research, noncommercial) and **Ubisoft CHORD** (`ubisoft/ComfyUI-Chord`; full basecolor/normal/height/roughness/metalness; Ubisoft research-only license).
- **The only true temporal method:** **NVIDIA UniRelight** (`nv-tlabs/UniRelight`) denoises the whole clip jointly so attention enforces cross-frame consistency. But it is NVIDIA noncommercial, has NO ComfyUI node, and outputs albedo + relit video only (no metallic/roughness/height).
- **3D route (real PBR, but UV/mesh space, not aligned per-frame passes):** **TRELLIS.2** (`microsoft/TRELLIS.2-4B`, MIT, commercial-OK) and **Hunyuan3D-2.1** emit basecolor/roughness/metallic on a generated mesh. Cleaner PBR, but it solves "make a 3D asset," not "decompose my footage." CAVEATS for TRELLIS.2-4B: it is NOT a ComfyUI node and NOT a diffusers pipeline - it needs the `microsoft/TRELLIS.2` GitHub stack (the `trellis2` + `o_voxel` packages) installed; it is LINUX-ONLY, needs 24GB+ VRAM, and was tested on A100/H100 only (consumer RTX GPUs untested, CUDA 12.4 recommended). Image-to-3D (single image -> GLB mesh with PBR); resolution/speed tradeoff 512 cubed (~3s H100) / 1024 cubed (~17s) / 1536 cubed (~60s); base model with NO RLHF alignment (style varies with the training distribution), and raw meshes may have small holes needing post-process hole-fill.
- **Realistic recipe for a sequence today:** decompose each frame with the Apache-2.0 stack (Marigold-IID for albedo/roughness/metallic, StableNormal for normals, StableDelight to kill specular), then add an explicit temporal pass (optical-flow warp + blend, the `pablodawson/Marigold-Video` technique) to suppress flicker. It reduces, not eliminates, flicker; metallic and height are the least reliable channels (single-photo material is physically ambiguous, so there is a real precision ceiling). For commercial cleanliness stay on Apache/openrail tools and avoid rgb2x / CHORD / UniRelight.

## Max detail, precision, and sequence-native VFX I/O

- **Tiled detail at high res:** **Ultimate SD Upscale** (`ssitu/ComfyUI_UltimateSDUpscale`, GPL-3.0) or **Tiled Diffusion / MultiDiffusion + Tiled VAE** (`shiimizu/ComfyUI-TiledDiffusion`; note the MultiDiffusion part is CC-BY-NC-SA). Kill seams with a **ControlNet Tile** (conditions each tile on the source colors, the single biggest seam/drift reducer), higher tile overlap + mask blur, low denoise (~0.2-0.35), or SpotDiffusion / Context-Only-Overlap. For max detail prefer **upscale-then-refine** (ESRGAN-class upscale -> tiled img2img refine at low denoise) over hi-res fix.
- **Detail injection (training-free):** **Detail Daemon** (`Jonseed/ComfyUI-Detail-Daemon`, MIT; biases the sigma schedule to keep fine detail, adds no noise), the **PAG / SEG / NAG / FDG** family (`pamparamm/sd-perturbed-attention`, MIT), and **FreeU** (core node). All are tuning knobs that can over-sharpen or over-saturate.
- **Precision:** fidelity is fp32 >= bf16 >= fp8. Decode the VAE in fp32 or bf16, never fp16 for VFX. fp8 speeds sampling on FP8-tensor-core GPUs but loses quality (mostly in the UNet).
- **Color and bit depth:** SaveImage clamps to 8-bit PNG by default (banding on gradients/depth). For VFX use 32-bit EXR I/O: **`spacepxl/ComfyUI-HQ-Image-Save`** (32-bit float EXR for images AND latents, `%04d` sequences, MIT) and **`Conor-Collins/ComfyUI-CoCoTools_IO`** (Load EXR Sequence, EXR layer / Cryptomatte, OCIO colorspace sRGB / Linear / ACEScg, MIT). Convert sRGB -> Linear before saving a linear EXR or you double-apply gamma.
- **Samplers for detail:** `dpmpp_2m` (or `_sde`) with the **Karras** scheduler spends more steps in the low-sigma region where fine detail forms; ~20-35 steps is the sweet spot, more is diminishing returns.
- **The core tension:** per-frame max detail flickers; cross-frame stability blurs detail. Resolve it three ways: (a) a sequence-native upscaler that does both (**SeedVR2**, batch >= 5, `temporal_overlap`); (b) lock structure (low denoise + ControlNet Tile) and vary only fine detail; (c) detail-pass then a light deflicker. The deflicker window and SeedVR2 batch size are the explicit dials.

## High-detail matting / alpha extraction (hair, fur, semi-transparent, motion blur)

Pulling a clean alpha with hair/fur edges and fractional (semi-transparent) pixels is a multi-stage job, not one node. Trimap-free segmenters give near-binary silhouettes; true soft alpha needs a trimap/prompt model or a video-memory model. Per-frame matting of a sequence flickers unless the model is temporal.

**Still image, VFX-grade edges (the pipeline):** coarse select (SAM3, BiRefNet, or GroundingDINO) -> build a trimap (erode/dilate the coarse mask, or auto-trimap) -> alpha matte (ViTMatte for trimap-driven; SDMatte or Matte-Anything for prompt-driven, both stronger on transparency) -> edge refine (LayerStyle `MaskEdgeUltraDetailV2`, a local ViTMatte pass that captures hair and semi-transparent edges).
- One-node commercial-safe default: **BiRefNet_HR-matting** (2048, transparency-trained, MIT) or **InSPyReNet** (transparent-background, MIT).
- Best modern soft alpha on transparent objects: **SDMatte** (vivo, ICCV 2025, diffusion prior, MIT) or **Matte-Anything** (SAM -> auto-trimap -> ViTMatte, MIT).
- Hub pack bundling RMBG-2.0 / INSPYRENET / BEN2 / BiRefNet / SDMatte / SAM2 / SAM3: **ComfyUI-RMBG** (1038lab, GPL-3.0).

**Video / temporal (stable alpha across frames):** the per-frame segmenters above shimmer on a sequence (no frame-to-frame coupling). Use a temporal model:
- **MatAnyone** (CVPR 2025) and **MatAnyone2** (CVPR 2026 Highlight) - consistent memory propagation, true soft alpha that targets hair, semi-transparency, and motion blur. It is a PROPAGATOR, not a detector: it needs a first-frame (keyframe) mask from SAM2 / SAM3 / SeC. Memory flags `max_mem_frames` / `use_long_term` / `max_internal_size` trade quality for VRAM on long clips. Wrappers: FuouM/ComfyUI-MatAnyone (MIT), spiritform/comfy-matanyone2. **License: NTU S-Lab 1.0 (research-only).**
- **Robust Video Matting (RVM)** - older, human-only, detector-free, very fast (4K@76fps); the zero-setup fallback for clean human shots. GPL-3.0; the ComfyUI-Video-Matting wrapper is stale (2024).
- **Turnkey local pipeline:** `Code2Collapse/ComfyUI-CustomNodePacks` (Apache-2.0) ships a single "SeC + MatAnyone2" node (coarse concept-segment -> temporal matte) and a "SAM + ViTMatte" image node.
- **Recipe:** SAM2/SAM3/SeC keyframe mask -> MatAnyone2 temporal alpha -> optional edge refine -> composite.

**Ready workflows (checked the official library 2026-06):** Comfy-Org `workflow_templates` ships `remove_background_birefnet` (image, local BiRefNet matte) and `image/video_segmentation_sam3` (coarse, binary). There is **NO free local temporal video-matte template** - the only shipped video-matte templates are Bria API nodes (paid cloud: `api_bria_remove_video_background`). Build the local temporal pipeline yourself or use the Code2Collapse pack.

**Honest limits:** true transparency (glass, smoke, veils) and fast motion-blur edges are where every one of these is weakest. MatAnyone CLAIMS them but it is research-grade and untested on arbitrary plates; thin flyaway wisps are the hardest case; per-frame models shimmer; trimap-free models bias interior alpha to opaque; 4K is checkpoint/tile dependent, not free; a bad coarse mask propagates as a bad matte. None replace hand roto on a hero transparency shot.

**License map:** commercial-safe MIT - BiRefNet, ViTMatte, Matte-Anything, SDMatte, InSPyReNet, LayerStyle, SeC, the Code2Collapse pack. Flag: RMBG-2.0 (CC BY-NC, noncommercial), MatAnyone / MatAnyone2 (NTU S-Lab research-only), RVM and ComfyUI-RMBG (GPL-3.0 copyleft).

**RMBG-2.0 load caveats:** the model is GATED on HF - accept the license + use a token to download (an unauthenticated `from_pretrained` returns 401), and loading requires `trust_remote_code=True` (omitting it fails with a load error). Both omissions cause silent failures when an agent tries to use it without the right credentials or load flag.

| Matting tool | Repo / model | Use | License |
|---|---|---|---|
| BiRefNet (+ HR-matting) | github.com/ZhengPeng7/BiRefNet | trimap-free soft-alpha matte, hair edges, 2048 | MIT |
| ViTMatte | github.com/hustvl/ViTMatte | trimap-driven true fractional alpha (edge-refine standard) | MIT |
| Matte-Anything | github.com/hustvl/Matte-Anything | SAM -> auto-trimap -> ViTMatte, transparent objects | MIT |
| SDMatte | github.com/vivoCameraResearch/SDMatte | diffusion-prior prompt matting, fine edges | MIT |
| InSPyReNet | github.com/john-mnz/ComfyUI-Inspyrenet-Rembg | trimap-free RGBA, strong default | MIT |
| ComfyUI-RMBG (hub) | github.com/1038lab/ComfyUI-RMBG | bundles RMBG2/BEN2/BiRefNet/SDMatte/SAM2-3 | GPL-3.0 |
| LayerStyle (edge refine) | github.com/chflame163/ComfyUI_LayerStyle | MaskEdgeUltraDetailV2 ViTMatte refine | MIT |
| RMBG-2.0 | huggingface.co/briaai/RMBG-2.0 | soft-alpha segmenter | CC BY-NC (NONCOMMERCIAL) |
| MatAnyone / MatAnyone2 | github.com/pq-yang/MatAnyone , /MatAnyone2 | temporal video matte (hair / transparency / blur) | NTU S-Lab 1.0 (research) |
| RVM | github.com/PeterL1n/RobustVideoMatting | fast detector-free human video matte | GPL-3.0 |
| SAM3 / SAM2 / SeC | github.com/facebookresearch/sam3 , /sam2 , github.com/OpenIXCLab/SeC | coarse (binary) select / video tracking, feeds the matter | SAM: Meta ; SeC: Apache-2.0 |
| Code2Collapse pack | github.com/Code2Collapse/ComfyUI-CustomNodePacks | turnkey SeC+MatAnyone2 + SAM+ViTMatte pipelines | Apache-2.0 |

Sources: github.com/ZhengPeng7/BiRefNet ; huggingface.co/docs/transformers/model_doc/vitmatte ; github.com/vivoCameraResearch/SDMatte ; github.com/pq-yang/MatAnyone2 ; github.com/PeterL1n/RobustVideoMatting ; github.com/Code2Collapse/ComfyUI-CustomNodePacks ; github.com/Comfy-Org/workflow_templates.

## Detailed inpainting on a high-res image (crop and stitch)

Inpainting or detail-fixing a small region of a large image directly is wasteful and off-resolution: run the model on the full canvas and it is slow and OOM-prone; downsample the whole image and the result goes soft. The fix is **crop and stitch** - crop only the masked region, size that crop to the model's native resolution, generate, then composite it back into the full-res original. This is how you add a person, fix hands/faces, or do detailed edits without regenerating the whole image.

- **Established:** `comfyui-inpaint-cropandstitch` (Comfy Registry) - the proven crop/stitch node pair, used in the Flux.2 masked-inpaint recipe here.
- **Auto-sizing alternative (new):** **HallettVisual Smart Image Crop and Stitch** (Apache-2.0), nodes `SmartImageCrop` + `SmartImageStitcher`. It auto-sizes the crop to the model's native resolution AND your GPU limits (`force_divisibility` keeps it VAE/model-friendly), with no-mask modes (Bypass / Resize Full / Crop Full) and a stitcher that blends + color-matches on the way back, so the manual crop-sizing this pattern normally needs goes away. Ships a ready Flux Klein workflow. New as of mid-2026 and lightly battle-tested, so prefer the established node for production until it matures.
- **Flow (either tool):** source `IMAGE` + `MASK` -> crop node -> process `crop_image` / `crop_mask` with your inpaint / detail / upscale graph -> stitcher node (+ the original image + the crop's stitch-info) -> final full-res image.
- **Official workflow:** `Klein Smart Crop and Stitch Hallett.json` in the repo's `workflows/` (Flux Klein: UNETLoader + ReferenceLatent + SamplerCustomAdvanced feeding the two Smart nodes). Fetch the exact file rather than rebuilding it from memory.

Sources: github.com/HallettVisual/ComfyUI-Smart-Image-Crop-and-Stitch ; Comfy Registry: comfyui-inpaint-cropandstitch.

## Combine two specific people (multi-reference identity compositing)

Putting two named faces (the user + a target person) into one believable image is reference-conditioning, not a from-scratch prompt. Recipe (adapted from `Comfy-Org/comfy-skills`, MIT):
- **Two real references are essential.** Without a reference of the second person the model leans on training data and misses the likeness. Have only a name? Generate a clean reference portrait first (Nano Banana 2 / Pro, or a strong edit model), then feed THAT back as reference 2.
- **Batch then edit.** Combine both refs with `ImageBatch` (`image1` = the user, `image2` = the other person) and feed the batch into a reference-capable edit model.
- **Face accuracy (from testing):** Nano Banana 2 at `thinking_level: HIGH` (best) > Nano Banana Pro > Kling O3 (`kling-v3-omni`) > FLUX Kontext (single-ref only, moderate) > SDXL img2img (poor). Fully local path: Qwen-Image-Edit handles two-image edits, identity accuracy below Nano Banana 2.
- **Name which ref is which in the prompt:** "The first image is [A] - reproduce this face EXACTLY (features, hair, ...); the second image shows [B] - reproduce their face exactly; they pose together in [setting], [style]. Important: NO glare on glasses, NO lens reflections." Stating which image is whom dramatically improves the likeness.
- **Run 3 seeds in parallel** (face reproduction varies by seed), let the user pick, then refine on the same seed (stay close) plus new ones.

## Tool reference (verified 2026-06, with license)

| Tool | Repo / model | Use | License |
|---|---|---|---|
| WanVideoWrapper | github.com/kijai/ComfyUI-WanVideoWrapper | Wan 2.x + context windows + FreeNoise | Apache-2.0 |
| Wan VACE | huggingface.co/Wan-AI/Wan2.1-VACE-14B | control / vid2vid / inpaint, temporally stable | Apache-2.0 |
| AnimateDiff-Evolved | github.com/Kosinkadink/ComfyUI-AnimateDiff-Evolved | SD1.5/SDXL long stable anim | Apache-2.0 |
| comfyui_controlnet_aux | github.com/Fannovel16/comfyui_controlnet_aux | depth/pose/tile preprocessors for per-frame control | Apache-2.0 |
| Frame-Interpolation | github.com/Fannovel16/ComfyUI-Frame-Interpolation | RIFE / FILM interpolation | MIT |
| SuperBeasts | github.com/SuperBeastsAI/ComfyUI-SuperBeasts | Deflicker / PixelDeflicker (luminance only) | MIT |
| SeedVR2 | github.com/numz/ComfyUI-SeedVR2_VideoUpscaler | temporally-coherent video upscale (batch >= 5) | check repo (ByteDance model) |
| Veevee / FLATTEN | github.com/logtd/ComfyUI-Veevee , /ComfyUI-FLATTEN | SD-era unsample + flow attention (STALE, SD only) | Veevee GPL-3.0 ; FLATTEN no LICENSE file |
| Marigold (+IID) | github.com/kijai/ComfyUI-Marigold | depth / normals / albedo+roughness+metallic | GPL-3.0 (model: Apache-2.0) |
| StableX (Normal+Delight) | github.com/kijai/ComfyUI-StableXWrapper | sharp normals + de-light to albedo | no LICENSE file (models: Apache-2.0) |
| StableMaterials | huggingface.co/gvecchio/StableMaterials | image/text -> tileable PBR (synthesizes) | openrail |
| rgb2x / RGB-X | github.com/toyxyz/ComfyUI_rgbx_Wrapper | albedo/normal/roughness/metallic/irradiance | Adobe, NONCOMMERCIAL |
| Ubisoft CHORD | github.com/ubisoft/ComfyUI-Chord | full single-image PBR set | research-only |
| UniRelight | github.com/nv-tlabs/UniRelight | temporally-stable albedo + relit video (no node) | NVIDIA NONCOMMERCIAL |
| TRELLIS.2 | huggingface.co/microsoft/TRELLIS.2-4B | image -> 3D with real PBR (mesh, not per-frame) | MIT |
| Ultimate SD Upscale | github.com/ssitu/ComfyUI_UltimateSDUpscale | tiled high-res detail refine | GPL-3.0 |
| TiledDiffusion | github.com/shiimizu/ComfyUI-TiledDiffusion | MultiDiffusion / SpotDiffusion / Tiled VAE | CC-BY-NC-SA + GPLv3 |
| Detail Daemon | github.com/Jonseed/ComfyUI-Detail-Daemon | sigma-schedule micro-detail | MIT |
| PAG family | github.com/pamparamm/sd-perturbed-attention | PAG/SEG/NAG/FDG guidance | MIT |
| HQ-Image-Save | github.com/spacepxl/ComfyUI-HQ-Image-Save | 32-bit float EXR (images + latents) | MIT |
| CoCoTools_IO | github.com/Conor-Collins/ComfyUI-CoCoTools_IO | EXR sequence/layer, OCIO color management | MIT |

Flag the NONCOMMERCIAL ones (rgb2x, CHORD, UniRelight, the MultiDiffusion part of TiledDiffusion) before any commercial use; everything else above is permissive (Apache/MIT/openrail/GPL).

**Wan2.1-VACE-14B (Apache-2.0) recipe:** three input modes - R2V (`src_ref_images`, no preprocessing), V2V (`src_video`, needs preprocessing for depth/pose), MV2V (masked video editing, needs preprocessing); V2V/MV2V run the `vace_preproccess.py` step, R2V skips it. Resolution targets: 480P (~81x480x832) and 720P (~81x720x1280) - the 14B supports both, the 1.3B is 480P only. CLI: `--model_name vace-14B` (or `vace-1.3B`) with `--src_ref_images` / `--src_video` / `--src_mask`; a negative prompt is recommended (same boilerplate as T2V/I2V). Full per-task parameter docs: github.com/ali-vilab/VACE/blob/main/UserGuide.md.

## Sources

Strengths/limits: github.com/comfyanonymous/ComfyUI (+ issues 7322, 500, 11905, 11791, 9156, 11660, 13116, 2229) ; docs.comfy.org/development/comfyui-server/comms_routes ; docs.comfy.org/custom-nodes/backend/server_overview ; blog.comfy.org (subgraph-official-release, dynamic-vram-in-comfyui-saving-local, comfyui-native-api-nodes, launching-comfyui-registry, comfyui-2025-jan-security-update). Temporal: docs.comfy.org/tutorials/video/wan/vace ; deepwiki.com/kijai/ComfyUI-WanVideoWrapper ; civitai.com/articles/5906 (unsampling). PBR: blog.comfy.org/p/ubisoft-open-sources-the-chord-model ; research.nvidia.com/labs/toronto-ai/UniRelight ; the repos in the table. Detail/precision: the repos in the table ; neurocanvas.net/blog/fp8-vs-bf16-comfyui-guide.
