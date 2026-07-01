# Custom-author nodes used in the kit's workflows

The non-core, non-API author packs whose nodes actually appear in our workflow library (the 444 official
template bundles + our saved workflows). Derived from the live inventory (`_INVENTORY.md`); I/O **confirmed via
get_node_info on 2026-06-30** (ComfyUI 0.25.1). kijai's packs (KJNodes etc.) are documented separately in
`docs/KIJAI.md` and are not duplicated here.

The custom-author pack used here is **ComfyUI-LTXVideo** (Lightricks). The only custom node used but NOT
installed locally is `SimpleMath+` (from `ComfyUI_essentials`, cubiq); see the end.

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
