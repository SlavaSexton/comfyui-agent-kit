# Image (part 1)

The pixel-space image-manipulation family: scaling and upscaling, compositing, mask making and editing,
batching, blend / edge filters, plus a detection-overlay and a compare node. These sit AFTER `VAEDecode` (or
after any node that produces an `IMAGE`) in the part of a graph that works on RGB pixels, not latents. All I/O
below is **confirmed via get_node_info: 2026-06-30** (ComfyUI 0.25.1) from the live `/object_info` pull; the
semantics, placement, and gotchas are the curated layer. Any input typed `COMBO` of file names is one machine's
installed files, so it is described as "a dropdown of installed <thing> files", never hardcoded. Display names,
combo option lists, and `python_module` source were confirmed live on the same pull.

`SaveImage` is the terminal sink for everything here; it is fully documented in `core.md` (8-bit sRGB PNG only,
use `SaveImageAdvanced` for 16-bit / EXR). Not duplicated below.

A note on scope: `nodes` in `python_module` means core ComfyUI's base `nodes.py`; `comfy_extras.*` means a core
ComfyUI extras module (still core, ships with ComfyUI, not a third-party pack). Both are core; the module name
is recorded so a future agent can read the source.

---

### ImageScale  (display: "Upscale Image")
- **pack / source:** core ComfyUI (`nodes`) | **category:** `image/upscaling` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** resize an image to an exact `width` x `height` in pixel space, with a chosen interpolation and optional center-crop.
- **inputs:**
  - `image` (`IMAGE`) - the image (or batch) to resize.
  - `upscale_method` (`COMBO[nearest-exact, bilinear, area, bicubic, lanczos]`) - the interpolation. `lanczos` / `bicubic` are sharpest for upscaling; `area` is best for downscaling; `nearest-exact` preserves hard pixel edges (pixel art, masks-as-images).
  - `width` / `height` (`INT`, default 512, min 0, step 1) - the exact target size. A value of 0 on either axis produces a zero-size dimension; set both to real sizes.
  - `crop` (`COMBO[disabled, center]`) - `disabled` stretches to the target (can change aspect ratio); `center` scales to cover then crops the center to the target (preserves aspect, loses edges).
- **outputs:**
  - `IMAGE` (`IMAGE`) - the resized image; feeds any IMAGE consumer (SaveImage, a compositor, a re-encode for img2img).
- **how it works:** runs the chosen interpolation kernel to the exact target dimensions; `center` crop does cover-then-crop so the output is never letterboxed.
- **strengths:** exact pixel control of the output size; the standard "make it exactly NxN" node; one node covers up and down scaling.
- **bugs / lags + fixes:** none known. This is pixel resampling, not a detail-adding super-resolution model; upscaling far beyond the source just interpolates (soft result). For detail use `ImageUpscaleWithModel`.
- **anti-patterns:** do not use it as a latent upscaler; it works on decoded pixels, its output does not go into a sampler (use `LatentUpscale` / `LatentUpscaleBy` for latent-space scaling). `disabled` crop on a target with a different aspect ratio warps the image.
- **placement:** anywhere on the pixel path, commonly right after `VAEDecode` to hit a delivery size, or before `SaveImage`.

### ImageScaleBy  (display: "Upscale Image By")
- **pack / source:** core ComfyUI (`nodes`) | **category:** `image/upscaling` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** resize an image by a multiplier (e.g. 2.0x) instead of an absolute size, preserving aspect ratio.
- **inputs:**
  - `image` (`IMAGE`) - the image to scale.
  - `upscale_method` (`COMBO[nearest-exact, bilinear, area, bicubic, lanczos]`) - same interpolation choices as `ImageScale`.
  - `scale_by` (`FLOAT`, default 1.0, min 0.01, max 8.0, step 0.01) - the multiplier. 2.0 doubles each side (4x the pixels); values below 1.0 downscale.
- **outputs:**
  - `IMAGE` (`IMAGE`) - the scaled image, aspect ratio kept.
- **how it works:** multiplies the current width and height by `scale_by` and resamples with the chosen method.
- **strengths:** keeps aspect ratio automatically; the right choice when you want "twice as big" regardless of the source size; pairs naturally after a model upscaler to dial the final factor.
- **bugs / lags + fixes:** none known. Like `ImageScale`, it interpolates and does not invent detail.
- **anti-patterns:** when you need an exact pixel size (not a ratio), use `ImageScale`. Not a latent operation.
- **placement:** on the pixel path; often after `VAEDecode` or after `ImageUpscaleWithModel` to fine-tune the multiplier.

### ImageUpscaleWithModel  (display: "Upscale Image (using Model)")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_upscale_model`) | **category:** `image/upscaling` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** run a loaded pixel-space upscale model (ESRGAN-family: RealESRGAN, 4x-UltraSharp, SwinIR, and similar) over an image to add detail while enlarging.
- **inputs:**
  - `upscale_model` (`UPSCALE_MODEL`) - the loaded upscaler, from `UpscaleModelLoader` (see `loaders.md`).
  - `image` (`IMAGE`) - the image to upscale.
- **outputs:**
  - `IMAGE` (`IMAGE`) - the model-upscaled image at the model's native factor (commonly 2x or 4x).
- **how it works:** tiles the image and runs it through the upscale network, then stitches the tiles; the enlargement factor is fixed by the model, not a parameter here.
- **strengths:** real super-resolution (adds plausible detail), unlike the interpolation-only scalers; works on a decoded `IMAGE` independent of the diffusion model.
- **bugs / lags + fixes:** large inputs spike VRAM during the tiled pass; this is a property of the run, not a code bug. If it OOMs, downscale first or use a batched / lower-VRAM variant from a pack (e.g. KJNodes `ImageUpscaleWithModelBatched`, which exposes a `per_batch` sub-batch size, confirmed via get_node_info 2026-06-30).
- **anti-patterns:** the model factor is fixed; if you need an arbitrary final size, follow this node with `ImageScale` / `ImageScaleBy` to hit the exact target. Do not expect a 4x model to give 2x. Its output is pixels, not a latent.
- **placement:** after `VAEDecode`; fed by `UpscaleModelLoader`. Often chained into `ImageScale` to set the exact delivery size, then `SaveImage`.

### ImageScaleToTotalPixels  (display: "Scale Image to Total Pixels")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_post_processing`) | **category:** `image/upscaling` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** resize an image to a target total pixel count (in megapixels), preserving aspect ratio. Useful to normalize varied inputs to a constant area (e.g. ~1 MP for SDXL).
- **inputs:**
  - `image` (`IMAGE`) - the image to scale.
  - `upscale_method` (`COMBO[nearest-exact, bilinear, area, bicubic, lanczos]`) - the interpolation.
  - `megapixels` (`FLOAT`, default 1.0, min 0.01, max 16, step 0.01) - target area in megapixels; the node solves width x height to hit this area at the current aspect ratio.
  - `resolution_steps` (`INT`, default 1, min 1, max 256, advanced) - rounds the computed dimensions to a multiple of this value (set to 8 / 16 / 64 to keep model-friendly sizes).
- **outputs:**
  - `IMAGE` (`IMAGE`) - the area-normalized image.
- **how it works:** computes the scale factor that brings the pixel count to `megapixels` while holding aspect ratio, then resamples; `resolution_steps` snaps the result to a grid.
- **strengths:** the clean way to make heterogeneous inputs share a compute budget (constant megapixels) without forcing a single aspect ratio; better than a fixed WxH when inputs vary in shape.
- **bugs / lags + fixes:** none known.
- **anti-patterns:** when you need an exact WxH, use `ImageScale`; when you want a simple multiplier, use `ImageScaleBy`. Interpolation only, not super-resolution.
- **placement:** on the pixel path, typically to normalize an input image before re-encoding for img2img, or to cap output area.

### ImageScaleToMaxDimension  (display: "Scale Image to Max Dimension")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_images`) | **category:** `image/upscaling` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** resize so the LONGER side equals `largest_size`, preserving aspect ratio. The "fit within a box" scaler driven by the longest edge.
- **inputs:**
  - `image` (`IMAGE`) - the image to scale.
  - `upscale_method` (`COMBO`) - the interpolation. On this build the live option list is `["area", "lanczos", "bilinear", "nearest-exact", "bilinear", "bicubic"]`, which is reordered and contains `"bilinear"` twice (a duplicate). This looks like an upstream defect in the node's option list, not intended; the methods themselves still work, just be aware the dropdown shows `bilinear` twice. Confirm the live list with `get_node_info` rather than trusting a fixed order.
  - `largest_size` (`INT`, default 512, min 0, step 1) - the target length of the longer side; the shorter side scales to match.
- **outputs:**
  - `IMAGE` (`IMAGE`) - the image whose longest side is now `largest_size`.
- **how it works:** finds the longer dimension, computes the factor to bring it to `largest_size`, applies it to both sides.
- **strengths:** the right tool to clamp an image to a maximum footprint while keeping aspect ratio (thumbnails, "no side bigger than N").
- **bugs / lags + fixes:** the duplicated `bilinear` in the `upscale_method` options (above) is a real quirk of this build's node; harmless to function but worth knowing. No fix on our side; it is upstream.
- **anti-patterns:** when you want to drive the result by total area, use `ImageScaleToTotalPixels`; by exact WxH, `ImageScale`. Interpolation only.
- **placement:** on the pixel path; common before saving or before feeding a downstream node that has a size cap.

### ImageCompositeMasked  (display: "Image Composite Masked")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_mask`) | **category:** `image/compositing` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** paste a `source` image onto a `destination` image at an (x, y) offset, optionally limited by a `mask` so only the masked region is composited.
- **inputs:**
  - `destination` (`IMAGE`) - the background / base image.
  - `source` (`IMAGE`) - the image pasted on top.
  - `x` / `y` (`INT`, default 0, min 0, step 1) - top-left placement of `source` on `destination`, in pixels.
  - `resize_source` (`BOOLEAN`, default False) - when True, resizes `source` to the destination size before compositing; when False, pastes at the source's own size.
  - `mask` (`MASK`, optional) - where omitted, the whole `source` is pasted; where provided, only the mask's white region of `source` shows through (the alpha of the paste).
- **outputs:**
  - `IMAGE` (`IMAGE`) - the composited result.
- **how it works:** places `source` at (x, y) over `destination`; if a `mask` is given it is used as a per-pixel alpha for the paste (white = source, black = destination).
- **strengths:** the core node for masked compositing / paste-back (e.g. paste an inpainted region back onto the original, overlay a logo through a mask); separate x/y control; optional auto-resize.
- **bugs / lags + fixes:** none known. The `mask` must align with `source` in the placed region; a mismatched mask size gives a wrong cutout (see anti-patterns).
- **anti-patterns:** feeding a `mask` whose dimensions do not match the placed `source` region produces misaligned compositing. `x` / `y` are non-negative here, so you cannot place `source` partly off the top-left with negative offsets. This composites pixels; it is not a latent blend and not a generative fill.
- **placement:** late on the pixel path, after both images exist (and after any `ImageToMask` / mask edit that builds the alpha); feeds `SaveImage` or further compositing.

### ImagePadForOutpaint  (display: "Pad Image for Outpainting")
- **pack / source:** core ComfyUI (`nodes`) | **category:** `image/transform` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** add blank canvas on chosen sides of an image and emit a matching `MASK` of the new (to-be-filled) area, the standard setup for outpainting.
- **inputs:**
  - `image` (`IMAGE`) - the image to extend.
  - `left` / `top` / `right` / `bottom` (`INT`, default 0, min 0, step 8) - pixels of padding to add on each side. Step 8 keeps the padded size on the model's size grid.
  - `feathering` (`INT`, default 40, advanced) - softens the mask edge at the seam between original and padding, so the outpaint blends instead of showing a hard line; 0 gives a hard mask edge.
- **outputs:**
  - `IMAGE` (`IMAGE`) - the original image on an enlarged canvas (padding added).
  - `MASK` (`MASK`) - white over the new padded region, black over the original; feed this to the inpaint encode / sampler so only the padding is generated.
- **how it works:** allocates a larger canvas, places the original inside it per the side paddings, and builds a mask covering exactly the added border with a feathered transition.
- **strengths:** one node produces both the padded image and the correctly-aligned mask for outpainting; per-side control; feathering for seamless blends.
- **bugs / lags + fixes:** none known.
- **anti-patterns:** the padded image is blank in the new area; you still need an inpaint-capable encode + sampler (e.g. `VAEEncodeForInpaint` + an inpainting model / denoise on the masked region) to fill it. This node only pads and masks; it does not generate the outpaint. Zero feathering can leave a visible seam.
- **placement:** at the start of an outpaint sub-graph: `IMAGE` and `MASK` feed the inpaint encode path; the result is decoded and composited or saved.

### ImageToMask  (display: "Convert Image to Mask")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_mask`) | **category:** `image/mask` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** extract a single channel from an image and return it as a `MASK`.
- **inputs:**
  - `image` (`IMAGE`) - the source image.
  - `channel` (`COMBO[red, green, blue, alpha]`) - which channel becomes the mask. `alpha` only carries data if the image actually has an alpha channel; otherwise use a color channel.
- **outputs:**
  - `MASK` (`MASK`) - the chosen channel as a single-channel mask; feeds any MASK consumer (compositing alpha, inpaint region, mask edits).
- **how it works:** reads the selected channel's values directly as the mask intensity (no thresholding).
- **strengths:** the bridge from an image-shaped signal (a rendered map, a painted layer, a generated matte) into the MASK type; trivial and cheap.
- **bugs / lags + fixes:** none known. Selecting `alpha` on an image without an alpha channel yields an empty or all-ones mask depending on the source; pick a color channel if there is no real alpha.
- **anti-patterns:** it does not threshold or binarize; if you need a hard mask, follow with a threshold / level node. To go the other way (MASK to IMAGE) use `MaskToImage`.
- **placement:** between an `IMAGE` source and a node that needs a `MASK` (e.g. `ImageCompositeMasked.mask`, an inpaint encode, `FeatherMask`).

### FeatherMask  (display: "Feather Mask")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_mask`) | **category:** `image/mask` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** soften a mask's edges by fading it inward from each side, producing a gradient border instead of a hard cut.
- **inputs:**
  - `mask` (`MASK`) - the mask to feather.
  - `left` / `top` / `right` / `bottom` (`INT`, default 0, min 0, step 1) - how many pixels to fade in from each edge; 0 on a side leaves that edge hard.
- **outputs:**
  - `MASK` (`MASK`) - the feathered mask.
- **how it works:** ramps the mask value from 0 to full over the given pixel distance inward from each specified edge.
- **strengths:** removes hard seams in masked compositing / inpainting; independent per-side control lets you feather only the edges that need it.
- **bugs / lags + fixes:** none known.
- **anti-patterns:** feathering operates from the mask's bounding edges inward by the given amounts; it is edge-based, not a uniform Gaussian blur of an arbitrary internal mask shape. For blurring an irregular internal boundary, a mask-blur node (e.g. from a pack) is closer to intent. Over-large feather values on a small mask can wash the mask toward empty.
- **placement:** after the mask is built (e.g. after `ImageToMask` or an outpaint/inpaint mask), before it is used as compositing alpha or an inpaint region.

### InvertMask  (display: "Invert Mask")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_mask`) | **category:** `image/mask` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** flip a mask: white becomes black and black becomes white (1 minus the mask).
- **inputs:**
  - `mask` (`MASK`) - the mask to invert.
- **outputs:**
  - `MASK` (`MASK`) - the inverted mask.
- **how it works:** computes `1 - mask` per pixel.
- **strengths:** trivial and exact; the one-node way to swap which region a downstream node treats as active (e.g. inpaint the background instead of the subject).
- **bugs / lags + fixes:** none known.
- **anti-patterns:** none specific. Just confirm which polarity the consumer expects (white = act) before deciding whether to invert.
- **placement:** anywhere on the mask path, between the mask source and its consumer.

### BatchImagesNode  (display: "Batch Images")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_post_processing`) | **category:** `image/batch` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** combine several separate images into one image batch along the batch dimension. The current, non-deprecated batch-combine node (replaces `ImageBatch`).
- **inputs:**
  - `images` (`COMFY_AUTOGROW_V3`) - an autogrow group of `IMAGE` slots: it starts with one `image` input and grows as you connect more (the live template allows 1 to 50 slots). Wire one image per slot; the node stacks them into a batch.
- **outputs:**
  - `IMAGE` (`IMAGE`) - the combined batch; feeds any node that processes a batch (a sampler over a batch, a save that writes each frame, a video assembler).
- **how it works:** concatenates the connected images along the batch axis into a single `IMAGE` tensor of shape (N, H, W, C).
- **strengths:** combines an arbitrary number of images (up to 50) in one node via the autogrow input, instead of chaining many two-input batch nodes; the modern replacement for the deprecated `ImageBatch`.
- **bugs / lags + fixes:** none known. As with any batch, the images should share H x W (and channel count); mismatched sizes will not stack cleanly. Resize first (`ImageScale`) if they differ.
- **anti-patterns:** do not use the deprecated two-input `ImageBatch` when this exists. Batching images of different dimensions without resizing them to a common size first.
- **placement:** mid-graph wherever you need to merge multiple image streams into one batch before a batch-aware consumer.

### ImageFromBatch  (display: "Get Image from Batch")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_images`) | **category:** `image/batch` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** extract one or more images from a batch by index, the inverse of batching.
- **inputs:**
  - `image` (`IMAGE`) - the input batch.
  - `batch_index` (`INT`, default 0, min -16384) - the starting index to pull from (0 = first). Negative indices count from the end.
  - `length` (`INT`, default 1, min 1) - how many consecutive images to take starting at `batch_index`.
- **outputs:**
  - `IMAGE` (`IMAGE`) - the selected slice of the batch (1 or more images).
- **how it works:** slices the batch tensor `[batch_index : batch_index + length]`.
- **strengths:** pick a single frame out of a batch (e.g. the best of N), or a sub-range; cheap.
- **bugs / lags + fixes:** none known. An index or range past the batch length is clamped / wraps depending on the slice; keep `batch_index + length` within the batch to be safe.
- **anti-patterns:** to add a frame INTO a batch use a batch-combine node, not this. Asking for more than the batch holds will not invent frames.
- **placement:** after any node that outputs a batch (a sampler, `BatchImagesNode`), to isolate the frame(s) you want before saving or further work.

### ImageBatch  (display: "Batch Images (DEPRECATED)")
- **pack / source:** core ComfyUI (`nodes`) | **category:** `image/batch` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** combine exactly two images into a batch. DEPRECATED on this build (`deprecated: true`, the display name itself says "(DEPRECATED)").
- **inputs:**
  - `image1` (`IMAGE`) - first image.
  - `image2` (`IMAGE`) - second image; auto-resized to match `image1` if their sizes differ.
- **outputs:**
  - `IMAGE` (`IMAGE`) - a two-image batch.
- **how it works:** stacks the two images along the batch dimension (resizing `image2` to `image1` if needed).
- **strengths:** historically the simple two-input batch node. There is no reason to reach for it now.
- **bugs / lags + fixes:** it is flagged deprecated by ComfyUI; this is not a bug but a status. The kit should prefer `BatchImagesNode` (autogrow, 1 to 50 inputs). Documented here only so an agent meeting it in an old workflow knows what it is and that it is superseded.
- **anti-patterns:** do not place it in new graphs; use `BatchImagesNode`. Chaining many `ImageBatch` nodes to build a large batch (use the autogrow node instead).
- **placement:** legacy only. If found in an existing workflow, it merges two image streams; replace with `BatchImagesNode` when touching that graph.

### ImageStitch  (display: "Stitch Images")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_images`) | **category:** `image/transform` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** join two images into ONE larger image side by side (or stacked), with optional spacing between them. This is spatial concatenation, not a batch.
- **inputs:**
  - `image1` (`IMAGE`) - the base image.
  - `direction` (`COMBO[right, down, left, up]`, default right) - where `image2` is placed relative to `image1`.
  - `match_image_size` (`BOOLEAN`, default True) - resize `image2` to match `image1` along the shared edge so they line up.
  - `spacing_width` (`INT`, default 0, min 0, max 1024, step 2, advanced) - gap in pixels inserted between the two images.
  - `spacing_color` (`COMBO[white, black, red, green, blue]`, default white, advanced) - the color of that gap.
  - `image2` (`IMAGE`, optional) - the image to stitch on. If omitted, `image1` is returned unchanged.
- **outputs:**
  - `IMAGE` (`IMAGE`) - the single combined image (wider or taller than the inputs).
- **how it works:** resizes `image2` to fit the shared edge (if `match_image_size`), optionally inserts a colored gap, and concatenates the two along the chosen direction into one image.
- **strengths:** the right node for before/after panels, contact sheets, or feeding a single comparison image somewhere; optional gutter with a chosen color; handles the missing-second-image case gracefully.
- **bugs / lags + fixes:** none known.
- **anti-patterns:** this makes one bigger image (spatial), NOT a batch of two; for a batch use `BatchImagesNode`. Without `match_image_size`, images of different sizes along the shared edge will not align cleanly.
- **placement:** late on the pixel path, to assemble a composite image; output goes to `SaveImage` or a compare / preview node.

### ImageBlend  (display: "Blend Images")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_post_processing`) | **category:** `image/filters` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** blend two images together with a chosen blend mode and a mix factor, producing one image (a per-pixel composite over the whole frame).
- **inputs:**
  - `image1` (`IMAGE`) - the base image.
  - `image2` (`IMAGE`) - the blend image; must match `image1`'s dimensions.
  - `blend_factor` (`FLOAT`, default 0.5, min 0, max 1, step 0.01) - mix weight, 0 = all `image1`, 1 = full blend toward `image2` under the mode.
  - `blend_mode` (`COMBO[normal, multiply, screen, overlay, soft_light, difference]`) - the compositing math.
- **outputs:**
  - `IMAGE` (`IMAGE`) - the blended result.
- **how it works:** applies the chosen blend-mode function between the two images, then mixes by `blend_factor`.
- **strengths:** quick full-frame blends and looks (multiply for darkening, screen for lightening, overlay / soft_light for contrast, difference for diffing) in one node.
- **bugs / lags + fixes:** none known. The two images must be the same size; mismatched dimensions fail.
- **anti-patterns:** this blends the WHOLE frame uniformly; for region-limited compositing use `ImageCompositeMasked` (with a mask). The mode list is fixed to the six options above; richer mode sets live in image-processing packs.
- **placement:** on the pixel path where you want to combine two full images (e.g. overlay a texture or a generated pass), before saving.

### Canny  (display: "Detect Edges (Canny)")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_canny`) | **category:** `image/filters` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** run Canny edge detection on an image, returning a black-and-white edge map. The classic preprocessor for a Canny ControlNet.
- **inputs:**
  - `image` (`IMAGE`) - the source image to find edges in.
  - `low_threshold` (`FLOAT`, default 0.4, min 0.01, max 0.99, step 0.01) - the weak-edge threshold of the hysteresis; lower keeps more faint edges.
  - `high_threshold` (`FLOAT`, default 0.8, min 0.01, max 0.99, step 0.01) - the strong-edge threshold; edges above it are kept outright, edges between the two thresholds are kept only if connected to a strong edge.
- **outputs:**
  - `IMAGE` (`IMAGE`) - the edge map (white lines on black), as an IMAGE; feed it to a Canny ControlNet apply node, or save it.
- **how it works:** standard Canny: gradient, non-max suppression, then double-threshold hysteresis between `low_threshold` and `high_threshold`.
- **strengths:** the built-in, no-extra-pack Canny preprocessor; two intuitive thresholds; output is a ready ControlNet hint image.
- **bugs / lags + fixes:** none known. Thresholds set too high give sparse / broken edges; too low gives noise. Tune per image.
- **anti-patterns:** the output is a hint image for a Canny ControlNet, not a finished result; feeding a raw photo (instead of this edge map) to a Canny ControlNet defeats the point. Other control types (depth, pose) need their own preprocessors, not this one.
- **placement:** on the pixel path feeding a ControlNet apply node's image input (the ControlNet itself comes from `ControlNetLoader`, see `loaders.md`); sits on the conditioning side of the graph.

### DrawBBoxes  (display: "Draw BBoxes")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_rtdetr`) | **category:** `image/detection` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** draw bounding boxes (from a detector) onto an image, for visualizing object-detection results. Part of the RT-DETR detection extras.
- **inputs:**
  - `bboxes` (`BOUNDING_BOX`) - the boxes to draw. This input is `socketless` + `forceInput`: it must come from a wire (a detector node that outputs `BOUNDING_BOX`), not typed by hand. The shown default `{x:0, y:0, width:512, height:512}` is a placeholder schema, not a value you set in the UI.
  - `image` (`IMAGE`, optional) - the image to draw on. If omitted, the boxes are drawn on a blank canvas.
- **outputs:**
  - `out_image` (`IMAGE`) - the image with boxes overlaid; feeds `SaveImage` / `PreviewImage` to inspect detections.
- **how it works:** rasterizes the box rectangles (and any associated labels from the detector output) over the image.
- **strengths:** the visualization end of an RT-DETR detection chain; lets you see what the detector found.
- **bugs / lags + fixes:** none known. The `bboxes` input requires a real `BOUNDING_BOX` source; without an upstream detector it has nothing meaningful to draw.
- **anti-patterns:** it does NOT detect anything; it only draws boxes produced by a detector. Wiring it without an RT-DETR (or compatible `BOUNDING_BOX`-producing) node upstream is the common mistake. Do not expect it to accept hand-typed coordinates through the port.
- **placement:** at the tail of a detection sub-graph: the detector emits `BOUNDING_BOX`, this draws them over the source `IMAGE`, then save / preview.

### ImageCompare  (display: "Compare Images")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_image_compare`), experimental | **category:** `image` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** show two images overlaid with a draggable slider in the node UI, for A/B visual comparison. This is an OUTPUT (terminal) node; it displays, it does not return an image.
- **inputs:**
  - `compare_view` (`IMAGECOMPARE`) - the node's own UI widget (marked `socketless`); not a port you wire from another node, it is the in-node comparison view.
  - `image_a` (`IMAGE`, optional) - the first image (one side of the slider).
  - `image_b` (`IMAGE`, optional) - the second image (the other side).
- **outputs:** none (`output_node`: it renders the comparison in the UI and returns nothing to the graph).
- **how it works:** takes the two images and presents them in a single widget with a slider that wipes between A and B; the comparison is interactive in the editor.
- **strengths:** fast in-editor A/B (before/after an upscale, two seeds, two settings) without leaving ComfyUI; no save needed to eyeball a difference.
- **bugs / lags + fixes:** flagged `experimental: true` on this build, so its behavior or I/O may change between versions; re-confirm with `get_node_info` if a graph using it breaks after an update. No functional bug known otherwise.
- **anti-patterns:** it is a viewer, not a processor; it produces no `IMAGE` output, so nothing can consume its result downstream. To save a side-by-side as a file, use `ImageStitch` into `SaveImage` instead. Do not try to wire `compare_view`; it is the widget.
- **placement:** a leaf at the end of two branches you want to compare; both `image_a` and `image_b` come from the nodes under test.

### GetImageSize  (display: "Get Image Size")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_images`) | **category:** `image` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** read an image's dimensions (width, height, batch size) as INTs while passing nothing else; a probe for driving downstream sizes.
- **inputs:**
  - `image` (`IMAGE`) - the image to measure.
- **outputs:**
  - `width` (`INT`) - the image width in pixels.
  - `height` (`INT`) - the image height in pixels.
  - `batch_size` (`INT`) - how many images are in the batch.
- **how it works:** reads the tensor shape and emits the three integers. (The node's description notes it passes the image through unchanged, but on this build only the three INTs are exposed as outputs; there is no IMAGE output port to chain. To also forward the image AND get a count, KJNodes `GetImageSizeAndCount` adds an `image` passthrough plus a `count`, confirmed via get_node_info 2026-06-30.)
- **strengths:** cheaply derive real dimensions to feed nodes that need a width / height number (a matching latent size, a target for `ImageScale`, math nodes), instead of hardcoding.
- **bugs / lags + fixes:** none known.
- **anti-patterns:** it measures, it does not resize; pair its INT outputs with a scaling node to actually change size. Do not expect an IMAGE passthrough from this exact node (use the KJNodes variant if you need that).
- **placement:** a probe tapped off any `IMAGE`; its INT outputs fan into size-consuming inputs elsewhere in the graph.

### EmptyImage  (display: "Empty Image")
- **pack / source:** core ComfyUI (`nodes`) | **category:** `image` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** generate a solid-color image of a given size and batch count. A blank pixel canvas (distinct from `EmptyLatentImage`, which makes a blank latent).
- **inputs:**
  - `width` / `height` (`INT`, default 512, min 1, max 16384, step 1) - the image size in pixels.
  - `batch_size` (`INT`, default 1, min 1) - how many identical images to make.
  - `color` (`INT`, default 0, displayed as a color picker) - the fill color as a packed 24-bit RGB integer (0 = black, 16777215 = white); the UI shows a color swatch.
- **outputs:**
  - `IMAGE` (`IMAGE`) - the solid-color image(s).
- **how it works:** allocates an image tensor filled with the chosen color at the requested size and batch count.
- **strengths:** a quick background / fill plate, a placeholder, or a base for compositing (e.g. a colored canvas under `ImageCompositeMasked`); the color picker makes choosing the fill easy.
- **bugs / lags + fixes:** none known.
- **anti-patterns:** this is a PIXEL image, not a latent; do not feed it where a `LATENT` is expected (use `EmptyLatentImage` for the sampler's empty canvas). It is a flat color, not noise; it will not seed generation like a latent does.
- **placement:** a leaf producing an `IMAGE`; feeds compositing / blend nodes or stands in as a background plate.
