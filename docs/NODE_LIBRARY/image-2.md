# Image (part 2)

The `image`, `image/transform`, `image/batch`, `image/mask`, and `image/compositing` families: the nodes that load a picture in, write results out (PNG, animated WEBP, SVG), resize and pad, repeat a batch, and the mask toolkit (create, combine, threshold, convert, attach as alpha, preview). These are the plumbing at the edges and the seams of a graph, not the diffusion engine. All I/O below is **confirmed via get_node_info: 2026-06-30** (ComfyUI 0.25.1) from the live `/object_info` pull; the semantics, placement, gotchas, and bug notes are the curated layer. Any input shown as a `COMBO[...]` of file names is one machine's installed files, so it is described as "a dropdown of installed <thing> files", never hardcoded. `SaveImage` already has a full entry in `core.md` and gets a one-line pointer here instead of a duplicate.

---

### LoadImage  (display: "Load Image")
- **pack / source:** core ComfyUI (`nodes`) | https://github.com/comfyanonymous/ComfyUI
- **category:** `image` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** read an image file from the ComfyUI `input` folder and hand it to the graph as an `IMAGE`, plus its alpha channel as a `MASK`. The standard entry point for img2img, inpaint, upscale, and any pipeline that starts from an existing picture.
- **inputs:**
  - `image` (`COMBO`, `image_upload: true`) - a dropdown of files in the `input` folder; the widget also has an upload button to drop a new file in. It is one machine's installed files, not a fixed list. Empty or missing file = the node errors at run; re-upload or pick an existing file.
- **outputs:**
  - `IMAGE` (`IMAGE`) - the decoded RGB image; feeds `VAEEncode`, a preprocessor, an upscaler, or anything that consumes `IMAGE`.
  - `MASK` (`MASK`) - the image's alpha channel as a mask. If the file has no alpha, this is a solid (fully opaque) mask, not an error; do not rely on it carrying a real selection unless the file actually has transparency.
- **how it works:** loads the file, splits RGB into `IMAGE` and the alpha into `MASK`, normalized to 0..1 float tensors.
- **strengths:** the universal "bring a picture in" node; gives both the image and its alpha in one shot; built-in upload widget.
- **bugs / lags + fixes:** none known in the node. The classic gotcha is the silent opaque mask when the source has no alpha (see outputs).
- **anti-patterns:** do not use it to read your own previous render from the `output` folder; that is `LoadImageOutput` (display "Load Image (from Outputs)", same `IMAGE` + `MASK`, with a refresh button). For a file you only want as a mask off a chosen channel, `LoadImageMask` (display "Load Image (as Mask)") takes a `channel` of alpha / red / green / blue and returns just `MASK`. For a whole folder as a batch, see the dataset loaders (`LoadImageDataSetFromFolder`) or `LoadImagesFromFolderKJ` (KJNodes). Treating the `MASK` output as a real selection when the file is a flat JPG gives a useless all-opaque mask.
- **placement:** a leaf at the start of the pixel side of a graph. Nothing feeds it; it feeds `VAEEncode` (for img2img / inpaint), preprocessors, upscalers, compositing nodes.

### PreviewImage  (display: "Preview Image")
- **pack / source:** core ComfyUI (`nodes`) | https://github.com/comfyanonymous/ComfyUI
- **category:** `image` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** show an `IMAGE` in the UI without committing a named file. The throwaway-preview sink for iterating.
- **inputs:**
  - `images` (`IMAGE`) - the image(s) to display; typically straight off `VAEDecode` or any IMAGE-producing node.
- **outputs:** none. It is an output (terminal) node: `output_node: true`, returns nothing to the graph.
- **how it works:** writes the image to the ComfyUI temp/output area and returns it to the UI for display, the same mechanism `SaveImage` uses but aimed at a temporary preview file rather than a deliberately named one.
- **strengths:** zero-config; the right sink while tuning a graph so you do not litter the output folder with named files.
- **bugs / lags + fixes:** none known.
- **anti-patterns:** do not use it for deliverables you want to keep with a chosen filename; that is `SaveImage`. It cannot rename or control the prefix. For a mask, use `MaskPreview` (it converts the single-channel mask to a viewable image first); feeding a `MASK` here is a type mismatch.
- **placement:** a leaf at the end of a branch, parallel to or instead of `SaveImage`.

### SaveImage  (display: "Save Image")
- See the full entry in `core.md`. Writes the final `IMAGE`(s) to the ComfyUI output dir as 8-bit sRGB PNG with the workflow embedded; `filename_prefix` supports tokens like `%date:yyyy-MM-dd%`. For 16-bit / EXR / linear, use `SaveImageAdvanced` (noted in `core.md`).

### SaveAnimatedWEBP  (display: "Save Animated WEBP")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_images`) | https://github.com/comfyanonymous/ComfyUI
- **category:** `image` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** write a batch of frames out as a single animated `.webp` file. The lightweight way to save a short animation or video preview without a full video-encode node.
- **inputs:**
  - `images` (`IMAGE`) - the frame batch, in order; the batch dimension is the timeline. One image in = a one-frame (static) webp.
  - `filename_prefix` (`STRING`, default `ComfyUI`) - output name prefix; supports the same token syntax as `SaveImage`.
  - `fps` (`FLOAT`, default 6.0) - playback frame rate written into the file. This sets only playback speed; it does not resample or change how many frames you have.
  - `lossless` (`BOOLEAN`, default True) - lossless WEBP when on. Lossless on a long high-res animation produces a large file; turn it off and use `quality` for a smaller lossy file.
  - `quality` (`INT`, default 80, 0..100) - lossy quality; only meaningful when `lossless` is off.
  - `method` (`COMBO`: `default`, `fastest`, `slowest`) - encoder effort / speed tradeoff. `slowest` compresses best, `fastest` encodes quickest, `default` is the middle.
- **outputs:** none. Output (terminal) node, `output_node: true`.
- **how it works:** encodes the frame batch into one animated WEBP at the given fps and quality settings, saving to the output dir.
- **strengths:** one node, no ffmpeg, gives a shareable looping animation; good for quick motion previews of a frame batch.
- **bugs / lags + fixes:** none known. Practical notes, not bugs: animated WEBP support varies by viewer, and a long lossless run makes a heavy file (see `lossless`).
- **anti-patterns:** not an MP4/H.264 encoder; for real video files use a video-combine node (VideoHelperSuite / the core video nodes), not this. Feeding a single image just makes a static webp. Expecting `fps` to drop or duplicate frames; it only labels playback speed.
- **placement:** a leaf at the end of a frame-producing branch (after `VAEDecode` of a video/animation latent, or after any node that emits an ordered IMAGE batch).

### SaveSVGNode  (display: "Save SVG")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_images`) | https://github.com/comfyanonymous/ComfyUI
- **category:** `image` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** write an `SVG` object to disk as a `.svg` file. The sink for vector output (the kind produced by vectorizer nodes that turn a raster into paths).
- **inputs:**
  - `svg` (`SVG`) - the vector graphics object to save. This is a dedicated `SVG` type, not an `IMAGE`; it must come from a node that produces vectors.
  - `filename_prefix` (`STRING`, default `svg/ComfyUI`) - output name prefix (note the default puts files in an `svg/` subfolder); supports the same token syntax as `SaveImage`.
- **outputs:** none. Output (terminal) node, `output_node: true`.
- **how it works:** serializes the `SVG` object to an `.svg` file in the output dir.
- **strengths:** the correct, lossless way to persist vector results; keeps paths editable in a vector editor rather than flattening to pixels.
- **bugs / lags + fixes:** none known in the node.
- **anti-patterns:** it consumes `SVG`, not `IMAGE`; you cannot feed it a decoded raster image directly. You need an upstream node that outputs `SVG` (a raster-to-vector / trace node). Wiring `VAEDecode`'s `IMAGE` here is a type mismatch. For raster output use `SaveImage`.
- **placement:** a leaf at the end of a vectorize branch; fed by whatever node emits the `SVG`.

### ResizeImageMaskNode  (display: "Resize Image/Mask")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_post_processing`) | https://github.com/comfyanonymous/ComfyUI
- **category:** `image/transform` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** resize EITHER an image or a mask by one of many sizing strategies (exact dimensions, scale factor, longer/shorter edge, total megapixels, snap-to-multiple, or match another input). The modern, type-flexible resize node.
- **inputs:**
  - `input` (`COMFY_MATCHTYPE_V3`, accepts `IMAGE` or `MASK`) - the thing to resize. This is a V3 match-type port: the output type follows whatever you connect here. Connect an `IMAGE` and you get a resized `IMAGE`; connect a `MASK` and you get a resized `MASK`.
  - `resize_type` (`COMFY_DYNAMICCOMBO_V3`) - a dynamic combo that reveals different sub-inputs per choice. The modes confirmed in the pull: `scale dimensions` (exposes `width`, `height`, and a `crop` of `disabled`/`center`; set width or height to 0 to auto-fit the other from aspect ratio), `scale by multiplier` (`multiplier` 0.01..8), `scale longer dimension` (`longer_size`), `scale shorter dimension` (`shorter_size`), `scale width` (`width`, height auto), `scale height` (`height`, width auto), `scale total pixels` (`megapixels`, e.g. 1.0 is about 1024x1024), `match size` (a reference `IMAGE,MASK` input plus `crop`), and `scale to multiple` (`multiple`, snaps both dimensions divisible by N, e.g. 8 or 64 for latent alignment).
  - `scale_method` (`COMBO`: `nearest-exact`, `bilinear`, `area`, `bicubic`, `lanczos`; default `area`) - interpolation algorithm. Per the node's own tooltip: `area` is best for downscaling, `lanczos` for upscaling, `nearest-exact` for pixel art.
- **outputs:**
  - `resized` (`COMFY_MATCHTYPE_V3`) - the resized result, same type as `input` (IMAGE in -> IMAGE out, MASK in -> MASK out).
- **how it works:** picks target dimensions from the chosen `resize_type` (and its revealed sub-inputs), then resamples with `scale_method`. The V3 match-type machinery keeps image and mask paths in one node and carries the input type through to the output.
- **strengths:** one node covers nearly every resize need; works on both IMAGE and MASK; `scale to multiple` is handy to keep a size latent-friendly; `match size` resizes to a reference without hand-entering numbers. Sensible interpolation guidance is built into the tooltips.
- **bugs / lags + fixes:** none known. It uses ComfyUI's V3 `MATCHTYPE` and `DYNAMICCOMBO` types; an old ComfyUI build or a stale frontend may not render the dynamic sub-inputs, in which case update ComfyUI.
- **anti-patterns:** wrong interpolation for the job (e.g. `bilinear`/`bicubic` upscale of pixel art, which blurs the hard edges `nearest-exact` would keep). It is a pixel/mask resampler, not a diffusion upscaler; it does not add detail, so for real upscaling pair an upscale-model path or a low-denoise resample-then-sample, not this alone. Feeding it a `LATENT` is wrong (that is `LatentUpscale` / `LatentUpscaleBy`).
- **placement:** inline on an `IMAGE` or `MASK` line, anywhere you need to change size: before `VAEEncode` to hit a target resolution, after `VAEDecode` to fit an output size, or on a mask to match an image it will be composited with.

### ResizeAndPadImage  (display: "Resize And Pad Image")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_images`) | https://github.com/comfyanonymous/ComfyUI
- **category:** `image/transform` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** fit an image into an exact target canvas without distorting it: scale to fit, then pad the leftover space with a solid color (letterbox / pillarbox). Search alias is literally "fit to size".
- **inputs:**
  - `image` (`IMAGE`) - the image to fit.
  - `target_width` (`INT`, default 512) - canvas width to fit into.
  - `target_height` (`INT`, default 512) - canvas height to fit into.
  - `padding_color` (`COMBO`: `white`, `black`) - the fill color for the padded bars. Only two options on this version, white or black.
  - `interpolation` (`COMBO`: `area`, `bicubic`, `nearest-exact`, `bilinear`, `lanczos`) - resampling algorithm for the scale-to-fit step. `area` suits downscaling, `lanczos` upscaling, `nearest-exact` pixel art.
- **outputs:**
  - `IMAGE` (`IMAGE`) - the padded image at exactly `target_width` x `target_height`, aspect ratio preserved, bars filled with `padding_color`.
- **how it works:** scales the image to fit inside the target box preserving aspect ratio, then centers it and pads the remaining margin with the chosen solid color so the result is exactly the requested size.
- **strengths:** guarantees an exact output size with no stretching; the clean way to normalize mixed-aspect inputs to one canvas (batch prep, model inputs that demand a fixed size). Aspect ratio is never broken.
- **bugs / lags + fixes:** none known. Limitation, not a bug: padding color is white or black only on this version; for an arbitrary fill color you would composite onto a `SolidMask`-derived background or use a different pad node.
- **anti-patterns:** reach for this only when you want letterboxing; if you want to crop-to-fill (no bars, fill the frame and lose the overflow) use `ResizeImageMaskNode` with `scale dimensions` + `crop: center`. It pads, it does not crop. Pixel-art inputs want `nearest-exact`, not the default-ish smooth filters.
- **placement:** inline on an `IMAGE` line, typically just before a stage that requires a fixed input size, or when assembling mixed-size images into one uniform batch.

### RepeatImageBatch  (display: "Repeat Image Batch")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_images`) | https://github.com/comfyanonymous/ComfyUI
- **category:** `image/batch` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** duplicate an image into a batch of N identical copies. Used to fan one image out so a later node processes (or varies) it N times.
- **inputs:**
  - `image` (`IMAGE`) - the image to repeat. If you pass a batch in, the whole batch is tiled `amount` times.
  - `amount` (`INT`, default 1, 1..4096) - how many copies. `amount: 1` is a passthrough.
- **outputs:**
  - `IMAGE` (`IMAGE`) - the batched copies, ready for any node that runs per-image over a batch.
- **how it works:** tiles the input along the batch dimension `amount` times; the copies are exact duplicates (no variation is added here).
- **strengths:** trivial way to set a batch count from an existing image (e.g. make N img2img variations off one source by repeating then sampling with a randomized seed downstream).
- **bugs / lags + fixes:** none known.
- **anti-patterns:** it copies, it does not vary; the variation has to come from a later node (a per-batch seed in the sampler, etc.). It is not a video/animation generator, the frames are identical. A large `amount` multiplies VRAM and time at every downstream node, so it is easy to OOM by over-repeating.
- **placement:** inline on an `IMAGE` line, before the node whose batch size you want to drive (a sampler doing img2img, a batched preview, a per-image effect).

### SolidMask  (display: "Create Solid Mask")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_mask`) | https://github.com/comfyanonymous/ComfyUI
- **category:** `image/mask` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** generate a flat, uniform mask of a chosen value and size. The building block for compositing backgrounds and for seeding `MaskComposite` operations.
- **inputs:**
  - `value` (`FLOAT`, default 1.0, 0..1) - the mask level everywhere: 1.0 fully white (selected / opaque), 0.0 fully black (unselected / transparent), anything between is a uniform gray.
  - `width` (`INT`, default 512) - mask width in pixels.
  - `height` (`INT`, default 512) - mask height in pixels.
- **outputs:**
  - `MASK` (`MASK`) - the uniform single-channel mask at the given size.
- **how it works:** allocates a single-channel tensor of `width` x `height` filled with `value`.
- **strengths:** the canonical way to make a blank canvas mask of exactly the size you need; the `destination` you paste a `source` mask onto in `MaskComposite`; a uniform alpha to attach with `JoinImageWithAlpha`.
- **bugs / lags + fixes:** none known.
- **anti-patterns:** its size is set by `width`/`height`, not derived from any image; if it must line up with an image, set the dimensions to match (or resize it with `ResizeImageMaskNode` `match size`), otherwise `MaskComposite` / compositing against a different-sized image misaligns. It carries no shape or selection, it is uniform by definition.
- **placement:** a leaf feeding the mask side of a graph: into `MaskComposite.destination`, into `JoinImageWithAlpha.alpha`, or as a plain background layer.

### MaskComposite  (display: "Combine Masks")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_mask`) | https://github.com/comfyanonymous/ComfyUI
- **category:** `image/mask` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** combine two masks into one by pasting `source` onto `destination` at an offset, using a chosen pixel operation. The mask-math / mask-layering node.
- **inputs:**
  - `destination` (`MASK`) - the base mask written into (often a `SolidMask` of the target size).
  - `source` (`MASK`) - the mask combined onto the destination.
  - `x` (`INT`, default 0, 0..16384) - horizontal offset of the source within the destination, in pixels.
  - `y` (`INT`, default 0, 0..16384) - vertical offset of the source, in pixels.
  - `operation` (`COMBO`: `multiply`, `add`, `subtract`, `and`, `or`, `xor`) - how the two are combined per pixel. `add`/`or` grow the selection, `subtract` cuts the source area out of the destination, `multiply`/`and` keep the overlap, `xor` keeps the non-overlapping parts.
- **outputs:**
  - `MASK` (`MASK`) - the combined mask.
- **how it works:** places `source` at (`x`, `y`) over `destination` and combines the overlapping region with the selected operation; the result is the size of `destination`.
- **strengths:** the core tool for building compound masks (union, intersection, difference) and for positioning a small mask inside a larger canvas; offset control lets you place a selection precisely.
- **bugs / lags + fixes:** none known. Note the result takes the `destination` size, so a `source` larger than the destination (or pushed past its edge by the offset) is clipped.
- **anti-patterns:** mismatched sizes are the usual surprise: the output is clipped to `destination`, so size the destination deliberately (a `SolidMask` of the canvas size is the common pattern). It composites masks, not images; for compositing pixel images use an image-composite node. Picking the wrong operation (e.g. `add` when you meant `subtract`) silently gives the wrong selection rather than erroring.
- **placement:** mid mask-chain. Fed by mask sources (`SolidMask`, `LoadImage`'s `MASK`, `ThresholdMask`, a detector); feeds whatever consumes the final mask (an inpaint encode, `JoinImageWithAlpha`, a mask preview).

### ThresholdMask  (display: "Threshold Mask")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_mask`) | https://github.com/comfyanonymous/ComfyUI
- **category:** `image/mask` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** binarize a soft (grayscale) mask: every pixel above the threshold becomes selected, everything else unselected. Cleans a feathered or probabilistic mask into a hard one.
- **inputs:**
  - `mask` (`MASK`) - the soft mask to threshold.
  - `value` (`FLOAT`, default 0.5, 0..1) - the cutoff. Pixels above `value` go to the selected level, the rest to unselected. Raise it to keep only the most confident areas, lower it to include more.
- **outputs:**
  - `MASK` (`MASK`) - the thresholded (hard-edged) mask.
- **how it works:** compares each mask pixel against `value` and pushes it to one of two levels, producing a binary mask.
- **strengths:** removes gray fringe from segmentation / detector masks so downstream compositing or inpaint has a crisp boundary; one knob.
- **bugs / lags + fixes:** none known.
- **anti-patterns:** thresholding throws away the soft falloff, so the result has hard, possibly jagged edges; if you wanted a smooth blend, do not threshold (or blur afterward). The default 0.5 is not always right, a poorly exposed mask may need a different cutoff. It does not grow or shrink the selection, only hard-cuts at the level (use a grow/shrink or blur node for that).
- **placement:** inline on a `MASK` line right after the source that produces a soft mask (a segmenter, a depth/edge-derived mask), before a consumer that wants a clean binary selection.

### MaskToImage  (display: "Convert Mask to Image")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_mask`) | https://github.com/comfyanonymous/ComfyUI
- **category:** `image/mask` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** convert a single-channel `MASK` into a viewable grayscale `IMAGE`. The bridge from the mask domain into anything that consumes `IMAGE`.
- **inputs:**
  - `mask` (`MASK`) - the mask to convert.
- **outputs:**
  - `IMAGE` (`IMAGE`) - the mask rendered as a grayscale RGB image (white = selected, black = unselected).
- **how it works:** expands the one-channel mask to a 3-channel image where each channel equals the mask value.
- **strengths:** lets you `SaveImage` / `PreviewImage` a mask, feed a mask into an IMAGE-only node, or blend a mask visually. The simple counterpart to `ImageToMask`.
- **bugs / lags + fixes:** none known.
- **anti-patterns:** for the specific goal of just looking at a mask in the UI, `MaskPreview` does it in one node (no separate preview needed). Converting to IMAGE and back via `ImageToMask` is a needless round-trip if you only needed the mask. It produces grayscale; it is not a colorize.
- **placement:** inline, bridging a `MASK` line into the IMAGE world: before `SaveImage`/`PreviewImage`, or into an IMAGE input that has no MASK equivalent.

### JoinImageWithAlpha  (display: "Join Image with Alpha")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_compositing`) | https://github.com/comfyanonymous/ComfyUI
- **category:** `image/compositing` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** attach a mask to an image as its alpha channel, producing an RGBA image with transparency. The way to turn a cutout mask into an actually transparent PNG.
- **inputs:**
  - `image` (`IMAGE`) - the RGB image to receive an alpha channel.
  - `alpha` (`MASK`) - the mask used as alpha: white stays opaque, black becomes transparent. Sizes should match the image, or the alpha will not line up.
- **outputs:**
  - `IMAGE` (`IMAGE`) - the RGBA image (alpha embedded); save it with `SaveImage` to get a PNG with real transparency.
- **how it works:** takes the RGB from `image` and the single-channel `alpha` mask and stacks them into a 4-channel RGBA image.
- **strengths:** the standard cutout-to-transparent-PNG step; pairs naturally with a background-removal or segmentation mask to export a subject on transparency.
- **bugs / lags + fixes:** none known. Mismatched image/alpha sizes misalign the transparency; resize the mask to the image first (`ResizeImageMaskNode` `match size`) if they differ.
- **anti-patterns:** the alpha is a `MASK`, not an `IMAGE`; feeding an RGB image where the mask goes is a type mismatch. Saving the RGBA result as JPEG drops the alpha (JPEG has no transparency), use PNG. It composites alpha onto one image, it does not blend two images over each other (that is an image-over-image composite node).
- **placement:** near the end of a cutout branch: fed by an `IMAGE` and a subject `MASK` (from background removal / segmentation), feeding `SaveImage` to write a transparent PNG.

### MaskPreview  (display: "Preview Mask")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_mask`) | https://github.com/comfyanonymous/ComfyUI
- **category:** `image/mask` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** display a `MASK` in the UI for inspection / debugging, without wiring a separate convert-then-preview pair.
- **inputs:**
  - `mask` (`MASK`) - the mask to view.
- **outputs:** none. Output (terminal) node, `output_node: true`.
- **how it works:** converts the single-channel mask to a viewable image internally and saves it to the output area for the UI to show; functionally `MaskToImage` + `PreviewImage` in one node (its description string says it saves images to the output directory).
- **strengths:** the quickest way to eyeball a mask while building a graph; one node, no conversion wiring.
- **bugs / lags + fixes:** none known.
- **anti-patterns:** it is a preview sink, it returns nothing, so you cannot wire its result onward; if you need the mask-as-image in the graph, use `MaskToImage`. To overlay the mask on top of the image to judge the selection in context, use a node built for that (e.g. KJNodes' `ImageAndMaskPreview`, which composites mask over image), not this.
- **placement:** a leaf off any `MASK` line you want to inspect; drop it next to a mask source or after `MaskComposite` / `ThresholdMask` to check the result.
