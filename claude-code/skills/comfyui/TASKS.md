# Task recipes (one entry point per common job)

`SKILL.md` is the full operating manual and `MODELS.md` is the per-model dialect. This file is the SHORTCUT
layer: a named task ("generate an image", "remove a background", "upscale", "image to video", "text to 3D",
"generate audio") mapped to the exact LOCAL flow. Every recipe runs on this machine's GPU via the template
library + `comfy_client` / the MCP driver (not a cloud), and every one ends with the same two non-negotiables:
validate inputs AND an output/save node before running (SKILL.md step 5), and save the built workflow to
`<ComfyUI>/user/default/workflows/` so the owner can reopen it.

The task-shortcut shape is adapted from `Comfy-Org/comfy-skills` (MIT); their version targets Comfy Cloud, these
are local-first.

## The shared spine (every task follows it)

1. **Find a template first** - read `templates/_quick_index.json`, match by task tag + model, read that
   `templates/<name>.json` and parameterize it. Building from scratch is the fallback, not the default.
2. **Pick the model with the hardware-aware check** - size it against live VRAM / RAM / disk (SKILL.md
   "hardware-aware") and recommend the variant that fits BEFORE downloading.
3. **Read the model's `MODELS.md` entry BEFORE writing the prompt** - each model has its own dialect and its own
   negative-prompt rule. Never carry one model's style to another.
4. **Validate** (SKILL.md step 5): every `class_type` is in `/object_info`, types match at every seam, model
   filenames exist locally, AND the graph has an input node + an output/save node. API / partner nodes often emit
   a tensor but include NO save node by default - add and wire one, or the job runs and produces nothing. Run
   small / low-res FIRST.
5. **Run** via `comfy_client.run()` or the MCP `enqueue_workflow`; poll status; fetch outputs; **view the output
   before shipping it**.
6. **Save** the workflow (GUI-format) to the workflows folder; hand over the name + the output paths + how to view.

## generate-image
- **Template:** search `_quick_index.json` for "text to image" + the model (e.g. the `text_to_image_z_image_turbo`
  blueprint, or a model-specific template). For img2img / style transfer, swap `EmptyLatentImage` for `LoadImage`
  + `VAEEncode`.
- **Model:** a turbo image model (Z-Image-Turbo, FLUX schnell, SDXL) usually fits one 24GB card. Read its MODELS.md
  entry for the prompt dialect + steps / cfg.
- **Chain:** loader -> `CLIPTextEncode` (pos / neg) -> `KSampler` (+ `EmptyLatentImage`) -> `VAEDecode` ->
  `SaveImage`. Edit models (Qwen-Image-Edit, FLUX Kontext, Nano Banana, Boogu Edit): feed the input image + the
  instruction per their MODELS.md entry.

## generate-video
- **Template:** "image to video" / "text to video" + the backend (LTX-2.3, Wan 2.2, HunyuanVideo); filter by the
  `video` tag if a text search returns image results. For i2v, feed the start frame via `LoadImage`.
- **Model:** video models are VRAM-heavy - run the hardware check; reach for fp8 / GGUF / multi-GPU on the big
  ones. Read the model's MODELS.md entry for camera + motion prompting.
- **Chain:** a video loader (`LTXVLoader` / `WanVideoModelLoader`) -> the video sampler -> a video output
  (`VHS_VideoCombine` / `SaveVideo`). The save node is mandatory. Renders take 30s to 2min+; run a short / low-res
  clip first.

## upscale-image
- **Template:** "upscale" / "super resolution". Upscaler models live in `upscale_models` (4x-UltraSharp general,
  RealESRGAN_x4plus photo, _anime_6B for illustration).
- **Chain:** `LoadImage` -> `UpscaleModelLoader` -> `ImageUpscaleWithModel` -> `SaveImage`. For more detail,
  upscale then a low-denoise (0.2-0.4) img2img pass. If the image is too big for VRAM, tile it (Ultimate SD
  Upscale, ADVANCED.md). For diffusion restore on degraded input, SUPIR / SeedVR2 (MODELS.md enhancement section).

## remove-background
- **Template:** "remove background". Nodes: `RMBG` (fast auto), `BiRefNet` (high-quality matting), `SAM` (precise
  masks).
- **Chain:** `LoadImage` -> the removal node -> `SaveImage` with PNG (to keep transparency). To REPLACE the
  background, composite a second image. For hair / fur / semi-transparent / motion-blur edges, use the multi-stage
  matting pipeline in ADVANCED.md, not a one-shot node.

## text-to-3D / image-to-3D
- **Template:** "Image to 3D" first (image-to-3D is the common case). Discover 3D nodes structurally:
  `/object_info` by `output_type` `MESH` / `FILE_3D_GLB`, or MODELS.md (Hunyuan3D local; Tripo / Rodin / Meshy via
  their API nodes).
- **Chain:** input (text or `LoadImage`) -> a 3D generation / reconstruction node -> a 3D save / output node. 3D
  takes longer than image; the save node is mandatory (mesh + textures + preview).

## generate-audio
- **Template:** "text to audio" / "music generation" / "sound effects" with `media_type: audio`. Models: Stable
  Audio (SFX / loops), ACE-Step (songs + lyrics), ElevenLabs / ChatterBox (TTS, API nodes). Read the MODELS.md
  entry for the field structure.
- **Chain:** the audio model nodes -> `SaveAudio`. Audio support is newer with fewer templates, so fall back to
  `/object_info` discovery for the available audio nodes.
