# Conditioning (part 2)

The Wan video-model conditioning family, plus `unCLIPConditioning`. These are not text encoders; they sit
*after* the text encoders and *before* the sampler. Each Wan node takes the already-encoded `positive` /
`negative` CONDITIONING plus a `VAE`, folds image / control / audio / track signals into that conditioning,
allocates the video latent at `width x height x length` frames, and hands back modified `positive` /
`negative` and a `LATENT`. In a Wan graph these replace `EmptyLatentImage`: the node that builds the latent is
the same node that injects the per-frame guidance, so the two stay in sync. Pick the node by what is driving
the motion (a start frame, a first+last pair, a control video, a camera path, audio, or motion tracks); the
wiring downstream (into KSampler `model` / `positive` / `negative` / `latent_image`) is identical across the
family.

All I/O below is **confirmed via get_node_info: 2026-06-30** (ComfyUI 0.25.1) from the provided /object_info
pull; the semantics, mechanism, placement, and gotchas are the curated layer. Every Wan node here reports
`display_name: null`, so ComfyUI shows the class name verbatim as the node title (confirmed via get_node_info:
2026-06-30). Inputs typed `COMBO` are enumerations resolved by the running server; where a combo is a list of
files it is described as "a dropdown of installed <thing>", never hardcoded. These nodes are core ComfyUI
(native `comfy_extras` / `nodes`), not a custom pack.

A note on confidence: the family-level pattern (encode the reference frames through the VAE, concatenate them
into the conditioning, size the latent to the requested frame count) is the established Wan I2V design and is
stated plainly. Where a single scalar's exact effect is not something the I/O pull proves (for example the
`temperature` / `topk` on `WanTrackToVideo`, or the precise loop bookkeeping inside `WanInfiniteTalkToVideo`),
it is marked inferred with what would confirm it.

---

### WanImageToVideo  (display: "WanImageToVideo")
- **pack / source:** core ComfyUI (`comfy_extras`) | **category:** `model/conditioning/video_models` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** the canonical Wan image-to-video conditioner. Takes a start frame and builds the conditioning + latent for a Wan I2V generation that animates outward from that frame.
- **inputs:**
  - `positive` (`CONDITIONING`) - the encoded positive prompt (from the Wan text encoder). The node returns a modified copy with the image guidance folded in; do not feed the raw encoder output straight to the sampler, route it through here first.
  - `negative` (`CONDITIONING`) - the encoded negative prompt, modified the same way.
  - `vae` (`VAE`) - the Wan VAE, used to encode `start_image` into latent space so it can be concatenated into the conditioning. Must be the Wan VAE, not an SD / SDXL one.
  - `width` / `height` (`INT`, default 832 / 480) - output frame size. Wan 2.1 480p models target 832x480; 720p variants want a larger size. Off-native sizes degrade motion and identity.
  - `length` (`INT`, default 81) - number of frames. Wan's native clip length is 81 (about 5s at 16fps). The model is trained at this length; large departures hurt coherence.
  - `batch_size` (`INT`, default 1) - clips per run.
  - `clip_vision_output` (`CLIP_VISION_OUTPUT`, optional) - CLIP-vision features of the start image, for models that take an image-embedding stream alongside the latent. Produced by a CLIP vision encoder on the same start frame.
  - `start_image` (`IMAGE`, optional) - the first frame to animate from. Optional in the schema, but this is an image-to-video node; with no start image you get a text-to-video result and the node's reason for existing is gone.
- **outputs:**
  - `positive` (`CONDITIONING`) - conditioning with the start-frame latent concatenated in; wire to `KSampler.positive`.
  - `negative` (`CONDITIONING`) - matching negative; wire to `KSampler.negative`.
  - `latent` (`LATENT`) - the empty video latent sized to `width x height x length`; wire to `KSampler.latent_image`. This replaces `EmptyLatentImage` for Wan.
- **how it works:** VAE-encodes `start_image` (and optionally its CLIP-vision features) and concatenates that into the positive / negative conditioning, then allocates a latent of the requested frame geometry for the sampler to denoise. The start frame anchors frame 0; the prompt drives what happens after.
- **strengths:** the default, lowest-friction Wan I2V path. One node produces all three sampler inputs at the correct shapes, so the latent and the conditioning can never disagree on size.
- **bugs / lags + fixes:** none known in the node. Wan video generation is VRAM-heavy and slow; that is the model, not this node. Wrong `width` / `height` / `length` versus the model's training point is the usual quality complaint.
- **anti-patterns:** feeding a non-Wan VAE or non-Wan conditioning (the latent space and the concat layout are Wan-specific). Using `EmptyLatentImage` in parallel and ignoring this node's `latent` output, then wondering why the start frame has no effect. Pushing `length` far past native and expecting clean long video, use a dedicated long-video / context-window path instead.
- **placement:** between the Wan text encoders (and an optional CLIP vision encoder on the start frame) and the KSampler. It is the Wan stand-in for `EmptyLatentImage`; everything it outputs feeds the sampler.

### WanFirstLastFrameToVideo  (display: "WanFirstLastFrameToVideo")
- **pack / source:** core ComfyUI (`comfy_extras`) | **category:** `model/conditioning/video_models` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** interpolate a Wan clip between a known first frame and a known last frame, generating the in-between motion.
- **inputs:**
  - `positive` / `negative` (`CONDITIONING`) - encoded prompts, returned modified.
  - `vae` (`VAE`) - Wan VAE, encodes both endpoint frames.
  - `width` / `height` (`INT`, default 832 / 480), `length` (`INT`, default 81), `batch_size` (`INT`, default 1) - same geometry meaning as `WanImageToVideo`.
  - `clip_vision_start_image` (`CLIP_VISION_OUTPUT`, optional) - CLIP-vision features for the first frame.
  - `clip_vision_end_image` (`CLIP_VISION_OUTPUT`, optional) - CLIP-vision features for the last frame.
  - `start_image` (`IMAGE`, optional) - frame 0 of the clip.
  - `end_image` (`IMAGE`, optional) - the final frame the clip must arrive at.
- **outputs:**
  - `positive` / `negative` (`CONDITIONING`) - endpoint frames concatenated into the conditioning.
  - `latent` (`LATENT`) - video latent for the sampler.
- **how it works:** encodes both endpoint frames into latent space and pins them at the two ends of the clip, leaving the sampler to fill the trajectory between them under the prompt. The first and last frames are fixed constraints; the prompt describes the path.
- **strengths:** the right node when you have both endpoints and want controlled interpolation (a clean loop, a precise start-to-end transition) rather than open-ended animation.
- **bugs / lags + fixes:** none known. Endpoints that are too dissimilar for the frame budget produce a rushed or morphy middle; raise `length` or pick closer endpoints.
- **anti-patterns:** giving only a start frame (then `WanImageToVideo` is the simpler, correct node). Endpoints from different scenes / subjects where no plausible interpolation exists.
- **placement:** same slot as `WanImageToVideo`; feeds the KSampler. Optionally fed by two CLIP-vision encoders, one per endpoint.

### WanFunControlToVideo  (display: "WanFunControlToVideo")
- **pack / source:** core ComfyUI (`comfy_extras`) | **category:** `model/conditioning/video_models` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** drive a Wan "Fun-Control" generation with a control video (pose / depth / edge sequence), optionally anchored by a start frame.
- **inputs:**
  - `positive` / `negative` (`CONDITIONING`) - encoded prompts, returned modified.
  - `vae` (`VAE`) - Wan VAE; encodes the start image and the control video frames.
  - `width` / `height` / `length` / `batch_size` (`INT`, defaults 832 / 480 / 81 / 1) - clip geometry.
  - `clip_vision_output` (`CLIP_VISION_OUTPUT`, optional) - CLIP-vision features of the start frame.
  - `start_image` (`IMAGE`, optional) - first frame to anchor identity / appearance.
  - `control_video` (`IMAGE`, optional) - the per-frame control sequence (a batch of frames) the motion follows. This is the steering signal for Fun-Control models.
- **outputs:**
  - `positive` / `negative` (`CONDITIONING`) - control + start frame concatenated in.
  - `latent` (`LATENT`) - video latent.
- **how it works:** encodes the control-video frames through the VAE and folds them into the conditioning so the Wan Fun-Control checkpoint follows that motion, while `start_image` anchors the look. Pairs with a Wan **Fun-Control** model specifically.
- **strengths:** motion transfer for the Wan Fun family without a separate ControlNet node; control and latent built together at matching length.
- **bugs / lags + fixes:** none known. A `control_video` whose frame count does not match `length` is the common setup error; align them.
- **anti-patterns:** using it with a plain Wan checkpoint (Fun-Control conditioning needs a Fun-Control model). Confusing it with `WanVaceToVideo` (VACE is a different control family with masks and a strength control). Treating `control_video` as a reference still image, it is a frame sequence.
- **placement:** between the encoders and the sampler, with the control-frame sequence wired into `control_video`. Requires a Wan Fun-Control diffusion model on the MODEL line.

### Wan22FunControlToVideo  (display: "Wan22FunControlToVideo")
- **pack / source:** core ComfyUI (`comfy_extras`) | **category:** `model/conditioning/video_models` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** the Wan 2.2 Fun-Control conditioner. Same role as `WanFunControlToVideo` but for the 2.2 Fun-Control models.
- **inputs:**
  - `positive` / `negative` (`CONDITIONING`), `vae` (`VAE`) - as in the rest of the family.
  - `width` / `height` / `length` / `batch_size` (`INT`, defaults 832 / 480 / 81 / 1) - clip geometry.
  - `ref_image` (`IMAGE`, optional) - a reference frame for appearance / identity (named `ref_image` here, distinct from the `start_image` used by the 2.1 Fun-Control node).
  - `control_video` (`IMAGE`, optional) - the per-frame control sequence the motion follows.
- **outputs:**
  - `positive` / `negative` (`CONDITIONING`) - reference + control concatenated in.
  - `latent` (`LATENT`) - video latent.
- **how it works:** the 2.2 Fun-Control variant of the same encode-and-concat mechanism. Note this node exposes no `clip_vision_output` input, unlike the 2.1 node; the 2.2 Fun-Control path conditions on `ref_image` + `control_video` directly (confirmed via the I/O pull).
- **strengths:** correct conditioner for Wan 2.2 Fun-Control; leaner input set than the 2.1 node.
- **bugs / lags + fixes:** none known.
- **anti-patterns:** pairing it with a 2.1 (or non-Fun) model; the conditioning layout is matched to the 2.2 Fun-Control architecture. Expecting a `clip_vision` input, it has none here.
- **placement:** same slot as the other Fun-Control node; requires a Wan 2.2 Fun-Control model.

### WanFunInpaintToVideo  (display: "WanFunInpaintToVideo")
- **pack / source:** core ComfyUI (`comfy_extras`) | **category:** `model/conditioning/video_models` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** the Wan Fun-Inpaint conditioner: generate the Wan clip between a start frame and an end frame for the Fun family. The Fun-model counterpart to `WanFirstLastFrameToVideo`.
- **inputs:**
  - `positive` / `negative` (`CONDITIONING`), `vae` (`VAE`) - family-standard.
  - `width` / `height` / `length` / `batch_size` (`INT`, defaults 832 / 480 / 81 / 1) - clip geometry.
  - `clip_vision_output` (`CLIP_VISION_OUTPUT`, optional) - CLIP-vision features of the start frame.
  - `start_image` (`IMAGE`, optional) - the first frame.
  - `end_image` (`IMAGE`, optional) - the final frame the clip should reach.
- **outputs:**
  - `positive` / `negative` (`CONDITIONING`) - endpoint frames concatenated in.
  - `latent` (`LATENT`) - video latent.
- **how it works:** encodes the start (and end) frame into the conditioning for a Wan Fun-Inpaint model and sizes the latent, pinning the available endpoints so the model fills the gap. With only a start frame it behaves as Fun image-to-video; with both, as start-to-end interpolation.
- **strengths:** start / end interpolation on the Wan Fun models, with a single CLIP-vision input on the start frame.
- **bugs / lags + fixes:** none known. Requires a Wan Fun-Inpaint model.
- **anti-patterns:** pairing with a non-Fun (or Fun-Control rather than Fun-Inpaint) model. Confusing it with `WanFunControlToVideo` (that one follows a control video; this one fills between endpoints). Note it has only one `clip_vision_output` (for the start), unlike `WanFirstLastFrameToVideo` which has separate start and end CLIP-vision inputs.
- **placement:** between encoders and sampler; requires a Wan Fun-Inpaint model.

### WanVaceToVideo  (display: "WanVaceToVideo")
- **pack / source:** core ComfyUI (`comfy_extras`) | **category:** `model/conditioning/video_models` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** the Wan VACE conditioner: combined control-video + mask + reference-image control with an adjustable strength, for the VACE editing / control models.
- **inputs:**
  - `positive` / `negative` (`CONDITIONING`), `vae` (`VAE`) - family-standard.
  - `width` / `height` / `length` / `batch_size` (`INT`, defaults 832 / 480 / 81 / 1) - clip geometry.
  - `strength` (`FLOAT`, default 1.0) - how hard the VACE control is applied. Lower it to let the prompt deviate from the control; raise it to hold the control tightly.
  - `control_video` (`IMAGE`, optional) - the control frame sequence.
  - `control_masks` (`MASK`, optional) - per-frame masks selecting where the control applies (inpaint-style spatial restriction within the clip).
  - `reference_image` (`IMAGE`, optional) - an appearance / identity reference frame.
- **outputs:**
  - `positive` / `negative` (`CONDITIONING`) - VACE control concatenated in.
  - `latent` (`LATENT`) - video latent.
  - `trim_latent` (`INT`) - the number of latent frames to trim after sampling. VACE prepends reference latents that are not part of the final clip; this count tells a downstream trim / decode step how many leading latent frames to drop. Carry it forward, do not ignore it, or the reference frames leak into the output.
- **how it works:** encodes control video, masks, and reference into the conditioning for a VACE model, scaled by `strength`, and reports `trim_latent` so the prepended reference region can be removed before the final decode.
- **strengths:** the most capable Wan control conditioner here: masked, reference-guided, strength-tunable control in one node. The right choice for VACE editing / controlled regeneration.
- **bugs / lags + fixes:** none known in the node. The recurring user error is dropping `trim_latent`, which leaves reference frames in the decoded video; route it to whatever trims the latent / image.
- **anti-patterns:** pairing it with a non-VACE Wan model. Forgetting the `trim_latent` handoff. Feeding a `control_masks` batch whose frame count disagrees with `control_video` / `length`.
- **placement:** between encoders and sampler; requires a Wan VACE model. `trim_latent` flows to the post-sampling trim step.

### WanCameraImageToVideo  (display: "WanCameraImageToVideo")
- **pack / source:** core ComfyUI (`comfy_extras`) | **category:** `model/conditioning/video_models` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** image-to-video with explicit camera-motion control for Wan camera models. Adds a camera-trajectory input on top of the standard I2V conditioner.
- **inputs:**
  - `positive` / `negative` (`CONDITIONING`), `vae` (`VAE`) - family-standard.
  - `width` / `height` / `length` / `batch_size` (`INT`, defaults 832 / 480 / 81 / 1) - clip geometry. Keep these consistent with the size used to build the camera embedding.
  - `clip_vision_output` (`CLIP_VISION_OUTPUT`, optional) - CLIP-vision features of the start frame.
  - `start_image` (`IMAGE`, optional) - first frame.
  - `camera_conditions` (`WAN_CAMERA_EMBEDDING`, optional) - the camera trajectory, produced by `WanCameraEmbedding`. This is what makes it a camera-controlled generation; without it the node behaves like plain I2V.
- **outputs:**
  - `positive` / `negative` (`CONDITIONING`) - start frame + camera path concatenated in.
  - `latent` (`LATENT`) - video latent.
- **how it works:** the standard I2V encode-and-concat, plus it injects the `WAN_CAMERA_EMBEDDING` so the camera-aware Wan model moves the virtual camera along the requested path.
- **strengths:** deterministic camera moves (orbit, push-in, pan) instead of hoping the prompt produces them. One node ties the start frame and the camera path to a correctly sized latent.
- **bugs / lags + fixes:** none known. Geometry mismatch between this node and `WanCameraEmbedding` is the trap; build the embedding at the same `width` / `height` / `length`.
- **anti-patterns:** pairing with a non-camera Wan model (the `WAN_CAMERA_EMBEDDING` has nowhere to act). Mismatched dimensions between the embedding and this node.
- **placement:** between encoders and sampler; `WanCameraEmbedding` feeds `camera_conditions`. Requires a Wan camera-control model.

### WanCameraEmbedding  (display: "WanCameraEmbedding")
- **pack / source:** core ComfyUI (`comfy_extras`) | **category:** `model/conditioning/video_models` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** build a camera-motion trajectory (the `WAN_CAMERA_EMBEDDING`) that `WanCameraImageToVideo` consumes. This is the camera-path source, not a conditioner itself.
- **inputs:**
  - `camera_pose` (`COMBO`, default "Static") - a dropdown of preset camera moves (the running server enumerates the choices; the default is a static, non-moving camera). Pick the named move you want.
  - `width` / `height` (`INT`, default 832 / 480), `length` (`INT`, default 81) - the geometry the trajectory is generated for. Match these to the `WanCameraImageToVideo` node that consumes the embedding.
  - `speed` (`FLOAT`, default 1.0, optional) - how fast the camera travels along the chosen path.
  - `fx` / `fy` (`FLOAT`, default 0.5, optional) - focal-length parameters of the virtual camera.
  - `cx` / `cy` (`FLOAT`, default 0.5, optional) - principal-point (optical-center) parameters.
- **outputs:**
  - `camera_embedding` (`WAN_CAMERA_EMBEDDING`) - the per-frame camera trajectory; feeds `WanCameraImageToVideo.camera_conditions`.
  - `width` / `height` / `length` (`INT`) - the geometry passed straight through, convenient for wiring the same numbers into the consuming node so the two cannot drift apart.
- **how it works:** synthesizes a camera path from the chosen preset, speed, and intrinsics (`fx` / `fy` / `cx` / `cy`) at the requested clip geometry, and emits it as a typed embedding plus the geometry it was built for. The `fx` / `fy` / `cx` / `cy` defaults of 0.5 read as normalized intrinsics; their precise scaling is inferred (the I/O pull confirms names and defaults, not the exact projection math), confirm against the node source if you need exact focal behavior.
- **strengths:** named, repeatable camera moves with tunable speed and lens intrinsics; passes geometry through so the consumer stays in sync.
- **bugs / lags + fixes:** none known.
- **anti-patterns:** feeding its embedding into anything but a Wan camera node (the `WAN_CAMERA_EMBEDDING` type only fits there). Building it at a different size than the consuming node.
- **placement:** a source node feeding `WanCameraImageToVideo`. Nothing model-side feeds it; it is configured by its widgets.

### WanSoundImageToVideo  (display: "WanSoundImageToVideo")
- **pack / source:** core ComfyUI (`comfy_extras`) | **category:** `model/conditioning/video_models` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** audio-driven Wan video: condition the generation on an encoded audio track (plus optional reference frame, control video, and motion reference) for sound-synced output such as talking / performance.
- **inputs:**
  - `positive` / `negative` (`CONDITIONING`), `vae` (`VAE`) - family-standard.
  - `width` / `height` (`INT`, default 832 / 480), `length` (`INT`, default 77), `batch_size` (`INT`, default 1) - clip geometry. Note the default `length` here is 77, not 81.
  - `audio_encoder_output` (`AUDIO_ENCODER_OUTPUT`, optional) - the encoded audio features that drive timing / lip motion. Produced by an audio encoder node upstream. This is the point of the node; without it you lose the sound conditioning.
  - `ref_image` (`IMAGE`, optional) - appearance / identity reference frame.
  - `control_video` (`IMAGE`, optional) - optional per-frame control sequence.
  - `ref_motion` (`IMAGE`, optional) - a motion reference (frames describing the desired movement style).
- **outputs:**
  - `positive` / `negative` (`CONDITIONING`) - audio + image references concatenated in.
  - `latent` (`LATENT`) - video latent.
- **how it works:** folds the encoded audio (and any reference / control frames) into the conditioning so a sound-capable Wan model syncs motion to the audio. The exact alignment between audio features and frames is handled by the model; this node supplies the encoded streams and the latent.
- **strengths:** audio-synced video from a single conditioner, with optional appearance and motion references.
- **bugs / lags + fixes:** none known. Requires a Wan model trained for audio conditioning; on a plain Wan model the `audio_encoder_output` is ignored.
- **anti-patterns:** using it with a non-audio Wan checkpoint. Assuming `length` defaults to 81 here (it is 77). Confusing `ref_image` (look) with `ref_motion` (movement style).
- **placement:** between encoders and sampler; an audio encoder feeds `audio_encoder_output`. Requires a sound-capable Wan model.

### WanHuMoImageToVideo  (display: "WanHuMoImageToVideo")
- **pack / source:** core ComfyUI (`comfy_extras`) | **category:** `model/conditioning/video_models` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** the Wan HuMo (human-motion / audio) image-to-video conditioner: a reference frame plus optional encoded audio for human-centric, optionally sound-driven generation.
- **inputs:**
  - `positive` / `negative` (`CONDITIONING`), `vae` (`VAE`) - family-standard.
  - `width` / `height` (`INT`, default 832 / 480), `length` (`INT`, default 97), `batch_size` (`INT`, default 1) - clip geometry. Default `length` here is 97.
  - `audio_encoder_output` (`AUDIO_ENCODER_OUTPUT`, optional) - encoded audio features, for sound-driven HuMo runs.
  - `ref_image` (`IMAGE`, optional) - the reference / identity frame.
- **outputs:**
  - `positive` / `negative` (`CONDITIONING`) - reference (and audio) concatenated in.
  - `latent` (`LATENT`) - video latent.
- **how it works:** the HuMo variant of the encode-and-concat conditioner, accepting an optional audio stream. Built for the Wan HuMo model family.
- **strengths:** human-motion-focused conditioning with optional audio in one node.
- **bugs / lags + fixes:** none known. The HuMo behavior depends on a matching HuMo model.
- **anti-patterns:** pairing with a non-HuMo Wan model. Assuming the standard 81-frame default (it is 97).
- **placement:** between encoders and sampler; optional audio encoder feeds `audio_encoder_output`. Requires a Wan HuMo model.

### WanInfiniteTalkToVideo  (display: "WanInfiniteTalkToVideo")
- **pack / source:** core ComfyUI (`comfy_extras`) | **category:** `model/conditioning/video_models` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** the InfiniteTalk conditioner for arbitrarily long audio-driven (talking) video, generated chunk by chunk with motion carried across chunks. Unlike the rest of the family it also takes and returns the `MODEL`, and it patches it.
- **inputs:**
  - `mode` (`COMFY_DYNAMICCOMBO_V3`) - a dynamic-combo mode selector (the running server resolves the choices). It changes which downstream inputs are active; read the live options on the node rather than assuming a fixed set.
  - `model` (`MODEL`) - the Wan diffusion model, taken in so the node can patch it for the InfiniteTalk / chunked path and return it.
  - `model_patch` (`MODEL_PATCH`) - a model-patch object the node applies (the InfiniteTalk patch). Required.
  - `positive` / `negative` (`CONDITIONING`), `vae` (`VAE`) - family-standard.
  - `width` / `height` (`INT`, default 832 / 480), `length` (`INT`, default 81) - geometry of one chunk.
  - `audio_encoder_output_1` (`AUDIO_ENCODER_OUTPUT`, required) - the encoded audio driving the talk; required here (the `_1` suffix implies the design anticipates multiple audio sources / speakers).
  - `motion_frame_count` (`INT`) - number of previous frames used as motion context for the next chunk (the note in the I/O pull states exactly this). Higher gives smoother continuity between chunks at more compute.
  - `audio_scale` (`FLOAT`, default 1.0) - how strongly the audio drives the motion.
  - `clip_vision_output` (`CLIP_VISION_OUTPUT`, optional) - CLIP-vision features of the start frame.
  - `start_image` (`IMAGE`, optional) - first frame.
  - `previous_frames` (`IMAGE`, optional) - the tail frames of the prior chunk, fed back in to continue a long sequence seamlessly.
- **outputs:**
  - `model` (`MODEL`) - the patched model; wire this to `KSampler.model` (not the un-patched one).
  - `positive` / `negative` (`CONDITIONING`) - conditioning for the chunk.
  - `latent` (`LATENT`) - the chunk's video latent.
  - `trim_image` (`INT`) - how many leading frames to trim from the decoded chunk (the motion-context frames that overlap the previous chunk and must not be duplicated in the stitched result). Carry it to the trim / stitch step.
- **how it works:** patches the model via `model_patch`, conditions a single chunk on the audio and (optionally) the carried-over `previous_frames` / motion context, and emits the patched model, the chunk conditioning, the chunk latent, and a `trim_image` count for stitching. Long video is produced by running the node per chunk and feeding each chunk's tail back as `previous_frames`. The precise chunk-stitching loop (how `motion_frame_count`, `previous_frames`, and `trim_image` interlock across iterations) is inferred from the input notes and names; the I/O pull confirms the ports and the `motion_frame_count` description but not the full iteration logic. Confirm against the node source / an official InfiniteTalk workflow before relying on exact counts.
- **strengths:** the path to long, continuous, audio-synced talking video with cross-chunk motion continuity. Bundles the model patch, so you do not wire a separate patch node.
- **bugs / lags + fixes:** none known, but this is the most complex node in the slice and the one most likely to be set up wrong. Two recurring traps: wiring the *un-patched* model to the sampler instead of this node's `model` output, and dropping `trim_image` so overlap frames duplicate at chunk seams.
- **anti-patterns:** ignoring the returned `model` (the InfiniteTalk patch then never reaches the sampler). Skipping `previous_frames` when extending a sequence (you get independent, discontinuous chunks). Treating it like a single-shot I2V node.
- **placement:** between encoders and sampler, but it also sits *on* the MODEL line: model in, patched model out to the sampler. An audio encoder feeds `audio_encoder_output_1`; on continuation chunks, the previous chunk's tail frames feed `previous_frames`. Requires the InfiniteTalk model patch.

### WanTrackToVideo  (display: "WanTrackToVideo")
- **pack / source:** core ComfyUI (`comfy_extras`) | **category:** `model/conditioning/video_models` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** motion-track (trajectory) controlled Wan video: drive the animation with point tracks plus a start frame, for the Wan "Move" / track-conditioned models.
- **inputs:**
  - `positive` / `negative` (`CONDITIONING`), `vae` (`VAE`) - family-standard.
  - `tracks` (`STRING`, default `[]`) - the motion tracks as a serialized string (a JSON-style list of point trajectories). Typically produced by a track-builder node (see `WanMoveTracksFromCoords`) and passed in as text. An empty `[]` means no tracks (no track control).
  - `width` / `height` (`INT`, default 832 / 480), `length` (`INT`, default 81), `batch_size` (`INT`, default 1) - clip geometry.
  - `temperature` (`FLOAT`, default 220.0) - a sampling-temperature parameter for how the track guidance is applied. The large default (220.0) is distinctive; its exact effect on track adherence is inferred (the I/O pull confirms the name and default, not the mechanism). Confirm against the node source before tuning it blindly.
  - `topk` (`INT`, default 2) - a top-k parameter paired with `temperature` in the track-guidance step; exact effect inferred, same caveat.
  - `start_image` (`IMAGE`, required) - the first frame. Required here, unlike the optional `start_image` on the plain I2V node.
  - `clip_vision_output` (`CLIP_VISION_OUTPUT`, optional) - CLIP-vision features of the start frame.
- **outputs:**
  - `positive` / `negative` (`CONDITIONING`) - tracks + start frame concatenated in.
  - `latent` (`LATENT`) - video latent.
- **how it works:** parses the `tracks` string into point trajectories, conditions a track-aware Wan model on them (modulated by `temperature` / `topk`), and anchors the start frame. The model moves image content along the supplied tracks.
- **strengths:** explicit trajectory control (drag a point along a path) rather than prompt-only motion. Pairs with the `WanMove*` helper nodes that build and visualize tracks.
- **bugs / lags + fixes:** none known. The `temperature` / `topk` defaults are unusual; leave them at default unless you have a reason and have checked their meaning.
- **anti-patterns:** pairing with a non-track Wan model. Hand-authoring the `tracks` string when the `WanMove*` helpers can build it. Omitting `start_image` (it is required here).
- **placement:** between encoders and sampler; a track-builder (`WanMoveTracksFromCoords` / `WanMoveConcatTrack`) feeds `tracks` (as a string). Requires a track-conditioned Wan model.

### WanMoveTracksFromCoords  (display: "WanMoveTracksFromCoords")
- **pack / source:** core ComfyUI (`comfy_extras`) | **category:** `model/conditioning/video_models` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** build motion TRACKS from coordinate input (and an optional mask), the track-authoring source for the Wan Move / track pipeline.
- **inputs:**
  - `track_coords` (`STRING`, default `[]`, optional) - the coordinates / trajectories as a serialized string (a list of points over time). Empty `[]` yields no tracks.
  - `track_mask` (`MASK`, optional) - a mask that scopes which region the tracks apply to (or from which to derive them).
- **outputs:**
  - `TRACKS` (`TRACKS`) - the typed track object; feeds `WanMoveConcatTrack`, `WanMoveVisualizeTracks`, or (serialized) the track-conditioned video nodes.
  - `track_length` (`INT`) - the number of frames / length the tracks span; useful to match a clip's `length`.
- **how it works:** parses coordinates (optionally constrained by a mask) into a `TRACKS` object and reports its length. The exact coordinate string format is inferred from the type and default; confirm via the node source or an example workflow before authoring it by hand.
- **strengths:** turns plain coordinates into the typed `TRACKS` other Move nodes consume; reports length so you can size the clip to match.
- **bugs / lags + fixes:** none known.
- **anti-patterns:** hand-writing malformed coordinate strings. Expecting a previewable image from this node (use `WanMoveVisualizeTracks` for that).
- **placement:** a source feeding the rest of the Move chain (`WanMoveConcatTrack`, `WanMoveVisualizeTracks`, and ultimately the track-to-video node).

### WanMoveConcatTrack  (display: "WanMoveConcatTrack")
- **pack / source:** core ComfyUI (`comfy_extras`) | **category:** `model/conditioning/video_models` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** concatenate / combine two TRACKS objects into one, for composing multiple motion trajectories.
- **inputs:**
  - `tracks_1` (`TRACKS`, required) - the first track set.
  - `tracks_2` (`TRACKS`, optional) - a second track set to merge with the first.
- **outputs:**
  - `TRACKS` (`TRACKS`) - the combined tracks; feeds another Move node or the track-to-video conditioner.
- **how it works:** merges the two `TRACKS` inputs into a single `TRACKS` object. With only `tracks_1` wired it is effectively a passthrough.
- **strengths:** lets you build complex multi-point / multi-path motion from separately authored track sets.
- **bugs / lags + fixes:** none known.
- **anti-patterns:** using it where a single track set already suffices (unnecessary node). Feeding non-`TRACKS` data.
- **placement:** mid-chain in the Move pipeline, after one or two `WanMoveTracksFromCoords` and before visualize / the video node.

### WanMoveVisualizeTracks  (display: "WanMoveVisualizeTracks")
- **pack / source:** core ComfyUI (`comfy_extras`) | **category:** `model/conditioning/video_models` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** render motion TRACKS onto images as an overlay (points and connecting lines) so you can see the trajectories before committing them to a generation. A debugging / preview node.
- **inputs:**
  - `images` (`IMAGE`, required) - the frames to draw the tracks over (typically the source / start frames).
  - `line_resolution` (`INT`, default 24) - sampling resolution of the drawn track lines (how finely the path is rendered).
  - `circle_size` (`INT`, default 12) - radius of the point markers drawn at track points.
  - `opacity` (`FLOAT`, default 0.75) - opacity of the overlay.
  - `line_width` (`INT`, default 16) - thickness of the track lines.
  - `tracks` (`TRACKS`, optional) - the tracks to visualize; with none wired it returns the input images unchanged.
- **outputs:**
  - `IMAGE` (`IMAGE`) - the frames with the track overlay drawn on; send to a preview / save node.
- **how it works:** draws the supplied tracks over the input images using the given marker / line styling and opacity, and returns the annotated images. The exact units of `line_resolution` are inferred from the name; the styling intent (markers + lines + opacity) is clear from the input set.
- **strengths:** the only node here that lets you *see* the motion tracks; invaluable for sanity-checking trajectories before a slow generation.
- **bugs / lags + fixes:** none known.
- **anti-patterns:** wiring its annotated `IMAGE` into a generation as if it were a control input (it is a preview, not a control signal). Treating it as required in the pipeline (it is optional, for inspection).
- **placement:** a side branch off the track chain: tracks + source frames in, annotated frames out to `PreviewImage` / `SaveImage`. Not in the generation path.

### Wan22ImageToVideoLatent  (display: "Wan22ImageToVideoLatent")
- **pack / source:** core ComfyUI (`comfy_extras`) | **category:** `model/conditioning/inpaint` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** build just the Wan 2.2 image-to-video LATENT from a start image. Unlike the rest of the family it does not touch conditioning; it only prepares the latent (note its category is `model/conditioning/inpaint`, not `video_models`).
- **inputs:**
  - `vae` (`VAE`) - the Wan VAE, encodes `start_image` into the latent.
  - `width` / `height` (`INT`, default 1280 / 704), `length` (`INT`, default 49), `batch_size` (`INT`, default 1) - latent geometry. The defaults here (1280x704, 49 frames) differ from the 832x480 / 81 of the video_models nodes; these target Wan 2.2.
  - `start_image` (`IMAGE`, optional) - the first frame to encode into the latent.
- **outputs:**
  - `LATENT` (`LATENT`) - the video latent with the start frame encoded in; wire to `KSampler.latent_image`. There is no conditioning output.
- **how it works:** VAE-encodes the start image and packs it into a Wan 2.2 video latent of the requested geometry. The image guidance lives in the latent here, not in the conditioning, so the prompt conditioning is wired separately (straight from the text encoders to the sampler).
- **strengths:** minimal Wan 2.2 I2V latent prep; useful when the conditioning is built elsewhere and you only need the start-frame-seeded latent.
- **bugs / lags + fixes:** none known. Because it does not return conditioning, remember to wire the positive / negative conditioning to the sampler yourself.
- **anti-patterns:** expecting it to also modify conditioning (it does not, unlike `WanImageToVideo`). Using the video_models defaults (832x480 / 81) blindly; this node defaults to a different geometry for 2.2.
- **placement:** a latent source feeding `KSampler.latent_image` in a Wan 2.2 I2V graph; conditioning is wired to the sampler on a separate path.

### unCLIPConditioning  (display: "unCLIPConditioning")
- **pack / source:** core ComfyUI (`nodes`) | **category:** `model/conditioning` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** add image guidance from a CLIP-vision embedding to existing text conditioning, for unCLIP (image-variation) checkpoints. Lets an image steer generation alongside the text prompt.
- **inputs:**
  - `conditioning` (`CONDITIONING`, required) - the text conditioning to augment (from a CLIP text encoder).
  - `clip_vision_output` (`CLIP_VISION_OUTPUT`, required) - the CLIP-vision embedding of a reference image, from a CLIP vision encoder run on that image.
  - `strength` (`FLOAT`, default 1.0, range -10 to 10) - how strongly the image embedding influences the result (confirmed via get_node_info: 2026-06-30, min -10 / max 10 / step 0.01). Negative pushes away from the reference.
  - `noise_augmentation` (`FLOAT`, default 0.0, range 0 to 1) - how much noise to add to the image embedding before conditioning (confirmed via get_node_info: 2026-06-30, min 0 / max 1 / step 0.01). Higher loosens adherence to the reference, allowing more variation.
- **outputs:**
  - `CONDITIONING` (`CONDITIONING`) - the text conditioning with the image embedding merged in; feeds `KSampler.positive` (and can be chained for multiple reference images).
- **how it works:** attaches the CLIP-vision embedding (scaled by `strength`, optionally noised by `noise_augmentation`) to the conditioning so an unCLIP-capable model conditions on the reference image as well as the prompt.
- **strengths:** image-variation / image-prompting on unCLIP checkpoints; chainable for several reference images; `strength` and `noise_augmentation` give a clean variation-vs-fidelity dial.
- **bugs / lags + fixes:** none known. It only does something on an unCLIP model; on a normal SD checkpoint the CLIP-vision conditioning has nothing to act on.
- **anti-patterns:** using it with a non-unCLIP checkpoint (no effect, the model has no image-embedding path). Feeding a CLIP-vision output from a mismatched encoder. This is the legacy unCLIP path; for modern image-prompting prefer the model's own image-conditioning route (IP-Adapter, or a model with a native reference input).
- **placement:** between a CLIP text encoder and the sampler's positive input, with a CLIP vision encoder feeding `clip_vision_output`. Requires an unCLIP checkpoint on the MODEL line.
