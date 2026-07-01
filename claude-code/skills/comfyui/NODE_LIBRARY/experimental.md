# Experimental

ComfyUI's `experimental` menu (and its `experimental/*` subgroups) is where core ships nodes that are useful but not yet promoted to a stable family. All six here are part of the core install (their `python_module` is either `nodes` or a `comfy_extras.*` module, confirmed via get_node_info on 2026-06-30, ComfyUI 0.25.1), and all but `VAEDecodeTiled` carry the `experimental: true` flag, so display names and exact I/O can shift between versions more readily than for a stable node. Treat the I/O below as a snapshot: it is confirmed for this version, but re-pull with `get_node_info` if the version moved. Three of these nodes (`ManualSigmas`, `T5TokenizerOptions`, `UNetTemporalAttentionMultiply`) have no registered display name, so the UI shows the class type itself as the label; that is noted per entry. The semantics, mechanism, placement, and gotchas are the curated layer.

One spans two worlds: `VAEDecodeTiled` is the low-VRAM decode that `core.md` points at from the `VAEDecode` entry. It gets a full entry here.

---

### VAEDecodeTiled  (display: "VAE Decode (Tiled)")
- **pack / source:** core ComfyUI (`nodes`) | **category:** `experimental` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** decode a latent to a pixel `IMAGE` in overlapping tiles instead of all at once, so a large image (or a long video latent) decodes within a VRAM budget that a single-pass `VAEDecode` would blow.
- **inputs:**
  - `samples` (`LATENT`) - the latent to decode, from the sampler (`KSampler` and friends). Same input `VAEDecode` takes.
  - `vae` (`VAE`) - the autoencoder, from the checkpoint's `VAE` output or a standalone `VAELoader`. Must match the latent's model family, exactly as for `VAEDecode`.
  - `tile_size` (`INT`, default 512) - the spatial tile edge in pixels. Smaller tiles use less VRAM but add more seams to blend and run slower; larger tiles are faster with fewer seams but cost more VRAM. This is the main knob to turn down when you still OOM.
  - `overlap` (`INT`, default 64) - how far neighbouring tiles overlap, in pixels. The overlap is blended so tile boundaries do not show. Too small and seams can appear; too large wastes compute. Keep it well below `tile_size`.
  - `temporal_size` (`INT`, default 64) - video VAEs only: how many frames to decode at a time. Ignored by image VAEs. Lower it to fit a long video latent in VRAM.
  - `temporal_overlap` (`INT`, default 8) - video VAEs only: how many frames neighbouring temporal chunks overlap, blended to avoid a visible seam between chunks. Ignored by image VAEs.
- **outputs:**
  - `IMAGE` (`IMAGE`) - the decoded pixels, identical in role to `VAEDecode`'s output. Feeds `SaveImage`, `PreviewImage`, an upscaler, or any IMAGE consumer.
- **how it works:** runs the VAE decoder tile by tile over the latent, with each tile overlapping its neighbours by `overlap`, then blends the overlaps so the full image is seamless. For video VAEs it also chunks along time by `temporal_size` with `temporal_overlap`. Peak VRAM is set by the tile, not the whole frame, which is the entire point.
- **strengths:** the standard escape hatch when `VAEDecode` OOMs on a big image or a long video on limited VRAM. Drop-in: same `samples` and `vae` wiring, same `IMAGE` out. Two independent budgets (spatial via `tile_size`/`overlap`, temporal via `temporal_size`/`temporal_overlap`) for video.
- **bugs / lags + fixes:** none known in the node. Practical gotchas: too-small `tile_size` or `overlap` can leave faint seams or grid artifacts, so raise `overlap` (or `tile_size`) if you see them; tiling is slower than a single pass, so prefer plain `VAEDecode` when it fits and only reach for this when it does not. For video specifically, KJNodes' `VAEDecodeLoopKJ` is the alternative when loop seams are the problem (noted in `core.md`).
- **anti-patterns:** using it by default when `VAEDecode` already fits, you pay the speed cost for nothing. Feeding a `vae` from the wrong model family (washed or shifted color, same failure as `VAEDecode`). Expecting the temporal inputs to do anything on an image VAE; they are inert there. Setting `overlap` close to or above `tile_size`.
- **placement:** drop-in replacement for `VAEDecode`, sitting between the sampler's `LATENT` output and the output node (`SaveImage` / `PreviewImage`) or a pixel-space upscaler.

### DifferentialDiffusion  (display: "Differential Diffusion")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_differential_diffusion`, confirmed via get_node_info `python_module`, 2026-06-30) | **category:** `experimental` | **I/O confirmed via get_node_info:** 2026-06-30 | upstream method: github.com/exx8/differential-diffusion (cited in the node's source header)
- **purpose:** turn a soft (greyscale) inpaint / img2img mask into a per-pixel gradient of denoise strength, so the change blends smoothly from "fully repainted" to "untouched" across the mask instead of having one hard edge.
- **inputs:**
  - `model` (`MODEL`) - the diffusion model to patch. The node attaches a custom denoise-mask function to a clone of it; weights are not changed.
  - `strength` (`FLOAT`, default 1.0, range 0.0 to 1.0, optional) - how hard the per-pixel gradient is applied. At 1.0 the mask is binarized per timestep (the full differential-diffusion behavior). Below 1.0 the result is blended back toward the raw mask (`strength * binary + (1 - strength) * mask`, confirmed in source), softening the effect. Source confirmed: the blend branch only runs when `strength < 1`.
- **outputs:**
  - `MODEL` (`MODEL`) - the patched model; wire it into the sampler in place of the original `MODEL`. Carries the attached denoise-mask behavior, nothing else about the model differs.
- **how it works:** confirmed from source. It clones the model and sets a `denoise_mask_function`. During sampling, for the current timestep it computes a threshold from where that timestep sits between the schedule's start and end, then keeps a mask pixel "active" only once the schedule has progressed past that pixel's grey value. The practical effect: a pixel's grey level in the mask decides at what point along the denoise trajectory it starts changing, so a smooth grey ramp becomes a smooth ramp of denoise start-times, and the repaint feathers into the original instead of cutting at a hard mask edge.
- **strengths:** smooth, gradient inpainting and masked img2img from an ordinary soft mask, no special sampler required. Cheap (it patches behavior, not weights). Model-family agnostic in principle, since it operates on the sampling mask rather than on architecture-specific weights.
- **bugs / lags + fixes:** none known in the node.
- **anti-patterns:** wiring it into a graph that never supplies a denoise mask. It only acts when the sampling path actually carries a `denoise_mask`, which means you need a masked latent (for example via `SetLatentNoiseMask`, or a `VAEEncodeForInpaint` path), not a plain txt2img graph; with no mask it does nothing. A hard binary mask defeats the purpose, the whole value is in a soft gradient mask. Expecting it to change colors or content by itself; it only reshapes how an existing masked edit is feathered. Note the separate `DifferentialDiffusionAdvanced` is a KJNodes custom node (category `_for_testing`, different I/O), not this core node.
- **placement:** on the `MODEL` line, between the model source (checkpoint `MODEL`, a `LoraLoader`, or `UNETLoader`) and the sampler, in an inpaint / masked-img2img graph that feeds the sampler a masked latent.

### T5TokenizerOptions  (display: class type "T5TokenizerOptions", no registered display name as of 2026-06-30)
- **pack / source:** core ComfyUI (`comfy_extras.nodes_cond`, confirmed via get_node_info `python_module`, 2026-06-30) | **category:** `experimental/conditioning` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** adjust the T5 tokenizer's padding / minimum-length behavior on a CLIP object before it encodes a prompt, for models whose text side uses a T5 encoder (Flux, SD3, and similar T5-bearing families).
- **inputs:**
  - `clip` (`CLIP`) - the CLIP / text-encoder object to adjust. For these models the `CLIP` object wraps a T5 tokenizer; this node sets options on a copy of it.
  - `min_padding` (`INT`, default 0) - a minimum amount of padding to apply at tokenization time. Default 0 leaves the tokenizer's normal behavior.
  - `min_length` (`INT`, default 0) - a minimum token sequence length to pad up to. Default 0 leaves the tokenizer's normal behavior.
- **outputs:**
  - `CLIP` (`CLIP`) - the same CLIP with the T5 tokenizer options applied; feed it into the text-encode node (the model's T5-aware encoder, e.g. the Flux or SD3 encode node) exactly where the original `CLIP` would have gone.
- **how it works:** it sets tokenizer padding / length options on a copy of the `CLIP` object so that, when a downstream encode node tokenizes the prompt, the T5 tokenizer pads or extends to the requested minimums. It changes how the prompt is tokenized, not the encoder weights. The exact numeric effect on a given model's conditioning is best confirmed by trying it on that model rather than assumed.
- **strengths:** a targeted knob for T5 padding behavior without touching the rest of the graph; pass-through wiring (CLIP in, CLIP out) so it inserts cleanly on the text path.
- **bugs / lags + fixes:** none known in the node. It is experimental, so treat the precise behavior as version-dependent and confirm on your model.
- **anti-patterns:** inserting it on a model whose text side has no T5 encoder (a plain SD1.5 / SDXL CLIP); there is no T5 tokenizer for it to affect, so it is at best a no-op. Leaving both values at 0 and expecting a change, the defaults are the tokenizer's normal behavior. Treating it as a general prompt or weighting control; it only governs T5 padding / minimum length.
- **placement:** on the `CLIP` line, between the CLIP / text-encoder source and the text-encode node that tokenizes the prompt, for T5-based model families.

### FluxKVCache  (display: "Flux KV Cache")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_flux`, confirmed via get_node_info `python_module`, 2026-06-30) | **category:** `experimental` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** enable a key/value cache optimization for reference images on Flux-family models, so repeated work over the same reference is cheaper. Description confirmed via get_node_info: "Enables KV Cache optimization for reference images on Flux family models."
- **inputs:**
  - `model` (`MODEL`) - the Flux-family diffusion model to patch. Input tooltip (confirmed via get_node_info): "The model to use KV Cache on."
- **outputs:**
  - `MODEL` (`MODEL`) - the patched model with KV cache enabled. Output tooltip (confirmed via get_node_info): "The patched model with KV Cache enabled." Wire it into the sampler in place of the original `MODEL`.
- **how it works:** it returns a patched `MODEL` that enables KV (key/value) caching for reference-image conditioning on Flux. Beyond the confirmed description and tooltips above, the exact caching mechanism is not detailed here; this is a Flux-specific optimization node, so confirm any performance claim by measuring on your own Flux reference workflow rather than assuming a speedup.
- **strengths:** a single-node, drop-in optimization for Flux reference-image pipelines (no new wiring beyond passing the model through it).
- **bugs / lags + fixes:** none known in the node.
- **anti-patterns:** using it on a non-Flux model; it is scoped to the Flux family per its own description and is not a general KV-cache for arbitrary models. Expecting it to do anything in a Flux graph that has no reference-image conditioning, the optimization is specifically for reference images. Treating it as a quality control; it is an optimization, not a conditioning node.
- **placement:** on the `MODEL` line of a Flux reference-image graph, between the model source (a Flux `UNETLoader` / checkpoint `MODEL`, after any LoRA) and the sampler.

### ManualSigmas  (display: class type "ManualSigmas", no registered display name as of 2026-06-30)
- **pack / source:** core ComfyUI (`comfy_extras.nodes_custom_sampler`, confirmed via get_node_info `python_module`, 2026-06-30) | **category:** `experimental/custom_sampling` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** build a `SIGMAS` schedule by hand from a typed list of numbers, for the custom-sampling (`SamplerCustom` / `SamplerCustomAdvanced`) path where you supply the sigma schedule explicitly instead of letting a scheduler node generate it.
- **inputs:**
  - `sigmas` (`STRING`, default `"1, 0.5"`) - the sigma values as a comma-separated string, highest (most noise) to lowest. This is a free-text field, so a malformed string (stray characters, wrong separators) is the obvious failure mode; keep it to plain comma-separated numbers in descending order. The default of two values is a minimal example, not a useful schedule for real sampling.
- **outputs:**
  - `SIGMAS` (`SIGMAS`) - the noise schedule, consumed by a custom sampler node (`SamplerCustom` / `SamplerCustomAdvanced`) in place of the `SIGMAS` a scheduler node (`BasicScheduler`, `KarrasScheduler`, and the like) would produce.
- **how it works:** it parses the comma-separated string into a sigma tensor and hands it out as `SIGMAS`. There is no model awareness; whatever numbers you type become the schedule verbatim, so correctness is entirely on you.
- **strengths:** total manual control of the noise schedule for experiments, custom curves, or reproducing a specific schedule the generator nodes will not produce. The way to hand-author sigmas in the custom-sampling graph.
- **bugs / lags + fixes:** none known in the node. The realistic risk is a bad schedule (values not strictly descending, the wrong range for the model, or a typo), which yields poor or broken output, not a node error.
- **anti-patterns:** using it when a scheduler node (`BasicScheduler`, `KarrasScheduler`, `ExponentialScheduler`, and so on) would give a correct, model-aware schedule with far less risk; reach for manual sigmas only when you specifically need a curve those cannot make. Feeding it into the basic `KSampler`, which takes a `scheduler` widget and does not accept a `SIGMAS` input; this belongs on the `SamplerCustom` path. Typing an ascending or arbitrary list and expecting sane results.
- **placement:** a near-leaf on the custom-sampling path: it produces `SIGMAS` that feed `SamplerCustom` / `SamplerCustomAdvanced`, parallel to the `SAMPLER` (from a sampler-select node) and the conditioning.

### UNetTemporalAttentionMultiply  (display: class type "UNetTemporalAttentionMultiply", no registered display name as of 2026-06-30)
- **pack / source:** core ComfyUI (`comfy_extras.nodes_attention_multiply`, confirmed via get_node_info `python_module`, 2026-06-30) | **category:** `experimental/attention_experiments` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** scale the attention output projections of a video UNet separately for its spatial (structural) and temporal paths, across self-attention and cross-attention, as an experiment to push or relax how much each path contributes.
- **inputs:**
  - `model` (`MODEL`) - the diffusion model to patch. Intended for a model whose UNet has temporal attention blocks (video / AnimateDiff-style); confirmed from source, the node keys off state-dict names containing `.time_stack.`.
  - `self_structural` (`FLOAT`, default 1.0, range 0.0 to 10.0) - multiplier on the `to_out` projection of self-attention (`attn1`) in the spatial (non-`time_stack`) blocks. 1.0 is no change.
  - `self_temporal` (`FLOAT`, default 1.0, range 0.0 to 10.0) - multiplier on the `to_out` projection of self-attention (`attn1`) in the temporal (`time_stack`) blocks.
  - `cross_structural` (`FLOAT`, default 1.0, range 0.0 to 10.0) - multiplier on the `to_out` projection of cross-attention (`attn2`) in the spatial blocks.
  - `cross_temporal` (`FLOAT`, default 1.0, range 0.0 to 10.0) - multiplier on the `to_out` projection of cross-attention (`attn2`) in the temporal (`time_stack`) blocks.
- **outputs:**
  - `MODEL` (`MODEL`) - the patched model; feed it to the sampler in place of the original.
- **how it works:** confirmed from source. It clones the model, walks the model state dict, and for each `attn1.to_out.0` (self) and `attn2.to_out.0` (cross) weight/bias it adds a scaling patch, choosing the temporal multiplier when the key contains `.time_stack.` and the structural multiplier otherwise. Only the output projection (`to_out`) is scaled, not q / k / v, which is what distinguishes it from the sibling `UNetSelfAttentionMultiply` / `UNetCrossAttentionMultiply` nodes (those scale q, k, v, and out on a single attention type).
- **strengths:** fine, separate control of spatial vs temporal attention strength in a video model, split across self and cross attention, all in one node. An experimentation knob for video-motion / coherence tradeoffs.
- **bugs / lags + fixes:** none known in the node. Behavioral caveat confirmed from source: on a plain image UNet (SD1.5 / SDXL) there are no `.time_stack.` keys, so the two `*_temporal` multipliers patch nothing and only the `*_structural` ones take effect; it is meant for models that actually have a temporal attention path.
- **anti-patterns:** expecting the temporal controls to do anything on a non-video model, they are inert without `.time_stack.` blocks. Pushing multipliers far from 1.0 and expecting stability; this is an experimental scaling hack and large values can degrade or break output. Confusing it with the self / cross multiply siblings, which scale q/k/v/out on one attention type rather than splitting structural vs temporal on `to_out`.
- **placement:** on the `MODEL` line of a video-model graph, between the model source and the sampler. Stackable with the other attention-multiply nodes on the same line if you want to combine effects.
