# Node Library - index (start here)

The kit's per-node knowledge base: for every node, what it is for, what each input/output is for, how it
behaves, its strengths, bugs + fixes, anti-patterns, and where it slots in a graph. Built so a future agent
**remembers what is where** instead of rediscovering it. New to this? Read `_SCHEMA.md` for the format and the
rules (live-vs-curated I/O, confirmed-vs-inferred, add-on-encounter, custom-node authorship).

**Live I/O is never frozen here.** For a node's exact current inputs/outputs/defaults, query
`get_node_info <ClassType>` (MCP) or `/object_info`. This library holds the durable layer on top: semantics,
gotchas, fixes, placement, build-vs-search calls.

## The full universe (every node used in our workflows)
**`_INVENTORY.md`** is the master catalog: all **547 distinct node types** used across the kit's workflow
library (official template bundles), classified against a live ComfyUI: **185 core,
194 API / cloud partner, 4 custom-author** (ComfyUI-LTXVideo), 3 missing-but-used, 161
subgraph ids. Scan it to know a node EXISTS and where it comes from, even before it has a full entry below.
Regenerate with `tools/node_inventory.py`.

## Documented nodes

### `core.md` - the minimal text-to-image chain (all I/O confirmed 2026-06-30)
| Node | Purpose |
|------|---------|
| CheckpointLoaderSimple | load a checkpoint -> MODEL / CLIP / VAE |
| LoraLoader | apply a LoRA to model + CLIP (stackable, negative ok) |
| CLIPTextEncode | prompt -> CONDITIONING (use the model-specific encoder for Flux/SD3/SDXL) |
| EmptyLatentImage | blank latent canvas, sets output resolution |
| KSampler | the denoiser (seed/steps/cfg/sampler/scheduler/denoise) |
| VAEDecode | latent -> IMAGE (tiled / loop variants for big or video) |
| SaveImage | write 8-bit sRGB PNG (output node) |

### `color-and-transform.md` + `ocio.md` - color management + manual geometry
| Entry | Purpose |
|-------|---------|
| TECHNIQUE: transform in log | do manual scale/distort/warp in log space to preserve detail (Nuke/OCIO practice) |
| `ocio.md` - our ComfyUI-OCIO pack (Slava Sexton) | OCIO LogConvert + ColorSpace / Display / CDLTransform / FileTransform / LookTransform: the full Nuke OCIO set, runtime-verified |
| SaveImageAdvanced / LTXVHDRDecodePostprocess | native EXR / linear / HDR I/O (confirmed) |

### `custom-author.md` - non-core author packs used in our workflows (I/O confirmed 2026-06-30)
| Pack | Nodes |
|------|-------|
| ComfyUI-LTXVideo (Lightricks) | HDRDecodePostprocess / AddVideoICLoRAGuide / ICLoRALoaderModelOnly / GemmaAPITextEncode |
| missing: SimpleMath+ (ComfyUI_essentials) | used in 1 template, not installed - read source to document |

## Category reference (full per-node coverage, 183 entries, I/O confirmed via get_node_info 2026-06-30)
One file per category; every core node used across our workflows. Live I/O always from `get_node_info`.
| File | Entries | Covers |
|------|--------:|--------|
| `loaders.md` | 11 | VAE / LoRA / ControlNet / CLIPVision / upscale / style / checkpoint loaders |
| `samplers.md` | 17 | SamplerCustom(+Advanced), guiders, schedulers, noise, KSamplerAdvanced |
| `conditioning-1.md` | 20 | ControlNet apply, inpaint, IP2P, SVD, LTXV, Hunyuan, AceStep conditioning |
| `conditioning-2.md` | 17 | Wan I2V / FLF / VACE / camera / audio-driven video conditioning |
| `latent.md` | 21 | empty latents (image/video/audio/3D), VAE encode/decode, latent ops |
| `image-1.md` | 20 | scale / upscale / composite / outpaint / mask / batch / Canny |
| `image-2.md` | 14 | load / preview / save (WEBP/SVG), resize, mask compositing |
| `advanced.md` | 21 | UNET/CLIP loaders, Flux conditioning, ModelSampling, CFG/SLG patches |
| `three-d.md` | 8 | gaussian splat, Load3D / Preview3D, SaveGLB, voxel to mesh |
| `video.md` | 6 | Create / Save / Load / GetComponents / Slice / SaveWEBM |
| `audio.md` | 5 | Load / Save (MP3/Opus) / Concat / Record |
| `text.md` | 6 | string / regex / json helpers + local TextGenerate (LLM) |
| `utilities.md` | 11 | primitives, math, switch, resolution, PreviewAny, SUPIRApply |
| `experimental.md` | 6 | VAEDecodeTiled, DifferentialDiffusion, FluxKVCache, ManualSigmas |

API / cloud-partner nodes (194 across 44 providers) are catalogued in `_INVENTORY.md`; per-node entries are the next wave.

## Reverse lookup (by task)
- **Generate an image from text** -> the `core.md` graph.
- **Apply a style / subject LoRA** -> LoraLoader (`core.md`).
- **Preserve detail through a manual scale / distort / warp** -> log-space technique via `OCIO LogConvert` (`ocio.md`).
- **Convert colorspace, or apply a LUT / CDL / display / look** -> the OCIO nodes (`ocio.md`).
- **Save HDR / linear / EXR / 16-bit** -> SaveImageAdvanced (`color-and-transform.md`).
- **Big image OOMs on decode** -> VAEDecodeTiled (noted under VAEDecode, `core.md`).
- **Video loop seam artifacts on decode** -> VAEDecodeLoopKJ (noted under VAEDecode, `core.md`).
- **Base + refiner staged sampling** -> KSamplerAdvanced (noted under KSampler, `core.md`).

## Where other node knowledge lives (no orphan corners)
- **kijai ecosystem** (Wan / Hunyuan / Florence2 / KJNodes / SUPIR / SAM2 / DepthAnythingV2 ...) -> `docs/KIJAI.md` (per-tool node I/O + supersede map).
- **In-graph LLM nodes** (Anthropic Claude / OpenRouter prompt enrichment) -> `docs/NODES.md`.
- **Live bugs / broken paths** -> `docs/KNOWN_ISSUES.md` (read before building).
- **Core-node cheat-sheet + the /object_info discipline** -> `SKILL.md`.
- **Building your OWN node** (V3 API: basics / inputs / outputs / datatypes / lifecycle / packaging) -> the `comfyui-node-*` skills.

## Status
Started 2026-06-30 (ComfyUI 0.25.1). Grows on encounter: use or meet an undocumented node, add its entry before
finishing (see `_SCHEMA.md`). Entries carry their own confirmed/inferred + date.
