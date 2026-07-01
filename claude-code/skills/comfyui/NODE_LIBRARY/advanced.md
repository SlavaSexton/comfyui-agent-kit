# Advanced

The `advanced/...` menu family: the nodes you reach for once the seven-node core graph (see `core.md`) is not enough. Three jobs dominate here. First, model-only loaders for the newer architectures whose checkpoints ship as separate UNet + text-encoder + VAE files instead of one all-in-one checkpoint (UNETLoader, CLIPLoader, DualCLIPLoader, QuadrupleCLIPLoader, and friends). Second, MODEL patches that change how the diffusion model is sampled or guided without retraining it (the `ModelSampling*` shift nodes, the CFG-guidance patches, EasyCache). Third, conditioning helpers for edit and Flux-class models (CLIPTextEncodeFlux, FluxGuidance, ReferenceLatent, ConditioningZeroOut). All I/O below is **confirmed via get_node_info: 2026-06-30** (ComfyUI 0.25.1) from the provided pull; the semantics, placement, strengths, and gotchas are the curated layer. Any input typed `COMBO[...]` of file names is one machine's installed files, so it is described as "a dropdown of installed `<thing>` files", never hardcoded. The core seven nodes (`CheckpointLoaderSimple`, `LoraLoader`, `CLIPTextEncode`, `EmptyLatentImage`, `KSampler`, `VAEDecode`, `SaveImage`) are documented in `core.md` and are not repeated here.

---

### UNETLoader  (display: "Load Diffusion Model")
- **pack / source:** core ComfyUI (`nodes`) | **category:** `advanced/loaders` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** load a standalone diffusion model (the UNet / DiT weights only) for architectures that ship the diffusion model as its own file, separate from the text encoder and VAE (Flux, SD3, Qwen-Image, Wan, Z-Image, Ideogram, and most recent models).
- **inputs:**
  - `unet_name` (`COMBO[...]`) - a dropdown of installed diffusion-model files (read from `models/unet` / `models/diffusion_models`). Empty dropdown = none found; check the folder and `extra_model_paths.yaml`. This file carries no CLIP and no VAE; you load those separately.
  - `weight_dtype` (`COMBO[...]`) - the compute / storage dtype to load the weights at. `default` keeps the file's native precision; the `fp8_e4m3fn`, `fp8_e4m3fn_fast`, and `fp8_e5m2` options quantize to 8-bit float to cut VRAM, at some quality cost. `fp8_e4m3fn_fast` trades a little more accuracy for speed on hardware with fast fp8 paths.
- **outputs:**
  - `MODEL` (`MODEL`) - the diffusion model; feeds the sampler (often through a `ModelSampling*` shift patch and/or a `LoraLoaderModelOnly` first).
- **how it works:** reads the diffusion-model weights and returns a `MODEL` object, applying the chosen `weight_dtype` cast on load. Unlike `CheckpointLoaderSimple` it returns only the diffusion model; you must supply CLIP (via `CLIPLoader` / `DualCLIPLoader` / `QuadrupleCLIPLoader`) and VAE (via `VAELoader`) on parallel branches.
- **strengths:** the standard root for every modern UNet-only / DiT model; the `weight_dtype` picker makes fp8 quantization a one-click VRAM saving without a separate node.
- **bugs / lags + fixes:** none known in the node. fp8 dtypes save memory but can slightly degrade output; if quality matters more than VRAM, load at `default`.
- **anti-patterns:** expecting CLIP or VAE out of this node; it gives neither. Pairing it with the wrong text encoder for the architecture (Flux wants clip-l + t5 via `DualCLIPLoader`; see the recipe in each loader's description). Loading an all-in-one SD1.5 / SDXL checkpoint here instead of through `CheckpointLoaderSimple`.
- **placement:** the root of a UNet-only graph. Nothing feeds it; it feeds the sampler, in parallel with the CLIP loader chain and the VAE loader. A `ModelSamplingFlux` / `ModelSamplingSD3` / `ModelSamplingAuraFlow` patch commonly sits right after it on the MODEL line.

### CLIPLoader  (display: "Load CLIP")
- **pack / source:** core ComfyUI (`nodes`) | **category:** `advanced/loaders` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** load a single standalone text encoder for models that use one text encoder, when you are not loading it from an all-in-one checkpoint (the case for many UNet-only diffusion models).
- **inputs:**
  - `clip_name` (`COMBO[...]`) - a dropdown of installed text-encoder files (read from `models/clip` / `models/text_encoders`). Empty dropdown = none found; check the folder and `extra_model_paths.yaml`.
  - `type` (`COMBO[...]`) - which text-encoder family / loading mode to use. This MUST match the model you are encoding for; the node's description carries a recipe table (for example `wan` uses umt5 xxl, `lumina2` uses gemma 2 2B, `cosmos` uses an older t5 xxl, `lens` uses gpt-oss-20b). Picking the wrong `type` for a file mis-loads the encoder and the conditioning will not steer correctly.
  - `device` (`COMBO[...]`, optional) - where to place the encoder (`default` or `cpu`). Use `cpu` to keep the text encoder off the GPU and save VRAM for the diffusion model, at the cost of slower encoding.
- **outputs:**
  - `CLIP` (`CLIP`) - the text encoder; feeds `CLIPTextEncode` (or a model-specific encoder such as `CLIPTextEncodeFlux`).
- **how it works:** loads the text-encoder weights under the rules of the chosen `type` and returns a `CLIP` object. For single-encoder models this replaces the `CLIP` you would otherwise get from a checkpoint.
- **strengths:** the single-encoder loader for the modern split-file models; the `type` recipe in the description tells you exactly which encoder each model family wants; `device cpu` is a clean VRAM-offload lever.
- **bugs / lags + fixes:** none known in the node. The recurring trap is a `type` that does not match the loaded file, which mis-loads silently.
- **anti-patterns:** using it for a model that needs two or more encoders (Flux, SDXL-split, HiDream); those need `DualCLIPLoader` or `QuadrupleCLIPLoader`. Choosing a `type` that does not match the encoder file. Treating the output as a vision encoder; this is the text side, it does not plug into image-conditioning nodes.
- **placement:** a leaf on the conditioning branch. Nothing feeds it; it feeds the text-encode node, in parallel with `UNETLoader` and `VAELoader`.

### DualCLIPLoader  (display: "DualCLIPLoader")
- **pack / source:** core ComfyUI (`nodes`) | **category:** `advanced/loaders` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** load two text encoders together for models that condition on a pair (the common case is Flux: clip-l + t5; also SDXL-split, SD3, HiDream, several others).
- **inputs:**
  - `clip_name1` (`COMBO[...]`) - a dropdown of installed text-encoder files; the first of the pair.
  - `clip_name2` (`COMBO[...]`) - a dropdown of installed text-encoder files; the second of the pair.
  - `type` (`COMBO[...]`) - which two-encoder recipe to apply. Must match the model; the node's description lists the pairings (for example `flux` uses clip-l + t5, `sdxl` uses clip-l + clip-g, `hunyuan_image` uses qwen2.5vl 7b + byt5 small). The two `clip_name` slots are not interchangeable for every recipe; follow the order the recipe implies.
  - `device` (`COMBO[...]`, optional) - `default` or `cpu`; `cpu` offloads both encoders to save VRAM.
- **outputs:**
  - `CLIP` (`CLIP`) - a single combined `CLIP` object wrapping both encoders; feeds `CLIPTextEncode` or a model-specific encoder (Flux pairs with `CLIPTextEncodeFlux`, which exposes separate `clip_l` and `t5xxl` text boxes).
- **how it works:** loads both encoder files under the chosen `type` recipe and returns one `CLIP` object that downstream encode nodes treat as the model's text encoder.
- **strengths:** the standard two-encoder loader for Flux and SDXL-split graphs; the recipe table in the description removes the guesswork about which two files and in which roles.
- **bugs / lags + fixes:** none known in the node. Wrong `type`, or the two files swapped against the recipe, mis-loads the encoders.
- **anti-patterns:** using it for a single-encoder model (use `CLIPLoader`) or a four-encoder model (use `QuadrupleCLIPLoader`). Mismatching `type` to the files. Feeding its `CLIP` into a base `CLIPTextEncode` for Flux and losing the t5 guidance path; pair it with `CLIPTextEncodeFlux` instead.
- **placement:** a leaf on the conditioning branch, in parallel with `UNETLoader` and `VAELoader`; feeds the text-encode node ahead of the sampler.

### QuadrupleCLIPLoader  (display: "QuadrupleCLIPLoader")
- **pack / source:** core ComfyUI (`nodes`) | **category:** `advanced/loaders` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** load four text encoders together for models that condition on four (the documented case is HiDream: long clip-l, long clip-g, t5xxl, llama_8b_3.1_instruct).
- **inputs:**
  - `clip_name1` (`COMBO`) - a dropdown of installed text-encoder files; first of the four.
  - `clip_name2` (`COMBO`) - a dropdown of installed text-encoder files; second of the four.
  - `clip_name3` (`COMBO`) - a dropdown of installed text-encoder files; third of the four.
  - `clip_name4` (`COMBO`) - a dropdown of installed text-encoder files; fourth of the four. The four slots map to specific roles in the model's recipe (see the HiDream recipe in the description); they are not interchangeable.
- **outputs:**
  - `CLIP` (`CLIP`) - one combined `CLIP` object wrapping all four encoders; feeds the matching text-encode node.
- **how it works:** loads four encoder files and returns a single `CLIP` object the downstream encoder treats as the model's full text-conditioning stack.
- **strengths:** the only loader that assembles a four-encoder stack in one node; the description spells out the HiDream slot order.
- **bugs / lags + fixes:** none known in the node. Four encoders is heavy on VRAM and load time; budget for it.
- **anti-patterns:** using it for models that need fewer encoders (use `CLIPLoader` or `DualCLIPLoader`). Putting the four files in the wrong slots against the recipe. Note this node exposes no `type` selector in the pull, unlike `CLIPLoader` / `DualCLIPLoader`; the role mapping is positional, so slot order is the only control you have.
- **placement:** a leaf on the conditioning branch, in parallel with the diffusion-model loader and VAE loader; feeds the text-encode node before the sampler.

### CLIPTextEncodeFlux  (display: "CLIPTextEncodeFlux")
- **pack / source:** core ComfyUI (`comfy_extras`, Flux conditioning) | **category:** `advanced/conditioning/flux` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** the Flux-family prompt node. Encodes a prompt through Flux's dual encoders (clip-l + t5xxl) and bakes in the Flux `guidance` value, producing CONDITIONING shaped for Flux models.
- **inputs:**
  - `clip` (`CLIP`) - the combined Flux text encoder, from `DualCLIPLoader` (type `flux`).
  - `clip_l` (`STRING`) - the prompt text routed to the clip-l encoder. Flux workflows often put the same prompt in both boxes, or a shorter tag-style prompt here and a fuller natural-language prompt in `t5xxl`.
  - `t5xxl` (`STRING`) - the prompt text routed to the t5xxl encoder; t5 handles longer, more natural-language descriptions well.
  - `guidance` (`FLOAT`, default 3.5) - the Flux distilled-guidance value embedded into the conditioning. Flux is a guidance-distilled model, so this replaces the sampler's CFG; typical range is roughly 2.5 to 4.0 for Flux dev.
- **outputs:**
  - `CONDITIONING` (`CONDITIONING`) - Flux-shaped positive conditioning; feeds `KSampler.positive` (or an advanced sampler). For Flux the negative is usually a zeroed conditioning (see `ConditioningZeroOut`) since CFG is not used.
- **how it works:** encodes `clip_l` and `t5xxl` through the two Flux encoders and attaches the `guidance` scalar to the resulting conditioning, so Flux's guidance-embedding mechanism reads it during sampling.
- **strengths:** the correct prompt node for Flux; exposes the two prompt boxes and the guidance value in one place, matching how Flux actually conditions.
- **bugs / lags + fixes:** none known in the node. Note `guidance` here and a separate `FluxGuidance` node both set the same Flux guidance value; use one path, not both stacked, to avoid confusion about which value wins.
- **anti-patterns:** using the base `CLIPTextEncode` for Flux (loses the guidance embedding and the dual-prompt structure). Setting `guidance` here AND adding a `FluxGuidance` node on the same conditioning (redundant; pick one). Feeding a non-Flux `CLIP` into it.
- **placement:** on the conditioning branch, after `DualCLIPLoader`, before the sampler. The positive instance feeds `KSampler.positive`; pair with a zeroed negative.

### FluxGuidance  (display: "FluxGuidance")
- **pack / source:** core ComfyUI (`comfy_extras`, Flux conditioning) | **category:** `advanced/conditioning/flux` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** set or override the Flux distilled-guidance value on an existing CONDITIONING, without re-encoding the prompt.
- **inputs:**
  - `conditioning` (`CONDITIONING`) - the conditioning to stamp the guidance value onto (typically the positive prompt's conditioning).
  - `guidance` (`FLOAT`, default 3.5) - the Flux guidance value to embed. Same meaning as the `guidance` field on `CLIPTextEncodeFlux`; roughly 2.5 to 4.0 for Flux dev, higher for stronger prompt adherence at the cost of variety.
- **outputs:**
  - `CONDITIONING` (`CONDITIONING`) - the same conditioning with the guidance value attached; feeds the sampler's positive input.
- **how it works:** attaches the guidance scalar to the conditioning so Flux's guidance-embedding path reads it during sampling. It does not encode text; it only stamps the value.
- **strengths:** lets you tune Flux guidance with a plain `CLIPTextEncode` (or any conditioning source) instead of switching to `CLIPTextEncodeFlux`; quick to A/B different guidance values by editing one field.
- **bugs / lags + fixes:** none known in the node.
- **anti-patterns:** stacking it on conditioning that already carries a guidance value from `CLIPTextEncodeFlux` (pick one source of truth). Applying it to a non-Flux model's conditioning, where the value is ignored. Putting it on the negative conditioning for a model that does not use a real negative.
- **placement:** inline on the positive conditioning path, between the text-encode node and the sampler.

### FluxKontextImageScale  (display: "FluxKontextImageScale")
- **pack / source:** core ComfyUI (`comfy_extras`, Flux conditioning) | **category:** `advanced/conditioning/flux` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** resize an input image to a resolution Flux Kontext (the Flux edit / reference model) prefers, so the reference image is at an aspect ratio and size the model handles well. The node's own description: "resizes the image to one that is more optimal for flux kontext".
- **inputs:**
  - `image` (`IMAGE`) - the reference / input image to rescale for Flux Kontext.
- **outputs:**
  - `IMAGE` (`IMAGE`) - the rescaled image, ready to be VAE-encoded into a reference latent (see `ReferenceLatent`) or otherwise fed into the Kontext conditioning path.
- **how it works:** picks a Kontext-friendly target resolution from the image's aspect ratio and resizes to it. It only resizes; it does no encoding or conditioning itself.
- **strengths:** removes the guesswork of choosing a Kontext-safe resolution; one node, no parameters to tune.
- **bugs / lags + fixes:** none known in the node.
- **anti-patterns:** using it as a general-purpose resize for non-Kontext workflows (it targets Kontext's preferred sizes specifically; for arbitrary resizing use a general image-scale node). Expecting it to encode or condition; it only outputs a resized `IMAGE`.
- **placement:** early on the reference-image branch of a Flux Kontext graph, before the VAE-encode / `ReferenceLatent` step that turns the image into guiding conditioning.

### ReferenceLatent  (display: "ReferenceLatent")
- **pack / source:** core ComfyUI (`comfy_extras`, edit-model conditioning) | **category:** `advanced/conditioning/edit_models` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** attach a guiding reference latent to conditioning for an edit model, so the model edits / continues from a given image. The node's description: "sets the guiding latent for an edit model. If the model supports it you can chain multiple to set multiple reference images."
- **inputs:**
  - `conditioning` (`CONDITIONING`) - the conditioning to attach the reference latent to (typically the positive prompt's conditioning).
  - `latent` (`LATENT`, optional) - the reference image encoded to latent (via `VAEEncode`). This is the image the edit model uses as its guide. Optional in the schema, but supplying it is the point of the node; chain multiple `ReferenceLatent` nodes to set several reference images on models that support it.
- **outputs:**
  - `CONDITIONING` (`CONDITIONING`) - the conditioning carrying the reference latent; feeds the sampler's positive input.
- **how it works:** stores the reference latent inside the conditioning so the edit model reads it as its guiding image during sampling. Chaining nodes adds more reference latents for multi-reference edit models.
- **strengths:** the clean way to give an edit / reference model its source image through the conditioning path; chainable for multi-image references.
- **bugs / lags + fixes:** none known in the node. Behavior with multiple chained references depends on whether the specific model supports more than one; confirm against the model's docs rather than assuming.
- **anti-patterns:** using it with a model that is not an edit / reference model (it has nothing to do with the reference latent). Feeding a pixel `IMAGE` directly into `latent`; it expects a `LATENT`, so `VAEEncode` the image first. Chaining several references into a model that only honors one.
- **placement:** on the positive conditioning path of an edit-model graph, after the text encoder and after the reference image has been VAE-encoded to latent; feeds the sampler.

### ConditioningZeroOut  (display: "ConditioningZeroOut")
- **pack / source:** core ComfyUI (`nodes`) | **category:** `advanced/conditioning` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** produce a zeroed (empty) conditioning of the right shape, most often used as the negative for guidance-distilled models (Flux, some edit models) that do not use a real text negative.
- **inputs:**
  - `conditioning` (`CONDITIONING`) - an existing conditioning whose shape / structure is copied; the values are zeroed out. Wire your positive (or any same-shape) conditioning in so the zeroed result matches it structurally.
- **outputs:**
  - `CONDITIONING` (`CONDITIONING`) - a structurally-matching conditioning with zeroed content; feeds `KSampler.negative` (or the negative slot of an advanced sampler).
- **how it works:** copies the input conditioning's tensor shape and metadata but zeroes the embedding, giving a valid "empty" negative without encoding an empty prompt through CLIP.
- **strengths:** the standard negative for Flux and other models where you do not want a real negative prompt but the sampler still needs something wired into `negative`; cheaper and cleaner than encoding an empty string.
- **bugs / lags + fixes:** none known in the node.
- **anti-patterns:** using it as the negative for a normal CFG model (SD1.5 / SDXL) where a real negative prompt is useful; there, encode an actual negative with `CLIPTextEncode`. Wiring a different-shaped conditioning in as the template, which can mismatch the positive.
- **placement:** a small inline node feeding `KSampler.negative`, fed by (a copy of) the positive conditioning so the shapes match.

### ModelSamplingFlux  (display: "ModelSamplingFlux")
- **pack / source:** core ComfyUI (`comfy_extras`, model sampling) | **category:** `advanced/model` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** patch a Flux MODEL with the resolution-aware timestep shift Flux expects, so the noise schedule matches the image size. Without it Flux outputs are typically soft or mis-exposed.
- **inputs:**
  - `model` (`MODEL`) - the Flux diffusion model to patch (from `UNETLoader`).
  - `max_shift` (`FLOAT`, default 1.15) - the upper end of the timestep shift, applied toward larger resolutions.
  - `base_shift` (`FLOAT`, default 0.5) - the baseline shift at the reference resolution.
  - `width` (`INT`, default 1024) - the target width the shift is computed for; set it to match the resolution you are generating at.
  - `height` (`INT`, default 1024) - the target height the shift is computed for; match your generation resolution.
- **outputs:**
  - `MODEL` (`MODEL`) - the patched Flux model with the shifted sampling schedule; feeds the sampler.
- **how it works:** it is a non-destructive MODEL patch. It computes a sigma / timestep shift from `base_shift`, `max_shift`, and the `width` x `height` you give, so larger images get a larger shift, then wraps the model so the sampler uses that schedule.
- **strengths:** the correct sampling patch for Flux; the per-resolution shift is what keeps Flux sharp across sizes.
- **bugs / lags + fixes:** none known in the node. If `width` / `height` here do not match the actual latent size, the shift is computed for the wrong resolution and quality drops; keep them in sync with the canvas.
- **anti-patterns:** using it on a non-Flux model (the shift math is Flux-specific; SD3 uses `ModelSamplingSD3`, AuraFlow uses `ModelSamplingAuraFlow`). Leaving `width` / `height` at defaults when generating a very different resolution. Stacking more than one `ModelSampling*` patch on the same line.
- **placement:** inline on the MODEL line, right after `UNETLoader` and before the sampler (and before any LoRA model patch, or after it, but as the sampling-schedule patch it belongs on the MODEL line into the sampler).

### ModelSamplingSD3  (display: "ModelSamplingSD3")
- **pack / source:** core ComfyUI (`comfy_extras`, model sampling) | **category:** `advanced/model` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** patch an SD3-style (flow-matching) MODEL with a single timestep `shift` value, tuning where on the noise schedule the model spends its steps. Also used for several other flow-matching models that take a single shift.
- **inputs:**
  - `model` (`MODEL`) - the diffusion model to patch.
  - `shift` (`FLOAT`, default 3.0) - the timestep shift. Higher shift moves emphasis toward earlier (noisier) steps; it is the main quality / structure knob for SD3-class flow models. The default 3.0 is the common SD3 starting point.
- **outputs:**
  - `MODEL` (`MODEL`) - the patched model with the shifted schedule; feeds the sampler.
- **how it works:** a non-destructive MODEL patch that applies a single-parameter sigma shift to the flow-matching schedule, unlike the resolution-aware `ModelSamplingFlux`.
- **strengths:** one knob, easy to tune; the right sampling patch for SD3 and similar single-shift flow models.
- **bugs / lags + fixes:** none known in the node.
- **anti-patterns:** using it on Flux (use `ModelSamplingFlux` for the resolution-aware shift) or on epsilon / v-prediction SD1.5 / SDXL models (they do not use this flow shift). Stacking it with another `ModelSampling*` patch.
- **placement:** inline on the MODEL line, after the diffusion-model loader, before the sampler.

### ModelSamplingAuraFlow  (display: "ModelSamplingAuraFlow")
- **pack / source:** core ComfyUI (`comfy_extras`, model sampling) | **category:** `advanced/model` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** patch an AuraFlow-style MODEL with a single timestep `shift`, the AuraFlow-tuned counterpart to `ModelSamplingSD3`.
- **inputs:**
  - `model` (`MODEL`) - the diffusion model to patch.
  - `shift` (`FLOAT`, default 1.73) - the timestep shift for the AuraFlow schedule. The default 1.73 reflects AuraFlow's tuning, which differs from SD3's default.
- **outputs:**
  - `MODEL` (`MODEL`) - the patched model with the shifted schedule; feeds the sampler.
- **how it works:** a non-destructive MODEL patch applying a single-parameter shift to the flow schedule, with the default tuned for AuraFlow rather than SD3.
- **strengths:** the correct single-shift sampling patch for the AuraFlow family; one knob.
- **bugs / lags + fixes:** none known in the node.
- **anti-patterns:** using it on Flux or SD3 instead of their own sampling nodes (the defaults and intended schedule differ). Stacking multiple `ModelSampling*` patches.
- **placement:** inline on the MODEL line, after the loader, before the sampler.

### ModelNoiseScale  (display: "ModelNoiseScale")
- **pack / source:** core ComfyUI (`comfy_extras`, model sampling) | **category:** `advanced/model` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** set the model's absolute training noise scale, for models that were trained with a specific noise scale and need it stated at sampling time (the node's note cites HiDream-O1 base 8.0, dev 7.5).
- **inputs:**
  - `model` (`MODEL`) - the diffusion model to patch.
  - `noise_scale` (`FLOAT`) - the absolute training noise scale to apply. The note gives concrete values (HiDream-O1 base: 8.0, dev: 7.5); use the value the model was trained with, not a guessed one.
- **outputs:**
  - `MODEL` (`MODEL`) - the patched model carrying the stated noise scale; feeds the sampler.
- **how it works:** a non-destructive MODEL patch that sets the absolute noise scale the sampler uses, matching what the model saw in training.
- **strengths:** the way to feed a model its correct training noise scale when that scale is not the default; small, targeted patch.
- **bugs / lags + fixes:** none known in the node. The right `noise_scale` is model-specific; the correct value comes from the model's documentation, and a wrong value mis-scales the noise.
- **anti-patterns:** guessing `noise_scale` instead of using the model's documented value. Applying it to a model that does not need an explicit noise scale. Stacking it carelessly with other sampling patches without knowing how they interact.
- **placement:** inline on the MODEL line, after the loader, before the sampler; commonly alongside the model's other required patches in the HiDream-O1 path.

### HiDreamO1PatchSeamSmoothing  (display: "HiDreamO1PatchSeamSmoothing")
- **pack / source:** core ComfyUI (`comfy_extras`) | **category:** `advanced/model` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** cancel patch-grid seams in HiDream-O1 output by averaging the model's prediction across several shifted patch-grid positions during the late part of sampling. The node's description: "Average the model output across multiple shifted patch-grid positions during the late portion of sampling. Cancels seams."
- **inputs:**
  - `model` (`MODEL`) - the HiDream-O1 model to patch.
  - `start_percent` (`FLOAT`) - sampling progress (0 = start, 1 = end) at which the seam-blend turns ON. Because the blend targets the late portion, this is usually set well into the run.
  - `end_percent` (`FLOAT`) - sampling progress at which the blend turns OFF.
  - `pattern` (`COMBO`) - the shift layout. Per the note, `single_shift` does one pass at the natural patch grid plus others offset; `symmetric` puts all passes off-grid with shifts split around the origin.
  - `passes` (`COMBO`) - number of passes per gated step. Per the note, `2` / `4` are fixed counts; the `ramp_*` options increase the pass count as sampling approaches the end, putting more smoothing where seams are most visible.
  - `blend` (`COMBO`) - how the passes are combined. Per the note: `average` is an equal-weight mean; `window` is a Hann-windowed weighting favoring each pass away from its patch boundaries; `median` is a per-pixel median that rejects wraparound outliers.
  - `strength` (`FLOAT`) - interpolation between the natural-grid prediction (0) and the averaged result (1).
- **outputs:**
  - `MODEL` (`MODEL`) - the patched model that performs the seam-smoothing blend during sampling; feeds the sampler.
- **how it works:** a non-destructive MODEL patch. During the gated window (`start_percent` to `end_percent`) it runs several predictions at shifted patch-grid offsets (controlled by `pattern` and `passes`), combines them by the chosen `blend`, and mixes the combined result toward the natural-grid prediction by `strength`. More passes plus shifted grids average away the seams that a fixed patch grid leaves.
- **strengths:** a targeted fix for HiDream-O1 patch seams; the `ramp_*` pass schedules and `median` blend give control over cost versus seam rejection.
- **bugs / lags + fixes:** none known in the node. Each extra pass re-runs the model on that step, so more passes (or a `ramp_*` schedule) cost proportionally more time in the gated window; keep the window late and the pass count to what the seams actually need.
- **anti-patterns:** using it on a model that is not HiDream-O1 (it is built for that patch structure). Setting a very wide gated window with high pass counts and paying a large time cost for little gain. Turning the blend on across the whole run rather than the late portion it targets.
- **placement:** inline on the HiDream-O1 MODEL line, after the loader and the model's other required patches (such as `ModelNoiseScale`), before the sampler.

### SkipLayerGuidanceDiT  (display: "SkipLayerGuidanceDiT")
- **pack / source:** core ComfyUI (`comfy_extras`) | **category:** `advanced/guidance` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** apply Skip-Layer Guidance (SLG) to any DiT (transformer) model: during part of sampling, a second prediction is run with certain transformer layers skipped, and the difference sharpens detail and structure. The description calls it the "Generic version of SkipLayerGuidance node that can be used on every DiT model".
- **inputs:**
  - `model` (`MODEL`) - the DiT model to patch.
  - `double_layers` (`STRING`, default "7, 8, 9") - comma-separated indices of the double-stream transformer blocks to skip in the guidance pass. Which indices help is model-specific.
  - `single_layers` (`STRING`, default "7, 8, 9") - comma-separated indices of the single-stream transformer blocks to skip in the guidance pass.
  - `scale` (`FLOAT`, default 3.0) - how strongly the skip-layer difference is applied; the main SLG strength knob.
  - `start_percent` (`FLOAT`, default 0.01) - sampling progress at which SLG turns ON.
  - `end_percent` (`FLOAT`, default 0.15) - sampling progress at which SLG turns OFF. The default window (0.01 to 0.15) keeps SLG to the early part of sampling.
  - `rescaling_scale` (`FLOAT`, default 0.0) - optional rescale of the guided result to counter over-amplification; 0.0 disables it.
- **outputs:**
  - `MODEL` (`MODEL`) - the patched model that runs the skip-layer guidance during the gated window; feeds the sampler.
- **how it works:** a non-destructive MODEL patch. Inside the `start_percent` to `end_percent` window it computes a second model prediction with the listed `double_layers` / `single_layers` skipped, then pushes the main prediction away from that degraded one by `scale` (optionally rescaled by `rescaling_scale`), which tends to add structure and detail.
- **strengths:** a general DiT detail / structure booster that works across transformer models; the layer lists and window make it tunable; `rescaling_scale` is there to tame overshoot.
- **bugs / lags + fixes:** none known in the node. Too high a `scale`, or skipping the wrong layers, can introduce artifacts; the useful layer indices differ by model, so the defaults are a starting point, not a guarantee.
- **anti-patterns:** applying it to a non-DiT (UNet) model where layer indices have no matching meaning. Cranking `scale` until artifacts appear. Running the window across the whole sampling range rather than the early portion the defaults target. Guessing layer indices for an unfamiliar model without checking what that model responds to.
- **placement:** inline on the MODEL line, after the loader (and any sampling-shift patch), before the sampler.

### CFGNorm  (display: "CFGNorm")
- **pack / source:** core ComfyUI (`comfy_extras`) | **category:** `advanced/guidance` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** rescale (normalize) the classifier-free-guidance result so high CFG does not blow out the prediction, keeping contrast and color in check. A norm-scaled CFG, matching the approach some models (the note cites Lens) use.
- **inputs:**
  - `model` (`MODEL`) - the diffusion model to patch.
  - `strength` (`FLOAT`, default 1.0) - how strongly the normalization is applied; 1.0 is full norm-scaling, lower values blend toward the un-normalized CFG.
  - `pre_cfg` (`BOOLEAN`, optional) - per the note: if true, rescale the combined noise BEFORE the sampler's CFG combine, without clamping (which can amplify). This matches the norm-scaled CFG used by models like Lens. If false (the default behavior implied), the rescale is applied after the CFG combine.
- **outputs:**
  - `patched_model` (`MODEL`) - the model patched to apply CFG normalization during sampling; feeds the sampler.
- **how it works:** a non-destructive MODEL patch on the guidance step. It normalizes the magnitude of the guided prediction toward the conditioned prediction's scale (controlled by `strength`), so raising CFG sharpens adherence without the over-saturation high CFG usually causes. `pre_cfg` chooses whether the rescale happens before or after the CFG combine.
- **strengths:** lets you push CFG higher for prompt adherence while holding back the burn / over-contrast; the `pre_cfg` option matches the exact scheme some models expect.
- **bugs / lags + fixes:** none known in the node. The note flags that `pre_cfg` true rescales without clamping and "can amplify"; if you see over-amplification with `pre_cfg` on, that is expected behavior, lower `strength` or turn `pre_cfg` off.
- **anti-patterns:** stacking it with `CFGZeroStar` or other CFG patches without understanding how the combined rescales interact. Using it on a guidance-distilled model that does not run real CFG (Flux), where there is no CFG step to normalize. Leaving `strength` at 1.0 with `pre_cfg` on for a model that over-amplifies.
- **placement:** inline on the MODEL line, after the loader, before the sampler; it changes the model's guidance behavior, so it sits on the MODEL path into the sampler.

### CFGZeroStar  (display: "CFGZeroStar")
- **pack / source:** core ComfyUI (`comfy_extras`) | **category:** `advanced/guidance` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** apply the "CFG-Zero-Star" guidance patch, which improves classifier-free guidance (the technique zeroes / re-projects the guidance contribution in a way that reduces over-saturation and artifacts) with no parameters to tune.
- **inputs:**
  - `model` (`MODEL`) - the diffusion model to patch. This is the node's only input; the method has no exposed knobs in this pull.
- **outputs:**
  - `patched_model` (`MODEL`) - the model patched with the CFG-Zero-Star guidance behavior; feeds the sampler.
- **how it works:** a non-destructive, parameter-free MODEL patch that modifies how the CFG result is formed during sampling (the published CFG-Zero-Star method re-scales / zero-projects the guidance term). Since it exposes no parameters, it is an on/off improvement: insert it or do not.
- **strengths:** zero-config; drop it on the MODEL line and it adjusts guidance with nothing to tune. Useful on models where standard CFG over-saturates.
- **bugs / lags + fixes:** none known in the node.
- **anti-patterns:** stacking it with `CFGNorm` or other CFG patches without checking how the two rescales compound. Using it on a model that does not run real CFG (a guidance-distilled model like Flux), where there is no CFG term for it to act on. Expecting a tunable strength; there is none here.
- **placement:** inline on the MODEL line, after the loader, before the sampler.

### EasyCache  (display: "EasyCache")
- **pack / source:** core ComfyUI (`comfy_extras`) | **category:** `advanced/debug/model` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** speed up sampling by reusing (caching) the model's output across steps when consecutive steps are similar enough, skipping recomputation. The description: "Native EasyCache implementation."
- **inputs:**
  - `model` (`MODEL`) - the model to add EasyCache to (per the note).
  - `reuse_threshold` (`FLOAT`) - the threshold for reusing cached steps (per the note). Lower threshold reuses more aggressively (faster, more risk of quality loss); higher threshold reuses less (safer, slower).
  - `start_percent` (`FLOAT`) - the relative sampling step at which EasyCache begins (per the note).
  - `end_percent` (`FLOAT`) - the relative sampling step at which EasyCache ends (per the note).
  - `verbose` (`BOOLEAN`) - whether to log verbose information about cache hits (per the note); useful while tuning the threshold.
- **outputs:**
  - `MODEL` (`MODEL`) - the model patched to cache and reuse step outputs during sampling; feeds the sampler.
- **how it works:** a non-destructive MODEL patch. During the `start_percent` to `end_percent` window it measures how much the prediction changes between steps and, when the change is under `reuse_threshold`, reuses the cached result instead of recomputing, trading a little accuracy for speed.
- **strengths:** a real inference speedup with one node and a single main knob (`reuse_threshold`); the percent window lets you keep caching out of the steps that matter most; `verbose` helps dial it in.
- **bugs / lags + fixes:** none known in the node. Too low a `reuse_threshold` reuses stale predictions and degrades the image; raise it (or narrow the window) if quality drops. Its category (`advanced/debug/model`) signals it is a performance / experimental tool, so verify output quality against an uncached run before trusting it.
- **anti-patterns:** setting `reuse_threshold` so low that visibly stale steps get reused. Caching across the full run including the early structure-forming steps. Assuming the speedup is free; confirm the cached result matches the uncached one for your model and settings.
- **placement:** inline on the MODEL line, after the loader (and any other model patches), before the sampler. Order against other MODEL patches matters; place it where it wraps the prediction you actually want to cache.

### ModelPatchLoader  (display: "ModelPatchLoader")
- **pack / source:** core ComfyUI (`nodes`) | **category:** `advanced/loaders` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** load a model-patch file (a separate weights file that modifies or augments a base model, for example a SUPIR patch or a Z-Image ControlNet-style patch) and hand it back as a `MODEL_PATCH` object for a consumer node to apply.
- **inputs:**
  - `name` (`COMBO[...]`) - a dropdown of installed model-patch files (read from the model-patch folder). Empty dropdown = none installed; check the folder and `extra_model_paths.yaml`.
- **outputs:**
  - `MODEL_PATCH` (`MODEL_PATCH`) - the loaded patch object; consumed by the node that applies it to a base model (for example `QwenImageDiffsynthControlnet` takes a `model_patch` input).
- **how it works:** reads the patch-weights file and returns a `MODEL_PATCH` object. It does not apply anything itself; the apply / consumer node combines the patch with a base `MODEL`.
- **strengths:** isolates the patch-file choice from the apply node; the standard loader for the `MODEL_PATCH` type.
- **bugs / lags + fixes:** none known in the node. The right consumer depends on what the patch is for (a SUPIR patch and a Z-Image ControlNet patch go to different apply nodes); confirm the consumer for your patch rather than assuming.
- **anti-patterns:** loading a patch that does not match the base model or the consumer node expecting it. Treating `MODEL_PATCH` as a `MODEL`; it is a patch, not a runnable diffusion model, and only the matching apply node accepts it.
- **placement:** a leaf feeding the model-patch input of an apply node (such as `QwenImageDiffsynthControlnet.model_patch`); sits parallel to the base-model loader.

### QwenImageDiffsynthControlnet  (display: "QwenImageDiffsynthControlnet")
- **pack / source:** core ComfyUI (`comfy_extras`, Qwen-Image) | **category:** `advanced/loaders/qwen` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** apply a DiffSynth-style ControlNet patch to a Qwen-Image model, steering generation by a control image (and optionally a mask). It takes the base model plus a loaded model-patch and returns the patched model ready to sample.
- **inputs:**
  - `model` (`MODEL`) - the base Qwen-Image diffusion model to steer.
  - `model_patch` (`MODEL_PATCH`) - the ControlNet patch weights, from `ModelPatchLoader`.
  - `vae` (`VAE`) - the VAE, used to encode the control image into the model's latent space.
  - `image` (`IMAGE`) - the control / hint image that drives the ControlNet guidance.
  - `strength` (`FLOAT`, default 1.0) - how strongly the ControlNet steers; lower values loosen the control's influence.
  - `mask` (`MASK`, optional) - an optional mask to restrict where the control applies.
- **outputs:**
  - `MODEL` (`MODEL`) - the Qwen-Image model with the DiffSynth ControlNet applied; feeds the sampler.
- **how it works:** encodes the control `image` through the `vae`, combines it with the `model_patch` weights and the base `model` at the given `strength` (optionally masked), and returns a patched `MODEL` whose sampling is steered by the control image. Despite the `advanced/loaders/qwen` category, it is an apply node: it consumes a `MODEL_PATCH`, it does not load one.
- **strengths:** the integrated way to bring a DiffSynth ControlNet into a Qwen-Image graph; `strength` and the optional `mask` give control over influence and region.
- **bugs / lags + fixes:** none known in the node. A control image not in the format the patch expects gives weak or wrong steering.
- **anti-patterns:** feeding a `model_patch` that is not the matching DiffSynth ControlNet for Qwen-Image. Using it on a non-Qwen-Image base model. Forgetting the `vae` is needed to encode the control image. Wiring a raw photo as `image` when the patch expects a specific control map.
- **placement:** on the MODEL line of a Qwen-Image graph. Fed by `UNETLoader` (base model), `ModelPatchLoader` (the patch), a VAE loader, and the control-image branch; its `MODEL` output feeds the sampler.

### LTXAVTextEncoderLoader  (display: "LTXAVTextEncoderLoader")
- **pack / source:** core ComfyUI (`comfy_extras`, LTX-Audio-Video) | **category:** `advanced/loaders` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** load the text encoder for the LTX audio-video (LTXAV) model family. The description's recipe: "ltxav: gemma 3 12B".
- **inputs:**
  - `text_encoder` (`COMBO`) - a dropdown of installed text-encoder files for LTXAV (the recipe points to a gemma 3 12B encoder).
  - `ckpt_name` (`COMBO`) - a dropdown of installed checkpoint files associated with the encoder load. The encoder load is tied to a checkpoint here; pick the LTXAV-matching entries.
  - `device` (`COMBO`) - where to place the encoder (for example `default` or `cpu`); `cpu` offloads to save VRAM.
- **outputs:**
  - `CLIP` (`CLIP`) - the LTXAV text encoder, returned as a `CLIP` object; feeds the text-encode node for the LTXAV pipeline.
- **how it works:** loads the LTXAV text encoder (per the recipe, a gemma-3-12B encoder) keyed to the chosen checkpoint and returns it as a `CLIP`. The exact roles of `text_encoder` versus `ckpt_name` are specific to the LTXAV loader; confirm against the LTXAV workflow rather than assuming a generic split.
- **strengths:** the dedicated text-encoder loader for the LTXAV family, with the recipe stated in the description so you know which encoder to install.
- **bugs / lags + fixes:** none known in the node. This is an LTXAV-specific loader; the precise meaning of its three combos and the downstream encode node come from the LTXAV pipeline, so verify with `get_node_info` and the LTXAV docs for that workflow.
- **anti-patterns:** using it as a generic CLIP loader for non-LTXAV models (use `CLIPLoader` / `DualCLIPLoader`). Mixing encoder and checkpoint entries that do not belong to the same LTXAV release.
- **placement:** a leaf on the conditioning branch of an LTXAV graph, feeding the text-encode node, in parallel with the model and VAE loaders.
