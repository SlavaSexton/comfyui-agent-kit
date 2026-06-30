# Video

The core `video` family: nodes that assemble an `IMAGE` batch (plus optional `AUDIO`) into a `VIDEO` object, pull a `VIDEO` back apart into its components, trim it, load one off disk, and write it out. They all ship in core ComfyUI's `comfy_extras.nodes_video` module (confirmed via get_node_info `python_module`, 2026-06-30, ComfyUI 0.25.1) and live in the `video` menu category. The pivot type is `VIDEO`: a container that carries frames, framerate, and audio together, distinct from a raw `IMAGE` batch. `CreateVideo` builds one, `GetVideoComponents` reverses it, `SaveVideo` / `SaveWEBM` are the terminal sinks. All I/O below is confirmed via get_node_info: 2026-06-30; the semantics, placement, and gotchas are the curated layer. Any input typed `COMBO` of file names is one machine's installed files, so it is described as "a dropdown of installed <thing> files", never hardcoded.

---

### CreateVideo  (display: "Create Video")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_video`) | **category:** `video` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** pack a sequence of frames (and optionally an audio track) into a single `VIDEO` object that the save nodes and other video nodes consume. This is the assembly point that turns the per-frame output of a diffusion graph into a video.
- **inputs:**
  - `images` (`IMAGE`) - the ordered frame batch to turn into a video. Frame order is the batch order; this is what most video model graphs (decoded latent frames) feed here.
  - `fps` (`FLOAT`, default 30.0) - playback framerate. Set it to match what the model was sampled at; a mismatch makes motion play too fast or too slow. Range is 1 to 120.
  - `audio` (`AUDIO`, optional) - an audio track to mux into the video. Leave unconnected for a silent video.
  - `bit_depth` (`INT`, optional, default 8, values 8 or 10) - per-channel bit depth of the assembled video. 10-bit keeps smoother gradients with less banding, but some players and downstream nodes may not support it, so leave it at 8 unless you specifically need the extra precision and know the consumer handles it.
- **outputs:**
  - `VIDEO` (`VIDEO`) - the assembled video container (frames + framerate + any audio); feeds `SaveVideo`, `GetVideoComponents`, `Video Slice`, or any node taking a `VIDEO`.
- **how it works:** collects the frame batch with the given fps and optional audio into an in-memory `VIDEO` object. It does not write a file by itself; that is the save node's job.
- **strengths:** the standard, one-node way to go from decoded frames to a `VIDEO`; muxes audio in the same step; exposes bit depth for higher-quality intermediates.
- **bugs / lags + fixes:** none known in the node.
- **anti-patterns:** wiring an `IMAGE` batch straight into `SaveVideo` (which wants a `VIDEO`, not an `IMAGE`); build the `VIDEO` here first, or use `SaveWEBM`, which takes `IMAGE` directly. Setting `fps` to a value that does not match the sampling rate of the model. Choosing 10-bit when the downstream save codec or target player cannot handle it.
- **placement:** after `VAEDecode` (or whatever produces the frame `IMAGE` batch), before `SaveVideo` / `Video Slice` / `GetVideoComponents`. The bridge from the pixel-space frames to the `VIDEO` type.

### SaveVideo  (display: "Save Video")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_video`) | **category:** `video` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** write a `VIDEO` object to the ComfyUI output directory as a container file. This is an output (terminal) node (`output_node: true`).
- **inputs:**
  - `video` (`VIDEO`) - the video to save, normally from `CreateVideo` or `Video Slice`. (Note: the node's own description string reads "Saves the input images", but the actual input is a `VIDEO`, not an `IMAGE`; the description is stale copy from an image-save node. Feed it a `VIDEO`.)
  - `filename_prefix` (`STRING`, default `video/ComfyUI`) - the output path prefix. Supports tokens like `%date:yyyy-MM-dd%` and `%Empty Latent Image.width%` to pull values from other nodes. The default writes into a `video/` subfolder of the output dir.
  - `format` (`COMBO`, default `auto`) - the container format. `auto` lets the node pick; the explicit choice in this build is `mp4`.
  - `codec` (`COMBO`, default `auto`) - the video codec. `auto` lets the node pick; the explicit choice in this build is `h264`.
- **outputs:** none (output node: writes the file, returns nothing to the graph).
- **how it works:** encodes the `VIDEO` (its frames, framerate, and any muxed audio) into the chosen container/codec and writes it to disk under the prefix.
- **strengths:** the default video sink; carries audio through automatically because it operates on the `VIDEO` container, not a bare frame batch; `auto` settings give a sane mp4/h264 result without tuning.
- **bugs / lags + fixes:** none known in the node. The misleading "input images" description (above) is a documentation bug in the node, not a runtime one.
- **anti-patterns:** feeding it an `IMAGE` batch instead of a `VIDEO` (use `CreateVideo` first, or use `SaveWEBM` for direct `IMAGE` input). Expecting transparency: h264/mp4 has no alpha channel, so for transparent video use `SaveWEBM` with vp9. Expecting a fine-grained quality knob here; for explicit CRF control use `SaveWEBM`.
- **placement:** the leaf at the end of a video graph, after `CreateVideo` (optionally via `Video Slice`).

### GetVideoComponents  (display: "Get Video Components")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_video`) | **category:** `video` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** the inverse of `CreateVideo`: split a `VIDEO` back into its parts so a graph can process the frames, the audio, or read the framerate. The way to get an editable `IMAGE` batch out of a loaded or assembled video.
- **inputs:**
  - `video` (`VIDEO`) - the video to decompose, typically from `LoadVideo`, `CreateVideo`, or `Video Slice`.
- **outputs:**
  - `images` (`IMAGE`) - the frame batch; feeds any IMAGE consumer (upscale, filter, re-encode, `VAEEncode` for video-to-video).
  - `audio` (`AUDIO`) - the audio track; feeds an audio node or back into `CreateVideo` to re-mux.
  - `fps` (`FLOAT`) - the source framerate; wire it into `CreateVideo.fps` (or `SaveWEBM.fps`) to preserve timing on re-encode.
  - `bit_depth` (`INT`) - the source per-channel bit depth; carry it back into `CreateVideo.bit_depth` to keep the same precision.
- **how it works:** demuxes the `VIDEO` container and returns each component as the matching ComfyUI type, with no re-encoding of its own.
- **strengths:** the entry point for any video-to-video or frame-editing pipeline; preserving `fps` and `bit_depth` through a round-trip is trivial because both are exposed as outputs to feed back into `CreateVideo`.
- **bugs / lags + fixes:** none known in the node. A long high-resolution video decoded to an `IMAGE` batch holds every frame in memory at once and can spike RAM/VRAM; trim with `Video Slice` first if you only need a segment.
- **anti-patterns:** decoding a whole long clip when you only need a slice (slice first). Dropping the `fps` output and then guessing a framerate at re-encode, which changes playback speed. Treating the `images` output as a single frame; it is the full batch.
- **placement:** right after the `VIDEO` source (`LoadVideo` / `CreateVideo` / `Video Slice`), at the front of the frame-processing part of the graph. Its `images` go into the pixel pipeline; its `fps` / `bit_depth` / `audio` are usually fed back into `CreateVideo` at the end.

### LoadVideo  (display: "Load Video")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_video`) | **category:** `video` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** load a video file from the ComfyUI input directory (with an upload control) as a `VIDEO` object, for video-to-video, re-encode, or audio-extraction workflows.
- **inputs:**
  - `file` (`COMBO`) - a dropdown of video files available to ComfyUI (input dir); the widget is an upload control (`video_upload: true` confirmed via get_node_info, 2026-06-30), so you can upload a file through it and it then appears as the selection. Empty dropdown = no videos uploaded yet.
- **outputs:**
  - `VIDEO` (`VIDEO`) - the loaded video container; feeds `GetVideoComponents` (to get frames/audio), `Video Slice` (to trim), or `SaveVideo` (to transcode).
- **how it works:** reads the selected file off disk and returns it as a `VIDEO` object, without decoding it to frames until a downstream node (such as `GetVideoComponents`) asks for them.
- **strengths:** the one-node way to get an external video into a graph; the built-in upload control means no manual file copying into the input folder.
- **bugs / lags + fixes:** none known in the node.
- **anti-patterns:** expecting an `IMAGE` batch straight out; it returns a `VIDEO`, so put `GetVideoComponents` after it to get frames. Expecting per-frame controls (frame cap, skip, stride, force-rate) here; this core loader has none. For that, the KJNodes / VideoHelperSuite loaders expose frame_load_cap, skip_first_frames, select_every_nth and force_rate (separate custom packs, out of scope for this core group).
- **placement:** the root of a video-to-video graph. Nothing feeds it; it feeds `GetVideoComponents` / `Video Slice` / `SaveVideo`.

### Video Slice  (display: "Video Slice")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_video`) | **category:** `video` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** trim a `VIDEO` to a time window (a start point and a duration) without decoding it to frames yourself, returning a shorter `VIDEO`.
- **inputs:**
  - `video` (`VIDEO`) - the source video to trim.
  - `start_time` (`FLOAT`, default 0.0) - where the slice begins, in seconds. Can be negative (the pull allows down to -100000), which addresses from the end rather than the start; use a plain positive offset for normal forward trimming.
  - `duration` (`FLOAT`, default 0.0) - length of the slice in seconds, or 0 for unlimited duration (everything from `start_time` to the end).
  - `strict_duration` (`BOOLEAN`, default false) - if true, when the requested duration is not possible (the clip is shorter than asked), the node raises an error instead of returning whatever is available. Leave false for best-effort trimming; set true when a downstream step needs an exact length and a short clip should fail loudly.
- **outputs:**
  - `VIDEO` (`VIDEO`) - the trimmed video; feeds `SaveVideo`, `GetVideoComponents`, or another video node.
- **how it works:** selects the `[start_time, start_time + duration)` window of the source `VIDEO` and returns it as a new `VIDEO`, operating on the container so timing and audio stay aligned. `duration` 0 means "to the end".
- **strengths:** cheap way to cut a clip to length before heavier processing (decode, upscale, re-encode), which keeps frame counts and memory down; `strict_duration` gives a hard guarantee when exact length matters.
- **bugs / lags + fixes:** none known in the node.
- **anti-patterns:** leaving `strict_duration` true when you actually want best-effort behavior, which turns a short source into a hard error. Relying on negative `start_time` without testing how your build resolves it; for ordinary trimming, a positive offset is unambiguous. Expecting frame-accurate cuts on a long-GOP codec; container-level slicing snaps to nearby keyframes on some formats, so exact-frame trims may land slightly off.
- **placement:** between a `VIDEO` source (`LoadVideo` / `CreateVideo`) and the rest of the graph, to cut length before decode or save.

### SaveWEBM  (display: "Save WEBM")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_video`) | **category:** `video` (marked experimental, confirmed via get_node_info `experimental: true`, 2026-06-30) | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** encode an `IMAGE` frame batch directly to a WebM file (vp9 or av1), with explicit quality (CRF) control and optional alpha-channel transparency. Takes frames directly, unlike `SaveVideo` which needs a `VIDEO`. This is an output (terminal) node (`output_node: true`).
- **inputs:**
  - `images` (`IMAGE`) - the frame batch to encode. RGBA images are saved with their alpha channel as transparency, but only with the vp9 codec.
  - `filename_prefix` (`STRING`, default `ComfyUI`) - the output path prefix; supports the same token substitution as the other save nodes.
  - `codec` (`COMBO`) - the WebM video codec; the options in this build are vp9 and av1. vp9 is the one that supports alpha; av1 generally gives better compression but is slower to encode.
  - `fps` (`FLOAT`, default 24.0) - playback framerate; set it to match the source rate so motion plays at the right speed.
  - `crf` (`FLOAT`, default 32.0, range 0 to 63) - constant rate factor: higher crf means lower quality with a smaller file, lower crf means higher quality and a larger file. Lower it for a higher-quality export.
- **outputs:** none (output node: writes the WebM file, returns nothing to the graph).
- **how it works:** encodes the frame batch to a WebM container with the chosen codec at the given CRF and framerate, writing straight from an `IMAGE` batch (no separate `CreateVideo` step needed). With vp9 and RGBA input, the alpha channel is preserved as transparency.
- **strengths:** the way to get a transparent (alpha) video out of ComfyUI (vp9); direct `IMAGE` input, so no `CreateVideo` in between; an explicit CRF quality dial that `SaveVideo` does not expose; WebM is small and web-friendly.
- **bugs / lags + fixes:** none known beyond it being flagged experimental in this build (`experimental: true`), so its inputs or behavior may shift between ComfyUI versions; re-confirm with get_node_info if a graph that used it breaks after an update.
- **anti-patterns:** expecting alpha with av1; transparency is vp9-only here, so a transparent export must use vp9. Feeding it a `VIDEO` object; this node takes an `IMAGE` batch (use `GetVideoComponents` to get frames from a `VIDEO`, or use `SaveVideo` for a `VIDEO`). Muxing audio here; this is a frames-to-WebM encoder with no audio input, so for audio use the `CreateVideo` + `SaveVideo` path. Leaving crf at a high value when quality matters (raise quality by lowering crf).
- **placement:** a leaf at the end of the graph, fed by an `IMAGE` frame batch (straight from `VAEDecode`, or from `GetVideoComponents.images`).
