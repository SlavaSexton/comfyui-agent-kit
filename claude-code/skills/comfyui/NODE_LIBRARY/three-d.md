# 3D

The `3d` and `3d/splat` families: core ComfyUI nodes (all from `comfy_extras.*`, no custom pack) for loading, viewing, rendering, converting, and saving 3D assets. Two sub-groups sit here. The gaussian-splat set (`comfy_extras.nodes_gaussian_splat`: Render Splat, Extract Mesh from Splat, Create 3D File from Splat, Create Camera Info) takes a `SPLAT` object and either rasterizes it to images, bakes it to a mesh, or serializes it to a file. The mesh / viewport set (`comfy_extras.nodes_load_3d`, `nodes_save_3d`, `nodes_hunyuan3d`: Load 3D, Preview 3D, Save 3D Model, Voxel to Mesh) loads a model into an interactive viewport, previews it, writes it to disk, or turns a voxel grid into a mesh. The shared currency between them is a small set of 3D types: `SPLAT`, `MESH`, `VOXEL`, `LOAD3D_CAMERA` (a camera definition), and the `FILE_3D*` family of on-disk-file handles.

All I/O below is **confirmed via get_node_info: 2026-06-30** (live ComfyUI 0.25.1) from the provided slice, cross-checked against a live `get_node_info` pull the same day (which also resolved each display name, `python_module`, and the full tooltips). The semantics, placement, and gotchas are the curated layer. Any input typed `COMBO` of file names is one machine's installed files, so it is described as "a dropdown of installed <thing> files", never hardcoded. Several of these nodes are flagged `experimental: true` in the live pull (Load 3D, Preview 3D); that is noted per entry.

---

### RenderSplat  (display: "Render Splat")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_gaussian_splat`, confirmed via get_node_info `python_module`, 2026-06-30) | **category:** `3d/splat` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** rasterize a gaussian splat to one or more images. A single still, or a turntable batch of frames that can feed a video node.
- **inputs:**
  - `splat` (`SPLAT`) - the gaussian splat to render. The required input; comes from a splat-producing node upstream (a splat loader or a model that outputs `SPLAT`).
  - `width` (`INT`, default 1024) - output image width in pixels (live range 64 to 2048, step 8).
  - `height` (`INT`, default 1024) - output image height in pixels (live range 64 to 2048, step 8).
  - `frames` (`INT`, default 1) - `-1`, `0`, `1` all give a single still image; `>1` gives a turntable batch where the camera orbits a full 360 turn (works with any `camera_info`). A negative value orbits the other way. Live range -240 to 240.
  - `splat_scale` (`FLOAT`, default 1) - multiplier on each splat's projected footprint. Lower gives crisper points, higher gives a softer / fuller surface. Live range 0.1 to 5.
  - `sharpen` (`FLOAT`, default 2) - sharpen overlapping splats. `1.0` is the physically-correct blend; higher biases each pixel toward its dominant (nearest) splat for crisper texture, without shrinking splats or opening gaps. Non-physical above 1. Live range 1 to 8.
  - `headlight_shading` (`FLOAT`, default 0) - diffuse shading from a light at the camera (a headlight), using the splat surfel normals. Darkens surfaces that turn away from view to reveal form / curvature. `0` = flat albedo, `1` = strongest shading. Live range 0 to 3.
  - `opacity_threshold` (`FLOAT`, default 0) - cull gaussians with opacity below this, which removes faint floaters. Live range 0 to 1.
  - `render_style` (`COMBO`) - what the `image` output shows: `color`, `clay` (neutral-albedo shaded), `depth` (near = bright), or `normal` (OpenGL normal map).
  - `background` (`COLOR`, default `#000000`) - solid background colour behind the splat.
  - `bg_image` (`IMAGE`, optional) - background plate composited behind the splat; overrides the solid `background` colour. Resized to the render size. A batch is used one image per frame, a single image for all frames. The live tooltip says `color`/`clay` styles only.
  - `camera_info` (`LOAD3D_CAMERA`, optional) - camera to render from: a Load 3D / Preview 3D camera, or a Create Camera Info node. If empty, the splat is auto-framed from a default 3/4 view.
- **outputs:**
  - `image` (`IMAGE`) - the rendered image(s). One frame, or a batch when `frames > 1`. Feeds any IMAGE consumer (Save Image, a video / combine node for a turntable, an upscaler).
  - `mask` (`MASK`) - coverage mask of where the splat rendered, for compositing the splat over a separate background downstream.
- **how it works:** an anisotropic EWA rasterizer draws the gaussians as oriented elliptical splats, antialiased and depth-sorted front-to-back, from the given (or auto-framed) camera. With `frames > 1` it sweeps the camera around the target to produce the turntable batch.
- **strengths:** the direct splat-to-image path with no mesh-extraction step, so it keeps the splat's full visual fidelity (view-dependent colour, soft edges). Built-in turntable batching from one node. Multiple debug / render styles (color, clay, depth, normal) and a coverage mask for compositing.
- **bugs / lags + fixes:** none known. The `bg_image` tooltip restricts it to `color`/`clay` styles, so expecting a background plate behind a `depth` or `normal` render is a configuration mismatch, not a bug. Large `width`/`height` with many frames is the obvious VRAM / time cost; lower the frame count or resolution if it spikes.
- **anti-patterns:** feeding anything but a `SPLAT` (it does not take a `MESH`; for a mesh, render through the viewport nodes or a mesh renderer instead). Wiring a mesh-family camera type where a `LOAD3D_CAMERA` is required. Expecting a 3D file out of this; it produces 2D images and a mask, not a `FILE_3D`. For an on-disk splat, use Create 3D File from Splat; for a mesh, use Extract Mesh from Splat.
- **placement:** sits in the splat branch. A `SPLAT` source feeds it, optionally a Create Camera Info (or a Load 3D / Preview 3D camera) into `camera_info`; its `image` output feeds Save Image or a video / combine node (for turntables), its `mask` feeds a compositor.

### SplatToMesh  (display: "Extract Mesh from Splat")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_gaussian_splat`, confirmed via get_node_info `python_module`, 2026-06-30) | **category:** `3d/splat` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** extract a coloured mesh from a gaussian splat, so the splat can be saved or used as conventional geometry.
- **inputs:**
  - `splat` (`SPLAT`) - the gaussian splat to mesh.
  - `resolution` (`INT`, default 384) - density-grid resolution along the longest axis. Higher gives a finer surface but more VRAM / time (cost grows with resolution cubed). Live range 64 to 768, step 16.
  - `kernel` (`INT`, default 5) - max splat half-width in voxels. Each gaussian is rasterized over a window sized to its own 3-sigma, capped here, so small surfels stay cheap and large ones are not truncated. Raise it if sparse splats leave gaps. Live range 1 to 8.
  - `smooth` (`INT`, default 0) - Taubin mesh-smoothing iterations. Smooths the surface without shrinking it (volume-preserving), unlike blurring the density. `0` = raw surface. Live range 0 to 60.
  - `level` (`FLOAT`, default 0.4) - iso-surface level. Auto-picked by Otsu; this biases it (`1.0` = auto, lower = fatter / more-connected surface, higher = thinner / tighter). Live range 0 to 2.
  - `min_component` (`INT`, default 500) - drop connected components smaller than this many vertices (`0` = keep all). Removes detached floater blobs and the inner shell of a double wall. Live range 0 to 100000.
  - `min_opacity` (`FLOAT`, default 0.02) - ignore gaussians fainter than this before meshing. Live range 0 to 1.
  - `color_sharpen` (`FLOAT`, default 2) - crisp up the vertex texture. `1.0` is the physically-correct blend; higher biases each voxel's colour toward its dominant gaussian instead of averaging neighbours (de-smears the texture). Colour only, geometry is unchanged. Live range 1 to 8.
- **outputs:**
  - `mesh` (`MESH`) - the extracted coloured mesh, with per-vertex colour. Feeds Save 3D Model, the viewport / preview nodes, or any node that consumes a `MESH`.
- **how it works:** the gaussians are accumulated into a density grid (rasterized per-gaussian over a window sized to each one's 3-sigma, capped by `kernel`), an iso-surface is pulled at the (Otsu-biased) `level`, optionally Taubin-smoothed and pruned by component size, and vertex colours are sampled from the splat with the `color_sharpen` bias.
- **strengths:** turns a splat into editable / saveable geometry with surface controls that are honest about what they do (volume-preserving smoothing, component pruning to kill floaters, a colour-only sharpen that leaves geometry alone). Resolution / level / kernel give a real quality-vs-cost dial.
- **bugs / lags + fixes:** none known. The headline cost is `resolution` (cubic in VRAM / time); a too-high value is the usual way to OOM or stall this node, so step it up rather than maxing it. Sparse splats leaving holes is a `kernel`-too-low symptom, not a bug.
- **anti-patterns:** expecting it to preserve the splat's view-dependent appearance; meshing bakes a single per-vertex colour and drops the splat's soft, view-dependent look (if you want that, render the splat directly with Render Splat instead). Feeding a non-splat input. Treating the `MESH` output as a file; it is in-memory geometry, route it through Save 3D Model to write it.
- **placement:** in the splat branch when you need geometry rather than an image. A `SPLAT` source feeds it; its `mesh` output feeds Save 3D Model, Preview 3D, or any `MESH` consumer.

### SplatToFile3D  (display: "Create 3D File (from Splat)")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_gaussian_splat`, confirmed via get_node_info `python_module`, 2026-06-30) | **category:** `3d/splat` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** serialize a gaussian splat to a `FILE_3D` object (in one of three splat container formats) so a Save or Preview 3D node can write or display it.
- **inputs:**
  - `splat` (`SPLAT`) - the gaussian splat to serialize.
  - `format` (`COMBO`) - the container format. `ply`: standard 3D Gaussian Splat with full spherical harmonics. `ksplat`: mkkellogg SplatBuffer (level 0, uncompressed), base colour only. `spz`: Niantic gzip-compressed (roughly 10x smaller), base colour only.
- **outputs:**
  - `model_3d` (`FILE_3D_SPLAT_ANY`) - the serialized splat file object; consumed by Save 3D Model (to write it to disk) or a Preview 3D node (to view it).
- **how it works:** packs the splat's gaussians into the chosen container. `ply` keeps full spherical-harmonics colour, the other two keep base colour only (`ksplat` uncompressed, `spz` gzip-compressed for size).
- **strengths:** the route to get a splat onto disk or into the viewer without meshing it (keeps it as a splat). Format choice trades fidelity for size: `ply` for full SH colour, `spz` for a roughly 10x-smaller file when base colour is enough.
- **bugs / lags + fixes:** none known. One real constraint stated in the node description: it supports one item per batch only, so do not feed a multi-item splat batch and expect all of them serialized.
- **anti-patterns:** picking `ksplat` or `spz` when you need the full view-dependent colour (those drop spherical harmonics to base colour); use `ply` for that. Treating the `FILE_3D_SPLAT_ANY` output as a mesh (it is a splat file; to get a mesh, use Extract Mesh from Splat). Feeding a multi-item batch.
- **placement:** the serialize step in the splat branch. A `SPLAT` source feeds it; `model_3d` feeds Save 3D Model (whose `mesh` input accepts `FILE_3D_SPLAT_ANY`) or a Preview 3D node.

### CreateCameraInfo  (display: "Create Camera Info")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_gaussian_splat`, confirmed via get_node_info `python_module`, 2026-06-30) | **category:** `3d` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** build a `camera_info` object that defines a camera, used by Render Splat (and the Preview 3D nodes) to render from a chosen viewpoint. Coordinates are the viewer's world space (right-handed, Y-up).
- **inputs:**
  - `mode` (`COMFY_DYNAMICCOMBO_V3`) - how to define the camera, and a dynamic combo: the secondary inputs it reveals change with the choice. `orbit` aims with yaw / pitch / distance around the target; `look_at` places the camera at an explicit world position aimed at the target; `quaternion` places it at a world position with an explicit rotation quaternion. (The live pull shows the mode-specific sub-inputs: `orbit` reveals `yaw` / `pitch` / `distance`; `look_at` and `quaternion` reveal `position_x/y/z`, and `quaternion` adds `quat_x/y/z/w`. These are dynamic, surfaced by the selected mode, not fixed top-level ports.)
  - `target_x` (`FLOAT`, default 0) - the look-at point (orbit pivot / aim). In `orbit` mode, move it to pan / translate the whole camera. Ignored in `quaternion` mode. Defaults to the origin.
  - `target_y` (`FLOAT`, default 0) - look-at point Y.
  - `target_z` (`FLOAT`, default 0) - look-at point Z.
  - `roll` (`FLOAT`, default 0) - camera roll about the view axis, in degrees. Live range -180 to 180.
  - `fov` (`FLOAT`, default 35) - vertical field of view in degrees. Live range 1 to 120.
  - `zoom` (`FLOAT`, default 1) - digital zoom (a focal-length multiplier); `>1` zooms in without moving the camera. Live range 0.01 to 100.
  - `camera_type` (`COMBO`) - projection used by Render Splat: `perspective` (foreshortening) or `orthographic` (parallel).
- **outputs:**
  - `camera_info` (`LOAD3D_CAMERA`) - the camera definition; feeds the `camera_info` input of Render Splat (and the Preview 3D nodes), which is the same type Load 3D / Preview 3D emit.
- **how it works:** assembles the chosen mode's parameters (orbit angles, or a world position, or a position plus a normalized rotation quaternion) together with target, roll, fov, zoom, and projection into a `LOAD3D_CAMERA` the renderer reads.
- **strengths:** a deterministic, parameter-driven camera (no manual viewport dragging), so renders are repeatable and scriptable. Three ways to specify the view (orbit, look-at, quaternion) and both perspective and orthographic projection. Its output type matches the camera that Load 3D / Preview 3D emit, so it is a drop-in replacement for them.
- **bugs / lags + fixes:** none known. One gotcha from the I/O: `target_*` is ignored in `quaternion` mode (the rotation already fixes orientation), so setting a target there has no effect.
- **anti-patterns:** wiring `camera_info` into a node that does not take a `LOAD3D_CAMERA`. Expecting `target_*` to do anything in quaternion mode. Treating `zoom` as moving the camera; it is a focal-length multiplier, it does not change camera position (use `distance` in orbit mode, or the explicit position, to actually move).
- **placement:** a small leaf on the camera side of the splat branch. Nothing feeds it; its `camera_info` feeds Render Splat (or a Preview 3D node) in place of a viewport camera.

### Load3D  (display: "Load 3D & Animation")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_load_3d`, confirmed via get_node_info `python_module`, 2026-06-30; flagged `experimental: true`) | **category:** `3d` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** load a 3D model into an interactive viewport and emit renders of it (RGB, mask, normal), its camera, a recording, the model file, and model metadata. The entry point for getting an existing 3D asset into a graph.
- **inputs:**
  - `model_file` (`COMBO`) - a dropdown of installed 3D model files (read from the ComfyUI `input/3d` area). The live pull shows it with a `file_upload: true` flag and a default `none`, meaning you upload / pick the model through the node's widget; an empty or `none`-only dropdown means no 3D files are present yet.
  - `image` (`LOAD_3D`) - the interactive viewport widget state (the orbit / frame the user sets in the 3D view), not a normal wired IMAGE port. It carries the live camera / viewport back to the node so the renders match what is framed. The output type name `LOAD_3D` here is the widget, distinct from the node's image outputs.
  - `width` (`INT`, default 1024) - render width in pixels (live range 1 to 4096).
  - `height` (`INT`, default 1024) - render height in pixels (live range 1 to 4096).
- **outputs:**
  - `image` (`IMAGE`) - the RGB render of the model from the viewport camera; feeds any IMAGE consumer.
  - `mask` (`MASK`) - the model's coverage / silhouette mask, for compositing it over a background.
  - `mesh_path` (`STRING`) - the on-disk path of the loaded model file, for nodes that take a path string.
  - `normal` (`IMAGE`) - a normal-map render of the model.
  - `camera_info` (`LOAD3D_CAMERA`) - the viewport camera, the same type Create Camera Info emits; feeds Render Splat or a Preview 3D node.
  - `recording_video` (`VIDEO`) - a recorded turntable / interaction video captured in the viewport.
  - `model_3d` (`FILE_3D`) - the loaded model as a file object; feeds Save 3D Model or a Preview 3D node.
  - `model_3d_info` (`LOAD3D_MODEL_INFO`) - model metadata; consumed by Preview 3D (Advanced), which has a matching `model_3d_info` input.
- **how it works:** the node hosts a three.js-style interactive 3D viewport in the ComfyUI UI. You load / upload a model and frame it; the viewport state (the `image` / `LOAD_3D` widget) feeds the framing back, and the node renders RGB / mask / normal from that camera at the requested size, alongside the model file, its camera, a recording, and metadata.
- **strengths:** one node turns an arbitrary 3D file into the 2D renders a diffusion graph can use (RGB plus matching normal and mask), and also exposes the model file, its camera, and metadata for downstream 3D nodes. The interactive viewport means the camera is framed by eye, then captured. Wide output fan-out covers most "I have a model, now what" needs.
- **bugs / lags + fixes:** none known specific to the node. It is flagged `experimental: true` in the live pull, so treat its I/O as more likely to shift between ComfyUI versions than a stable node, and re-confirm with `get_node_info` if a wire breaks after an update. The interactive widget state (`image` / `LOAD_3D`) is a UI-driven input, so a headless / API run that does not set the viewport gets a default framing rather than a hand-set one.
- **anti-patterns:** treating the `image` (`LOAD_3D`) input as a normal IMAGE port to wire a picture into; it is the viewport-state widget. Treating `camera_info` (`LOAD3D_CAMERA`) as an image. Confusing `mesh_path` (a STRING path) with `model_3d` (a `FILE_3D` object); they feed different consumers. Expecting it to load a splat container as a `SPLAT` object; its model output is a `FILE_3D`, the splat-specific path is the `comfy_extras.nodes_gaussian_splat` nodes.
- **placement:** the root of a mesh / model branch. Nothing wired feeds it (the model is picked / uploaded in the widget); it feeds image consumers (`image`, `normal`, `mask`), 3D-file consumers (`model_3d` into Save / Preview 3D), and camera consumers (`camera_info` into Render Splat or Preview 3D).

### Preview3D  (display: "Preview 3D & Animation")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_load_3d`, confirmed via get_node_info `python_module`, 2026-06-30; flagged `experimental: true`) | **category:** `3d` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** display a 3D model (from a file or a path string) in an interactive viewport. This is a terminal / output node, it shows the model and returns nothing to the graph.
- **inputs:**
  - `model_file` (`STRING,FILE_3D_GLB,FILE_3D_GLTF,FILE_3D_FBX,FILE_3D_OBJ,FILE_3D_STL,FILE_3D_USDZ,FILE_3D`) - the model to preview, accepted either as a path STRING or as any of the listed `FILE_3D*` file objects. The live tooltip: "3D model file or path string". This multi-type input is why it accepts the output of Load 3D (`model_3d`, a `FILE_3D`) or a `mesh_path` STRING.
  - `camera_info` (`LOAD3D_CAMERA`, optional) - a camera to frame the preview from (a Create Camera Info, or a Load 3D / Preview 3D camera). If empty, the viewport uses its own interactive framing.
  - `bg_image` (`IMAGE`, optional) - a background image shown behind the model in the viewport.
- **outputs:** none. It is an `output_node` (it renders the interactive preview in the UI and returns nothing to the graph).
- **how it works:** loads the given model (file object or path) into the same interactive 3D viewport as Load 3D and displays it, optionally framed by a supplied `camera_info` and over a supplied `bg_image`.
- **strengths:** the lightweight way to eyeball a 3D result inside ComfyUI without writing a file. Accepts both a path string and the `FILE_3D*` objects upstream nodes emit, so it drops onto almost any 3D output. Optional camera and background for a framed preview.
- **bugs / lags + fixes:** none known. Flagged `experimental: true` in the live pull, so its I/O is more likely to change across versions; re-confirm with `get_node_info` if a wire breaks after an update. Being an output node, it produces nothing downstream; do not wire anything off it.
- **anti-patterns:** trying to take an image or file out of it; it has no outputs (for renders you can route onward, use Load 3D, which emits `image` / `mask` / `normal`; to capture model / camera / dimensions downstream, use Preview 3D (Advanced), which does have outputs). Feeding a type outside its accepted STRING / `FILE_3D*` list. Expecting it to save the model; it only displays (use Save 3D Model to write a file).
- **placement:** a terminal leaf at the end of a 3D branch. Fed by a `FILE_3D*` object (e.g. Load 3D `model_3d`, Create 3D File from Splat `model_3d`) or a path STRING (e.g. Load 3D `mesh_path`); feeds nothing.

### SaveGLB  (display: "Save 3D Model")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_save_3d`, confirmed via get_node_info `python_module`, 2026-06-30) | **category:** `3d` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** write a mesh or a 3D file object to the ComfyUI output directory. This is a terminal / output node.
- **inputs:**
  - `mesh` (`MESH,FILE_3D_GLB,FILE_3D_GLTF,FILE_3D_OBJ,FILE_3D_FBX,FILE_3D_STL,FILE_3D_USDZ,FILE_3D_PLY,FILE_3D_SPLAT,FILE_3D_SPZ,FILE_3D_KSPLAT,FILE_3D_SPLAT_ANY,FILE_3D_POINT_CLOUD_ANY,FILE_3D`) - the thing to save, accepted as an in-memory `MESH` or as any of the listed `FILE_3D*` file objects (including the splat file types). Live tooltip: "Mesh or 3D file to save". This broad multi-type input is why it accepts both Extract Mesh from Splat (`MESH`) and Create 3D File from Splat (`FILE_3D_SPLAT_ANY`).
  - `filename_prefix` (`STRING`, default `3d/ComfyUI`) - the output path prefix under the ComfyUI output dir (the `3d/` segment puts it in a `3d` subfolder).
- **outputs:** none. It is an `output_node` (it writes the file and returns nothing to the graph).
- **how it works:** takes the mesh or 3D-file object and writes it to disk under `output/<filename_prefix>`. Despite the GLB-derived class name and "Save 3D Model" display name, its input accepts the full `FILE_3D*` family (meshes and the splat containers), so what it writes follows the object handed in.
- **strengths:** the standard 3D sink. One node, a broad accepted-type list (mesh or any `FILE_3D*`, including splat files), and the same `filename_prefix` convention as the image savers.
- **bugs / lags + fixes:** none known. The class name `SaveGLB` is narrower than the node's real capability (the accepted-type list is the whole `FILE_3D*` family, not GLB only); rely on the confirmed input type list, not the class name, when deciding what it can write. Whether a given output format is honored end-to-end for every one of those input types is best confirmed by running it for that specific type rather than assumed from the type list alone.
- **anti-patterns:** feeding a 2D `IMAGE` (use Save Image for that). Feeding a `SPLAT` object directly; serialize it to a file first with Create 3D File from Splat, then save the resulting `FILE_3D_SPLAT_ANY`. Wiring anything off it (it has no outputs).
- **placement:** the leaf at the end of a 3D branch. Fed by a `MESH` (e.g. Extract Mesh from Splat) or a `FILE_3D*` object (e.g. Load 3D `model_3d`, Create 3D File from Splat `model_3d`); feeds nothing.

### VoxelToMesh  (display: "Voxel to Mesh")
- **pack / source:** core ComfyUI (`comfy_extras.nodes_hunyuan3d`, confirmed via get_node_info `python_module`, 2026-06-30) | **category:** `3d` | **I/O confirmed via get_node_info:** 2026-06-30
- **purpose:** convert a voxel grid to a mesh. The surfacing step for voxel-producing 3D pipelines (the Hunyuan3D family, given the module).
- **inputs:**
  - `voxel` (`VOXEL`) - the voxel grid to surface; comes from a voxel-producing upstream node.
  - `algorithm` (`COMBO`) - the surfacing algorithm. The live pull lists `surface net` and `basic`. (`surface net` gives a smoother surface; `basic` is the simpler marching-style extraction.)
  - `threshold` (`FLOAT`, default 0.6) - the iso-surface threshold (occupied vs empty cutoff). Live range -1 to 1.
- **outputs:**
  - `MESH` (`MESH`) - the extracted mesh; feeds Save 3D Model, a Preview 3D node, or any `MESH` consumer.
- **how it works:** pulls an iso-surface out of the voxel grid at `threshold` using the chosen `algorithm` (`surface net` or `basic`), returning a `MESH`.
- **strengths:** the direct voxel-to-mesh step for voxel-based 3D models, with a smoothness choice (`surface net` vs `basic`) and a single threshold control. Lightweight (only three inputs).
- **bugs / lags + fixes:** none known in the node itself. The live pull shows a separate, explicitly DEPRECATED sibling `VoxelToMeshBasic` (display "Voxel to Mesh (Basic) (DEPRECATED)") that has no `algorithm` input; do not reach for that one, this `VoxelToMesh` with `algorithm = basic` supersedes it.
- **anti-patterns:** using the deprecated `VoxelToMeshBasic` instead of this node. Feeding a `SPLAT` or a `MESH` (it needs a `VOXEL`; for a splat use Extract Mesh from Splat). A `threshold` set wrong for the grid can give an empty or bloated mesh; it is a normal parameter, not a bug, so adjust within the -1 to 1 range.
- **placement:** the surfacing step in a voxel pipeline. A `VOXEL` source feeds it; its `MESH` output feeds Save 3D Model, Preview 3D, or another `MESH` consumer.
