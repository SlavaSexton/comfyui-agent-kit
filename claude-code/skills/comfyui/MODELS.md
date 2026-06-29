# Per-model prompting reference

**This reference is distilled from official sources** (each model maker's docs / model card, docs.comfy.org, and
the per-model prompt templates shipped with the `anthropic-claude` ComfyUI node). Each generative model has its
own "character" and rewards a different prompt approach. Treat every model as its own dialect.

**How to use it (the auto-pull rule):** when a specific model is named in the request, the workflow, or the
template, READ that model's entry below BEFORE writing the prompt, and follow its structure, its negative-prompt
rule, and its settings. Do not carry one model's prompt style over to another (SDXL tags will not help FLUX;
FLUX prose will not help SDXL).

## Quick cheat sheet (prompt style + negatives)

| Model / family | Prompt style | Negative prompts |
|---|---|---|
| FLUX.1 / .2, FLUX Kontext | natural-language sentences (word order matters) | NOT supported, rephrase positively |
| Z-Image-Turbo | natural-language, subject-first | not used (CFG-distilled) |
| Qwen-Image / Edit | structured natural language, one style | limited / not supported (edit) |
| SDXL | natural language (hybrid tags ok) | supported, effectively required |
| SD 1.5 | comma tags, `(token:1.2)` weights | supported, heavily used |
| SD 3.5 | natural language (no weighting syntax) | supported element |
| HiDream-I1 | natural language | Full=yes, Dev/Fast inert (guidance 0) |
| BRIA 3.x | natural language (short text) | supported (CFG>1) |
| OmniGen v1/v2 | instruction + inline image tags | v2 yes |
| Chroma | natural language | supported |
| Krea 1 (FLUX Krea) | natural language, no weights | no (guidance-distilled) |
| Krea 2 (RAW + Turbo) | natural language, quote text | RAW yes (CFG 3.5), Turbo no (CFG 0) |
| ERNIE-Image | instruction + prompt enhancer | not documented |
| FireRed / LongCat / ChronoEdit (edit) | instruction (quote literal text) | mostly empty/unset |
| SVD (video) | NONE, image + motion params | no |
| Ideogram, Recraft | natural language, quoted text | Ideogram yes / Recraft no |
| Nano Banana Pro/2 (Gemini) | rich descriptive prose | NOT used, phrase positively |
| Seedream 4.x | structured spec (identity-lock) | describe positively |
| Seedream 5 Lite | natural sentences (no boosters) | NOT supported |
| GPT-Image, Grok Image | structured brief / 5-part | exclusions slot, no negative field |
| Reve, Kandinsky | natural language | Reve no / Kandinsky yes |
| Wan 2.x / 2.5-2.7 | cinematic shot description | supported (best on 2.2+) |
| LTX-2.3 / 2 Pro | one flowing paragraph, NOT tag dumps + audio | Dev only (CFG>1), Distilled ignores |
| Hunyuan Video | detailed natural language + motion | leans on positive + prompt-rewrite |
| Kling, Seedance, MiniMax | structured + camera direction | Kling yes / others use exclusions |
| Veo, Sora | natural / storyboard, audio after visual | descriptive exclusions at end |
| Luma, Runway | content-only (camera via API/refs) | NOT supported |
| Stable Audio | genre + mood + instruments + BPM | n/a |
| ACE-Step | tags + structured `[verse]/[chorus]` lyrics | n/a |
| 3D (Hunyuan3D, Tripo, Rodin, Meshy) | subject + materials + style; clean input image | mostly n/a |

---

## Image models (open / local-runnable)

### FLUX.1 (Black Forest Labs)
- **Prompt style:** natural-language sentences, not comma tags. Word order matters (earlier tokens weighted more).
- **Structure:** Subject -> Action/Pose -> Style/Medium -> Context/Environment -> Technical details; most important first. Rendered text in quotes (keep under ~25 chars); hex codes tied to specific objects work.
- **Strengths:** native text rendering, photorealism via real camera/lens/film language, hex color control, multilingual.
- **Avoid:** negative prompts NOT supported on any FLUX.1 version (may add the unwanted element); no named fonts (describe the style).
- **Settings:** Schnell 1-4 steps / guidance ~3.0 / ~1MP; Dev 20-50 steps / guidance 1.5-5.0 / ~2MP; Pro/Ultra API. ComfyUI: FluxGuidance node, euler/simple typical.
- **Source:** docs.bfl.ml ; node template `flux.md`.

### FLUX.2 (Black Forest Labs)
- **Prompt style:** natural language OR JSON structured (natural for iteration, JSON for precise production control).
- **Structure:** main subject -> key action -> critical style -> essential context -> secondary details.
- **Strengths:** photorealism, text rendering, hex color, product shots, native multilingual; multi-reference compositing (pro up to 8, flex ~10, dev ~6) with identity/style/pose typing.
- **Avoid:** negative prompts NOT supported.
- **Settings:** API for pro/max/flex; FLUX.2 [dev] open-weight runs locally (guidance/steps per the dev workflow).
- **Field recipes (community):** **Klein masked inpaint + dual reference** (Flux.2 [Klein]): `InpaintStitchImproved`
  (comfyui-inpaint-cropandstitch) + a mask + two reference images, one prompt-driven and one ref+mask driven, for
  controlled edits. **1-click multi-angle character turnarounds:** a prompt-batcher fans one character into several camera
  angles for consistency. **Multi-reference identity lock, training-free** (Flux.2 [Klein] 9B): the
  `ComfyUI-Flux2Klein-Enhancer` suite (capitan01R, ~510 stars as of 2026-06) does identity-preserving multi-subject
  edits with NO LoRA training. Core node **Identity Feature Transfer Final** patches Klein attention output
  (`set_model_attn1_output_patch`) to transfer features from up to 8 VAE-encoded reference latents (fed via **Multi
  ReferenceLatent**), with per-reference masks (`subject_mask_1..8`), similarity matching, and confidence-gated
  transfer across Klein's 8 double + 24 single blocks, presets HARD/MID/SOFT_LOCK. Companions: **Color Anchor**
  (post-CFG channel-mean color match), **Sectioned Encoder + Detail Controller** (FRONT/MID/END prompt-section
  weights), **Ref / Mask Ref Controllers**, and an experimental resolution-aware Euler sampler. No extra Python deps.
  **License: PolyForm Noncommercial 1.0.0 (personal/research free; commercial use needs a separate license).**
  Community workflows, not official BFL recipes.
- **Source:** docs.bfl.ml/guides/prompting_guide_flux2 ; github.com/black-forest-labs/skills ; github.com/capitan01R/ComfyUI-Flux2Klein-Enhancer (Klein enhancer suite, PolyForm NC).

### FLUX.1 Kontext (image edit)
- **Prompt style:** natural-language instructions (tell it what to change, like instructing a person).
- **Structure:** "Change/Replace/Add/Remove [target] to/with [description]"; add preservation language ("keeping the pose unchanged"); one focused edit per instruction; text edits in quotes.
- **Strengths:** outfit/background swaps, object add/remove, text editing (Max = best typography), character identity + style transfer.
- **Avoid:** "don't" instructions (rephrase positively); stacking many complex edits; re-describing the whole image.
- **Settings:** Dev open-weight (local); Pro/Max API.
- **Source:** docs.bfl.ml ; node template `flux_edit.md`.

### Z-Image-Turbo (Tongyi / Alibaba)
- **Prompt style:** natural-language descriptive, subject-first; no special token syntax. Optional LLM prompt-enhancement template in the repo.
- **Strengths:** photorealism, accurate bilingual (EN/CN) text, strong instruction adherence, sub-second on 16GB VRAM.
- **Avoid:** negative prompts not used (CFG-distilled); high CFG (4+) degrades results.
- **Settings:** 9 steps (8 DiT forwards) per the official card; CFG 0.0 per the official card (community ComfyUI guides ~1.5-2.0 if any); torch_dtype bfloat16 (official); 1024x1024 best (2K direct can distort, upscale + second pass at ~0.3 denoise); community sampler euler_ancestral or dpmpp_sde, scheduler sgm_uniform.
- **Source:** huggingface.co/Tongyi-MAI/Z-Image-Turbo ; docs.comfy.org/tutorials/image/z-image/z-image-turbo.
- **ControlNet (Fun-Controlnet-Union, alibaba-pai, Apache-2.0):** union ControlNet for Z-Image-Turbo; modes Canny / Depth / Pose / HED / MLSD (+ Scribble in the 2601 build, + Gray in 2602), plus an inpaint mode. Use the distilled `2.1-2602-8steps` variant at 8 steps (the non-distilled 2.0/2.1 lose Turbo's acceleration and then need more steps + cfg). Main knob `control_context_scale` 0.65-1.00 (higher = stronger control and better detail preservation); a detailed prompt helps stability. ComfyUI wiring: load the weights with `ModelPatchLoader`, apply with a DiffSynth ControlNet node (`QwenImageDiffsynthControlnet` in the reference graph; confirm the exact node/pack against `/object_info`). Source: huggingface.co/alibaba-pai/Z-Image-Turbo-Fun-Controlnet-Union-2.1 ; github.com/aigc-apps/VideoX-Fun.
- **Upscale (two options, pick by need):** (1) hires-fix / controlnet-locked: resize up (lanczos 2x) then a Z-Image-Turbo img2img refine with the Union ControlNet locking composition. VERIFIED by testing: the ControlNet holds STRUCTURE (pose, framing, edges) but Z-Image still regenerates content, so at denoise ~0.4-0.7 a real person's face drifts to a similar-but-different identity (structure preserved, identity NOT). Keep denoise ~0.2 to stay faithful (little detail gain), or treat this mode as stylize/enhance, not identity-faithful SR. (2) real super-resolution: the companion `Z-Image-Turbo-Fun-Controlnet-Tile-2.1-2601-8steps` Tile model, trained to 2048x2048 for SR, 8 steps, tiled so structure holds WITHOUT reinterpreting; this is the faithful path. For an identity-locked face upscale, prefer a GAN (Real-ESRGAN) or the Tile model, optionally with a face-ID adapter (PuLID/InstantID). Cost / gotchas: needs the controlnet checkpoint(s) + custom nodes (DiffSynth ControlNet apply node, KJNodes `ImageResizeKJv2`, rgthree Power Lora Loader; core `Canny` or controlnet_aux for the control image); a single high-res pass with the FULL 6.7GB control model is VRAM-heavy and offloads (a ~2.7K refine OOM-crashed a running server on a 24GB card), so cap the target resolution or use the lite control model.

### Qwen-Image (Alibaba)
- **Prompt style:** structured natural language, not tag dumps.
- **Structure:** Subject -> Style -> Details -> Composition -> Lighting; choose ONE primary style; add framing or it defaults centered; exact text in quotes with font/position.
- **Strengths:** commercial-grade text in 26+ languages, posters/infographics/layouts, human realism (2512), natural textures.
- **Avoid:** negatives accepted but inconsistent; long text passages degrade; contradictory styles confuse it.
- **Settings:** base ~20+ steps, sampler euler or res_multistep, CFG 5-7 (text/production), 25-45 steps text-heavy; distilled 15 steps CFG 1.0; 8-step Lightning-LoRA at 8 steps; max prompt ~800 chars.
- **Source:** docs.comfy.org/tutorials/image/qwen/qwen-image ; node template `qwen_image.md`.

### Qwen-Image-Edit (Alibaba)
- **Prompt style:** surgical natural-language instructions, describe only the change.
- **Structure:** "Add/Remove/Change [element + color/size/orientation] [position]"; text edits in English double quotes; reference inputs by number ("Image 1", up to 3 in 2509+); keep 50-200 chars.
- **Strengths:** add/remove/replace, background swap, style transfer, bilingual text editing, portrait/pose edits, multi-image fusion, old-photo restoration.
- **Avoid:** negative prompts NOT supported (use a single space if a field is required); no mask inpainting/outpainting.
- **Settings:** true_cfg_scale 4.0 (4-5), num_inference_steps 50 (20-30 previews), guidance_scale 1.0; node TextEncodeQwenImageEdit + official edit workflow.
- **Source:** docs.comfy.org/tutorials/image/qwen/qwen-image-edit ; node template `qwen_edit.md`.

### SDXL (Stability)
- **Prompt style:** natural language preferred (dual encoder), short comma tags work as hybrid.
- **Structure:** subject + descriptors + style + quality/medium + lighting.
- **Strengths:** 1024-native coherence, better hands/anatomy than SD1.5, huge LoRA/ControlNet ecosystem.
- **Avoid:** negatives supported and effectively required (no built-in quality filter); never generate at 512x512.
- **Settings:** 1024x1024 (or 832x1216, etc.); ~25-40 steps; CFG ~5-8 (~7); sampler DPM++ 2M / Euler a + Karras; optional base->refiner split at the official 80/20 ratio (`high_noise_frac=0.8`: `denoising_end=0.8` on base, `denoising_start=0.8` on refiner, n_steps=40, per the card example). (Step/CFG are community-standard ComfyUI defaults, not a fixed official spec.)
- **Source:** huggingface.co/stabilityai/stable-diffusion-xl-base-1.0.

### Stable Diffusion 1.5
- **Prompt style:** comma-separated tags / keyword-driven; `(token:1.2)` weighting works.
- **Structure:** subject tags -> descriptor tags -> style/quality tags.
- **Strengths:** speed, low VRAM, massive community models/LoRAs/embeddings.
- **Avoid:** negatives supported and heavily used ("blurry, lowres, bad anatomy, watermark"); don't generate far above 512 natively (use hi-res fix); weak hands/text.
- **Settings:** 512x512 native, guidance ~7 (community default; the official card prescribes NO single CFG, it only evaluates a 1.5-8.0 range), 50 PNDM/PLMS steps (community ~20-30 steps, CFG 7); samplers Euler a / DPM++ 2M Karras.
- **Source:** huggingface.co/stable-diffusion-v1-5/stable-diffusion-v1-5 (unofficial mirror, not RunwayML-affiliated); canonical weights now live at huggingface.co/sd-legacy/stable-diffusion-v1-5.

### Stable Diffusion 3.5 Large (Stability)
- **Prompt style:** natural-language sentences (trained on natural language; handles them far better than SD1.5/SDXL).
- **Structure:** Style, Subject + Action, Composition/Framing, Lighting/Color, Technical, Text integration, Negative; ~1MP, dimensions divisible by 64.
- **Avoid:** keyword weighting and bracket/emphasis syntax do NOT work, write plain natural language.
- **Settings:** steps 28 (official example; community up to ~40), guidance 3.5-4.5 (4.5 complex); max_sequence_length 512 for the long / quantized-prompt path; SD3-family nodes; ~1MP divisible by 64.
- **Download:** GATED on HF, accept the license + use a token to download (Stability AI Community License form at huggingface.co/stabilityai/stable-diffusion-3.5-large before the weights are accessible). License: free for orgs / individuals under $1M annual revenue, enterprise license required above that.
- **Source:** huggingface.co/stabilityai/stable-diffusion-3.5-large.

### HiDream-I1
- **Prompt style:** natural-language (multi-encoder incl. an LLM text encoder); no prescribed tag format.
- **Strengths:** state-of-the-art prompt adherence and quality (DPG-Bench 85.89, GenEval 0.83), good text rendering.
- **Avoid:** negative-prompt support not documented; Full (CFG-guided) can use them, Dev/Fast run at guidance 0.0 so negatives are inert.
- **Settings:** Full 50 steps guidance 5.0; Dev 28 steps guidance 0.0; Fast 16 steps guidance 0.0; ComfyUI HiDream sampler nodes.
- **Setup:** requires Flash Attention installed (a hard dependency, not optional) + CUDA 12.4 recommended; inference auto-downloads `meta-llama/Meta-Llama-3.1-8B-Instruct` as the LLM text encoder, which needs a separate HF token with Meta Llama access approved at huggingface.co/meta-llama/Meta-Llama-3.1-8B-Instruct. License: MIT for the transformer weights; the Llama 3.1 Community License governs the text-encoder component.
- **Source:** github.com/HiDream-ai/HiDream-I1 ; huggingface.co/HiDream-ai/HiDream-I1-Full.

### Boogu Image 0.1
- **Prompt style:** natural-language descriptive (Qwen3-VL-8B text encoder); a built-in prompt rewriter (instruction reasoner, Qwen3-VL-32B-Instruct) expands terse inputs, so plain prompts work but detail steers better.
- **Structure:** subject + scene + style + lighting + composition in complete sentences; the VLM encoder favors natural language over tags.
- **Strengths:** open-weight Apache-2.0 (commercial-OK, not gated); three variants - Base (quality), Turbo (few-step distilled, competitive with Z-Image-Turbo), Edit (instruction image edit at 1K/1.5K/2K); rides the Qwen3-VL stack + FLUX VAE.
- **Avoid:** no tag-weighting / bracket syntax (natural language only); negative-prompt support not documented.
- **Settings:** Base ~50 steps, text_guidance 4.0; Turbo is few-step distilled (ships a turbo LoRA `boogu_image_turbo_lora_rank_128`); Edit at 1K / 1.5K / 2K.
- **ComfyUI build:** official templates `image_boogu_image_0_1_turbo_t2i.json` (t2i) and `image_boogu_image_0_1_edit.json` (edit). Comfy-Org repack `huggingface.co/Comfy-Org/Boogu-Image`: `diffusion_models/boogu_image_{base,turbo,edit}_fp8_scaled` (bf16 / nvfp4 also) + `text_encoders/qwen3vl_8b_fp8_scaled` + `vae/flux1_vae` (the FLUX ae). GGUF for low VRAM: `realrebelai/Boogu-Image-{Turbo,Edit}_GGUFs`.
- **License:** Apache-2.0 (commercial use OK), open weights, not gated.
- **Source:** huggingface.co/Boogu (maker) ; huggingface.co/Comfy-Org/Boogu-Image (ComfyUI repack) ; demo-turbo.boogu.org.

## Image models (API / closed)

### Ideogram (2.x and 3.0)
- **Prompt style:** natural-language sentences (no tags, no `--ar`/`::` flags); typography specialist.
- **Structure:** describe as to a person; important elements and text early; exact text in quotes (under ~25 chars), describe font style/position/color, don't name fonts.
- **Strengths:** quoted-text rendering, posters/logos/signage; `DESIGN` style for typography, `REALISTIC` for photos.
- **Avoid:** long text strings, burying text mid-prompt, naming fonts. Negative prompts ARE supported (`negative_prompt`; positive takes precedence).
- **Settings (API):** `style_type`, `rendering_speed` (TURBO/DEFAULT/QUALITY), `magic_prompt`, aspect ratios, seed, up to 4 images/call, character & style refs.
- **Source:** docs.ideogram.ai/using-ideogram/prompting-guide ; developer.ideogram.ai.

### Nano Banana Pro (Gemini 3 Pro Image)
- **Prompt style:** natural-language, rich descriptive paragraphs (describe the scene, don't list keywords).
- **Structure:** prose covering subject, spatial relationships, lighting/mood, woven-in camera language; exact text in quotes; label each reference by role ("Image 1 is the product").
- **Strengths:** internal reasoning before render, multilingual text + in-image translation, character consistency, reference blending, Google Search grounding (add "using current data"), world-knowledge physics. Up to 11 refs.
- **Avoid:** keyword lists, bracket templates, telegraphic language, vague praise. Negatives not used, phrase positively ("an empty street", not "no cars").
- **Source:** ai.google.dev/gemini-api/docs/image-generation.

### Nano Banana 2 (Gemini 3.1 Flash Image)
- **Prompt style:** natural-language descriptive prose (same as Pro), speed-optimized (<~20s).
- **Structure:** six elements - subject, composition/camera, action, aspect ratio (state when non-standard), lighting (photographic terms), style; exact text in quotes; label refs; request resolution above default 1K.
- **Strengths:** fast iteration, extended ratios (1:4, 4:1, 1:8, 8:1), tiers 0.5K/1K/2K/4K, web+image Search grounding, up to 14 refs, 360-degree character sheets.
- **Avoid:** keyword dumps, bracket templates, negative phrasing, temperature below 1.0 (loops). Small CJK text and data-viz error-prone; knowledge cutoff Jan 2025 (use grounding).
- **Source:** ai.google.dev/gemini-api/docs/image-generation.

### Seedream 4.0 / 4.5 (ByteDance)
- **Prompt style:** structured (technical specifications, direct over narrative - the exception among modern models).
- **Structure:** explicit identity-lock descriptors (face, hair, build, clothing) for series; state what's consistent vs variable; exact text in quotes; 50-100 words (range 30-300; cap ~600 EN words / 300 CN chars).
- **Strengths:** up to 15-image sequential batch with identity locking, up to 14 refs, facial-landmark consistency, sharp small-text/logo typography.
- **Avoid:** keyword dumps, flowery language, missing identity-lock descriptors. Describe positively (no explicit negative guidance).
- **Source:** volcengine.com/docs (BytePlus/Volcengine Seedream) ; node template `seedream.md`.

### Seedream 5.0 Lite (ByteDance)
- **Prompt style:** natural-language sentences REPLACE keyword lists; relationship-first; CoT reasoning model.
- **Structure:** `[subject + key trait] [action/pose] [environment with spatial relationship] [optional one-phrase style anchor]`; state object relationships; for series state count + consistency; text in double quotes; refs as Figure 1, 2.
- **Strengths:** coherent from short/abstract prompts, web search, stronger identity lock than 4.x, 2560x1440 to 3072x3072 (`auto_2K`/`auto_3K`).
- **Avoid:** CRITICAL - quality boosters ("masterpiece", "8K", "best quality") HARM output (distract the CoT pipeline); no `(word:1.3)` weights; negatives NOT supported; no guidance-scale param.
- **Source:** volcengine.com/docs (Seedream 5.0 Lite) ; node template `seedream_5_lite.md`.

### Recraft (V3)
- **Prompt style:** natural-language, specific over vague; long-text + vector design specialist.
- **Structure:** "A `<style>` of `<main content>`. `<detailed description>`. `<background>`. `<style description>`." general -> specific; exact text in quotes.
- **Strengths:** long multi-word text with exact positioning/sizing; `style` param (`realistic_image`, `digital_illustration`, `vector_illustration`, `icon`) + 100+ presets + custom style refs; true scalable vector/SVG.
- **Avoid:** negative phrasing confuses it (just omit unwanted elements, no negative field); ambiguous nouns; vague plurals.
- **Source:** recraft.ai/docs (prompting + styles) ; recraft.ai/api.

### GPT-Image (gpt-image-2, OpenAI)
- **Prompt style:** structured natural-language ("structure beats length"), a labeled five-slot brief.
- **Structure:** Scene -> Subject -> Important Details (lighting, camera, materials, exact text in quotes) -> Use Case -> Constraints (don'ts/preservation); include literal "photorealistic"; spell unusual names letter-by-letter + "render text verbatim".
- **Strengths:** accurate dense/multi-font text, identity consistency, any size, up to 10 refs; `low` quality is production-grade.
- **Avoid:** vague praise, generic style tags, one giant rewrite, negative subject phrasing. No negative field, state avoidances in Constraints.
- **Settings (API):** `quality` (low/medium/high/auto), edges multiple of 16, max edge 3840px, <=3:1, reliable up to 2560x1440; `background`, `output_format`.
- **Source:** platform.openai.com/docs/guides/image-generation.

### Grok Image (Grok Imagine Image, xAI)
- **Prompt style:** natural-language scene description, six-part formula.
- **Structure:** Subject -> Style -> Mood -> Lighting -> Camera/Framing -> Finishing; subject in the first words; 60-80 words (cut past 120); one style; in-image text ALL CAPS + quotes, 1-3 words.
- **Strengths:** behavior-based light, concrete camera/lens, named aesthetics; `-quality` tier adds i2i (1-3 refs) and better non-English text.
- **Avoid:** negatives IGNORED (rephrase positive); keyword stacking; mixed styles; buried subject.
- **Source:** docs.x.ai/docs/guides/image-generations.

### Reve
- **Prompt style:** natural-language, descriptive/conversational; high prompt adherence so be concrete and complete.
- **Avoid:** negative prompts NOT supported (single `prompt` param); no documented weighting syntax (don't rely on `(red:1.3)`).
- **Settings (API):** single `prompt`; aspect ratios 16:9/9:16/3:2(def)/2:3/4:3/3:4/1:1; 4K output (Reve 2.x); edit-image endpoint.
- **Source:** app.reve.com ; docs.aimlapi.com/api-references/image-models/reve. (Official prompt-engineering page is thin.)

### Kandinsky (3.x, Sber / FusionBrain)
- **Prompt style:** natural-language; built-in beautifier LLM expands plain prompts, so describe simply.
- **Structure:** subject + setting + style in natural language; select a `style` preset; pass excluded elements via the negative field.
- **Strengths:** built-in prompt enhancement, style presets, inpainting/i2i, fully open checkpoints.
- **Avoid:** over-long prompts. Negative prompts ARE supported (dedicated field).
- **Settings (FusionBrain API):** `query` + negative field, `style`, 1024x1024 default, sizes multiples of 64.
- **Source:** fusionbrain.ai/docs/en ; ai-forever.github.io/Kandinsky-3.

## More open image models

### BRIA 3.x
- **Prompt style:** natural-language descriptive sentences.
- **Structure:** plain descriptive sentence; for text-in-image name the literal words + style/placement ("the words 'BRIA 3.2' in bold yellow 3D letters"). FLUX-derived MMDiT + T5-XXL.
- **Strengths:** commercial-safe (licensed-data only), short 1-6 word text rendering, photorealism, prompt adherence.
- **Avoid:** long text passages (optimized for 1-6 words). Negatives ARE supported (`negative_prompt`, active when guidance_scale > 1).
- **Settings:** FlowMatchEulerDiscrete; guidance_scale 5.0; ~30-50 steps; 1024x1024; true CFG (not distilled); T5 precision-sensitive (bf16 + final layer fp32), VAE fp32; gated.
- **Source:** huggingface.co/briaai/BRIA-3.2 (GATED - fill the form + `hf auth login` to download; commercial Bria license, free trial at bria.ai) ; github.com/Bria-AI/BRIA-3.2 (pipeline source + API; no ComfyUI nodes in the repo) ; huggingface.co/docs/diffusers/api/pipelines/bria_3_2 (`BriaPipeline`, public, no gate - recipe verified here). **ComfyUI:** no native node ships; build via the diffusers BriaPipeline or an API node.

### OmniGen (v1 / v2) - unified gen + edit
- **Prompt style:** instruction + inline image placeholders.
- **Structure:** v1 refs inline `<img><|image_1|></img>` (one per image), place the image BEFORE the instruction for edits. v2 edit template "Edit the first image: add/replace ... the [object] from the second image. [target]"; name sources explicitly; longer/detailed prompts beat short, English best.
- **Avoid:** vague cross-image references. Negatives supported in v2 ("blurry, low quality, text, watermark").
- **Settings:** v1 guidance_scale 2-3, img_guidance_scale ~1.6, output divisible by 16, 1024x1024; v2 text_guidance_scale + image_guidance_scale ~1.2-2.0 (edit) / ~2.5-3.0 (in-context), 50 steps, refs >512x512.
- **ComfyUI build (v2):** official templates `image_omnigen2_t2i.json` (t2i) and `image_omnigen2_image_edit.json` (editing) in the Comfy-Org template library. v1 has no native ComfyUI node (use diffusers).
- **Source:** github.com/VectorSpaceLab/OmniGen ; github.com/VectorSpaceLab/OmniGen2.

### Chroma
- **Prompt style:** natural-language.
- **Structure:** descriptive sentence(s): subject, style, lighting, palette.
- **Strengths:** Apache-2.0 open-weight 8.9B from FLUX.1-schnell; broad/less-censored aesthetic range; Chroma1-HD is the higher-quality variant.
- **Avoid:** no official prompt-recipe doc (maker says users figure settings out), treat numbers as examples. Negatives supported (card example: "low quality, ugly, unfinished, out of focus, deformed, blurry, flat colors").
- **Settings:** card example ~40 steps, CFG 3.0, bfloat16; ChromaPipeline; same optimizations as Flux.
- **ComfyUI setup:** put the checkpoint in `diffusion_models/` (NOT `checkpoints/`); needs a T5 XXL text encoder (`t5xxl_fp16.safetensors`) in `models/clip/` and the FLUX VAE (`ae.safetensors`) in `models/vae/` as separate downloads. Official workflow JSON: huggingface.co/lodestones/Chroma1-HD/resolve/main/ComfyUI_Chroma1-HD_T2I-workflow.json. Worked card example: "A high-fashion close-up portrait of a blonde woman in clear sunglasses ... bold teal and red color split ... designed for viewing with anaglyph 3D glasses." Sister model `Chroma1-Flash` is the fast CFG-baked variant if throughput matters.
- **Source:** huggingface.co/lodestones/Chroma1-HD.

### Krea 1 (FLUX.1 Krea [dev])
- **Prompt style:** natural-language, no weighting syntax.
- **Structure:** subject + style + scene + lighting + colors; short imaginative prompts work.
- **Strengths:** photorealism without the "AI look" (no plastic texture / blurred-bg artifacts); drop-in for FLUX.1 [dev].
- **Avoid:** filler ("beautiful", "amazing"); ignores `(best quality:1.3)` / `[[masterpiece]]` brackets/colons; guidance-distilled so no true CFG/negative (like FLUX.1 [dev]).
- **Settings:** guidance_scale 4.5 (official example); 1024x1024; FLUX.1 [dev] pipeline.
- **Download / license:** GATED on HF, accept the license + use a token to download (must accept the FluxDev Non-Commercial License Agreement + Acceptable Use Policy on the model page first). License is NON-COMMERCIAL only (flux-1-dev-non-commercial-license).
- **Source:** huggingface.co/black-forest-labs/FLUX.1-Krea-dev ; docs.krea.ai.

### Krea 2 (Krea AI, open weights)
- **Prompt style:** natural language; long detailed prompts give the best results, but minimal prompts also work;
  put words in quotes for text rendering. Built-in prompt enhancement is on by default in the ComfyUI template (swap
  it for OpenAI / Gemini nodes, or use the repo's `expansion.txt` as an LLM system prompt).
- **Example (official prompt guide):** minimal works (`immense rocket launch exhaust as seen from extremely close
  up`), but detail wins. Stack natural-language clauses for subject, composition, lighting, color, texture, and
  medium, e.g. `stylized digital painting of a dark convertible on a winding coastal cliff road, high-angle
  perspective, blocky painterly brushstrokes, golden hour sunlight hitting rocky orange terrain and green
  vegetation, ... vibrant warm color palette, sharp graphic shadows`.
- **Style-suffix pattern (from ~15 of the 20 official Raw/Turbo gallery prompts):** append a comma-separated style
  tag at the END of the scene description to steer style: `<scene>, <style tag>`. Example tags from the cards:
  `halftone texture`, `thermal imaging style`, `impressionist painting, visible brushstrokes`, `black and white
  photography` (others in the galleries: low-poly 3D models, anime, vintage collage, dark fantasy concept art).
- **Two models that pair:** **RAW** (base, undistilled, diverse and malleable) is for fine-tuning and LoRA training;
  **Turbo** (8-step distilled) is for fast inference. Train LoRAs on RAW, then apply them on Turbo (compatible).
- **Strengths:** from-scratch MMDiT; the most aesthetic open-weight image model and the #1 text-to-image model from
  an independent lab (Artificial Analysis); 2K-native on Turbo, strong text rendering. Architecture rides the Qwen
  stack: a Qwen3-VL-4B text encoder + the Qwen-Image VAE.
- **Settings:** RAW = full sampler, 52 steps, CFG 3.5, up to 1K. Turbo = 8 steps, CFG 0.0 (disabled), mu 1.15 (the
  flow shift), 1K to 2K (2048x2048).
- **Run it (ComfyUI, day-0 native, no custom nodes):** official template `image_krea2_turbo_t2i` in the Comfy-Org
  template library. Comfy-Org repackaged the weights at `huggingface.co/Comfy-Org/Krea-2`:
  `diffusion_models/krea2_turbo_fp8_scaled` (plus BF16 / NVFP4 variants), `text_encoders/qwen3vl_4b_fp8_scaled`,
  `vae/qwen_image_vae`. NINE official style LoRAs (`Comfy-Org/Krea-2/loras`), each with its trigger word at strength
  1.0 (put the trigger phrase in the prompt): `krea2_darkbrush` "monochrome ink wash style", `krea2_dotmatrix`
  "Monochrome stippling style", `krea2_kidsdrawing` "naive expressive sketch style", `krea2_neondrip` "Textured abstract
  style", `krea2_rainywindow` "rainy window style", `krea2_retroanime` "Purple retro anime style", `krea2_softwatercolor`
  "Art Deco watercolor style", `krea2_sunsetblur` "ethereal motion blur style", `krea2_vintagetarot` "vintage tarot style".
- **Community style LoRAs (fal, ~1503):** beyond the 9 official LoRAs, `ilkerzgi/fal-Krea-2-Style-LoRAs` indexes ~1503
  community style LoRAs for Krea 2 Turbo (Krea-2 Community License), each its own repo (e.g. `ilkerzgi/krea-2-airy-porcelain-blue-lora`).
  Put the style trigger at the END of the prompt, LoRA scale 1.0-1.25; run on fal `fal-ai/krea-2/turbo/lora` or download the individual LoRA.
- **Weak VAE, much better decode (RECOMMENDED, big quality jump):** Krea 2's stock Qwen-Image VAE is the weak link;
  swapping the decoder is a large, clearly visible jump (practitioner-confirmed, not subtle). Use **NVIDIA PiD** (Pixel
  Diffusion Decoder: latent-conditioned pixel-diffusion decode + super-res in one pass) via **`Merserk/ComfyUI-PiD`**
  (MIT, Comfy-Org/PixelDiT loading; prefer over `tsolful/ComfyUI-PiD`, which is thinner + license "other"). **Build it:**
  PiD needs the latent AND its sigma, so replace the stock `KSampler -> VAEDecode` tail with `PiD KSampler Capture` (a
  drop-in sampler, outputs `pid_latent` + `pid_sigma`) -> `PiD Decode` (latent + caption + sigma -> `IMAGE`), caption from
  `PiD Text Prompt`. Krea 2 rides the Qwen-Image VAE latent, so use PiD's Qwen-Image path at `model_precision=bf16` (fp8 is
  Flux-only); weights auto-download (`auto_download=true`) into `models/vae/nvidia_pid/`. Simpler alternative: swap the VAE
  node for the **WAN 2.1 VAE**. (PiD's official backbones are flux/flux2/sd3/zimage; Krea 2 is community-applied, works very
  well.) Sources: github.com/Merserk/ComfyUI-PiD ; github.com/nv-tlabs/PiD ; Reddit r/StableDiffusion 1ue8rns ; t.me/GreenNeuralRobots/12656.
- **Reference-image control (image+mask), buildable:** `ComfyUI-Krea2TextEncoder` (ethanfel, MIT) adds the
  **`TextEncodeKrea2`** node (category `model/conditioning/krea2`). **Wire it in place of the text encode:** inputs `clip`
  (the Krea2 CLIP) + `prompt` (multiline) + optional reference pairs `image1`/`mask1` (a fresh `image2`/`mask2` appears as
  you connect each) + `mask_padding` (0 = tight crop to the mask, ~0.1 = ~10% margin per side); output `CONDITIONING` -> the
  sampler's positive. It forces the Krea2 descriptor template and routes the reference image+mask through Krea 2's
  Qwen3-VL-4B vision path, fixing the core `TextEncodeQwenImageEdit` (whose VAE input does nothing, since Krea 2's DiT has no
  reference-latent slot, and which falls back to the plain Qwen template).
- **License:** the code is Apache-2.0; the WEIGHTS use the Krea 2 Community License: commercial use needs a separate
  Enterprise License (community use is non-commercial), with acceptable-use / content-filter obligations.
- **Source:** github.com/krea-ai/krea-2 (incl. `docs/prompting.md`) ; huggingface.co/Comfy-Org/Krea-2 (ComfyUI repackaged) ;
  huggingface.co/krea/Krea-2-Raw + huggingface.co/krea/Krea-2-Turbo ;
  blog.comfy.org/p/krea-2-open-source-models-are-now ; krea.ai/blog/krea-2-technical-report.

### ERNIE-Image (Baidu)
- **Prompt style:** instruction / natural-language; built-in 3B Prompt Enhancer expands terse inputs.
- **Structure:** describe the scene + exact text strings and their layout; handles multi-object relations and knowledge-intensive descriptions; EN/CN + mixed-language text in one image.
- **Strengths:** layout-sensitive typography, multilingual text, complex/structured compositions (posters, storyboards, multi-panel); Apache-2.0 8B single-stream DiT.
- **Avoid:** no official CFG/negative/resolution recipe published; lean on the prompt enhancer for terse inputs.
- **Settings:** base ~50 steps; ERNIE-Image-Turbo 8 steps; Comfy repack needs ernie-image[-turbo], ernie-image-prompt-enhancer, ministral-3-3b, flux2-vae.
- **Source:** docs.comfy.org/tutorials/image/ernie-image/ernie-image ; github.com/baidu/ERNIE-Image. (Baidu's text-to-image DiT, NOT the ERNIE-4.5-VL understanding models.)

## Image editing models (instruction-based)

Edit models take an input image + a change instruction, not a from-scratch prompt. Also see FLUX.1 Kontext,
Qwen-Image-Edit, OmniGen (above), Seedream Edit, and Nano Banana edit, which are instruction-based too.

### FireRed Image Edit
- **Prompt style:** instruction, bilingual CN-EN; state the change directly.
- **Structure:** direct edit command; text edits name the literal string + placement ("add '2nd Edition' below 'Python'"); makeup/style transfer, virtual try-on, old-photo restoration, multi-element edits; no rigid template.
- **Strengths:** precise instruction following, identity preservation, high-fidelity text-in-image (open-source SOTA edit).
- **Avoid:** no official CFG/negative/resolution spec; Lightning-8steps variant for speed.
- **Settings:** sparse official numbers (~4.5s/sample, ~30GB VRAM optimized); official ComfyUI workflow + quantized weights (v1.0/v1.1).
- **Source:** github.com/FireRedTeam/FireRed-Image-Edit.
- **ComfyUI build:** official template `image_firered_image_edit1_1.json` (Comfy-Org template library).

### LongCat-Image / LongCat-Image-Edit (Meituan)
- **Prompt style:** natural-language (T2I) / instruction (edit), bilingual; 6B.
- **Structure:** CRITICAL text rule - enclose literal target text in quotes ('...' / "..."); a character-level encoder handles quoted content, unquoted text renders poorly. Edit instructions are direct ("turn the cat into a dog").
- **Strengths:** multilingual text in images, photorealism, efficient (6B beats larger on several benchmarks).
- **Avoid:** forgetting quotes around target text. Negative prompt can be empty.
- **Settings (T2I):** guidance_scale 4.0, 50 steps, 768x1344 canonical resolution, `enable_cfg_renorm=True`, `enable_prompt_rewrite=True` (LLM prompt-refine flag, improves quality), bf16, ~17GB VRAM with CPU offload.
- **Settings (edit):** guidance_scale 4.5, 50 steps, bf16, ~18GB VRAM with CPU offload.
- **ComfyUI build:** no official Comfy-Org template; run via diffusers, or a community repack/wrapper if one is installed.
- **Source:** huggingface.co/meituan-longcat/LongCat-Image-Edit ; huggingface.co/meituan-longcat/LongCat-Image.

### ChronoEdit (NVIDIA)
- **Prompt style:** instruction; optional Prompt Enhancer rewrites it.
- **Structure:** image + short imperative ("Add sunglasses to the cat's face"); reframes the edit as a short video between input and edited frame so changes respect physics; up to ~300 tokens.
- **Strengths:** physically/temporally consistent edits, action-conditioned "world simulation"; can output the reasoning frames.
- **Avoid:** gated card, sparse on CFG/negatives; use `--use-prompt-enhancer` for terse instructions.
- **Settings:** RGB input recommended <=1024x1024; Upscaler LoRA published; ComfyUI + diffusers (nvidia/ChronoEdit-14B-Diffusers).
- **Source:** github.com/nv-tlabs/ChronoEdit.
- **ComfyUI build:** official template `image_chrono_edit_14B.json` (Comfy-Org template library) - open it and wire per the template-reading note in SKILL.md.

## Video models (open / local-runnable)

### Wan 2.1 & 2.2 (Alibaba)
- **Prompt style:** concise cinematic shot description; camera-sees-first, then action, then one camera move; specific descriptors. I2V = motion + camera only (image is the anchor).
- **Structure:** shot type -> subject -> primary action -> one camera move -> environment (3-5) -> lighting -> style -> color.
- **Strengths:** 2.2 better prompt adherence, negative enforcement, camera control, temporal consistency; sequential "first... then...".
- **Avoid:** multiple actions/conflicting camera moves, keyword stuffing, vague descriptors. Negatives ARE supported (best on 2.2): "blurry, low quality, watermark, jittery motion, deformed hands, extra limbs, distorted face, morphing".
- **Settings:** ~5s; native fps 16 (24 for 5B TI2V); ~480-720p by VRAM; prompt ~256 tokens; 14B loads BOTH high-noise + low-noise experts sequentially; 5B TI2V single hybrid (8GB-friendly). Use the official ComfyUI Wan2.2 workflow defaults; run a short low-res test first.
- **Multi-shot temporal control (Prompt Relay):** Wan 2.2 is the NATIVE target of Prompt Relay (arXiv 2604.10030):
  route timed `local_prompts` to their segments via a cross-attention penalty for multi-event clips without
  entanglement (often beats base Wan 2.2 on temporal alignment, near Kling 3.0). Official Wan2.2 implementation +
  ComfyUI port `kijai/ComfyUI-PromptRelay`; node + Smart-syntax details in the LTX-2.3 entry. Source: gordonchen19.github.io/Prompt-Relay.
- **Source:** docs.comfy.org/tutorials/video/wan/wan2_2 ; node template `wan_2-1_2-2.md`.

### Wan 2.5 / 2.6 (Alibaba, API)
- **Prompt style:** cinematic visual first, then layer audio; multi-shot uses a global style line + timed blocks ("Shot 1 [0-3s]: ..."); I2V describes temporal change only.
- **Structure:** shot -> subject -> action -> one camera move -> environment -> lighting -> style -> `Audio: [dialogue / SFX / ambient / music]`; R2V tags `@Video1/@Video2/@Video3`.
- **Strengths:** synchronized multilingual lip-sync dialogue, ambient/SFX/music, multi-person timbre, multi-shot; make audio specific.
- **Avoid:** audio overpowering visual instruction; vague audio. Negatives supported (~500 chars); LLM prompt expansion on by default.
- **Settings:** API; 720p/1080p; 5/10/15s (R2V 5/10s); aspect 16:9/9:16/1:1/4:3/3:4; audio in WAV/MP3 3-30s. Use API-wrapper/partner nodes.
- **Source:** fal.ai/learn/devs/wan-2-6-prompt-guide ; DashScope/Alibaba Cloud Wan docs ; node template `wan_2-5_2-6.md`.

### Wan 2.7 (Alibaba)
- **Prompt style:** generation formula Subject + Scene + Motion + Aesthetic control (light, shot size, angle, lens, move) + Stylization + `Sound description`. Editing uses imperative commands instead.
- **Structure:** subject (appearance) -> scene -> motion (amplitude + speed) -> aesthetic control -> stylization -> audio; R2V uses numbered indices ("the character in Video 1"), NOT `@Video1`; FLF2V = first -> bridging motion -> end.
- **Strengths:** first+last-frame control, 3x3 image input for cross-shot consistency, up to 5 refs, subject+voice cloning, instruction edits, multi-shot.
- **Avoid:** multiple actions/camera moves per shot, mixing description with edit commands, `@VideoN` tags. Negatives supported.
- **Settings:** API (open Apache-2.0 weights expected Q2 2026); 720p/1080p; 2-15s; ~80-120 words; ComfyUI partner nodes v0.18.5+.
- **Source:** node template `wan_2-7.md` ; fal.ai / Replicate / WaveSpeedAI / Alibaba Cloud DashScope.

### LTX-2.3 (Lightricks)
- **Prompt style (official guide):** ONE flowing cinematography paragraph, not tag dumps. Order: shot/framing ->
  scene (lighting, color, texture, atmosphere) -> action (present-tense verbs) -> character (age, clothing,
  features) -> camera move(s) -> audio. Match prompt length to clip length (a 10-word prompt for a 10s clip
  underperforms; longer beats shorter). Dialogue in quotation marks, short phrases with acting beats between them;
  describe performance physically ("pauses, looks aside"), not emotionally ("sad"). Lens/optics terms land
  ("macro lens", "shallow depth of field", "golden hour", "handheld tracking").
- **I2V:** prompt the MOTION / transition only, do not re-describe what is already in the image. Audio-to-video:
  the audio anchors timing, the prompt describes the visual interpretation.
- **Strengths:** native synced audio (more impactful in 2.3), multilingual dialogue (9 langs), smooth I2V, 9:16.
- **Avoid:** internal emotions, readable text/logos (unreliable), chaotic physics, overloaded or self-contradicting
  scenes, numerical over-specification. Negatives: the official guide does not cover them, but templates expose a
  negative conditioning input (works on Dev/CFG>1; Distilled at CFG=1 ignores it).
- **Settings:** width/height divisible by 32; frame count 8k+1 (9, 17, ... 121, 193, 257); fps up to 50; up to
  ~10s; two-stage 2x upsample (official spatial x2/x1.5 + temporal x2 upscalers pair with the base); Dev ~30-40
  steps CFG ~3.0 STG ~1.0; Distilled (8-step, CFG 1) for speed.
- **Run it (ComfyUI):** base t2v/i2v/flf2v/ia2v run on NATIVE ComfyUI core (no extra nodes, just keep ComfyUI
  updated). The IC-LoRA / id-LoRA / lipdub / control workflows REQUIRE the `ComfyUI-LTXVideo` node pack (Manager:
  search "LTXVideo") and its `LTXICLoRALoaderModelOnly`; a generic LoRA loader silently will NOT apply IC-LoRA
  conditioning. Useful IC-LoRAs (into `models/loras`, run via the ic_lora workflow): **Ingredients** (official,
  cross-clip character/prop consistency; two-part prompt "Reference sheet: ... / Generated video: ...", strength
  ~1.4); **MotionDeblur** (oumoumad, community, KEY for RESTORATION: reduces/removes motion blur and reconstructs
  sharper frames; file `ltx-2.3-22b-ic-lora-motiondeblur.safetensors`). Pair MotionDeblur with the LTX-2.3 restore
  templates (restore_archival_footage, remove_watermark) and the SeedVR2/SUPIR upscalers for a restoration chain.
- **HDR IC-LoRA (SDR -> HDR video):** `Lightricks/LTX-2.3-22b-IC-LoRA-HDR` (files `ltx-2.3-22b-ic-lora-hdr-0.9.safetensors`
  + `ltx-2.3-22b-ic-lora-hdr-scene-emb.safetensors`; `license:other`, GATED on HF, so accept the license + use a token
  to download). Per the paper (arXiv 2604.11788, "HDR Video Generation via Latent Alignment with Logarithmic Encoding")
  a logarithmic encoding maps HDR into the model's latent so a light IC-LoRA adapts it without retraining the encoder.
  READY workflow ships in the pack: `ComfyUI-LTXVideo/example_workflows/2.3/LTX-2.3_ICLoRA_HDR_Distilled.json` (with the
  `hdr.py` node + an `hdr_input_video.mp4` example); needs a CURRENT ComfyUI-LTXVideo with BOTH required nodes,
  `LTXICLoRALoaderModelOnly` (loads the LoRA + extracts the downscale factor) AND `LTXAddVideoICLoRAGuide` (adds the small
  latent as a guide), both absent in older installs. Save to an HDR-capable format (EXR / 16-bit / HDR video), NOT 8-bit PNG. Source:
  huggingface.co/Lightricks/LTX-2.3-22b-IC-LoRA-HDR ; hdr-lumivid.github.io ; github.com/Lightricks/ComfyUI-LTXVideo.
- **Water Simulation IC-LoRA (add water to a live shot):** `Lightricks/LTX-2.3-22b-IC-LoRA-Water-Simulation` (file
  `ltx-2.3-22b-ic-lora-water-simulation-0.9.safetensors`; gated LTX-2-community-license; v2v reference-conditioned).
  Adds rivers / surf / rain / waterfalls / floods / splashes / wet specularities to a "dry" reference clip while keeping
  identity, clothing, pose, camera framing and background geometry identical. Control = the dry video VAE-encoded (24 fps,
  no mask, whole-frame, downscale 1), conditioning on the first `F` frames where `(F-1) % 8 == 0` (e.g. 121 / 153 / 185,
  ~7.7s max). Prompt is dual-panel and MUST contain the trigger `ADD WATER`: "Reference shows <dry scene>. Edited shows the
  same scene with water added. ADD WATER <concrete water: type, motion, how it interacts with the subject>. Subject
  identity, clothing, framing and background are identical to the reference." Worked gallery examples (vary the subject +
  the ADD-WATER clause, keep the wrapper): brown rabbit on mossy rocks -> fast river with white foam over the rocks; hands
  drawing lines in dry sand -> clear shallow water filling the lines; goats on a dirt path -> shallow clear stream
  splashing around their hooves; a hand over dry sand -> calm rippling water, hand dipping and dripping; people and a cart
  in a narrow alley -> murky flood submerging the cart wheels and splashing legs; dogs on a dry pine-needle forest floor ->
  calm reflective flood, dogs in a shallow marsh. Run via a V2V IC-LoRA workflow from the
  `ComfyUI-LTXVideo` pack (`LTX-2.3_V2V_ICLoRA_Single_Stage_Distilled.json` + `LTXICLoRALoaderModelOnly`); no water-specific
  workflow ships yet. **Strength sweet spot 1.2** (1.0-1.05 natural / identity-safe; 1.1-1.5 hard surface replacement like
  ground -> sea; >= 1.5 maximizes drama but warps faces). **CRITICAL recipe:** render the distilled **stage-1 ONLY at native
  resolution** (1920x1088 / 1088x1920, 24 fps), CFG 1.0, 8 fixed sigmas, no negative - the two-stage path applies the
  reference only in stage 1, and the stage-2 upscaler drifts the subject's identity; lowering strength does NOT fix it
  (structural). Trained on real water, so other liquids (lava / slime / paint) generalize only loosely. **Higher res without the
  stage-2 identity drift (kit tip, inferred, not card-tested):** the drift comes from the LTX stage-2 upscaler
  re-diffusing the subject from the prompt, so render the identity-safe stage-1 at native, then upscale OUTSIDE the LTX
  two-stage with a NON-re-diffusing / identity-preserving upscaler (SeedVR2, a tile-GAN like 4x-UltraSharp, or SUPIR at
  low denoise). Resolution rises and the subject stays put. Source:
  huggingface.co/Lightricks/LTX-2.3-22b-IC-LoRA-Water-Simulation ; docs.ltx.video IC-LoRA guide ; github.com/Lightricks/ComfyUI-LTXVideo.
- **3D render to photoreal (3DREAL IC-LoRA):** `fal/LTX-2.3-3DREAL-LoRA`, trigger `3DREAL` (license:other, base LTX-Video).
  An in-context LoRA that turns a rough grey 3D viewport animation (Blender blockouts, game-engine viewports, CG / synthetic
  renders) into photoreal cinematic video, with the 3D render as the reference. Run on fal `fal-ai/ltx-2.3-quality/render-to-real`
  (LoRA built in), or load it as an LTX-2.3 V2V IC-LoRA. Built for CG / synthetic-data to photoreal and viewport-driven final renders.
  Source: huggingface.co/fal/LTX-2.3-3DREAL-LoRA.
- **Multi-shot / timeline direction (Prompt Relay + LTX Director 2.0):** several TIMED events in ONE clip without
  temporal entanglement (one paragraph for many events smears them). **Prompt Relay** (arXiv 2604.10030, S-Lab NTU)
  is a training-free, inference-time method: it routes each prompt to its time segment via a distance penalty in
  cross-attention. Input = a `global_prompt` (persistent character/scene) + ordered `local_prompts` + optional
  `segment_lengths` (latent-frame budget per prompt, summing to (frames-1)//4+1). ComfyUI port:
  `kijai/ComfyUI-PromptRelay` (nodes `PromptRelayEncodeTimeline` + a "Smart" encoder: one field, segments split by
  `|` or `Scene N:` headers, weights `[0-50]`/ranges, auto frame distribution); ready graph
  `prompt_relay_ltx23_test_02.json`; works on LTX 2.3 AND Wan 2.2; WIP, NO license file (use ok, do not
  redistribute). **LTX Director 2.0** (`WhatDreamsCost/WhatDreamsCost-ComfyUI`, GPL-3.0) wraps Prompt Relay into a
  full timeline-editor node for LTX 2.3: trim/split/combine, IC-LoRA track, keyframes, audio inpaint, Retake
  (regenerate a shot segment), save/load timeline; ready graph `LTX_Director_2_Workflow_Hotfix.json` (nodes
  `LTXDirector`/`LTXDirectorGuide` + 2-stage `LTXVLatentUpsampler` + audio). Both REQUIRE current
  `ComfyUI-LTXVideo` + `ComfyUI-KJNodes`, and Prompt Relay monkeypatches cross-attention (version-sensitive).
  Source: gordonchen19.github.io/Prompt-Relay ; github.com/kijai/ComfyUI-PromptRelay ; github.com/WhatDreamsCost/WhatDreamsCost-ComfyUI.
- **Field techniques (community, surfaced from production users; NOT in the official LTXVideo pack unless noted):**
  - **External-audio sync (official nodes, field wiring):** drive video from an external audio track (image + audio ->
    motion/lip-synced clip) with `LTXVAudioVAEEncode/Decode`, `LTXVConcatAVLatent` / `LTXVSeparateAVLatent`,
    `LTXVEmptyLatentAudio`, `LoadAudio`, `TrimAudioDuration` (all official ComfyUI-LTXVideo). Tip: run the source through
    `ComfyUI-MelBandRoFormer` (stem separation) first to feed clean vocals.
  - **Fit the 22B on a 24GB card: GGUF.** `GGUFLoaderKJ` (KJNodes) loads a GGUF-quantized LTX-2.3, shrinking the ~25GB
    fp8 transformer to fit one 24GB GPU (the exact wall this kit hit sizing a 22B run). VRAM win for a small quality cost.
  - **Speed / quality / long clips (KJNodes + CacheDiT):** `CacheDiT_LTX2_Optimizer` (Jasonzzt/ComfyUI-CacheDiT) caches
    diffusion steps to accelerate inference; `LTX2_NAG` (KJNodes) adds Normalized Attention Guidance as a quality/adherence
    lever; `LTXVChunkFeedForward` (KJNodes) chunks the feed-forward to cut memory on long clips; `LTXVAddGuideMulti`
    (KJNodes) drives multi-keyframe (first / middle / last and more) guided motion.
  - **Lipsync + storyboard + long audio: GAP LTX 2.3 Motion** (`github.com/GeekatplayStudio/LTX-2-3-LipSync`, MIT) adds
    nodes for audio-segment render loops, storyboard scheduling, and motion transfer for long-form audio-driven video.
    CAVEAT: users report the storyboard variant's custom-audio path can produce noise, so test the audio leg on a short
    clip first. Status: community-endorsed (widely used in production), NOT independently benchmarked by this kit.
- **Train a custom LTX-2 LoRA (own character / style / motion / control):** that is the official Lightricks trainer
  (`Lightricks/LTX-2`, `packages/ltx-trainer`) + their `train-model` Claude skill, NOT ComfyUI; the trained
  `.safetensors` LoRA loads back here via the ComfyUI-LTXVideo loader. Needs Linux + CUDA + >= 32 GB VRAM per GPU
  (a 24 GB or Windows box cannot run it). When a user works with LTX-2 and wants a recurring custom subject/style or
  cross-shot consistency a prompt or the Ingredients IC-LoRA does not give, mention they can train a LoRA and offer
  the setup (one offer, not a nag). Full guide + the offer trigger: `docs/LTX2_TRAINING.md`.
- **Source:** https://ltx.io/blog/ltx-2-3-prompt-guide (official prompt guide) ; docs.comfy.org/tutorials/video/ltx/ltx-2-3 ; huggingface.co/Lightricks/LTX-2.3 ; github.com/Lightricks/ComfyUI-LTXVideo.

### LTX-2 Pro (Lightricks)
- **Prompt style:** single flowing paragraph (4-8 sentences), not tag lists (the model resists keyword dumps); a shot list a camera operator could execute.
- **Structure:** scene anchor (location/time/atmosphere) -> subject + action verb -> camera + lens (movement, focal length, aperture, framing) -> style/color science -> motion/time cue; start with the action.
- **Strengths:** physically plausible camera work, lens/aperture realism, multi-keyframe interpolation, beat-matched audio, camera presets.
- **Avoid:** tag/adjective lists, multiple actions/characters, contradictory shots. Negatives weak at CFG=1 (describe what you WANT).
- **Settings:** 24GB+ -> 720p24/4s/~20 steps; 8-16GB -> 540p24/4s/~20 steps; width/height divisible by 32; frame count divisible by 8 then +1; max prompt ~200 words.
- **Source:** github.com/Lightricks/LTX-2 ; node template `ltx2pro.md`.

### Hunyuan Video (Tencent)
- **Prompt style:** detailed English natural language (MLLM text encoder); include dynamic motion descriptors and explicit camera cues; built-in Prompt Rewrite (Normal vs Master mode).
- **Structure:** subject + appearance -> action/motion (speed/intensity) -> camera movement -> scene -> lighting/style.
- **Strengths:** motion quality and physical realism, instruction following, subject consistency across camera moves.
- **Avoid:** leans on positive description + Prompt Rewrite rather than negatives; FP8 the diffusion model if OOM.
- **Settings (ComfyUI native T2V):** 1280x720x129f, 24 fps; steps ~20-30; sampler euler (default); scheduler simple; CFG ~6.0; denoise 1.0; encoders clip_l + llava_llama3 (fp8_scaled); VAE hunyuan_video_vae; flow-shift 7.0 is the card's scheduler shift value when configuring advanced sampler nodes.
- **VRAM floor (card):** 720p (720x1280x129f) needs ~60GB GPU memory, 540p (544x960x129f) needs ~45GB; a single consumer 24GB GPU CANNOT run 720p even with FP8 (FP8 saves only ~10GB) - use 540p or multi-GPU xDiT.
- **Source:** huggingface.co/tencent/HunyuanVideo ; docs.comfy.org/tutorials/video/hunyuan/hunyuan-video.

### SVD (Stable Video Diffusion, Stability)
- **Prompt style:** NONE (image-conditioned only); motion controlled by numeric parameters, not words.
- **Structure:** provide a conditioning image; tune motion/fps via parameters.
- **Strengths:** animate a strong still into smooth short motion; `motion_bucket_id` is the main dial (higher = more motion).
- **Avoid:** no text-prompt control, no negative prompt; high `noise_aug_strength` drifts away from the input image.
- **Settings:** motion_bucket_id 127 (0-255); fps 7 (5-30); min/max_guidance_scale 1.0/3.0 (interpolated first->last frame); noise_aug_strength 0-1; svd = 14 frames, svd-xt = 25, both 576x1024.
- **Source:** huggingface.co/docs/diffusers/using-diffusers/svd ; stabilityai/stable-video-diffusion-img2vid-xt.

## Video models (API / closed)

### Kling (2.1/2.5, 2.6, 3.0/V3, O1, O3) - Kuaishou
- **Prompt style:** five-part - Subject (specific) -> Action/Motion (start+end, "first... then... finally...", speed) -> Scene (5-7 details + lighting) -> Camera (move with motivation + lens) -> Audio (tag speakers + tone, on 2.6/V3/O3). `++emphasis++` max 2. O1 edits use plain instructions.
- **Structure:** most-important first; multi-shot (V3/O3): label `Shot 1 (Xs): [framing] - [subject+action]. [camera]. [audio]`; bind recurring subjects with `@ElementName`.
- **Strengths:** motion/physics fidelity, explicit camera direction, native audio (2.6/V3/O3) with lip-sync + multi-character dialogue; up to 15s / 6 shots (O3); O1 unifies generate + edit.
- **Avoid:** open-ended motion (looping), pronouns/synonyms across shots, >2 emphasis. Negatives ARE supported (no negation words).
- **Settings:** 1080p; 5/10s (O1 3-10s; O3 up to 15s); aspect 16:9/9:16/1:1; `cfg_scale` 0-1 (def 0.5); Standard vs Pro; prompt ~2500 chars.
- **Source:** ir.kuaishou.com (Kling O1 / 3.0 releases) ; node templates `kling_*.md`.

### Veo 3 / 3.1 (Google)
- **Prompt style:** natural-language, 100-150 words; one camera move (film terms); audio after the visual ("Audio: ...").
- **Structure:** Subject -> Action -> Context/Setting -> Style (early) -> Camera/Lens -> Lighting -> Motion -> Audio -> Constraints (end).
- **Strengths:** native audio (dialogue + SFX + ambient + music) with lip-sync, real-world physics; 3.1 adds native 9:16, up to 3 refs, first/last-frame, Scene Extension.
- **Avoid:** "don't show X" does NOT work (use descriptive exclusions at the end, 1-3 max); over-constraining; conflicting camera moves.
- **Settings:** T2V + I2V; 5-20s; aspect 16:9/9:16/1:1/21:9; prompt ~1024 tokens; optional structured JSON.
- **Source:** ai.google.dev/gemini-api/docs/video ; node template `veo.md`.

### Sora 2 / Sora 2 Pro (OpenAI)
- **Prompt style:** storyboard sketch, 50-100 words; write for the lens, not adjectives.
- **Structure:** Subject+environment -> Camera (framing, angle, lens, single move) -> Action (2-3 beats with timing) -> Lighting+color (3-5 anchors) -> Audio (one note/line) -> Constraints; front-load visuals into the first ~500 chars.
- **Strengths:** coherence/continuity, native dialogue + SFX synced to timing, technical lens/film-stock cues; Pro = higher fidelity.
- **Avoid:** abstract descriptors, >2-3 beats, multiple camera moves, past ~100 words. Exclusions structured at end.
- **Settings:** T2V + I2V (image = first frame, match resolution); max ~2000 chars; Storyboard/Loop are web-app only.
- **Source:** platform.openai.com/docs/guides/video-generation ; node template `sora.md`.

### Seedance 1.0 and 2.0 (ByteDance)
- **Prompt style:** structured, concise (2.0 under ~60 words + constraints); cinematic camera language is the core strength.
- **Structure:** Subject -> Action (one verb/shot + speed + endpoint) -> Camera (shot size, then one move + angle + lens) -> Style -> Constraints; multi-shot via cut words ("Cut to / Camera switching"); 2.0 refs `@Image1 as the main character`.
- **Strengths:** camera-language response (surround, aerial, zoom, pan, follow, handheld); multi-shot consistency; 2.0 native audio with phoneme-level lip-sync (8+ langs), camera-motion replication, beat-synced editing.
- **Avoid:** stacking motion verbs, vague mood as camera direction; on-screen text and fast hands glitch; set "not fixed camera" when moving. Constraints (3-5 bans) substitute for a negative field.
- **Settings:** 480/720/1080p, **2.0 now up to 4K** (smoother gradients, richer tones, detail that holds through motion and into post; the templates default to 720p, raise the resolution field for 4K), 24fps; 2-12s (1.0) / 4-15s or auto (2.0); 2.0 inputs up to 9 images / 3 videos / 3 audio (`model.reference_images.image_1..9`, `reference_videos.video_*`, `reference_audios.audio_*`).
- **2.0 official ComfyUI templates / modes:** T2V, reference-to-video (R2V), first-last-frame (FLF2V); R2V and FLF2V each also ship a `_real_human` variant tuned for realistic people (T2V does not); `api_seedance2_0_t2v.json` + `api_seedance2_0_{r2v,flf2v}(_real_human).json` (Comfy-Org/workflow_templates), plus community storyboard-to-video / character-swap / LLM-prompt-helper. A faster, cheaper **Seedance 2.0 Mini** is selectable in the same `ByteDance2TextToVideoNode` / `ByteDance2ReferenceNode` (templates `api_seedance2_0_mini_{t2v,r2v}.json`).
- **Source:** docs.byteplus.com (Seedance 1.0 / 2.0) ; Comfy-Org/workflow_templates `api_seedance2_0_*` ; ComfyUI "Seedance 2.0 4K is live" announce (2026-06).

### Luma Ray 2 / Ray 3 (Dream Machine)
- **Prompt style:** keep camera OUT of the prompt (set via API "Concepts"); content-only.
- **Structure:** Main subject -> Action (direction + endpoint) -> details -> scene/atmosphere -> style -> quality reinforcer at end; pass camera as composable Concepts (20 moves, 14 angles).
- **Strengths:** photorealism, composable multi-motion camera, Loop + Video Extension (~60s); Ray 3 reasoning + 16-bit EXR HDR.
- **Avoid:** camera in the prompt text; multiple primary actions; negative phrasing. No negative field, no CFG, no seed, no native audio.
- **Settings:** 540/720/1080p; 5s or 9s; many aspects; Ray 2 Flash 3x faster; image inputs `frame0`/`frame1`.
- **ComfyUI:** Ray 3.x runs via `LumaRay32TextToVideoNode` (+ `LumaRay32ExtendVideoNode` to extend a clip, chained by the upstream `generation_id`); template `api_luma_ray3_3_t2v.json`.
- **Source:** docs.lumalabs.ai/docs/video-generation ; node template `luma.md`.

### Runway Gen-4 / Gen-4.5
- **Prompt style:** complete natural-language sentences (not keyword lists); precise verbs; one action + one camera move per sentence with a speed modifier.
- **Structure:** Subject action -> Camera motion -> Visual context/style; for I2V don't re-describe the source; references control their domain (Character / Style / Environment, up to 3).
- **Strengths:** reference consistency across shots, clean cinematic motion; Gen-4.5 adds T2V + sequenced camera choreography + higher resolution.
- **Avoid:** "no X"/"avoid Y" NOT supported (may backfire); keyword lists; competing actions. No negatives, no CFG, no native audio.
- **Settings:** 720p (Gen-4 Turbo) / 720-1080p (Gen-4.5); 5/10s; 24fps; max prompt 1000 chars; Gen-4 Turbo is I2V-only.
- **Source:** docs.dev.runwayml.com ; help.runwayml.com Gen-4 prompting guide ; node template `runway.md`.

### MiniMax / Hailuo
- **Prompt style:** Subject + Action (dynamic verbs) + Setting + Time + Style; camera commands in square brackets with NO space before text, e.g. `[Push in]A lamb stands...`.
- **Structure:** bracket at the point the move occurs; combine up to 3 moves - simultaneous `[Pan left,Pedestal up]` (no gap) or sequential `[Push in] then [Pan right]`.
- **Strengths:** physics/motion realism, facial expression, frame-accurate motion; Director-mode camera; keyframe control; multilingual.
- **Avoid:** vague words, natural-language camera descriptions (use brackets), space after `]`, over-long. Default Prompt Optimizer rewrites prompts (set `prompt_optimizer: false` for precise control). No standard negative field.
- **Settings:** T2V + I2V; Standard vs Fast; prompt 2-2000 chars (optimal ~100-300).
- **Source:** minimax.io/platform/document/video_generation ; node template `minimax.md`.

### PixVerse
- **Prompt style:** `[Character] [Action] [Scene] with [Visual Style], [Cinematography], and [Mood]`; state camera work explicitly and chain it.
- **Structure:** character/object -> scene -> cinematography (position, movement, angle) -> style/grade -> mood -> negative prompt.
- **Strengths:** customizable camera movement/angle, follows camera + lighting words (V5.6), product multi-clip orbit.
- **Avoid:** generic prompts, visual overload, omitting style, excessive length. Negatives ARE supported (list artifacts/objects/styles to exclude).
- **Settings:** 5/8/10s; up to 1080p (720p for 10s); aspect 16:9/9:16/4:5; T2V + I2V + Effects. (Maker docs gated; verify exact knobs against PixVerse platform docs.)
- **Source:** imagine.art/blogs/pixverse-v5-prompt-guide ; docs.pollo.ai.

### Vidu (Q1 / Q2)
- **Prompt style:** `@`-label syntax to bind subjects, then action + camera in natural language: `@a(short-hair woman in red coat), @b(man in denim)` ... action ... camera.
- **Structure:** reference labels first -> action (sequential) -> camera (intentional moves); Q1 leans on keyframes.
- **Strengths:** multi-subject reference consistency (up to 7, one image each, `@a, @b...`); built-in push/pull, pan, tilt, zoom; motion-amplitude control; video extension.
- **Avoid:** thin official prompt doc; keep references high-res; fixed seed for repeatable motion. Negative support not documented.
- **Settings:** 1080p; refs JPG/PNG/WEBP (<=10MB, up to 7); motion amplitude auto/small/medium/large; aspect 16:9/9:16.
- **Source:** wavespeed.ai/docs (Vidu R2V) ; vidu.com. (Verify knobs against Vidu platform docs.)

### Pika 2.2 / 2.5
- **Prompt style:** shot-plan order - subject + material details -> one motion cue (direction + speed) -> scene/lighting -> one camera move -> style at the end; describe what IS.
- **Structure:** one motion per shot; exactly ONE camera type (zoom OR pan OR rotate OR tilt); "smooth" reduces jitter.
- **Strengths:** quick turnaround; Pikascenes (combine refs, `ingredients_mode`), Pikaframes (up to 5 keyframes) for transitions/loops.
- **Avoid:** complex multi-stage motion, stacking camera types, over-describing. Negatives ARE supported ("ugly, blurry, low quality, watermark, distorted, jittery, morphing"). Pikaffects/Pikaswaps are web-UI only.
- **Settings:** 720/1080p; 5/10s; many aspects; guidance 8-24 (def 12); motion intensity 1-4 (def 1).
- **Source:** pika.art ; docs.pika.art ; node template `pika.md`.

## Audio models

### Stable Audio (Stability)
- **Prompt style:** genre + mood + instruments + BPM/tempo, short English phrase ("128 BPM tech house drum loop"). No lyrics, no realistic vocals.
- **Structure:** concise tag-like sound description, then set `seconds_total` (and optional `seconds_start`).
- **Strengths:** SFX, foley, ambiences, drum/instrument loops; precise BPM and instrument naming.
- **Avoid:** vocals/singing, full songs, non-English prompts.
- **Settings:** 44.1kHz stereo; max ~47s (default 47.6s via EmptyLatentAudio); steps in KSampler.
- **Download / license:** GATED on HF, accept the license + use a token to download (requires an HF account + license-agreement form at huggingface.co/stabilityai/stable-audio-open-1.0 before the weights are accessible). License is NON-COMMERCIAL only (stable-audio-community); commercial use requires a separate license from stability.ai/license.
- **Source:** huggingface.co/stabilityai/stable-audio-open-1.0 ; docs.comfy.org/tutorials/audio/stable-audio.

### ACE-Step
- **Prompt style:** two fields. Tags = comma-separated genres/scenes/instruments/vocals/tempo ("electronic, pop, female voice, 110 bpm, melodic"). Lyrics = `[verse]`, `[chorus]`, `[bridge]`, `[outro]`; optional leading language code `[en]`/`[zh]` (19 languages).
- **Structure:** tags describe the sound; lyrics drive sung content and sections.
- **Strengths:** mainstream styles, lyric alignment, fast (~4 min audio in ~20s on A100), lyric editing/remix.
- **Avoid:** less-common languages underperform; lyric edits in small segments; copyright risk.
- **Settings:** duration in EmptyAceStepLatentAudio (-1 random); steps 27 or 60; `denoise` for similarity; vocal prominence via LatentOperationTonemapReinhard `multiplier`.
- **Source:** github.com/ace-step/ACE-Step ; docs.comfy.org/tutorials/audio/ace-step/ace-step-v1.

### ElevenLabs (API via ComfyUI nodes)
- **Prompt style:** TTS = plain text (voice/emotion via parameters). SFX = specific natural-language description (material, size, environment, distance, temporal arc, acoustic space); onomatopoeia helps.
- **Strengths:** natural multilingual voices, instant cloning, precise SFX; node supports `eleven_multilingual_v2` and `eleven_v3`.
- **Avoid:** over-long SFX prompts; expecting prompt words to control tone (use parameters).
- **Settings (built-in TTS node):** `stability` (def 0.5), `similarity_boost` (def 0.75), `style` (def 0.0), `speed` (def 1.0), `use_speaker_boost`. Text-to-Effect: `duration` 0.5-30s, `prompt_influence` 0-1 (def 0.3).
- **Source:** elevenlabs.io/docs ; docs.comfy.org/built-in-nodes/ElevenLabsTextToSpeech.

### ChatterBox (Resemble AI)
- **Prompt style:** literal text to speak (expressiveness via parameters, not words); voice cloning uses a 10s+ reference clip (match language to avoid accent transfer).
- **Strengths:** zero-shot cloning, emotion intensity dial, multilingual (23+ in V3), fast.
- **Avoid:** high `exaggeration` speeds up speech (lower `cfg_weight` to compensate); language mismatch causes accent bleed.
- **Settings:** defaults `exaggeration=0.5`, `cfg_weight=0.5`; dramatic `exaggeration` 0.7+ with `cfg_weight` ~0.3.
- **ComfyUI build:** the cited repo is the Python library; for ComfyUI install `filliptm/ComfyUI_Fill-ChatterBox` (ComfyUI Manager), whose TTS node takes `text` + `reference_audio` + `exaggeration` + `cfg_weight` -> AUDIO.
- **Source:** github.com/resemble-ai/chatterbox (Python library).

## 3D models

### Hunyuan3D (Tencent)
- **Prompt style:** subject supplied mainly as a clean input image (single or multi-view, background removed); text is secondary.
- **Structure:** two stages - Hunyuan3D-DiT geometry, then Hunyuan3D-Paint textures/PBR; use `Hunyuan3Dv2Conditioning` (single) or `...MultiView`.
- **Strengths:** strong geometry from images, multi-view input, high-res PBR textures.
- **Avoid:** cluttered/un-preprocessed input images; native ComfyUI gives geometry only on `2mv`.
- **Settings:** output `.glb` to ComfyUI/output/mesh; turbo workflow CFG/Flux-Guidance ~1.0; VRAM Mini 5GB / Standard 6GB geometry / 12GB with texture.
- **Source:** docs.comfy.org/tutorials/3d/hunyuan3D-2.

### Tripo
- **Prompt style:** "Subject + Detail Description + Style Definition" ("A futuristic cybernetic helmet, matte black finish, glowing blue neon strips, high detail, sci-fi style"); concrete geometry/materials/finishes.
- **Structure:** main subject + features clearly; prioritize materials over lighting.
- **Strengths:** material/texture fidelity, multi-view fusion, smart retopology; texture on/off, face-limit budget.
- **Avoid:** abstract adjectives, over-long prompts, cluttered/off-center input images.
- **Settings:** texture on/off; `face_limit`; image input JPG/PNG/WEBP <5MB, solid background, centered.
- **ComfyUI node:** `VAST-AI-Research/ComfyUI-Tripo` (Comfy Registry: `comfyui-tripo`); key nodes `TripoAPIDraft` (text/image -> draft mesh), `TripoTextureModel`, `TripoRefineModel`; needs a Tripo API key.
- **Source:** tripo3d.ai/blog/text-to-3d-prompt-engineering.

### Rodin (Hyper3D)
- **Prompt style:** specific detailed object description; name materials/textures, include lighting, state style, give context; image upload switches to Image-to-3D.
- **Strengths:** geometry quality (Gen-2), quad meshes, HD/4K textures, PBR/Shaded/All material modes, broad export.
- **Avoid:** vague prompts; cluttered backgrounds / low-res inputs (>=512x512, <=16MB); download links expire ~10 min.
- **Settings:** topology Raw or Quad (def Quad); materials PBR/Shaded/All; quality tiers; formats GLB/USDZ/FBX/OBJ/STL; up to 5 images.
- **ComfyUI node:** `DeemosTech/ComfyUI-Rodin`; key nodes `mLoadRodinAPIKEY` + `mRodin3D_Gen2` (text/image -> 3D mesh, GLB); needs a Hyper3D API key.
- **Source:** github.com/DeemosTech/rodin3d-skills ; developer.hyper3d.ai.

### Meshy
- **Prompt style:** Subject + Modifiers (materials, colors, details) + Style; 3-6 concrete physical details; reference anchors; style keywords (low-poly, photorealistic, cartoon, cyberpunk neon, anime cell shading).
- **Structure:** one object, not a scene; add "T-Pose" to characters you plan to rig.
- **Strengths:** style range, character/rigging support, iterative refine; prompts up to 800 chars, any language.
- **Avoid:** describing whole scenes; evaluative adjectives. Negatives ARE supported (`negative_prompt`). Iterate (Generate -> Refine -> Adjust).
- **ComfyUI node:** community `Kazama-Suichiku/ComfyUI-Meshy` (needs a Meshy API key); or call the Meshy REST API via a Python node.
- **Source:** help.meshy.ai (best practices) ; docs.meshy.ai/en/api/text-to-3d.

---

## Newer and niche models

Recently added to the template library. Most now have official docs.comfy.org pages or model cards (researched from
those); a few are thin on prompt specifics and say so.

### Image

**Capybara** (unified image + video, gen + edit), Glanty / xgen-universe, built on HunyuanVideo-1.5. The card defines
exactly four `--task_type` values: t2i, t2v, ti2i (instruction image edit), tv2v (instruction video edit); there is no
I2V task. Natural language for generation, imperative instruction for edits ("Change the time to night"); optional
Qwen3-VL-8B auto-rewrite expands short prompts (separate Qwen/Qwen3-VL-8B-Instruct download). Image 720p / 50 steps,
video 480p / 50 steps (frames 81/101/121). guidance_scale default is 1.0 (the card's parameter-table default); the 4.0
seen in the T2V/T2I example commands is a per-command override, not the default. FP8 available but requires NVIDIA
compute capability >= 8.9 (Ada Lovelace / Hopper: RTX 4090 / L40 / H100), so an RTX 3090 (cc 8.6) cannot use FP8.
Negatives not documented. Source: huggingface.co/xgen-universe/Capybara. **ComfyUI build:** official templates `Image_capybara_v0_1_image_edit.json` and `Image_capybara_v0_1_text_to_image.json` (Comfy-Org template library).

**Bernini-R** (image/video relighting edit), ByteDance, Wan2.2-based (also a 1.3B Wan2.1 fine-tune ~2.6GB). No official
prompt guide; prompt like a Wan/Qwen-edit relight: describe target lighting (direction, temperature, intensity, mood)
+ what to preserve ("keep subject and pose; relight as warm sunset key from camera-left"); use a reference image to
carry lighting across a set. Treat steps/CFG like a Wan2.2 edit workflow. Quantized variants for VRAM-constrained
setups (in the repo beyond the fp16 high/low-noise files): `wan2.2_bernini_r_high_noise_fp8_scaled.safetensors`,
`wan2.2_bernini_r_high_noise_mxfp8.safetensors`, `wan2.2_bernini_r_low_noise_fp8_scaled.safetensors`,
`wan2.2_bernini_r_low_noise_mxfp8.safetensors`. Source: huggingface.co/Comfy-Org/Bernini-R. **ComfyUI build:** official tutorial docs.comfy.org/tutorials/video/bytedance/bernini-r; the Comfy-Org repack runs on the standard Wan2.2 graph (the high-noise / low-noise UNETLoader pair).

**Anima** (anime t2i), CircleStone Labs, 2B (Qwen-3 0.6B encoder). Danbooru tags, natural language, or mix; order
`[quality/meta/year/safety] [char count] [character] [series] [artist] [general]`; positive prefix `masterpiece,
best quality, score_7, safe,`, negative `worst quality, low quality, score_1..3, artist name`; lowercase tags with
spaces, artists prefixed `@`. 512-1536px, 30-50 steps, CFG 4-5, sampler er_sde / euler_a / dpmpp_2m_sde_gpu;
negatives supported; weak at realism and text. Source: docs.comfy.org/tutorials/image/anima/anima.

**NewBie (Exp0.1)** (anime t2i), 3.5B Next-DiT (Gemma3-4B + Jina-CLIP-v2, FLUX VAE). Danbooru tags or natural
language, but trained on XML structured prompts that bind attributes per character. Use per-character XML blocks
(`<character_1><gender>1girl</gender><appearance>...</appearance><clothing>...</clothing><action>...</action>
<position>center_left</position></character_1>`) + a `<general_tags>` block for multi-character scenes; flat tags fine
for single subjects. 1024x1024, ~28 steps. Source: docs.comfy.org/tutorials/image/newbie-image/newbie-image-exp-0-1.

**PixelDiT** (t2i), NVIDIA, VAE-free pixel-space DiT (~1.3B, Gemma-2-2B-IT encoder). Plain natural-language positive +
negative (both exposed), no special syntax. No VAE means no reconstruction artifacts, fine texture preserved; 1024px
multi-aspect; steps/CFG not documented. Source: docs.comfy.org/tutorials/image/pixeldit/pixeldit.

**Ovis-Image** (t2i, text rendering), Alibaba AIDC-AI, 7B optimized for legible text. Natural language, put literal
text in quotes inside the description (`[scene/style] + "EXACT TEXT" + [typography/material/lighting]`); best for
posters/banners/logos/UI. 1024px, 50 steps, CFG 5.0; negatives supported. Source: docs.comfy.org/tutorials/image/ovis/ovis-image.

**Lens / Lens Turbo** (t2i), Microsoft, 3.8B MMDiT (GPT-OSS-20B encoder, FLUX.2 VAE); Turbo is the few-step distill.
Clear descriptive natural-language sentences (FLUX/MMDiT conventions); the encoder favors prompt following over tags.
1024px multi-aspect; Lens ~50 steps, Lens Turbo ~4-8 steps; CFG/negatives not documented; encoder can sit on CPU to
fit 24GB. Source: docs.comfy.org/tutorials/image/lens/lens.

**Quiver** (text/image to SVG), API partner node (SVG.io Arrow 1.1 / Max). Natural-language description in `prompt` +
style hints in `instructions` ("minimalist unicorn icon for a SaaS dashboard" / "flat monochrome, rounded corners,
clean geometry"); optional references (up to 4 / 16 on Max) + viewBox attributes. Lower temperature (~0.4) for clean
geometry; output is real editable vector paths. Source: docs.quiver.ai ; blog.comfy.org/p/quiver-structured-svg-generation.

### Video

**HappyHorse 1.1**, Alibaba, cinematic video model with native synchronized audio, API (muapi.ai / Model Studio
partner nodes; ComfyUI nodes `HappyHorseTextToVideoApi` / `HappyHorseImageToVideoApi` / `HappyHorseReferenceVideoApi`):
T2V, I2V, reference-to-video (up to 9 reference images, no cross-contamination; the official ComfyUI template wires 3, image1-3); 3-15s at 720p/1080p, aspect
16:9 / 9:16 / 1:1 / 4:3 / 3:4 / 21:9. **Audio generates in the same render pass** (dialogue, sound effects and
background music synced to the video, no stitching in post). Long-context prompts (2,500+ chars, 6-8 consecutive
scenes in one prompt) and full cinematic language (shot-reverse-shot, tracking shots, transitions); natural skin
holds up for close-up commercial work. Prompt formula still `subject + environment + camera move + motion behavior +
lighting + style`; keep each motion small and specific ("subtle wind in hair", not "dancing in a chaotic crowd"),
ONE camera move per beat (slow pan / dolly-in / handheld push-in). Worked example: "young woman in red jacket on
rainy neon street, medium shot, slow handheld push-in, slight head turn and blinking, wet pavement reflections,
cinematic lighting, consistent face, stable background." R2V: feed identity/outfit/style refs into the
`model.reference_images.image1..9` slots to lock them across cuts (more refs = more consistency). Negatives not
documented (hosted API); settings are API fields (resolution, duration, aspect, audio), no sampler knobs. Official
templates: `api_happyhorse1_1_t2v.json` / `_i2v.json` / `_r2v.json` (Comfy-Org/workflow_templates).
Source: blog.comfy.org/p/happyhorse-11-is-now-available-in ; docs.comfy.org/tutorials/partner-nodes/happyhorse.

**HuMo**, ByteDance + Tsinghua, human-centric video (HuMo-1.7B in ComfyUI): lip-synced video from text + image +
audio. Text describes appearance/action/scene, image conditions identity, audio drives lip-sync; modes Text+Audio and Text+Image+Audio (TIA = most control, best
lip-sync; standalone Text+Image is marked not-implemented for 1.7B in the repo Todo). Up to 97 frames @ 25fps, 720p (~3.9s); TIA wants
>=24GB; negatives not documented. Source: github.com/Phantom-video/HuMo. **ComfyUI build:** HuMo-1.7B runs natively and lip-sync is built into TIA mode; `ckinpdx/comfyui-humo-audio-motion` adds the `HuMoAudioAttentionControlV4` node (audio cross-attention patch; inputs `model` + `audio_blocks`) as an optional experimental audio-driven body-motion enhancement, not the lip-sync itself.

**SCAIL-2**, zai-org (Zhipu/GLM), Wan-based end-to-end character animation: animates a reference character with a
driving video (also replacement, multi-character). Control by inputs, not text: 1 reference image
+ 1 driving video + a per-frame driving mask (generated by the bundled SCAIL-Pose preprocessor; the mask is a required input even in Animation Mode); tune `pose_strength` (exact-copy vs style adaptation).
Source: github.com/zai-org/SCAIL-2. **ComfyUI build:** community all-in-one node `collbroGTR/comfyui-scail2-infinity` (also `TTPlanetPig/comfyui_scail2_multi_cond`); open its example workflow and feed the reference image + driving video + `pose_strength`.

### Audio

**Sonilo**, AI music, ComfyUI partner node: primarily video-to-music (scores a video frame-synced), plus a
text-to-music path. Video-to-music is promptless (analyzes visuals/pacing/emotion); optional brief mood+genre+
instrument phrase refines ("Dreamy ambient electronic", "Lazy jazz instrumental"); output auto-matches the video's
duration, ~20s, multiple variations. Not a lyric/structure tool. Source: docs.comfy.org/tutorials/partner-nodes/sonilo/video-to-music.

## Enhancement and utility (NOT prompt-driven)

These are not text-prompted generators. They take an existing image/video, or run inside a graph, and improve or
analyze it. They need the right SETTINGS and inputs, not a prompt recipe. Use them as pipeline steps (e.g. a final
upscale on a hero, frame interpolation on a clip, a depth map to drive ControlNet).

### Upscale, restore, interpolation

- **Real-ESRGAN / ESRGAN family** (upscale): GAN super-resolution, deterministic and fast; one pass that enlarges
  (2x/4x) and removes compression/blur. Use for a final 2x/4x on a good image or per-frame on video (detail
  preserved, not hallucinated). ComfyUI: `UpscaleModelLoader` -> `ImageUpscaleWithModel`; scale is baked into the
  model file (RealESRGAN_x2/x4plus, 4x-UltraSharp = 4x); add an ImageScale downsample for non-native targets.
  Source: github.com/xinntao/Real-ESRGAN, OpenModelDB.
- **SUPIR** (diffusion restore/upscale): SDXL-based, regenerates plausible high-frequency detail, optional caption.
  Use on heavily degraded/low-res photos where ESRGAN stays soft; heavier/slower, a quality pass not a bulk step.
  Settings: scale_by, ~30-45 steps, cfg, denoise, s_churn/s_noise; v0Q (quality) vs v0F (light degradation,
  faithful); ~10GB (512->1024) to 24GB (~3072px), FP8 + VAE tiling cuts VRAM. LICENSE: the SUPIR weights are
  NON-COMMERCIAL (XPixel Group); do not use in a commercial pipeline. Source: github.com/kijai/ComfyUI-SUPIR.
- **SeedVR2** (video/image upscale+restore): one-step diffusion with temporal consistency (frames denoised
  together). Target the short edge (default 1080); 3B (fast) vs 7B (quality); FP16/FP8/GGUF; batch follows the
  4n+1 rule (1,5,9,13,17,21...); ~8GB to 24GB+. Source: github.com/numz/ComfyUI-SeedVR2_VideoUpscaler.
- **FlashVSR** (video super-res): one-step streaming diffusion, ~17 FPS at 768x1408 on an A100; designed for 4x SR
  (use 4x for best stability); V1.1 recommended. CAVEAT: needs the Block-Sparse Attention (LCSA) module
  (`mit-han-lab/Block-Sparse-Attention`, a compile-and-install dependency, memory-intensive at build time); without it
  ComfyUI and other third-party implementations fall back to DENSE attention with noticeable quality degradation at
  higher resolutions (the card calls out early ComfyUI versions as affected). GPU compatibility confirmed on A100/A800;
  H200 (Hopper) also runs per the card (limited acceleration); RTX 40/50 and H800 currently unknown. Source: huggingface.co/JunhaoZhuang/FlashVSR. **ComfyUI build:** runs through kijai `ComfyUI-WanVideoWrapper` (FlashVSR is a supported family there) - see KIJAI.md for the WanVideoWrapper loader / sampler nodes. (`OHLIA/flashvsr_mix_gui` is a standalone GUI, not a node pack.)
- **Z-Image-Turbo Fun-ControlNet-Tile** (diffusion tile SR): ControlNet-Tile super-res for the Z-Image-Turbo stack,
  trained to 2048x2048, 8-step distilled; tiled so structure holds while enlarging. Reuses the Z-Image loader
  (8 steps, low CFG), so no separate SR model stack. This is the IDENTITY-FAITHFUL path: unlike the Union
  controlnet-locked img2img refine (which regenerates a real subject's face at denoise 0.4+), the Tile model
  enlarges without reinterpreting. See the Z-Image-Turbo entry above. Source:
  huggingface.co/alibaba-pai/Z-Image-Turbo-Fun-Controlnet-Union-2.1.
- **Topaz** (external API): commercial upscale/denoise/sharpen + frame interpolation via Topaz's API (built-in
  `TopazVideoEnhance` node). Upscale models Starlight (Astra) Fast/Creative + Starlight Precise 2.5; interpolation 15-240 fps, slow-mo 1-16x; needs a license.
  Source: docs.comfy.org/built-in-nodes/TopazVideoEnhance.
- **Magnific** (external API): cloud creative upscaler/enhancer (Freepik) up to 16K with prompt + creativity
  controls; no first-party ComfyUI node (HTTP/SDK or community wrapper). Scale 2x/4x/8x/16x. Source: docs.magnific.com.
- **FILM** (frame interpolation): Google, handles large motion; accepts as few as 2 frames, arbitrary multipliers.
  Use for slow-mo / fps boost with large motion. ComfyUI: FILM VFI node (multiplier, clear_cache_after_n_frames).
  Source: github.com/google-research/frame-interpolation.
- **RIFE** (frame interpolation): fast optical-flow interpolation, the default speed-first choice (e.g. 16->32/60
  fps over many frames). ComfyUI: RIFE VFI node (ckpt rife47/rife49, multiplier, ensemble). Source: github.com/hzwer/Practical-RIFE.

**Picking an upscaler + ordering a restore chain** (general practice, not tool-specific). Choose by content, not
only by scale: a GAN (Real-ESRGAN) is fast and faithful for photoreal footage, but x4 can look plastic on skin and
fine fabric, so x2 is the safer pore-preserving pass; a diffusion upscaler (FlashVSR / SeedVR2 / SUPIR) handles
stylized, anime, line-art, and AI-generated frames better and regenerates detail instead of only sharpening. Rough
rule: source under ~540p or big jumps -> 4x GAN; 720p+ cleanup -> 2x GAN; animated / AI-gen -> diffusion. ORDER
matters in a restore chain: denoise FIRST (4x grain becomes 4x larger grain, and noise turns into per-frame
flicker), then deinterlace (QTGMC / yadif) and deblock if the source is heavily compressed, THEN upscale, and
color-grade AFTER (more headroom). Stabilize on the original, not at 4x. Do not run x2 twice to fake x4 (it stacks
artifacts), and do not expect an upscaler to deblur, it reconstructs detail, not motion. Cheap generation path:
make it small, then upscale the keeper (e.g. LTX-2.3 at 512 -> Real-ESRGAN x4 -> ~2048).

### Segmentation, depth, pose, conditioning

- **SAM3** (segmentation): detects/segments/tracks every instance matching a text noun phrase or visual prompt,
  across images and video. Use to isolate subjects -> mask for inpaint/background-swap/compositing, or track an
  object through a clip. Outputs masks, boxes, scores, per-object IDs. Source: github.com/facebookresearch/sam3.
- **BiRefNet** (matting): high-res foreground mask with hair-level edges. Use for clean cutouts/background
  replacement when you need sharper edges than a coarse segmenter. Variants general/portrait/matting/HR (up to
  2048x2048). Source: github.com/ZhengPeng7/BiRefNet.
- **High-detail matting (hair / fur / semi-transparent / motion blur)** is a multi-stage VFX task, not one node:
  coarse select (SAM3 / BiRefNet) -> trimap -> alpha matte (ViTMatte / SDMatte / Matte-Anything) -> edge refine
  (LayerStyle `MaskEdgeUltraDetailV2`); for video use a temporal model (MatAnyone2, needs a SAM2/SAM3/SeC keyframe
  mask; or RVM for clean humans). Full recipe, tool table, ready-template pointer, and license flags in
  [`ADVANCED.md`](../../docs/ADVANCED.md).
- **Depth Anything V2 / V3** (depth/geometry): per-pixel relative depth from one image (V2); V3 adds consistent
  depth + geometry + camera pose across multi-view/video and can export point clouds. Use to make a depth map to
  drive a depth ControlNet, parallax, or masking. Source: github.com/DepthAnything/Depth-Anything-V2 ;
  github.com/ByteDance-Seed/Depth-Anything-3.
- **DWPose** (pose): whole-body 2D keypoints (18 body, 21/hand, 68 face) as a skeleton; a more accurate OpenPose
  replacement to drive a pose ControlNet. Source: github.com/IDEA-Research/DWPose.
- **MoGe** (geometry): monocular point map + depth + normals in one pass from a single photo, for 3D-aware
  conditioning/reconstruction beyond a flat depth map. MoGe-2 adds metric scale. Source: github.com/microsoft/MoGe.
- **IP-Adapter** (conditioning): ~22M adapter that lets a diffusion model take an IMAGE as a prompt (decoupled
  cross-attention). Use to transfer style/subject/face from a reference without text; stack with ControlNet.
  Variants base / Plus / Face / FaceID; main knob is conditioning weight. Source: github.com/tencent-ailab/IP-Adapter.
- **LivePortrait** (portrait animation): drives a still portrait with a driving video's motion/expression (stitching
  + eye/lip retargeting). Use to animate one portrait without per-subject training. Source: github.com/KlingAIResearch/LivePortrait.
- **Mediapipe** (landmarks): fast on-device face (478) / hand (21) / pose (33) landmarks (Holistic combines all).
  Use for lightweight keypoints for conditioning/masking/alignment. Source: ai.google.dev/edge/mediapipe.
- **VOID** (video inpainting / object removal): Netflix open-source; removes a subject plus its shadows, reflections,
  and the motion it caused. Control is a 4-value greyscale "quadmask" (remove / overlap / physically-affected / keep),
  NOT a binary mask or text prompt. Two passes: Pass 1 base, Pass 2 optical-flow refinement for longer/textured clips.
  Source: docs.comfy.org/tutorials/utility/void-video-inpainting. **ComfyUI build:** the linked tutorial IS the official Comfy-Org template - open it for the quadmask input node and the two-pass (generate + optical-flow refine) graph.
- **Qwen3-VL TextGenerate** (in-graph local VLM, NOT an image/video model): a `TextGenerate` node fed by `CLIPLoader(qwen3vl_4b_fp8_scaled.safetensors)` runs Qwen3-VL locally to generate text from a prompt + optional `image` / `video` / `audio` input. Use it in-graph for captioning, VQA, or prompt generation / rewriting with no API call. Params: `max_tokens` (def 512), `temperature` 0.7, `top_k` 64, `top_p` 0.95. Template `llm_qwen3vl_text_gen.json`; weights `Comfy-Org/Qwen3-VL` (Apache-2.0). The local, no-cost counterpart to the in-graph Claude / API prompt nodes.

## Sources and provenance

Per-model guidance above is distilled from official sources: each maker's documentation and model cards (Black
Forest Labs, Stability, Alibaba / Tongyi, ByteDance / BytePlus / Volcengine, Google, OpenAI, xAI, Kuaishou,
Lightricks, Tencent, Luma, Runway, MiniMax, Recraft, Ideogram, Reve, Sber / FusionBrain, Resemble AI, Tripo,
Hyper3D, Meshy, BRIA, Baidu, Meituan, NVIDIA, VectorSpaceLab, lodestones, Krea, Glanty / xgen-universe, CircleStone
Labs, NewBie-AI, Alibaba AIDC-AI, Microsoft, SVG.io, Sonilo, Phantom-video, zai-org / Zhipu, Netflix), the official
ComfyUI tutorials at docs.comfy.org, and the per-model prompt templates shipped with the `anthropic-claude` node (by
alexmunteanu), which are themselves distilled from official prompting guides. The enhancement/utility entries are
sourced from each project's GitHub / HuggingFace (Real-ESRGAN, SUPIR, SeedVR2, FlashVSR, Topaz, Magnific, FILM,
RIFE, SAM3, BiRefNet, Depth Anything, DWPose, MoGe, IP-Adapter, LivePortrait, Mediapipe). Specs change; when a
model updates, re-check its source link.
