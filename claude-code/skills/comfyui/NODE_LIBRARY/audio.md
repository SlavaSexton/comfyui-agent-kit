# Audio

The core `audio` family: the small set of nodes ComfyUI ships for getting audio into a graph, moving it
around, and writing it back out. They live in `comfy_extras.nodes_audio` (confirmed via get_node_info
`python_module`, 2026-06-30) and all carry the `audio` menu category. The common currency is the `AUDIO`
type (a waveform plus its sample rate); a loader or recorder produces it, a save node consumes it, and the
concat node both takes and returns it. These are the building blocks for audio-model pipelines (TTS, music,
audio-to-video conditioning): the model node sits in the middle, a loader/recorder feeds it, a save node ends
it. All I/O below is **confirmed via get_node_info: 2026-06-30** (ComfyUI 0.25.1) from the provided pull; the
semantics, placement, and gotchas are the curated layer. Any input typed `COMBO` of file names is one
machine's installed/uploaded files, so it is described as "a dropdown of installed/uploaded files", never
hardcoded.

---

### LoadAudio  (display: "Load Audio")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_audio`) | **category:** `audio` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** bring an audio file into the graph as an `AUDIO` object, the standard entry point for any audio pipeline.
- **inputs:**
  - `audio` (`COMBO`) - a dropdown of uploaded audio files (the widget carries `audio_upload: true`, so you upload a file through it and it then appears in the list, the same pattern as `LoadImage`). Files are read from the ComfyUI `input` folder. The list reflects whatever is uploaded on this machine; do not assume any specific filename. Common containers (wav, mp3, flac, and audio tracks inside video files) are accepted.
- **outputs:**
  - `AUDIO` (`AUDIO`) - the decoded waveform plus its sample rate; feeds an audio-model node, `AudioConcat`, or directly a save node.
- **how it works:** reads the selected file, decodes it to a waveform tensor at its sample rate, and returns it as the `AUDIO` type the rest of the audio nodes speak.
- **strengths:** the one node to get existing audio off disk and into a graph; the upload-through-the-widget flow means you do not have to pre-place files by hand.
- **bugs / lags + fixes:** none known in the node.
- **anti-patterns:** expecting it to record from a microphone (that is `RecordAudio`) or to generate audio (that is a model node). The dropdown only lists files that are actually present/uploaded; an empty list means nothing is in the `input` folder, not a node fault.
- **placement:** a leaf at the edge of the graph. Nothing feeds it; it feeds the first audio consumer (a model node, `AudioConcat`, or a save node).

### SaveAudioMP3  (display: "Save Audio (MP3) (Deprecated)")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_audio`) | **category:** `audio` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** write an `AUDIO` signal to disk as an MP3 file. This is an output (terminal) node.
- **inputs:**
  - `audio` (`AUDIO`) - the waveform to encode, from a model node, `LoadAudio`, `RecordAudio`, or `AudioConcat`.
  - `filename_prefix` (`STRING`, default `audio/ComfyUI`) - path/name prefix under the ComfyUI `output` folder; the leading `audio/` puts files in an `audio` subfolder.
  - `quality` (`COMBO`, default `V0`) - MP3 encode quality. Confirmed options: `V0`, `128k`, `320k`. `V0` is LAME variable-bitrate near-transparent; `128k`/`320k` are constant bitrate.
- **outputs:** none (output_node: writes the MP3, returns nothing to the graph).
- **how it works:** encodes the incoming waveform to MP3 at the chosen quality and saves it under `output/<filename_prefix>`.
- **strengths:** small, widely-playable files; the smallest-footprint of the audio save options.
- **bugs / lags + fixes:** ComfyUI flags this node `deprecated: true` (confirmed via get_node_info, 2026-06-30): the display name itself reads "(Deprecated)". The intended replacement is the unified `SaveAudio` node, which writes FLAC and supersedes the per-format save nodes (inferred from the deprecation flag and the parallel deprecation of `SaveAudioOpus`; confirm `SaveAudio`'s I/O with get_node_info before wiring it). MP3 is lossy, so the save itself loses quality regardless of node state.
- **anti-patterns:** using it as a lossless archive sink (MP3 is lossy; for an exact copy use the FLAC `SaveAudio`). Building new graphs on it given the deprecation; prefer the current save node. Feeding it anything other than `AUDIO`.
- **placement:** the leaf at the end of an audio graph. Sits where `SaveImage` would in an image graph.

### SaveAudioOpus  (display: "Save Audio (Opus) (Deprecated)")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_audio`) | **category:** `audio` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** write an `AUDIO` signal to disk as an Opus file (Ogg/Opus). This is an output (terminal) node.
- **inputs:**
  - `audio` (`AUDIO`) - the waveform to encode, from a model node, `LoadAudio`, `RecordAudio`, or `AudioConcat`.
  - `filename_prefix` (`STRING`, default `audio/ComfyUI`) - path/name prefix under the ComfyUI `output` folder; the leading `audio/` puts files in an `audio` subfolder.
  - `quality` (`COMBO`, default `128k`) - Opus target bitrate. Confirmed options: `64k`, `96k`, `128k`, `192k`, `320k`.
- **outputs:** none (output_node: writes the Opus file, returns nothing to the graph).
- **how it works:** encodes the incoming waveform to Opus at the chosen bitrate and saves it under `output/<filename_prefix>`.
- **strengths:** better quality-per-byte than MP3 at low bitrates; the right choice when size matters and you want modern lossy compression.
- **bugs / lags + fixes:** ComfyUI flags this node `deprecated: true` (confirmed via get_node_info, 2026-06-30); the display name reads "(Deprecated)". Same successor story as `SaveAudioMP3`: the unified `SaveAudio` (FLAC) node is the intended replacement (inferred from the deprecation flag; confirm its I/O with get_node_info). Opus is lossy.
- **anti-patterns:** using it for a lossless master (Opus is lossy; use the FLAC `SaveAudio` for that). Reaching for Opus when broad device/player compatibility matters (MP3 is more universally accepted). Building new graphs on a deprecated node. Feeding non-`AUDIO`.
- **placement:** the leaf at the end of an audio graph, an alternative sink to `SaveAudioMP3`.

### AudioConcat  (display: "Concatenate Audio")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_audio`) | **category:** `audio` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** join two `AUDIO` clips into one, end to end, in a chosen order.
- **inputs:**
  - `audio1` (`AUDIO`) - the first clip (the reference the other is placed relative to).
  - `audio2` (`AUDIO`) - the second clip, appended after or before `audio1`.
  - `direction` (`COMBO`, default `after`) - where `audio2` goes relative to `audio1`. Confirmed options: `after`, `before` (the node tooltip: "Whether to append audio2 after or before audio1.").
- **outputs:**
  - `AUDIO` (`AUDIO`) - the single concatenated clip; feeds another `AudioConcat` (chain to join more than two), a save node, or an audio consumer.
- **how it works:** sequences the two waveforms into one along the time axis, ordered by `direction`. Concatenation is time-domain joining (one clip then the other), not mixing/overlaying.
- **strengths:** the simple way to stitch clips in sequence; chainable to assemble several; order is explicit via `direction`.
- **bugs / lags + fixes:** none known. Joining two clips that differ in sample rate or channel count is the obvious risk area for any concat (the result is only well-defined when both clips share format); the provided pull does not expose how this node reconciles a mismatch, so confirm behavior on real differing inputs rather than assuming it resamples. Not a node bug, a property to verify.
- **anti-patterns:** expecting it to mix/overlay or crossfade (it sequences, it does not blend). Confusing it with the KJNodes `AudioConcatenate` (display "AudioConcatenate", `custom_nodes.comfyui-kjnodes`, category `KJNodes/audio`, confirmed via get_node_info 2026-06-30), which does the same job but whose `direction` options are `right`/`left` instead of `after`/`before`; in a graph that has both packs, pick the one you mean by class_type, not by the menu label. Feeding non-`AUDIO`.
- **placement:** mid-graph on the `AUDIO` line, between the clip sources (`LoadAudio` / `RecordAudio` / a model node) and a save node or further processing.

### RecordAudio  (display: "Record Audio")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_audio`) | **category:** `audio` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** capture audio from the browser's microphone and bring it into the graph as an `AUDIO` object.
- **inputs:**
  - `audio` (`AUDIO_RECORD`) - a record widget (the `AUDIO_RECORD` type is a front-end mic-capture control, not a wire you connect): you record a clip in the ComfyUI UI and it becomes the node's data. Because it depends on a browser microphone, it works from the UI, not from a headless/API run with no mic.
- **outputs:**
  - `AUDIO` (`AUDIO`) - the recorded waveform; feeds an audio-model node, `AudioConcat`, or a save node, the same as `LoadAudio`'s output.
- **how it works:** the `AUDIO_RECORD` widget records from the microphone in the browser; the node returns that capture as the standard `AUDIO` type.
- **strengths:** get a voice/audio prompt into a graph live without first saving a file; the quickest path for "speak a clip and use it".
- **bugs / lags + fixes:** none known in the node. The practical limit is the environment: no microphone, no browser, or a denied mic permission means nothing to capture. That is an environment constraint, not a node fault.
- **anti-patterns:** relying on it in an automated/headless or scheduled run (there is no mic to record from); use `LoadAudio` with a pre-recorded file there. Treating `AUDIO_RECORD` as a connectable input port (it is a UI widget, you do not wire another node into it).
- **placement:** a leaf at the edge of the graph, an alternative source to `LoadAudio`. Nothing feeds it; it feeds the first audio consumer.
