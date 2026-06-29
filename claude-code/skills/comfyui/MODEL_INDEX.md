# Model index: every model in the library and what the kit has for it

The template library names **149 distinct models** across 545 templates (plus 94 official Subgraph Blueprints, reusable subgraph bricks). This index shows, for each, what the kit
provides: a full prompt recipe in [`MODELS.md`](../skills/comfyui/MODELS.md), an enhancement/utility note, or
template-only coverage (runnable via a template, no dedicated recipe yet).

| Coverage | Meaning |
|---|---|
| ✅ **Recipe** | full per-model prompting guide in `MODELS.md` (structure, negatives, settings, official source) |
| 🔧 **Utility** | enhancement / utility tool, has a "when to use + settings" note (not prompt-driven) |
| 📋 **Template only** | runnable via a workflow template, no dedicated recipe yet (niche / thin official docs) |

**Totals:** ✅ 67 recipe families (covering ~122 model-name variants) · 🔧 18 utility tools · 📋 a few obscure
template-only · plus text encoders / inference providers that are not generative models.

**Updated: 2026-06-25.** Every ✅ entry has a current prompting recipe in
[`MODELS.md`](../skills/comfyui/MODELS.md); every 🔧 entry has a when-to-use + settings note.

---

## ✅ Models with a full prompt recipe

### Image (open / local-runnable)
| Family | Variants seen in templates | Run |
|---|---|---|
| FLUX | Flux, Flux.1, Flux.2, Flux.2 Klein, Flux.2 Dev, Flux.1 Kontext (edit), Flux.1 Krea Dev | local / API |
| Z-Image | Z-Image, Z-Image-Turbo | local |
| Qwen-Image | Qwen-Image, Qwen-Image-Edit, Qwen-Image 2512, Qwen-Image-Layered, Qwen Image Edit 2511 | local |
| SDXL | SDXL | local |
| Stable Diffusion 1.5 | SD1.5 | local |
| Stable Diffusion 3.5 | SD3.5 | local |
| HiDream | HiDream-I1 | local |
| BRIA | BRIA 3.x | local |
| OmniGen | OmniGen v1 / v2 (gen + edit) | local |
| Chroma | Chroma, Chroma1-HD | local |
| Krea | Krea 2 / FLUX.1 Krea Dev | local |
| ERNIE-Image | ERNIE-Image (+ Turbo) | local |
| Boogu | Boogu Image 0.1 (Base / Turbo / Edit) | local |

### Image (API / closed)
| Family | Variants seen in templates | Run |
|---|---|---|
| Ideogram | Ideogram (2.x / 3.0) | API |
| Nano Banana / Gemini Image | Nano Banana, Nano Banana Pro, Nano Banana 2, Gemini 3 Pro Image, Gemini 3.1 Pro/flash-lite, Gemini 2.5 Flash | API |
| Seedream | Seedream 4.0 / 4.5 / 5.0 Lite | API |
| Recraft | Recraft V3 | API |
| GPT-Image | GPT Image 2, GPT-Image-1 / 1.5 | API |
| Grok Image | Grok | API |
| Reve | Reve | API |
| Kandinsky | Kandinsky 3.x | local / API |

### Image editing (instruction-based)
| Family | Variants | Run |
|---|---|---|
| FLUX.1 Kontext | Flux.1 Kontext | local / API |
| Qwen-Image-Edit | Qwen-Image-Edit (+ 2511) | local |
| OmniGen | OmniGen v2 | local |
| FireRed Image Edit | FireRed Image Edit 1.1 | local |
| LongCat | LongCat, LongCat Image Edit | local |
| ChronoEdit | ChronoEdit (NVIDIA) | local |

### Video (open / local-runnable)
| Family | Variants seen in templates | Run |
|---|---|---|
| Wan | Wan, Wan 2.1, 2.2, 2.5, 2.6, 2.7, VACE, Animate, ATI, InfiniteTalk, SCAIL | local / API |
| LTX | LTX-2, LTX-2.3, LTX-0.9.5 | local |
| Hunyuan Video | Hunyuan Video | local |
| SVD | Stable Video Diffusion | local |

### Video (API / closed)
| Family | Variants seen in templates | Run |
|---|---|---|
| Kling | Kling 1.6, 2.0, 2.6, 3.0, O1, O3 | API |
| Veo | Veo 3 / 3.1 | API |
| Sora | Sora 2 | API |
| Seedance | Seedance 1.0 Pro, 1.5 Pro, 2.0 (4K) | API |
| Luma | Luma Ray, UNI-1 | API |
| Runway | Runway Gen-4 / 4.5 | API |
| MiniMax | MiniMax / Hailuo | API |
| PixVerse | PixVerse | API |
| Vidu | Vidu Q1 / Q2 / Q3 | API |
| Pika | Pika 2.2 / 2.5 | API |

### Audio
| Family | Run |
|---|---|
| Stable Audio | local |
| ACE-Step | local |
| ElevenLabs | API |
| Chatter Box | local |

### 3D
| Family | Variants | Run |
|---|---|---|
| Hunyuan3D | Hunyuan3D-2 | local |
| Tripo | Tripo, Tripo P1, TripoSplat | API |
| Rodin | Rodin (Hyper3D) | API |
| Meshy | Meshy | API |

---

### Newer / niche (now with recipes)
| Model | Modality | Run |
|---|---|---|
| Capybara | image + video (unified gen/edit) | local |
| Bernini-R | image/video relighting edit | local |
| Anima | image (anime t2i) | local |
| NewBie | image (anime t2i, XML prompts) | local |
| PixelDiT | image (VAE-free t2i) | local |
| Ovis-Image | image (text rendering t2i) | local |
| Lens / Lens Turbo | image (t2i) | local |
| Quiver | image (text/image to SVG) | API |
| HappyHorse 1.1 | video (t2v/i2v/r2v) + synced audio | API |
| HuMo | video (audio+image+text, lip-sync) | local |
| SCAIL-2 | video (character animation) | local |
| Sonilo | audio (music / video soundtrack) | API |

---

## 🔧 Enhancement and utility tools

Not prompt-driven, see the "Enhancement and utility" section in [`MODELS.md`](../skills/comfyui/MODELS.md) for
when-to-use + settings.

- **Upscale / restore:** Real-ESRGAN (+ ESRGAN family), SUPIR, SeedVR2, FlashVSR, Topaz, Magnific
- **Frame interpolation:** FILM, RIFE
- **Segmentation / matting:** SAM3, BiRefNet
- **Depth / geometry:** Depth Anything v2, Depth Anything v3, MoGe
- **Pose / landmarks:** DWPose, Mediapipe (also SDPose-OOD)
- **Conditioning / animation:** IP-Adapter, LivePortrait
- **Video object removal:** VOID (Netflix, quadmask video inpainting)

---

## 📋 Template-only (runnable, no recipe yet)

After the niche-model research pass, almost everything in the library now has a recipe or a utility note. What
remains here is a short tail of one-off entries with no official prompting docs (e.g. HitPaw and Reimagine, which are
enhancement-style; PiD). Run them from their template and prompt them with the closest family's approach from
`MODELS.md` as a starting point. Note: ByteDance **Seed 2.0** is an image/video *understanding* model (analysis to
text), not a generator, so it lives under "Not generative models" below, not here.

---

## Not generative models (excluded)

Text encoders, LLM nodes, and inference providers that appear in template metadata but are not image/video/audio
generators: Gemma 4 and Claude (text), Ovis-Image / SwitchX (encoders / routing), WaveSpeed and OpenRouter
(inference providers), and `None` (templates with no model tag).

---

*Counts reflect the cloned `workflow_templates` set on the build date. Run `git pull` in the templates clone and
rerun `tools/gen_quick_index.py` to refresh; new models from Comfy-Org appear automatically in the library and can
be given a recipe on demand.*
