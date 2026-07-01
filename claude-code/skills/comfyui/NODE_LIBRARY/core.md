# Core graph - the minimal text-to-image chain

The seven nodes every SD1.5 / SDXL graph is built from. I/O **confirmed via get_node_info on 2026-06-30**
(ComfyUI 0.25.1). For Flux / SD3 / Qwen / video models the loaders and text encoders differ; see the per-model
recipes in `MODELS.md` and the dedicated encoders noted under CLIPTextEncode.

## The buildable graph (drop these, wire them)

```
CheckpointLoaderSimple ──MODEL──▶ [LoraLoader.model] ──▶ KSampler.model
                       ──CLIP───▶ [LoraLoader.clip]  ──▶ CLIPTextEncode(pos).clip
                       │                                └▶ CLIPTextEncode(neg).clip
                       └─VAE────────────────────────────▶ VAEDecode.vae

CLIPTextEncode(pos) ──CONDITIONING──▶ KSampler.positive
CLIPTextEncode(neg) ──CONDITIONING──▶ KSampler.negative
EmptyLatentImage    ──LATENT───────▶ KSampler.latent_image
KSampler            ──LATENT───────▶ VAEDecode.samples
VAEDecode           ──IMAGE────────▶ SaveImage.images
```

LoraLoader is optional (skip it and wire MODEL/CLIP straight to KSampler/CLIPTextEncode). That is the whole
txt2img pipeline: load, encode prompts, make an empty canvas, denoise, decode, save.

---

### CheckpointLoaderSimple  (display: "Load Checkpoint")
- **pack / source:** core ComfyUI (`nodes`) | **category:** `model/loaders` | **I/O confirmed:** 2026-06-30
- **purpose:** load a single all-in-one checkpoint and split it into the three things a graph needs.
- **inputs:**
  - `ckpt_name` (combo) - dropdown of files found under `models/checkpoints`. Empty dropdown = none found, check `extra_model_paths.yaml`.
- **outputs:**
  - `MODEL` - the diffusion UNet, feeds KSampler (or a LoraLoader first).
  - `CLIP` - the text encoder, feeds CLIPTextEncode.
  - `VAE` - the autoencoder, feeds VAEDecode.
- **how it works:** reads a `.safetensors` that bundles UNet + CLIP + VAE and hands out all three.
- **strengths:** one node, one file, the standard SD1.5 / SDXL entry point.
- **bugs / lags + fixes:** none in the node. If a checkpoint ships UNet-only (many Flux / video builds), its CLIP / VAE outputs are empty or wrong.
- **anti-patterns:** do not use for UNet-only diffusion models; there, use `UNETLoader` + `DualCLIPLoader` + `VAELoader` separately.
- **placement:** the root of the graph. Nothing feeds it; it feeds KSampler, CLIPTextEncode, VAEDecode.

### LoraLoader  (display: "Load LoRA (Model and CLIP)")
- **pack / source:** core ComfyUI (`nodes`) | **category:** `model/loaders` | **I/O confirmed:** 2026-06-30
- **purpose:** apply a LoRA to BOTH the diffusion model and CLIP, altering style / subject.
- **inputs:**
  - `model` (MODEL), `clip` (CLIP) - what the LoRA patches.
  - `lora_name` (combo) - file under `models/loras`.
  - `strength_model` (FLOAT, default 1, can be negative) - how hard to push the UNet.
  - `strength_clip` (FLOAT, default 1, can be negative) - how hard to push CLIP.
- **outputs:** `MODEL`, `CLIP` - the patched pair; chain another LoraLoader off these to stack LoRAs.
- **how it works:** merges the LoRA delta into model + CLIP at the given strengths during the pass.
- **strengths:** stackable (link several), negative strength to subtract a style, separate model / clip control.
- **bugs / lags + fixes:** none known. A LoRA trained on a different base silently degrades output rather than erroring.
- **anti-patterns:** wrong base (an SD1.5 LoRA on SDXL); for UNet-only models use `LoraLoaderModelOnly`.
- **placement:** between CheckpointLoaderSimple and KSampler / CLIPTextEncode. Insert, do not branch around.

### CLIPTextEncode  (display: "CLIP Text Encode (Prompt)")
- **pack / source:** core ComfyUI (`nodes`) | **category:** `model/conditioning` | **I/O confirmed:** 2026-06-30
- **purpose:** turn a text prompt into CONDITIONING that steers the sampler. Used twice: positive and negative.
- **inputs:**
  - `text` (STRING, multiline) - the prompt.
  - `clip` (CLIP) - from the checkpoint (or LoraLoader).
- **outputs:** `CONDITIONING` - feeds KSampler.positive or .negative.
- **how it works:** encodes the text through CLIP into an embedding the UNet is conditioned on.
- **strengths:** the universal SD1.5 / SDXL prompt node; cheap; supports weighting like `(word:1.2)`.
- **bugs / lags + fixes:** none. An empty negative is fine (encode an empty string).
- **anti-patterns:** do not use the base node for models with their own encoder: Flux -> `CLIPTextEncodeFlux` (has `guidance` + t5), SD3 -> `CLIPTextEncodeSD3`, SDXL split -> `CLIPTextEncodeSDXL`, HiDream / Lumina2 / PixArt have their own. Base node on those loses model-specific conditioning.
- **placement:** after the CLIP source, before KSampler. Two instances per graph (pos + neg).

### EmptyLatentImage  (display: "Empty Latent Image")
- **pack / source:** core ComfyUI (`nodes`) | **category:** `model/latent` | **I/O confirmed:** 2026-06-30
- **purpose:** create the blank latent canvas the sampler denoises (this sets the output resolution).
- **inputs:**
  - `width` / `height` (INT, default 512, step 8) - pixel size. SDXL is happiest at 1024-area (e.g. 1024x1024, 832x1216).
  - `batch_size` (INT, default 1) - images per run.
- **outputs:** `LATENT` - feeds KSampler.latent_image.
- **how it works:** allocates an empty latent tensor of the right shape; nothing to denoise from yet.
- **strengths:** the txt2img starting point; batch in one node.
- **bugs / lags + fixes:** none.
- **anti-patterns:** for img2img / inpaint you do NOT use this; encode a real image with `VAEEncode` (or `VAEEncodeForInpaint`) instead. Non-native resolutions (e.g. 512 on SDXL) give duplicated / warped subjects.
- **placement:** a leaf feeding only KSampler.latent_image.

### KSampler  (display: "KSampler")
- **pack / source:** core ComfyUI (`nodes`) | **category:** `model/sampling` | **I/O confirmed:** 2026-06-30
- **purpose:** the denoiser. Turns the latent + prompts into a finished latent image.
- **inputs:**
  - `model` (MODEL), `positive` / `negative` (CONDITIONING), `latent_image` (LATENT) - the wiring above.
  - `seed` (INT) - noise seed (`control_after_generate` randomizes per run).
  - `steps` (INT, default 20) - denoise iterations.
  - `cfg` (FLOAT, default 8) - prompt adherence vs freedom. SDXL ~6-8.
  - `sampler_name` (combo) - 40+ options incl. `euler`, `dpmpp_2m`, `dpmpp_2m_sde`, `dpmpp_3m_sde`, `lcm`, `uni_pc`, `ddim`, `res_multistep`.
  - `scheduler` (combo) - `simple`, `karras`, `sgm_uniform`, `exponential`, `beta`, `normal`, `ddim_uniform`, `linear_quadratic`, `kl_optimal`.
  - `denoise` (FLOAT, default 1) - 1.0 for txt2img; <1.0 for img2img (keeps input structure).
- **outputs:** `LATENT` - the denoised latent, feeds VAEDecode.samples.
- **how it works:** runs the chosen sampler/scheduler for `steps`, guided by cfg and the conditioning, from the seeded noise.
- **strengths:** one node covers the whole sampling space; sane defaults; img2img by lowering denoise.
- **bugs / lags + fixes:** none in the node. Wrong cfg is the usual "bad output" cause (see anti-patterns).
- **anti-patterns:** high `cfg` (8) on distilled / turbo / lightning / lcm models burns the image; those want cfg ~1-2 and few steps. Flux uses `guidance` on its encoder, so cfg ~1 there. For staged base+refiner, use `KSamplerAdvanced` (exposes `start_at_step` / `end_at_step` / `return_with_leftover_noise`).
- **placement:** the engine, between conditioning/latent and VAEDecode.

### VAEDecode  (display: "VAE Decode")
- **pack / source:** core ComfyUI (`nodes`) | **category:** `model/latent` | **I/O confirmed:** 2026-06-30
- **purpose:** convert the sampled latent back to a viewable pixel image.
- **inputs:**
  - `samples` (LATENT) - from KSampler.
  - `vae` (VAE) - from the checkpoint (or a standalone `VAELoader`).
- **outputs:** `IMAGE` - feeds SaveImage / PreviewImage / any IMAGE consumer.
- **how it works:** runs the latent through the VAE decoder to RGB.
- **strengths:** simple, fast for normal sizes.
- **bugs / lags + fixes:** big images on low VRAM OOM here -> use `VAEDecodeTiled` (tile_size 512, overlap 64). Video loop seams -> `VAEDecodeLoopKJ` (KJNodes). The VAE round-trip adds a slight color shift; see `docs/ADVANCED.md`.
- **anti-patterns:** mismatched VAE (e.g. an SDXL VAE on an SD1.5 latent) gives washed / shifted color.
- **placement:** between KSampler and the output node.

### SaveImage  (display: "Save Image")
- **pack / source:** core ComfyUI (`nodes`) | **category:** `image` | **I/O confirmed:** 2026-06-30
- **purpose:** write the final image(s) to the ComfyUI output dir. This is an output (terminal) node.
- **inputs:**
  - `images` (IMAGE) - from VAEDecode.
  - `filename_prefix` (STRING, default "ComfyUI") - supports tokens like `%date:yyyy-MM-dd%` and `%Empty Latent Image.width%`.
- **outputs:** none (output_node: writes a PNG, returns nothing to the graph).
- **how it works:** saves 8-bit sRGB PNG with the workflow embedded in metadata.
- **strengths:** the default sink; round-trips the workflow inside the PNG.
- **bugs / lags + fixes:** none.
- **anti-patterns:** need HDR / linear / 16-bit / EXR? `SaveImage` only does 8-bit sRGB PNG. Use `SaveImageAdvanced` (confirmed 2026-06-30: PNG 8 or 16-bit, EXR 32-bit float, `input_color_space` sRGB / HDR / linear, EXR always written scene-linear). See `color-and-transform.md`. Use `PreviewImage` for throwaway previews.
- **placement:** the leaf at the end of the graph.
