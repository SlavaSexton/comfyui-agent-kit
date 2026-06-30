# OCIO color management (ComfyUI-OCIO, our own pack)

Six OpenColorIO nodes we build and maintain, modelled 1:1 on The Foundry Nuke's OCIO node set. Pack:
**`ComfyUI-OCIO`**, author **Slava Sexton** (github.com/SlavaSexton/ComfyUI-OCIO), MIT. All `IMAGE` in/out, float,
HDR-safe (no [0,1] clip). Category `OCIO`. Built 2026-06-30 to fill a real gap: the ComfyUI registry has no OCIO
pack (`search_custom_nodes "OCIO"` / `"OpenColorIO"` both return nothing).

**Dependency:** `pip install opencolorio` (OCIO 2.2+) + an OCIO config (`$OCIO`, a `config_path`, or the built-in
ACES studio config). The exception is `OCIOLogConvert` `method=acescct`, which is dependency-free.

**I/O status:** confirmed from the pack source (we wrote it), and verified at runtime 2026-06-30 with
OpenColorIO 2.5.2 against the built-in ACES studio config: `OCIOLogConvert` (acescct round-trip < 1e-6, and
ocio_config), `OCIOColorSpace`, `OCIOCDLTransform`, and `OCIODisplay` all run and return finite,
correctly-transformed images (`tools/test_ocio_nodes.py`). `OCIOFileTransform` (needs a LUT file) and
`OCIOLookTransform` (needs a config look) are not yet exercised on assets.

---

### OCIOLogConvert  (display: "OCIO LogConvert")  -- the log-space transform node
- **pack:** `ComfyUI-OCIO` (Slava Sexton) | **category:** `OCIO` | **the node for the log-space technique in `color-and-transform.md`**
- **purpose:** linear to/from log, so manual transforms (scale, rotate, distort, warp, resample) preserve highlight / shadow detail instead of crushing them in linear light.
- **inputs:**
  - `image` (IMAGE) - linear for `lin_to_log`, log for `log_to_lin`.
  - `operation` (combo: `lin_to_log` / `log_to_lin`) - `lin_to_log` before the transform, `log_to_lin` after.
  - `method` (combo: `acescct` / `ocio_config`) - `acescct` is the built-in curve, no OCIO needed; `ocio_config` uses the config's scene_linear <-> log.
  - `config_path` (STRING, optional), `log_colorspace` (STRING, optional) - for the `ocio_config` method.
- **outputs:** `image` (IMAGE) - converted, HDR range preserved.
- **how it works:** `acescct` applies the ACES S-2016-001 transfer in numpy (verified reversible); `ocio_config` builds an OCIO processor between `scene_linear` and the config's log (default role `compositing_log`).
- **strengths:** dependency-free by default, HDR-safe, reversible, one node per direction.
- **bugs / lags + fixes:** none known. `ocio_config` errors clearly if no config is found (use `acescct`).
- **anti-patterns:** do not run AI / diffusion / VAE in log; do not round-trip at 8-bit; one wrap around the whole transform block. Feed LINEAR for `lin_to_log` (linearize sRGB first).
- **placement:** wrap tightly around manual geometry. Replaces the old REDACTED `REDACTEDLogConvert` (that node is being retired from ComfyUI-REDACTED in favour of this pack).

### OCIOColorSpace  (display: "OCIO ColorSpace")
- **pack:** `ComfyUI-OCIO` | **category:** `OCIO`
- **purpose:** convert an image between two OCIO colorspaces (e.g. ACES2065-1 to ACEScg).
- **inputs:** `image` (IMAGE); `in_colorspace` / `out_colorspace` (combo of the config's spaces, or STRING if no config resolved); `config_path` (STRING, optional).
- **outputs:** `image` (IMAGE).
- **how it works:** `config.getProcessor(in, out)` applied per frame.
- **anti-patterns:** colorspace names must exist in the active config; a typo or a name from another config errors. Needs OpenColorIO + a config.
- **placement:** anywhere a colorspace change is needed; the OCIO workhorse.

### OCIODisplay  (display: "OCIO Display")
- **pack:** `ComfyUI-OCIO` | **category:** `OCIO`
- **purpose:** apply a display + view transform (scene-linear to a display, e.g. sRGB / Rec.709 / a HDR view).
- **inputs:** `image` (IMAGE); `in_colorspace` (combo/STRING); `display` (STRING, e.g. "sRGB - Display"); `view` (STRING, e.g. "ACES 1.0 - SDR Video"); `config_path` (optional).
- **outputs:** `image` (IMAGE).
- **anti-patterns:** this is a viewing / output transform, not a working-space convert; do not feed its output back into a linear pipeline. `display` / `view` must be valid for the config.
- **placement:** near the end, before save / preview, to bake a display look.

### OCIOCDLTransform  (display: "OCIO CDLTransform")
- **pack:** `ComfyUI-OCIO` | **category:** `OCIO`
- **purpose:** an ASC CDL grade: per-channel slope, offset, power, plus saturation.
- **inputs:** `image` (IMAGE); `slope_r/g/b`, `offset_r/g/b`, `power_r/g/b` (FLOAT); `saturation` (FLOAT); `direction` (forward / inverse).
- **outputs:** `image` (IMAGE).
- **how it works:** builds an `OCIO.CDLTransform` and applies it (config-independent grade).
- **anti-patterns:** CDL math assumes the right working space (usually log or a defined grade space); applying on raw linear gives a different look than a colorist expects.
- **placement:** the primary-grade step in a color chain.

### OCIOFileTransform  (display: "OCIO FileTransform")
- **pack:** `ComfyUI-OCIO` | **category:** `OCIO`
- **purpose:** apply an external LUT / CCC / CDL file (`.cube`, `.3dl`, `.spi1d`, `.csp`, ...).
- **inputs:** `image` (IMAGE); `file_path` (STRING); `interpolation` (linear / nearest / tetrahedral / best); `direction` (forward / inverse).
- **outputs:** `image` (IMAGE).
- **anti-patterns:** the LUT expects a specific input space; feeding the wrong space gives wrong color. `tetrahedral` is for 3D LUTs; `linear` for 1D. File must exist.
- **placement:** wherever a show / camera LUT belongs in the chain.

### OCIOLookTransform  (display: "OCIO LookTransform")
- **pack:** `ComfyUI-OCIO` | **category:** `OCIO`
- **purpose:** apply a named OCIO "look" (a creative grade defined in the config).
- **inputs:** `image` (IMAGE); `in_colorspace` / `out_colorspace` (combo/STRING); `looks` (STRING, e.g. "cool" or "+cool,-warm"); `config_path` (optional).
- **outputs:** `image` (IMAGE).
- **anti-patterns:** the look name(s) must be defined in the active config; combine with `+`/`-` prefixes per OCIO syntax.
- **placement:** the creative-look step, after primaries, before display.
