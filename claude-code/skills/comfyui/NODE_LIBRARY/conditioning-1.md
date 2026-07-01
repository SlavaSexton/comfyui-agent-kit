# Conditioning (part 1)

The `model/conditioning` family: nodes that take CONDITIONING (the encoded prompt embedding produced by a text encoder) and other signals (a ControlNet, a reference image, a CLIP vision embedding, a VAE-encoded latent) and return modified CONDITIONING, or that build the conditioning a specific model family needs. These sit between the text encoder and the sampler. Most of them carry the positive and negative conditioning together so they can write into both at once. All I/O below is **confirmed via get_node_info: 2026-06-30** (ComfyUI 0.25.1) from the provided `/object_info` pull; the semantics, mechanism, placement, and gotchas are the curated layer. Any input typed `COMBO[...]` whose values are file or model names is one machine's installed files, so it is described as "a dropdown of installed <thing>", never hardcoded.

This is part 1 of the conditioning set. `CLIPTextEncode`, the universal SD1.5 / SDXL prompt node, already has a full entry in `core.md` and gets a one-line pointer here instead of a duplicate.

---

### CLIPTextEncode  (display: "CLIP Text Encode (Prompt)")
- See the full entry in `core.md`. Turns a text prompt into CONDITIONING that steers the sampler; used twice (positive and negative). Model families with their own encoder (Flux, SD3, SDXL split, HiDream, Lumina2, PixArt) need their dedicated node instead.

---

### ControlNetApplyAdvanced  (display: "Apply ControlNet")
- **pack / source:** core ComfyUI (`nodes`) | **category:** `model/conditioning/controlnet` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** apply a loaded ControlNet to both positive and negative conditioning so a control image (pose, depth, canny, scribble, and so on) steers generation, with strength and a start/end window over the denoise.
- **inputs:**
  - `positive` (`CONDITIONING`) - the positive conditioning to inject the control signal into.
  - `negative` (`CONDITIONING`) - the negative conditioning; the node writes the control hint into both branches.
  - `control_net` (`CONTROL_NET`) - the loaded ControlNet (from `ControlNetLoader` or equivalent). Must match the base model family.
  - `image` (`IMAGE`) - the control/hint image, already preprocessed (a depth map, a canny edge map, an openpose render, and so on). This node does NOT preprocess; feed it the finished hint.
  - `strength` (`FLOAT`, default 1.0) - how strongly the ControlNet pulls. Lower to loosen its grip.
  - `start_percent` (`FLOAT`, default 0.0) - fraction of the denoise at which the ControlNet starts acting (0.0 = from the first step).
  - `end_percent` (`FLOAT`, default 1.0) - fraction at which it stops (1.0 = through the last step). A window like 0.0 to 0.5 lets the ControlNet set composition early then releases it.
  - `vae` (`VAE`, optional) - only needed for ControlNets that operate in latent space (some newer ones); leave unwired for the classic pixel-hint ControlNets.
- **outputs:**
  - `positive` (`CONDITIONING`) - positive conditioning with the control hint attached; feeds the sampler's `positive`.
  - `negative` (`CONDITIONING`) - negative conditioning with the hint attached; feeds the sampler's `negative`.
- **how it works:** attaches the ControlNet and its hint image to the conditioning, with the strength and the start/end timestep range recorded, so the sampler applies the ControlNet's residuals only within that window at that strength.
- **strengths:** the standard, full-control ControlNet apply node. Separate start/end percents make it the right choice for staged control (lock structure early, free detail later) and for multi-ControlNet stacks (chain several, each over its own window). Writes both conditioning branches in one node.
- **bugs / lags + fixes:** none known in the node. A control image that was not run through the matching preprocessor (raw photo instead of a depth/canny map) gives weak or wrong guidance, that is a wiring problem, not a node bug.
- **anti-patterns:** feeding a ControlNet from the wrong base family (an SD1.5 ControlNet against an SDXL model, or vice versa). Passing an un-preprocessed image and expecting the node to detect edges/pose itself. Wiring `vae` for a pixel-space ControlNet that does not use it. For the simpler one-output legacy flow there is `ControlNetApply` (single conditioning), but this advanced node is preferred because it handles negative and the timestep window.
- **placement:** between the text encoders and the sampler. `CLIPTextEncode(pos/neg)` feed `positive`/`negative`; a ControlNet loader feeds `control_net`; a preprocessor (or a loaded hint) feeds `image`; the two outputs go to `KSampler.positive` / `.negative`. Chain multiple instances to stack ControlNets.

### InpaintModelConditioning  (display: "InpaintModelConditioning")
- **pack / source:** core ComfyUI (`nodes`) | **category:** `model/conditioning/inpaint` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** build the conditioning and masked latent for inpainting, so a model paints only inside a mask while keeping the rest of the image. Prepares positive, negative, and the latent in one node.
- **inputs:**
  - `positive` (`CONDITIONING`) - positive prompt conditioning for the inpaint region.
  - `negative` (`CONDITIONING`) - negative conditioning.
  - `vae` (`VAE`) - encodes the source pixels into the latent the sampler edits.
  - `pixels` (`IMAGE`) - the source image to inpaint into.
  - `mask` (`MASK`) - where to paint (white = repaint, black = keep). Must match the image resolution.
  - `noise_mask` (`BOOLEAN`) - per the node's own description, adds a noise mask to the latent so sampling happens only within the mask; "might improve results or completely break things depending on the model." Treat it as model-dependent and test both states.
- **outputs:**
  - `positive` (`CONDITIONING`) - inpaint-ready positive conditioning.
  - `negative` (`CONDITIONING`) - inpaint-ready negative conditioning.
  - `latent` (`LATENT`) - the encoded, masked latent; feeds `KSampler.latent_image`.
- **how it works:** VAE-encodes the source pixels, applies the mask, and packages the masked latent together with the (mask-aware) conditioning so the sampler only denoises inside the masked area.
- **strengths:** one node prepares all three things inpainting needs (positive, negative, latent), correctly mask-aware. The right path for inpaint-aware models and for SD3 / Flux-style fill where a plain `VAEEncodeForInpaint` is not enough.
- **bugs / lags + fixes:** the `noise_mask` toggle can degrade or break output on some models per its own warning; if inpaint results look wrong, flip it. No other known issue in the node.
- **anti-patterns:** a mask whose resolution does not match `pixels`. Using it for plain txt2img (there is no source image to inpaint). For older SD1.5 inpaint checkpoints the simpler `VAEEncodeForInpaint` route is often enough; reach for this node when the model expects integrated inpaint conditioning.
- **placement:** after the text encoders and a VAE source, before the sampler. Outputs replace both conditioning lines AND the latent line into `KSampler`.

### StyleModelApply  (display: "Apply Style Model")
- **pack / source:** core ComfyUI (`nodes`) | **category:** `model/conditioning/style_model` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** inject a style model's guidance (the classic case is a CLIP-Vision style/IP-style transfer, and the Flux Redux path) into conditioning, so an image's style or content steers generation.
- **inputs:**
  - `conditioning` (`CONDITIONING`) - the conditioning to augment (typically your positive). Note: single conditioning input, not a positive/negative pair.
  - `style_model` (`STYLE_MODEL`) - the loaded style model (from `StyleModelLoader`), for example a Flux Redux model.
  - `clip_vision_output` (`CLIP_VISION_OUTPUT`) - the encoded reference image, produced by `CLIPVisionEncode`. This is the image whose style/content is transferred.
  - `strength` (`FLOAT`, default 1.0) - how strongly the style model's tokens weigh in.
  - `strength_type` (`COMBO["multiply", "attn_bias"]`) - how strength is applied: `multiply` scales the appended style tokens; `attn_bias` biases attention toward them. `attn_bias` tends to give finer control on Flux Redux; test per model.
- **outputs:**
  - `CONDITIONING` (`CONDITIONING`) - the original conditioning with the style model's tokens appended; feeds the sampler's `positive` (or onward to another conditioning node).
- **how it works:** runs the style model on the CLIP-Vision embedding of the reference image and appends the resulting tokens to the conditioning, weighted by `strength` and combined per `strength_type`, so the sampler attends to them.
- **strengths:** the apply half of the style-transfer / Redux path. The `multiply` vs `attn_bias` choice makes it tunable rather than all-or-nothing. Stackable (feed its output into another `StyleModelApply` with a second reference).
- **bugs / lags + fixes:** none known. A mismatch between the style model and the CLIP-Vision model that produced the embedding gives weak or garbage style transfer.
- **anti-patterns:** feeding a `clip_vision_output` from a CLIP-Vision encoder that does not match the style model. Expecting it to touch the negative branch (it only takes one conditioning). Using it without a `StyleModelLoader` and a `CLIPVisionEncode` upstream.
- **placement:** after `CLIPTextEncode(pos)` and a `CLIPVisionEncode` + `StyleModelLoader`. Its output replaces the positive conditioning into the sampler. Sits in the conditioning chain, not the model chain.

### CLIPVisionEncode  (display: "CLIP Vision Encode")
- **pack / source:** core ComfyUI (`nodes`) | **category:** `model/conditioning` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** encode an image through a CLIP-Vision model into a CLIP_VISION_OUTPUT embedding, the visual equivalent of encoding a text prompt. This embedding feeds style models, IP-Adapters, image-to-video conditioners, and 3D conditioners.
- **inputs:**
  - `clip_vision` (`CLIP_VISION`) - the loaded CLIP-Vision model (from `CLIPVisionLoader`).
  - `image` (`IMAGE`) - the image to encode.
  - `crop` (`COMBO["center", "none"]`) - how to fit the image to the model's expected square input. `center` center-crops to square; `none` skips cropping (the image is resized/letterboxed instead). Use `center` when the subject is centered; `none` to avoid losing edges.
- **outputs:**
  - `CLIP_VISION_OUTPUT` (`CLIP_VISION_OUTPUT`) - the image embedding; consumed by `StyleModelApply`, `Hunyuan3Dv2Conditioning`, the HunyuanVideo image-to-video nodes, and IP-Adapter-style nodes.
- **how it works:** preprocesses the image (crop/resize to the model's input size) and runs it through the CLIP-Vision encoder, returning the pooled/patch embeddings as a `CLIP_VISION_OUTPUT`.
- **strengths:** the single source of `CLIP_VISION_OUTPUT` for the whole image-conditioning ecosystem. Cheap. The `crop` toggle lets you preserve framing.
- **bugs / lags + fixes:** none known. `center` cropping can cut off off-center subjects; switch to `none` if the subject sits near an edge.
- **anti-patterns:** pairing a CLIP-Vision model with a downstream style/IP/video model that expects a different CLIP-Vision variant (the embedding dimensions or training must match). Feeding its output where a text `CONDITIONING` is expected (different type). Expecting it to encode text (use a text encoder for that).
- **placement:** a near-leaf in the conditioning area. `CLIPVisionLoader` feeds `clip_vision`; an image source feeds `image`; the output goes to whichever node consumes a `CLIP_VISION_OUTPUT`.

### ControlNetInpaintingAliMamaApply  (display: "ControlNetInpaintingAliMamaApply")
- **pack / source:** core ComfyUI (`nodes`) | **category:** `model/conditioning/controlnet` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** apply an AliMama-style inpainting ControlNet, which combines ControlNet guidance with an inpaint mask so the controlled region is also the repainted region. Built for the AliMama inpainting ControlNet family.
- **inputs:**
  - `positive` (`CONDITIONING`) - positive conditioning to apply the ControlNet to.
  - `negative` (`CONDITIONING`) - negative conditioning.
  - `control_net` (`CONTROL_NET`) - the loaded AliMama inpainting ControlNet.
  - `vae` (`VAE`) - required here (unlike the generic advanced apply, where it is optional), to bridge the inpaint image/mask into the ControlNet's space.
  - `image` (`IMAGE`) - the source image being inpainted.
  - `mask` (`MASK`) - the inpaint region (white = repaint).
  - `strength` (`FLOAT`, default 1.0) - ControlNet strength.
  - `start_percent` (`FLOAT`, default 0.0) - denoise fraction at which control starts.
  - `end_percent` (`FLOAT`, default 1.0) - denoise fraction at which control stops.
- **outputs:**
  - `positive` (`CONDITIONING`) - conditioning with the inpaint-ControlNet attached.
  - `negative` (`CONDITIONING`) - the negative branch, likewise.
- **how it works:** combines the ControlNet with the masked source image so the ControlNet guides the repaint inside the mask over the given strength and timestep window. Inferred from the I/O shape and node family (an AliMama inpaint ControlNet apply); confirm the exact masking mechanism against the node source if it is load-bearing.
- **strengths:** the dedicated apply node for AliMama inpainting ControlNets, where a generic `ControlNetApplyAdvanced` would not wire the mask. Keeps the inpaint mask and the ControlNet in one place with a timestep window.
- **bugs / lags + fixes:** none known. Using it with a ControlNet that is not an AliMama-style inpainting model is the likely failure mode.
- **anti-patterns:** feeding a non-inpainting ControlNet (use `ControlNetApplyAdvanced` for those). Omitting the mask or supplying one that does not match the image resolution. Wrong base family.
- **placement:** between the text encoders and the sampler, in an inpainting graph. A ControlNet loader, a VAE, the source image, and a mask feed it; both outputs go to the sampler's conditioning inputs.

### InstructPixToPixConditioning  (display: "InstructPixToPixConditioning")
- **pack / source:** core ComfyUI (`nodes`) | **category:** `model/conditioning/instructpix2pix` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** build the conditioning and latent for InstructPix2Pix-style edit models, where a text instruction edits a source image ("make it winter", "turn the car red").
- **inputs:**
  - `positive` (`CONDITIONING`) - the edit instruction, encoded as conditioning.
  - `negative` (`CONDITIONING`) - negative conditioning.
  - `vae` (`VAE`) - encodes the source pixels into the image-conditioning latent.
  - `pixels` (`IMAGE`) - the source image to edit.
- **outputs:**
  - `positive` (`CONDITIONING`) - positive conditioning carrying the source-image latent for the edit model.
  - `negative` (`CONDITIONING`) - negative conditioning, likewise.
  - `latent` (`LATENT`) - the latent to denoise; feeds `KSampler.latent_image`.
- **how it works:** VAE-encodes the source image and packages it into the conditioning the way an InstructPix2Pix model expects (the image is supplied as conditioning, not just as a starting latent), and emits the latent to sample from.
- **strengths:** the correct prep node for ip2p edit checkpoints; one node sets up conditioning plus latent. The image-as-conditioning wiring is what distinguishes ip2p from plain img2img.
- **bugs / lags + fixes:** none known.
- **anti-patterns:** using it with a non-ip2p model (a normal SD1.5/SDXL checkpoint will not read the image conditioning). Expecting an explicit mask (ip2p edits the whole image by instruction; for masked edits use the inpaint path). Note ip2p models also want their own CFG / image-CFG balance at the sampler, which this node does not set.
- **placement:** after the text encoders and a VAE source, before the sampler. Replaces both conditioning lines and the latent line into `KSampler`.

### SVD_img2vid_Conditioning  (display: "SVD_img2vid_Conditioning")
- **pack / source:** core ComfyUI (`nodes`) | **category:** `model/conditioning/video_models` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** build the conditioning and latent for Stable Video Diffusion image-to-video, turning a single still into the conditioning an SVD model animates.
- **inputs:**
  - `clip_vision` (`CLIP_VISION`) - the CLIP-Vision model SVD uses to read the init image (SVD conditions on a CLIP-Vision embedding of the frame).
  - `init_image` (`IMAGE`) - the starting frame to animate.
  - `vae` (`VAE`) - encodes the init image into the latent.
  - `width` (`INT`, default 1024) / `height` (`INT`, default 576) - output frame size; SVD is trained around 1024x576.
  - `video_frames` (`INT`, default 14) - number of frames to generate (SVD comes in 14- and 25-frame variants).
  - `motion_bucket_id` (`INT`, default 127) - SVD's motion-amount control; higher means more movement. The signature SVD knob.
  - `fps` (`INT`, default 6) - frames-per-second conditioning value the model was trained with.
  - `augmentation_level` (`FLOAT`, default 0.0) - how much noise to add to the init image; raise it for more deviation from the source frame.
- **outputs:**
  - `positive` (`CONDITIONING`) - SVD positive conditioning (carries the CLIP-Vision embedding and motion settings).
  - `negative` (`CONDITIONING`) - the negative branch.
  - `latent` (`LATENT`) - the video latent of the right frame count and size; feeds the sampler.
- **how it works:** CLIP-Vision-encodes the init frame, VAE-encodes it to a latent, and bakes the SVD-specific settings (motion bucket, fps, frame count, augmentation) into the conditioning so the sampler produces a short clip.
- **strengths:** one node sets up the whole SVD img2vid conditioning. `motion_bucket_id` and `augmentation_level` are the two levers that make SVD output usable; both are here.
- **bugs / lags + fixes:** none known in the node. Off-resolution input (far from 1024x576) and an unmatched CLIP-Vision model are the usual causes of poor SVD output.
- **anti-patterns:** using it for any non-SVD video model (LTXV, Hunyuan, Wan all have their own conditioners). Wrong CLIP-Vision variant. Expecting long clips; SVD is built for 14 or 25 frames.
- **placement:** the conditioning+latent root of an SVD graph. A CLIP-Vision loader, an image, and a VAE feed it; the three outputs feed the SVD sampler.

### LTXVImgToVideo  (display: "LTXVImgToVideo")
- **pack / source:** core ComfyUI (`nodes`) | **category:** `model/conditioning/video_models` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** build the conditioning and latent for LTX-Video image-to-video, seeding an LTXV generation from a starting frame.
- **inputs:**
  - `positive` (`CONDITIONING`) / `negative` (`CONDITIONING`) - the text conditioning (from the LTXV text encoder path) to carry into the video.
  - `vae` (`VAE`) - encodes the start image into the video latent.
  - `image` (`IMAGE`) - the starting frame.
  - `width` (`INT`, default 768) / `height` (`INT`, default 512) - output frame size.
  - `length` (`INT`, default 97) - number of frames. LTXV expects frame counts of a specific form (commonly 8n+1, which 97 satisfies).
  - `batch_size` (`INT`, default 1) - clips per run.
  - `strength` (`FLOAT`, default 1.0) - how strongly the start image conditions the result; lower to let the video drift further from the frame.
- **outputs:**
  - `positive` (`CONDITIONING`) - LTXV positive conditioning seeded with the start frame.
  - `negative` (`CONDITIONING`) - the negative branch.
  - `latent` (`LATENT`) - the video latent of the requested size/length; feeds the sampler.
- **how it works:** VAE-encodes the start frame into the LTXV latent and attaches it to the conditioning at `strength`, producing the latent the LTXV sampler denoises. Usually paired with `LTXVConditioning` (which sets frame rate) before the sampler.
- **strengths:** the img2vid entry for LTX-Video. `strength` gives direct control over how much the first frame is honored.
- **bugs / lags + fixes:** none known in the node. A `length` that does not fit LTXV's expected form, or a size off the model's grid, can produce artifacts or errors.
- **anti-patterns:** using it for a non-LTXV model. Forgetting to also pass the result through `LTXVConditioning` for frame-rate conditioning where the recipe calls for it. Arbitrary frame counts.
- **placement:** in an LTXV image-to-video graph, after the text encoders, before (often) `LTXVConditioning` and the sampler. A VAE and a start image feed it; its three outputs continue down the LTXV chain.

### LTXVConditioning  (display: "LTXVConditioning")
- **pack / source:** core ComfyUI (`nodes`) | **category:** `model/conditioning/video_models` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** stamp a frame rate onto LTX-Video conditioning, the timing parameter LTXV needs alongside the prompt.
- **inputs:**
  - `positive` (`CONDITIONING`) / `negative` (`CONDITIONING`) - the LTXV conditioning to annotate.
  - `frame_rate` (`FLOAT`, default 25.0) - the target frames-per-second the model conditions on.
- **outputs:**
  - `positive` (`CONDITIONING`) / `negative` (`CONDITIONING`) - the same conditioning with `frame_rate` attached; feeds the sampler.
- **how it works:** writes the frame-rate value into both conditioning branches so the LTXV sampler generates motion at the intended cadence.
- **strengths:** small, single-purpose, the canonical place to set LTXV frame rate. Pairs with `LTXVImgToVideo` and the LTXV text encoder.
- **bugs / lags + fixes:** none known.
- **anti-patterns:** using it with a non-LTXV pipeline (other video families set frame rate differently or not at all). Treating `frame_rate` as the playback fps of the saved file; it is a conditioning value for the model, the file's fps is set by the video-save node.
- **placement:** late in the LTXV conditioning chain, just before the sampler. Takes LTXV conditioning in, hands rate-stamped conditioning out.

### LTXVCropGuides  (display: "LTXVCropGuides")
- **pack / source:** core ComfyUI (`nodes`) | **category:** `model/conditioning/video_models` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** strip the guide/keyframe latents back out of LTXV conditioning after sampling, so the final latent does not include the injected guide frames. The cleanup half of an LTXV keyframe-guided run.
- **inputs:**
  - `positive` (`CONDITIONING`) / `negative` (`CONDITIONING`) - the LTXV conditioning that had guides added.
  - `latent` (`LATENT`) - the sampled latent that still carries the guide frames.
- **outputs:**
  - `positive` (`CONDITIONING`) / `negative` (`CONDITIONING`) - conditioning with the guides removed.
  - `latent` (`LATENT`) - the latent cropped back to the intended output frames; feeds `VAEDecode`.
- **how it works:** removes the extra guide latents (added earlier by a keyframe/guide node) from both the conditioning and the latent so decoding produces only the wanted frames. Inferred from the node name, its category, and the LTXV guide workflow; confirm the exact crop against the source if load-bearing.
- **strengths:** the matching teardown node for LTXV guided generation; without it the guide frames leak into the decoded clip.
- **bugs / lags + fixes:** none known.
- **anti-patterns:** using it when no guides were added (nothing to crop). Wiring it into a non-LTXV pipeline.
- **placement:** after the LTXV sampler, before `VAEDecode`. Closes the guide path that an LTXV keyframe node opened upstream.

### HunyuanVideo15ImageToVideo  (display: "HunyuanVideo15ImageToVideo")
- **pack / source:** core ComfyUI (`nodes`) | **category:** `model/conditioning/video_models` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** build the conditioning and latent for HunyuanVideo 1.5 image-to-video, seeding a Hunyuan 1.5 generation from a start frame (and optionally a CLIP-Vision embedding of it).
- **inputs:**
  - `positive` (`CONDITIONING`) / `negative` (`CONDITIONING`) - the text conditioning for the clip.
  - `vae` (`VAE`) - encodes the start image into the video latent.
  - `width` (`INT`, default 848) / `height` (`INT`, default 480) - output frame size.
  - `length` (`INT`, default 33) - number of frames.
  - `batch_size` (`INT`, default 1) - clips per run.
  - `start_image` (`IMAGE`, optional) - the first frame to animate from; omit for a text-only generation through this node.
  - `clip_vision_output` (`CLIP_VISION_OUTPUT`, optional) - a CLIP-Vision embedding of the start frame, when the model uses one for stronger image conditioning.
- **outputs:**
  - `positive` (`CONDITIONING`) / `negative` (`CONDITIONING`) - Hunyuan 1.5 conditioning seeded for img2vid.
  - `latent` (`LATENT`) - the video latent; feeds the sampler.
- **how it works:** VAE-encodes the start frame (when given) into the latent and folds the start image and optional CLIP-Vision embedding into the conditioning, producing the latent the HunyuanVideo 1.5 sampler denoises. Mechanism inferred from the I/O and the node family; confirm against the node source if exact behavior is load-bearing.
- **strengths:** the dedicated img2vid conditioner for HunyuanVideo 1.5. Optional `start_image` and `clip_vision_output` make it flexible (pure text, image-seeded, or image+vision-seeded).
- **bugs / lags + fixes:** none known. Match the resolution and frame count to what the 1.5 model expects.
- **anti-patterns:** using it for a different Hunyuan version or a different video family. Supplying a `clip_vision_output` from a non-matching CLIP-Vision model.
- **placement:** the conditioning+latent root of a HunyuanVideo 1.5 img2vid graph. A VAE, a start image, and optionally a `CLIPVisionEncode` feed it; the three outputs feed the Hunyuan sampler. For an upscaling pass see `HunyuanVideo15SuperResolution`.

### HunyuanVideo15SuperResolution  (display: "HunyuanVideo15SuperResolution")
- **pack / source:** core ComfyUI (`nodes`) | **category:** `model/conditioning/video_models` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** set up a HunyuanVideo 1.5 super-resolution / refine pass, taking an existing video latent and conditioning a higher-detail re-generation with a controllable amount of added noise.
- **inputs:**
  - `positive` (`CONDITIONING`) / `negative` (`CONDITIONING`) - the text conditioning to carry into the SR pass.
  - `latent` (`LATENT`) - the low(er)-res video latent to upscale/refine.
  - `noise_augmentation` (`FLOAT`, default 0.7) - how much noise to add before the SR pass; the main knob trading fidelity to the source against room for new detail.
  - `vae` (`VAE`, optional) - provided when the node needs to (re)encode pixels for the SR step.
  - `start_image` (`IMAGE`, optional) - an optional reference/start frame for the SR pass.
  - `clip_vision_output` (`CLIP_VISION_OUTPUT`, optional) - an optional CLIP-Vision embedding for image conditioning.
- **outputs:**
  - `positive` (`CONDITIONING`) / `negative` (`CONDITIONING`) - conditioning prepared for the SR pass.
  - `latent` (`LATENT`) - the latent to run the SR sampling on; feeds the sampler.
- **how it works:** packages the incoming video latent with the chosen noise augmentation and (optional) image/vision references into conditioning for a second HunyuanVideo 1.5 pass that adds detail. Mechanism inferred from the I/O and node name; confirm against source if load-bearing.
- **strengths:** the dedicated SR/refine stage for HunyuanVideo 1.5, with `noise_augmentation` as a direct fidelity-vs-detail control. Pairs after `HunyuanVideo15ImageToVideo`.
- **bugs / lags + fixes:** none known. Too-high `noise_augmentation` drifts the SR pass away from the source clip.
- **anti-patterns:** feeding it a latent from a different video family. Treating it as a pixel upscaler (it conditions a latent SR pass, not an ESRGAN-style image upscale).
- **placement:** a second stage after the base HunyuanVideo 1.5 sampler, before a final `VAEDecode`. Takes the first-pass latent in, hands an SR-ready latent and conditioning to the SR sampler.

### GenerateTracks  (display: "GenerateTracks")
- **pack / source:** core ComfyUI (`nodes`) | **category:** `model/conditioning/video_models` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** generate motion tracks (point paths across the frame) to drive trajectory/motion-controlled video, by laying out start and end points and optional curve/spread settings.
- **inputs:**
  - `width` (`INT`, default 832) / `height` (`INT`, default 480) - the frame dimensions the normalized coordinates map onto.
  - `start_x` / `start_y` (`FLOAT`) - normalized (0 to 1) start position of the motion.
  - `end_x` / `end_y` (`FLOAT`) - normalized end position of the motion.
  - `num_frames` (`INT`, default 81) - how many frames the track spans.
  - `num_tracks` (`INT`, default 5) - how many parallel tracks to generate.
  - `track_spread` (`FLOAT`) - normalized distance between tracks; tracks are spread perpendicular to the motion direction.
  - `bezier` (`BOOLEAN`) - enable a Bezier curved path using the mid point as the control point (otherwise the path is straight).
  - `mid_x` / `mid_y` (`FLOAT`) - normalized control point for the Bezier curve; only used when `bezier` is enabled.
  - `interpolation` (`COMBO`) - a dropdown of timing curves controlling the speed of movement along the path (easing). Values are the installed interpolation options.
  - `track_mask` (`MASK`, optional) - an optional mask indicating which frames are visible.
- **outputs:**
  - `TRACKS` (`TRACKS`) - the generated motion tracks, consumed by a track-conditioned video node/sampler.
  - `track_length` (`INT`) - the length of the tracks (frame span), useful to wire into a matching frame-count input downstream.
- **how it works:** builds `num_tracks` point paths from the start to the end coordinate (straight, or Bezier through the mid control point), spread perpendicular by `track_spread`, timed by `interpolation` over `num_frames`, and returns them as a `TRACKS` object plus their length. All input semantics are quoted from the node's own field descriptions in the pull; the exact `TRACKS` consumer is the matching motion-control video sampler (confirm against the recipe you are building).
- **strengths:** a parametric way to author motion trajectories without hand-drawing them; Bezier and per-track spread give expressive paths; normalized coordinates make it resolution-independent.
- **bugs / lags + fixes:** none known.
- **anti-patterns:** wiring `TRACKS` into a node that does not consume that type (it only feeds track/trajectory-aware video models). Setting `mid_x`/`mid_y` while `bezier` is off (they are ignored). Expecting it to render anything itself; it only produces the track data.
- **placement:** a generator at the edge of a motion-controlled video graph. Nothing model-side feeds it; `TRACKS` feeds the trajectory-conditioned sampler, and `track_length` can feed that sampler's frame count.

### HiDreamO1ReferenceImages  (display: "HiDreamO1ReferenceImages")
- **pack / source:** core ComfyUI (`nodes`) | **category:** `model/conditioning/image` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** attach 1 to 10 reference images to conditioning for HiDream-O1: one image for an instruction edit, multiple for subject-driven personalization. (Purpose quoted from the node's own description.)
- **inputs:**
  - `positive` (`CONDITIONING`) / `negative` (`CONDITIONING`) - the conditioning the reference images attach to.
  - `images` (`COMFY_AUTOGROW_V3`) - a growable list of reference images: per the node's description, 1 image = instruction edit, 2 to 10 images = multi-reference. `COMFY_AUTOGROW_V3` is the auto-growing input widget, so you add image slots as needed rather than passing a fixed batch.
- **outputs:**
  - `positive` (`CONDITIONING`) / `negative` (`CONDITIONING`) - conditioning with the reference images attached; feeds the sampler.
- **how it works:** folds the supplied reference image(s) into the HiDream-O1 conditioning so the model either follows an edit instruction (single image) or borrows subject identity from several (multi-reference). Mechanism beyond what the description states is inferred; confirm against the node source if load-bearing.
- **strengths:** the reference-image conditioning node for HiDream-O1, with the auto-grow input making 1-to-10 references ergonomic. One node covers both the edit and the personalization cases.
- **bugs / lags + fixes:** none known. The description caps useful references at 10.
- **anti-patterns:** using it with a non-HiDream-O1 model. Exceeding the stated 1-to-10 range. Feeding plain `IMAGE` where the auto-grow widget expects its slots filled.
- **placement:** between the HiDream text encoders and the sampler. Image sources feed the `images` slots; both outputs replace the conditioning into the sampler.

### Hunyuan3Dv2Conditioning  (display: "Hunyuan3Dv2Conditioning")
- **pack / source:** core ComfyUI (`nodes`) | **category:** `model/conditioning/3d_models` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** turn a CLIP-Vision embedding of a reference image into the positive/negative conditioning a Hunyuan3D v2 model uses to generate a 3D shape from that image.
- **inputs:**
  - `clip_vision_output` (`CLIP_VISION_OUTPUT`) - the encoded reference image (from `CLIPVisionEncode`); this is the single view the 3D model conditions on.
- **outputs:**
  - `positive` (`CONDITIONING`) - the positive conditioning for the Hunyuan3D v2 sampler.
  - `negative` (`CONDITIONING`) - the negative conditioning (the node emits both from the one image embedding).
- **how it works:** wraps the CLIP-Vision embedding into the conditioning pair Hunyuan3D v2 expects, so the 3D sampler generates geometry consistent with the input image. Exact internal construction inferred from the I/O and node family; confirm against source if load-bearing.
- **strengths:** the minimal single-image entry to Hunyuan3D v2 conditioning; emits both branches from one embedding so there is nothing else to wire on the conditioning side.
- **bugs / lags + fixes:** none known. A CLIP-Vision model that does not match what Hunyuan3D v2 expects gives poor geometry.
- **anti-patterns:** feeding it a text `CONDITIONING` or a raw `IMAGE` (it needs a `CLIP_VISION_OUTPUT`). For multiple views use `Hunyuan3Dv2ConditioningMultiView` instead.
- **placement:** after `CLIPVisionEncode`, before the Hunyuan3D v2 sampler. One image embedding in, a conditioning pair out.

### Hunyuan3Dv2ConditioningMultiView  (display: "Hunyuan3Dv2ConditioningMultiView")
- **pack / source:** core ComfyUI (`nodes`) | **category:** `model/conditioning/3d_models` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** build Hunyuan3D v2 conditioning from up to four orthographic views (front, left, back, right) of a subject, for more consistent 3D generation than a single image allows.
- **inputs:**
  - `front` (`CLIP_VISION_OUTPUT`, optional) - encoded front view.
  - `left` (`CLIP_VISION_OUTPUT`, optional) - encoded left view.
  - `back` (`CLIP_VISION_OUTPUT`, optional) - encoded back view.
  - `right` (`CLIP_VISION_OUTPUT`, optional) - encoded right view.
  - All four are optional, so you can supply any subset (for example front only, or front and back); each is the `CLIP_VISION_OUTPUT` of that view from `CLIPVisionEncode`.
- **outputs:**
  - `positive` (`CONDITIONING`) - positive conditioning combining the supplied views.
  - `negative` (`CONDITIONING`) - the negative branch.
- **how it works:** merges the per-view CLIP-Vision embeddings into one conditioning pair so Hunyuan3D v2 reconstructs geometry consistent across the given viewpoints. Exact merge inferred from the I/O and node name; confirm against source if load-bearing.
- **strengths:** multi-view conditioning gives the 3D model more to anchor on than a single image, reducing back/side guesswork. Optional inputs make it usable with whatever views you have.
- **bugs / lags + fixes:** none known. Views that disagree (different subject, scale, or lighting) can confuse reconstruction.
- **anti-patterns:** supplying mismatched views, or views from a non-matching CLIP-Vision model. Using it when you only have one image (the single-view `Hunyuan3Dv2Conditioning` is simpler).
- **placement:** after one `CLIPVisionEncode` per view, before the Hunyuan3D v2 sampler. Several image embeddings in, one conditioning pair out.

### TextEncodeAceStepAudio  (display: "TextEncodeAceStepAudio")
- **pack / source:** core ComfyUI (`nodes`) | **category:** `model/conditioning` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** encode ACE-Step music conditioning, combining a tag prompt (genre, mood, instrumentation) and lyrics into CONDITIONING for an ACE-Step audio model.
- **inputs:**
  - `clip` (`CLIP`) - the ACE-Step text encoder (loaded as a CLIP-type object) that encodes the tags and lyrics.
  - `tags` (`STRING`) - the style/description prompt: genre, mood, instruments, tempo words, and so on.
  - `lyrics` (`STRING`) - the lyrics to sing/perform.
  - `lyrics_strength` (`FLOAT`, default 1.0) - how strongly the lyrics weigh against the tags; lower to make lyrics looser.
- **outputs:**
  - `CONDITIONING` (`CONDITIONING`) - the ACE-Step audio conditioning; feeds the sampler in an ACE-Step graph.
- **how it works:** encodes tags and lyrics through the ACE-Step text encoder and combines them (with `lyrics_strength` weighting the lyric contribution) into the conditioning the audio model samples from.
- **strengths:** the dedicated text-to-music conditioner for ACE-Step; separating tags from lyrics with a strength knob is exactly the control music generation needs.
- **bugs / lags + fixes:** none known.
- **anti-patterns:** using it with a non-ACE-Step model. Feeding a normal SD CLIP where the ACE-Step encoder is required. For the newer 1.5 line with explicit tempo/key/duration controls, use `TextEncodeAceStepAudio1.5`.
- **placement:** the conditioning root of an ACE-Step audio graph. An ACE-Step CLIP feeds it; its `CONDITIONING` feeds the audio sampler.

### TextEncodeAceStepAudio1.5  (display: "TextEncodeAceStepAudio1.5")
- **pack / source:** core ComfyUI (`nodes`) | **category:** `model/conditioning` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** encode ACE-Step 1.5 music conditioning with far more musical control than the original node: tags, lyrics, tempo, key, time signature, language, duration, and the sampling parameters for the audio-code LLM.
- **inputs:**
  - `clip` (`CLIP`) - the ACE-Step 1.5 text encoder.
  - `tags` (`STRING`) - the style/description prompt.
  - `lyrics` (`STRING`) - the lyrics.
  - `seed` (`INT`, default 0) - seed for the audio-code generation step.
  - `bpm` (`INT`, default 120) - target tempo in beats per minute.
  - `duration` (`FLOAT`, default 120.0) - target length of the piece in seconds.
  - `timesignature` (`COMBO`) - a dropdown of supported time signatures (for example common-time options).
  - `language` (`COMBO`, default `en`) - a dropdown of supported lyric languages.
  - `keyscale` (`COMBO`) - a dropdown of musical key/scale options.
  - `generate_audio_codes` (`BOOLEAN`) - per the node's own description, enables the LLM that generates audio codes: slower but higher quality; turn it off when you are giving the model an audio reference (the description is truncated in the pull at "if you are giving the model an a", read the full tooltip in the UI). 
  - `cfg_scale` (`FLOAT`, default 2.0) - classifier-free guidance scale for the audio-code LLM.
  - `temperature` (`FLOAT`, default 0.85) - sampling temperature for the audio-code LLM.
  - `top_p` (`FLOAT`, default 0.9) - nucleus-sampling cutoff for the LLM.
  - `top_k` (`INT`, default 0) - top-k cutoff (0 = disabled).
  - `min_p` (`FLOAT`, default 0.0) - minimum-probability cutoff (0 = disabled).
- **outputs:**
  - `CONDITIONING` (`CONDITIONING`) - the ACE-Step 1.5 audio conditioning; feeds the sampler.
- **how it works:** encodes the tags and lyrics with the 1.5 encoder and, when `generate_audio_codes` is on, runs an LLM (controlled by the cfg/temperature/top_p/top_k/min_p sampling block) to produce audio codes, packaging everything plus the musical metadata (bpm, key, time signature, duration, language) into the conditioning. Behavior summarized from the node's own field descriptions; the exact internal pipeline is inferred, confirm against source if load-bearing.
- **strengths:** the most controllable music conditioner in this set: explicit tempo, key, time signature, duration and language, plus a full LLM sampling block. The `generate_audio_codes` toggle trades speed for quality and supports reference-guided generation.
- **bugs / lags + fixes:** none known. Leaving `generate_audio_codes` on is slow per its own description; turn it off when supplying an audio reference.
- **anti-patterns:** using it with the original ACE-Step model that does not expect the 1.5 controls (and vice versa, the older `TextEncodeAceStepAudio` for the v1 model). Pushing temperature/top_p to extremes and expecting coherent music. Treating `duration` as a hard cut rather than a target.
- **placement:** the conditioning root of an ACE-Step 1.5 audio graph. The 1.5 CLIP feeds it; its `CONDITIONING` feeds the audio sampler.

### AudioEncoderEncode  (display: "AudioEncoderEncode")
- **pack / source:** core ComfyUI (`nodes`) | **category:** `model/conditioning` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** encode an audio clip through an audio encoder into an AUDIO_ENCODER_OUTPUT embedding, the audio equivalent of `CLIPVisionEncode` for images. Used to condition models on a reference sound (for example audio-driven video or audio-reference music).
- **inputs:**
  - `audio_encoder` (`AUDIO_ENCODER`) - the loaded audio encoder model (from its loader).
  - `audio` (`AUDIO`) - the audio clip to encode.
- **outputs:**
  - `AUDIO_ENCODER_OUTPUT` (`AUDIO_ENCODER_OUTPUT`) - the audio embedding; consumed by whatever model node accepts audio conditioning.
- **how it works:** runs the audio through the encoder and returns the embedding as an `AUDIO_ENCODER_OUTPUT`. The exact consumer depends on the model recipe; confirm which node accepts this type in the workflow you are building.
- **strengths:** the single source of audio embeddings, mirroring the CLIP-Vision pattern; keeps audio conditioning out of the model nodes and in one reusable place.
- **bugs / lags + fixes:** none known.
- **anti-patterns:** wiring `AUDIO_ENCODER_OUTPUT` into a node that does not consume that type. Pairing an audio encoder with a downstream model that expects a different encoder. Feeding it where an `AUDIO` (raw clip) is wanted instead of the embedding.
- **placement:** a near-leaf in the conditioning area. An audio-encoder loader feeds `audio_encoder`, an audio source feeds `audio`, and the output goes to the model node that consumes audio conditioning.
