# Custom-author nodes used in the kit's workflows

The non-core, non-API author packs whose nodes actually appear in our workflow library (the 444 official
template bundles + our saved workflows). Derived from the live inventory (`_INVENTORY.md`); I/O **confirmed via
get_node_info on 2026-06-30** (ComfyUI 0.25.1). kijai's packs (KJNodes etc.) are documented separately in
`docs/KIJAI.md` and are not duplicated here.

Two packs are used: **ComfyUI-REDACTED** (the owner's own pack) and **ComfyUI-LTXVideo** (Lightricks). The only
custom node used but NOT installed locally is `SimpleMath+` (from `ComfyUI_essentials`, cubiq); see the end.

---

## ComfyUI-REDACTED  (the owner's own pack; category `REDACTED/*`)
A fisheye-dome pipeline: load -> reproject to flat tangent patches -> upscale -> reproject back -> save. Built
for REDACTED dome masters. Its generic Linear<->Log color node has moved to the `ComfyUI-OCIO` pack as
`OCIOLogConvert` (see `ocio.md`).

### REDACTEDLoad  (display: "REDACTED Load (video / image / folder)")
- **category:** `REDACTED/io` | **purpose:** auto-detect a dome source and load it as an IMAGE batch.
- **inputs:** `path` (STRING: a video file / single image / folder-as-sequence), `fps_override` (FLOAT, 0=auto), `max_frames` (INT, 0=all), `start_frame` (INT).
- **outputs:** `images` (IMAGE batch), `fps` (FLOAT), `source_info` (STRING).
- **how / strengths:** any codec ffmpeg reads; 16-bit PNG/TIFF -> /65535; **EXR and float TIFF keep real HDR range (no clip)**. The HDR-correct loader.
- **anti-patterns:** a folder must be a sorted image sequence; mixed sizes will not batch.
- **placement:** graph root for a dome pipeline; feeds REDACTEDToTangent.

### REDACTEDToTangent  (display: "REDACTED -> Tangent Patches")
- **category:** `REDACTED/geometry` | **purpose:** reproject a fisheye dome master into flat tangent patches so 2D models can process it without fisheye distortion.
- **inputs:** `image` (IMAGE, square fisheye 0..1), `fov_deg` (FLOAT, default 180), `patch_size` (INT, default 256), `tilt_deg` (FLOAT, dome tilt), `rings_preset` (combo: default/dense/sparse).
- **outputs:** `patches` (IMAGE, order frame-major), `layout` (`REDACTED_LAYOUT` token).
- **placement:** between REDACTEDLoad and any per-patch processing (upscale / diffusion). The `layout` MUST be carried to REDACTEDFromTangent (and optionally REDACTEDSeedVR2) for the inverse.
- **anti-patterns:** dropping the `layout` token breaks reconstruction; non-square input mis-projects.

### REDACTEDSeedVR2  (display: "REDACTED SeedVR2 (video SR)")
- **category:** `REDACTED/video_sr` | **purpose:** temporal video super-resolution of the tangent-patch batch via the SeedVR2 model.
- **inputs:** `images` (IMAGE patches), `resolution` (INT short-side), `cuda_device` (STRING, the 2-GPU dispatch point), `batch_size` (INT, 0=auto 4n+1 per clip), `dit_model` (STRING, default fp8 3B), `blocks_to_swap` (INT, BlockSwap VRAM saving); optional `layout` (`REDACTED_LAYOUT`, groups patches into temporal clips).
- **outputs:** `images` (IMAGE, SAME order as input).
- **how / gotchas:** runs the vendored SeedVR2 CLI in the REDACTED_Upscaler venv via subprocess; set `REDACTED_PROJECT_ROOT` to relocate. Connect `layout` so frames-of-one-patch form a temporal clip (coherence); without it the whole batch is one clip.
- **placement:** between REDACTEDToTangent and REDACTEDFromTangent.

### REDACTEDFromTangent  (display: "Tangent Patches -> REDACTED")
- **category:** `REDACTED/geometry` | **purpose:** inverse of REDACTEDToTangent: feather-splat patches back to fisheye frames.
- **inputs:** `patches` (IMAGE, possibly upscaled), `layout` (`REDACTED_LAYOUT` from the forward node), `target_size` (INT, 0=round-trip to input resolution).
- **outputs:** `image` (IMAGE, reconstructed dome master).
- **placement:** after patch processing; feeds REDACTEDSave.

### REDACTEDSave  (display: "REDACTED Save (video + sequence)")
- **category:** `REDACTED/io` | **output node** | **purpose:** write the dome batch as a video master and/or image sequence.
- **inputs:** `images` (IMAGE), `filename_prefix` (STRING), `fps` (FLOAT), `save_video` (BOOL), `video_codec` (combo: prores_4444 / prores_422hq / h264_preview), `save_sequence` (BOOL), `sequence_format` (combo: exr_f16 / exr_f32 / tiff_16 / png_16 / png_8).
- **outputs:** `video_path` (STRING), `sequence_dir` (STRING).
- **strengths:** ProRes 10-bit + EXR keep HDR headroom; the HDR-correct sink for dome work.
- **anti-patterns:** `png_*` clips to 0..1 (loses HDR); use exr/tiff to preserve range.

### REDACTEDLogConvert -- RETIRED, moved to ComfyUI-OCIO
The generic Linear<->Log node has moved out of ComfyUI-REDACTED into our `ComfyUI-OCIO` pack as `OCIOLogConvert`
(a correct name, and it joins the full OCIO set). Full entry in `ocio.md`; the technique in `color-and-transform.md`.

---

## ComfyUI-LTXVideo  (Lightricks; category `Lightricks/*`)
LTX-2 video helpers used by the LTX templates and our HDR / IC-LoRA workflows. See also `MODELS.md` (LTX-2
recipes) and `docs/LTX2_TRAINING.md`.

### LTXVHDRDecodePostprocess  (display: "LTXVHDR Decode Postprocess")
- **category:** `Lightricks/HDR` | **output node** | **purpose:** decompress LogC3 HDR IC-LoRA VAE output + Reinhard tonemap. Place AFTER VAE Decode.
- **inputs:** `image` (IMAGE); optional `exposure` (FLOAT EV, default 0), `save_exr` (BOOL), `output_dir` (STRING), `filename_prefix` (STRING), `half_precision` (BOOL, float16 EXR).
- **outputs:** `tonemapped` (IMAGE, SDR preview), `hdr_linear` (IMAGE, raw linear HDR for downstream).
- **gotchas:** for `save_exr` set env `OPENCV_IO_ENABLE_OPENEXR=1` or the EXR write fails.
- **placement:** straight after the LTX VAE Decode on an HDR IC-LoRA graph.

### LTXAddVideoICLoRAGuide  (display: "Add Video IC-LoRA Guide")
- **category:** `Lightricks/IC-LoRA` | **purpose:** inject one or more conditioning frames (image or multi-frame video) into an LTX video latent at a frame index.
- **inputs:** `positive` / `negative` (CONDITIONING), `vae` (VAE), `latent` (LATENT, must be a 5D video latent), `image` (IMAGE), `frame_idx` (INT), `strength` (FLOAT), `latent_downscale_factor` (FLOAT, 1=full/2=half for small-grid IC-LoRA), `crop` (disabled/center), `use_tiled_encode` (BOOL) + `tile_size` / `tile_overlap`.
- **outputs:** `positive`, `negative` (CONDITIONING), `latent` (LATENT).
- **gotchas:** `frame_idx` for video must be 1 modulo 8 (else rounded down). Sibling `LTXAddVideoICLoRAGuideAdvanced` adds `attention_strength` + an optional spatial `attention_mask`.
- **placement:** after encoding conditioning, before the LTX sampler; chains (call again to add more guides).

### LTXICLoRALoaderModelOnly  (display: "IC-LoRA Loader Model Only")
- **category:** `Lightricks/IC-LoRA` | **purpose:** load an LTX IC-LoRA and read its `latent_downscale_factor` from the safetensors metadata.
- **inputs:** `model` (MODEL), `lora_name` (combo of LTX LoRAs), `strength_model` (FLOAT).
- **outputs:** `model` (MODEL), `latent_downscale_factor` (FLOAT) - feed the factor straight into LTXAddVideoICLoRAGuide.
- **placement:** after the model loader; pairs with LTXAddVideoICLoRAGuide.

### GemmaAPITextEncode  (display: "Gemma API Text Encode")
- **category:** `api node/text/Lightricks` | **purpose:** enhance a prompt with Gemma 3 (Lightricks API) then encode it to CONDITIONING for LTX.
- **inputs:** `api_key` (STRING), `prompt` (STRING), `enhance_prompt` (BOOL, default true), `ckpt_name` (combo of installed checkpoints).
- **outputs:** `conditioning` (CONDITIONING).
- **gotchas:** needs a Lightricks API key (cloud call); set `enhance_prompt` false to encode verbatim. For offline prompt enrichment prefer the in-graph LLM nodes in `docs/NODES.md`.
- **placement:** replaces CLIPTextEncode on an LTX graph when you want Gemma enhancement.

---

## Missing custom node (used in a template, not installed)
- **`SimpleMath+`** - from `ComfyUI_essentials` (github.com/cubiq/ComfyUI_essentials). A string/number math
  expression node. Used by one template. To document its real I/O, read the pack's source (the `essentials`
  math node) or install the pack and `get_node_info SimpleMath+`. Reading the source does not require
  installing it.
