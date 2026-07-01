# Custom-author nodes used in the kit's workflows

The non-core, non-API author packs whose nodes actually appear in our workflow library (the 444 official
template bundles + our saved workflows). Derived from the live inventory (`_INVENTORY.md`); I/O **confirmed via
get_node_info on 2026-06-30** (ComfyUI 0.25.1). kijai's packs (KJNodes etc.) are documented separately in
`docs/KIJAI.md` and are not duplicated here.

The get_node_info-confirmed pack here is **ComfyUI-LTXVideo** (Lightricks). Also documented, from their READMEs
(not installed locally, I/O unconfirmed): **ComfyUI-Panorama-Stickers** (nomadoor), the model-agnostic 360 tool
the Flux.2 Klein and LTX-2.3 panorama recipes share, and **ComfyUI_Gear** (oumad), the LogC3/LogC4 HDR-EXR decode
+ grade side of the LumiPic SDR->HDR LoRAs. The only custom node used but NOT installed locally is
`SimpleMath+` (from `ComfyUI_essentials`, cubiq); see the end.

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

## ComfyUI-Panorama-Stickers  (nomadoor; MIT; category `Panorama/*`)
A model-agnostic 360 equirectangular (ERP) toolkit + WebGL frontend extension. Used by BOTH the Flux.2 Klein 360
image route AND the LTX-2.3 360 video route (see `MODELS.md`), so it lives here rather than under either model -
it is a projection tool, not a model-specific pack. **NOT installed locally:** node names + purposes are from the
pack README (2026-07-01); I/O is NOT get_node_info-confirmed (install via ComfyUI Manager + `get_node_info` to
lock exact sockets before wiring).

- **Panorama Stickers** - place / scale / rotate sticker images onto an ERP canvas; outputs a composited
  conditioning panorama (the piece you feed an outpaint / inpaint sampler).
- **Panorama Cutout** - extract a framed perspective (rectilinear) view from an ERP image via a saved
  camera / frame state; the counterpart that lets you edit a normal-lens crop and composite it back.
- **Panorama Preview** - interactive drag-around 360 preview inside ComfyUI (WebGL), without duplicating the
  default image preview. No headset needed - this is the "judge VR coverage" node.
- **Panorama Seam Prep** - shift the ERP wrap seam to the image center and emit hard / blurred vertical seam
  masks, for seam-focused inpainting (removes the left/right-edge discontinuity of an equirect).

v1.3.0 added video + 180-panorama support. Companion outpaint LoRAs the pack was built around (nomadoor):
Flux.2 Klein 360 ERP outpaint (`flux-2-klein-4B-...` apache-2.0 / `-9B-...` license:other). Source:
github.com/nomadoor/ComfyUI-Panorama-Stickers ; comfyui.nomadoor.net/en/notes/panorama-stickers.

---

## ComfyUI_Gear  (oumad / oumoumad; MIT; category `Gear/*`)
VFX HDR-EXR nodes - the ComfyUI decode side of the **LumiPic** SDR->HDR LoRAs (see MODELS.md, Qwen-Image-Edit).
**NOT installed locally:** node names + I/O are from the pack README (2026-07-01), not get_node_info-confirmed;
needs `>= v0.2.0` for the LogC4 node. Three nodes:

- **Gear · LogC3 Decode + Save EXR** - inverse-LogC3 a `[0,1]` LoRA output to scene-linear HDR + write a float16
  EXR. Ceiling ~55 linear (~8.3 stops above 0.18 mid-gray). Input `image` (IMAGE, the log-compressed LoRA output).
  Outputs `hdr_linear` (scene-linear HDR, values > 1), `tonemapped_preview` (Reinhard at a `preview_ev`),
  `exr_paths` (newline-joined saved paths). `filename_prefix` takes ComfyUI tokens; EXRs auto-counter-suffixed.
  Also decodes the **LTX-2 HDR IC-LoRA** output (the README lists it as a valid LogC3 input).
- **Gear · LogC4 Decode + Save EXR** - identical I/O, ARRI LogC4, ceiling ~470 linear (~11.3 stops, ~3 extra
  highlight stops); for LoRAs trained on LogC4 targets (LumiPic V10 `*_logc4_*`). NEVER mix curves - the wrong
  node is silently wrong absolute linear.
- **Gear · Color Grade (exr-viewer)** - a full ACEScct grade panel as a pop-up modal (color wheels,
  lift/gamma/gain/offset, scopes, an A|B wipe vs an optional `sdr_reference`, batch scrubber, AgX / ACES Fitted /
  Hable / Reinhard tonemappers, `.cube` LUTs), powered by an embedded `exr-viewer` SPA. Wire `hdr_linear` in;
  outputs `graded_display` (display sRGB 0..1) and `graded_linear` (scene-linear HDR, pipe back to an EXR writer
  to bake the grade). Grade math is a mirrored GLSL shader (live preview) + torch port (backend).

RELATION TO OUR ComfyUI-OCIO (honest): Gear decodes LogC3/LogC4 -> linear and writes EXR but keeps the SOURCE
primaries (no gamut convert); for a true ACEScg master, decode LogC3 with our `OCIOLogConvert(logc3)` then
`OCIOColorSpace(Rec.709 -> ACEScg)` -> `OCIO Write`. Gear's edge is LogC4 (a curve our OCIO does NOT have yet) plus
the grade panel. Source: github.com/oumad/ComfyUI_Gear.

---

## Missing custom node (used in a template, not installed)
- **`SimpleMath+`** - from `ComfyUI_essentials` (github.com/cubiq/ComfyUI_essentials). A string/number math
  expression node. Used by one template. To document its real I/O, read the pack's source (the `essentials`
  math node) or install the pack and `get_node_info SimpleMath+`. Reading the source does not require
  installing it.
