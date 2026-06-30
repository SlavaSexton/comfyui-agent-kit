# Loaders

The `model/loaders` family: nodes that read a file off disk and hand back one typed model object (a VAE, a LoRA-patched MODEL, an upscale model, a ControlNet, a CLIP vision encoder, a style model). They have no model inputs to wire (the file picker is a widget, not a port); they sit at the edges of a graph and feed the consumer that needs that object. Two of the most-used loaders, `CheckpointLoaderSimple` and `LoraLoader`, already have full entries in `core.md`; they get a one-line pointer here instead of a duplicate. All I/O below is **confirmed via get_node_info: 2026-06-30** (ComfyUI 0.25.1) from the provided pull; the semantics, placement, and gotchas are the curated layer. Any input typed `COMBO[...]` of file names is one machine's installed files, so it is described as "a dropdown of installed <thing> files", never hardcoded.

For model-specific text encoder and diffusion loaders (UNETLoader, DualCLIPLoader, CLIPLoader, and friends) that live in `advanced/loaders`, see the core chain and `MODELS.md`; this file covers the `model/loaders` set that came through in the loaders group.

---

### CheckpointLoaderSimple  (display: "Load Checkpoint")
- See the full entry in `core.md`. Loads one all-in-one checkpoint and splits it into `MODEL` / `CLIP` / `VAE`. The standard SD1.5 / SDXL root.

### LoraLoader  (display: "Load LoRA (Model and CLIP)")
- See the full entry in `core.md`. Applies a LoRA to BOTH the diffusion model and CLIP; stackable; strength can be negative.

---

### VAELoader  (display: "Load VAE")
- **pack / source:** core ComfyUI (`nodes`) | **category:** `model/loaders` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** load a standalone VAE from disk when you do not want the checkpoint's bundled one (or the checkpoint has none).
- **inputs:**
  - `vae_name` (`COMBO`) - a dropdown of installed VAE files (read from `models/vae`). Empty dropdown = none found; check `extra_model_paths.yaml`. The list can also include built-in pseudo-entries such as a `taesd` preview decoder or a `pixel_space` option for models that decode without a learned VAE; pick the one that matches your model family.
- **outputs:**
  - `VAE` (`VAE`) - the autoencoder object; feeds `VAEDecode.vae` (latent to pixels) or `VAEEncode.vae` (pixels to latent for img2img / inpaint).
- **how it works:** reads a `.safetensors` (or `.pt`) VAE and returns it as a `VAE` object, no UNet or CLIP involved.
- **strengths:** the way to override a checkpoint's VAE with a better or model-correct one; the required path for UNet-only diffusion models whose checkpoint carries no VAE.
- **bugs / lags + fixes:** none known in the node.
- **anti-patterns:** loading a VAE from the wrong model family (an SDXL VAE for an SD1.5 latent, or vice versa) gives washed-out or color-shifted decodes. Each model generation has its own latent space; the VAE must match it, not just "be a VAE". Do not reach for this when the checkpoint already ships a correct VAE; use the checkpoint's `VAE` output and save the load.
- **placement:** a leaf at the edge of the graph. Nothing feeds it; it feeds `VAEDecode` (and `VAEEncode`). Sits parallel to the checkpoint loader, not in series with it.

### LoraLoaderModelOnly  (display: "Load LoRA")
- **pack / source:** core ComfyUI (`nodes`) | **category:** `model/loaders` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** apply a LoRA to the diffusion model ONLY, for models that have no CLIP to patch (UNet-only diffusion models, many video / Flux-style builds).
- **inputs:**
  - `model` (`MODEL`) - the diffusion model the LoRA patches. Unlike `LoraLoader`, there is no `clip` input.
  - `lora_name` (`COMBO`) - a dropdown of installed LoRA files (read from `models/loras`).
  - `strength_model` (`FLOAT`, default 1.0) - how hard to push the UNet; can be negative to subtract a learned style.
- **outputs:**
  - `MODEL` (`MODEL`) - the patched diffusion model; chain another `LoraLoaderModelOnly` off this to stack LoRAs, then wire into the sampler.
- **how it works:** merges the LoRA delta into the diffusion model at `strength_model` during the pass; touches model weights only, leaving any CLIP untouched.
- **strengths:** the correct LoRA node when there is no CLIP in the pipeline; stackable; negative strength supported. Lighter wiring than `LoraLoader` (one model port in, one out).
- **bugs / lags + fixes:** none known. A LoRA trained on a different base silently degrades the output rather than erroring.
- **anti-patterns:** using it when you DO have a CLIP you also want patched; there, `LoraLoader` (model + clip) is correct, otherwise the CLIP-side of the LoRA is dropped. Feeding a LoRA built for a different base model. Wiring it where the model has a normal CLIP path but the LoRA also carries CLIP weights you are now silently discarding.
- **placement:** in series on the MODEL line, between the diffusion loader (UNETLoader or a checkpoint's `MODEL`) and the sampler. Insert it, do not branch around it.

### UpscaleModelLoader  (display: "Load Upscale Model")
- **pack / source:** core ComfyUI (`nodes`) | **category:** `model/loaders` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** load a pixel-space upscale model (ESRGAN-family: RealESRGAN, 4x-UltraSharp, SwinIR, and similar) for use by an image upscaler node.
- **inputs:**
  - `model_name` (`COMBO`) - a dropdown of installed upscale-model files (read from `models/upscale_models`). Empty dropdown = none found; check the folder and `extra_model_paths.yaml`.
- **outputs:**
  - `UPSCALE_MODEL` (`UPSCALE_MODEL`) - the loaded upscaler; consumed by `ImageUpscaleWithModel` (and equivalent nodes), which run it over an `IMAGE`.
- **how it works:** loads the upscale-model weights and returns an `UPSCALE_MODEL` object. It does NOT upscale anything by itself; it only hands the model to a node that does.
- **strengths:** the standard entry point for detail-adding pixel upscalers; works on a decoded `IMAGE`, independent of the diffusion model.
- **bugs / lags + fixes:** none known in the node. Large images run through the paired upscaler can spike VRAM; that is a property of the upscale node, not this loader.
- **anti-patterns:** confusing it with latent upscaling. This produces a pixel-space `UPSCALE_MODEL` for `ImageUpscaleWithModel`; it is NOT a latent upscaler and its output does not go into a sampler. For latent-space upscaling use the latent-upscale path (e.g. `LatentUpscaleModelLoader` for the Hunyuan family, or `LatentUpscale` / `LatentUpscaleBy`). Each upscale model also has a fixed native factor (2x, 4x); expecting an arbitrary scale from the model itself is wrong.
- **placement:** a leaf feeding only the image-upscaler node, which sits after `VAEDecode` in the pixel-space part of the graph.

### ControlNetLoader  (display: "Load ControlNet Model")
- **pack / source:** core ComfyUI (`nodes`) | **category:** `model/loaders` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** load a ControlNet model so a conditioning node can steer generation by an extra signal (pose, depth, canny, scribble, and so on).
- **inputs:**
  - `control_net_name` (`COMBO`) - a dropdown of installed ControlNet files (read from `models/controlnet`).
- **outputs:**
  - `CONTROL_NET` (`CONTROL_NET`) - the loaded ControlNet; feeds `ControlNetApply` / `ControlNetApplyAdvanced`, which combine it with a preprocessed hint `IMAGE` and the positive (and negative) `CONDITIONING`.
- **how it works:** loads the ControlNet weights and returns a `CONTROL_NET` object. The actual steering happens in the apply node, which needs the control image and the conditioning; this node only supplies the model.
- **strengths:** the standard way to bring any single ControlNet into a graph; one node per ControlNet, stack apply nodes to combine several.
- **bugs / lags + fixes:** none known in the node. A ControlNet trained for a different base (an SD1.5 ControlNet on SDXL, or vice versa) loads but produces weak or wrong guidance; that mismatch surfaces at the apply node, not here. For ControlNets that need the model weights at load time, the separate `DiffControlNetLoader` exists (out of scope for this group).
- **anti-patterns:** loading a ControlNet whose base does not match the checkpoint. Forgetting the preprocessor: the apply node needs a hint image in the format the ControlNet expects (a depth map, a canny edge map, a pose skeleton), not a raw photo. This loader alone changes nothing until wired into an apply node.
- **placement:** a leaf into `ControlNetApply` / `ControlNetApplyAdvanced`, which sits on the conditioning path between `CLIPTextEncode` and the sampler.

### CLIPVisionLoader  (display: "Load CLIP Vision")
- **pack / source:** core ComfyUI (`nodes`) | **category:** `model/loaders` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** load a CLIP vision (image encoder) model, used to turn a reference image into an embedding for IP-Adapter, unCLIP, and style-by-image workflows.
- **inputs:**
  - `clip_name` (`COMBO[]`) - a dropdown of installed CLIP-vision files (read from `models/clip_vision`). The pull shows it as an empty `COMBO[]`, which means no CLIP-vision models are installed on this machine right now; on a populated install the dropdown lists the files.
- **outputs:**
  - `CLIP_VISION` (`CLIP_VISION`) - the image encoder; feeds `CLIPVisionEncode` (image to embedding), which then drives an IP-Adapter apply node, unCLIP conditioning, or a style-model path.
- **how it works:** loads a CLIP vision transformer and returns a `CLIP_VISION` object. It encodes images, not text; it is a separate model from the checkpoint's text-side `CLIP`.
- **strengths:** the entry point for any image-prompt / reference-image pipeline; pairs with `CLIPVisionEncode` and IP-Adapter or unCLIP nodes.
- **bugs / lags + fixes:** none known in the node. The most common practical issue is a CLIP-vision model that does not match the adapter or unCLIP path expecting it (e.g. the wrong vision-encoder variant for a given IP-Adapter), which gives weak or broken image conditioning.
- **anti-patterns:** confusing it with the text `CLIP` from the checkpoint; this is the vision encoder and its `CLIP_VISION` does NOT plug into `CLIPTextEncode`. Pairing the wrong CLIP-vision variant with an adapter that expects a specific one.
- **placement:** a leaf feeding `CLIPVisionEncode`; the chain then joins the conditioning path via the relevant adapter / unCLIP node, ahead of the sampler.

### StyleModelLoader  (display: "Load Style Model")
- **pack / source:** core ComfyUI (`nodes`) | **category:** `model/loaders` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** load a style model (the classic case is the SDXL Revision style adapter; also the Flux Redux style model) that injects a reference image's style into conditioning.
- **inputs:**
  - `style_model_name` (`COMBO[]`) - a dropdown of installed style-model files (read from `models/style_models`). The pull shows an empty `COMBO[]`, meaning none are installed on this machine right now.
- **outputs:**
  - `STYLE_MODEL` (`STYLE_MODEL`) - the style adapter; feeds `StyleModelApply`, which combines it with a `CLIP_VISION` embedding of the reference image and the positive `CONDITIONING`.
- **how it works:** loads the style-model weights and returns a `STYLE_MODEL` object. On its own it does nothing; `StyleModelApply` uses it together with a CLIP-vision encoding of the reference image to modify the conditioning.
- **strengths:** the route for image-driven style transfer (Revision / Redux); composes with the CLIP-vision path.
- **bugs / lags + fixes:** none known in the node. A style model paired with a checkpoint of a different family (a Flux Redux model on an SDXL graph, or a Revision model on Flux) will not steer correctly; the mismatch shows at the apply node.
- **anti-patterns:** wiring it without the matching `CLIPVisionLoader` + `CLIPVisionEncode` + `StyleModelApply` chain (the style model needs an image embedding to act on). Mixing a style model and base model from different families.
- **placement:** a leaf feeding `StyleModelApply`, which sits on the conditioning path with the CLIP-vision embedding, before the sampler.

### ImageOnlyCheckpointLoader  (display: "Load Checkpoint Image Only (img2vid model)")
- **pack / source:** core ComfyUI (`nodes`) | **category:** `model/loaders` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** load an image-to-video checkpoint (the original case is Stable Video Diffusion), which conditions on an input image rather than on a text prompt, so it returns a CLIP VISION encoder instead of a text CLIP.
- **inputs:**
  - `ckpt_name` (`COMBO`) - a dropdown of installed checkpoint files (read from `models/checkpoints`). Pick an img2vid checkpoint here; a normal SD1.5 / SDXL checkpoint loaded through this node gives outputs that do not fit a text-to-image graph.
- **outputs:**
  - `MODEL` (`MODEL`) - the diffusion model; feeds the sampler.
  - `CLIP_VISION` (`CLIP_VISION`) - the image encoder (NOT a text `CLIP`); feeds the SVD image-conditioning node (e.g. `SVD_img2vid_Conditioning`), which encodes the start image.
  - `VAE` (`VAE`) - the autoencoder; feeds `VAEDecode` of the video frames.
- **how it works:** reads a checkpoint that bundles UNet + CLIP vision + VAE for image-conditioned video, and hands out all three. The defining difference from `CheckpointLoaderSimple` is the second output: `CLIP_VISION` for image conditioning, not `CLIP` for text.
- **strengths:** the one-node entry point for SVD-style image-to-video; gives exactly the three objects an img2vid graph needs.
- **bugs / lags + fixes:** none known in the node.
- **anti-patterns:** treating its `CLIP_VISION` output as a text `CLIP`; it does NOT plug into `CLIPTextEncode`. Loading a plain text-to-image checkpoint through it. Expecting a text-prompt workflow from an img2vid model; conditioning here is the input image plus motion controls, not a prompt.
- **placement:** the root of an image-to-video graph. Nothing feeds it; it feeds the sampler, the SVD image-conditioning node, and `VAEDecode`.

### AudioEncoderLoader  (display: "Load Audio Encoder")
- **pack / source:** core ComfyUI (`nodes`) | **category:** `model/loaders` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** load an audio encoder model, used by audio-conditioned pipelines that need an audio signal turned into an embedding (for example audio-driven video or audio-to-audio conditioning).
- **inputs:**
  - `audio_encoder_name` (`COMBO`) - a dropdown of installed audio-encoder files (read from the audio-encoder models folder). Empty dropdown = none installed; check the folder and `extra_model_paths.yaml`.
- **outputs:**
  - `AUDIO_ENCODER` (`AUDIO_ENCODER`) - the loaded audio encoder; consumed by the audio-encode node in the matching pipeline, which turns audio into the embedding the model conditions on.
- **how it works:** loads the audio-encoder weights and returns an `AUDIO_ENCODER` object. Like the other loaders here, it only supplies the model; the encoding happens in the downstream encode node.
- **strengths:** the entry point for audio-conditioned graphs; isolates the audio-encoder choice from the rest of the pipeline.
- **bugs / lags + fixes:** none known in the node. Which downstream encode node consumes `AUDIO_ENCODER` depends on the specific model family; confirm the consumer with `get_node_info` for that pipeline rather than assuming.
- **anti-patterns:** pairing an audio encoder with a model family that does not expect that encoder. Treating the `AUDIO_ENCODER` output as audio data; it is the model, not an encoded signal.
- **placement:** a leaf feeding the audio-encode node of its pipeline, upstream of the sampler / video model that consumes the audio embedding.

### LatentUpscaleModelLoader  (display: "Load Latent Upscale Model")
- **pack / source:** core ComfyUI, `comfy_extras.nodes_hunyuan` (confirmed via get_node_info `python_module`, 2026-06-30) | **category:** `model/loaders` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** load a latent-space upscale model for the Hunyuan family (the node ships in the Hunyuan extras module), which upscales in latent space rather than on decoded pixels.
- **inputs:**
  - `model_name` (`COMBO`) - a dropdown of installed latent-upscale-model files. Empty dropdown = none installed.
- **outputs:**
  - `LATENT_UPSCALE_MODEL` (`LATENT_UPSCALE_MODEL`) - the loaded latent upscaler; consumed by the matching Hunyuan latent-upscale apply node, which scales a `LATENT` before it is decoded.
- **how it works:** loads the latent-upscale-model weights and returns a `LATENT_UPSCALE_MODEL` object. It does not upscale by itself; it hands the model to the apply node that runs it over a latent. The exact apply node and its parameters are the Hunyuan latent-upscale node; confirm it with `get_node_info` rather than assuming, since this is a Hunyuan-specific path (the module is `comfy_extras.nodes_hunyuan`).
- **strengths:** keeps the upscale in latent space (no VAE round-trip mid-pipeline), within the Hunyuan workflow it was built for.
- **bugs / lags + fixes:** none known in the node. A low-VRAM variant exists as a separate custom node (`LowVRAMLatentUpscaleModelLoader`, from ComfyUI-LTXVideo, category `LTXV/loaders`, confirmed via get_node_info 2026-06-30) with the same `LATENT_UPSCALE_MODEL` output plus an optional `dependencies` input for sequential loading; reach for it only if the core node spikes VRAM and you have that pack installed.
- **anti-patterns:** confusing it with `UpscaleModelLoader`; the two produce different output types (`LATENT_UPSCALE_MODEL` vs `UPSCALE_MODEL`) for different apply nodes and different stages (latent vs pixel). Using this outside the Hunyuan latent-upscale path it belongs to. Wiring its output into an image upscaler (type mismatch).
- **placement:** a leaf feeding the Hunyuan latent-upscale apply node, which sits on the `LATENT` line between the sampler and `VAEDecode`.
