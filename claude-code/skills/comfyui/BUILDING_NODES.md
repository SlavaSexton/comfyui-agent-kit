# Building a custom node pack - the hard-won field guide

The distilled lessons from building **ComfyUI-OCIO** (our eight-node OpenColorIO pack, 2026-06/07). This is the
"how it actually goes" layer on top of the `comfyui-node-*` node-building skills (Layer 4): the gotchas that cost
real time, so the next node pack does not re-pay them. When you write or modify a custom node, read this first.

Everything here is confirmed - it is what we hit and fixed shipping ComfyUI-OCIO.

## The node shape (Python)

A node is a class in a module ComfyUI imports from `custom_nodes/<pack>/__init__.py`:

- `INPUT_TYPES(cls)` (a `@classmethod`) returns `{"required": {...}, "optional": {...}}`. Each entry is a
  `(type, opts)` tuple: `("IMAGE",)`, `("INT", {"default":0,"min":0})`, `("STRING", {"default":""})`,
  `(["a","b"], {"default":"a"})` for a combo, `("BOOLEAN", {"default":False})`, `("MASK",)`, `("FLOAT", {...})`.
- `RETURN_TYPES` / `RETURN_NAMES` (tuples), `FUNCTION` (the method name), `CATEGORY`, optional
  `OUTPUT_NODE = True` (a save/preview node with no downstream).
- `NODE_CLASS_MAPPINGS` / `NODE_DISPLAY_NAME_MAPPINGS` dicts; `WEB_DIRECTORY = "./web"` if you ship JS.
- Combos populate at DEFINITION time. If a combo lists names from an external config (colorspaces, LUT files),
  build the list inside `INPUT_TYPES` each call - it re-runs when `/object_info` is queried, so it picks up new
  files without a code reload.

**Widget order == `widgets_values` order.** ComfyUI serialises a saved workflow's widget values positionally, in
the order the widget entries appear in `INPUT_TYPES` (required then optional), skipping connection inputs
(IMAGE / MASK / LATENT ...). If you reorder or insert a widget, old saved workflows shift by one and load with
wrong values. When you change the widget set, rebuild your example workflow. (Trailing extra values from an older
schema are harmless - ComfyUI ignores them.)

**The function receives inputs as kwargs by name**, so the signature order does not matter, but the NAMES must
match `INPUT_TYPES` keys exactly (so a widget key must be a valid Python identifier - no `/`, no spaces).

## The combo-validation trap (this one bit hard)

`/prompt` VALIDATES a combo input against its option list. **Pass a value not in the list and the whole prompt is
rejected with HTTP 400**, not a soft fallback. So:

- A combo is right when the choices are a closed, known set (colorspaces from the config, formats, codecs).
- A combo is WRONG when the user needs an arbitrary value - **a file path**. We first made OCIO Read's `source` a
  combo of input-folder files; a real image sequence lives at an absolute disk path (`D:\shots\...`), which is
  not in that list, so it could not be selected at all. **Fix: make it a `STRING`.** A STRING accepts anything
  and is not validated, so any path works. Reach for STRING + a browse button whenever the value is open-ended.

## The JS front end (`web/*.js`)

Ship UI behaviour as an `app.registerExtension` with `beforeRegisterNodeDef(nodeType, nodeData)`; hook
`nodeType.prototype.onNodeCreated` to add buttons and wrap widget callbacks. Patterns we rely on:

- **Buttons:** `node.addWidget("button", label, null, callback, { serialize: false })` (serialize:false so it is
  not stored in the workflow).
- **Set a widget value:** find it with `node.widgets.find(w => w.name === name)`, set `w.value`, push into
  `w.options.values` if it is a combo, call `w.callback(v)` if you want reactions, then `node.setDirtyCanvas`.
- **`setWSilent` (value without firing the callback).** Critical when auto-filling widgets: if your "manual edit
  turns auto OFF" logic lives in a widget's wrapped callback, then auto-setting that widget with a normal setter
  fires the callback and turns itself off. Use a silent setter (just `w.value = v`) for programmatic fills; the
  user's real drag still fires the callback. This is how OCIO Write tells an auto-sync from a manual edit.
- **React to a widget change:** wrap its `callback` - store the original, set `w.callback = (v) => { orig?.(v);
  yourHandler(v); }`.
- **Conditional visibility (show a widget only when relevant, e.g. codec only for a video container).** There is
  no native hide. The working trick: swap the widget's `type` to an unknown string (litegraph's draw switch
  skips it) and set `computeSize = () => [0, -4]` (zero height; the `-4` cancels the row spacing), plus
  `w.hidden = true` for newer ComfyUI; restore both to show. Then `node.setSize([w, node.computeSize()[1]])`.
- **On-node labels:** `onDrawForeground(ctx)` draws in node-local coords - the title bar is at negative y, the
  body starts at 0. We draw the colorspace label in the title bar (`ctx.textAlign="right"; fillText(..., size[0]-8, -6)`)
  and the missing-frame list / "wrote N frames" near the bottom.
- **Post-run info:** `onExecuted(message)` receives the node's `ui` dict from the run - return
  `{"ui": {"images": [...], "count": [str(n)]}, "result": (...)}` from Python and read `message.count` in JS to
  show "wrote N frames". (For a live thumbnail on any node, return `ui.images` like SaveImage does.)
- **Cross-node auto (pull a value along the wire).** Walk `node.inputs[i].link` -> `app.graph.links[id]` ->
  `app.graph.getNodeById(origin_id)` recursively until you find the upstream node type you want, then read its
  widgets. OCIO Write traces back to OCIO Read (through any number of nodes) to auto-fill frame range + fps. To
  re-sync when the upstream changes, iterate `app.graph._nodes` from the upstream node's change handler; also
  re-sync on `onConnectionsChange` and `onConfigure` (loaded workflow) with a `setTimeout(..., 0)`.

## Server routes (upload, browse, detect)

For a node that needs the server's filesystem (browse a folder, upload a file, probe a sequence), register aiohttp
routes in `__init__.py`, guarded so a standalone import does not crash:

```python
try:
    import server; from aiohttp import web; import folder_paths
    @server.PromptServer.instance.routes.post("/yourpack/route")
    async def _handler(request): ...
except Exception:
    pass
```

We use three: `/ocio/upload` (multipart -> input folder, optional subfolder for a sequence), `/ocio/list_dirs`
(list server folders + media files for the browse dialog), `/ocio/seq_range` (detect a sequence's range + fps for
the JS auto-fill). The browse dialog is a DOM overlay the JS builds; the browser cannot pick a real server path
itself, so the server route does the listing.

## ComfyUI facts that shape the design

- **No color management.** ComfyUI holds images as plain gamma-encoded sRGB in `0..1` (LoadImage = `x/255`, no
  linearise; SaveImage = `x*255`). It is colorspace-unaware. Diffusion models were trained on that, so it is
  deliberate, not a bug. This is exactly why an OCIO pack is needed, and why its working space is `sRGB - Display`.
- **No timeline, no fps.** `IMAGE` is a batch `[B, H, W, C]`, float32, RGB, `0..1`-ish. There is no time - a
  sequence is just a batch of frames. fps is metadata only; it does not change the frame count. A real retime
  (dup/drop frames) is an explicit operation. Frame numbers are a labeling convention that only matters at read
  (which files) and write (output filenames).
- **Alpha is a separate `MASK`**, not a 4th channel of IMAGE. Output an alpha as a MASK (like LoadImage does),
  take one as an optional MASK input, and combine into RGBA yourself at write time.
- **`IS_CHANGED` footgun:** a node that should re-run but does not - return `float("NaN")` from `IS_CHANGED` to
  force it (or bust a real input). A seed change that does nothing = stale cache.

## IO libraries

- **cv2 (OpenCV):** EXR / DPX read + write, RGBA supported, EXR half vs float via `IMWRITE_EXR_TYPE`. **EXR needs
  `OPENCV_IO_ENABLE_OPENEXR=1` in the environment BEFORE cv2 is imported** - set it in the ComfyUI launch command,
  not in your module (cv2 is usually already imported by the time your node loads).
- **tifffile:** TIFF 8/16/32-float + a `description=` metadata tag. **Pillow:** PNG (text chunk metadata) / JPEG
  (comment) - PIL 16-bit RGB is limited, use cv2 for 16-bit PNG.
- **ffmpeg (external binary):** video decode/encode - ProRes / DNxHR / h264 / hevc all come from it. Find it with
  `shutil.which("ffmpeg")`, fall back to bare `"ffmpeg"` (PATH), and fail with a CLEAR message if missing rather
  than a raw `FileNotFoundError`. `ffprobe` (metadata) ships with a full ffmpeg; derive its path from ffmpeg's
  basename, NOT by string-replacing "ffmpeg" in the whole path (that corrupts a directory like `ffmpeg-2024-.../`).

## Verify like you mean it (Fable 5)

- **Compile is not "works".** `py_compile` catches syntax, nothing else. To know a node works, **enqueue it
  through `/prompt`** on a running ComfyUI and read the result (`/history/<id>` status + outputs). A node import
  error shows in the boot log and the node is simply absent from `/object_info`.
- **Run the REAL entry path, on REAL files.** We tested every node on toy files in ComfyUI's input folder and
  called it done - and missed that a user's sequences live at absolute paths on another drive, which the
  input-only combo could not even select. Test the way the user actually loads: a real sequence at a real disk
  path, opened the way they open it. A green test on the dev setup you happen to have is not proof of the path
  the work ships into.
- **Deploy = the source of truth.** Our repo is the source; ComfyUI loads a `cp`-copy in `custom_nodes`. After
  every edit, `cp` to `custom_nodes` and restart the server (kill the port, relaunch with the env vars) - editing
  the source without re-copying means the running server has stale code and "my fix did not take".
- **Interop is a claim to verify.** "It uses standard IMAGE" - prove it: run your node into a stock node and a
  stock node into yours, both through `/prompt`. We confirmed OCIO Read -> core `ImageScaleBy` -> `SaveImage` and
  `LoadImage` -> OCIO Write.

## When you build the demo workflow

Lay it out with `shared/comfyui/workflow_layout.py` (`auto_layout` + `inspect` + `fit_group`) - never eyeball a
graph from a screenshot (see SKILL.md "Lay the graph out cleanly"). Bundle any asset the workflow needs (image,
LUT) in the repo and make the paths portable (relative to the input folder), with a one-line "copy these into
input" note. Then **run the whole workflow once** (convert the UI graph to the `/prompt` API format and enqueue)
to confirm it opens and executes - that is what the user does.
