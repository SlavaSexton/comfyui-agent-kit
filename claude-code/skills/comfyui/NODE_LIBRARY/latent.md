# Latent

The latent-space toolbox: nodes that allocate the empty latent a sampler denoises (one per model family, because each family fixes its own channel count and spatial/temporal compression), move latents back and forth across the VAE boundary (encode pixels/audio in, decode latents out), and splice or transform latents in place. All of these are core ComfyUI nodes shipped under `comfy_extras` (the model-family extras) or the base `nodes` module. None are third-party packs. I/O **confirmed via get_node_info on 2026-06-30** (ComfyUI 0.25.1). The two nodes already covered in `core.md` get a one-line pointer here, not a duplicate.

The pattern to remember: an Empty*Latent node is the txt2img/txt2video/txt2audio starting canvas and it must match the model loaded in the graph. Wiring an SD3 empty latent into a Flux sampler, or an SDXL `EmptyLatentImage` into a video model, produces shape errors or garbage because the latent channel layout differs per family. Pick the empty-latent node that matches the checkpoint.

---

### EmptyFlux2LatentImage  (display: "Empty Flux 2 Latent")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_flux`) | **category:** `model/latent` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** allocate the empty latent canvas for a Flux 2 text-to-image graph (sets output resolution).
- **inputs:**
  - `width` (`INT`, default 1024, step 16) - latent width in pixels. Step 16, so values snap to multiples of 16.
  - `height` (`INT`, default 1024, step 16) - latent height in pixels.
  - `batch_size` (`INT`, default 1) - images per run.
- **outputs:**
  - `LATENT` - the empty Flux 2 latent, feeds the sampler's `latent_image`.
- **how it works:** allocates a zero latent tensor shaped for the Flux 2 autoencoder (its own channel count and 16-px stride), ready to be denoised from seeded noise.
- **strengths:** the correct starting canvas for Flux 2 txt2img; one node sets resolution and batch.
- **bugs / lags + fixes:** none known.
- **anti-patterns:** do not feed a Flux 2 latent into a non-Flux-2 sampler, or the SDXL `EmptyLatentImage` into a Flux 2 sampler; the channel layouts differ and you get shape errors or garbage. For img2img encode a real image with `VAEEncode` instead of starting empty.
- **placement:** a leaf feeding only the sampler's `latent_image`. Pair with a Flux 2 checkpoint/UNet and the Flux text encoder.

### EmptySD3LatentImage  (display: "Empty SD3 Latent Image")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_sd3`) | **category:** `model/latent/sd3` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** allocate the empty latent canvas for a Stable Diffusion 3 / 3.5 text-to-image graph.
- **inputs:**
  - `width` (`INT`, default 1024, step 16) - latent width in pixels.
  - `height` (`INT`, default 1024, step 16) - latent height in pixels.
  - `batch_size` (`INT`, default 1) - images per run.
- **outputs:**
  - `LATENT` - the empty SD3 latent, feeds the sampler's `latent_image`.
- **how it works:** allocates a zero latent shaped for the SD3 16-channel VAE. SD3 uses 16 latent channels (versus 4 for SD1.5/SDXL), which is exactly why a dedicated empty-latent node exists instead of reusing `EmptyLatentImage`.
- **strengths:** the correct canvas for SD3 / SD3.5; trained around 1-megapixel area, so the 1024 default is on-distribution.
- **bugs / lags + fixes:** none known.
- **anti-patterns:** do not pair with an SD1.5/SDXL sampler (4-channel latent) or feed the 4-channel `EmptyLatentImage` into an SD3 sampler; channel-count mismatch fails. Encode real pixels with `VAEEncode` for SD3 img2img.
- **placement:** a leaf feeding only the sampler's `latent_image`, alongside an SD3 checkpoint and the SD3 text encoder (`TripleCLIPLoader` + `CLIPTextEncodeSD3` in a typical SD3 graph).

### EmptyHiDreamO1LatentImage  (display: "Empty HiDream-O1 Latent Image")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_hidream_o1`) | **category:** `model/latent/image` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** allocate the empty latent for HiDream-O1-Image, which is sensitive to resolution because it was trained at roughly 4 megapixels.
- **inputs:**
  - `width` (`INT`, default 2048, step 32, max 4096) - latent width in pixels.
  - `height` (`INT`, default 2048, step 32, max 4096) - latent height in pixels.
  - `batch_size` (`INT`, default 1) - images per run.
- **outputs:**
  - `LATENT` - the empty HiDream-O1 latent, feeds the sampler's `latent_image`.
- **how it works:** allocates a zero latent for the HiDream-O1 autoencoder. The node's own description (confirmed via get_node_info) states the model was trained at ~4 megapixels and lists its trained resolutions: 2048x2048, 2304x1728, 1728x2304, 2560x1440, 1440x2560, 2496x1664, 1664x2496, 3104x1312, 1312x3104, 2304x1792, 1792x2304.
- **strengths:** the right canvas for HiDream-O1; the 2048x2048 default is one of the trained resolutions, so the default is on-distribution.
- **bugs / lags + fixes:** none known as a node bug. Quality regression at low resolution is a model trait, not a node fault: per the node's description, dropping below the ~4 MP trained band goes off-distribution and quality drops noticeably. Fix is to stay on a listed resolution.
- **anti-patterns:** do not run this at small SDXL-style sizes (e.g. 1024x1024) expecting HiDream quality, it goes off-distribution. Do not feed into a non-HiDream sampler.
- **placement:** a leaf feeding only the HiDream-O1 sampler's `latent_image`, with the matching HiDream checkpoint and encoder.

### EmptyHunyuanVideo15Latent  (display: "Empty HunyuanVideo 1.5 Latent")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_hunyuan`) | **category:** `model/latent/video` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** allocate the empty video latent for HunyuanVideo 1.5 text-to-video (sets frame size and clip length).
- **inputs:**
  - `width` (`INT`, default 848, step 16) - frame width in pixels.
  - `height` (`INT`, default 480, step 16) - frame height in pixels.
  - `length` (`INT`, default 25, step 4) - number of frames. Stepped by 4 because the video VAE compresses along time; off-step lengths are invalid.
  - `batch_size` (`INT`, default 1) - clips per run.
- **outputs:**
  - `LATENT` - the empty video latent (carries a temporal dimension), feeds the sampler's `latent_image`.
- **how it works:** allocates a zero latent with a time axis sized for the HunyuanVideo 1.5 VAE's spatial and temporal compression, ready for the video sampler to denoise.
- **strengths:** the correct empty canvas for HunyuanVideo 1.5 txt2video; one node sets resolution, length, and batch.
- **bugs / lags + fixes:** none known. High `length` x resolution is the usual VRAM/time cost driver, not a node defect.
- **anti-patterns:** this is HunyuanVideo 1.5 specific. Do not mix it with the 1.0 model (use `EmptyHunyuanLatentVideo` for 1.0) or any image sampler; the temporal latent will not decode through an image VAE.
- **placement:** a leaf feeding the HunyuanVideo 1.5 sampler's `latent_image`. Decode with the matching video VAE; `TrimVideoLatent` can drop conditioning frames before decode.

### EmptyHunyuanLatentVideo  (display: "Empty HunyuanVideo 1.0 Latent")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_hunyuan`) | **category:** `model/latent/video` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** allocate the empty video latent for HunyuanVideo 1.0 text-to-video.
- **inputs:**
  - `width` (`INT`, default 848, step 16) - frame width in pixels.
  - `height` (`INT`, default 480, step 16) - frame height in pixels.
  - `length` (`INT`, default 25, step 4) - number of frames, stepped by 4 for the time-compressing VAE.
  - `batch_size` (`INT`, default 1) - clips per run.
- **outputs:**
  - `LATENT` - the empty video latent, feeds the sampler's `latent_image`.
- **how it works:** allocates a zero latent with a temporal axis for the HunyuanVideo 1.0 VAE.
- **strengths:** the correct empty canvas for HunyuanVideo 1.0 txt2video.
- **bugs / lags + fixes:** none known.
- **anti-patterns:** HunyuanVideo 1.0 specific. For the newer model use `EmptyHunyuanVideo15Latent`; the two video VAEs are not interchangeable. Not for image samplers.
- **placement:** a leaf feeding the HunyuanVideo 1.0 sampler's `latent_image`.

### EmptyLTXVLatentVideo  (display: "Empty LTXV Latent Video")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_lt`) | **category:** `model/latent/video/ltxv` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** allocate the empty video latent for LTX-Video (LTXV) text-to-video.
- **inputs:**
  - `width` (`INT`, default 768, step 32) - frame width in pixels (LTXV snaps to a 32-px grid).
  - `height` (`INT`, default 512, step 32) - frame height in pixels.
  - `length` (`INT`, default 97, step 8) - number of frames. Default 97 reflects LTXV's typical clip length; stepped by 8 for its temporal compression.
  - `batch_size` (`INT`, default 1) - clips per run.
- **outputs:**
  - `LATENT` - the empty LTXV video latent, feeds the LTXV sampler's `latent_image`.
- **how it works:** allocates a zero latent sized for LTXV's spatial (32-px) and temporal (8-frame) strides.
- **strengths:** the correct canvas for LTXV txt2video; defaults (768x512, 97 frames) are LTXV-native.
- **bugs / lags + fixes:** none known.
- **anti-patterns:** LTXV specific. Do not feed into a non-LTXV sampler or mix with HunyuanVideo latents. For LTXV image-to-video you condition differently rather than starting from a pure empty latent.
- **placement:** a leaf feeding the LTXV sampler's `latent_image`. Decode with the LTXV VAE.

### EmptyLatentHunyuan3Dv2  (display: "Empty Latent Hunyuan3Dv2")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_hunyuan3d`) | **category:** `model/latent/3d` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** allocate the empty latent for Hunyuan3D v2 (a 3D-shape generator), sized by a single resolution scalar rather than width x height.
- **inputs:**
  - `resolution` (`INT`, default 3072, max 8192) - the latent resolution for the 3D shape representation. One scalar, not a width/height pair, because the latent is not a 2D image grid.
  - `batch_size` (`INT`, default 1) - shapes per run.
- **outputs:**
  - `LATENT` - the empty Hunyuan3D v2 latent, feeds the Hunyuan3D sampler.
- **how it works:** allocates a zero latent for Hunyuan3D v2's shape-latent space at the given resolution.
- **strengths:** the correct empty canvas for Hunyuan3D v2 shape generation.
- **bugs / lags + fixes:** none known.
- **anti-patterns:** 3D pipeline only. This latent decodes to a `VOXEL` (via `VAEDecodeHunyuan3D`), not an image; do not route it to an image VAE or image sampler.
- **placement:** a leaf feeding the Hunyuan3D v2 sampler. The sampled latent is decoded by `VAEDecodeHunyuan3D` into a `VOXEL`, then meshed downstream.

### EmptyAceStep1.5LatentAudio  (display: "Empty Ace Step 1.5 Latent Audio")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_ace`) | **category:** `model/latent/audio` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** allocate the empty audio latent for ACE-Step 1.5 text-to-music/audio, sized by duration.
- **inputs:**
  - `seconds` (`FLOAT`, default 120.0, step 0.01) - target audio length in seconds. This sets the latent's time extent, the audio analogue of width/height.
  - `batch_size` (`INT`, default 1) - clips per run.
- **outputs:**
  - `LATENT` - the empty audio latent, feeds the ACE-Step 1.5 sampler's `latent_image`.
- **how it works:** allocates a zero audio latent whose temporal length corresponds to `seconds` at the ACE-Step 1.5 VAE's time compression.
- **strengths:** the correct empty canvas for ACE-Step 1.5 audio generation; length is set directly in seconds.
- **bugs / lags + fixes:** none known.
- **anti-patterns:** ACE-Step 1.5 specific. Do not use the 1.0 node (`EmptyAceStepLatentAudio`) or the generic `EmptyLatentAudio` with an ACE-Step 1.5 sampler unless the model accepts it; decode with `VAEDecodeAudio` and the matching audio VAE, never an image VAE.
- **placement:** a leaf feeding the ACE-Step 1.5 sampler. Decode the sampled latent with `VAEDecodeAudio`.

### EmptyAceStepLatentAudio  (display: "Empty Ace Step 1.0 Latent Audio")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_ace`) | **category:** `model/latent/audio` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** allocate the empty audio latent for ACE-Step 1.0 text-to-music/audio.
- **inputs:**
  - `seconds` (`FLOAT`, default 120.0, step 0.1) - target audio length in seconds.
  - `batch_size` (`INT`, default 1) - clips per run.
- **outputs:**
  - `LATENT` - the empty audio latent, feeds the ACE-Step 1.0 sampler.
- **how it works:** allocates a zero audio latent of the requested duration for the ACE-Step 1.0 VAE.
- **strengths:** the correct empty canvas for ACE-Step 1.0 audio.
- **bugs / lags + fixes:** none known.
- **anti-patterns:** ACE-Step 1.0 specific; the 1.5 node is `EmptyAceStep1.5LatentAudio`. Not for image or video samplers.
- **placement:** a leaf feeding the ACE-Step 1.0 sampler; decode with `VAEDecodeAudio`.

### EmptyLatentAudio  (display: "Empty Latent Audio")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_audio`) | **category:** `model/latent/audio` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** allocate the empty audio latent for the Stable Audio family (the generic audio empty-latent node).
- **inputs:**
  - `seconds` (`FLOAT`, default 47.6, step 0.1) - target audio length in seconds. The 47.6 default matches Stable Audio's typical clip length.
  - `batch_size` (`INT`, default 1) - clips per run.
- **outputs:**
  - `LATENT` - the empty audio latent, feeds the audio sampler.
- **how it works:** allocates a zero audio latent of the requested duration for the Stable Audio VAE.
- **strengths:** the standard empty canvas for Stable Audio text-to-audio.
- **bugs / lags + fixes:** none known.
- **anti-patterns:** built for the Stable Audio VAE; the ACE-Step models have their own empty-latent nodes. Not for image/video. Decode with `VAEDecodeAudio`.
- **placement:** a leaf feeding the audio sampler; decode the result with `VAEDecodeAudio`.

### VAEEncode  (display: "VAE Encode")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_latent`) | **category:** `model/latent` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** encode a pixel image into a latent, the entry point for img2img, inpaint, and any latent-space editing of a real image.
- **inputs:**
  - `pixels` (`IMAGE`) - the source RGB image to encode (e.g. from `LoadImage`).
  - `vae` (`VAE`) - the autoencoder, from the checkpoint or a standalone `VAELoader`. Must match the model family the latent will be sampled with.
- **outputs:**
  - `LATENT` - the encoded latent, feeds a sampler's `latent_image` (run the sampler at `denoise` < 1.0 to keep input structure for img2img).
- **how it works:** runs the image through the VAE encoder to produce the latent representation the sampler operates on.
- **strengths:** the standard img2img / latent-edit on-ramp; pairs with a reduced `denoise` to keep composition while restyling.
- **bugs / lags + fixes:** none known in the node. Image dimensions are expected to align to the VAE stride; arbitrary sizes may be cropped or padded by the VAE.
- **anti-patterns:** for inpainting that needs a noise mask, follow with `SetLatentNoiseMask` (or use `VAEEncodeForInpaint`); plain `VAEEncode` carries no mask. Mismatched VAE (encoding with an SD1.5 VAE then sampling an SDXL model, or vice versa) corrupts the latent. Do not use to start a txt2img graph, that is `EmptyLatentImage`.
- **placement:** between `LoadImage` and the sampler; the img2img counterpart of `EmptyLatentImage`. For inpaint, insert `SetLatentNoiseMask` after it.

### VAEDecodeAudio  (display: "VAE Decode Audio")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_audio`) | **category:** `model/latent/audio` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** decode an audio latent back into a playable waveform. The audio counterpart of `VAEDecode`.
- **inputs:**
  - `samples` (`LATENT`) - the audio latent from an audio sampler.
  - `vae` (`VAE`) - the audio VAE, matching the model that produced the latent (Stable Audio, ACE-Step, etc.).
- **outputs:**
  - `AUDIO` - the decoded waveform, feeds `SaveAudio` / `PreviewAudio` or any AUDIO consumer.
- **how it works:** runs the latent through the audio VAE decoder to a time-domain waveform.
- **strengths:** the standard sink for any audio-latent pipeline; one node from latent to waveform.
- **bugs / lags + fixes:** none known. Very long clips on low VRAM can be decoded in chunks with `VAEDecodeAudioTiled` (confirmed present 2026-06-30: adds `tile_size` default 512, `overlap` default 64).
- **anti-patterns:** audio only; an image VAE will not decode an audio latent. Use the audio VAE that matches the generating model.
- **placement:** between the audio sampler and the audio save/preview node.

### VAEEncodeAudio  (display: "VAE Encode Audio")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_audio`) | **category:** `model/latent/audio` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** encode a waveform into an audio latent, the audio analogue of `VAEEncode` for audio-to-audio / continuation workflows.
- **inputs:**
  - `audio` (`AUDIO`) - the source waveform (e.g. from `LoadAudio`).
  - `vae` (`VAE`) - the audio VAE matching the target model.
- **outputs:**
  - `LATENT` - the encoded audio latent, feeds an audio sampler's `latent_image`.
- **how it works:** runs the waveform through the audio VAE encoder into the latent the audio sampler operates on.
- **strengths:** on-ramp for audio-to-audio (style transfer, continuation) where you start from real audio rather than an empty latent.
- **bugs / lags + fixes:** none known.
- **anti-patterns:** audio only; do not feed an `IMAGE`. VAE must match the audio model family. For pure text-to-audio start from `EmptyLatentAudio` (or the ACE-Step empty nodes) instead.
- **placement:** between `LoadAudio` and the audio sampler; the audio img2img counterpart.

### VAEDecodeHunyuan3D  (display: "VAE Decode Hunyuan3D")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_hunyuan3d`) | **category:** `model/latent/3d` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** decode a Hunyuan3D shape latent into a `VOXEL` volume (the step before meshing).
- **inputs:**
  - `samples` (`LATENT`) - the 3D shape latent from the Hunyuan3D sampler.
  - `vae` (`VAE`) - the Hunyuan3D VAE.
  - `num_chunks` (`INT`, default 8000, min 1000, max 500000) - how many query points are decoded per chunk. Marked advanced. Lower it to trade speed for less peak memory; it controls batching of the implicit-field evaluation, not output quality.
  - `octree_resolution` (`INT`, default 256, min 16, max 512) - the resolution of the octree the volume is sampled on. Higher gives a finer voxel grid (more detail, more memory and time); lower is coarser and faster.
- **outputs:**
  - `VOXEL` - the decoded voxel volume, consumed by a Hunyuan3D meshing node downstream to produce a mesh.
- **how it works:** evaluates the Hunyuan3D implicit shape field decoded from the latent over an octree at `octree_resolution`, in batches of `num_chunks` query points, producing a voxel occupancy/SDF volume.
- **strengths:** the bridge from Hunyuan3D latent to a usable 3D volume; `octree_resolution` and `num_chunks` give a direct detail-vs-memory dial.
- **bugs / lags + fixes:** none known. High `octree_resolution` with a large `num_chunks` is the memory/time cost driver; reduce `num_chunks` first if you OOM, since it does not change the final grid.
- **anti-patterns:** 3D only; outputs `VOXEL`, not `IMAGE`, so it does not connect to image save/preview nodes. Pair only with the Hunyuan3D VAE and a Hunyuan3D latent.
- **placement:** after the Hunyuan3D sampler, before the voxel-to-mesh node. The 3D counterpart of `VAEDecode`.

### SetLatentNoiseMask  (display: "Set Latent Noise Mask")
- **pack / source:** core ComfyUI (`nodes`) | **category:** `model/latent/inpaint` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** attach a mask to a latent so the sampler only denoises (changes) the masked region, the lightweight inpaint mechanism.
- **inputs:**
  - `samples` (`LATENT`) - the latent to mask, usually from `VAEEncode` of the image being inpainted.
  - `mask` (`MASK`) - the region to denoise. White (1.0) areas get regenerated, black (0.0) areas are preserved.
- **outputs:**
  - `LATENT` - the same latent with a noise mask attached, feeds the sampler.
- **how it works:** stores the mask on the latent dict; the sampler reads it and restricts denoising to the masked area, leaving the rest of the latent intact.
- **strengths:** simple, model-agnostic inpaint; no special inpaint checkpoint required. Cheaper than re-architecting the graph for inpainting.
- **bugs / lags + fixes:** none known. A hard-edged mask can leave a visible seam; feather/blur the mask upstream for a smoother blend. The mask resolution should correspond to the latent it is set on.
- **anti-patterns:** this masks denoising, it does not composite. For dedicated inpaint models or better edge handling consider `VAEEncodeForInpaint` (which bakes the mask in at encode time). Feeding a mask that does not match the latent's spatial size gives misaligned edits.
- **placement:** between `VAEEncode` (or any latent source) and the sampler, in inpaint graphs. Mask typically comes from `LoadImageMask` or a mask editor.

### LatentConcat  (display: "Latent Concat")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_latent`) | **category:** `model/latent/advanced` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** join two latents along a chosen axis, stitching them in latent space (spatial tiling, or temporal joining for video).
- **inputs:**
  - `samples1` (`LATENT`) - the first latent.
  - `samples2` (`LATENT`) - the second latent, concatenated onto the first.
  - `dim` (`COMBO`) - which axis to join on. Options confirmed 2026-06-30: `x`, `-x`, `y`, `-y`, `t`, `-t`. `x`/`y` are the spatial width/height axes, `t` is the temporal axis for video latents; the `-` variants prepend `samples2` before `samples1` instead of appending.
- **outputs:**
  - `LATENT` - the concatenated latent, feeds a sampler or further latent ops.
- **how it works:** tensor concatenation of the two latents along the selected dimension. The two inputs must match in size on every axis except the one being joined.
- **strengths:** latent-space stitching without a VAE round-trip; the `t` axis makes it useful for extending or joining video-latent segments.
- **bugs / lags + fixes:** none known. Concatenating on `x` or `y` with mismatched height/width on the other axis fails; sizes must agree on the non-join axes.
- **anti-patterns:** do not join latents from different model families (incompatible channel layouts). `t` only makes sense for video latents; using it on an image latent has no temporal axis to join. For splitting back out, use `LatentCut`.
- **placement:** wherever two latents need merging before sampling or decode; commonly in video-latent assembly.

### LatentCut  (display: "Latent Cut")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_latent`) | **category:** `model/latent/advanced` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** extract a slice from a latent along a chosen axis, the inverse of `LatentConcat` (crop a region, or pull a frame range from a video latent).
- **inputs:**
  - `samples` (`LATENT`) - the latent to cut from.
  - `dim` (`COMBO`) - axis to cut along. Options confirmed 2026-06-30: `x`, `y`, `t` (width, height, time). Note this set has no negative variants, unlike `LatentConcat`.
  - `index` (`INT`, default 0, can be negative) - the start position along that axis. Negative indexes from the end.
  - `amount` (`INT`, default 1, min 1) - how many units along the axis to keep.
- **outputs:**
  - `LATENT` - the extracted slice, feeds a sampler, decode, or further ops.
- **how it works:** slices the latent tensor along `dim` from `index` for `amount` units and returns the sub-latent.
- **strengths:** latent-space cropping / frame extraction without a VAE round-trip; the `t` axis pulls specific frame ranges from a video latent.
- **bugs / lags + fixes:** none known. `index` + `amount` running past the axis length will error or return a short slice; keep within bounds for the chosen `dim`.
- **anti-patterns:** for splitting a latent into a batch of equal slices use `LatentCutToBatch` (confirmed present 2026-06-30) rather than many manual cuts. `t` only applies to video latents.
- **placement:** wherever a sub-region or frame range of a latent is needed; pairs with `LatentConcat` for split/rejoin patterns.

### TrimVideoLatent  (display: "Trim Video Latent")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_wan`) | **category:** `model/latent/video` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** drop a number of frames from the front of a video latent, typically to remove conditioning/warm-up frames before decode.
- **inputs:**
  - `samples` (`LATENT`) - the video latent to trim.
  - `trim_amount` (`INT`, default 0, min 0) - how many leading latent frames to remove. 0 is a pass-through.
- **outputs:**
  - `LATENT` - the trimmed video latent, feeds the VAE decode.
- **how it works:** removes `trim_amount` frames from the start of the latent's temporal axis. It lives in the WAN extras module but operates on any video latent's time dimension.
- **strengths:** clean removal of leading conditioning frames (common in image-to-video and extension workflows) so they do not appear in the final clip.
- **bugs / lags + fixes:** none known. Trimming more frames than the latent holds leaves nothing to decode; keep `trim_amount` below the frame count.
- **anti-patterns:** video latents only; an image latent has no temporal axis to trim. This trims only from the front; to take an arbitrary frame range use `LatentCut` on the `t` axis.
- **placement:** between the video sampler and `VAEDecode` (or a video-decode node), after any frame-conditioning stage.

### HunyuanVideo15LatentUpscaleWithModel  (display: "Hunyuan Video 15 Latent Upscale With Model")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_hunyuan`) | **category:** `model/latent` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** upscale a HunyuanVideo 1.5 latent to a larger resolution using a dedicated latent-upscale model, staying in latent space (no decode/re-encode).
- **inputs:**
  - `model` (`LATENT_UPSCALE_MODEL`) - the latent-upscale model that does the work. This is a distinct type from a diffusion `MODEL`; it comes from the matching upscale-model loader, not a checkpoint.
  - `samples` (`LATENT`) - the HunyuanVideo 1.5 latent to enlarge.
  - `upscale_method` (`COMBO`, default `bilinear`) - resampling method. Options confirmed 2026-06-30: `nearest-exact`, `bilinear`, `area`, `bicubic`, `bislerp`.
  - `width` (`INT`, default 1280, step 8) - target width in pixels.
  - `height` (`INT`, default 720, step 8) - target height in pixels.
  - `crop` (`COMBO`) - how to fit the target aspect. Options confirmed 2026-06-30: `disabled`, `center`.
- **outputs:**
  - `LATENT` - the upscaled latent, fed back into a sampler (a second low-denoise pass) or into decode.
- **how it works:** runs the latent through the supplied latent-upscale model to the target `width`/`height`, using `upscale_method` for resampling and `crop` to handle aspect, all within latent space.
- **strengths:** higher-resolution HunyuanVideo 1.5 output without the cost and color drift of a full pixel-space decode/upscale/re-encode cycle.
- **bugs / lags + fixes:** none known. Requires the correct `LATENT_UPSCALE_MODEL` to be loaded; an empty model input or a wrong-family upscale model is the likely failure.
- **anti-patterns:** built for HunyuanVideo 1.5 latents; do not feed image or other-family latents. `LATENT_UPSCALE_MODEL` is not interchangeable with an image upscale `MODEL` (the ESRGAN-style type used by `UpscaleModelLoader`); they are different types and consumers.
- **placement:** after the first HunyuanVideo 1.5 sampling pass; typically feeds a second short low-`denoise` sampler pass, then `VAEDecode`.

### LatentApplyOperationCFG  (display: "Latent Apply Operation CFG")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_latent`) | **category:** `model/latent/advanced/operations` | **I/O confirmed via get_node_info:** 2026-06-30 | **experimental** (flagged experimental in get_node_info)
- **purpose:** patch a model so a `LATENT_OPERATION` is applied to the CFG result at sampling time (for example tone-mapping the guided latent each step).
- **inputs:**
  - `model` (`MODEL`) - the diffusion model to patch.
  - `operation` (`LATENT_OPERATION`) - the operation to apply, produced by a `LatentOperation*` node such as `LatentOperationTonemapReinhard`.
- **outputs:**
  - `MODEL` - the patched model, wired into the sampler in place of the original.
- **how it works:** installs a hook on the model's CFG (classifier-free guidance) computation so the chosen latent operation transforms the post-CFG latent on every sampling step. It modifies the model, not a latent directly, which is why it returns `MODEL`.
- **strengths:** applies a latent transform continuously during sampling (not just once after), useful for taming over-bright or out-of-range guided latents at high CFG.
- **bugs / lags + fixes:** none known. Marked experimental, so behavior may change between ComfyUI versions; confirm against the running build.
- **anti-patterns:** the `operation` input needs a real `LATENT_OPERATION` source; it is not a latent and not a plain value. Patch the model before the sampler, not after. Wrong if you only want a one-shot transform of a finished latent (apply the operation directly in that case).
- **placement:** between the model source (checkpoint / LoRA) and the sampler's `model` input, with a `LatentOperation*` node feeding `operation`.

### LatentOperationTonemapReinhard  (display: "Latent Operation Tonemap Reinhard")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_latent`) | **category:** `model/latent/advanced/operations` | **I/O confirmed via get_node_info:** 2026-06-30 | **experimental** (flagged experimental in get_node_info)
- **purpose:** produce a Reinhard tone-mapping `LATENT_OPERATION` that compresses latent dynamic range, to be applied via `LatentApplyOperationCFG`.
- **inputs:**
  - `multiplier` (`FLOAT`, default 1.0, min 0, max 100, step 0.01) - scales the tone-mapping strength. 1.0 is the baseline; higher pushes harder compression of bright values.
- **outputs:**
  - `LATENT_OPERATION` - the operation object, consumed by `LatentApplyOperationCFG` (it does not output a latent itself).
- **how it works:** builds and returns a Reinhard tone-map operation parameterized by `multiplier`; the actual transform runs later when a node like `LatentApplyOperationCFG` applies it to latents during sampling.
- **strengths:** a knob to reduce blown-out highlights / clipping in the guided latent, especially at high CFG; the `multiplier` is the single tuning dial.
- **bugs / lags + fixes:** none known. Experimental, so confirm behavior on the running build.
- **anti-patterns:** this node alone does nothing visible; its `LATENT_OPERATION` must be wired into an applier (`LatentApplyOperationCFG`). It is not a latent and cannot feed a sampler's `latent_image` or a decode node.
- **placement:** feeds the `operation` input of `LatentApplyOperationCFG` (or another `LatentApplyOperation*` node); sits to the side of the main model-to-sampler chain.

---

## Documented in core.md (pointer only)

- **EmptyLatentImage** (display: "Empty Latent Image") - the SD1.5 / SDXL empty txt2img canvas. Full entry in `core.md`.
- **VAEDecode** (display: "VAE Decode") - decode a sampled image latent back to pixels. Full entry in `core.md`.
