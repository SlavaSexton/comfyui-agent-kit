# Color and transform - working in the right space

Nodes and techniques for color-space conversion and manual (non-AI) pixel geometry: scale, rotate, distort,
warp, skew, crop, resample. The headline is a production-color practice from compositing, and we already ship a
node that implements it.

## TECHNIQUE: do manual transforms in LOG, not linear

**Rule:** any manual, non-AI change to pixels (scale, transform, rotate, distortion, warp, skew, any resample)
should be done in a LOG-encoded space, then converted back, rather than on linear data. Linear resampling
crushes detail in highlights and shadows; log encoding spreads code values perceptually so interpolation
preserves it.

**Flow:**
```
image ──▶ Linear→Log ──▶ [scale / transform / distort / warp / skew] ──▶ Log→Linear ──▶ continue
```

- **Source / status:** *confirmed.* Standard practice in The Foundry's Nuke (OCIO `OCIOLogConvert` /
  `OCIOColorSpace`) and the kit owner's own pipeline. Feed LINEAR data (linearize sRGB first); carry float
  through the wrap; convert back before any node that expects linear / sRGB.
- **Why it works:** a log curve allocates more code values to darks and compresses brights the way perception
  does, so resampling in that space keeps tonal detail linear interpolation would average away. Same reason
  film scans and ACEScct grade in log.
- **Anti-patterns:** do NOT run AI / diffusion / VAE steps in log (they expect linear or sRGB); do NOT
  round-trip at 8-bit (carry float); one wrap around the whole transform block, not per node.

### OCIO LogConvert  (class `OCIOLogConvert`)  -- the node we ship for this
We build and maintain this in our own **ComfyUI-OCIO** pack (Slava Sexton); full entry in `ocio.md`. It is the
Linear<->Log transfer that makes the technique above one node: `operation` = `lin_to_log` before the manual
transform, `log_to_lin` after. The default `method = acescct` is dependency-free (ACEScct transfer, verified
round-trip error < 1e-6, HDR-safe, reversible), so it needs no OpenColorIO install; `method = ocio_config` uses
an OCIO config's scene-linear <-> log instead.

The other five Nuke
OCIO nodes (ColorSpace, Display, CDLTransform, FileTransform, LookTransform) ship in the same pack, see `ocio.md`.

## Native linear / HDR / EXR I/O (confirmed)

You do not need OCIO to persist linear or HDR. Confirmed via get_node_info 2026-06-30:
- **`SaveImageAdvanced`** (core, `image`): PNG 8/16-bit; EXR 32-bit float; `input_color_space` sRGB / HDR
  (HLG Rec.2020) / linear (scene-linear Rec.709). EXR always stored scene-linear.
- **`LTXVHDRDecodePostprocess`** (`ComfyUI-LTXVideo`): decompresses LogC3 HDR IC-LoRA output + Reinhard
  tonemap; outputs `tonemapped` (SDR) + `hdr_linear`, optional EXR sequence (needs
  `OPENCV_IO_ENABLE_OPENEXR=1`). See `custom-author.md`.
- **anti-pattern:** plain `SaveImage` is 8-bit sRGB PNG only; it discards the precision the log workflow exists
  to protect.

## Status
Technique: confirmed (Nuke / OCIO standard + owner pipeline). `OCIOLogConvert` (our ComfyUI-OCIO pack): the
ACEScct path is verified by a round-trip test (2026-06-30); the OCIO-config paths need a runtime smoke test
(see `ocio.md`). `SaveImageAdvanced`, `LTXVHDRDecodePostprocess`: I/O confirmed via
get_node_info 2026-06-30.
